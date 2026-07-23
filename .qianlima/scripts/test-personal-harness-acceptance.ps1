<##
.SYNOPSIS
  Offline acceptance checks for the personal Harness subset.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$contractPath = Join-Path $projectRoot '.qianlima\specifications\personal-harness-acceptance-matrix.json'
$contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = [System.Collections.Generic.List[object]]::new()
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
function Has([object[]]$Items, [string]$Value) { return (@($Items) -contains $Value) }

$scope = @($contract.scope)
$tooling = $contract.layers.T_tooling
$context = $contract.layers.C_context
$lifecycle = $contract.layers.L_lifecycle
$observability = $contract.layers.O_basic_observability
$verification = $contract.layers.V_basic_verification
$pipeline = $contract.two_stage_pipeline

Add-Case 'personal_scope_excludes_enterprise_control_plane' ($contract.edition -eq 'personal' -and @($contract.enterprise_layers_excluded).Count -ge 3 -and $contract.layers.G_personal_progressive.enterprise_controls -eq 'excluded')
Add-Case 'tooling_uses_least_privilege_profiles' ((Has $scope 'T_tooling') -and (Has $tooling.required 'profile_registered') -and (Has $tooling.required 'capability_allowlist') -and (Has $tooling.required 'high_risk_capability_denied_by_default'))
Add-Case 'context_filters_before_recall' ((Has $scope 'C_context') -and (Has $context.required 'grant_filter_before_recall') -and (Has $context.required 'task_relevance_filter') -and (Has $context.required 'minimal_top_k_injection') -and (Has $context.required 'memory_has_no_authority'))
Add-Case 'lifecycle_is_replayable_and_stoppable' ((Has $scope 'L_lifecycle') -and (Has $lifecycle.required 'replayable_reference_inputs') -and (Has $lifecycle.required 'cancel_and_freeze') -and @($lifecycle.required).Count -ge 7)
Add-Case 'observability_stays_minimal' ((Has $scope 'O_basic_observability') -and (Has $observability.required 'trace_id_or_task_id') -and (Has $observability.required 'budget_snapshot') -and $observability.raw_prompt_storage -eq 'disabled_by_default')
Add-Case 'verification_blocks_unproven_results' ((Has $scope 'V_basic_verification') -and (Has $verification.required 'artifact_hash') -and (Has $verification.required 'evidence_receipt') -and $verification.command_success_is_business_success -eq $false)
Add-Case 'cheap_stage_is_local_and_network_free' ($pipeline.cheap_stage.external_calls -eq $false -and $pipeline.cheap_stage.network -eq 'none' -and @($pipeline.cheap_stage.allowed_levels).Count -eq 4)
Add-Case 'review_stage_is_bounded_and_triggered' ((Has $pipeline.review_stage.trigger 'L2_or_higher') -and (Has $pipeline.review_stage.requires 'same_grant_scope') -and $pipeline.review_stage.l0_l1_default -eq 'suppressed')
Add-Case 'personal_progressive_governance_preserves_authority_boundary' ($contract.layers.G_personal_progressive.status -eq 'minimal_personal_only' -and (Has $contract.layers.G_personal_progressive.required 'preferences_cannot_change_authority') -and (Has $contract.layers.G_personal_progressive.required 'high_impact_action_requires_confirmation'))

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ suite = 'personal_harness_acceptance'; passed = ($failed.Count -eq 0); total = $cases.Count; passed_count = ($cases.Count - $failed.Count); external_calls = $false; installations = $false; business_writes = $false; cases = @($cases) }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize; Write-Host ("Personal Harness acceptance: {0}/{1} PASS" -f $result.passed_count, $result.total) }
if ($failed.Count -gt 0) { throw ('Personal Harness acceptance failed: ' + (($failed | ForEach-Object { $_.name }) -join ', ')) }
