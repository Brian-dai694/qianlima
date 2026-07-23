<# .SYNOPSIS Offline regression for the governed employee-Agent evidence fan-in. #>
param([switch]$PassThru)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$tmp = Join-Path $root '.qianlima\tmp\governed-fan-in'
$trace = Join-Path $root '.qianlima\run-traces'
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$runner = Join-Path $PSScriptRoot 'invoke-governed-collaboration-fan-in.ps1'
$stamp = [Guid]::NewGuid().ToString('n')

function Write-Json($path, $value) { [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false)) }
function Participant($role,$employee,$agent,$model,$provider,$error,$n) { [ordered]@{role=$role;employee_id=$employee;agent_id=$agent;model_id=$model;model_version='v1';provider_family=$provider;error_group=$error;work_order_ref="work:$n";grant_ref="grant:$n"} }
function New-Pack($taskId,$fusionId,$employee,$agent,$model,$n,$statement) { [ordered]@{claim_pack_id="pack-$model-$stamp";fusion_id=$fusionId;task_id=$taskId;producer_employee_id=$employee;producer_agent_id=$agent;producer_model_id=$model;producer_model_version='v1';work_order_ref="work:$n";grant_ref="grant:$n";claims=@([ordered]@{claim_id='decision';statement=$statement;source_refs=@('evidence:public');confidence=.8;uncertainty='test';falsifiers=@('source changes')});source_refs=@('evidence:public');data_time_range='test';assumptions=@('test source valid');uncertainties=@('test only');falsifiers=@('source changes');method_ref='evidence-first';status='candidate';metrics=[ordered]@{estimated_cost_usd=0;total_latency_ms=1}} }
function Run-Case($name,$correlationValue,$samples,$mutatePack,$mutateCorrelation) {
  $taskId="task-$name-$stamp";$fusionId="fusion-$name-$stamp"
  $collaboration=[ordered]@{collaboration_id="collab-$name-$stamp";task_id=$taskId;fusion_id=$fusionId;risk_level='L3';participants=@((Participant manager emp-m agent-m model-m local coordination 1),(Participant candidate emp-a agent-a model-a provider-a factual 2),(Participant candidate emp-b agent-b model-b provider-b causal 3),(Participant independent_verifier emp-v agent-v model-v provider-v verification 4),(Participant adversarial_checker emp-d agent-d model-d provider-d adversarial 5));manager_employee_id='emp-m';final_adoption_authority='qianlima_broker';direct_agent_to_agent='deny';status='draft'}
  $plan=[ordered]@{fusion_id=$fusionId;task_id=$taskId;risk_level='L3';selected_models=@('model-a','model-b');selection_reason='independent evidence';independence_requirement='historical_error_independence';allowed_input_refs=@('evidence:public');data_classification='public';candidate_budget=[ordered]@{max_calls=2;max_cost_usd=0};fusion_method='evidence_first_claim_pack';verifier='agent-v';claim_pack_refs=@('pack-a','pack-b');stop_conditions=@('conflict_found');human_approval_requirement='not_required';status='draft'}
  $packA=New-Pack $taskId $fusionId emp-a agent-a model-a 2 'collect more evidence'
  $packB=New-Pack $taskId $fusionId emp-b agent-b model-b 3 'require human review'
  if ($mutatePack) { & $mutatePack $packB }
  $corr=[ordered]@{task_type='market_analysis';members=@([ordered]@{id='model-a';error_group='factual'},[ordered]@{id='model-b';error_group='causal'});pairwise_correlations=@([ordered]@{left='model-a';right='model-b';critical_error_correlation=$correlationValue;sample_size=$samples})}
  if ($mutateCorrelation) { & $mutateCorrelation $corr }
  $collabPath=Join-Path $tmp "$name-collaboration.json";$planPath=Join-Path $tmp "$name-plan.json";$aPath=Join-Path $tmp "$name-a.json";$bPath=Join-Path $tmp "$name-b.json";$corrPath=Join-Path $tmp "$name-correlation.json";$outPath=Join-Path $trace "fan-in-$name-$stamp.json"
  Write-Json $collabPath $collaboration;Write-Json $planPath $plan;Write-Json $aPath $packA;Write-Json $bPath $packB;Write-Json $corrPath $corr
  try { $output=& $runner -CollaborationPath $collabPath -FusionPlanPath $planPath -ClaimPackPath @($aPath,$bPath) -ErrorCorrelationPath $corrPath -OutputPath $outPath -PassThru 2>&1; $code=0 } catch { $output=@($_.Exception.Message);$code=1 }
  [pscustomobject]@{code=$code;text=($output -join "`n");output_path=$outPath}
}

