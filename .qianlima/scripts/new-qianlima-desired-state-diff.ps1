<##
.SYNOPSIS
  Creates a reviewable Qianlima current-state versus desired-state diff.
.DESCRIPTION
  This script compares small structured JSON objects. It never calls a business
  system and never executes candidate actions.
##>
param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')] [string]$DiffId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [string]$Workflow,
  [Parameter(Mandatory = $true)] [string]$CurrentStatePath,
  [Parameter(Mandatory = $true)] [string]$DesiredStatePath,
  [Parameter(Mandatory = $true)] [string[]]$SourceRef,
  [Parameter(Mandatory = $true)] [string]$DataTimeRange,
  [string[]]$FormulaRef = @(),
  [string]$OutputPath = '',
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\state-diffs')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
function Resolve-WorkspaceFile([string]$Path) {
  $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
  $full = [IO.Path]::GetFullPath([string]$resolved.Path)
  $prefix = [IO.Path]::GetFullPath($root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Input paths must remain inside the Qianlima workspace.' }
  return $full
}
function Read-Object([string]$Path) { $full = Resolve-WorkspaceFile $Path; try { return (Get-Content -LiteralPath $full -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { throw "Invalid JSON input: $Path" } }
function Get-Map($Object) { $map = @{}; foreach ($property in $Object.PSObject.Properties) { $map[$property.Name] = $property.Value }; return $map }
$current = Read-Object $CurrentStatePath
$desired = Read-Object $DesiredStatePath
$currentMap = Get-Map $current
$desiredMap = Get-Map $desired
$keys = @($currentMap.Keys + $desiredMap.Keys | Sort-Object -Unique)
$differences = @()
foreach ($key in $keys) {
  $hasCurrent = $currentMap.ContainsKey($key); $hasDesired = $desiredMap.ContainsKey($key)
  $currentValue = if ($hasCurrent) { $currentMap[$key] } else { $null }
  $desiredValue = if ($hasDesired) { $desiredMap[$key] } else { $null }
  $currentJson = $currentValue | ConvertTo-Json -Depth 8 -Compress
  $desiredJson = $desiredValue | ConvertTo-Json -Depth 8 -Compress
  if ($currentJson -ne $desiredJson) { $differences += [ordered]@{ field = $key; current = $currentValue; desired = $desiredValue; change = if (-not $hasCurrent) { 'add' } elseif (-not $hasDesired) { 'remove' } else { 'change' } } }
}
$candidateActions = @($differences | ForEach-Object { [ordered]@{ action_id = 'review-' + $_.field; action_class = 'diagnose'; target_field = $_.field; status = 'candidate'; execution = 'not_started' } })
$status = if ($differences.Count -eq 0) { 'verified' } else { 'candidate' }
$item = [ordered]@{ diff_id = $DiffId; task_id = $TaskId; workflow = $Workflow; current_state = $current; desired_state = $desired; differences = @($differences); candidate_actions = @($candidateActions); source_refs = @($SourceRef); data_time_range = $DataTimeRange; formula_refs = @($FormulaRef); pending_verification = if ($differences.Count -eq 0) { @() } else { @('candidate_actions_require_business_verification') }; status = $status; execution = [ordered]@{ external_calls = $false; business_write = $false; network_access = $false; source_overwrite = $false; deleted = $false }; created_at = (Get-Date).ToUniversalTime().ToString('o') }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $traceRoot "$DiffId.json" }
$fullOutput = [IO.Path]::GetFullPath($OutputPath)
if (-not $fullOutput.StartsWith($traceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputPath must remain under .qianlima/run-traces/state-diffs.' }
if (Test-Path -LiteralPath $fullOutput) { throw "Diff already exists: $DiffId" }
New-Item -ItemType Directory -Path (Split-Path -Parent $fullOutput) -Force | Out-Null
[IO.File]::WriteAllText($fullOutput, ($item | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
if ($PassThru) { $item | ConvertTo-Json -Depth 12 } else { Write-Host "Qianlima desired-state diff created: $fullOutput" }
