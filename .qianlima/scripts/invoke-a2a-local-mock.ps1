param(
  [Parameter(Mandatory = $true)] [string]$EnvelopePath,
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$receiptScript = Join-Path $PSScriptRoot 'new-run-receipt.ps1'
$artifactReceiptScript = Join-Path $PSScriptRoot 'new-artifact-receipt.ps1'

$envelopeFullPath = (Resolve-Path -LiteralPath $EnvelopePath).Path
$envelope = Get-Content -LiteralPath $envelopeFullPath -Raw -Encoding UTF8 | ConvertFrom-Json
$required = @('schema_version', 'contract_type', 'context_id', 'task_id', 'parent_run_id', 'agent_ref', 'goal', 'input_refs', 'delegation', 'expected_artifacts', 'verification', 'stop_conditions', 'prohibited')
foreach ($field in $required) {
  $property = $envelope.PSObject.Properties[$field]
  $value = if ($property) { $property.Value } else { $null }
  $emptyCollection = $value -is [Collections.IEnumerable] -and -not ($value -is [string]) -and @($value).Count -eq 0
  if ($null -eq $value -or $emptyCollection -or ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) {
    throw "A2A mock envelope is missing required field: $field"
  }
}

if ($envelope.contract_type -ne 'qianlima_a2a_internal_task_envelope') {
  throw 'Only the Qianlima internal A2A task envelope is accepted.'
}
if ($envelope.agent_ref -ne 'evidence_checker') {
  throw 'Phase 1 mock permits only the read-only evidence_checker agent.'
}
if ($envelope.delegation.network_access -ne 'none' -or $envelope.delegation.write_access -ne 'none') {
  throw 'Phase 1 mock rejects any network or delegated write access.'
}
if ($envelope.delegation.risk_ceiling -notin @('L0', 'L1', 'L2', 'L3')) {
  throw 'Phase 1 mock rejects L4 or unknown risk ceilings.'
}
foreach ($reference in @($envelope.input_refs)) {
  if ($reference.source_classification -notin @('public', 'internal_sanitized')) {
    throw 'Phase 1 mock accepts only public or internal_sanitized input references.'
  }
  if ($reference.context_id -and $reference.context_id -ne $envelope.context_id) {
    throw 'Input reference context_id does not match the task context_id.'
  }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $traceRoot "a2a-mock-$($envelope.task_id).json"
}
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFullPath.StartsWith($traceRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'A2A mock artifacts must be written under .qianlima/run-traces.'
}
if (Test-Path -LiteralPath $outputFullPath) {
  throw 'A2A task artifacts are immutable. Create a new task_id for refinements.'
}

$artifact = [ordered]@{
  schema_version = 1
  artifact_type = 'qianlima_a2a_mock_verification'
  artifact_id = "artifact-$($envelope.task_id)"
  task_id = $envelope.task_id
  context_id = $envelope.context_id
  parent_run_id = $envelope.parent_run_id
  name = 'verification_receipt'
  media_type = 'application/json'
  source_classification = 'internal_sanitized'
  status = 'completed'
  summary = 'Local mock verified the task contract and emitted a bounded artifact reference only.'
  input_reference_count = @($envelope.input_refs).Count
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
$artifactJson = $artifact | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText($outputFullPath, $artifactJson, [Text.UTF8Encoding]::new($false))

$relativeArtifactRef = ('run-traces/a2a-mock-{0}.json' -f $envelope.task_id)
$fileHash = (Get-FileHash -LiteralPath $outputFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
$artifactHash = "sha256:$fileHash"
$artifactId = "artifact-$($envelope.task_id)"
$artifactReceiptScript = Join-Path $PSScriptRoot 'new-artifact-receipt.ps1'
$artifactReceiptArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $artifactReceiptScript, '-ArtifactId', $artifactId, '-TaskId', $envelope.task_id, '-Name', 'verification_receipt', '-MediaType', 'application/json', '-Reference', $relativeArtifactRef, '-IntegrityHash', $artifactHash, '-SourceClassification', 'internal_sanitized', '-VerificationStatus', 'passed')
& powershell.exe @artifactReceiptArgs | Out-Null
$runId = "a2a-local-$($envelope.task_id)"
$receiptArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $receiptScript, '-RunId', $runId, '-WorkflowId', 'a2a_compatibility', '-Status', 'completed', '-VerifierStatus', 'passed', '-ArtifactRef', $relativeArtifactRef)
foreach ($evidence in @($envelope.input_refs | ForEach-Object { $_.artifact_id })) { $receiptArgs += @('-EvidenceRef', $evidence) }
& powershell.exe @receiptArgs | Out-Null

$result = [PSCustomObject]@{
  task_id = $envelope.task_id
  context_id = $envelope.context_id
  status = 'completed'
  artifact_path = $outputFullPath
  artifact_ref = $relativeArtifactRef
  artifact_hash = $artifactHash
}
if ($PassThru) { $result | ConvertTo-Json -Depth 4 } else { $result | Format-List }
