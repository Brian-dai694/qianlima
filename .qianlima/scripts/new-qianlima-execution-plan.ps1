<##
.SYNOPSIS
  Creates a bounded, read-only Qianlima Execution Plan.
##>
param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')] [string]$PlanId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{2,120}$')] [string]$Workflow,
  [Parameter(Mandatory = $true)] [string]$Goal,
  [Parameter(Mandatory = $true)] [string]$DataScope,
  [string]$StepsJson = '',
  [string]$StepsPath = '',
  [ValidateSet('L0', 'L1', 'L2', 'L3')] [string]$RiskLevel = 'L2',
  [int]$MaxSteps = 6,
  [int]$MaxToolCalls = 8,
  [int]$TimeoutMs = 120000,
  [string[]]$StopCondition = @('budget_exhausted', 'verification_failed', 'source_scope_mismatch'),
  [string]$OutputPath = '',
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$contract = Get-Content -LiteralPath (Join-Path $root '.qianlima\specifications\qianlima-execution-plan-contract.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($Goal) -or [string]::IsNullOrWhiteSpace($DataScope)) { throw 'Goal and DataScope are required.' }
if ($MaxSteps -lt 1 -or $MaxToolCalls -lt 1 -or $TimeoutMs -lt 1) { throw 'Plan budgets must be positive.' }
if ([string]::IsNullOrWhiteSpace($StepsJson) -and [string]::IsNullOrWhiteSpace($StepsPath)) { throw 'StepsJson or StepsPath is required.' }
$stepText = $StepsJson
if ($StepsPath) {
  $stepsResolved = Resolve-Path -LiteralPath $StepsPath -ErrorAction Stop
  $stepsFull = [IO.Path]::GetFullPath([string]$stepsResolved.Path)
  $rootPrefix = [IO.Path]::GetFullPath($root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $stepsFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'StepsPath must remain inside the Qianlima project workspace.' }
  $stepText = Get-Content -LiteralPath $stepsFull -Raw -Encoding UTF8
}
try { $steps = @($stepText | ConvertFrom-Json) } catch { throw 'StepsJson or StepsPath must contain valid JSON.' }
if ($steps.Count -eq 0) { throw 'At least one execution step is required.' }
if ($steps.Count -gt $MaxSteps) { throw 'Step count exceeds the plan budget.' }
$seen = @{}
foreach ($step in $steps) {
  foreach ($field in @('step_id', 'action', 'input_refs', 'allowed_tools', 'expected_output', 'verification')) {
    if ($null -eq $step.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace([string]$step.$field)) { throw "Step is missing required field: $field" }
  }
  if ([string]$step.step_id -notmatch '^[A-Za-z0-9._-]{2,120}$' -or $seen.ContainsKey([string]$step.step_id)) { throw 'Step ids must be unique and safe.' }
  $seen[[string]$step.step_id] = $true
  if (@($contract.allowed_step_actions) -notcontains [string]$step.action) { throw "Step action is not allowed: $($step.action)" }
  foreach ($tool in @($step.allowed_tools)) { if (@($contract.allowed_tools) -notcontains [string]$tool) { throw "Step tool is not allowed: $tool" } }
  foreach ($value in @([string]$step.expected_output, [string]$step.verification, [string]$step.input_refs)) {
    if ($value -match '(?i)(network|web|erp|external_write|source_overwrite|delete|package_install|delegat|api[_-]?key|password|token)') { throw 'Execution plans cannot contain forbidden capabilities or secrets.' }
  }
}
$planRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\execution-plans')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $planRoot "$PlanId.json" }
$full = [IO.Path]::GetFullPath($OutputPath)
if (-not $full.StartsWith($planRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Execution plans must be written under .qianlima/run-traces/execution-plans.' }
New-Item -ItemType Directory -Path (Split-Path -Parent $full) -Force | Out-Null
$plan = [ordered]@{
  schema_version = 1; plan_type = 'qianlima_execution_plan'; plan_id = $PlanId; task_id = $TaskId; workflow = $Workflow; goal = $Goal
  execution_mode = 'read_only'; risk_level = $RiskLevel; data_scope = $DataScope; network_access = $false; external_write = $false; source_overwrite = $false; can_delegate = $false
  steps = @($steps); budget = [ordered]@{ max_steps = $MaxSteps; max_tool_calls = $MaxToolCalls; timeout_ms = $TimeoutMs }
  stop_conditions = @($StopCondition); verification_policy = $contract.verification_policy; status = 'planned'; evr_phase = 'execute'; created_at = (Get-Date).ToUniversalTime().ToString('o')
}
if (Test-Path -LiteralPath $full) { throw "Execution plan already exists: $PlanId" }
[IO.File]::WriteAllText($full, ($plan | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
if ($PassThru) { $plan | ConvertTo-Json -Depth 12 } else { Write-Host "Execution plan created: $full" }
