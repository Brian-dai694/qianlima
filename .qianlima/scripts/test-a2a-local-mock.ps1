$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = Join-Path $projectRoot '.qianlima\run-traces'
$mockScript = Join-Path $PSScriptRoot 'invoke-a2a-local-mock.ps1'
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
$taskId = "mock-$stamp"
$envelopePath = Join-Path $traceRoot "a2a-envelope-$taskId.json"
$artifactPath = Join-Path $traceRoot "a2a-mock-$taskId.json"

$envelope = [ordered]@{
  schema_version = 1
  contract_type = 'qianlima_a2a_internal_task_envelope'
  protocol_target = 'A2A 1.0 semantics'
  context_id = "ctx-$stamp"
  task_id = $taskId
  parent_run_id = "run-$stamp"
  agent_ref = 'evidence_checker'
  goal = 'Verify a sanitized mock claim package.'
  input_refs = @([ordered]@{ artifact_id = 'artifact-sanitized'; source_classification = 'internal_sanitized'; media_type = 'application/json'; integrity_hash = 'sha256:test'; context_id = "ctx-$stamp" })
  delegation = [ordered]@{ risk_ceiling = 'L3'; allowed_tools = @('read_selected_sources'); data_scope = 'task_selected_sources_only'; budget = [ordered]@{ max_steps = 4; max_tool_calls = 3; timeout_ms = 90000 }; network_access = 'none'; write_access = 'none' }
  expected_artifacts = @('verification_receipt')
  verification = [ordered]@{ owner = 'parent_agent'; pass_condition = 'Mock contract accepted.' }
  stop_conditions = @('evidence_sufficient')
  prohibited = @('hidden_reasoning', 'full_memory', 'secrets', 'raw_workspace_export', 'external_write')
}
[IO.File]::WriteAllText($envelopePath, ($envelope | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

$cases = @()
$result = & $mockScript -EnvelopePath $envelopePath -OutputPath $artifactPath -PassThru | ConvertFrom-Json
$cases += [PSCustomObject]@{ name = 'happy_path'; passed = ($result.status -eq 'completed' -and (Test-Path -LiteralPath $result.artifact_path)) }

try { & $mockScript -EnvelopePath $envelopePath -OutputPath $artifactPath | Out-Null; $cases += [PSCustomObject]@{ name = 'task_immutability'; passed = $false } }
catch { $cases += [PSCustomObject]@{ name = 'task_immutability'; passed = $_.Exception.Message -match 'immutable' } }

$networkEnvelope = $envelope | ConvertTo-Json -Depth 8 | ConvertFrom-Json
$networkEnvelope.task_id = "network-$stamp"
$networkEnvelope.delegation.network_access = 'external'
$networkPath = Join-Path $traceRoot "a2a-envelope-network-$stamp.json"
[IO.File]::WriteAllText($networkPath, ($networkEnvelope | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
try { & $mockScript -EnvelopePath $networkPath | Out-Null; $cases += [PSCustomObject]@{ name = 'network_rejected'; passed = $false } }
catch { $cases += [PSCustomObject]@{ name = 'network_rejected'; passed = $_.Exception.Message -match 'network' } }

$contextEnvelope = $envelope | ConvertTo-Json -Depth 8 | ConvertFrom-Json
$contextEnvelope.task_id = "context-$stamp"
$contextEnvelope.input_refs[0].context_id = 'ctx-other'
$contextPath = Join-Path $traceRoot "a2a-envelope-context-$stamp.json"
[IO.File]::WriteAllText($contextPath, ($contextEnvelope | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
try { & $mockScript -EnvelopePath $contextPath | Out-Null; $cases += [PSCustomObject]@{ name = 'cross_context_rejected'; passed = $false } }
catch { $cases += [PSCustomObject]@{ name = 'cross_context_rejected'; passed = $_.Exception.Message -match 'context_id' } }

$cases | Format-Table -AutoSize
$failed = @($cases | Where-Object { -not $_.passed })
if ($failed.Count -gt 0) { throw "A2A local mock regression failed: $($failed.name -join ', ')" }
Write-Host "A2A local mock regression passed: $($cases.Count) cases."
