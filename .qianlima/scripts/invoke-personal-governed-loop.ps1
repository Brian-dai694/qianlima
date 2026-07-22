<##
.SYNOPSIS
  Drives the personal Builder -> Checker -> Qianlima governed loop.
.DESCRIPTION
  This is a local state machine, not an Agent executor. It records bounded
  outcomes, preserves checker bytes without interpreting them, and freezes on
  regression, repeated failure, no progress, timeout, or boundary violations.
  It never grants tools, starts a background worker, opens a network connection,
  or writes business data.
##>
param(
  [Parameter(Mandatory = $true)] [ValidateSet('Start', 'Check', 'Status', 'Stop')] [string]$Action,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{1,79}$')] [string]$TaskId,
  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{1,79}$')] [string]$RunId = '',
  [ValidateRange(1, 5)] [int]$MaxRounds = 5,
  [ValidateSet('all_green', 'check_failed', 'same_failure', 'regression', 'no_progress', 'boundary_exceeded', 'timeout', 'user_cancel')] [string]$Outcome = '',
  [string]$CheckerOutputPath = '',
  [string]$FailureSignature = '',
  [string]$StatePath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($RunId)) { $RunId = "$TaskId-$((Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss-fff'))" }
if ([string]::IsNullOrWhiteSpace($StatePath)) { $StatePath = Join-Path $traceRoot "personal-loop-$RunId.json" }
$stateFullPath = [IO.Path]::GetFullPath($StatePath)
if (-not $stateFullPath.StartsWith($traceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Personal loop state must stay under .qianlima/run-traces.' }

function Read-Json([string]$Path) { return ([IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json) }
function Save-State($State) {
  $directory = Split-Path -Parent $stateFullPath
  if (-not (Test-Path -LiteralPath $directory -PathType Container)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
  [IO.File]::WriteAllText($stateFullPath, ($State | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
}
function Add-History($State, [string]$Event, [string]$OutcomeValue = '', [string]$CheckerRef = '', [string]$CheckerHash = '') {
  $State.history = @($State.history) + [PSCustomObject]@{ at = (Get-Date).ToUniversalTime().ToString('o'); round = [int]$State.round; phase = [string]$State.phase; event = $Event; outcome = if ($OutcomeValue) { $OutcomeValue } else { $null }; checker_output_ref = if ($CheckerRef) { $CheckerRef } else { $null }; checker_output_hash = if ($CheckerHash) { $CheckerHash } else { $null } }
  $State.updated_at = (Get-Date).ToUniversalTime().ToString('o')
}
function Get-Result($State) {
  return [ordered]@{ schema_version = 1; run_id = $State.run_id; task_id = $State.task_id; phase = $State.phase; status = $State.status; round = $State.round; max_rounds = $State.max_rounds; same_failure_count = $State.same_failure_count; no_progress_count = $State.no_progress_count; stop_reason = $State.stop_reason; checker_output_ref = $State.checker_output_ref; checker_output_hash = $State.checker_output_hash; state_path = $stateFullPath; network_access = 'none'; business_write_access = 'none'; direct_agent_to_agent = $false }
}
function Resolve-InputFile([string]$Path) {
  $full = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  $workingRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\working')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($traceRoot, [StringComparison]::OrdinalIgnoreCase) -and -not $full.StartsWith($workingRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Checker output must stay under .qianlima/run-traces or .qianlima/working.' }
  return $full
}
function Save-CheckerBytes([string]$InputPath, [int]$Round) {
  if ([string]::IsNullOrWhiteSpace($InputPath)) { return [PSCustomObject]@{ reference = ''; hash = '' } }
  $inputFull = Resolve-InputFile $InputPath
  $outputDirectory = Join-Path $traceRoot "personal-loop-$RunId"
  if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
  $outputPath = Join-Path $outputDirectory "checker-$Round.txt"
  if (Test-Path -LiteralPath $outputPath) { throw 'Checker output trace is immutable; use a new round.' }
  $bytes = [IO.File]::ReadAllBytes($inputFull)
  [IO.File]::WriteAllBytes($outputPath, $bytes)
  $hash = 'sha256:' + (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
  return [PSCustomObject]@{ reference = ('run-traces/personal-loop-{0}/checker-{1}.txt' -f $RunId, $Round); hash = $hash }
}

if ($Action -eq 'Start') {
  if (Test-Path -LiteralPath $stateFullPath -PathType Leaf) { throw "Personal governed loop already exists: $stateFullPath" }
  $state = [PSCustomObject]@{
    schema_version = 1; loop_id = 'personal_builder_checker_loop'; run_id = $RunId; task_id = $TaskId
    phase = 'builder'; status = 'running'; round = 0; max_rounds = $MaxRounds; same_failure_count = 0; no_progress_count = 0
    stop_reason = $null; checker_output_ref = ''; checker_output_hash = ''; network_access = 'none'; business_write_access = 'none'; direct_agent_to_agent = $false
    role_boundary = [ordered]@{ builder = 'task_selected_scope_only'; checker = 'read_only_with_trace_output'; orchestrator = 'raw_result_forward_only'; qianlima = 'final_accept_freeze_stop' }
    history = @(); started_at = (Get-Date).ToUniversalTime().ToString('o'); updated_at = (Get-Date).ToUniversalTime().ToString('o')
  }
  Add-History $state 'started'
  Save-State $state
} elseif (-not (Test-Path -LiteralPath $stateFullPath -PathType Leaf)) {
  throw "Personal governed loop state not found: $stateFullPath"
} else {
  $state = Read-Json $stateFullPath
}

if ($Action -eq 'Check') {
  if ([string]::IsNullOrWhiteSpace($Outcome)) { throw 'Check requires an Outcome.' }
  if ($state.status -ne 'running') { throw "Personal governed loop is already terminal: $($state.status)" }
  $round = [int]$state.round + 1
  $checker = Save-CheckerBytes $CheckerOutputPath $round
  $state.round = $round
  $state.checker_output_ref = $checker.reference
  $state.checker_output_hash = $checker.hash
  if ($Outcome -eq 'all_green') {
    $state.phase = 'completed'; $state.status = 'completed'; $state.stop_reason = 'all_green'
  } elseif ($Outcome -eq 'user_cancel') {
    $state.phase = 'stopped'; $state.status = 'stopped'; $state.stop_reason = 'user_cancel'
  } elseif ($Outcome -in @('regression', 'boundary_exceeded', 'timeout')) {
    $state.phase = 'frozen'; $state.status = 'frozen'; $state.stop_reason = $Outcome
  } elseif ($Outcome -eq 'same_failure') {
    $state.same_failure_count = [int]$state.same_failure_count + 1
    if ($state.same_failure_count -ge 2) { $state.phase = 'frozen'; $state.status = 'frozen'; $state.stop_reason = 'same_failure_twice' } else { $state.phase = 'builder' }
  } elseif ($Outcome -eq 'no_progress') {
    $state.no_progress_count = [int]$state.no_progress_count + 1
    if ($state.no_progress_count -ge 2) { $state.phase = 'frozen'; $state.status = 'frozen'; $state.stop_reason = 'no_progress_twice' } else { $state.phase = 'builder' }
  } else {
    $state.same_failure_count = 0; $state.no_progress_count = 0
    if ($round -ge [int]$state.max_rounds) { $state.phase = 'frozen'; $state.status = 'frozen'; $state.stop_reason = 'max_rounds' } else { $state.phase = 'builder' }
  }
  Add-History $state 'checker_recorded' $Outcome $checker.reference $checker.hash
  Save-State $state
} elseif ($Action -eq 'Stop') {
  if ($state.status -eq 'running') { $state.phase = 'stopped'; $state.status = 'stopped'; $state.stop_reason = 'user_stop'; Add-History $state 'user_stopped'; Save-State $state }
}

$result = Get-Result $state
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List }
