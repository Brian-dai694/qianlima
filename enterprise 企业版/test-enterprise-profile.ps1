<#
.SYNOPSIS
  Regression test for the Enterprise Edition overlay profile.
.DESCRIPTION
  Checks that the Enterprise Edition references the shared core, keeps the
  default runtime fail-closed, and remains inside the approved overlay path.
#>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$enterpriseRoot = $PSScriptRoot
$enterpriseDirectoryName = Split-Path -Leaf $enterpriseRoot
$projectRoot = (Resolve-Path (Join-Path $enterpriseRoot '..')).Path
$editionPath = Join-Path $enterpriseRoot 'edition.yaml'
$configPath = Join-Path $enterpriseRoot 'config.example.yaml'
$trustPath = Join-Path $enterpriseRoot 'trust-policy.yaml'
$adapterPath = Join-Path $enterpriseRoot 'governance-adapter.yaml'
$eventPath = Join-Path $enterpriseRoot 'event-contract.json'
$deploymentPath = Join-Path $enterpriseRoot 'deployment-policy.yaml'
$taskLevelPath = Join-Path $enterpriseRoot 'task-level-policy.json'
$taskGatePath = Join-Path $enterpriseRoot 'invoke-enterprise-task-gate.ps1'
$roleTemplatePath = Join-Path $enterpriseRoot 'organization-role-templates.json'
$organizationWizardPath = Join-Path $enterpriseRoot 'new-enterprise-organization.ps1'
$onboardingTextPath = Join-Path $enterpriseRoot 'onboarding-text.zh-CN.json'
$connectionPolicyPath = Join-Path $enterpriseRoot 'connection-policy.json'
$connectionGatePath = Join-Path $enterpriseRoot 'invoke-enterprise-connection-gate.ps1'
$approvalRoutingPath = Join-Path $enterpriseRoot 'approval-routing-policy.json'
$fiveViewPath = Join-Path $enterpriseRoot 'five-view-task-contract.json'
$commercePackPath = Join-Path $enterpriseRoot 'commerce-deliverable-contract.json'
$commerceOperatingPath = Join-Path $enterpriseRoot 'commerce-operating-model.json'
$complianceMcpPath = Join-Path $enterpriseRoot 'compliance-mcp-policy.json'
$lingxingArchitecturePath = Join-Path $enterpriseRoot 'lingxing-business-architecture.json'
$lingxingMcpPath = Join-Path $enterpriseRoot 'lingxing-mcp-adapter-contract.json'
$enterpriseMcpPath = Join-Path $enterpriseRoot 'enterprise-mcp-platform-contract.json'
$obsidianContractPath = Join-Path $enterpriseRoot 'obsidian-connector-contract.json'
$obsidianRegistryPath = Join-Path $enterpriseRoot 'obsidian-connector-registry.example.json'
$obsidianGatePath = Join-Path $enterpriseRoot 'invoke-obsidian-connector-gate.ps1'
$directMcpPath = Join-Path $enterpriseRoot 'direct-mcp-session-contract.json'
$employeeLifecyclePath = Join-Path $enterpriseRoot 'employee-lifecycle-policy.json'
$fileOrganizationPath = Join-Path $enterpriseRoot 'file-organization-policy.json'
$reviewCompoundingPath = Join-Path $enterpriseRoot 'review-compounding-policy.json'
$modelPortfolioPath = Join-Path $projectRoot '.qianlima\model-portfolio.yaml'
$fusionPlanPath = Join-Path $projectRoot '.qianlima\fusion-plan-schema.yaml'
$claimPackPath = Join-Path $projectRoot '.qianlima\claim-pack-schema.yaml'
$evidenceMarketPath = Join-Path $projectRoot '.qianlima\evidence-market-policy.json'
$shadowReceiptPath = Join-Path $projectRoot '.qianlima\shadow-fusion-receipt-schema.yaml'
$shadowRuntimePath = Join-Path $projectRoot '.qianlima\scripts\invoke-shadow-fusion.ps1'
$employeeCollaborationPath = Join-Path $projectRoot '.qianlima\employee-agent-collaboration-schema.yaml'
$shadowProviderRegistryPath = Join-Path $projectRoot '.qianlima\shadow-candidate-provider-registry.json'
$shadowDispatchGatePath = Join-Path $projectRoot '.qianlima\scripts\invoke-shadow-candidate-dispatch-gate.ps1'
$blindspotObservationPath = Join-Path $projectRoot '.qianlima\blindspot-observation-schema.yaml'
$collaborationOutcomePath = Join-Path $projectRoot '.qianlima\collaboration-outcome-receipt-schema.yaml'
$errorIndependenceGatePath = Join-Path $projectRoot '.qianlima\scripts\evaluate-error-independence.ps1'
$governedFanInPath = Join-Path $projectRoot '.qianlima\scripts\invoke-governed-collaboration-fan-in.ps1'
$deploymentModePath = Join-Path $enterpriseRoot 'deployment-mode-policy.json'
$businessCatalogPath = Join-Path $projectRoot '.qianlima\specifications\business-capability-catalog.json'
$boundaryChecker = Join-Path $projectRoot '.qianlima\scripts\check-harness-boundary.ps1'

