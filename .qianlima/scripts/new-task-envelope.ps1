param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$ContextId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$ParentRunId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$AgentRef,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$WorkOrderRef,
  [Parameter(Mandatory = $true)] [string]$Goal,
  [string[]]$InputArtifactRef = @(),
  [string[]]$AllowedTool = @(),
  [Parameter(Mandatory = $true)] [string]$DataScope,
  [ValidateSet('L0', 'L1', 'L2', 'L3', 'L4')] [string]$RiskCeiling = 'L1',
  [int]$MaxSteps = 1,
  [int]$MaxToolCalls = 1,
  [int]$TimeoutMs = 30000,
  [string[]]$ExpectedArtifact = @(),
  [Parameter(Mandatory = $true)] [string]$VerificationOwner,
  [Parameter(Mandatory = $true)] [string]$PassCondition,
  [Parameter(Mandatory = $true)] [string[]]$StopCondition,
  [ValidateSet('none', 'allowlisted')] [string]$NetworkAccess = 'none',
  [ValidateSet('none', 'approved_scope')] [string]$WriteAccess = 'none',
  [switch]$RequiresConfirmation,
  [switch]$RollbackRequired,
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if ($MaxSteps -lt 1 -or $MaxToolCalls -lt 1 -or $TimeoutMs -lt 1) { throw 'Task budgets must be positive.' }
if ($InputArtifactRef.Count -eq 0 -or $ExpectedArtifact.Count -eq 0) { throw 'Task envelopes require input and expected artifact references.' }
if ($RiskCeiling -eq 'L4' -and (-not $RequiresConfirmation -or -not $RollbackRequired)) { throw 'L4 task envelopes require confirmation and rollback.' }
if ($NetworkAccess -ne 'none' -and $RiskCeiling -eq 'L4') { throw 'L4 task envelopes cannot grant network access.' }
function Test-SafeReference([string]$Value) {
  return -not ([IO.Path]::IsPathRooted($Value) -or $Value -match '(^|[\\/])\.\.([\\/]|$)')
}
foreach ($reference in @($InputArtifactRef) + @($ExpectedArtifact)) { if (-not (Test-SafeReference $reference)) { throw "Unsafe artifact reference: $reference" } }
$forbidden = @('api_key', 'access_token', 'refresh_token', 'password', 'cookie', 'authorization:')
foreach ($value in @($Goal, $DataScope, $VerificationOwner, $PassCondition) + @($InputArtifactRef) + @($ExpectedArtifact) + @($StopCondition)) {
  foreach ($needle in $forbidden) { if ($value -match [regex]::Escape($needle)) { throw 'Task envelopes cannot contain secrets or authorization material.' } }
}
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cardPath = Join-Path $PSScriptRoot '..\agent-cards.yaml'
$cardPattern = "(?m)^\s*- id:\s*$([regex]::Escape($AgentRef))\s*$"
if (-not (Select-String -LiteralPath $cardPath -Pattern $cardPattern -Quiet)) { throw "Unknown Agent Card: $AgentRef" }
$envelopeRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\task-envelopes')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $envelopeRoot "$TaskId.json" }
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFullPath.StartsWith($envelopeRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Task envelopes must be written under .qianlima/run-traces/task-envelopes.' }
if (Test-Path -LiteralPath $outputFullPath) { throw "Task envelope already exists; create a new task_id for revisions: $TaskId" }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputFullPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $outputFullPath) -Force | Out-Null }
$envelope = [ordered]@{
  schema_version = 1
  contract_type = 'qianlima_a2a_internal_task_envelope'
  protocol_target = 'A2A 1.0 semantics'
  context_id = $ContextId
  task_id = $TaskId
  parent_run_id = $ParentRunId
  work_order_ref = $WorkOrderRef
  agent_ref = $AgentRef
  goal = $Goal
  input_refs = @($InputArtifactRef)
  delegation = [ordered]@{
    risk_ceiling = $RiskCeiling
    allowed_tools = @($AllowedTool)
    data_scope = $DataScope
    budget = [ordered]@{ max_steps = $MaxSteps; max_tool_calls = $MaxToolCalls; timeout_ms = $TimeoutMs }
    network_access = $NetworkAccess
    write_access = $WriteAccess
    requires_confirmation = [bool]$RequiresConfirmation
    rollback_required = [bool]$RollbackRequired
  }
  expected_artifacts = @($ExpectedArtifact)
  verification = [ordered]@{ owner = $VerificationOwner; pass_condition = $PassCondition }
  stop_conditions = @($StopCondition)
  status = 'submitted'
  terminal_task_immutable = $true
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($outputFullPath, ($envelope | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
if ($PassThru) { $envelope | ConvertTo-Json -Depth 10 } else { Write-Host "Task envelope created: $outputFullPath" }
