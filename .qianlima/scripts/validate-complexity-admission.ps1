<##
.SYNOPSIS
  Validates whether new Agent or pipeline complexity is admissible.
.DESCRIPTION
  This Overlay gate requires measured independent value, explicit contracts,
  failure terminals, simulation evidence, an independent verifier, and rollback.
  It never edits production rules or starts an Agent.
##>
param(
  [Parameter(Mandatory = $true)] [string]$ProposalPath,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$contract = Get-Content -LiteralPath (Join-Path $projectRoot '.qianlima\specifications\complexity-admission-contract.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$proposalRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\evolution\candidates')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$resolved = (Resolve-Path -LiteralPath $ProposalPath -ErrorAction Stop).Path
if (-not $resolved.StartsWith($proposalRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Complexity proposal must be inside the isolated candidate scope.' }
$raw = Get-Content -LiteralPath $resolved -Raw -Encoding UTF8
$proposal = $raw | ConvertFrom-Json
$violations = [System.Collections.Generic.List[string]]::new()
function Add-Violation([string]$Id) { [void]$violations.Add($Id) }
function Has-Value($Object, [string]$Name) {
  if ($null -eq $Object) { return $false }
  $property = @($Object.PSObject.Properties | Where-Object { $_.Name -eq $Name }) | Select-Object -First 1
  if ($null -eq $property -or $null -eq $property.Value) { return $false }
  if ($property.Value -is [string]) { return -not [string]::IsNullOrWhiteSpace([string]$property.Value) }
  return $true
}
function Is-SafeEvidence([string]$Ref) { return ([string]$Ref -match '^\.qianlima/evolution/eval-cases/' -and [string]$Ref -notmatch '(?i)(private|raw|secret|customer|browser[_-]?export)') }
foreach ($field in @($contract.required_fields)) { if (-not (Has-Value $proposal $field)) { Add-Violation "missing_$field" } }
if ((Has-Value $proposal 'lifecycle_state') -and @($contract.lifecycle_states).IndexOf([string]$proposal.lifecycle_state) -lt 0) { Add-Violation 'invalid_lifecycle_state' }
if ((Has-Value $proposal 'change_type') -and @($contract.allowed_change_types).IndexOf([string]$proposal.change_type) -lt 0) { Add-Violation 'invalid_change_type' }
if ((Has-Value $proposal 'target_layer') -and @($contract.allowed_target_layers).IndexOf([string]$proposal.target_layer) -lt 0) { Add-Violation 'invalid_target_layer' }
if ([bool]$proposal.single_agent_sufficient) { Add-Violation 'unnecessary_complexity_when_single_agent_sufficient' }
if (-not (Has-Value $proposal.independent_benefit 'measured_metric') -or -not (Has-Value $proposal.independent_benefit 'baseline_value') -or -not (Has-Value $proposal.independent_benefit 'candidate_value') -or [bool]$proposal.independent_benefit.proven -ne $true) { Add-Violation 'independent_benefit_not_measured' }
foreach ($field in @('schema_ref', 'accepted_inputs', 'rejected_inputs')) { if (-not (Has-Value $proposal.input_contract $field)) { Add-Violation "input_contract_missing_$field" } }
foreach ($field in @('schema_ref', 'produced_artifacts', 'verification_status')) { if (-not (Has-Value $proposal.output_contract $field)) { Add-Violation "output_contract_missing_$field" } }
if (-not (Has-Value $proposal 'failure_terminals') -or @($proposal.failure_terminals).Count -lt 1) { Add-Violation 'failure_terminals_missing' }
foreach ($terminal in @($proposal.failure_terminals)) { foreach ($field in @('condition', 'terminal_state', 'authority_action')) { if (-not (Has-Value $terminal $field)) { Add-Violation "failure_terminal_missing_$field" } }; if ([string]$terminal.terminal_state -notin @('frozen', 'rejected', 'needs_human', 'failed', 'cancelled')) { Add-Violation 'invalid_failure_terminal_state' } }
foreach ($field in @($contract.required_simulation_fields)) { if (-not (Has-Value $proposal.simulation_evidence $field)) { Add-Violation "simulation_missing_$field" } }
if ((Has-Value $proposal.simulation_evidence 'status') -and [string]$proposal.simulation_evidence.status -ne 'passed') { Add-Violation 'simulation_not_passed' }
if ((Has-Value $proposal.simulation_evidence 'report_ref') -and -not (Is-SafeEvidence ([string]$proposal.simulation_evidence.report_ref))) { Add-Violation 'simulation_evidence_not_sanitized' }
if ((Has-Value $proposal.simulation_evidence 'source_classification') -and @($contract.allowed_evidence_classifications).IndexOf([string]$proposal.simulation_evidence.source_classification) -lt 0) { Add-Violation 'simulation_classification_forbidden' }
if (-not (Has-Value $proposal.independent_verifier 'verifier_id') -or -not (Has-Value $proposal.independent_verifier 'independence_basis')) { Add-Violation 'independent_verifier_missing' }
if ([string]$proposal.independent_verifier.verifier_id -eq [string]$proposal.proposed_by_agent_id) { Add-Violation 'self_verification_forbidden' }
if (-not (Has-Value $proposal.rollback_plan 'rollback_ref') -or -not (Has-Value $proposal.rollback_plan 'trigger')) { Add-Violation 'rollback_plan_incomplete' }
if ([bool]$proposal.permission_impact.expands_permissions) { $approvalStatus = [string]$proposal.human_approval.status; $approvalRef = [string]$proposal.human_approval.approval_ref; if ($approvalStatus -ne 'approved' -or [string]::IsNullOrWhiteSpace($approvalRef)) { Add-Violation 'permission_expansion_without_approval' } }
if ([bool]$proposal.proposed_change.auto_apply -or [bool]$proposal.proposed_change.production_change) { Add-Violation 'automatic_production_change_forbidden' }
if ([bool]$proposal.privacy.raw_data_included -or [bool]$proposal.privacy.secrets_included -or [bool]$proposal.privacy.sanitized -ne $true) { Add-Violation 'private_or_raw_evidence_forbidden' }
foreach ($field in @($contract.prohibited_fields)) { if ($raw -match ('(?i)"' + [regex]::Escape($field) + '"\s*:')) { Add-Violation "prohibited_field_$field" } }
$status = if ($violations.Count -eq 0) { 'passed' } else { 'blocked' }
$result = [ordered]@{ status = $status; proposal_id = $proposal.proposal_id; lifecycle_state = $proposal.lifecycle_state; violations = @($violations); production_change = $false; external_calls = $false; raw_private_evidence_recorded = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
if ($status -ne 'passed') { exit 1 }
