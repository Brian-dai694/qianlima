<##
.SYNOPSIS
  Drives the Qianlima Execute-Verify-Revise state machine.
.DESCRIPTION
  This is a local workflow state manager. It does not start a process, call a
  network, or grant a tool. Worker outputs must be written as step results by
  a separately allowed deterministic runner.
##>
param(
  [Parameter(Mandatory = $true)] [ValidateSet('execute', 'verify', 'revise', 'stop', 'status')] [string]$Action,
  [Parameter(Mandatory = $true)] [string]$PlanPath,
  [string]$RevisionPlanPath = '',
  [int]$MaxRevisions = 3,
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$planRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\execution-plans')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$planResolved = Resolve-Path -LiteralPath $PlanPath -ErrorAction Stop
$planFull = [IO.Path]::GetFullPath([string]$planResolved.Path)
if (-not $planFull.StartsWith($planRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'PlanPath must be inside execution-plans.' }
$plan = Get-Content -LiteralPath $planFull -Raw -Encoding UTF8 | ConvertFrom-Json
$eventRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\evr')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$eventPath = Join-Path $eventRoot "$($plan.plan_id).jsonl"
$resultRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\step-results')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
function Get-Events { if (-not (Test-Path -LiteralPath $eventPath -PathType Leaf)) { return @() }; return @(Get-Content -LiteralPath $eventPath -Encoding UTF8 | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json }) }
function Get-State($Events) {
  $items = @($Events | Where-Object { $null -ne $_ -and $_.PSObject.Properties['to_state'] })
  if ($items.Count -eq 0) { return 'planned' }
  $last = $items[$items.Count - 1]
  if ($null -eq $last -or [string]::IsNullOrWhiteSpace([string]$last.to_state)) { return 'planned' }
  return [string]$last.to_state
}
function Add-Event([string]$From, [string]$To, [string]$Reason = '', [string[]]$Refs = @(), [string]$NextPlan = '') {
  New-Item -ItemType Directory -Path $eventRoot -Force | Out-Null
  $item = [ordered]@{ event_id = 'evr-' + [Guid]::NewGuid().ToString('n'); recorded_at = (Get-Date).ToUniversalTime().ToString('o'); plan_id = [string]$plan.plan_id; task_id = [string]$plan.task_id; action = $Action; from_state = $From; to_state = $To; reason = $Reason; result_refs = @($Refs); next_plan_ref = if ($NextPlan) { $NextPlan } else { $null }; external_calls = $false; network_access = $false }
  [IO.File]::AppendAllText($eventPath, (($item | ConvertTo-Json -Depth 10 -Compress) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
  return $item
}
$events = Get-Events
$state = Get-State $events
if ($Action -eq 'status') { $output = [ordered]@{ status = 'ok'; plan_id = $plan.plan_id; task_id = $plan.task_id; state = $state; event_log = '.qianlima/run-traces/evr/' + $plan.plan_id + '.jsonl'; external_calls = $false }; if ($PassThru) { $output | ConvertTo-Json -Depth 10 } else { $output | Format-List }; exit 0 }
if ($MaxRevisions -lt 1 -or $MaxRevisions -gt 3) { throw 'MaxRevisions must be between 1 and 3.' }
$to = $null; $reason = ''; $refs = @(); $next = ''
switch ($Action) {
  'execute' { if ($state -notin @('planned', 'revised')) { throw "Execute requires planned or revised state; current state is $state." }; $to = 'executing' }
  'verify' {
    if ($state -ne 'executing') { throw "Verify requires executing state; current state is $state." }
    $stepIds = @($plan.steps | ForEach-Object { [string]$_.step_id })
    $results = @(Get-ChildItem -LiteralPath $resultRoot -File -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object { try { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} } | Where-Object { $_.plan_id -eq $plan.plan_id })
    $missing = @($stepIds | Where-Object { $id = $_; @($results | Where-Object { $_.step_id -eq $id }).Count -eq 0 })
    $bad = @($results | Where-Object { $_.step_status -in @('partial', 'failed', 'blocked') })
    $pending = @($results | ForEach-Object { @($_.pending_verification) } | Where-Object { $_ })
    $critical = @($results | ForEach-Object { @($_.warnings) } | Where-Object { $_ -match '(?i)(critical|budget_exhausted|source_scope_mismatch)' })
    $refs = @($results | ForEach-Object { $_.result_id })
    if ($critical.Count -gt 0) { $to = 'frozen'; $reason = 'Critical warning or budget/scope failure.' }
    elseif ($missing.Count -gt 0 -or $bad.Count -gt 0 -or $pending.Count -gt 0) { $to = 'revision_required'; $reason = 'Missing, partial, failed, or pending step verification.' }
    else { $to = 'completed'; $reason = 'All declared steps completed and verification inputs are present.' }
  }
  'revise' {
    if ($state -ne 'revision_required') { throw "Revise requires revision_required state; current state is $state." }
    if ([string]::IsNullOrWhiteSpace($RevisionPlanPath)) { throw 'RevisionPlanPath is required.' }
    $revisionResolved = Resolve-Path -LiteralPath $RevisionPlanPath -ErrorAction Stop
    $revisionFull = [IO.Path]::GetFullPath([string]$revisionResolved.Path)
    if (-not $revisionFull.StartsWith($planRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Revision plan must be inside execution-plans.' }
    $revision = Get-Content -LiteralPath $revisionFull -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$revision.plan_id -eq [string]$plan.plan_id) { throw 'Revision must create a new plan_id.' }
    $revisionCount = @($events | Where-Object { $_.action -eq 'revise' }).Count
    if ($revisionCount -ge $MaxRevisions) { throw 'Maximum EVR revisions reached; freeze or stop the task.' }
    $to = 'revised'; $next = '.qianlima/run-traces/execution-plans/' + [IO.Path]::GetFileName($revisionFull); $reason = 'New plan references the prior plan and addresses verification gaps.'
  }
  'stop' { if ($state -in @('completed', 'stopped', 'frozen')) { throw "Cannot stop terminal state: $state." }; $to = 'stopped'; $reason = 'Stopped by the local workflow controller.' }
}
$event = Add-Event $state $to $reason $refs $next
$output = [ordered]@{ status = 'accepted'; plan_id = $plan.plan_id; task_id = $plan.task_id; state = $to; event_id = $event.event_id; reason = $reason; external_calls = $false; network_access = $false }
if ($PassThru) { $output | ConvertTo-Json -Depth 10 } else { $output | Format-List }
