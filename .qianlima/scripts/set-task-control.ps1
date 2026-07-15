<#
.SYNOPSIS
Updates the control signal on an existing task contract.
.DESCRIPTION
Loads working/task-contract-<RequestId>.json, sets its control field, and
stamps control_updated_at. Certain controls also change state: conclusion_only
and stop_deep_dive freeze the task, cancel marks it cancelled, and report moves
it to decision_delivery. Throws if the RequestId is unsafe or the file is absent.
.PARAMETER RequestId
Short file-safe identifier for the task contract to update.
.PARAMETER Control
The control signal: continue, conclusion_only, stop_deep_dive, report, or cancel.
.PARAMETER Root
Workspace root; defaults to the parent of the scripts directory.
.EXAMPLE
.\set-task-control.ps1 -RequestId run-2026-07-13 -Control stop_deep_dive
#>
param(
  [Parameter(Mandatory)]
  [string]$RequestId,
  [ValidateSet('continue', 'conclusion_only', 'stop_deep_dive', 'report', 'cancel')]
  [string]$Control,
  [string]$Root = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
if ($RequestId -match '[\\/:*?"<>|]' -or $RequestId.Length -gt 80) {
  throw 'RequestId must be a short file-safe identifier.'
}

$path = Join-Path (Join-Path $Root 'working') "task-contract-$RequestId.json"
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
  throw "Task contract not found: $path"
}

$contract = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
$contract.control = $Control
$contract | Add-Member -NotePropertyName control_updated_at -NotePropertyValue (Get-Date).ToString('o') -Force
switch ($Control) {
  'conclusion_only' { $contract.state = 'frozen' }
  'stop_deep_dive' { $contract.state = 'frozen' }
  'cancel' { $contract.state = 'cancelled' }
  'report' { $contract.state = 'decision_delivery' }
}
$contract | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "Task control updated: $Control"
