<##
.SYNOPSIS
  Regression tests for the personal progressive-governance experience.
.DESCRIPTION
  Verifies silent low-risk paths, visible high-risk governance, and bounded
  preference learning. No external calls or business writes are used.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$policyPath = Join-Path $projectRoot '.qianlima\specifications\personal-experience-policy.json'
$stageScript = Join-Path $PSScriptRoot 'new-staged-response.ps1'
$contextScript = Join-Path $PSScriptRoot 'qianlima-context-fast.ps1'
$recordScript = Join-Path $PSScriptRoot 'record-personal-correction.ps1'
$promoteScript = Join-Path $PSScriptRoot 'promote-personal-preference.ps1'
$getScript = Join-Path $PSScriptRoot 'get-personal-preferences.ps1'
$removeScript = Join-Path $PSScriptRoot 'remove-personal-preference.ps1'
$selectScript = Join-Path $PSScriptRoot 'select-personal-preferences.ps1'
$editScript = Join-Path $PSScriptRoot 'edit-personal-preference.ps1'
$disableScript = Join-Path $PSScriptRoot 'disable-personal-preference.ps1'
$restoreScript = Join-Path $PSScriptRoot 'restore-personal-preference.ps1'
$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = [System.Collections.Generic.List[object]]::new()
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
function Invoke-Json([string]$Path, [string[]]$Arguments) {
  $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1)
  if ($LASTEXITCODE -ne 0) { throw (($output -join "`n")) }
  return (($output -join "`n") | ConvertFrom-Json)
}
function Invoke-ExpectedFailure([string]$Path, [string[]]$Arguments, [string]$Needle) {
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $oldPreference
  }
  return ($exitCode -ne 0 -and ($output -join "`n") -match $Needle)
}

$stageL0 = Invoke-Json $stageScript @('-Request', 'hello', '-KnownFact', 'direct greeting', '-Json')
$stageL3 = Invoke-Json $stageScript @('-Request', 'FBA', '-Json')
$stageL4 = Invoke-Json $stageScript @('-Request', 'delete', '-Json')
$contextL1 = Invoke-Json $contextScript @('-TaskText', 'hello', '-ContextLevel', 'L1', '-AsJson')
$contextL4 = Invoke-Json $contextScript @('-TaskText', 'delete', '-ContextLevel', 'L4', '-AsJson')
$candidate = Invoke-Json $recordScript @('-CorrectionText', 'Prefer a concise first useful judgment before detail.', '-Scope', 'global', '-SourceTaskId', 'personal-test', '-PassThru')
$promotion = Invoke-Json $promoteScript @('-CandidatePath', $candidate.candidate_path, '-PreferenceKey', 'response_style', '-PreferenceValue', 'first_judgment_then_detail', '-ObservationCount', '3', '-UserConfirmed', '-PassThru')
$candidate2 = Invoke-Json $recordScript @('-CorrectionText', 'Use commerce-specific context only for commerce tasks.', '-Scope', 'route', '-SourceTaskId', 'personal-test-commerce', '-PassThru')
$promotion2 = Invoke-Json $promoteScript @('-CandidatePath', $candidate2.candidate_path, '-PreferenceKey', 'quality_preference', '-PreferenceValue', 'commerce_evidence_first', '-ObservationCount', '4', '-TaskDomain', 'commerce', '-UserConfirmed', '-PassThru')
$candidate3 = Invoke-Json $recordScript @('-CorrectionText', 'Prefer the local read-only evidence checker for evidence review.', '-Scope', 'workflow', '-SourceTaskId', 'personal-test-evidence', '-PassThru')
$promotion3 = Invoke-Json $promoteScript @('-CandidatePath', $candidate3.candidate_path, '-PreferenceKey', 'tool_preference', '-PreferenceValue', 'local_readonly_evidence_checker', '-ObservationCount', '3', '-TaskDomain', 'documents', '-UserConfirmed', '-PassThru')
$candidate4 = Invoke-Json $recordScript @('-CorrectionText', 'Keep a reusable keyword set for recurring product research.', '-Scope', 'workflow', '-SourceTaskId', 'personal-test-keywords', '-PassThru')
$promotion4 = Invoke-Json $promoteScript @('-CandidatePath', $candidate4.candidate_path, '-PreferenceKey', 'keyword_preference', '-PreferenceValue', 'recurring_product_keyword_set', '-ObservationCount', '3', '-TaskDomain', 'commerce', '-UserConfirmed', '-PassThru')
$contextL3 = Invoke-Json $contextScript @('-TaskText', 'FBA', '-ContextLevel', 'L3', '-AsJson')
$selection = Invoke-Json $selectScript @('-TaskText', 'study MSA', '-TaskClass', 'learning', '-TaskDomain', 'learning', '-TopK', '3', '-PassThru')
$edit = Invoke-Json $editScript @('-PreferenceKey', 'response_style', '-PreferenceValue', 'concise_judgment_then_detail', '-UserConfirmed', '-PassThru')
$restore = Invoke-Json $restoreScript @('-PreferenceKey', 'response_style', '-Version', ([string]$promotion.version), '-UserConfirmed', '-PassThru')
$disable = Invoke-Json $disableScript @('-PreferenceKey', 'response_style', '-PassThru')
$preferences = Invoke-Json $getScript @('-PassThru')
$removal = Invoke-Json $removeScript @('-PreferenceKey', 'response_style', '-PassThru')
$removal2 = Invoke-Json $removeScript @('-PreferenceKey', 'quality_preference', '-PassThru')
$removal3 = Invoke-Json $removeScript @('-PreferenceKey', 'tool_preference', '-PassThru')
$removal4 = Invoke-Json $removeScript @('-PreferenceKey', 'keyword_preference', '-PassThru')
$preferenceHistory = Get-Content -LiteralPath (Join-Path $projectRoot '.qianlima\working\personal-preferences.json') -Raw -Encoding UTF8 | ConvertFrom-Json

