<#
.SYNOPSIS
  Validates a JSON Fusion Plan against risk and evidence-first boundaries.
#>
param([Parameter(Mandatory=$true)][string]$PlanPath,[switch]$PassThru)
$ErrorActionPreference='Stop'
$plan=Get-Content -LiteralPath $PlanPath -Raw -Encoding UTF8|ConvertFrom-Json
$issues=[System.Collections.Generic.List[string]]::new()
if([string]::IsNullOrWhiteSpace($plan.fusion_id)){[void]$issues.Add('fusion_id_required')}
if([string]::IsNullOrWhiteSpace($plan.task_id)){[void]$issues.Add('task_id_required')}
if(@($plan.selected_models).Count -lt 1){[void]$issues.Add('selected_models_required')}
if(@($plan.selected_models|Sort-Object -Unique).Count -ne @($plan.selected_models).Count){[void]$issues.Add('duplicate_model_is_not_independent')}
if([string]$plan.fusion_method -notin @('evidence_first_claim_pack','independent_claims_then_verification')){[void]$issues.Add('unsupported_fusion_method')}
if([string]$plan.verifier -eq 'producer_self'){[void]$issues.Add('producer_cannot_verify_self')}
if([string]$plan.risk_level -in @('L0','L1','L2')){[void]$issues.Add('fusion_denied_for_L0_L2')}
if([string]$plan.risk_level -eq 'L3' -and @($plan.selected_models).Count -lt 2){[void]$issues.Add('L3_requires_independent_candidates')}
if([string]$plan.risk_level -in @('L3','L4') -and @($plan.claim_pack_refs).Count -lt @($plan.selected_models).Count){[void]$issues.Add('claim_pack_ref_required_per_candidate')}
if([string]$plan.risk_level -eq 'L4' -and [string]$plan.human_approval_requirement -ne 'required'){[void]$issues.Add('L4_human_approval_required')}
if([string]$plan.data_classification -notin @('public','internal_sanitized','confidential_reference_only')){[void]$issues.Add('invalid_data_classification')}
$result=[ordered]@{status=if($issues.Count -eq 0){if([string]$plan.risk_level -eq 'L4'){'needs_human'}else{'approved'}}else{'rejected'};fusion_id=$plan.fusion_id;issues=@($issues);external_calls=$false;permissions_granted=$false}
if($PassThru){$result|ConvertTo-Json -Depth 8}else{[PSCustomObject]$result|Format-List}
if($issues.Count -gt 0){exit 1}
