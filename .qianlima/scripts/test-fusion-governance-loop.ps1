<#
.SYNOPSIS
  Offline shadow regression for the Fusion Plan governance loop.
.DESCRIPTION
  Exercises Fusion Plan validation, a task-bound read-only grant, bounded
  artifact/evidence receipts, revocation, and a frozen trace. It never invokes
  a model, network endpoint, MCP server, or business tool.
#>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = Join-Path $projectRoot '.qianlima\run-traces'
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
$taskId = "fusion-loop-$stamp"
$traceId = "trace-$stamp"
$grantId = "grant-$stamp"
$artifactId = "artifact-$stamp"
$evidenceId = "evidence-$stamp"
$claimPackId = "claim-pack-$stamp"
$planPath = Join-Path $traceRoot "fusion-plan-$stamp.json"
$artifactPath = Join-Path $traceRoot "fusion-artifact-$stamp.json"
$tracePath = Join-Path $traceRoot "fusion-trace-$stamp.json"

$fusionValidator = Join-Path $PSScriptRoot 'validate-fusion-plan.ps1'
$claimValidator = Join-Path $PSScriptRoot 'validate-claim-pack.ps1'
$grantCreator = Join-Path $PSScriptRoot 'new-delegation-grant.ps1'
$artifactCreator = Join-Path $PSScriptRoot 'new-artifact-receipt.ps1'
$evidenceCreator = Join-Path $PSScriptRoot 'new-evidence-receipt.ps1'
$revokeGrant = Join-Path $PSScriptRoot 'revoke-delegation-grant.ps1'
$traceValidator = Join-Path $PSScriptRoot 'validate-run-trace.ps1'

$plan = [ordered]@{
  fusion_id = "fusion-$stamp"
  task_id = $taskId
  risk_level = 'L3'
  selected_models = @('candidate-model-a', 'candidate-model-b')
  selection_reason = 'High uncertainty requires independent evidence candidates.'
  independence_requirement = 'distinct_provider_or_version'
  allowed_input_refs = @('evidence:internal-sanitized-1')
  data_classification = 'internal_sanitized'
  candidate_budget = [ordered]@{ max_calls = 4; max_cost_usd = 1 }
  fusion_method = 'evidence_first_claim_pack'
  verifier = 'evidence_checker'
  claim_pack_refs = @('claim-pack:candidate-model-a', 'claim-pack:candidate-model-b')
  stop_conditions = @('evidence_sufficient', 'conflict_found', 'budget_exhausted')
  human_approval_requirement = 'not_required'
  status = 'draft'
}
[IO.File]::WriteAllText($planPath, ($plan | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

$cases = [System.Collections.Generic.List[object]]::new()
function Add-Case([string]$Name, [bool]$Passed) {
  $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed })
}

