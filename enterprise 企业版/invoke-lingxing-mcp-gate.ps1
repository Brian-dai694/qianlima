<##
.SYNOPSIS
  Validates a future Lingxing MCP request without opening MCP or network access.
##>
param(
  [ValidateSet('initialization','operations','advertising','finance','supply_chain')][string]$Domain,
  [ValidateSet('read','write')][string]$Mode='read',[string]$ServerId='',[string]$ToolId='',[string]$GrantId='',[string]$ShopScope='',[string]$MarketplaceScope='',[string]$CredentialRef='',
  [string]$ApprovalProfile='',[string]$IdempotencyKey='',[string]$SnapshotRef='',[string]$CompensationRef='',
  [switch]$ServerEnabled,[switch]$ToolAllowlisted,[switch]$VerifiedAttestation,[switch]$DedicatedWriteAdapter,[switch]$PassThru
)
$ErrorActionPreference='Stop';$reasons=[System.Collections.Generic.List[string]]::new();foreach($field in @(@{n='server_id';v=$ServerId},@{n='tool_id';v=$ToolId},@{n='grant_id';v=$GrantId},@{n='shop_scope';v=$ShopScope},@{n='marketplace_scope';v=$MarketplaceScope},@{n='credential_ref';v=$CredentialRef})){if([string]::IsNullOrWhiteSpace($field.v)){[void]$reasons.Add("missing_$($field.n)")}}
if(-not $ServerEnabled){[void]$reasons.Add('lingxing_mcp_server_disabled')};if(-not $ToolAllowlisted){[void]$reasons.Add('lingxing_tool_not_allowlisted')};if(-not $VerifiedAttestation){[void]$reasons.Add('verified_attestation_required')};if($CredentialRef-match'[\s:/\\]'-or $CredentialRef-match'(?i)^(sk-|bearer|basic)'){[void]$reasons.Add('credential_must_be_reference_only')}
$level=if($Mode-eq'write'){'L4'}else{'L2'};if($Mode-eq'write'){if(-not $DedicatedWriteAdapter){[void]$reasons.Add('dedicated_lingxing_write_adapter_required')};foreach($field in @(@{n='approval_profile';v=$ApprovalProfile},@{n='idempotency_key';v=$IdempotencyKey},@{n='snapshot_ref';v=$SnapshotRef},@{n='compensation_ref';v=$CompensationRef})){if([string]::IsNullOrWhiteSpace($field.v)){[void]$reasons.Add("missing_$($field.n)")}}}
$result=[PSCustomObject]@{status=if($reasons.Count-eq 0){'allowed'}else{'blocked'};domain=$Domain;mode=$Mode;required_level=$level;mcp_called=$false;network_opened=$false;reasons=@($reasons)};if($PassThru){$result|ConvertTo-Json -Depth 6}else{$result|Format-List};if($reasons.Count-gt 0){exit 1}