$eligible=Run-Case eligible .2 10 $null $null
$insufficient=Run-Case insufficient .2 2 $null $null
$correlated=Run-Case correlated .8 10 $null $null
$lineage=Run-Case bad_lineage .2 10 { param($pack) $pack.producer_agent_id='agent-unbound' } $null
$identityMismatch=Run-Case identity_mismatch .2 10 $null { param($corr) $corr.members[1].id='model-unbound';$corr.pairwise_correlations[0].right='model-unbound' }
$immutable=Run-Case immutable .2 10 $null $null
try { $immutableRetry=& $runner -CollaborationPath (Join-Path $tmp "immutable-collaboration.json") -FusionPlanPath (Join-Path $tmp "immutable-plan.json") -ClaimPackPath @((Join-Path $tmp "immutable-a.json"),(Join-Path $tmp "immutable-b.json")) -ErrorCorrelationPath (Join-Path $tmp "immutable-correlation.json") -OutputPath $immutable.output_path -PassThru 2>&1;$immutableCode=0 } catch { $immutableRetry=$_.Exception.Message;$immutableCode=1 }
$eligibleReceipt=Get-Content -LiteralPath $eligible.output_path -Raw -Encoding UTF8|ConvertFrom-Json
$cases=@(
  [pscustomobject]@{name='eligible_team_reaches_governed_fan_in';passed=($eligible.code-eq0-and$eligible.text-match'disputed_outcome')},
  [pscustomobject]@{name='insufficient_history_remains_shadow_only';passed=($insufficient.code-eq0-and$insufficient.text-match'shadow_only_insufficient_history')},
  [pscustomobject]@{name='high_error_correlation_stops_before_fusion';passed=($correlated.code-ne0)},
  [pscustomobject]@{name='claim_pack_lineage_mismatch_rejected';passed=($lineage.code-ne0)},
  [pscustomobject]@{name='correlation_identity_must_match_collaboration';passed=($identityMismatch.code-ne0)},
  [pscustomobject]@{name='outcome_receipt_is_immutable';passed=($immutable.code-eq0-and$immutableCode-ne0)},
  [pscustomobject]@{name='receipt_arrays_and_shadow_hash_are_stable';passed=($eligibleReceipt.accepted_claim_refs -is [array]-and@($eligibleReceipt.accepted_claim_refs).Count-eq0-and[string]$eligibleReceipt.shadow_report_sha256-match'^[a-f0-9]{64}$')},
  [pscustomobject]@{name='fan_in_has_no_adoption_or_permission_authority';passed=($eligible.text-match'"adoption_authority"\s*:\s*"none"'-and$eligible.text-match'"permissions_granted"\s*:\s*false')}
)
$failed=@($cases|Where-Object{-not$_.passed});$result=[pscustomobject]@{passed=($failed.Count-eq0);cases=$cases;external_calls=$false;permissions_granted=$false};if($PassThru){$result|ConvertTo-Json -Depth 8}else{$cases|Format-Table -AutoSize};if($failed.Count){throw('Governed collaboration fan-in regression failed: '+(($failed.name)-join', '))}