$fusionResult = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fusionValidator -PlanPath $planPath -PassThru | ConvertFrom-Json
Add-Case 'fusion_plan_approved_for_L3' ($fusionResult.status -eq 'approved')
$claimPath = Join-Path $traceRoot "claim-pack-$stamp.json"
$claim = [ordered]@{ claim_pack_id = $claimPackId; fusion_id = $plan.fusion_id; task_id = $taskId; producer_employee_id = 'employee-a'; producer_agent_id = 'candidate-agent-a'; producer_model_id = 'candidate-model-a'; producer_model_version = 'test-v1'; work_order_ref = "work-$stamp"; grant_ref = $grantId; claims = @([ordered]@{ claim_id = 'claim-1'; statement = 'Test-only candidate claim.'; source_refs = @('evidence:internal-sanitized-1'); confidence = 0.7; uncertainty = 'Test-only uncertainty.'; falsifiers = @('Independent check disproves the claim.') }); source_refs = @('evidence:internal-sanitized-1'); data_time_range = 'test-only'; assumptions = @('Input is sanitized.'); uncertainties = @('No production data.'); falsifiers = @('Independent verification fails.'); method_ref = 'evidence-first-claim-pack'; status = 'candidate' }
[IO.File]::WriteAllText($claimPath, ($claim | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$claimResult = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $claimValidator -ClaimPackPath $claimPath -PassThru | ConvertFrom-Json
Add-Case 'claim_pack_candidate_validated' ($claimResult.status -eq 'accepted_as_candidate' -and $claimResult.production_authority -eq 'none')

$grant = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $grantCreator -GrantId $grantId -AgentId evidence_checker -TaskId $taskId -WorkOrderId "work-$stamp" -DataRef 'evidence:internal-sanitized-1' -AllowedTool read_selected_sources -RiskCeiling L3 -VerifierAgentId evidence_checker -PassThru | ConvertFrom-Json
Add-Case 'read_only_grant_issued' ($grant.network_access -eq 'none' -and $grant.write_access -eq 'none' -and $grant.can_delegate -eq $false)

$artifact = [ordered]@{ status = 'candidate_only'; summary = 'Sanitized candidate evidence metadata only.'; trace_id = $traceId }
[IO.File]::WriteAllText($artifactPath, ($artifact | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
$hash = 'sha256:' + (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
$artifactReceipt = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $artifactCreator -ArtifactId $artifactId -TaskId $taskId -Name candidate_evidence -MediaType application/json -Reference ("fusion-artifact-$stamp.json") -IntegrityHash $hash -SourceClassification internal_sanitized -VerificationStatus passed -PassThru | ConvertFrom-Json
$evidenceReceipt = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $evidenceCreator -ReceiptId $evidenceId -TaskId $taskId -GrantId $grantId -AgentId evidence_checker -ConclusionSummary 'Candidate evidence is bounded and ready for independent review.' -SourceRef evidence:internal-sanitized-1 -DataTimeRange 'test-only' -MethodRef evidence-first-claim-pack -ArtifactRef ("artifact-receipts/$artifactId.json") -IntegrityHash $hash -SourceClassification internal_sanitized -VerificationStatus passed -VerifierAgentId independent_checker -PassThru | ConvertFrom-Json
Add-Case 'evidence_receipts_linked' ($artifactReceipt.task_id -eq $taskId -and $evidenceReceipt.grant_id -eq $grantId -and $evidenceReceipt.verifier_agent_id -eq 'independent_checker')

$revocationOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $revokeGrant -GrantId $grantId -Reason 'Shadow loop requires revocation before downstream execution.' -PassThru 6>$null)
$revocationText = $revocationOutput -join "`n"
$revocationStart = $revocationText.IndexOf('{')
if ($revocationStart -lt 0) { throw 'Grant revocation did not return a JSON result.' }
$revocation = $revocationText.Substring($revocationStart) | ConvertFrom-Json
Add-Case 'grant_revoked_before_execution' ($revocation.grant_id -eq $grantId -and $revocation.task_id -eq $taskId)

$trace = [ordered]@{
  trace_id = $traceId; run_id = "run-$stamp"; task_id = $taskId; agent_id = 'evidence_checker'; agent_version = 'test-v1'; approved_agent_version = 'test-v1'; runner_id = 'shadow-no-execution'; policy_version = '1.0'; protocol_version = '1.0.0'
  budget_snapshot = [ordered]@{ max_steps = 4; max_tool_calls = 3; timeout_ms = 90000; steps_used = 1; tool_calls_used = 0 }
  grant_ref = "delegation-grants/$grantId.json"; artifact_refs = @("artifact-receipts/$artifactId.json"); evidence_refs = @("evidence-receipts/$evidenceId.json"); audit_event_refs = @('audit-events.jsonl')
  terminal_status = 'frozen'; created_at = (Get-Date).ToUniversalTime().ToString('o'); failure_scenario = 'revoked_grant'; failure_action = 'deny_before_tool_use'; artifact_status = 'passed'; pending_downstream = 0
  linked_contracts = @([ordered]@{ trace_id = $traceId; task_id = $taskId; agent_id = 'evidence_checker'; grant_ref = "delegation-grants/$grantId.json" })
  events = @([ordered]@{ event_type = 'grant_revoked'; decision = 'revoke'; external_calls = $false; permissions_granted = $false })
}
[IO.File]::WriteAllText($tracePath, ($trace | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$traceResult = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $traceValidator -TracePath $tracePath -PassThru | ConvertFrom-Json
Add-Case 'revoked_downstream_trace_frozen' ($traceResult.status -eq 'passed' -and $traceResult.terminal_status -eq 'frozen' -and $traceResult.failure_scenario -eq 'revoked_grant')

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{
  passed = ($failed.Count -eq 0)
  trace_id = $traceId
  task_id = $taskId
  cases = @($cases)
  external_calls = $false
  permissions_granted = $false
}
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw "Fusion governance loop regression failed: $($failed.name -join ', ')" }
