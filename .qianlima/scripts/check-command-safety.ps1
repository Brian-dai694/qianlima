<#
.SYNOPSIS
  Classify a shell command as allow, confirmation-required, or deny.
.DESCRIPTION
  Inspects a command string for destructive verbs, recursion, wildcards, variable paths,
  and parent traversal, then resolves literal target paths. Destructive commands need an
  explicit in-workspace target, and recursive ops are limited to approved runtime scopes.
  Returns the classification and reasons; by default exits 10 for confirmation and 20 for deny.
.PARAMETER Command
  The full command string to evaluate.
.PARAMETER AsJson
  Emit the result object as JSON instead of console text.
.PARAMETER NoExit
  Do not set a non-zero exit code for confirmation or deny outcomes.
.EXAMPLE
  .\check-command-safety.ps1 -Command 'Remove-Item .\.qianlima\tmp\a.txt' -AsJson
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Command,
  [switch]$AsJson,
  [switch]$NoExit
)

$ErrorActionPreference = 'Stop'

function Test-PathWithin([string]$Candidate, [string]$Parent) {
  $candidateFull = [System.IO.Path]::GetFullPath($Candidate).TrimEnd('\')
  $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\')
  return $candidateFull.StartsWith($parentFull + '\', [System.StringComparison]::OrdinalIgnoreCase) -or
    $candidateFull.Equals($parentFull, [System.StringComparison]::OrdinalIgnoreCase)
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$allowedCleanupScopes = @(
  (Join-Path $projectRoot '.qianlima\tmp'),
  (Join-Path $projectRoot '.qianlima\logs'),
  (Join-Path $projectRoot '.qianlima\run-traces'),
  (Join-Path $projectRoot '.qianlima\reports\generated')
)
$reasons = New-Object System.Collections.Generic.List[string]
$lower = $Command.ToLowerInvariant()
$destructive = $lower -match '(^|[\s;|&])(remove-item|rm|del|erase|rd|rmdir|clear-content|format|format-volume|move-item|mv|move)([\s;|&]|$)'
$recursive = $lower -match '(-recurse\b|/s\b|/q\b|-rf\b|-fr\b)'
$hasWildcard = $Command -match '[*?]'
$hasVariablePath = $Command -match '(\$env:|\$home\b|\$userprofile\b|%userprofile%|%homepath%|%homedrive%)'
$hasTraversal = $Command -match '(^|[\\/])\.\.([\\/]|$)'

$absoluteMatches = [regex]::Matches($Command, '(?i)[a-z]:\\[^\s"''|;&]*') | ForEach-Object { $_.Value.Trim('"', '''', ',', ')', ']') }
$quotedMatches = [regex]::Matches($Command, '(["''])(?<path>[^"'']+)\1') | ForEach-Object { $_.Groups['path'].Value }
$targets = @(@($absoluteMatches) + @($quotedMatches))
$targets = @($targets | Where-Object { $_ -and ($_ -notmatch '^[-/]') } | Sort-Object -Unique)

$classification = 'allow'
if ($destructive) {
  $classification = 'confirmation_required'
  if ($hasVariablePath) { $reasons.Add('Variable-based target path is not allowed for destructive commands.') }
  if ($hasWildcard) { $reasons.Add('Wildcard target is not allowed for destructive commands.') }
  if ($hasTraversal) { $reasons.Add('Parent-directory traversal is not allowed for destructive commands.') }
  if ($targets.Count -eq 0) { $reasons.Add('Destructive command needs an explicit literal target path.') }

  foreach ($target in $targets) {
    $candidate = if ([System.IO.Path]::IsPathRooted($target)) { $target } else { Join-Path $projectRoot $target }
    try {
      $resolved = [System.IO.Path]::GetFullPath($candidate)
    } catch {
      $reasons.Add("Target path cannot be resolved: $target")
      continue
    }
    if ($resolved -match '^[A-Za-z]:\\?$') {
      $reasons.Add("Disk root is forbidden: $resolved")
      continue
    }
    if (-not (Test-PathWithin $resolved $projectRoot)) {
      $reasons.Add("Target is outside the workspace: $resolved")
      continue
    }
    if ($recursive -and -not (@($allowedCleanupScopes | Where-Object { Test-PathWithin $resolved $_ }).Count -gt 0)) {
      $reasons.Add("Recursive operation is limited to approved runtime scopes: $resolved")
    }
  }
  if ($reasons.Count -gt 0) { $classification = 'deny' }
}

$result = [PSCustomObject]@{
  classification = $classification
  destructive = $destructive
  recursive = $recursive
  targets = $targets
  workspace = $projectRoot
  allowed_cleanup_scopes = $allowedCleanupScopes
  reasons = @($reasons)
  required_action = switch ($classification) {
    'allow' { 'may_continue' }
    'confirmation_required' { 'show_absolute_targets_and_wait_for_explicit_second_confirmation' }
    'deny' { 'do_not_execute' }
  }
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 5
} else {
  Write-Host "Command safety: $($result.classification)"
  foreach ($reason in $result.reasons) { Write-Host "- $reason" }
}

if (-not $NoExit) {
  if ($classification -eq 'confirmation_required') { exit 10 }
  if ($classification -eq 'deny') { exit 20 }
}
