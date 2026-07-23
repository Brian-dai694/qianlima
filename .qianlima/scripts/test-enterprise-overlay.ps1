<##
.SYNOPSIS
  Regression tests for the sidecar Enterprise Overlay Gateway.
  No core Harness files, providers, Docker, or external notifications are used.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$overlay = Join-Path $PSScriptRoot 'invoke-enterprise-overlay.ps1'
$orderScript = Join-Path $PSScriptRoot 'new-work-order.ps1'
$grantScript = Join-Path $PSScriptRoot 'new-delegation-grant.ps1'
$traceRoot = Join-Path $projectRoot '.qianlima\run-traces'
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
$taskId = "overlay-task-$stamp"; $orderId = "overlay-order-$stamp"; $grantId = "overlay-grant-$stamp"
$orderPath = Join-Path $traceRoot "work-orders/$orderId.json"; $grantPath = Join-Path $traceRoot "delegation-grants/$grantId.json"
$artifactPath = Join-Path $traceRoot "working/overlay-safe-$stamp.md"
$pipelinePath = Join-Path $traceRoot "pipeline-tests/overlay-pipeline-$stamp.json"
$isolation = Join-Path $traceRoot "sandbox-workspaces/$taskId/container"
New-Item -ItemType Directory -Path $isolation -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $artifactPath) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $pipelinePath) -Force | Out-Null
[IO.File]::WriteAllText($artifactPath, 'Overlay sanitized evidence.', [Text.UTF8Encoding]::new($false))
& $orderScript -WorkOrderId $orderId -ParentRunId "overlay-parent-$stamp" -AgentId codewhale_worker -Goal 'Inspect one sanitized evidence reference.' -InputRef artifact-sanitized -AllowedTool read_selected_sources -DataScope task_selected_sources_only -RiskCeiling L2 -ExpectedArtifact overlay-receipt -Verification evidence_checker_passed -StopCondition evidence_sufficient | Out-Null
& $grantScript -GrantId $grantId -AgentId codewhale_worker -TaskId $taskId -WorkOrderId $orderId -DataRef artifact-sanitized -AllowedTool read_selected_sources -RiskCeiling L2 -VerifierAgentId codex_supervisor | Out-Null
$pipeline = [ordered]@{ pipeline_id = "overlay-pipeline-$stamp"; pipeline_version = '1.0.0'; task_id = $taskId; agent_id = 'codewhale_worker'; agent_version = '0.8.67'; runner_id = 'docker_local_mock'; stages = @('input_reference','classify_and_minimize','authorize','execute','artifact_scan','independent_verify','adopt_or_freeze' | ForEach-Object { [ordered]@{ id = $_; status = 'completed' } }); artifact_metadata = [ordered]@{ task_id = $taskId; grant_id = $grantId; agent_id = 'codewhale_worker'; agent_version = '0.8.67'; runner_id = 'docker_local_mock'; input_hash = ('sha256:' + ('a' * 64)); source_classification = 'internal_sanitized'; created_at = (Get-Date).ToUniversalTime().ToString('o'); budget_snapshot = [ordered]@{ max_tool_calls = 2 }; verification_status = 'passed'; verifier_id = 'evidence_checker' }; budget = [ordered]@{ max_steps = 7; max_tool_calls = 2; timeout_ms = 30000; max_concurrent_agents = 1; max_failed_attempts = 0; steps_used = 6; tool_calls_used = 1; failed_attempts = 0 }; backpressure = [ordered]@{ on_exhaustion = 'freeze_and_revoke'; on_verifier_backlog = 'stop_upstream_generation' }; final_decision = 'pending' }
[IO.File]::WriteAllText($pipelinePath, ($pipeline | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
$hash = 'sha256:' + ('a' * 64); $attestationId = "overlay-attestation-$stamp"
$attestationPath = Join-Path $traceRoot "sandbox-attestations/$attestationId.json"
$attestation = [ordered]@{ schema_version=1; contract_type='qianlima_sandbox_attestation'; attestation_id=$attestationId; runner_id='docker_local_mock'; provider='docker'; agent_id='codewhale_worker'; task_id=$taskId; status='verified'; sandbox_type='docker-mock'; isolation_root=$isolation; host_workspace_mounted=$false; agent_network='none'; mcp_mode='allowlist_read_only'; mcp_servers=@(); file_export=$false; web_access=$false; erp_access=$false; secret_mode='secret_ref_only'; expires_at=(Get-Date).ToUniversalTime().AddMinutes(5).ToString('o'); evidence_hash=$hash }
[IO.File]::WriteAllText($attestationPath, ($attestation | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$result = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $overlay -RunnerId docker_local_mock -WorkOrderPath $orderPath -GrantPath $grantPath -AttestationPath $attestationPath -PipelinePath $pipelinePath -ArtifactPath $artifactPath -ArtifactMediaType text/markdown -ArtifactClassification internal_sanitized -PassThru | ConvertFrom-Json
$cases = [System.Collections.Generic.List[object]]::new(); $cases.Add([PSCustomObject]@{name='overlay_dry_run';passed=($result.status -eq 'validated_dry_run' -and $result.boundary_status -eq 'pass' -and $result.pipeline_status -eq 'passed' -and $result.artifact_scan.status -eq 'passed' -and $result.external_calls -eq $false)})
$cases.Add([PSCustomObject]@{name='credential_gate_still_denies';passed=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $overlay -RunnerId docker_local_mock -WorkOrderPath $orderPath -GrantPath $grantPath -AttestationPath $attestationPath -PipelinePath $pipelinePath -CredentialId model_provider_openai 2>&1 | Out-String) -match 'Credential reference validation failed'})
$badPipelinePath = Join-Path (Split-Path -Parent $pipelinePath) "overlay-pipeline-bad-$stamp.json"; $badPipeline = Get-Content $pipelinePath -Raw -Encoding UTF8 | ConvertFrom-Json; $badPipeline.runner_id = 'docker_other_runner'; [IO.File]::WriteAllText($badPipelinePath, ($badPipeline | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false)); $cases.Add([PSCustomObject]@{name='pipeline_binding_denied';passed=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $overlay -RunnerId docker_local_mock -WorkOrderPath $orderPath -GrantPath $grantPath -AttestationPath $attestationPath -PipelinePath $badPipelinePath 2>&1 | Out-String) -match 'Pipeline task, Agent, or Runner binding'})
$cases.Add([PSCustomObject]@{name='core_boundary_unchanged';passed=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check-harness-boundary.ps1') -PassThru | ConvertFrom-Json).status -eq 'pass'})
$failed=@($cases|Where-Object{-not $_.passed});$final=[PSCustomObject]@{passed=($failed.Count -eq 0);cases=@($cases);core_files_changed_by_test=$false;external_calls=$false}
if($PassThru){$final|ConvertTo-Json -Depth 10}else{$cases|Format-Table -AutoSize};if($failed.Count -gt 0){throw "Enterprise Overlay regression failed: $($failed.name -join ', ')"}
