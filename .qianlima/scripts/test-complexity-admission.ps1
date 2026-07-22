<##
.SYNOPSIS
  Regression tests for complexity admission.
  All proposals are synthetic; no Agent, Runner, Docker, or network is started.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $PSScriptRoot 'validate-complexity-admission.ps1'
$root = Join-Path $projectRoot '.qianlima\evolution\candidates'
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
New-Item -ItemType Directory -Path $root -Force | Out-Null
function Write-Json($Value, [string]$Name) { $path = Join-Path $root "$Name-$stamp.json"; [IO.File]::WriteAllText($path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false)); return $path }
function New-Proposal([string]$Name = 'valid') {
  return [ordered]@{
    proposal_id = "complexity-$Name-$stamp"; proposal_version = '1.0.0'; lifecycle_state = 'shadow_converged'; target_layer = 'specification'; change_type = 'new_verifier'; goal = 'Synthetic verifier adds independent evidence coverage.'; single_agent_sufficient = $false
    independent_benefit = [ordered]@{ measured_metric = 'evidence_gap_detection_rate'; baseline_value = 0.60; candidate_value = 0.90; proven = $true }
    input_contract = [ordered]@{ schema_ref = '.qianlima/specifications/trace-contract.json'; accepted_inputs = @('sanitized_trace_metadata'); rejected_inputs = @('raw_prompt','secret_value') }
    output_contract = [ordered]@{ schema_ref = '.qianlima/specifications/trace-contract.json'; produced_artifacts = @('verification_report'); verification_status = 'passed' }
    failure_terminals = @([ordered]@{ condition = 'evidence_conflict'; terminal_state = 'needs_human'; authority_action = 'freeze_and_revoke' }, [ordered]@{ condition = 'budget_exceeded'; terminal_state = 'frozen'; authority_action = 'revoke_and_shrink' })
    permission_impact = [ordered]@{ expands_permissions = $false; changed_capabilities = @(); attack_surface_change = 'none' }
    simulation_evidence = [ordered]@{ status = 'passed'; report_ref = '.qianlima/evolution/eval-cases/complexity-synthetic.json'; case_count = 4; failure_injection_cases = @('grant_expiry','budget_exhaustion','verification_conflict','cancelled_downstream'); terminal_state_checked = $true; source_classification = 'internal_sanitized' }
    independent_verifier = [ordered]@{ verifier_id = 'complexity-independent-evaluator'; independence_basis = 'Separate replay and rule checker.' }; proposed_by_agent_id = 'complexity-proposer'; rollback_plan = [ordered]@{ rollback_ref = '.qianlima/snapshots/complexity-baseline'; trigger = 'Any safety, latency, or evidence regression.' }; human_approval = [ordered]@{ status = 'pending'; approval_ref = $null }; proposed_change = [ordered]@{ auto_apply = $false; production_change = $false }; privacy = [ordered]@{ sanitized = $true; raw_data_included = $false; secrets_included = $false }
  }
}
function Invoke-ExpectedFailure([string]$Path, [string]$Expected) { $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $out = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -ProposalPath $Path -PassThru 2>&1); $code = $LASTEXITCODE; $ErrorActionPreference = $old; return ($code -ne 0 -and ($out -join "`n") -match $Expected) }
function Add-Case([System.Collections.Generic.List[object]]$Cases, [string]$Name, [bool]$Passed) { $Cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
$cases = [System.Collections.Generic.List[object]]::new(); $valid = Write-Json (New-Proposal) 'valid'; $validOut = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -ProposalPath $valid -PassThru | ConvertFrom-Json); Add-Case $cases 'valid_complexity_proposal' ($validOut.status -eq 'passed')
$single = New-Proposal 'single-sufficient'; $single.single_agent_sufficient = $true; Add-Case $cases 'unnecessary_split_blocked' (Invoke-ExpectedFailure (Write-Json $single 'single-sufficient') 'unnecessary_complexity_when_single_agent_sufficient')
$unmeasured = New-Proposal 'unmeasured'; $unmeasured.independent_benefit.proven = $false; Add-Case $cases 'unmeasured_benefit_blocked' (Invoke-ExpectedFailure (Write-Json $unmeasured 'unmeasured') 'independent_benefit_not_measured')
$noTerminal = New-Proposal 'no-terminal'; $noTerminal.failure_terminals = @(); Add-Case $cases 'missing_failure_terminal_blocked' (Invoke-ExpectedFailure (Write-Json $noTerminal 'no-terminal') 'failure_terminals_missing')
$simFail = New-Proposal 'simulation-failure'; $simFail.simulation_evidence.status = 'failed'; Add-Case $cases 'simulation_failure_blocked' (Invoke-ExpectedFailure (Write-Json $simFail 'simulation-failure') 'simulation_not_passed')
$self = New-Proposal 'self-verifier'; $self.independent_verifier.verifier_id = 'complexity-proposer'; Add-Case $cases 'self_verification_blocked' (Invoke-ExpectedFailure (Write-Json $self 'self-verifier') 'self_verification_forbidden')
$expanded = New-Proposal 'permission-expansion'; $expanded.permission_impact.expands_permissions = $true; Add-Case $cases 'permission_expansion_blocked' (Invoke-ExpectedFailure (Write-Json $expanded 'permission-expansion') 'permission_expansion_without_approval')
$auto = New-Proposal 'automatic'; $auto.proposed_change.auto_apply = $true; Add-Case $cases 'automatic_production_change_blocked' (Invoke-ExpectedFailure (Write-Json $auto 'automatic') 'automatic_production_change_forbidden')
$specPath = Join-Path $projectRoot ".qianlima\specifications\drafts\complexity-admission-$stamp.json"; & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'new-agent-admission-spec.ps1') -SpecId "complexity-admission-$stamp" -AgentId evidence_checker -Goal 'Synthetic governed admission integration.' -RiskLevel L2 -OutputPath $specPath | Out-Null; $admission = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'invoke-governed-agent-admission.ps1') -ComplexityProposalPath $valid -SpecPath $specPath -PassThru | ConvertFrom-Json); Add-Case $cases 'complexity_gate_precedes_agent_analysis' ($admission.status -eq 'admission_analyzed' -and $admission.stage -eq 'complexity_then_agent_spec' -and $admission.runner_started -eq $false)
$failed = @($cases | Where-Object { -not $_.passed }); $result = [PSCustomObject]@{ passed = ($failed.Count -eq 0); cases = @($cases); production_change = $false; external_calls = $false; raw_private_evidence_recorded = $false }; if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $cases | Format-Table -AutoSize }; if ($failed.Count -gt 0) { throw "Complexity admission regression failed: $($failed.name -join ', ')" }
