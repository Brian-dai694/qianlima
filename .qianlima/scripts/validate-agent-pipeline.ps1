<##
.SYNOPSIS
  Validates a declared Agent pipeline and its carried artifact metadata.
.DESCRIPTION
  This Overlay validator models Copilot-style hooks and DeepStream-style
  metadata/backpressure without starting an Agent or a provider process.
##>
param(
  [Parameter(Mandatory = $true)] [string]$PipelinePath,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$specRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\specifications')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$traceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$contractPath = Join-Path $projectRoot '.qianlima\specifications\agent-pipeline-contract.json'
$audit = Join-Path $PSScriptRoot 'write-audit-event.ps1'
$contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
$resolved = Resolve-Path -LiteralPath $PipelinePath -ErrorAction Stop
$fullPath = [string]$resolved.Path
if (-not $fullPath.StartsWith($specRoot, [StringComparison]::OrdinalIgnoreCase) -and -not $fullPath.StartsWith($traceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Pipeline declaration must be inside specifications or run-traces.' }
$pipeline = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8 | ConvertFrom-Json
$violations = [System.Collections.Generic.List[string]]::new()
function Add-Violation([string]$Id) { [void]$violations.Add($Id) }
function Has-Value($Object, [string]$Name) {
  if ($null -eq $Object) { return $false }
  $property = @($Object.PSObject.Properties | Where-Object { $_.Name -eq $Name }) | Select-Object -First 1
  if ($null -eq $property -or $null -eq $property.Value) { return $false }
  if ($property.Value -is [string]) { return -not [string]::IsNullOrWhiteSpace([string]$property.Value) }
  return $true
}

foreach ($field in @('pipeline_id','pipeline_version','task_id','stages','artifact_metadata','budget','backpressure')) { if (-not (Has-Value $pipeline $field)) { Add-Violation "missing_$field" } }
$hasPipelineVersion = Has-Value $pipeline 'pipeline_version'
if ($hasPipelineVersion -and -not [string]::Equals(([string]$pipeline.pipeline_version), ([string]$contract.contract_version), [StringComparison]::Ordinal)) { Add-Violation 'contract_version_mismatch' }
if (@($pipeline.stages).Count -ne @($contract.required_stage_order).Count) { Add-Violation 'stage_count_mismatch' }
else {
  for ($i = 0; $i -lt @($contract.required_stage_order).Count; $i++) {
    if ([string]$pipeline.stages[$i].id -ne [string]$contract.required_stage_order[$i]) { Add-Violation "stage_order_mismatch_$i" }
  }
}
if (Has-Value $pipeline 'stages') {
  $stageIds = @($pipeline.stages | ForEach-Object { $_.id })
  if (@($stageIds | Where-Object { $_ -eq 'independent_verify' }).Count -ne 1) { Add-Violation 'independent_verifier_missing' }
  if (@($stageIds | Where-Object { $_ -eq 'artifact_scan' }).Count -ne 1) { Add-Violation 'artifact_scan_missing' }
  $executeIndex = [Array]::IndexOf([string[]]$stageIds, 'execute'); $verifyIndex = [Array]::IndexOf([string[]]$stageIds, 'independent_verify')
  if ($executeIndex -ge 0 -and $verifyIndex -ge 0 -and $verifyIndex -lt $executeIndex) { Add-Violation 'verification_before_execution_contract_invalid' }
}
foreach ($field in @($contract.artifact_metadata_required)) { if (-not (Has-Value $pipeline.artifact_metadata $field)) { Add-Violation "artifact_metadata_missing_$field" } }
if ((Has-Value $pipeline.artifact_metadata 'source_classification')) { $sourceClass = [string]$pipeline.artifact_metadata.source_classification; if (@('public','internal_sanitized','confidential_reference_only').IndexOf($sourceClass) -lt 0) { Add-Violation 'invalid_source_classification' } }
if ((Has-Value $pipeline.artifact_metadata 'verification_status')) { $verificationStatus = [string]$pipeline.artifact_metadata.verification_status; if (@('pending','passed','partial','failed','rejected').IndexOf($verificationStatus) -lt 0) { Add-Violation 'invalid_verification_status' } }
if ((Has-Value $pipeline 'budget')) {
  foreach ($field in @('max_steps','max_tool_calls','timeout_ms','max_concurrent_agents')) { if (-not (Has-Value $pipeline.budget $field) -or [int]$pipeline.budget.$field -lt 1) { Add-Violation "invalid_budget_$field" } }
  if (-not (Has-Value $pipeline.budget 'max_failed_attempts') -or [int]$pipeline.budget.max_failed_attempts -lt 0) { Add-Violation 'invalid_budget_max_failed_attempts' }
  if ((Has-Value $pipeline.budget 'steps_used') -and [int]$pipeline.budget.steps_used -gt [int]$pipeline.budget.max_steps) { Add-Violation 'budget_exceeded_steps_used' }
  if ((Has-Value $pipeline.budget 'tool_calls_used') -and [int]$pipeline.budget.tool_calls_used -gt [int]$pipeline.budget.max_tool_calls) { Add-Violation 'budget_exceeded_tool_calls_used' }
  if ((Has-Value $pipeline.budget 'failed_attempts') -and [int]$pipeline.budget.failed_attempts -gt [int]$pipeline.budget.max_failed_attempts) { Add-Violation 'budget_exceeded_failed_attempts' }
  if ([int]$pipeline.budget.max_concurrent_agents -gt [int]$contract.backpressure.max_concurrent_agents) { Add-Violation 'concurrency_exceeds_contract' }
}
foreach ($forbidden in @('network_access','write_access','file_export','web_access','erp_access','arbitrary_mcp','direct_agent_to_agent','secret_value')) { if (Has-Value $pipeline $forbidden -and [bool]$pipeline.$forbidden) { Add-Violation "forbidden_capability_$forbidden" } }
if (Has-Value $pipeline 'event_fields') { foreach ($field in @($contract.event_contract.prohibited_fields)) { if (@($pipeline.event_fields) -contains $field) { Add-Violation "prohibited_event_field_$field" } } }
if ([string]$pipeline.artifact_metadata.verification_status -eq 'passed' -and [string]$pipeline.final_decision -eq 'completed' -and [string]$pipeline.artifact_metadata.verifier_id -eq '') { Add-Violation 'completed_without_verifier' }
$status = if ($violations.Count -eq 0) { 'passed' } else { 'blocked' }
$eventType = if ($status -eq 'passed') { 'pipeline_validated' } else { 'pipeline_frozen' }
$auditDecision = if ($status -eq 'passed') { 'complete' } else { 'freeze' }
& $audit -EventType $eventType -Decision $auditDecision -TaskId ([string]$pipeline.task_id) -AgentId ([string]$pipeline.agent_id) -Reason "Declared pipeline validation status: $status; raw prompts and sensitive parameters are not recorded." 6>$null | Out-Null
$result = [ordered]@{ status=$status; pipeline_id=$pipeline.pipeline_id; task_id=$pipeline.task_id; contract_version=$contract.contract_version; violations=@($violations); backpressure_action=if($violations.Count -gt 0){'freeze_and_revoke'}else{'none'}; external_calls=$false; raw_prompt_recorded=$false }
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List }
if ($status -ne 'passed') { exit 1 }
