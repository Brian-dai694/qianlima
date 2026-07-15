<#
.SYNOPSIS
  Evaluate and update a task contract's state and delivery mode.
.DESCRIPTION
  Loads working\task-contract-<RequestId>.json, compares now against its deadline, and
  checks the control flag. Cancels, freezes, or leaves the contract running accordingly,
  stamps last_checked_at, and writes it back. Returns whether external reads may continue
  plus the delivery mode and pending checks. Throws on an unsafe RequestId or missing file.
.PARAMETER RequestId
  Short file-safe id identifying the task contract.
.PARAMETER Root
  Path to the .qianlima root; defaults to the script's parent when empty.
.EXAMPLE
  .\check-task-contract.ps1 -RequestId req-2026-0713-01 -Json
#>
param(
  [Parameter(Mandatory)]
  [string]$RequestId,
  [string]$Root = '',
  [switch]$Json
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
$now = [datetimeoffset]::Now
$deadline = [datetimeoffset]::Parse($contract.deadline_at)
$timedOut = $now -gt $deadline
$controlStopsDeepDive = $contract.control -in @('conclusion_only', 'stop_deep_dive', 'cancel')

if ($contract.control -eq 'cancel') {
  $contract.state = 'cancelled'
} elseif ($timedOut -or $controlStopsDeepDive) {
  if ($contract.state -notin @('completed', 'cancelled')) {
    $contract.state = 'frozen'
  }
}
$contract | Add-Member -NotePropertyName last_checked_at -NotePropertyValue $now.ToString('o') -Force
$contract | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8

$result = [PSCustomObject]@{
  request_id = $contract.request_id
  state = $contract.state
  control = $contract.control
  timed_out = $timedOut
  continue_external_reads = -not $timedOut -and -not $controlStopsDeepDive -and $contract.state -notin @('completed', 'cancelled', 'frozen')
  delivery_mode = if ($contract.state -eq 'cancelled') { 'cancelled' } elseif ($contract.state -eq 'frozen') { 'conclusion_only_with_pending_checks' } else { 'continue' }
  pending_checks = [object[]]@($contract.pending_checks)
}

if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $result | Format-List }
