param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$WorkOrderId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$ParentRunId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$AgentId,
  [Parameter(Mandatory = $true)] [string]$Goal,
  [string[]]$InputRef = @(),
  [string[]]$AllowedTool = @(),
  [Parameter(Mandatory = $true)] [string]$DataScope,
  [ValidateSet('L0', 'L1', 'L2', 'L3', 'L4')] [string]$RiskCeiling = 'L1',
  [int]$MaxSteps = 1,
  [int]$MaxToolCalls = 1,
  [int]$TimeoutMs = 30000,
  [string[]]$ExpectedArtifact = @(),
  [Parameter(Mandatory = $true)] [string]$Verification,
  [Parameter(Mandatory = $true)] [string[]]$StopCondition,
  [switch]$RollbackRequired,
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if ($MaxSteps -lt 1 -or $MaxToolCalls -lt 1 -or $TimeoutMs -lt 1) { throw 'Work-order budgets must be positive.' }
if ([string]::IsNullOrWhiteSpace($Goal) -or [string]::IsNullOrWhiteSpace($DataScope) -or [string]::IsNullOrWhiteSpace($Verification)) { throw 'Goal, DataScope, and Verification are required.' }
if ($ExpectedArtifact.Count -eq 0) { throw 'At least one expected artifact reference is required.' }
if ($RiskCeiling -eq 'L4' -and -not $RollbackRequired) { throw 'L4 work orders require RollbackRequired.' }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cardPath = Join-Path $PSScriptRoot '..\agent-cards.yaml'
$cardPattern = "(?m)^\s*- id:\s*$([regex]::Escape($AgentId))\s*$"
if (-not (Select-String -LiteralPath $cardPath -Pattern $cardPattern -Quiet)) { throw "Unknown Agent Card: $AgentId" }
$forbidden = @('api_key', 'access_token', 'refresh_token', 'password', 'cookie', 'authorization:')
foreach ($value in @($Goal) + @($InputRef) + @($ExpectedArtifact) + @($Verification) + @($StopCondition)) {
  foreach ($needle in $forbidden) { if ($value -match [regex]::Escape($needle)) { throw 'Work orders cannot contain secrets or authorization material.' } }
}
$orderRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\work-orders')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $orderRoot "$WorkOrderId.json" }
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFullPath.StartsWith($orderRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Work orders must be written under .qianlima/run-traces/work-orders.' }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputFullPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $outputFullPath) -Force | Out-Null }
$order = [ordered]@{
  schema_version = 1
  order_type = 'qianlima_agent_work_order'
  work_order_id = $WorkOrderId
  parent_run_id = $ParentRunId
  agent_id = $AgentId
  goal = $Goal
  input_refs = @($InputRef)
  allowed_tools = @($AllowedTool)
  data_scope = $DataScope
  budget = [ordered]@{ max_steps = $MaxSteps; max_tool_calls = $MaxToolCalls; timeout_ms = $TimeoutMs }
  risk_ceiling = $RiskCeiling
  expected_artifacts = @($ExpectedArtifact)
  verification = $Verification
  stop_conditions = @($StopCondition)
  rollback_required = [bool]$RollbackRequired
  status = 'pending'
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($outputFullPath, ($order | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
if ($PassThru) { $order | ConvertTo-Json -Depth 8 } else { Write-Host "Work order created: $outputFullPath" }
