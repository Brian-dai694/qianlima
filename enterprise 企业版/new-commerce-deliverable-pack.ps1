<##
.SYNOPSIS
  Creates an unexecuted commerce deliverable pack for one governed task.
##>
param(
  [Parameter(Mandatory=$true)][string]$TaskId,[Parameter(Mandatory=$true)][string]$TraceId,
  [Parameter(Mandatory=$true)][string]$ProductId,[Parameter(Mandatory=$true)][string]$Marketplace,
  [string]$Locale='en-US',[string]$Currency='USD',[Parameter(Mandatory=$true)][string]$OwnerId,[switch]$PassThru
)
$ErrorActionPreference='Stop'
function Pending([hashtable]$Fields){$item=[ordered]@{status='pending'};foreach($key in $Fields.Keys){$item[$key]=$Fields[$key]};$item}
$pack=[ordered]@{
  schema_version=1;task_id=$TaskId;trace_id=$TraceId;product_id=$ProductId;marketplace=$Marketplace;locale=$Locale;currency=$Currency;owner_id=$OwnerId;created_at=(Get-Date).ToUniversalTime().ToString('o')
  profitability=Pending @{source_refs=@();data_as_of=$null;selling_price=$null;product_cost=$null;inbound_freight=$null;platform_fees=$null;fulfillment_fees=$null;ad_cost_assumption=$null;return_loss_assumption=$null;tax_assumption=$null;contribution_margin=$null;margin_rate=$null;break_even_acos=$null;calculation_ref=$null;verification_status='pending'}
  title=Pending @{text=$null;character_count=0;keyword_refs=@();claim_evidence_refs=@();compliance_status='pending';verification_status='pending'}
  main_image=Pending @{asset_ref=$null;source_asset_refs=@();width=0;height=0;background_policy=$null;product_accuracy_status='pending';compliance_status='pending';verification_status='pending'}
  bullet_points=Pending @{items=@();keyword_refs=@();claim_evidence_refs=@();compliance_status='pending';verification_status='pending'}
  long_description=Pending @{content=$null;structure=@();keyword_refs=@();claim_evidence_refs=@();compliance_status='pending';verification_status='pending'}
  completion_status='partial';external_upload_authorized=$false;price_change_authorized=$false
}
if($PassThru){$pack|ConvertTo-Json -Depth 12}else{$pack|Format-List}
