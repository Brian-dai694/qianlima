<##
.SYNOPSIS
  Regression tests for isolated improvement candidates and promotion gates.
  All inputs are synthetic and sanitized; no provider or Agent is started.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $PSScriptRoot 'validate-improvement-candidate.ps1'
$promoter = Join-Path $PSScriptRoot 'promote-improvement-candidate.ps1'
$root = Join-Path $projectRoot '.qianlima\evolution\candidates'
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
New-Item -ItemType Directory -Path $root -Force | Out-Null
function Write-Json($Value, [string]$Name) { $path = Join-Path $root "$Name-$stamp.json"; [IO.File]::WriteAllText($path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false)); return $path }
function New-Evaluation([string]$Suite) { return [ordered]@{ status = 'passed'; report_ref = ".qianlima/evolution/eval-cases/$Suite-synthetic.json"; case_count = 2; source_classification = 'internal_sanitized' } }
function New-Candidate([string]$Name = 'valid', [string]$State = 'shadow_converged') {
  $evaluation = [ordered]@{}; foreach ($suite in @('update_validation','id_holdout','ood_holdout','replay','latency_regression','L4_safety')) { $evaluation[$suite] = New-Evaluation $suite }
  $evaluation.latency_regression.baseline_first_useful_output_ms = 1800; $evaluation.latency_regression.candidate_first_useful_output_ms = 1750; $evaluation.L4_safety.gate_weakened = $false
  return [ordered]@{
    candidate_id = "candidate-$Name-$stamp"; candidate_version = '1.0.0'; lifecycle_state = $State; north_star_protocol_version = '1.0.0'; target_layer = 'specification'; target_files = @('.qianlima/specifications/improvement-candidate-contract.json'); hypothesis = 'Synthetic candidate improves governance validation without changing runtime authority.'
    expected_benefit = [ordered]@{ quality = 'evidence completeness remains stable'; latency = 'first useful output is not slower'; cost = 'no additional provider calls' }; proposed_by_agent_id = 'improvement-proposer'; tested_with = @([ordered]@{ provider_or_agent = 'codex-supervisor'; model_or_version = 'synthetic-1.0'; test_date = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd'); result = 'passed' }); baseline_version = 'v2.7.4'
    evaluation = $evaluation; independent_verifier = [ordered]@{ verifier_id = 'independent-evaluator'; independence_basis = 'Separate rule and replay evaluator.' }; permission_impact = [ordered]@{ expands_permissions = $false; changed_capabilities = @(); attack_surface_change = 'none' }; rollback_plan = [ordered]@{ rollback_version = 'v2.7.4'; rollback_ref = '.qianlima/snapshots/synthetic-baseline'; snapshot_ref = '.qianlima/snapshots/synthetic-baseline'; trigger = 'Any L4 safety regression, evidence regression, or first-useful-output slowdown.' }; human_approval = [ordered]@{ status = 'pending'; approval_ref = $null; required = $true }; proposed_change = [ordered]@{ apply_mode = 'shadow_only'; auto_apply = $false; production_change = $false }; privacy = [ordered]@{ sanitized = $true; raw_data_included = $false; secrets_included = $false; source_classification = 'internal_sanitized' }
  }
}
function Invoke-ExpectedFailure([string]$Path, [string]$Expected) { $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $out = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -CandidatePath $Path -PassThru 2>&1); $code = $LASTEXITCODE; $ErrorActionPreference = $old; return ($code -ne 0 -and ($out -join "`n") -match $Expected) }
function Add-Case([System.Collections.Generic.List[object]]$Cases, [string]$Name, [bool]$Passed) { $Cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
$cases = [System.Collections.Generic.List[object]]::new()
$validPath = Write-Json (New-Candidate 'valid') 'valid'; $validOut = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -CandidatePath $validPath -PassThru | ConvertFrom-Json); Add-Case $cases 'valid_candidate_passed' ($validOut.status -eq 'passed')
$self = New-Candidate 'self-verifier'; $self.independent_verifier.verifier_id = 'improvement-proposer'; Add-Case $cases 'self_verification_blocked' (Invoke-ExpectedFailure (Write-Json $self 'self-verifier') 'self_verification_forbidden')
$replay = New-Candidate 'replay-failure'; $replay.evaluation.replay.status = 'failed'; Add-Case $cases 'replay_failure_blocked' (Invoke-ExpectedFailure (Write-Json $replay 'replay-failure') 'evaluation_not_passed_replay')
$expanded = New-Candidate 'permission-expansion'; $expanded.permission_impact.expands_permissions = $true; Add-Case $cases 'permission_expansion_without_approval_blocked' (Invoke-ExpectedFailure (Write-Json $expanded 'permission-expansion') 'permission_expansion_without_explicit_approval')
$noRollback = New-Candidate 'no-rollback'; $noRollback.rollback_plan.rollback_ref = $null; Add-Case $cases 'missing_rollback_blocked' (Invoke-ExpectedFailure (Write-Json $noRollback 'no-rollback') 'rollback_plan_incomplete')
$auto = New-Candidate 'automatic-change'; $auto.proposed_change.auto_apply = $true; Add-Case $cases 'automatic_production_change_blocked' (Invoke-ExpectedFailure (Write-Json $auto 'automatic-change') 'automatic_production_change_forbidden')
$private = New-Candidate 'private-evidence'; $private.evaluation.replay.report_ref = '.qianlima/evolution/eval-cases/private-raw-report.json'; $private.evaluation.replay.source_classification = 'confidential_reference_only'; Add-Case $cases 'private_evidence_blocked' (Invoke-ExpectedFailure (Write-Json $private 'private-evidence') 'evaluation_evidence_not_sanitized_replay')
$promoteOut = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $promoter -CandidatePath $validPath -HumanApprovalRef 'approval-synthetic-001' -PassThru | ConvertFrom-Json); Add-Case $cases 'promotion_candidate_requires_no_production_change' ($promoteOut.status -eq 'promotion_candidate' -and $promoteOut.production_change -eq $false -and $promoteOut.automatic_promotion -eq $false)
$boundary = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check-harness-boundary.ps1') -PassThru | ConvertFrom-Json); Add-Case $cases 'core_harness_unchanged' ($boundary.status -eq 'pass')
$failed = @($cases | Where-Object { -not $_.passed }); $result = [PSCustomObject]@{ passed = ($failed.Count -eq 0); cases = @($cases); production_change = $false; automatic_promotion = $false; external_calls = $false; raw_private_evidence_recorded = $false }; if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $cases | Format-Table -AutoSize }; if ($failed.Count -gt 0) { throw "Improvement candidate regression failed: $($failed.name -join ', ')" }