function Add-Case([System.Collections.Generic.List[object]]$Cases, [string]$Name, [bool]$Passed) {
  $Cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed })
}

if (-not (Test-Path -LiteralPath $editionPath -PathType Leaf)) { throw 'Missing enterprise edition profile.' }
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'Missing enterprise example configuration.' }
if (-not (Test-Path -LiteralPath $trustPath -PathType Leaf)) { throw 'Missing continuous trust policy.' }
if (-not (Test-Path -LiteralPath $adapterPath -PathType Leaf)) { throw 'Missing governance adapter contract.' }
if (-not (Test-Path -LiteralPath $eventPath -PathType Leaf)) { throw 'Missing append-only event contract.' }
if (-not (Test-Path -LiteralPath $deploymentPath -PathType Leaf)) { throw 'Missing enterprise deployment policy.' }
if (-not (Test-Path -LiteralPath $taskLevelPath -PathType Leaf)) { throw 'Missing enterprise task-level policy.' }
if (-not (Test-Path -LiteralPath $taskGatePath -PathType Leaf)) { throw 'Missing enterprise task gate.' }
if (-not (Test-Path -LiteralPath $roleTemplatePath -PathType Leaf)) { throw 'Missing enterprise organization role templates.' }
if (-not (Test-Path -LiteralPath $organizationWizardPath -PathType Leaf)) { throw 'Missing enterprise organization wizard.' }
if (-not (Test-Path -LiteralPath $onboardingTextPath -PathType Leaf)) { throw 'Missing Chinese organization onboarding text.' }
if (-not (Test-Path -LiteralPath $connectionPolicyPath -PathType Leaf)) { throw 'Missing enterprise connection policy.' }
if (-not (Test-Path -LiteralPath $connectionGatePath -PathType Leaf)) { throw 'Missing enterprise connection gate.' }
if (-not (Test-Path -LiteralPath $approvalRoutingPath -PathType Leaf)) { throw 'Missing enterprise approval routing policy.' }
if (-not (Test-Path -LiteralPath $fiveViewPath -PathType Leaf)) { throw 'Missing enterprise five-view task contract.' }
if (-not (Test-Path -LiteralPath $commercePackPath -PathType Leaf)) { throw 'Missing commerce deliverable contract.' }
if (-not (Test-Path -LiteralPath $commerceOperatingPath -PathType Leaf)) { throw 'Missing commerce operating model.' }
if (-not (Test-Path -LiteralPath $complianceMcpPath -PathType Leaf)) { throw 'Missing compliance MCP policy.' }
if (-not (Test-Path -LiteralPath $lingxingArchitecturePath -PathType Leaf)) { throw 'Missing Lingxing business architecture map.' }
if (-not (Test-Path -LiteralPath $lingxingMcpPath -PathType Leaf)) { throw 'Missing Lingxing MCP adapter contract.' }
if (-not (Test-Path -LiteralPath $enterpriseMcpPath -PathType Leaf)) { throw 'Missing vendor-neutral Enterprise MCP platform contract.' }
if (-not (Test-Path -LiteralPath $obsidianContractPath -PathType Leaf)) { throw 'Missing Obsidian connector contract.' }
if (-not (Test-Path -LiteralPath $obsidianRegistryPath -PathType Leaf)) { throw 'Missing disabled Obsidian connector registry example.' }
if (-not (Test-Path -LiteralPath $obsidianGatePath -PathType Leaf)) { throw 'Missing Obsidian connector gate.' }
if (-not (Test-Path -LiteralPath $directMcpPath -PathType Leaf)) { throw 'Missing employee direct MCP session contract.' }
if (-not (Test-Path -LiteralPath $employeeLifecyclePath -PathType Leaf)) { throw 'Missing employee lifecycle policy.' }
if (-not (Test-Path -LiteralPath $fileOrganizationPath -PathType Leaf)) { throw 'Missing file organization policy.' }
if (-not (Test-Path -LiteralPath $reviewCompoundingPath -PathType Leaf)) { throw 'Missing review compounding policy.' }
if (-not (Test-Path -LiteralPath $deploymentModePath -PathType Leaf)) { throw 'Missing API and Agent deployment mode policy.' }
if (-not (Test-Path -LiteralPath $modelPortfolioPath -PathType Leaf)) { throw 'Missing model portfolio policy.' }
if (-not (Test-Path -LiteralPath $fusionPlanPath -PathType Leaf)) { throw 'Missing fusion plan schema.' }
if (-not (Test-Path -LiteralPath $claimPackPath -PathType Leaf)) { throw 'Missing claim pack schema.' }
if (-not (Test-Path -LiteralPath $evidenceMarketPath -PathType Leaf)) { throw 'Missing evidence market policy.' }
if (-not (Test-Path -LiteralPath $shadowReceiptPath -PathType Leaf)) { throw 'Missing shadow fusion receipt schema.' }
if (-not (Test-Path -LiteralPath $shadowRuntimePath -PathType Leaf)) { throw 'Missing shadow fusion runtime.' }
if (-not (Test-Path -LiteralPath $employeeCollaborationPath -PathType Leaf)) { throw 'Missing employee Agent collaboration contract.' }
if (-not (Test-Path -LiteralPath $shadowProviderRegistryPath -PathType Leaf)) { throw 'Missing shadow candidate provider registry.' }
if (-not (Test-Path -LiteralPath $shadowDispatchGatePath -PathType Leaf)) { throw 'Missing shadow candidate dispatch gate.' }
if (-not (Test-Path -LiteralPath $blindspotObservationPath -PathType Leaf)) { throw 'Missing blindspot observation contract.' }
if (-not (Test-Path -LiteralPath $collaborationOutcomePath -PathType Leaf)) { throw 'Missing collaboration outcome receipt contract.' }
if (-not (Test-Path -LiteralPath $errorIndependenceGatePath -PathType Leaf)) { throw 'Missing error independence routing gate.' }
if (-not (Test-Path -LiteralPath $governedFanInPath -PathType Leaf)) { throw 'Missing governed collaboration fan-in.' }
if (-not (Test-Path -LiteralPath $businessCatalogPath -PathType Leaf)) { throw 'Missing shared business capability catalog.' }
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'start-qianlima.ps1') -PathType Leaf)) { throw 'Missing shared core start script.' }

