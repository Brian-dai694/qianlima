<#$
.SYNOPSIS
  Enforce the protected-invariants file policy for a target path.
.DESCRIPTION
  Classifies writes or script execution against protected project paths. A block
  cannot be overridden by confirmation; an ask requires explicit confirmation.
  This complements, and does not replace, check-command-safety.ps1.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$TargetPath,
  [ValidateSet('read', 'write', 'modify', 'execute', 'external_write')]
  [string]$Operation = 'write',
  [switch]$Confirmed,
  [switch]$AsJson,
  [switch]$NoExit
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$policyPath = Join-Path $PSScriptRoot '..\protected-invariants.yaml'

function Get-NormalizedRelativePath([string]$PathValue) {
  $candidate = if ([IO.Path]::IsPathRooted($PathValue)) { $PathValue } else { Join-Path $projectRoot $PathValue }
  $full = [IO.Path]::GetFullPath($candidate)
  $root = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { return $null }
  return $full.Substring($root.Length).Replace('\', '/')
}

function Get-PolicyEntries([string]$Path) {
  $entries = @()
  $current = $null
  foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8 -Force)) {
    if ($line -match '^    - path:\s*(.+?)\s*$') {
      if ($current) { $entries += [PSCustomObject]$current }
      $current = [ordered]@{ path = $Matches[1].Trim('"', "'"); action = 'ask'; reason = '' }
      continue
    }
    if ($current -and $line -match '^      action:\s*(\S+)\s*$') { $current.action = $Matches[1].Trim('"', "'"); continue }
    if ($current -and $line -match '^      reason:\s*(.+?)\s*$') { $current.reason = $Matches[1].Trim('"', "'"); continue }
  }
  if ($current) { $entries += [PSCustomObject]$current }
  return @($entries)
}

$relative = Get-NormalizedRelativePath $TargetPath
$reasons = New-Object System.Collections.Generic.List[string]
$matched = @()
if ($Operation -eq 'read') {
  $classification = 'allow'
} elseif ($null -eq $relative) {
  $classification = 'deny'
  $reasons.Add('Target is outside the project workspace.')
} else {
  $entries = Get-PolicyEntries $policyPath
  foreach ($entry in $entries) {
    $entryPath = $entry.path.Replace('\', '/').TrimEnd('/')
    if ($relative -eq $entryPath -or $relative.StartsWith($entryPath + '/', [StringComparison]::OrdinalIgnoreCase)) {
      $matched += $entry
    }
  }
  $block = @($matched | Where-Object { $_.action -eq 'block' })
  $ask = @($matched | Where-Object { $_.action -eq 'ask' })
  if ($block.Count -gt 0) {
    $classification = 'deny'
    foreach ($entry in $block) { $reasons.Add("$($entry.path): $($entry.reason)") }
  } elseif ($ask.Count -gt 0 -and -not $Confirmed) {
    $classification = 'confirmation_required'
    foreach ($entry in $ask) { $reasons.Add("$($entry.path): $($entry.reason)") }
  } else {
    $classification = 'allow'
  }
}

$result = [PSCustomObject]@{
  classification = $classification
  operation = $Operation
  target = $TargetPath
  relative_target = $relative
  matched = @($matched)
  reasons = @($reasons)
  required_action = switch ($classification) {
    'allow' { 'may_continue' }
    'confirmation_required' { 'show_target_and_reason_then_wait_for_explicit_confirmation' }
    'deny' { 'do_not_execute' }
  }
}
if ($AsJson) { $result | ConvertTo-Json -Depth 6 } else { Write-Host "Protected invariant: $($result.classification)"; $result.reasons | ForEach-Object { Write-Host "- $_" } }
if (-not $NoExit) { if ($classification -eq 'confirmation_required') { exit 10 }; if ($classification -eq 'deny') { exit 20 } }
