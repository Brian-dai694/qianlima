<#
.SYNOPSIS
  Creates and registers Qianlima's built-in local read-only A2A-compatible agent.
.DESCRIPTION
  This is the beginner entry point. It creates the local Agent Card and registry
  entry, then runs the local contract test. It never starts a listener, sends a
  network request, reads arbitrary workspace files, or grants write authority.
#>
param(
  [ValidatePattern('^[A-Za-z0-9_-]{3,80}$')]
  [string]$AgentId = 'local-readonly-evidence-checker',
  [string]$AgentName = 'Local Read-Only Evidence Checker',
  [switch]$SkipContractTest,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$agentRoot = Join-Path $projectRoot ('.qianlima\local-a2a-agents\' + $AgentId)
$cardPath = Join-Path $agentRoot 'agent-card.json'
$registryPath = Join-Path $projectRoot '.qianlima\local-a2a-agents.json'
$testScript = Join-Path $PSScriptRoot 'test-local-readonly-a2a-agent.ps1'

if (-not (Test-Path -LiteralPath $agentRoot -PathType Container)) {
  New-Item -ItemType Directory -Path $agentRoot -Force | Out-Null
}

# This URL is an identity placeholder only. Dispatch is disabled and no listener is started.
$interface = [PSCustomObject]@{
  url = "http://127.0.0.1:15722/a2a"
  protocolBinding = 'JSONRPC'
  protocolVersion = '1.0'
}
$skill = [PSCustomObject]@{
  id = 'verify-sanitized-evidence'
  name = 'Verify sanitized evidence'
  description = 'Validates the bounded local task contract and returns a receipt reference.'
  tags = @('local', 'read-only', 'evidence', 'qianlima')
  examples = @('Verify this sanitized evidence package')
  inputModes = @('application/json')
  outputModes = @('application/json')
}
$card = [ordered]@{
  name = $AgentName
  description = 'Qianlima built-in local evidence checker. Read-only, sanitized references only, and no network dispatch.'
  version = '0.1.0-local'
  protocolVersion = '1.0'
  supportedInterfaces = @($interface)
  capabilities = [ordered]@{
    streaming = $false
    pushNotifications = $false
    stateTransitionHistory = $false
  }
  defaultInputModes = @('application/json')
  defaultOutputModes = @('application/json')
  skills = @($skill)
  qianlima = [ordered]@{
    internal_agent_ref = 'evidence_checker'
    registration_mode = 'local_only'
    dispatch_enabled = $false
    network_access = 'none'
    write_access = 'none'
    risk_ceiling = 'L3'
    data_scope = 'public_or_internal_sanitized_references_only'
    authority_rule = 'Agent Card is discovery metadata, never a permission grant.'
  }
}
[IO.File]::WriteAllText($cardPath, ($card | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))

$registry = if (Test-Path -LiteralPath $registryPath) {
  Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
  [PSCustomObject]@{ schema_version = 1; purpose = 'Local-only A2A-compatible agent registrations. No network dispatch.'; agents = @() }
}
if ($registry.schema_version -ne 1) { throw 'Unsupported local A2A registry schema version.' }
$existing = @($registry.agents | Where-Object { $_.id -eq $AgentId })
$entry = [PSCustomObject]@{
  id = $AgentId
  name = $AgentName
  status = 'registered_local_only'
  card_path = ('.qianlima/local-a2a-agents/{0}/agent-card.json' -f $AgentId)
  internal_agent_ref = 'evidence_checker'
  dispatch_enabled = $false
  network_access = 'none'
  write_access = 'none'
  risk_ceiling = 'L3'
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
if ($existing.Count -gt 0) {
  $registry.agents = @($registry.agents | Where-Object { $_.id -ne $AgentId }) + @($entry)
} else {
  $registry.agents = @($registry.agents) + @($entry)
}
[IO.File]::WriteAllText($registryPath, ($registry | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

$testResult = $null
if (-not $SkipContractTest) {
  $testResult = & $testScript -AgentId $AgentId -PassThru | ConvertFrom-Json
  if (-not $testResult.passed) { throw 'Local read-only A2A agent was registered but failed its contract test.' }
}

$result = [PSCustomObject]@{
  agent_id = $AgentId
  name = $AgentName
  status = 'registered_local_only'
  card_path = $cardPath
  registry_path = $registryPath
  contract_test_passed = if ($null -eq $testResult) { $null } else { [bool]$testResult.passed }
  network_dispatch_enabled = $false
  write_access = 'none'
}
if ($PassThru) { $result | ConvertTo-Json -Depth 6 } else { $result | Format-List }
