<##
.SYNOPSIS
  Validates a tax, customs, or product-compliance MCP request without calling MCP.
##>
param(
  [ValidateSet('tax','customs','product_compliance')][string]$Domain,
  [ValidateSet('query_official_rules','validate_evidence_pack','prepare_draft','submit_official','amend_official','cancel_official')][string]$Operation,
  [string]$McpServerId='',[string]$GrantId='',[string]$OfficialSourceRefs='',[string]$CredentialRef='',
  [string]$ResponsibleOwnerId='',[ValidateSet('tax_owner','customs_owner','compliance_owner','none')][string]$ResponsibleOwnerRole='none',
  [string]$HumanApprovalRef='',[string]$IdempotencyKey='',[string]$CompensationPlanRef='',
  [switch]$ServerAllowlisted,[switch]$DedicatedSubmissionAdapter,[switch]$PassThru
)
$ErrorActionPreference='Stop';$reasons=[System.Collections.Generic.List[string]]::new();foreach($field in @(@{n='mcp_server_id';v=$McpServerId},@{n='grant_id';v=$GrantId},@{n='official_source_refs';v=$OfficialSourceRefs},@{n='credential_ref';v=$CredentialRef})){if([string]::IsNullOrWhiteSpace($field.v)){[void]$reasons.Add("missing_$($field.n)")}}
if(-not $ServerAllowlisted){[void]$reasons.Add('mcp_server_not_allowlisted')};if($CredentialRef-match'[\s:/\\]'-or $CredentialRef-match'(?i)^(sk-|bearer|basic)'){[void]$reasons.Add('credential_must_be_reference_only')}
$level=if($Operation-in@('submit_official','amend_official','cancel_official')){'L4'}else{'L3'};$expectedRole=@{tax='tax_owner';customs='customs_owner';product_compliance='compliance_owner'}[$Domain]
if($level-eq'L4'){if(-not $DedicatedSubmissionAdapter){[void]$reasons.Add('dedicated_submission_adapter_required')};if([string]::IsNullOrWhiteSpace($ResponsibleOwnerId)-or $ResponsibleOwnerRole-ne$expectedRole){[void]$reasons.Add("responsible_owner_required:$expectedRole")};foreach($field in @(@{n='human_approval_ref';v=$HumanApprovalRef},@{n='idempotency_key';v=$IdempotencyKey},@{n='compensation_plan_ref';v=$CompensationPlanRef})){if([string]::IsNullOrWhiteSpace($field.v)){[void]$reasons.Add("missing_$($field.n)")}}}
$result=[PSCustomObject]@{status=if($reasons.Count-eq 0){'allowed'}else{'blocked'};domain=$Domain;operation=$Operation;required_level=$level;business_owner_required=$false;mcp_called=$false;reasons=@($reasons)};if($PassThru){$result|ConvertTo-Json -Depth 6}else{$result|Format-List};if($reasons.Count-gt 0){exit 1}
