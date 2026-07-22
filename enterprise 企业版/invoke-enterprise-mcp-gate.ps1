<##
.SYNOPSIS
  Vendor-neutral Enterprise MCP policy gate. It never calls an MCP server.
##>
param(
  [ValidateSet('file_and_cloud_storage','commerce_erp','finance_tax_customs','database_and_bi','advertising_and_marketing','logistics_and_inventory','supplier_and_procurement','collaboration_and_messaging','search_and_research','code_and_devops','identity_and_organization','security_and_compliance')][string]$Category,
  [ValidateSet('discover','read_selected','analyze','cross_source_analyze','prepare_draft','create','update','send','submit','delete')][string]$OperationClass,
  [ValidateSet('public','internal_sanitized','confidential_reference_only','restricted_secret')][string]$DataClassification='public',
  [ValidateSet('zone_1_local','zone_2_internal','zone_3_approved_cloud','zone_4_external')][string]$NetworkZone='zone_1_local',
  [string]$ServerId='',[string]$ServerVersion='',[string]$ExpectedVersion='',[string]$ToolId='',[string]$GrantId='',[string]$CredentialRef='',[string]$DataScope='',
  [string]$ApprovalProfile='',[string]$IdempotencyKey='',[string]$SnapshotOrCompensationRef='',
  [switch]$ServerEnabled,[switch]$ToolAllowlisted,[switch]$VerifiedAttestation,[switch]$DedicatedWriteAdapter,[switch]$BudgetAvailable,[switch]$PassThru
)
$ErrorActionPreference='Stop';$reasons=[System.Collections.Generic.List[string]]::new();foreach($field in @(@{n='server_id';v=$ServerId},@{n='server_version';v=$ServerVersion},@{n='expected_version';v=$ExpectedVersion},@{n='tool_id';v=$ToolId},@{n='grant_id';v=$GrantId},@{n='credential_ref';v=$CredentialRef},@{n='data_scope';v=$DataScope})){if([string]::IsNullOrWhiteSpace($field.v)){[void]$reasons.Add("missing_$($field.n)")}}
if(-not $ServerEnabled){[void]$reasons.Add('mcp_server_disabled')};if(-not $ToolAllowlisted){[void]$reasons.Add('mcp_tool_not_allowlisted')};if(-not $VerifiedAttestation){[void]$reasons.Add('verified_attestation_required')};if(-not $BudgetAvailable){[void]$reasons.Add('mcp_budget_unavailable')};if($ServerVersion-ne$ExpectedVersion){[void]$reasons.Add('mcp_server_version_drift')};if($CredentialRef-match'[\s:/\\]'-or $CredentialRef-match'(?i)^(sk-|bearer|basic)'){[void]$reasons.Add('credential_must_be_reference_only')}
if($DataClassification-eq'restricted_secret'){[void]$reasons.Add('restricted_secret_payload_denied')};if($NetworkZone-eq'zone_4_external'-and $DataClassification-notin@('public','internal_sanitized')){[void]$reasons.Add('external_mcp_data_class_denied')}
$write=$OperationClass-in@('create','update','send','submit','delete');$level=if($write){'L4'}elseif($OperationClass-in@('cross_source_analyze','prepare_draft')){'L3'}elseif($OperationClass-eq'discover'){'L1'}else{'L2'}
if($write){if(-not $DedicatedWriteAdapter){[void]$reasons.Add('dedicated_mcp_write_adapter_required')};foreach($field in @(@{n='approval_profile';v=$ApprovalProfile},@{n='idempotency_key';v=$IdempotencyKey},@{n='snapshot_or_compensation_ref';v=$SnapshotOrCompensationRef})){if([string]::IsNullOrWhiteSpace($field.v)){[void]$reasons.Add("missing_$($field.n)")}}}
$result=[PSCustomObject]@{status=if($reasons.Count-eq 0){'allowed'}else{'blocked'};category=$Category;operation_class=$OperationClass;required_level=$level;write=$write;mcp_called=$false;network_opened=$false;reasons=@($reasons)};if($PassThru){$result|ConvertTo-Json -Depth 6}else{$result|Format-List};if($reasons.Count-gt 0){exit 1}
