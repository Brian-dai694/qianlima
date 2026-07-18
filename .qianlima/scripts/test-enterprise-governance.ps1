<##
.SYNOPSIS
  Regression checks for the enterprise governance baseline.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$frameworkPath = Join-Path $projectRoot '.qianlima\enterprise-governance-framework.json'
$registryPath = Join-Path $projectRoot '.qianlima\execution-runners.json'
$policyPath = Join-Path $projectRoot '.qianlima\agent-runtime-policy.yaml'
$adapterPath = Join-Path $projectRoot '.qianlima\agent-runtime-adapters.yaml'
$matrixPath = Join-Path $projectRoot '.qianlima\enterprise-governance-control-matrix.md'
$credentialPolicyPath = Join-Path $projectRoot '.qianlima\credential-policy.json'
$securityScriptPath = Join-Path $PSScriptRoot 'test-security-controls.ps1'
$boundaryPath = Join-Path $projectRoot '.qianlima\harness-boundary.json'
$protocolPath = Join-Path $projectRoot '.qianlima\specifications\north-star-protocol.json'
$overlayPath = Join-Path $PSScriptRoot 'invoke-enterprise-overlay.ps1'
$pipelineContractPath = Join-Path $projectRoot '.qianlima\specifications\agent-pipeline-contract.json'
$pipelineValidatorPath = Join-Path $PSScriptRoot 'validate-agent-pipeline.ps1'
$traceContractPath = Join-Path $projectRoot '.qianlima\specifications\trace-contract.json'
$traceValidatorPath = Join-Path $PSScriptRoot 'validate-run-trace.ps1'
$memoryReadContractPath = Join-Path $projectRoot '.qianlima\specifications\memory-read-contract.json'
$memoryReadValidatorPath = Join-Path $PSScriptRoot 'validate-memory-read.ps1'
$complexityContractPath = Join-Path $projectRoot '.qianlima\specifications\complexity-admission-contract.json'
$complexityValidatorPath = Join-Path $PSScriptRoot 'validate-complexity-admission.ps1'
$admissionAnalyzerPath = Join-Path $PSScriptRoot 'analyze-agent-admission-spec.ps1'
$framework = Get-Content -LiteralPath $frameworkPath -Raw -Encoding UTF8 | ConvertFrom-Json
$registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = [System.Collections.Generic.List[object]]::new()
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
Add-Case 'framework_identity' ($framework.framework_id -eq 'qianlima-enterprise-agent-governance' -and $framework.status -eq 'baseline_defined_execution_restricted')
Add-Case 'ten_principles' (@($framework.governance_principles).Count -ge 10)
Add-Case 'risk_levels_complete' (@('L0','L1','L2','L3','L4' | Where-Object { $null -eq $framework.risk_model.levels.$_ }).Count -eq 0)
Add-Case 'l4_hard_controls' (@('original_data_reload','preflight_snapshot','explicit_confirmation','rollback_reference' | Where-Object { @($framework.risk_model.non_bypassable_L4_controls) -notcontains $_ }).Count -eq 0)
Add-Case 'runtime_restrictions' ($framework.runtime_controls.registered_runner_required -eq $true -and $framework.runtime_controls.host_workspace_mount -eq 'deny' -and $framework.runtime_controls.network -eq 'deny_by_default' -and $framework.runtime_controls.file_export -eq 'deny')
Add-Case 'real_runner_disabled' (@($registry.runners | Where-Object { $_.runner_id -eq 'docker_local_isolated' -and $_.enabled -eq $false -and $_.execution_enabled -eq $false }).Count -eq 1)
Add-Case 'policy_references_framework' ((Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8) -match 'enterprise-governance-framework.json')
Add-Case 'adapter_references_runner_gate' ((Get-Content -LiteralPath $adapterPath -Raw -Encoding UTF8) -match 'runner_gate:')
Add-Case 'human_promotion_required' ($framework.change_management.human_promotion -eq $true -and $framework.change_management.automatic_production_change -eq $false)
Add-Case 'control_matrix_exists' (Test-Path -LiteralPath $matrixPath -PathType Leaf)
Add-Case 'credential_policy_exists' (Test-Path -LiteralPath $credentialPolicyPath -PathType Leaf)
Add-Case 'security_regression_exists' (Test-Path -LiteralPath $securityScriptPath -PathType Leaf)
Add-Case 'core_boundary_exists' (Test-Path -LiteralPath $boundaryPath -PathType Leaf)
Add-Case 'north_star_protocol_exists' (Test-Path -LiteralPath $protocolPath -PathType Leaf)
Add-Case 'enterprise_overlay_exists' (Test-Path -LiteralPath $overlayPath -PathType Leaf)
Add-Case 'agent_pipeline_contract_exists' (Test-Path -LiteralPath $pipelineContractPath -PathType Leaf)
Add-Case 'agent_pipeline_validator_exists' (Test-Path -LiteralPath $pipelineValidatorPath -PathType Leaf)
Add-Case 'trace_contract_exists' (Test-Path -LiteralPath $traceContractPath -PathType Leaf)
Add-Case 'trace_validator_exists' (Test-Path -LiteralPath $traceValidatorPath -PathType Leaf)
Add-Case 'memory_read_contract_exists' (Test-Path -LiteralPath $memoryReadContractPath -PathType Leaf)
Add-Case 'memory_read_validator_exists' (Test-Path -LiteralPath $memoryReadValidatorPath -PathType Leaf)
Add-Case 'complexity_contract_exists' (Test-Path -LiteralPath $complexityContractPath -PathType Leaf)
Add-Case 'complexity_validator_exists' (Test-Path -LiteralPath $complexityValidatorPath -PathType Leaf)
Add-Case 'agent_analyze_enforces_complexity' ((Get-Content -LiteralPath $admissionAnalyzerPath -Raw -Encoding UTF8) -match 'ComplexityProposalPath' -and (Get-Content -LiteralPath $admissionAnalyzerPath -Raw -Encoding UTF8) -match 'complexity_admission_required_or_failed')
$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ passed = ($failed.Count -eq 0); cases = @($cases); real_execution_enabled = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw "Enterprise governance regression failed: $($failed.name -join ', ')" }
