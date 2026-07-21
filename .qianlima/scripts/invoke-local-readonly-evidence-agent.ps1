param(
  [Parameter(Mandatory = $true)] [string]$EnvelopePath,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$envelopeFullPath = (Resolve-Path -LiteralPath $EnvelopePath -ErrorAction Stop).Path
if (-not $envelopeFullPath.StartsWith($traceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Local evidence input must stay under .qianlima/run-traces.' }
$envelope = Get-Content -LiteralPath $envelopeFullPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Get-Field($Object, [string]$Name) {
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

if ((Get-Field $envelope 'agent_id') -ne 'local-readonly-evidence-checker') { throw 'Only the registered local read-only evidence checker is permitted.' }
if ((Get-Field $envelope 'tool_id') -ne 'qianlima_readonly_evidence_task') { throw 'Unsupported personal tool.' }
if ([string]::IsNullOrWhiteSpace((Get-Field $envelope 'task_id')) -or [string]::IsNullOrWhiteSpace((Get-Field $envelope 'context_id'))) { throw 'Evidence task requires task_id and context_id.' }
$inputRefs = @((Get-Field $envelope 'input_refs'))
if ($inputRefs.Count -eq 0) { throw 'Evidence task requires input references.' }
foreach ($reference in $inputRefs) {
  $classification = Get-Field $reference 'source_classification'
  if ($classification -notin @('public', 'internal_sanitized')) { throw 'Only public or internal_sanitized evidence references are accepted.' }
  if ([string]::IsNullOrWhiteSpace((Get-Field $reference 'artifact_id'))) { throw 'Each evidence reference requires an artifact_id.' }
}

$taskId = Get-Field $envelope 'task_id'
$artifactPath = Join-Path $traceRoot "personal-local-evidence-$taskId.json"
if (Test-Path -LiteralPath $artifactPath) { throw 'Artifacts are immutable; create a new task for a revision.' }
$artifact = [ordered]@{
  schema_version = 1
  artifact_type = 'personal_local_readonly_evidence'
  artifact_id = "artifact-$taskId"
  task_id = $taskId
  context_id = Get-Field $envelope 'context_id'
  agent_id = 'local-readonly-evidence-checker'
  transport = 'stdio'
  source_refs = @($inputRefs | ForEach-Object { Get-Field $_ 'artifact_id' })
  source_classifications = @($inputRefs | ForEach-Object { Get-Field $_ 'source_classification' })
  status = 'completed'
  summary = 'Local read-only evidence contract completed without network or business writes.'
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($artifactPath, ($artifact | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$hash = 'sha256:' + (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
$result = [ordered]@{
  tool_id = 'qianlima_readonly_evidence_task'
  task_id = $taskId
  context_id = Get-Field $envelope 'context_id'
  agent_id = 'local-readonly-evidence-checker'
  transport = 'stdio'
  status = 'completed'
  artifact_ref = ('run-traces/personal-local-evidence-{0}.json' -f $taskId)
  artifact_path = $artifactPath
  artifact_hash = $hash
}
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
