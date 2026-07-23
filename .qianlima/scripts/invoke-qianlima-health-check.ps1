<##
.SYNOPSIS
  Runs bounded Qianlima startup, background, or pre-L4 health checks.
.DESCRIPTION
  Explicitly invoked only. It reads local contracts and references, reports a
  degraded or blocked capability, and never starts a scheduler or external call.
##>
param(
  [Parameter(Mandatory = $true)] [ValidateSet('startup','background','pre_l4')] [string]$Mode,
  [string]$WorkflowId = '',
  [string]$ProjectScopePath = '',
  [string]$SourceRequestPath = '',
  [int]$MaxIndexAgeHours = 24,
  [string]$OutputPath = '',
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$healthRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\health-checks')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$checks = [System.Collections.Generic.List[object]]::new()
function Check([string]$Id, [bool]$Passed, [string]$Location, [string]$Recovery) { [void]$checks.Add([ordered]@{ check_id = $Id; passed = $Passed; location = $Location; recovery_hint = $Recovery }) }
function Read-JsonRef([string]$Path, [string]$Name) {
  $full = [IO.Path]::GetFullPath((Join-Path $root ($Path -replace '/', '\')))
  $prefix = [IO.Path]::GetFullPath($root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) { Check "$Name.exists" $false $Path 'Create or refresh the local reference.'; return $null }
  try { return (Get-Content -LiteralPath $full -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { Check "$Name.json" $false $Path 'Regenerate a valid JSON reference.'; return $null }
}
$required = @('.qianlima\WORKSPACE_INDEX.md','.qianlima\workflow-index.yaml','.qianlima\risk-rules.yaml','.qianlima\context-policy.yaml')
foreach ($file in $required) { Check "required:$file" (Test-Path -LiteralPath (Join-Path $root $file) -PathType Leaf) $file 'Restore the missing public-safe runtime file.' }
if ($WorkflowId) {
  $index = Join-Path $root '.qianlima\workflow-index.yaml'; $text = if (Test-Path -LiteralPath $index -PathType Leaf) { Get-Content -LiteralPath $index -Raw -Encoding UTF8 } else { '' }
  Check 'workflow.registered' ($text -match "(?m)^\s*-\s*id:\s*$([regex]::Escape($WorkflowId))\s*$") '.qianlima/workflow-index.yaml' 'Register the workflow before running it.'
}
if ($Mode -in @('background','pre_l4')) {
  $indexPath = Join-Path $root '.qianlima\WORKSPACE_INDEX.md'; $fresh = $false
  if (Test-Path -LiteralPath $indexPath -PathType Leaf) { $line = (Get-Content -LiteralPath $indexPath -Encoding UTF8 | Where-Object { $_ -match '^Generated at:' } | Select-Object -First 1); if ($line -match '^Generated at:\s*(.+)$') { try { $fresh = (([datetimeoffset]::Now - [datetimeoffset]::Parse($Matches[1])).TotalHours -le $MaxIndexAgeHours) } catch {} } }
  Check 'workspace_index.fresh' $fresh '.qianlima/WORKSPACE_INDEX.md' 'Regenerate the workspace index before the next non-trivial task.'
}
if ($Mode -eq 'pre_l4') {
  $scope = if ($ProjectScopePath) { Read-JsonRef $ProjectScopePath 'project_scope' } else { Check 'project_scope.provided' $false 'ProjectScopePath' 'Bind the task to a store, marketplace, brand, and product line.'; $null }
  if ($scope) { Check 'project_scope.safe' ($scope.network_access -eq $false -and $scope.business_write -eq $false -and -not [string]::IsNullOrWhiteSpace([string]$scope.store_id)) $ProjectScopePath 'Regenerate a read-only project scope.' }
  $request = if ($SourceRequestPath) { Read-JsonRef $SourceRequestPath 'source_request' } else { Check 'source_request.provided' $false 'SourceRequestPath' 'Create a bounded Service/Repository request.'; $null }
  if ($request) { Check 'source_request.read_only' ($request.access_mode -eq 'read_only' -and $request.network_access -eq $false -and $request.business_write -eq $false) $SourceRequestPath 'Use a selected-field, read-only source request.' }
}
$failed = @($checks | Where-Object { -not $_.passed })
$outcome = if ($failed.Count -eq 0) { 'passed' } elseif ($Mode -eq 'pre_l4') { 'blocked' } else { 'degraded' }
$capability = if ($outcome -eq 'passed') { 'normal' } elseif ($outcome -eq 'degraded') { 'read_only_limited' } else { 'no_high_impact_execution' }
$item = [ordered]@{ check_id = 'health-' + [Guid]::NewGuid().ToString('n'); mode = $Mode; workflow_id = $WorkflowId; checks = @($checks); failed_checks = @($failed.check_id); outcome = $outcome; capability = $capability; scheduler_started = $false; network_calls = $false; business_write = $false; created_at = (Get-Date).ToUniversalTime().ToString('o') }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $healthRoot "$($item.check_id).json" }
$fullOutput = [IO.Path]::GetFullPath($OutputPath); if (-not $fullOutput.StartsWith($healthRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputPath must remain under health-checks.' }
New-Item -ItemType Directory -Path (Split-Path -Parent $fullOutput) -Force | Out-Null
[IO.File]::WriteAllText($fullOutput, ($item | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
if ($PassThru) { $item | ConvertTo-Json -Depth 12 } else { Write-Host "Qianlima health check [$Mode]: $outcome" }
if ($outcome -eq 'blocked') { exit 1 }
