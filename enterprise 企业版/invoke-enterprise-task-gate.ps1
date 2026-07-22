<##
.SYNOPSIS
  Classifies and validates a task against Enterprise-specific L0-L4 controls.
.DESCRIPTION
  This gate is fail-closed and performs no Agent, network, file, or business
  action. L4 approval is routed by responsibility and threshold; it does not
  always require the business owner.
##>
param(
  [ValidateSet('L0','L1','L2','L3','L4')] [string]$RequestedLevel = 'L0',
  [ValidateSet('enterprise','personal')] [string]$ClassificationEdition = 'enterprise',
  [ValidateSet('none','public','internal_sanitized','confidential_reference_only','restricted_secret')] [string]$DataClassification = 'none',
  [ValidateSet('self','project','cross_project','cross_department')] [string]$OrganizationalScope = 'self',
  [ValidateSet('conversation','readonly','analysis','recommendation','task_artifact_write','task_cache_delete','internal_project_upload','new_version_write','internal_send','external_send','business_write','source_write','deployment','governance_change','credential_assignment','erp_write','finance_write','purchase')] [string]$ActionType = 'conversation',
  [ValidateSet('none','routine_reversible','data_external','technical_production','financial_material','governance_critical')] [string]$ApprovalProfile = 'none',
  [string]$TenantId = '', [string]$OrganizationId = '', [string]$EmployeeId = '',
  [string]$DeviceId = '', [string]$ProjectId = '', [string]$CostCenter = '',
  [ValidateSet('T0','T1','T2','T3','T4')] [string]$AgentTrust = 'T0',
  [string]$GrantId = '',
  [ValidateSet('missing','verified','expired','revoked')] [string]$AttestationStatus = 'missing',
  [string]$VerifierId = '', [string]$HumanOwnerId = '',
  [string]$ApproverIds = '', [string]$ApproverRoles = '',
  [string]$BatchApprovalId = '', [ValidateSet('none','valid','expired','revoked')] [string]$BatchApprovalStatus = 'none',
  [switch]$WithinApprovedThreshold, [switch]$ThresholdExceeded,
  [string]$SnapshotRef = '', [string]$RollbackRef = '', [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$rank = @{ L0 = 0; L1 = 1; L2 = 2; L3 = 3; L4 = 4 }
$requiredRank = $rank[$RequestedLevel]
$reasons = [System.Collections.Generic.List[string]]::new()
if ($ClassificationEdition -ne 'enterprise') { [void]$reasons.Add('personal_classification_has_no_enterprise_authority') }
if ($DataClassification -eq 'restricted_secret') { [void]$reasons.Add('restricted_secret_is_denied') }
if ($OrganizationalScope -in @('cross_project','cross_department')) { $requiredRank = [Math]::Max($requiredRank, 3) }
if ($DataClassification -eq 'confidential_reference_only') { $requiredRank = [Math]::Max($requiredRank, 3) }
if ($ActionType -in @('task_artifact_write','task_cache_delete')) { $requiredRank = [Math]::Max($requiredRank, 2) }
if ($ActionType -in @('internal_project_upload','new_version_write','internal_send')) { $requiredRank = [Math]::Max($requiredRank, 3) }

$profileByAction = @{
  external_send = 'data_external'; business_write = 'routine_reversible'; source_write = 'routine_reversible'; erp_write = 'routine_reversible'
  deployment = 'technical_production'; finance_write = 'financial_material'; purchase = 'financial_material'
  governance_change = 'governance_critical'; credential_assignment = 'governance_critical'
}
if ($profileByAction.ContainsKey($ActionType)) { $requiredRank = 4; $expectedProfile = $profileByAction[$ActionType] } else { $expectedProfile = 'none' }
$effectiveLevel = @('L0','L1','L2','L3','L4')[$requiredRank]
if ($rank[$RequestedLevel] -lt $requiredRank) { [void]$reasons.Add("requested_level_below_required:$effectiveLevel") }
if ($requiredRank -eq 4 -and $ApprovalProfile -ne $expectedProfile) { [void]$reasons.Add("approval_profile_required:$expectedProfile") }

function Require-Value([string]$Name, [string]$Value) { if ([string]::IsNullOrWhiteSpace($Value)) { [void]$reasons.Add("missing_$Name") } }
if ($requiredRank -ge 1) { Require-Value 'tenant_id' $TenantId; Require-Value 'organization_id' $OrganizationId; Require-Value 'employee_id' $EmployeeId }
if ($requiredRank -ge 2) {
  Require-Value 'device_id' $DeviceId; Require-Value 'project_id' $ProjectId; Require-Value 'cost_center' $CostCenter; Require-Value 'grant_id' $GrantId
  if ($AttestationStatus -ne 'verified') { [void]$reasons.Add('verified_attestation_required') }
}
$trustRank = @{ T0 = 0; T1 = 1; T2 = 2; T3 = 3; T4 = -1 }
$minimumTrust = if ($requiredRank -ge 4) { 3 } elseif ($requiredRank -ge 3) { 2 } elseif ($requiredRank -ge 2) { 1 } else { 0 }
if ($trustRank[$AgentTrust] -lt $minimumTrust) { [void]$reasons.Add("agent_trust_below_required:T$minimumTrust") }
if ($requiredRank -eq 0 -and $DataClassification -notin @('none','public')) { [void]$reasons.Add('L0_enterprise_data_denied') }
if ($requiredRank -eq 1 -and $DataClassification -notin @('none','public')) { [void]$reasons.Add('L1_internal_data_requires_L2') }
if ($requiredRank -ge 3) { Require-Value 'verifier_id' $VerifierId }

$uniqueApprovers = @(($ApproverIds -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
$uniqueRoles = @(($ApproverRoles -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
if ($requiredRank -eq 4) {
  Require-Value 'human_owner_id' $HumanOwnerId; Require-Value 'snapshot_ref' $SnapshotRef; Require-Value 'rollback_ref' $RollbackRef
  if ($uniqueApprovers -contains $EmployeeId) { [void]$reasons.Add('initiator_cannot_approve_enterprise_L4') }
  if ($VerifierId -eq $EmployeeId) { [void]$reasons.Add('initiator_cannot_self_verify') }

  $validBatch = $ApprovalProfile -in @('routine_reversible','technical_production','financial_material') -and -not [string]::IsNullOrWhiteSpace($BatchApprovalId) -and $BatchApprovalStatus -eq 'valid' -and $WithinApprovedThreshold -and -not $ThresholdExceeded
  if (-not $validBatch) {
    if ($uniqueApprovers.Count -lt 1) { [void]$reasons.Add('responsible_approver_required') }
    switch ($ApprovalProfile) {
      'routine_reversible' { if (@($uniqueRoles | Where-Object { $_ -in @('department_manager','data_owner','technical_owner','business_owner') }).Count -eq 0) { [void]$reasons.Add('routine_responsible_role_required') } }
      'data_external' {
        if ($uniqueRoles -notcontains 'data_owner') { [void]$reasons.Add('data_owner_approval_required') }
        if ($DataClassification -eq 'confidential_reference_only' -and $uniqueRoles -notcontains 'security_admin') { [void]$reasons.Add('security_approval_required_for_confidential_external_send') }
      }
      'technical_production' { if ($uniqueRoles -notcontains 'technical_owner') { [void]$reasons.Add('technical_owner_approval_required') }; if ($ThresholdExceeded -and $uniqueRoles -notcontains 'security_admin') { [void]$reasons.Add('security_approval_required_for_critical_deployment') } }
      'financial_material' { if ($uniqueRoles -notcontains 'finance_owner') { [void]$reasons.Add('finance_owner_approval_required') }; if ($ThresholdExceeded -and $uniqueRoles -notcontains 'business_owner') { [void]$reasons.Add('business_owner_required_above_threshold') } }
      'governance_critical' { if ($uniqueRoles -notcontains 'security_admin') { [void]$reasons.Add('security_admin_approval_required') }; if ($uniqueRoles -notcontains 'business_owner') { [void]$reasons.Add('business_owner_approval_required') }; if ($uniqueApprovers.Count -lt 2) { [void]$reasons.Add('two_distinct_approvers_required_for_governance') } }
    }
  }
}
$result = [PSCustomObject]@{ status = if ($reasons.Count -eq 0) { 'allowed' } else { 'blocked' }; edition = 'enterprise'; requested_level = $RequestedLevel; effective_level = $effectiveLevel; approval_profile = $ApprovalProfile; approval_route = if ($requiredRank -eq 4) { if ($validBatch) { 'valid_batch_approval' } else { 'responsible_owner' } } else { 'workflow_policy' }; business_owner_required = ($requiredRank -eq 4 -and ($ApprovalProfile -eq 'governance_critical' -or ($ApprovalProfile -eq 'financial_material' -and $ThresholdExceeded))); reasons = @($reasons); execution_authorized = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 6 } else { $result | Format-List }
if ($reasons.Count -gt 0) { exit 1 }
