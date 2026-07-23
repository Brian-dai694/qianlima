<#
.SYNOPSIS
  Evaluates evidence strength and disagreement without model voting.
#>
param([Parameter(Mandatory=$true)][string]$InputPath,[switch]$PassThru)
$ErrorActionPreference='Stop';$input=Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8|ConvertFrom-Json;$issues=[System.Collections.Generic.List[string]]::new()
if(@($input.claim_pack_refs).Count -lt 1){[void]$issues.Add('claim_pack_refs_required')};if(@($input.source_refs).Count -lt 1){[void]$issues.Add('source_refs_required')};if([string]$input.verifier_id -eq [string]$input.producer_id){[void]$issues.Add('independent_verifier_required')};if([string]::IsNullOrWhiteSpace([string]$input.adversarial_checker_id)){[void]$issues.Add('adversarial_checker_required')}
$strong=([double]$input.evidence_strength -ge 0.70 -and [bool]$input.sources_traceable -and [bool]$input.falsifiers_present);$high=([string]$input.disagreement_level -eq 'high')
$decision=if($issues.Count){'rejected'}elseif(-not$high-and$strong){'verified'}elseif(-not$high){'low_confidence'}elseif([bool]$input.supplementable){'evidence_required'}else{'needs_human'}
$result=[ordered]@{status=$decision;fusion_id=$input.fusion_id;issues=@($issues);disagreement_preserved=$high;additional_budget_proposal=($decision-eq'evidence_required');additional_budget_granted=$false;primary_result_affected=$false;external_write=$false;permissions_granted=$false;production_authority='none'};if($PassThru){$result|ConvertTo-Json -Depth 8}else{[PSCustomObject]$result|Format-List};if($issues.Count){exit 1}
