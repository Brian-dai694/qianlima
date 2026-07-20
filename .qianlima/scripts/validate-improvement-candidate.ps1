<##
.SYNOPSIS
  Validates an isolated, sanitized improvement candidate.
.DESCRIPTION
  This Overlay validator checks evidence, independence, privacy, rollback,
  permission impact, and the core Harness boundary. It never edits a target
  file and never promotes a candidate.
##>
param(
  [Parameter(Mandatory = $true)] [string]$CandidatePath,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$contractPath = Join-Path $projectRoot '.qianlima\specifications\improvement-candidate-contract.json'
$boundaryPath = Join-Path $projectRoot '.qianlima\harness-boundary.json'
$candidateRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\evolution\candidates')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\evolution\eval-cases')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
$boundary = Get-Content -LiteralPath $boundaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$resolved = Resolve-Path -LiteralPath $CandidatePath -ErrorAction Stop
$fullPath = [string]$resolved.Path
if (-not $fullPath.StartsWith($candidateRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Improvement candidate must be inside .qianlima/evolution/candidates.' }
$raw = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8
$candidate = $raw | ConvertFrom-Json
$violations = [System.Collections.Generic.List[string]]::new()
function Add-Violation([string]$Id) { [void]$violations.Add($Id) }
function Has-Value($Object, [string]$Name) {
  if ($null -eq $Object) { return $false }
  $property = @($Object.PSObject.Properties | Where-Object { $_.Name -eq $Name }) | Select-Object -First 1
  if ($null -eq $property -or $null -eq $property.Value) { return $false }
  if ($property.Value -is [string]) { return -not [string]::IsNullOrWhiteSpace([string]$property.Value) }
  return $true
}
function NonEmpty([object[]]$Values) { return ($null -ne $Values -and @($Values).Count -gt 0) }
function Normalize([string]$Value) {
  $normalized = (($Value -replace '\\', '/') -replace '/+', '/')
  if ($normalized.StartsWith('./', [StringComparison]::Ordinal)) { $normalized = $normalized.Substring(2) }
  return $normalized.TrimStart('/')
}
function Is-AllowedPattern([string]$RelativePath) {
  foreach ($allowed in @($contract.approved_target_patterns)) {
    $pattern = '^' + [regex]::Escape([string]$allowed).Replace('\*', '.*') + '$'
    if ($RelativePath -match $pattern) { return $true }
  }
  return $false
}
function Is-EvidenceRefAllowed([string]$Reference) {
  $normalized = Normalize $Reference
  return $normalized.StartsWith('.qianlima/evolution/eval-cases/', [StringComparison]::OrdinalIgnoreCase) -and
    -not ($normalized -match '(?i)(private|raw|secret|confidential|customer|browser[_-]?export)')
}

foreach ($field in @($contract.required_fields)) { if (-not (Has-Value $candidate $field)) { Add-Violation "missing_$field" } }
if ((Has-Value $candidate 'candidate_id') -and [string]$candidate.candidate_id -notmatch '^[A-Za-z0-9._-]{3,120}$') { Add-Violation 'invalid_candidate_id' }
if ((Has-Value $candidate 'candidate_version') -and [string]$candidate.candidate_version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { Add-Violation 'invalid_candidate_version' }
if ((Has-Value $candidate 'lifecycle_state') -and @($contract.lifecycle_states).IndexOf([string]$candidate.lifecycle_state) -lt 0) { Add-Violation 'invalid_lifecycle_state' }
if ((Has-Value $candidate 'target_layer') -and @($contract.allowed_target_layers).IndexOf([string]$candidate.target_layer) -lt 0) { Add-Violation 'invalid_target_layer' }
if ((-not (Has-Value $candidate 'target_files')) -or (-not (NonEmpty @($candidate.target_files)))) { Add-Violation 'target_files_empty' }
foreach ($target in @($candidate.target_files)) {
  $relative = Normalize ([string]$target)
  if ([IO.Path]::IsPathRooted([string]$target) -or $relative -match '(^|/)\.\.(?:/|$)') { Add-Violation 'target_path_not_relative' }
  if ($relative -match '(?i)^\.qianlima/evolution/') { Add-Violation 'candidate_cannot_target_evolution_store' }
  $protected = @($boundary.protected_files | Where-Object { (Normalize ([string]$_.path)) -eq $relative }).Count -gt 0
  if ($protected) { Add-Violation "target_core_protected_$relative" }
  elseif (-not (Is-AllowedPattern $relative)) { Add-Violation "target_outside_overlay_$relative" }
}
if (Has-Value $candidate 'proposed_change') {
  if ([bool]$candidate.proposed_change.auto_apply) { Add-Violation 'automatic_production_change_forbidden' }
  if ([bool]$candidate.proposed_change.production_change) { Add-Violation 'production_change_declared' }
  if (([string]$candidate.proposed_change.apply_mode -notin @('shadow_only', 'candidate_only', 'human_release_only'))) { Add-Violation 'invalid_apply_mode' }
}
foreach ($benefit in @('quality', 'latency', 'cost')) { if (-not (Has-Value $candidate.expected_benefit $benefit)) { Add-Violation "expected_benefit_missing_$benefit" } }
if (-not (Has-Value $candidate 'baseline_version')) { Add-Violation 'baseline_version_missing' }
if ((-not (Has-Value $candidate 'tested_with')) -or (-not (NonEmpty @($candidate.tested_with)))) { Add-Violation 'tested_with_missing' }
$testedAgents = @($candidate.tested_with | ForEach-Object { if (Has-Value $_ 'provider_or_agent') { [string]$_.provider_or_agent } elseif (Has-Value $_ 'agent_id') { [string]$_.agent_id } })
foreach ($tested in @($candidate.tested_with)) {
  foreach ($field in @('provider_or_agent', 'model_or_version', 'test_date', 'result')) { if (-not (Has-Value $tested $field)) { Add-Violation "tested_with_missing_$field" } }
  if ((Has-Value $tested 'result') -and ([string]$tested.result -notin @('passed', 'pending', 'partial', 'failed'))) { Add-Violation 'invalid_tested_with_result' }
}
if (-not (Has-Value $candidate 'proposed_by_agent_id')) { Add-Violation 'proposed_by_agent_missing' }
if (-not (Has-Value $candidate.independent_verifier 'verifier_id')) { Add-Violation 'independent_verifier_missing' }
if (-not (Has-Value $candidate.independent_verifier 'independence_basis')) { Add-Violation 'independence_basis_missing' }
if (Has-Value $candidate.independent_verifier 'verifier_id') {
  $verifierId = [string]$candidate.independent_verifier.verifier_id
  if ($verifierId -eq [string]$candidate.proposed_by_agent_id -or @($testedAgents | Where-Object { $_ -eq $verifierId }).Count -gt 0) { Add-Violation 'self_verification_forbidden' }
}
foreach ($suite in @($contract.required_evaluations)) {
  $evaluation = $candidate.evaluation.$suite
  if (-not (Has-Value $candidate.evaluation $suite)) { Add-Violation "evaluation_missing_$suite"; continue }
  if ((-not (Has-Value $evaluation 'status')) -or [string]$evaluation.status -ne 'passed') { Add-Violation "evaluation_not_passed_$suite" }
  if ((-not (Has-Value $evaluation 'report_ref')) -or (-not (Is-EvidenceRefAllowed ([string]$evaluation.report_ref)))) { Add-Violation "evaluation_evidence_not_sanitized_$suite" }
  if ((-not (Has-Value $evaluation 'case_count')) -or [int]$evaluation.case_count -lt 1) { Add-Violation "evaluation_case_count_invalid_$suite" }
  if ((Has-Value $evaluation 'source_classification') -and @($contract.allowed_evidence_classifications).IndexOf([string]$evaluation.source_classification) -lt 0) { Add-Violation "evaluation_classification_forbidden_$suite" }
}
if (Has-Value $candidate.evaluation 'latency_regression') {
  $latency = $candidate.evaluation.latency_regression
  if ((Has-Value $latency 'baseline_first_useful_output_ms') -and (Has-Value $latency 'candidate_first_useful_output_ms') -and [int]$latency.candidate_first_useful_output_ms -gt [int]$latency.baseline_first_useful_output_ms) { Add-Violation 'first_useful_output_slower' }
}
if ((Has-Value $candidate.evaluation 'L4_safety') -and [bool]$candidate.evaluation.L4_safety.gate_weakened) { Add-Violation 'L4_gate_weakened' }
if ((-not (Has-Value $candidate.rollback_plan 'rollback_version')) -or (-not (Has-Value $candidate.rollback_plan 'rollback_ref')) -or (-not (Has-Value $candidate.rollback_plan 'trigger')) -or (-not (Has-Value $candidate.rollback_plan 'snapshot_ref'))) { Add-Violation 'rollback_plan_incomplete' }
if ($null -ne $candidate.permission_impact) {
  if (-not (Has-Value $candidate.permission_impact 'attack_surface_change')) { Add-Violation 'attack_surface_impact_missing' }
  if ([bool]$candidate.permission_impact.expands_permissions) {
    $approvalStatus = if ($null -ne $candidate.human_approval) { [string]$candidate.human_approval.status } else { '' }
    $approvalRef = if ($null -ne $candidate.human_approval) { [string]$candidate.human_approval.approval_ref } else { '' }
    if ($approvalStatus -ne 'approved' -or [string]::IsNullOrWhiteSpace($approvalRef)) { Add-Violation 'permission_expansion_without_explicit_approval' }
  }
}
if ((-not (Has-Value $candidate.human_approval 'status')) -or ([string]$candidate.human_approval.status -notin @('pending', 'approved', 'rejected'))) { Add-Violation 'invalid_human_approval_state' }
if ($null -ne $candidate.privacy) {
  if ([bool]$candidate.privacy.raw_data_included -or [bool]$candidate.privacy.secrets_included -or [bool]$candidate.privacy.sanitized -ne $true) { Add-Violation 'private_or_raw_evidence_forbidden' }
  if ((Has-Value $candidate.privacy 'source_classification') -and @($contract.allowed_evidence_classifications).IndexOf([string]$candidate.privacy.source_classification) -lt 0) { Add-Violation 'privacy_classification_forbidden' }
}
foreach ($field in @($contract.prohibited_field_names)) { if ($raw -match ('(?i)"' + [regex]::Escape($field) + '"\s*:')) { Add-Violation "prohibited_field_$field" } }
if ($raw -match '(?i)([A-Z]:\\Users\\|/Users/|/home/|-----BEGIN .*PRIVATE KEY-----|sk-[A-Za-z0-9_-]{20,})') { Add-Violation 'raw_private_value_or_path_detected' }
$status = if ($violations.Count -eq 0) { 'passed' } else { 'blocked' }
$result = [ordered]@{ status = $status; candidate_id = if (Has-Value $candidate 'candidate_id') { $candidate.candidate_id } else { $null }; candidate_content_sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant(); lifecycle_state = if (Has-Value $candidate 'lifecycle_state') { $candidate.lifecycle_state } else { $null }; contract_version = $contract.contract_version; violations = @($violations); production_change = $false; automatic_promotion = $false; raw_private_evidence_recorded = $false; external_calls = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
if ($status -ne 'passed') { exit 1 }