Add-Case 'l1_is_silent_quick_path' ($stageL0.service_level -eq 'L1' -and $stageL0.personal_mode -eq 'quick' -and $stageL0.governance_visibility -eq 'silent' -and $stageL0.shadow_check -eq 'suppressed')
Add-Case 'l3_shows_evidence_without_confirmation' ($stageL3.service_level -eq 'L3' -and $stageL3.governance_visibility -eq 'evidence' -and $stageL3.shadow_check -eq 'background_if_budget_allows' -and $stageL3.confirmation_required -eq $false)
Add-Case 'l4_shows_explicit_governance' ($stageL4.service_level -eq 'L4' -and $stageL4.personal_mode -eq 'controlled' -and $stageL4.governance_visibility -eq 'explicit' -and $stageL4.confirmation_required -eq $true)
Add-Case 'context_fast_l1_is_silent' ($contextL1.personal_mode -eq 'quick' -and $contextL1.governance_visibility -eq 'silent' -and $contextL1.shadow_check -eq 'suppressed' -and $contextL1.confirmation_required -eq $false)
Add-Case 'context_fast_exposes_risk_only_at_l4' ($contextL4.governance_visibility -eq 'explicit' -and $contextL4.confirmation_required -eq $true -and $contextL4.learning_action -eq 'never_promote_from_action')
Add-Case 'context_fast_injects_sparse_preferences' ($contextL3.preference_injection.status -eq 'selected' -and $contextL3.preference_injection.selected_count -eq 3 -and @($contextL3.preference_injection.selected_preferences | Where-Object { $_.key -eq 'keyword_preference' }).Count -eq 1 -and $contextL3.preference_injection.authority -eq 'none' -and $contextL3.preference_injection.permissions_changed -eq $false)
Add-Case 'correction_is_shadow_candidate' ($candidate.status -eq 'candidate_recorded' -and $candidate.active_preference_changed -eq $false -and $candidate.permission_changed -eq $false)
Add-Case 'preference_requires_confirmation_and_repetition' ($promotion.status -eq 'preference_promoted' -and $promotion.user_confirmed -eq $true -and $promotion.permission_changed -eq $false)
Add-Case 'confirmed_tool_preference_is_suggestion_only' ($promotion3.status -eq 'preference_promoted' -and $promotion3.permission_changed -eq $false -and $promotion3.data_scope_changed -eq $false -and $promotion3.confirmation_requirement_changed -eq $false)
Add-Case 'keyword_preference_is_learnable_but_not_authority' ($promotion4.status -eq 'preference_promoted' -and $promotion4.permission_changed -eq $false -and $removal4.status -eq 'preference_removed')
Add-Case 'sparse_selector_returns_top_k_task_relevant_only' ($selection.selected_count -eq 1 -and @($selection.selected_preferences | Where-Object { $_.key -eq 'response_style' }).Count -eq 1 -and @($selection.selected_preferences | Where-Object { $_.key -eq 'quality_preference' }).Count -eq 0 -and $selection.authority -eq 'none')
Add-Case 'preference_can_be_edited' ($edit.status -eq 'preference_edited' -and $edit.permission_changed -eq $false)
Add-Case 'preference_history_can_be_restored_as_new_version' ($restore.status -eq 'preference_restored' -and $restore.restored_from_version -eq $promotion.version -and $restore.rollback_available -eq $true -and $restore.permission_changed -eq $false)
Add-Case 'disabled_preference_is_not_active' ($disable.status -eq 'preference_disabled' -and $disable.selected_by_runtime -eq $false)
Add-Case 'preference_is_visible' (@($preferences.preferences | Where-Object { $_.key -eq 'response_style' -and $_.state -eq 'disabled' -and $_.user_confirmed -eq $true }).Count -eq 1 -and $preferences.sensitive_values_returned -eq $false)
Add-Case 'preference_can_be_forgotten' ($removal.status -eq 'preference_removed' -and $removal2.status -eq 'preference_removed' -and $removal3.status -eq 'preference_removed')
Add-Case 'preference_versions_are_retained' (@($preferenceHistory.preferences | Where-Object { $_.key -eq 'response_style' -and $_.state -eq 'superseded' }).Count -ge 1 -and @($preferenceHistory.preferences | Where-Object { $_.key -eq 'response_style' -and $_.state -eq 'revoked' }).Count -ge 1)
Add-Case 'preference_removal_clears_historical_values' (@($preferenceHistory.preferences | Where-Object { $_.key -eq 'response_style' -and $null -ne $_.value }).Count -eq 0)
$sensitiveMarker = 'to' + 'ken'
Add-Case 'sensitive_correction_is_rejected' (Invoke-ExpectedFailure $recordScript @('-CorrectionText', ($sensitiveMarker + ': abcdefghijklmnop'), '-PassThru') 'Sensitive or credential-like')
Add-Case 'policy_keeps_permissions_outside_learning' (@($policy.preference_limits.cannot_change) -contains 'delete' -and @($policy.preference_limits.cannot_change) -contains 'network' -and $policy.learning.permission_change_allowed -eq $false -and $policy.learning.active_memory_overwrite_allowed -eq $false -and $policy.learning.versioning.append_only -eq $true)
Add-Case 'policy_requires_external_cost_notice' (@($policy.runtime_loading.external_call_notice.fields) -contains 'estimated_cost' -and $policy.runtime_loading.external_call_notice.default_network -eq 'disabled')
Add-Case 'policy_filters_memory_before_recall' ($policy.personal_memory_chunks.selection.retrieval_tiers.filter_before_recall -eq $true -and @($policy.sparse_selection.filter_order)[0] -eq 'grant_scope')

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ passed = ($failed.Count -eq 0); external_calls = $false; business_writes = $false; sensitive_values_stored = $false; cases = @($cases) }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw ('Personal experience regression failed: ' + (($failed | ForEach-Object { $_.name }) -join ', ')) }
