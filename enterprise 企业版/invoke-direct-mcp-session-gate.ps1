<##
.SYNOPSIS
  Validates a Broker-signed direct MCP session without opening a connection.
##>
param(
  [string]$SessionGrantId='',[string]$BusinessOwnerApprovalRef='',[string]$OrganizationId='',[string]$EmployeeId='',[string]$TaskId='',[string]$AgentId='',[string]$AgentVersion='',[string]$DeviceId='',
  [string]$ServerId='',[string]$ServerVersion='',[string]$ExpectedServerVersion='',[string]$ToolManifestHash='',[string]$ExpectedToolManifestHash='',
  [string]$AllowedTools='',[string]$RequestedTool='',[string]$DataScope='',[string]$ExpiresAt='',
  [ValidateSet('active','revoked','expired','missing')][string]$GrantStatus='missing',
  [switch]$ConnectorVerified,[switch]$BudgetAvailable,[switch]$WriteRequested,[switch]$DedicatedWriteAdapter,[switch]$PassThru
)
$ErrorActionPreference='Stop';$reasons=[System.Collections.Generic.List[string]]::new();foreach($field in @(@{n='session_grant_id';v=$SessionGrantId},@{n='business_owner_approval_ref';v=$BusinessOwnerApprovalRef},@{n='organization_id';v=$OrganizationId},@{n='employee_id';v=$EmployeeId},@{n='task_id';v=$TaskId},@{n='agent_id';v=$AgentId},@{n='agent_version';v=$AgentVersion},@{n='device_id';v=$DeviceId},@{n='server_id';v=$ServerId},@{n='server_version';v=$ServerVersion},@{n='tool_manifest_hash';v=$ToolManifestHash},@{n='allowed_tools';v=$AllowedTools},@{n='requested_tool';v=$RequestedTool},@{n='data_scope';v=$DataScope},@{n='expires_at';v=$ExpiresAt})){if([string]::IsNullOrWhiteSpace($field.v)){[void]$reasons.Add("missing_$($field.n)")}}
if($GrantStatus-ne'active'){[void]$reasons.Add('direct_session_grant_not_active')};if(-not $ConnectorVerified){[void]$reasons.Add('verified_governance_connector_required')};if(-not $BudgetAvailable){[void]$reasons.Add('direct_session_budget_unavailable')};if($ServerVersion-ne$ExpectedServerVersion){[void]$reasons.Add('mcp_server_version_drift')};if($ToolManifestHash-ne$ExpectedToolManifestHash){[void]$reasons.Add('mcp_tool_manifest_drift')}
$tools=@(($AllowedTools-split',')|ForEach-Object{$_.Trim()}|Where-Object{$_});if($RequestedTool-and $tools-notcontains$RequestedTool){[void]$reasons.Add('requested_tool_outside_session_scope')};if($ExpiresAt){try{if((Get-Date).ToUniversalTime()-ge[DateTime]::Parse($ExpiresAt).ToUniversalTime()){[void]$reasons.Add('direct_session_expired')}}catch{[void]$reasons.Add('invalid_expiry_timestamp')}}
if($WriteRequested-and-not $DedicatedWriteAdapter){[void]$reasons.Add('direct_session_does_not_inherit_write_authority')}
$result=[PSCustomObject]@{status=if($reasons.Count-eq 0){'allowed'}else{'blocked'};organization_id=$OrganizationId;employee_id=$EmployeeId;connection_path='employee_agent_to_local_governance_connector_to_mcp';central_broker_in_data_path=$false;business_owner_approved=(-not[string]::IsNullOrWhiteSpace($BusinessOwnerApprovalRef));connection_opened=$false;reasons=@($reasons)};if($PassThru){$result|ConvertTo-Json -Depth 6}else{$result|Format-List};if($reasons.Count-gt 0){exit 1}
