param(
  [ValidatePattern('^[A-Za-z0-9_-]{3,80}$')]
  [string]$AgentId = 'local-readonly-evidence-checker',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cardPath = Join-Path $projectRoot ('.qianlima\local-a2a-agents\{0}\agent-card.json' -f $AgentId)
$registryPath = Join-Path $projectRoot '.qianlima\local-a2a-agents.json'
$traceRoot = Join-Path $projectRoot '.qianlima\run-traces'
$mockScript = Join-Path $PSScriptRoot 'invoke-a2a-local-mock.ps1'

if (-not (Test-Path -LiteralPath $cardPath -PathType Leaf)) { throw "Local Agent Card not found: $cardPath" }
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { throw "Local agent registry not found: $registryPath" }
$card = Get-Content -LiteralPath $cardPath -Raw -Encoding UTF8 | ConvertFrom-Json
$registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$registration = @($registry.agents | Where-Object { $_.id -eq $AgentId }) | Select-Object -First 1

$cases = @()
$cases += [PSCustomObject]@{ name = 'required_card_fields'; passed = ($card.name -and $card.description -and $card.version -and $card.capabilities -and @($card.supportedInterfaces).Count -eq 1 -and @($card.skills).Count -eq 1) }
$cases += [PSCustomObject]@{ name = 'registration_is_readonly'; passed = ($registration.status -eq 'registered_local_only' -and $registration.dispatch_enabled -eq $false -and $registration.network_access -eq 'none' -and $registration.write_access -eq 'none') }
$cases += [PSCustomObject]@{ name = 'card_is_readonly'; passed = ($card.qianlima.internal_agent_ref -eq 'evidence_checker' -and $card.qianlima.dispatch_enabled -eq $false -and $card.qianlima.network_access -eq 'none' -and $card.qianlima.write_access -eq 'none') }

$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
$taskId = "onboard-$stamp"
$contextId = "ctx-$stamp"
$envelopePath = Join-Path $traceRoot "a2a-onboarding-envelope-$taskId.json"
$artifactPath = Join-Path $traceRoot "a2a-mock-$taskId.json"
$envelope = [ordered]@{
  schema_version = 1; contract_type = 'qianlima_a2a_internal_task_envelope'; protocol_target = 'A2A 1.0 semantics'
  context_id = $contextId; task_id = $taskId; parent_run_id = "onboarding-$stamp"; agent_ref = 'evidence_checker'
  goal = 'Verify the local read-only agent onboarding contract.'
  input_refs = @([ordered]@{ artifact_id = 'artifact-onboarding-sanitized'; source_classification = 'internal_sanitized'; media_type = 'application/json'; integrity_hash = 'sha256:onboarding'; context_id = $contextId })
  delegation = [ordered]@{ risk_ceiling = 'L3'; allowed_tools = @('read_selected_sources'); data_scope = 'task_selected_sources_only'; budget = [ordered]@{ max_steps = 4; max_tool_calls = 3; timeout_ms = 90000 }; network_access = 'none'; write_access = 'none' }
  expected_artifacts = @('verification_receipt'); verification = [ordered]@{ owner = 'parent_agent'; pass_condition = 'Local mock contract accepted.' }
  stop_conditions = @('evidence_sufficient'); prohibited = @('hidden_reasoning', 'full_memory', 'secrets', 'raw_workspace_export', 'external_write')
}
[IO.File]::WriteAllText($envelopePath, ($envelope | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$mockResult = & $mockScript -EnvelopePath $envelopePath -OutputPath $artifactPath -PassThru | ConvertFrom-Json
$cases += [PSCustomObject]@{ name = 'local_contract_exchange'; passed = ($mockResult.status -eq 'completed' -and (Test-Path -LiteralPath $mockResult.artifact_path)) }

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ agent_id = $AgentId; passed = ($failed.Count -eq 0); cases = $cases }
if ($PassThru) { $result | ConvertTo-Json -Depth 6 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw "Local read-only A2A agent test failed: $($failed.name -join ', ')" }
