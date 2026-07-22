<##
.SYNOPSIS
  Validates an enterprise file or business-system connection before use.
.DESCRIPTION
  Routine task artifacts and internal collaboration are not treated as formal
  business-state changes. L4 actions use responsibility-routed approval.
##>
param(
  [Parameter(Mandatory=$true)][ValidateSet('managed_local_folder','smb_nas','sharepoint_onedrive','lark_drive','object_storage','business_api','database_warehouse','event_stream','temporary_download')][string]$Type,
  [Parameter(Mandatory=$true)][ValidateSet('list_selected','read_selected','download_to_task_sandbox','query_readonly','cross_source_query','external_sanitized_transfer','write_task_artifact','delete_task_cache','upload_internal_project','write_new_version','send_internal','overwrite_source','send_external','business_write','delete_business_record')][string]$Operation,
  [ValidateSet('public','internal_sanitized','confidential_reference_only','restricted_secret')][string]$DataClassification='public',
  [ValidateSet('zone_1_local','zone_2_internal','zone_3_approved_cloud','zone_4_external')][string]$NetworkZone='zone_1_local',
  [ValidateSet('none','routine_reversible','data_external')][string]$ApprovalProfile='none',
  [string]$EndpointRef='',[string]$CredentialRef='',[string]$OwnerId='',[string]$OrganizationId='',[string]$CostCenter='',
  [string]$GrantId='',[ValidateSet('missing','verified','expired','revoked')][string]$AttestationStatus='missing',
  [string]$ApproverRoles='',[string]$BatchApprovalId='',[ValidateSet('none','valid','expired','revoked')][string]$BatchApprovalStatus='none',[switch]$WithinApprovedThreshold,
  [string]$SnapshotOrIdempotencyRef='',[string]$RollbackOrCompensationRef='',
  [switch]$Enabled,[switch]$DirectAgentAccess,[switch]$PassThru
)
$ErrorActionPreference='Stop';$reasons=[System.Collections.Generic.List[string]]::new()
if(-not $Enabled){[void]$reasons.Add('connection_disabled')};if($DirectAgentAccess){[void]$reasons.Add('direct_agent_connection_denied')}
foreach($field in @(@{n='endpoint_ref';v=$EndpointRef},@{n='credential_ref';v=$CredentialRef},@{n='owner_id';v=$OwnerId},@{n='organization_id';v=$OrganizationId},@{n='cost_center';v=$CostCenter})){if([string]::IsNullOrWhiteSpace($field.v)){[void]$reasons.Add("missing_$($field.n)")}}
if($EndpointRef-match'://.*@'-or $EndpointRef-match'(?i)(password|token|api[_-]?key)='){[void]$reasons.Add('endpoint_contains_credentials')};if($CredentialRef-match'[\s:/\\]'-or $CredentialRef-match'(?i)^(sk-|bearer|basic)'){[void]$reasons.Add('credential_must_be_reference_id_only')}
if($DataClassification-eq'restricted_secret'){[void]$reasons.Add('restricted_secret_connection_denied')};if($NetworkZone-eq'zone_4_external'-and $DataClassification-notin@('public','internal_sanitized')){[void]$reasons.Add('external_zone_data_class_denied')}
$level=if($Operation-in@('overwrite_source','send_external','business_write','delete_business_record')){'L4'}elseif($Operation-in@('cross_source_query','external_sanitized_transfer','upload_internal_project','write_new_version','send_internal')){'L3'}elseif($Operation-eq'list_selected'){'L1'}else{'L2'}
if($level-in@('L2','L3','L4')){if([string]::IsNullOrWhiteSpace($GrantId)){[void]$reasons.Add('task_grant_required')};if($AttestationStatus-ne'verified'){[void]$reasons.Add('verified_attestation_required')}}
if($level-eq'L4'){
  $expectedProfile=if($Operation-eq'send_external'){'data_external'}else{'routine_reversible'};if($ApprovalProfile-ne$expectedProfile){[void]$reasons.Add("approval_profile_required:$expectedProfile")}
  if([string]::IsNullOrWhiteSpace($SnapshotOrIdempotencyRef)){[void]$reasons.Add('snapshot_or_idempotency_required')};if([string]::IsNullOrWhiteSpace($RollbackOrCompensationRef)){[void]$reasons.Add('rollback_or_compensation_required')}
  $roles=@(($ApproverRoles-split',')|ForEach-Object{$_.Trim()}|Where-Object{$_}|Sort-Object -Unique);$validBatch=$ApprovalProfile-eq'routine_reversible'-and $BatchApprovalStatus-eq'valid'-and $WithinApprovedThreshold-and-not[string]::IsNullOrWhiteSpace($BatchApprovalId)
  if(-not $validBatch){if($ApprovalProfile-eq'routine_reversible'-and @($roles|Where-Object{$_-in@('department_manager','data_owner','technical_owner','business_owner')}).Count-eq 0){[void]$reasons.Add('routine_responsible_role_required')};if($ApprovalProfile-eq'data_external'){if($roles-notcontains'data_owner'){[void]$reasons.Add('data_owner_approval_required')};if($DataClassification-eq'confidential_reference_only'-and $roles-notcontains'security_admin'){[void]$reasons.Add('security_approval_required_for_confidential_external_send')}}}
}
$result=[PSCustomObject]@{status=if($reasons.Count-eq 0){'allowed'}else{'blocked'};required_level=$level;connection_type=$Type;operation=$Operation;approval_route=if($level-ne'L4'){'workflow_policy'}elseif($validBatch){'valid_batch_approval'}else{'responsible_owner'};business_owner_required=$false;reasons=@($reasons);network_opened=$false;execution_authorized=$false};if($PassThru){$result|ConvertTo-Json -Depth 6}else{$result|Format-List};if($reasons.Count-gt 0){exit 1}
