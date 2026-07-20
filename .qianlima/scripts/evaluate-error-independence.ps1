<#
.SYNOPSIS
  Evaluates observed critical-error correlation for a candidate model/Agent team.
#>
param([Parameter(Mandatory=$true)][string]$InputPath,[switch]$PassThru)
$ErrorActionPreference='Stop';$x=Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8|ConvertFrom-Json;$issues=[System.Collections.Generic.List[string]]::new();$members=@($x.members);if($members.Count-lt2){[void]$issues.Add('two_candidates_required')};if(@($members.error_group|Sort-Object -Unique).Count-lt2){[void]$issues.Add('distinct_error_groups_required')};$reselect=$false;$insufficient=$false;foreach($pair in @($x.pairwise_correlations)){if([int]$pair.sample_size-lt5){$insufficient=$true};if([int]$pair.sample_size-ge5-and[double]$pair.critical_error_correlation-ge0.70){$reselect=$true}}
$status=if($issues.Count){'rejected'}elseif($reselect){'reselect_required'}elseif($insufficient){'shadow_only_insufficient_history'}else{'eligible_as_independent_candidates'};$r=[ordered]@{status=$status;task_type=$x.task_type;issues=@($issues);permission_change='none';budget_change='none';production_authority='none';external_calls=$false};if($PassThru){$r|ConvertTo-Json -Depth 6}else{[pscustomobject]$r|Format-List};if($issues.Count){exit 1}
