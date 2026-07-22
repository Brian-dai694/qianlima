param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$AgentId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$WorkflowId,
  [ValidateSet('L0', 'L1', 'L2', 'L3', 'L4')] [string]$RiskCeiling = 'L1',
  [ValidateSet('public', 'internal_sanitized', 'confidential_reference_only')] [string]$SourceClassification = 'public',
  [ValidateSet('1.0')] [string]$ProtocolVersion = '1.0',
  [int]$TimeoutMs = 10000,
  [int]$MaxSteps = 3,
  [int]$MaxToolCalls = 2,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$policyPath = Join-Path $PSScriptRoot '..\a2a-client-gateway-policy.yaml'
$registryPath = Join-Path $PSScriptRoot '..\a2a-remote-registry.json'
$result = [ordered]@{
  decision = 'blocked'
  agent_id = $AgentId
  workflow_id = $WorkflowId
  protocol_version = $ProtocolVersion
  network_io_performed = $false
  reasons = @()
  policy = '.qianlima/a2a-client-gateway-policy.yaml'
}
function Block([string]$Reason) { $result.reasons += $Reason }
if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) { Block 'Gateway policy is missing.' }
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { Block 'Remote registry is missing.' }
if ($RiskCeiling -eq 'L3' -or $RiskCeiling -eq 'L4') { Block 'Phase 2 gateway maximum risk ceiling is L2.' }
if ($TimeoutMs -lt 1 -or $TimeoutMs -gt 30000) { Block 'Timeout exceeds the Phase 2 budget.' }
if ($MaxSteps -lt 1 -or $MaxSteps -gt 5) { Block 'Step budget exceeds the Phase 2 budget.' }
if ($MaxToolCalls -lt 1 -or $MaxToolCalls -gt 3) { Block 'Tool budget exceeds the Phase 2 budget.' }
if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
  $registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($registry.default_action -ne 'deny') { Block 'Remote registry default action must remain deny.' }
  if ($registry.network_dispatch_enabled -ne $true) { Block 'Network dispatch is disabled; preflight will not enable it.' }
  $agent = @($registry.agents | Where-Object { $_.id -eq $AgentId }) | Select-Object -First 1
  if ($null -eq $agent) { Block 'Agent is not present in the remote registry.' }
  elseif ($agent.enabled -ne $true) { Block 'Agent registry entry is disabled.' }
  elseif ($agent.protocol_versions -notcontains $ProtocolVersion) { Block 'Protocol version is not allowlisted by the Agent.' }
  elseif ($agent.allowed_workflows -notcontains $WorkflowId) { Block 'Workflow is not allowlisted by the Agent.' }
  elseif ($agent.allowed_source_classifications -notcontains $SourceClassification) { Block 'Source classification is not allowlisted by the Agent.' }
}
if ($result.reasons.Count -eq 0) { $result.decision = 'ready_for_human_approval' }
if ($PassThru) { [PSCustomObject]$result | ConvertTo-Json -Depth 6 } else { Write-Host "A2A client preflight: $($result.decision)"; $result.reasons | ForEach-Object { Write-Host "- $_" } }
if ($result.decision -eq 'blocked') { exit 20 }
