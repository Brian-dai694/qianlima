<#
.SYNOPSIS
Drive a Loop Engineering state machine (SDR / EVR / PBV / EDA) for a workflow run.
.DESCRIPTION
Manages a JSON loop-state file under .qianlima/run-traces. Start creates a new state
in the loop's first phase; Advance transitions phases based on the supplied Outcome,
incrementing the iteration counter on a retry outcome and freezing once MaxIterations
is reached; Status reports the current state. Every change appends a history entry.
Transitions are data-driven from a per-loop-type table that mirrors loop-engineering.yaml.
.PARAMETER WorkflowId
Lowercase workflow identifier used to name the run and state file.
.PARAMETER LoopType
Loop family to drive: SDR, EVR (default), PBV or EDA.
.PARAMETER Action
Operation to perform: Start, Advance or Status (default Status).
.PARAMETER Outcome
Transition trigger required for Advance (e.g. execute_complete, verify_pass, stop).
.PARAMETER MaxIterations
Maximum retry iterations before the loop freezes, 1-10 (default 3, or 2 for PBV).
.EXAMPLE
.\invoke-qianlima-loop.ps1 -WorkflowId daily_ad_report -LoopType EVR -Action Start
.EXAMPLE
.\invoke-qianlima-loop.ps1 -WorkflowId keyword_rank_scan -LoopType SDR -Action Start
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9][a-z0-9_-]*$')]
  [string]$WorkflowId,

  [ValidateSet('SDR', 'EVR', 'PBV', 'EDA')]
  [string]$LoopType = 'EVR',
  [ValidateSet('Start', 'Advance', 'Status')]
  [string]$Action = 'Status',
  [ValidateSet(
    'execute_complete', 'verify_pass', 'verify_issues', 'verify_critical', 'refine_complete',
    'scan_complete', 'doubt_complete', 'reconcile_ok', 'reconcile_blind_spots',
    'plan_ready', 'build_complete',
    'explore_complete', 'decide_ok', 'decide_low_confidence', 'act_complete', 'observe_complete',
    'stop')]
  [string]$Outcome = '',
  [string]$RunId = '',
  [ValidateRange(1, 10)]
  [int]$MaxIterations = 0,
  [string]$StatePath = '',
  [string]$Note = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceDirectory = Join-Path $projectRoot '.qianlima\run-traces'

# ── Loop definitions (mirror loop-engineering.yaml) ──────────────────────────
# Each loop: start phase, default max iterations, and a phase->outcome->action map.
# Action kinds: goto <phase> | done | fail | retry <phase> | stopped
$LoopDefs = @{
  SDR = @{
    start = 'scan'; maxIterations = 3
    transitions = @{
      scan      = @{ scan_complete = 'goto doubt'; stop = 'stopped' }
      doubt     = @{ doubt_complete = 'goto reconcile'; stop = 'stopped' }
      reconcile = @{ reconcile_ok = 'done'; reconcile_blind_spots = 'retry scan'; stop = 'stopped' }
    }
  }
  EVR = @{
    start = 'execute'; maxIterations = 3
    transitions = @{
      execute = @{ execute_complete = 'goto verify'; stop = 'stopped' }
      verify  = @{ verify_pass = 'done'; verify_critical = 'fail'; verify_issues = 'retry refine'; stop = 'stopped' }
      refine  = @{ refine_complete = 'goto verify'; stop = 'stopped' }
    }
  }
  PBV = @{
    start = 'plan'; maxIterations = 2
    transitions = @{
      plan   = @{ plan_ready = 'goto build'; stop = 'stopped' }
      build  = @{ build_complete = 'goto verify'; stop = 'stopped' }
      verify = @{ verify_pass = 'done'; verify_critical = 'fail'; verify_issues = 'retry plan'; stop = 'stopped' }
    }
  }
  EDA = @{
    start = 'explore'; maxIterations = 3
    transitions = @{
      explore = @{ explore_complete = 'goto decide'; stop = 'stopped' }
      decide  = @{ decide_ok = 'goto act'; decide_low_confidence = 'retry explore'; stop = 'stopped' }
      act     = @{ act_complete = 'goto observe'; stop = 'stopped' }
      observe = @{ observe_complete = 'done'; stop = 'stopped' }
    }
  }
}

$def = $LoopDefs[$LoopType]
if ($MaxIterations -le 0) { $MaxIterations = [int]$def.maxIterations }

if ([string]::IsNullOrWhiteSpace($RunId)) {
  $RunId = "$WorkflowId-$((Get-Date).ToString('yyyyMMdd-HHmmss-fff'))"
}
if ([string]::IsNullOrWhiteSpace($StatePath)) {
  $StatePath = Join-Path $traceDirectory "loop-$RunId.json"
}

function Save-State([object]$State) {
  $directory = Split-Path -Parent $StatePath
  if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($StatePath, ($State | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))
}

function Add-History([object]$State, [string]$Event) {
  $State.history += [PSCustomObject]@{
    at = (Get-Date).ToUniversalTime().ToString('o')
    state = $State.current_state
    event = $Event
    note = $Note
  }
  $State.updated_at = (Get-Date).ToUniversalTime().ToString('o')
}

if ($Action -eq 'Start') {
  if (Test-Path -LiteralPath $StatePath -PathType Leaf) {
    throw "Loop state already exists: $StatePath"
  }
  $state = [PSCustomObject]@{
    schema_version = 2
    run_id = $RunId
    workflow_id = $WorkflowId
    loop_type = $LoopType
    current_state = [string]$def.start
    status = 'running'
    iteration = 0
    max_iterations = $MaxIterations
    started_at = (Get-Date).ToUniversalTime().ToString('o')
    updated_at = (Get-Date).ToUniversalTime().ToString('o')
    history = @()
  }
  Add-History $state 'started'
  Save-State $state
} else {
  if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
    throw "Loop state not found: $StatePath"
  }
  $state = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
  $def = $LoopDefs[[string]$state.loop_type]
}

if ($Action -eq 'Advance') {
  if ([string]::IsNullOrWhiteSpace($Outcome)) {
    throw 'Advance requires an Outcome.'
  }
  if ($state.status -ne 'running') {
    throw "Loop is already terminal: $($state.status)"
  }

  $phase = [string]$state.current_state
  $phaseMap = $def.transitions[$phase]
  if (-not $phaseMap -or -not $phaseMap.ContainsKey($Outcome)) {
    throw "Outcome '$Outcome' is invalid from state '$phase' for loop $($state.loop_type)."
  }

  $parts = ($phaseMap[$Outcome] -split '\s+', 2)
  $kind = $parts[0]
  switch ($kind) {
    'goto'    { $state.current_state = $parts[1] }
    'done'    { $state.current_state = 'completed'; $state.status = 'completed' }
    'fail'    { $state.current_state = 'failed'; $state.status = 'failed' }
    'stopped' { $state.current_state = 'stopped'; $state.status = 'stopped' }
    'retry'   {
      if ([int]$state.iteration -ge [int]$state.max_iterations) {
        $state.current_state = 'frozen'; $state.status = 'frozen'
      } else {
        $state.iteration = [int]$state.iteration + 1
        $state.current_state = $parts[1]
      }
    }
    default   { throw "Unknown transition action: $kind" }
  }
  Add-History $state $Outcome
  Save-State $state
}

if ($PassThru) {
  [PSCustomObject]@{ StatePath = $StatePath; State = $state }
} else {
  Write-Host "Loop [$($state.loop_type)] state: $($state.current_state) / $($state.status) (iter $($state.iteration)/$($state.max_iterations))"
  Write-Host "Trace: $StatePath"
}
