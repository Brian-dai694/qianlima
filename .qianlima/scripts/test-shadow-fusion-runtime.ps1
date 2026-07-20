param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = Join-Path $projectRoot '.qianlima\run-traces'
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
$fusionId = "shadow-fusion-$stamp"
$taskId = "shadow-task-$stamp"
$planPath = Join-Path $traceRoot "shadow-plan-$stamp.json"
$packAPath = Join-Path $traceRoot "shadow-pack-a-$stamp.json"
$packBPath = Join-Path $traceRoot "shadow-pack-b-$stamp.json"
$runner = Join-Path $PSScriptRoot 'invoke-shadow-fusion.ps1'

$plan = [ordered]@{ fusion_id = $fusionId; task_id = $taskId; risk_level = 'L3'; selected_models = @('model-a', 'model-b'); selection_reason = 'Test independent candidates.'; independence_requirement = 'distinct_provider_or_version'; allowed_input_refs = @('evidence:public-1'); data_classification = 'public'; candidate_budget = [ordered]@{ max_calls = 4; max_cost_usd = 1 }; fusion_method = 'evidence_first_claim_pack'; verifier = 'evidence_checker'; claim_pack_refs = @('claim-pack:model-a', 'claim-pack:model-b'); stop_conditions = @('evidence_sufficient', 'conflict_found'); human_approval_requirement = 'not_required'; status = 'draft' }
function New-Pack([string]$ModelId, [string]$Statement, [int]$Latency) { [ordered]@{ claim_pack_id = "pack-$ModelId-$stamp"; fusion_id = $fusionId; task_id = $taskId; producer_employee_id = "employee-$ModelId"; producer_agent_id = "agent-$ModelId"; producer_model_id = $ModelId; producer_model_version = 'test-v1'; work_order_ref = "work-$ModelId"; grant_ref = "grant-$ModelId"; claims = @([ordered]@{ claim_id = 'recommendation'; statement = $Statement; source_refs = @('evidence:public-1'); confidence = 0.7; uncertainty = 'Test-only uncertainty.'; falsifiers = @('Independent evidence disagrees.') }); source_refs = @('evidence:public-1'); data_time_range = 'test-only'; assumptions = @('Public test reference is valid.'); uncertainties = @('No production input.'); falsifiers = @('Independent evidence disagrees.'); method_ref = 'evidence-first-claim-pack'; status = 'candidate'; metrics = [ordered]@{ estimated_cost_usd = 0.01; total_latency_ms = $Latency } } }
[IO.File]::WriteAllText($planPath, ($plan | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($packAPath, ((New-Pack 'model-a' 'Candidate A recommends further evidence collection.' 120) | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($packBPath, ((New-Pack 'model-b' 'Candidate B recommends human review before any conclusion.' 180) | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$result = & $runner -FusionPlanPath $planPath -ClaimPackPath @($packAPath, $packBPath) -PassThru | ConvertFrom-Json
$cases = @(
  [PSCustomObject]@{ name = 'conflict_preserved'; passed = (@($result.material_conflicts).Count -eq 1 -and $result.shadow_status -eq 'needs_human') },
  [PSCustomObject]@{ name = 'metrics_aggregated'; passed = ($result.candidate_count -eq 2 -and $result.estimated_cost_usd -eq 0.02 -and $result.total_latency_ms -eq 180) },
  [PSCustomObject]@{ name = 'no_execution_authority'; passed = ($result.adoption_authority -eq 'none' -and $result.primary_result_affected -eq $false -and $result.external_calls -eq $false -and $result.permissions_granted -eq $false) }
)
$failed = @($cases | Where-Object { -not $_.passed })
$output = [PSCustomObject]@{ passed = ($failed.Count -eq 0); cases = $cases; external_calls = $false; permissions_granted = $false }
if ($PassThru) { $output | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw "Shadow fusion runtime regression failed: $($failed.name -join ', ')" }
