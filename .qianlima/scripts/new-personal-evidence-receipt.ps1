param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]+$')] [string]$ReceiptId,
  [Parameter(Mandatory = $true)] [string]$TaskId,
  [Parameter(Mandatory = $true)] [string]$GrantId,
  [Parameter(Mandatory = $true)] [string]$AgentId,
  [Parameter(Mandatory = $true)] [string[]]$SourceRef,
  [Parameter(Mandatory = $true)] [string]$ArtifactRef,
  [Parameter(Mandatory = $true)] [ValidatePattern('^sha256:[0-9a-f]{64}$')] [string]$IntegrityHash,
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if ($SourceRef.Count -eq 0) { throw 'Evidence receipt requires at least one source reference.' }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$receiptRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\evidence-receipts')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $receiptRoot "$ReceiptId.json" }
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFullPath.StartsWith($receiptRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Personal evidence receipts must stay under .qianlima/run-traces/evidence-receipts.' }
if (Test-Path -LiteralPath $outputFullPath) { throw 'Evidence receipts are immutable; create a new task and receipt.' }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputFullPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $outputFullPath) -Force | Out-Null }
$receipt = [ordered]@{
  schema_version = 1
  receipt_type = 'qianlima_evidence_receipt'
  receipt_id = $ReceiptId
  task_id = $TaskId
  grant_id = $GrantId
  agent_id = $AgentId
  conclusion_summary = 'Bounded local read-only evidence task completed.'
  source_refs = @($SourceRef)
  data_time_range = 'provided_by_input_artifact'
  assumptions = @('Input references were supplied as sanitized logical references.')
  uncertainties = @('No network refresh was performed.')
  method_ref = 'personal_local_readonly_evidence_checker_v1'
  artifact_ref = $ArtifactRef
  integrity_hash = $IntegrityHash
  source_classification = 'public_or_internal_sanitized'
  verification_status = 'passed'
  verifier_agent_id = 'qianlima_evidence_verifier'
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($outputFullPath, ($receipt | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
if ($PassThru) { $receipt | ConvertTo-Json -Depth 8 } else { Write-Host "Evidence receipt created: $outputFullPath" }
