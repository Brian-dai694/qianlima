<##
.SYNOPSIS
  Static-only security scan for a personal Skill before installation.
.DESCRIPTION
  Reads files and detects permission/risk signals. It never executes Skill code,
  opens a network connection, loads a module, or writes outside the report.
##>
param(
  [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$SkillPath,
  [string]$PolicyPath = '',
  [string]$ReportPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if ([string]::IsNullOrWhiteSpace($PolicyPath)) { $PolicyPath = Join-Path $projectRoot '.qianlima\specifications\personal-skill-install-policy.json' }
$policy = Get-Content -LiteralPath $PolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json
$skillFullPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SkillPath -ErrorAction Stop).Path)
if (-not (Test-Path -LiteralPath $skillFullPath -PathType Container)) { throw 'SkillPath must be a directory.' }
$scriptExtensions = @('.ps1', '.psm1', '.sh', '.bash', '.py', '.js', '.ts', '.cmd', '.bat', '.vbs', '.rb', '.pl')
$files = @(Get-ChildItem -LiteralPath $skillFullPath -Recurse -File -Force | Where-Object { $_.Name -notin @('.git', '.DS_Store') })
$findings = [System.Collections.Generic.List[object]]::new()
$scriptCount = @($files | Where-Object { $_.Extension.ToLowerInvariant() -in $scriptExtensions }).Count
function Add-Finding([string]$Category, [string]$Signal, [string]$Path, [string]$Severity) { $findings.Add([PSCustomObject]@{ category = $Category; signal = $Signal; path = $Path; severity = $Severity }) }
foreach ($file in $files) {
  $relative = $file.FullName.Substring($skillFullPath.Length).TrimStart('\', '/')
  if ($file.Length -gt 2097152) { Add-Finding 'file_size' 'file_over_2mb' $relative 'medium'; continue }
  try { $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 } catch { Add-Finding 'file_read' 'unreadable_file' $relative 'high'; continue }
  foreach ($property in @($policy.red_flags.PSObject.Properties)) {
    foreach ($signal in @($property.Value)) {
      if ($content.IndexOf([string]$signal, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $severity = if (@($policy.risk_escalators.high) -contains $property.Name) { 'high' } elseif (@($policy.risk_escalators.medium) -contains $property.Name) { 'medium' } else { 'medium' }
        Add-Finding $property.Name ([string]$signal) $relative $severity
      }
    }
  }
}
if ($scriptCount -gt 0) { Add-Finding 'script' 'executable_script_present' '<skill-root>' 'medium' }
$uniqueFindings = @($findings | Sort-Object category, signal, path -Unique)
$highCount = @($uniqueFindings | Where-Object { $_.severity -eq 'high' }).Count
$mediumCount = @($uniqueFindings | Where-Object { $_.severity -eq 'medium' }).Count
$riskBand = if ($highCount -gt 0) { 'high' } elseif ($mediumCount -gt 0) { 'medium' } else { 'low' }
$verdict = switch ($riskBand) { 'low' { 'checked_restricted_install' } 'medium' { 'risk_needs_confirmation' } default { 'high_risk_not_recommended' } }
$result = [ordered]@{
  schema_version = 1
  scan_id = 'skill-scan-' + [Guid]::NewGuid().ToString('n')
  skill_path = $skillFullPath
  files_scanned = $files.Count
  scripts_found = $scriptCount
  risk_band = $riskBand
  verdict = $verdict
  user_message_key = $verdict
  findings = $uniqueFindings
  restricted_install_contract = $policy.first_install_contract
  execution_performed = $false
  network_calls = $false
  personal_memory_written = $false
  scanned_at = (Get-Date).ToUniversalTime().ToString('o')
}
if (-not [string]::IsNullOrWhiteSpace($ReportPath)) { [IO.File]::WriteAllText([IO.Path]::GetFullPath($ReportPath), ($result | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false)) }
if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
