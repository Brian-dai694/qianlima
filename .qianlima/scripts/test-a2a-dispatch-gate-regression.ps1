$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = Join-Path $projectRoot '.qianlima\run-traces'
$gate = Join-Path $PSScriptRoot 'test-a2a-dispatch-gate.ps1'
$registryPath = Join-Path $projectRoot '.qianlima\a2a-remote-registry.json'
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
$envelopePath = Join-Path $traceRoot "a2a-dispatch-gate-$stamp.json"
$envelope = [ordered]@{
  schema_version = 1
  contract_type = 'qianlima_a2a_internal_task_envelope'
  protocol_target = 'A2A 1.0 semantics'
  context_id = "ctx-$stamp"
  task_id = "gate-$stamp"
  parent_run_id = "run-$stamp"
  agent_ref = 'evidence_checker'
  goal = 'Research a public source.'
  input_refs = @([ordered]@{ artifact_id = 'artifact-public'; source_classification = 'public'; media_type = 'text/markdown'; integrity_hash = 'sha256:test'; context_id = "ctx-$stamp" })
  delegation = [ordered]@{ risk_ceiling = 'L2'; allowed_tools = @('read_selected_sources'); data_scope = 'public_only'; budget = [ordered]@{ max_steps = 3; max_tool_calls = 2; timeout_ms = 30000 }; network_access = 'none'; write_access = 'none' }
  expected_artifacts = @('research_summary')
  verification = [ordered]@{ owner = 'parent_agent'; pass_condition = 'Sources are cited.' }
  stop_conditions = @('evidence_sufficient')
  prohibited = @('hidden_reasoning', 'full_memory', 'secrets', 'raw_workspace_export', 'external_write')
}
[IO.File]::WriteAllText($envelopePath, ($envelope | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

$cases = @()
foreach ($agentId in @('example_readonly_research_agent', 'unknown_agent')) {
  try { & $gate -AgentId $agentId -EnvelopePath $envelopePath -RegistryPath $registryPath | Out-Null; $cases += [PSCustomObject]@{ name = "deny_$agentId"; passed = $false } }
  catch { $cases += [PSCustomObject]@{ name = "deny_$agentId"; passed = $_.Exception.Message -match 'A2A dispatch denied' } }
}

$enabledRegistry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$enabledRegistry.network_dispatch_enabled = $true
$enabledRegistry.agents[0].enabled = $true
$enabledPath = Join-Path $traceRoot "a2a-registry-enabled-$stamp.json"
[IO.File]::WriteAllText($enabledPath, ($enabledRegistry | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
try { & $gate -AgentId 'example_readonly_research_agent' -EnvelopePath $envelopePath -RegistryPath $enabledPath | Out-Null; $cases += [PSCustomObject]@{ name = 'network_dispatch_still_denied'; passed = $false } }
catch { $cases += [PSCustomObject]@{ name = 'network_dispatch_still_denied'; passed = $_.Exception.Message -match 'Network dispatch is disabled' } }

$cases | Format-Table -AutoSize
$failed = @($cases | Where-Object { -not $_.passed })
if ($failed.Count -gt 0) { throw "A2A dispatch gate regression failed: $($failed.name -join ', ')" }
Write-Host "A2A dispatch gate regression passed: $($cases.Count) cases."
