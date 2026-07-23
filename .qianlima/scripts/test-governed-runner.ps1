<##
.SYNOPSIS
  Regression tests for the registered execution Runner gate.
  No Docker or vendor process is started.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runnerScript = Join-Path $PSScriptRoot 'invoke-governed-runner.ps1'
$grantScript = Join-Path $PSScriptRoot 'new-delegation-grant.ps1'
$orderScript = Join-Path $PSScriptRoot 'new-work-order.ps1'
$revokeScript = Join-Path $PSScriptRoot 'revoke-delegation-grant.ps1'
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
$traceRoot = Join-Path $projectRoot '.qianlima\run-traces'
$cases = [System.Collections.Generic.List[object]]::new()
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
function Invoke-ExpectedFailure([scriptblock]$Action, [string]$Needle) {
  $output = @(); $exitCode = 0
  try { $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $output = @(& $Action 2>&1); $exitCode = $LASTEXITCODE; $ErrorActionPreference = $old }
  catch { $output += $_ | Out-String; $exitCode = 1 }
  return ($exitCode -ne 0 -and ($output -join "`n") -match $Needle)
}
function New-Scenario([string]$Suffix) {
  $taskId = "runner-task-$Suffix-$stamp"; $orderId = "runner-order-$Suffix-$stamp"; $grantId = "runner-grant-$Suffix-$stamp"
  $orderPath = Join-Path $traceRoot "work-orders/$orderId.json"; $grantPath = Join-Path $traceRoot "delegation-grants/$grantId.json"
  & $orderScript -WorkOrderId $orderId -ParentRunId "runner-parent-$stamp" -AgentId 'codewhale_worker' -Goal 'Inspect one sanitized evidence reference.' -InputRef 'artifact-sanitized' -AllowedTool 'read_selected_sources' -DataScope 'task_selected_sources_only' -RiskCeiling L2 -MaxSteps 2 -MaxToolCalls 1 -TimeoutMs 30000 -ExpectedArtifact 'runner-receipt' -Verification 'evidence_checker_passed' -StopCondition 'evidence_sufficient' | Out-Null
  & $grantScript -GrantId $grantId -AgentId 'codewhale_worker' -TaskId $taskId -WorkOrderId $orderId -DataRef 'artifact-sanitized' -AllowedTool 'read_selected_sources' -RiskCeiling L2 -VerifierAgentId 'codex_supervisor' | Out-Null
  $isolation = Join-Path $traceRoot "sandbox-workspaces/$taskId/container"
  New-Item -ItemType Directory -Path $isolation -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $traceRoot 'sandbox-attestations') -Force | Out-Null
  $evidenceText = "docker mock $taskId"
  $sha = [Security.Cryptography.SHA256]::Create(); $hash = 'sha256:' + (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($evidenceText)) | ForEach-Object { $_.ToString('x2') }) -join '')
  $attestationId = "docker-attestation-$taskId"
  $attestationPath = Join-Path $traceRoot "sandbox-attestations/$attestationId.json"
  $attestation = [ordered]@{ schema_version = 1; contract_type = 'qianlima_sandbox_attestation'; attestation_id = $attestationId; runner_id = 'docker_local_mock'; provider = 'docker'; agent_id = 'codewhale_worker'; task_id = $taskId; status = 'verified'; sandbox_type = 'docker-mock'; isolation_root = $isolation; host_workspace_mounted = $false; agent_network = 'none'; mcp_mode = 'allowlist_read_only'; mcp_servers = @(); file_export = $false; web_access = $false; erp_access = $false; secret_mode = 'secret_ref_only'; expires_at = (Get-Date).ToUniversalTime().AddMinutes(5).ToString('o'); evidence_hash = $hash }
  [IO.File]::WriteAllText($attestationPath, ($attestation | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
  return [PSCustomObject]@{ TaskId = $taskId; OrderId = $orderId; GrantId = $grantId; OrderPath = $orderPath; GrantPath = $grantPath; AttestationPath = $attestationPath }
}

$scenario = New-Scenario 'valid'
$valid = & $runnerScript -RunnerId docker_local_mock -WorkOrderPath $scenario.OrderPath -GrantPath $scenario.GrantPath -AttestationPath $scenario.AttestationPath -Mode DryRun -PassThru | ConvertFrom-Json
Add-Case 'docker_mock_dry_run' ($valid.status -eq 'validated_dry_run' -and $valid.process_started -eq $false)
Add-Case 'host_direct_denied' (Invoke-ExpectedFailure { & $runnerScript -RunnerId host_direct -WorkOrderPath $scenario.OrderPath -GrantPath $scenario.GrantPath -AttestationPath $scenario.AttestationPath } 'Unknown execution Runner')
Add-Case 'execute_disabled' (Invoke-ExpectedFailure { & $runnerScript -RunnerId docker_local_mock -WorkOrderPath $scenario.OrderPath -GrantPath $scenario.GrantPath -AttestationPath $scenario.AttestationPath -Mode Execute } 'Execution is disabled')
$badAttestation = Get-Content -LiteralPath $scenario.AttestationPath -Raw -Encoding UTF8 | ConvertFrom-Json
$badAttestation.task_id = "other-task-$stamp"
$badAttestationPath = Join-Path $traceRoot "sandbox-attestations/docker-attestation-bad-$stamp.json"
[IO.File]::WriteAllText($badAttestationPath, ($badAttestation | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
Add-Case 'attestation_task_binding' (Invoke-ExpectedFailure { & $runnerScript -RunnerId docker_local_mock -WorkOrderPath $scenario.OrderPath -GrantPath $scenario.GrantPath -AttestationPath $badAttestationPath } 'not verified')
$revoked = New-Scenario 'revoked'
& $revokeScript -GrantId $revoked.GrantId -Reason 'Runner regression revocation.' | Out-Null
Add-Case 'revoked_grant_denied' (Invoke-ExpectedFailure { & $runnerScript -RunnerId docker_local_mock -WorkOrderPath $revoked.OrderPath -GrantPath $revoked.GrantPath -AttestationPath $revoked.AttestationPath } 'revoked')
$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ passed = ($failed.Count -eq 0); cases = @($cases); docker_started = $false; vendor_process_started = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw "Governed Runner regression failed: $($failed.name -join ', ')" }