$edition = Get-Content -LiteralPath $editionPath -Raw -Encoding UTF8
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
$trust = Get-Content -LiteralPath $trustPath -Raw -Encoding UTF8
$adapter = Get-Content -LiteralPath $adapterPath -Raw -Encoding UTF8
$events = Get-Content -LiteralPath $eventPath -Raw -Encoding UTF8 | ConvertFrom-Json
$deployment = Get-Content -LiteralPath $deploymentPath -Raw -Encoding UTF8
$taskLevels = Get-Content -LiteralPath $taskLevelPath -Raw -Encoding UTF8 | ConvertFrom-Json
$roleTemplates = Get-Content -LiteralPath $roleTemplatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$onboardingText = Get-Content -LiteralPath $onboardingTextPath -Raw -Encoding UTF8 | ConvertFrom-Json
$connectionPolicy = Get-Content -LiteralPath $connectionPolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json
$approvalRouting = Get-Content -LiteralPath $approvalRoutingPath -Raw -Encoding UTF8 | ConvertFrom-Json
$fiveView = Get-Content -LiteralPath $fiveViewPath -Raw -Encoding UTF8 | ConvertFrom-Json
$commercePack = Get-Content -LiteralPath $commercePackPath -Raw -Encoding UTF8 | ConvertFrom-Json
$commerceOperating = Get-Content -LiteralPath $commerceOperatingPath -Raw -Encoding UTF8 | ConvertFrom-Json
$complianceMcp = Get-Content -LiteralPath $complianceMcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
$lingxingArchitecture = Get-Content -LiteralPath $lingxingArchitecturePath -Raw -Encoding UTF8 | ConvertFrom-Json
$lingxingMcp = Get-Content -LiteralPath $lingxingMcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
$enterpriseMcp = Get-Content -LiteralPath $enterpriseMcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
$obsidianContract = Get-Content -LiteralPath $obsidianContractPath -Raw -Encoding UTF8 | ConvertFrom-Json
$obsidianRegistry = Get-Content -LiteralPath $obsidianRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$directMcp = Get-Content -LiteralPath $directMcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
$employeeLifecycle = Get-Content -LiteralPath $employeeLifecyclePath -Raw -Encoding UTF8 | ConvertFrom-Json
$fileOrganization = Get-Content -LiteralPath $fileOrganizationPath -Raw -Encoding UTF8 | ConvertFrom-Json
$reviewCompounding = Get-Content -LiteralPath $reviewCompoundingPath -Raw -Encoding UTF8 | ConvertFrom-Json
$deploymentModes = Get-Content -LiteralPath $deploymentModePath -Raw -Encoding UTF8 | ConvertFrom-Json
$businessCatalog = Get-Content -LiteralPath $businessCatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = [System.Collections.Generic.List[object]]::new()
Add-Case $cases 'shared_core_reference' ($edition -match '(?m)^\s*shared_core_root:\s*\.\.')
Add-Case $cases 'no_harness_fork' ($edition -match '(?m)^\s*do_not_fork_harness:\s*true\s*$')
Add-Case $cases 'plan_mode_default' ($edition -match '(?m)^\s*mode:\s*plan\s*$' -and $edition -match '(?m)^\s*dry_run:\s*true\s*$')
Add-Case $cases 'network_and_external_a2a_denied' ($edition -match '(?m)^\s*network:\s*deny_by_default\s*$' -and $edition -match '(?m)^\s*external_a2a:\s*disabled\s*$')
Add-Case $cases 'real_execution_attestation_gated' ($edition -match '(?m)^\s*real_execution:\s*disabled_until_attestation\s*$' -and $config -match '(?m)^\s*require_attestation:\s*true\s*$' -and $config -match '(?m)^\s*enable_real_execution:\s*false\s*$')
Add-Case $cases 'secret_reference_only' ($edition -match '(?m)^\s*secret_mode:\s*secret_ref_only\s*$' -and $config -match '(?m)secret_ref_only')
Add-Case $cases 'continuous_trust_before_every_action' ($trust -match '(?m)^evaluation_frequency:\s*before_every_tool_memory_network_artifact_action\s*$' -and $trust -match '(?m)^default_action:\s*deny\s*$')
Add-Case $cases 'single_governance_adapter' ($adapter -match '(?m)^authoritative_control_plane:\s*qianlima_broker\s*$' -and $adapter -match '(?m)^fail_closed:\s*true\s*$')
Add-Case $cases 'append_only_event_lineage' ($events.storage -match 'append_only' -and @($events.required_fields) -contains 'trace_id' -and @($events.allowed_events) -contains 'grant_revoked')
Add-Case $cases 'zero_exposure_default' ($trust -match '(?m)^\s*public_listener:\s*deny\s*$' -and $trust -match '(?m)^\s*broker_initiated_outbound_only:\s*true\s*$')
Add-Case $cases 'push_pull_and_backpressure' ($events.delivery.event_stream_is_source_of_truth -eq $true -and @($events.delivery.pull) -contains 'audit_timeline' -and $events.backpressure.verification_queue_high -eq 'pause_new_multi_agent_delegations')
Add-Case $cases 'managed_environment_required' ($edition -match '(?m)^\s*environment_gate:\s*required_before_enterprise_start\s*$' -and $deployment -match '(?m)^\s*on_failure:\s*block_enterprise_start\s*$')
Add-Case $cases 'deployment_does_not_grant_execution' ($deployment -match '(?m)^\s*deployment_ready_is_execution_authority:\s*false\s*$' -and $deployment -match '(?m)^\s*task_bound_attestation_still_required:\s*true\s*$')
Add-Case $cases 'enterprise_levels_distinct_from_personal' ($taskLevels.edition -eq 'enterprise' -and $taskLevels.personal_classification_authority -eq 'deny')
Add-Case $cases 'enterprise_l4_responsibility_routing' ($taskLevels.levels.L4.minimum_distinct_approvers -eq 1 -and $taskLevels.levels.L4.business_owner_required -eq 'only_by_profile_or_threshold' -and $taskLevels.levels.L4.initiator_may_approve -eq $false)
Add-Case $cases 'beginner_role_templates' (@($roleTemplates.roles).Count -eq 4 -and @($roleTemplates.roles.id) -contains 'employee' -and @($roleTemplates.roles.id) -contains 'security_admin')
Add-Case $cases 'owner_not_automatic_super_admin' ((@($roleTemplates.roles | Where-Object { $_.id -eq 'business_owner' }) | Select-Object -First 1).platform_admin -eq $false)
Add-Case $cases 'chinese_beginner_onboarding' (-not [string]::IsNullOrWhiteSpace($onboardingText.prompts.company_name) -and $onboardingText.locale -eq 'zh-CN')
Add-Case $cases 'configured_connections_deny_by_default' ($connectionPolicy.default_action -eq 'deny' -and $connectionPolicy.invariants.direct_agent_connection -eq 'deny')
Add-Case $cases 'connection_operations_are_risk_specific' ($connectionPolicy.operation_levels.write_task_artifact -eq 'L2' -and $connectionPolicy.operation_levels.upload_internal_project -eq 'L3' -and $connectionPolicy.operation_levels.business_write -eq 'L4')
Add-Case $cases 'routine_L4_does_not_require_owner' ($approvalRouting.profiles.routine_reversible.business_owner_required -eq $false -and $approvalRouting.profiles.routine_reversible.batch_approval_allowed -eq $true)
Add-Case $cases 'critical_governance_requires_owner' ($approvalRouting.profiles.governance_critical.business_owner_required -eq $true -and $approvalRouting.profiles.governance_critical.per_action_minimum_approvers -eq 2)
Add-Case $cases 'five_task_views_defined' (@($fiveView.required_views).Count -eq 5 -and @($fiveView.required_views) -contains 'business' -and @($fiveView.required_views) -contains 'handling')
Add-Case $cases 'commerce_outcome_pack_defined' (@($commercePack.required_deliverables).Count -eq 5 -and @($commercePack.required_deliverables) -contains 'profitability' -and @($commercePack.required_deliverables) -contains 'main_image')
Add-Case $cases 'commerce_pack_has_no_write_authority' ($commercePack.authority_boundary.pack_creation_authorizes_listing_upload -eq $false -and $commercePack.authority_boundary.pack_creation_authorizes_price_change -eq $false)
Add-Case $cases 'commerce_full_lifecycle_defined' (@($commerceOperating.lifecycle).Count -eq 5 -and @($commerceOperating.cadence.PSObject.Properties.Name) -contains 'annual_report')
Add-Case $cases 'profit_periods_are_distinct' (@($commerceOperating.profit_settlement.PSObject.Properties).Count -eq 5 -and $commerceOperating.profit_settlement.daily_profit.may_be_official_accounting -eq $false)
Add-Case $cases 'compliance_mcp_write_separated' ($complianceMcp.write_path.ordinary_mcp_write -eq 'deny' -and $complianceMcp.write_path.dedicated_submission_adapter_required -eq $true)
Add-Case $cases 'lingxing_business_domains_mapped' (@($lingxingArchitecture.domains.PSObject.Properties).Count -eq 6 -and @($lingxingArchitecture.domains.PSObject.Properties.Name) -contains 'finance' -and @($lingxingArchitecture.domains.PSObject.Properties.Name) -contains 'supply_chain')
Add-Case $cases 'lingxing_mcp_interface_reserved' ($lingxingMcp.status -eq 'interface_reserved_not_connected' -and $lingxingMcp.default_mode -eq 'allowlist_read_only' -and $lingxingMcp.direct_agent_access -eq 'deny')
Add-Case $cases 'vendor_neutral_mcp_platform_defined' (@($enterpriseMcp.server_categories).Count -eq 12 -and $enterpriseMcp.default_action -eq 'deny')
Add-Case $cases 'obsidian_interface_is_reserved_and_disabled' ($obsidianContract.status -eq 'interface_reserved_not_connected' -and $obsidianRegistry.connectors[0].enabled -eq $false)
Add-Case $cases 'obsidian_vault_is_scoped_and_not_agent_direct' ($obsidianContract.vault_path_mode -eq 'reference_only' -and $obsidianContract.direct_agent_access -eq 'deny' -and @($obsidianContract.always_denied_operations) -contains 'export_entire_vault')
Add-Case $cases 'generic_mcp_write_is_L4' ($enterpriseMcp.operation_classes.update.minimum_level -eq 'L4' -and $enterpriseMcp.operation_classes.update.write -eq $true)
Add-Case $cases 'employee_direct_mcp_requires_owner_and_connector' ($directMcp.enforcement.connector_checks_each_call -eq $true -and @($directMcp.required_bindings) -contains 'employee_id' -and @($directMcp.required_bindings) -contains 'business_owner_approval_ref')
Add-Case $cases 'employee_records_are_never_physically_deleted' ($employeeLifecycle.physical_employee_delete -eq 'deny' -and @($employeeLifecycle.states) -contains 'offboarded')
Add-Case $cases 'transfer_revokes_before_regrant' ($employeeLifecycle.actions.transfer.order[1] -eq 'revoke_old_department_grants' -and @($employeeLifecycle.actions.transfer.order) -contains 'revoke_direct_mcp_sessions')
Add-Case $cases 'offboard_revokes_all_access' (@($employeeLifecycle.actions.offboard.actions) -contains 'disable_identity' -and @($employeeLifecycle.actions.offboard.actions) -contains 'revoke_credential_assignments')
Add-Case $cases 'enterprise_artifacts_have_governed_dimensions' (@($fileOrganization.required_dimensions).Count -eq 6 -and @($fileOrganization.required_dimensions) -contains 'risk_level')
Add-Case $cases 'compounding_cannot_mutate_production' ($reviewCompounding.hard_boundaries.automatic_AGENTS_change -eq $false -and $reviewCompounding.hard_boundaries.automatic_risk_rule_change -eq $false -and $reviewCompounding.hard_boundaries.automatic_permission_expansion -eq $false)
Add-Case $cases 'lesson_promotion_is_verified_and_human' (@($reviewCompounding.promotion_flow) -contains 'replay' -and @($reviewCompounding.promotion_flow) -contains 'independent_verification' -and @($reviewCompounding.promotion_flow) -contains 'human_approval')
Add-Case $cases 'four_api_agent_modes_defined' (@($deploymentModes.modes.PSObject.Properties).Count -eq 4 -and $deploymentModes.default_mode -eq 'E2')
Add-Case $cases 'E4_is_restricted_by_default' ($deploymentModes.modes.E4.initial_trust_ceiling -eq 'T1' -and $deploymentModes.modes.E4.credential_mode -eq 'byok_secret_ref_only')
Add-Case $cases 'deployment_mode_never_grants_business_authority' (@($deploymentModes.invariants | Where-Object { $_ -match 'L4' }).Count -gt 0 -and @($deploymentModes.invariants | Where-Object { $_ -match 'never grants MCP' }).Count -gt 0)
Add-Case $cases 'model_fusion_contracts_present' ((Test-Path -LiteralPath $modelPortfolioPath -PathType Leaf) -and (Test-Path -LiteralPath $fusionPlanPath -PathType Leaf))
Add-Case $cases 'claim_pack_contract_present' (Test-Path -LiteralPath $claimPackPath -PathType Leaf)
Add-Case $cases 'evidence_market_contract_present' ((Test-Path -LiteralPath $evidenceMarketPath -PathType Leaf) -and (Test-Path -LiteralPath $shadowReceiptPath -PathType Leaf))
Add-Case $cases 'shadow_fusion_runtime_present' (Test-Path -LiteralPath $shadowRuntimePath -PathType Leaf)
Add-Case $cases 'employee_agent_collaboration_contract_present' (Test-Path -LiteralPath $employeeCollaborationPath -PathType Leaf)
Add-Case $cases 'shadow_candidate_dispatch_disabled_by_default' (((Get-Content -LiteralPath $shadowProviderRegistryPath -Raw -Encoding UTF8|ConvertFrom-Json).network_dispatch_enabled -eq $false) -and (Test-Path -LiteralPath $shadowDispatchGatePath -PathType Leaf))
Add-Case $cases 'blindspot_learning_is_governed_and_routing_only' ((Test-Path -LiteralPath $blindspotObservationPath -PathType Leaf) -and (Test-Path -LiteralPath $collaborationOutcomePath -PathType Leaf) -and (Test-Path -LiteralPath $errorIndependenceGatePath -PathType Leaf) -and $edition.Contains('no_permission_change'))
Add-Case $cases 'collaboration_fan_in_enforces_contract_lineage_and_independence' ((Test-Path -LiteralPath $governedFanInPath -PathType Leaf) -and $edition.Contains('contract_lineage_independence_then_shadow_receipt'))
Add-Case $cases 'raw_shadow_runtime_is_not_enterprise_entrypoint' ($edition.Contains('internal_component_governed_fan_in_only') -and $edition.Contains('collaboration_entrypoint: governed_collaboration_fan_in'))
Add-Case $cases 'personal_and_enterprise_share_all_capabilities' ($businessCatalog.profiles.personal.capabilities -eq 'all' -and $businessCatalog.profiles.enterprise.capabilities -eq 'all' -and @($businessCatalog.capabilities).Count -ge 10)
Add-Case $cases 'business_periods_and_profit_views_defined' (@($businessCatalog.periods.PSObject.Properties.Name).Count -eq 5 -and @($businessCatalog.capabilities | Where-Object { $_.id -eq 'profit_accounting' }).standard_views.Count -ge 4)
Add-Case $cases 'enterprise_overlay_allowed' ((& $boundaryChecker -CandidatePath ($enterpriseDirectoryName + '/edition.yaml') -PassThru | ConvertFrom-Json).status -eq 'pass')

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{
  passed = ($failed.Count -eq 0)
  edition = 'enterprise'
  profile_directory = $enterpriseDirectoryName
  shared_core_unchanged_by_test = $true
  external_calls = $false
  real_execution_enabled = $false
  cases = @($cases)
}
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) {
  $failedNames = ($failed | ForEach-Object { $_.name }) -join ', '
  throw ('Enterprise profile regression failed: ' + $failedNames)
}
