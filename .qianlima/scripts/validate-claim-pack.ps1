<#
.SYNOPSIS
  Validates a structured evidence-first Claim Pack.
#>
param([Parameter(Mandatory=$true)][string]$ClaimPackPath,[switch]$PassThru)
$ErrorActionPreference='Stop';$pack=Get-Content -LiteralPath $ClaimPackPath -Raw -Encoding UTF8|ConvertFrom-Json;$issues=[System.Collections.Generic.List[string]]::new()
foreach($field in @('claim_pack_id','fusion_id','task_id','producer_employee_id','producer_agent_id','producer_model_id','producer_model_version','work_order_ref','grant_ref','source_refs','data_time_range','assumptions','uncertainties','falsifiers','method_ref','status')){if($null -eq $pack.$field -or [string]::IsNullOrWhiteSpace([string]$pack.$field)){[void]$issues.Add($field+'_required')}}
if(@($pack.claims).Count -lt 1){[void]$issues.Add('claims_required')}
if([string]$pack.status -notin @('candidate','partially_verified','verified','conflicting','rejected')){[void]$issues.Add('invalid_status')}
foreach($claim in @($pack.claims)){foreach($field in @('claim_id','statement','source_refs','confidence','uncertainty','falsifiers')){if($null -eq $claim.$field -or [string]::IsNullOrWhiteSpace([string]$claim.$field)){[void]$issues.Add('claim_'+$field+'_required')}}}
$result=[ordered]@{status=if($issues.Count -eq 0){'accepted_as_candidate'}else{'rejected'};claim_pack_id=$pack.claim_pack_id;issues=@($issues);production_authority='none';external_calls=$false;permissions_granted=$false};if($PassThru){$result|ConvertTo-Json -Depth 8}else{[PSCustomObject]$result|Format-List};if($issues.Count){exit 1}
