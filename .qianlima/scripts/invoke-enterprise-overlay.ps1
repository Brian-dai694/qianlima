<##
.SYNOPSIS
  Runs the enterprise governance Overlay around a registered Runner.
.DESCRIPTION
  This sidecar gateway does not modify the core Harness. It checks the frozen
  boundary, optionally validates a credential reference, scans an Artifact,
  and then delegates to the existing governed Runner. DryRun is the only
  available successful dispatch mode until a real isolated Runner is approved.
##>
param(
  [Parameter(Mandatory = $true)] [string]$RunnerId,
  [Parameter(Mandatory = $true)] [string]$WorkOrderPath,
  [Parameter(Mandatory = $true)] [string]$GrantPath,
  [Parameter(Mandatory = $true)] [string]$AttestationPath,
  [Parameter(Mandatory = $true)] [string]$PipelinePath,
  [ValidateSet('DryRun', 'Execute')] [string]$Mode = 'DryRun',
  [string]$ArtifactPath = '',
  [ValidateSet('text/plain', 'text/markdown', 'application/json', 'text/csv', 'text/yaml', 'application/yaml', 'text/html', 'application/xml', 'text/xml')] [string]$ArtifactMediaType = '',
  [ValidateSet('public', 'internal_sanitized', 'confidential_reference_only')] [string]$ArtifactClassification = '',
  [string]$CredentialId = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$boundaryScript = Join-Path $PSScriptRoot 'check-harness-boundary.ps1'
$credentialScript = Join-Path $PSScriptRoot 'validate-credential-reference.ps1'
$artifactScript = Join-Path $PSScriptRoot 'scan-governed-artifact.ps1'
$pipelineScript = Join-Path $PSScriptRoot 'validate-agent-pipeline.ps1'
$runnerScript = Join-Path $PSScriptRoot 'invoke-governed-runner.ps1'
$grantRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\delegation-grants')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar

function Invoke-JsonScript([string]$ScriptPath, [string[]]$Arguments) {
  $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1)
  $exitCode = $LASTEXITCODE
  $text = ($output -join "`n")
  $value = $null
  $jsonStart = $text.IndexOf('{')
  $jsonEnd = $text.LastIndexOf('}')
  if ($jsonStart -ge 0 -and $jsonEnd -gt $jsonStart) {
    try { $value = $text.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json } catch { }
  }
  return [PSCustomObject]@{ exit_code = $exitCode; text = $text; value = $value }
}
function Emit([hashtable]$Value, [int]$ExitCode = 0) {
  if ($PassThru) { $Value | ConvertTo-Json -Depth 12 } else { $Value | Format-List }
  if ($ExitCode -ne 0) { exit $ExitCode }
}

$boundary = Invoke-JsonScript $boundaryScript @('-PassThru')
if ($boundary.exit_code -ne 0 -or $null -eq $boundary.value -or $boundary.value.status -ne 'pass') { Emit @{ status = 'blocked'; stage = 'harness_boundary'; reason = 'Core Harness boundary check failed.'; core_read_only = $true } 1 }

$grantFullPath = (Resolve-Path -LiteralPath $GrantPath -ErrorAction Stop).Path
if (-not $grantFullPath.StartsWith($grantRoot, [StringComparison]::OrdinalIgnoreCase)) { Emit @{ status = 'blocked'; stage = 'grant_scope'; reason = 'Grant is outside the governed run-traces scope.' } 1 }
$grant = Get-Content -LiteralPath $grantFullPath -Raw -Encoding UTF8 | ConvertFrom-Json
$taskId = [string]$grant.task_id
$agentId = [string]$grant.agent_id
$pipelineCheck = Invoke-JsonScript $pipelineScript @('-PipelinePath', $PipelinePath, '-PassThru')
if ($pipelineCheck.exit_code -ne 0 -or $null -eq $pipelineCheck.value -or $pipelineCheck.value.status -ne 'passed') {
  Emit @{ status = 'blocked'; stage = 'pipeline_spec'; reason = 'Agent Pipeline specification did not pass Analyze.'; pipeline_result = $pipelineCheck.value; core_read_only = $true } 1
}
$pipelineFullPath = (Resolve-Path -LiteralPath $PipelinePath -ErrorAction Stop).Path
$pipeline = Get-Content -LiteralPath $pipelineFullPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]$pipeline.task_id -ne $taskId -or [string]$pipeline.agent_id -ne $agentId -or [string]$pipeline.runner_id -ne $RunnerId) {
  Emit @{ status = 'blocked'; stage = 'pipeline_binding'; reason = 'Pipeline task, Agent, or Runner binding does not match the Grant and requested Runner.'; core_read_only = $true } 1
}

$credentialResult = [ordered]@{ status = 'not_requested'; secret_value_exposed = $false }
if ($CredentialId) {
  $credentialCheck = Invoke-JsonScript $credentialScript @('-CredentialId', $CredentialId, '-ConsumerId', $agentId, '-TaskId', $taskId, '-PassThru')
  if ($credentialCheck.exit_code -ne 0 -or $null -eq $credentialCheck.value) { Emit @{ status = 'blocked'; stage = 'credential_reference'; reason = 'Credential reference validation failed; no secret was exposed.'; secret_value_exposed = $false } 1 }
  $credentialResult = $credentialCheck.value
}

$artifactResult = [ordered]@{ status = 'not_requested'; raw_content_recorded = $false }
if ($ArtifactPath) {
  if (-not $ArtifactMediaType -or -not $ArtifactClassification) { Emit @{ status = 'blocked'; stage = 'artifact_scan'; reason = 'ArtifactMediaType and ArtifactClassification are required with ArtifactPath.'; raw_content_recorded = $false } 1 }
  $artifactCheck = Invoke-JsonScript $artifactScript @('-ArtifactPath', $ArtifactPath, '-MediaType', $ArtifactMediaType, '-SourceClassification', $ArtifactClassification, '-TaskId', $taskId, '-PassThru')
  if ($artifactCheck.exit_code -ne 0 -or $null -eq $artifactCheck.value -or $artifactCheck.value.status -ne 'passed') { Emit @{ status = 'blocked'; stage = 'artifact_scan'; reason = 'Artifact did not pass the Overlay content gate.'; artifact_scan = $artifactCheck.value; raw_content_recorded = $false } 1 }
  $artifactResult = $artifactCheck.value
}

$runnerArgs = @('-RunnerId', $RunnerId, '-WorkOrderPath', $WorkOrderPath, '-GrantPath', $GrantPath, '-AttestationPath', $AttestationPath, '-Mode', $Mode, '-PassThru')
$runnerCheck = Invoke-JsonScript $runnerScript $runnerArgs
if ($runnerCheck.exit_code -ne 0 -or $null -eq $runnerCheck.value) { Emit @{ status = 'blocked'; stage = 'runner_dispatch'; reason = 'Governed Runner rejected the dispatch.'; runner_result = $runnerCheck.value; core_read_only = $true } 1 }
$result = [ordered]@{ status = $runnerCheck.value.status; gateway = 'enterprise_overlay'; core_read_only = $true; task_id = $taskId; agent_id = $agentId; pipeline_id = $pipeline.pipeline_id; pipeline_status = $pipelineCheck.value.status; boundary_status = 'pass'; credential = $credentialResult; artifact_scan = $artifactResult; runner = $runnerCheck.value; external_calls = $false; secret_value_exposed = $false }
Emit $result 0
