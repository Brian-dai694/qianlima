<##
.SYNOPSIS
  Regression tests for the Skill self-evolution manager.
##>
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$manager = Join-Path $PSScriptRoot 'invoke-skill-self-evolution.ps1'
$testId = 'self-evolution-test-' + [Guid]::NewGuid().ToString('n')
$candidateId = $testId
$testDir = Join-Path $root '.qianlima\evolution\self-evolution-tests'
$eventLog = Join-Path $testDir "$testId.jsonl"
$feedbackDir = Join-Path $root '.qianlima\feedback\skill-evolution'
$feedbackPath = Join-Path $feedbackDir "$testId.yaml"
$candidatePath = Join-Path $root ".qianlima\evolution\candidates\$testId.json"
$evidencePath = Join-Path $root '.qianlima\evolution\eval-cases\self-evolution-synthetic.json'
$checks = [System.Collections.Generic.List[object]]::new()
function Check([string]$Name, [bool]$Passed) { [void]$checks.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
function Run-Manager([string[]]$Arguments, [int]$ExpectedCode = 0) {
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $manager @Arguments 2>&1); $actual = $LASTEXITCODE } finally { $ErrorActionPreference = $previousPreference }
  if ($actual -ne $ExpectedCode) { throw "Unexpected manager exit code $actual, expected $ExpectedCode. Output: $($output -join "`n")" }
  $text = ($output -join "`n"); $start = $text.IndexOf('{'); $end = $text.LastIndexOf('}')
  if ($start -ge 0 -and $end -gt $start) { return ($text.Substring($start, $end - $start + 1) | ConvertFrom-Json) }
  return $null
}
try {
  New-Item -ItemType Directory -Path $testDir -Force | Out-Null
  New-Item -ItemType Directory -Path $feedbackDir -Force | Out-Null
  [IO.File]::WriteAllText($feedbackPath, "skill_feedback:`n  skill_id: test-skill`n  status: observed`n", (New-Object Text.UTF8Encoding($false)))
  [IO.File]::WriteAllText($evidencePath, '{"case":"sanitized","status":"passed"}', (New-Object Text.UTF8Encoding($false)))
  $candidate = [ordered]@{
    candidate_id = $candidateId; candidate_version = '1.0.1'; lifecycle_state = 'shadow_converged'; north_star_protocol_version = 'v2.7.8'; target_layer = 'skill'; target_files = @('.qianlima/specifications/skill-self-evolution-contract.json'); hypothesis = 'The manager prevents out-of-order Skill changes.'
    expected_benefit = @{ quality = 'no regression'; latency = 'no regression'; cost = 'no regression' }; proposed_by_agent_id = 'test-proposer'; baseline_version = '1.0.0'
    tested_with = @(@{ provider_or_agent = 'test-agent'; model_or_version = 'fixture-1'; test_date = '2026-07-22'; result = 'passed' })
    evaluation = @{
      update_validation = @{ status = 'passed'; report_ref = '.qianlima/evolution/eval-cases/self-evolution-synthetic.json'; case_count = 1; source_classification = 'internal_sanitized' }
      id_holdout = @{ status = 'passed'; report_ref = '.qianlima/evolution/eval-cases/self-evolution-synthetic.json'; case_count = 1; source_classification = 'internal_sanitized' }
      ood_holdout = @{ status = 'passed'; report_ref = '.qianlima/evolution/eval-cases/self-evolution-synthetic.json'; case_count = 1; source_classification = 'internal_sanitized' }
      replay = @{ status = 'passed'; report_ref = '.qianlima/evolution/eval-cases/self-evolution-synthetic.json'; case_count = 1; source_classification = 'internal_sanitized' }
      latency_regression = @{ status = 'passed'; report_ref = '.qianlima/evolution/eval-cases/self-evolution-synthetic.json'; case_count = 1; source_classification = 'internal_sanitized'; baseline_first_useful_output_ms = 100; candidate_first_useful_output_ms = 100 }
      L4_safety = @{ status = 'passed'; report_ref = '.qianlima/evolution/eval-cases/self-evolution-synthetic.json'; case_count = 1; source_classification = 'internal_sanitized'; gate_weakened = $false }
    }
    independent_verifier = @{ verifier_id = 'test-verifier'; independence_basis = 'Separate fixture validator.' }
    permission_impact = @{ expands_permissions = $false; attack_surface_change = 'none' }
    rollback_plan = @{ rollback_version = '1.0.0'; rollback_ref = '.qianlima/snapshots/self-evolution-baseline'; trigger = 'Any regression.'; snapshot_ref = '.qianlima/snapshots/self-evolution-baseline' }
    human_approval = @{ status = 'pending'; approval_ref = $null }; proposed_change = @{ auto_apply = $false; production_change = $false; apply_mode = 'auto_release' }
    privacy = @{ sanitized = $true; raw_data_included = $false; secrets_included = $false; source_classification = 'internal_sanitized' }
  }
  [IO.File]::WriteAllText($candidatePath, ($candidate | ConvertTo-Json -Depth 15), (New-Object Text.UTF8Encoding($false)))

  $early = Run-Manager -Arguments @('-Action','abstract_rule','-CandidateId',$candidateId,'-SkillId','test-skill','-RuleSummary','rule before evidence') -ExpectedCode 1
  Check 'out_of_order_rule_is_denied' ($null -eq $early)
  $r1 = Run-Manager @('-Action','record_feedback','-CandidateId',$candidateId,'-SkillId','test-skill','-FeedbackPath',$feedbackPath,'-Root',$root,'-EventLogPath',$eventLog,'-PassThru')
  $r2 = Run-Manager @('-Action','collect_evidence','-CandidateId',$candidateId,'-SkillId','test-skill','-EvidencePath',$evidencePath,'-Root',$root,'-EventLogPath',$eventLog,'-PassThru')
  $r3 = Run-Manager @('-Action','abstract_rule','-CandidateId',$candidateId,'-SkillId','test-skill','-RuleSummary','Require replay before release.','-Root',$root,'-EventLogPath',$eventLog,'-PassThru')
  $r4 = Run-Manager @('-Action','create_patch','-CandidateId',$candidateId,'-SkillId','test-skill','-CandidatePath',$candidatePath,'-Root',$root,'-EventLogPath',$eventLog,'-PassThru')
  $r5 = Run-Manager @('-Action','validate','-CandidateId',$candidateId,'-SkillId','test-skill','-CandidatePath',$candidatePath,'-Root',$root,'-EventLogPath',$eventLog,'-PassThru')
  $r6 = Run-Manager @('-Action','auto_release','-CandidateId',$candidateId,'-SkillId','test-skill','-CandidatePath',$candidatePath,'-Root',$root,'-EventLogPath',$eventLog,'-PassThru')
  Check 'low_risk_candidate_auto_releases' ($r6.automatic_promotion -eq $true -and $r6.production_change -eq $false)
  $r7 = Run-Manager @('-Action','rollback','-CandidateId',$candidateId,'-SkillId','test-skill','-RollbackRef','.qianlima/snapshots/self-evolution-baseline','-Reason','synthetic regression','-Root',$root,'-EventLogPath',$eventLog,'-PassThru')
  $status = Run-Manager @('-Action','status','-CandidateId',$candidateId,'-SkillId','test-skill','-Root',$root,'-EventLogPath',$eventLog,'-PassThru')
  Check 'full_state_machine_reaches_rollback' ($status.state -eq 'rolled_back')
  Check 'production_change_never_enabled' ((Get-Content -LiteralPath $eventLog -Raw) -notmatch '"production_change":true')
  Check 'original_feedback_and_candidate_remain' ((Test-Path $feedbackPath) -and (Test-Path $candidatePath))
  Check 'event_log_is_append_only' (@(Get-Content -LiteralPath $eventLog).Count -eq 7)
} catch {
  Check 'unexpected_test_error' $false
  Write-Error $_
} finally {
  Remove-Item -LiteralPath $feedbackPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $candidatePath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $evidencePath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $eventLog -Force -ErrorAction SilentlyContinue
}
$failed = @($checks | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ passed = $failed.Count -eq 0; checks = $checks }
$checks | ForEach-Object { Write-Host ("{0}: {1}" -f $_.name, $(if ($_.passed) { 'PASS' } else { 'FAIL' })) }
if (-not $result.passed) { exit 1 }
