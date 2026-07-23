param(
  [Parameter(Mandatory = $true)] [string]$RunId,
  [Parameter(Mandatory = $true)] [string]$WorkflowId,
  [ValidateSet('running', 'completed', 'partial', 'failed', 'frozen', 'stopped')]
  [string]$Status = 'completed',
  [ValidateSet('', 'transient', 'task', 'verifier', 'needs_human')]
  [string]$FailureCategory = '',
  [ValidateSet('pending', 'passed', 'failed', 'skipped')]
  [string]$VerifierStatus = 'pending',
  [string[]]$ArtifactRef = @(),
  [string[]]$EvidenceRef = @(),
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$receiptRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $receiptRoot "receipt-$RunId.json" }
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFullPath.StartsWith($receiptRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Run receipts must be written under .qianlima/run-traces.'
}
if ($Status -eq 'completed') {
  if ($ArtifactRef.Count -eq 0) { throw 'Completed receipts require at least one artifact reference.' }
  if ($VerifierStatus -ne 'passed') { throw 'Completed receipts require verifier status: passed.' }
} elseif ([string]::IsNullOrWhiteSpace($FailureCategory)) {
  throw 'Non-completed receipts require FailureCategory.'
}
$OutputPath = $outputFullPath
$parent = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$receipt = [ordered]@{
  schema_version = 1
  receipt_type = 'qianlima_run_receipt'
  run_id = $RunId
  workflow_id = $WorkflowId
  status = $Status
  failure_category = if ($FailureCategory) { $FailureCategory } else { $null }
  verifier_status = $VerifierStatus
  artifact_refs = @($ArtifactRef)
  evidence_refs = @($EvidenceRef)
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($OutputPath, ($receipt | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
if ($PassThru) { [PSCustomObject]$receipt | ConvertTo-Json -Depth 6 } else { Write-Host "Run receipt: $OutputPath" }
