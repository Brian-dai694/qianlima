<##
.SYNOPSIS
  Validates a sanitized Overlay Trace Envelope and injected failure state.
.DESCRIPTION
  This validator does not read provider credentials or raw business artifacts.
  It checks lineage, versions, budget, failure handling, and terminal status.
##>
param(
  [Parameter(Mandatory = $true)] [string]$TracePath,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$specRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\specifications')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$traceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$contract = Get-Content -LiteralPath (Join-Path $projectRoot '.qianlima\specifications\trace-contract.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$resolved = Resolve-Path -LiteralPath $TracePath -ErrorAction Stop
$fullPath = [string]$resolved.Path
if (-not $fullPath.StartsWith($specRoot, [StringComparison]::OrdinalIgnoreCase) -and -not $fullPath.StartsWith($traceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Trace must be inside specifications or run-traces.' }
$trace = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8 | ConvertFrom-Json
$violations = [System.Collections.Generic.List[string]]::new()
function Add-Violation([string]$Id) { [void]$violations.Add($Id) }
function Has-Value($Object, [string]$Name) {
  if ($null -eq $Object) { return $false }
  $property = @($Object.PSObject.Properties | Where-Object { $_.Name -eq $Name }) | Select-Object -First 1
  if ($null -eq $property -or $null -eq $property.Value) { return $false }
  if ($property.Value -is [string]) { return -not [string]::IsNullOrWhiteSpace([string]$property.Value) }
  return $true
}
function Same([string]$Left, [string]$Right) { return [string]::Equals($Left, $Right, [StringComparison]::Ordinal) }

foreach ($field in @($contract.required_fields)) { if (-not (Has-Value $trace $field)) { Add-Violation "missing_$field" } }
if (Has-Value $trace 'terminal_status') {
  $terminal = [string]$trace.terminal_status
  if (@($contract.terminal_statuses).IndexOf($terminal) -lt 0) { Add-Violation 'invalid_terminal_status' }
}
if (Has-Value $trace 'budget_snapshot') {
  foreach ($field in @('max_steps','max_tool_calls','timeout_ms')) { if (-not (Has-Value $trace.budget_snapshot $field) -or [int]$trace.budget_snapshot.$field -lt 1) { Add-Violation "invalid_budget_$field" } }
  if ((Has-Value $trace.budget_snapshot 'steps_used') -and [int]$trace.budget_snapshot.steps_used -gt [int]$trace.budget_snapshot.max_steps) { Add-Violation 'budget_exceeded_steps' }
  if ((Has-Value $trace.budget_snapshot 'tool_calls_used') -and [int]$trace.budget_snapshot.tool_calls_used -gt [int]$trace.budget_snapshot.max_tool_calls) { Add-Violation 'budget_exceeded_tool_calls' }
}
$linked = @()
if ($null -ne $trace.linked_contracts) { $linked = @($trace.linked_contracts) }
foreach ($item in $linked) {
  if (-not (Same ([string]$item.trace_id) ([string]$trace.trace_id))) { Add-Violation 'linked_trace_id_mismatch' }
  if (-not (Same ([string]$item.task_id) ([string]$trace.task_id))) { Add-Violation 'linked_task_id_mismatch' }
  if (-not (Same ([string]$item.agent_id) ([string]$trace.agent_id))) { Add-Violation 'linked_agent_id_mismatch' }
}
if ((Has-Value $trace 'approved_agent_version') -and -not (Same ([string]$trace.agent_version) ([string]$trace.approved_agent_version))) { Add-Violation 'version_drift' }
if (Has-Value $trace 'events') {
  foreach ($event in @($trace.events)) {
    foreach ($field in @($contract.prohibited_fields)) { if ($null -ne $event.PSObject.Properties[$field]) { Add-Violation "prohibited_event_field_$field" } }
  }
}
if (Has-Value $trace 'failure_scenario') {
  $scenario = [string]$trace.failure_scenario
  if (-not $contract.failure_actions.PSObject.Properties[$scenario]) { Add-Violation 'unknown_failure_scenario' }
  else {
    $expected = [string]$contract.failure_actions.$scenario
    if ((-not (Has-Value $trace 'failure_action')) -or -not (Same ([string]$trace.failure_action) $expected)) { Add-Violation "failure_action_mismatch_$scenario" }
    if ($scenario -eq 'artifact_hash_mismatch' -and [string]$trace.artifact_status -ne 'rejected') { Add-Violation 'artifact_mismatch_not_rejected' }
    if ($scenario -eq 'verification_conflict' -and [string]$trace.terminal_status -notin @('frozen','partial','failed')) { Add-Violation 'verification_conflict_not_frozen' }
    if ($scenario -eq 'budget_exceeded' -and [string]$trace.terminal_status -notin @('frozen','failed','rejected')) { Add-Violation 'budget_failure_not_frozen' }
    if ($scenario -eq 'cancelled_downstream' -and [int]$trace.pending_downstream -gt 0) { Add-Violation 'cancelled_downstream_still_runnable' }
  }
}
$status = if ($violations.Count -eq 0) { 'passed' } else { 'blocked' }
$audit = Join-Path $PSScriptRoot 'write-audit-event.ps1'
$decision = if ($status -eq 'passed') { 'complete' } else { 'freeze' }
& $audit -EventType trace_validated -Decision $decision -TaskId ([string]$trace.task_id) -AgentId ([string]$trace.agent_id) -Reason "Overlay trace validation status: $status; raw prompt and secret values excluded." 6>$null | Out-Null
$result = [ordered]@{ status=$status; trace_id=$trace.trace_id; task_id=$trace.task_id; terminal_status=$trace.terminal_status; failure_scenario=if(Has-Value $trace 'failure_scenario'){$trace.failure_scenario}else{$null}; violations=@($violations); revoke_required=($violations.Count -gt 0); raw_content_recorded=$false }
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List }
if ($status -ne 'passed') { exit 1 }
