<##
.SYNOPSIS
  Offline regression for personal project selection and value measurement.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$candidateRoot = Join-Path $projectRoot '.qianlima\working\project-value-tests'
$evaluator = Join-Path $PSScriptRoot 'evaluate-personal-project-candidate.ps1'
New-Item -ItemType Directory -Path $candidateRoot -Force | Out-Null
$cases = [System.Collections.Generic.List[object]]::new()

function Write-JsonFile([string]$Path, $Value) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false)) }
function New-Candidate([string]$Name, [hashtable]$Overrides = @{}) {
  $candidate = [ordered]@{
    project_id = "project-$Name"
    high_frequency = $true
    rule_stability = $true
    historical_samples_available = $true
    measurable_outcome = $true
    rollback_available = $true
    risk_isolatable = $true
    human_verification_point = $true
    baseline_refs = @("baseline-ref:$Name")
    evidence_refs = @("evidence-ref:$Name")
    rollback_condition = 'rework rate exceeds baseline by 10 percent'
    industry_benchmark_only = $false
    claims_staff_replacement = $false
  }
  foreach ($key in $Overrides.Keys) { $candidate[$key] = $Overrides[$key] }
  $path = Join-Path $candidateRoot "$Name.json"
  Write-JsonFile $path $candidate
  return $path
}
function Invoke-Evaluator([string]$Path) { $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $evaluator -CandidatePath $Path -PassThru 2>&1); if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }; return (($output -join "`n") | ConvertFrom-Json) }
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }

$good = Invoke-Evaluator (New-Candidate 'good')
$lowFrequency = Invoke-Evaluator (New-Candidate 'low-frequency' @{ high_frequency = $false })
$noRollback = Invoke-Evaluator (New-Candidate 'no-rollback' @{ rollback_available = $false })
$noHumanCheck = Invoke-Evaluator (New-Candidate 'no-human-check' @{ human_verification_point = $false })
$replacementClaim = Invoke-Evaluator (New-Candidate 'replacement-claim' @{ claims_staff_replacement = $true })
$benchmark = Invoke-Evaluator (New-Candidate 'benchmark' @{ industry_benchmark_only = $true })
$noBaseline = Invoke-Evaluator (New-Candidate 'no-baseline' @{ baseline_refs = @() })

Add-Case 'good_candidate_enters_readonly_pilot' ($good.decision -eq 'eligible_for_readonly_pilot' -and $good.selection_score -eq 7)
Add-Case 'missing_signal_needs_more_evidence' ($lowFrequency.decision -eq 'needs_more_evidence' -and @($lowFrequency.issues) -contains 'selection_signal_missing_high_frequency')
Add-Case 'rollback_is_hard_boundary' ($noRollback.decision -eq 'blocked' -and @($noRollback.issues) -contains 'rollback_unavailable')
Add-Case 'human_verification_is_required' ($noHumanCheck.decision -eq 'blocked' -and @($noHumanCheck.issues) -contains 'human_verification_missing')
Add-Case 'staff_replacement_claim_is_rejected' ($replacementClaim.decision -eq 'blocked' -and @($replacementClaim.issues) -contains 'staff_replacement_is_not_a_success_claim')
Add-Case 'generic_benchmark_is_not_proof' ($benchmark.decision -eq 'blocked' -and @($benchmark.issues) -contains 'industry_benchmark_not_local_proof')
Add-Case 'local_baseline_is_required' ($noBaseline.decision -eq 'needs_more_evidence' -and @($noBaseline.issues) -contains 'baseline_ref_required')
Add-Case 'evaluation_has_no_side_effects' (@($good, $lowFrequency, $noRollback, $noHumanCheck, $replacementClaim, $benchmark, $noBaseline).Where({ $_.external_calls -or $_.business_writes -or $_.permissions_granted -or $_.production_changes }).Count -eq 0)

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ suite = 'personal_project_value'; passed = ($failed.Count -eq 0); total = $cases.Count; passed_count = ($cases.Count - $failed.Count); external_calls = $false; business_writes = $false; cases = @($cases) }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize; Write-Host ("Personal project value: {0}/{1} PASS" -f $result.passed_count, $result.total) }
if ($failed.Count -gt 0) { throw ('Personal project value failed: ' + (($failed | ForEach-Object { $_.name }) -join ', ')) }
