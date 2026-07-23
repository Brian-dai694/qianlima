<##
.SYNOPSIS
  Evaluates whether a personal-edition automation candidate is suitable for a bounded pilot.
.DESCRIPTION
  This is an offline selection and measurement gate. It does not calculate
  business ROI from generic benchmarks and never executes a candidate.
##>
param(
  [Parameter(Mandatory = $true)] [string]$CandidatePath,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$contractPath = Join-Path $projectRoot '.qianlima\specifications\personal-project-value-contract.json'
$contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
$candidate = Get-Content -LiteralPath $CandidatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$issues = [System.Collections.Generic.List[string]]::new()
$signals = [System.Collections.Generic.List[string]]::new()

function Get-Field($Object, [string]$Name) {
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}
function Add-Issue([string]$Value) { if (-not $issues.Contains($Value)) { [void]$issues.Add($Value) } }

$projectId = [string](Get-Field $candidate 'project_id')
if ([string]::IsNullOrWhiteSpace($projectId)) { Add-Issue 'project_id_required' }
foreach ($signal in $contract.project_selection.required_signals) {
  if ((Get-Field $candidate $signal) -eq $true) { [void]$signals.Add([string]$signal) } else { Add-Issue "selection_signal_missing_$signal" }
}
if ((Get-Field $candidate 'industry_benchmark_only') -eq $true) { Add-Issue 'industry_benchmark_not_local_proof' }
if ((Get-Field $candidate 'claims_staff_replacement') -eq $true) { Add-Issue 'staff_replacement_is_not_a_success_claim' }
if ((Get-Field $candidate 'baseline_refs')) {
  if (@($candidate.baseline_refs).Count -lt 1) { Add-Issue 'baseline_ref_required' }
} else { Add-Issue 'baseline_ref_required' }
if ((Get-Field $candidate 'evidence_refs')) {
  if (@($candidate.evidence_refs).Count -lt 1) { Add-Issue 'evidence_ref_required' }
} else { Add-Issue 'evidence_ref_required' }

$hardBlocker = $false
if ((Get-Field $candidate 'rollback_available') -ne $true) { $hardBlocker = $true; Add-Issue 'rollback_unavailable' }
if ((Get-Field $candidate 'risk_isolatable') -ne $true) { $hardBlocker = $true; Add-Issue 'risk_not_isolatable' }
if ((Get-Field $candidate 'human_verification_point') -ne $true) { $hardBlocker = $true; Add-Issue 'human_verification_missing' }

$score = $signals.Count
$decision = 'needs_more_evidence'
if ($hardBlocker -or @($issues | Where-Object { $_ -in @('industry_benchmark_not_local_proof', 'staff_replacement_is_not_a_success_claim') }).Count -gt 0) {
  $decision = 'blocked'
} elseif ($score -ge [int]$contract.project_selection.minimum_positive_signals -and $issues.Count -eq 0) {
  $decision = 'eligible_for_readonly_pilot'
}

$result = [ordered]@{
  status = 'evaluation_only'
  project_id = $projectId
  decision = $decision
  selection_score = $score
  minimum_positive_signals = [int]$contract.project_selection.minimum_positive_signals
  positive_signals = @($signals)
  issues = @($issues)
  baseline_refs = @((Get-Field $candidate 'baseline_refs'))
  metric_plan = $contract.metrics
  human_check_point = ((Get-Field $candidate 'human_verification_point') -eq $true)
  rollback_condition = if ((Get-Field $candidate 'rollback_condition')) { [string](Get-Field $candidate 'rollback_condition') } else { 'required' }
  evidence_refs = @((Get-Field $candidate 'evidence_refs'))
  external_calls = $false
  business_writes = $false
  permissions_granted = $false
  production_changes = $false
}
if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
