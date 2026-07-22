param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$ReceiptId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$GrantId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$AgentId,
  [Parameter(Mandatory = $true)] [string]$ConclusionSummary,
  [Parameter(Mandatory = $true)] [string[]]$SourceRef,
  [Parameter(Mandatory = $true)] [string]$DataTimeRange,
  [string[]]$Assumption = @(),
  [string[]]$Uncertainty = @(),
  [Parameter(Mandatory = $true)] [string]$MethodRef,
  [Parameter(Mandatory = $true)] [string]$ArtifactRef,
  [Parameter(Mandatory = $true)] [ValidatePattern('^sha256:[0-9a-f]{64}$')] [string]$IntegrityHash,
  [Parameter(Mandatory = $true)] [ValidateSet('public', 'internal_sanitized', 'confidential_reference_only')] [string]$SourceClassification,
  [ValidateSet('pending', 'passed', 'partial', 'failed', 'rejected')] [string]$VerificationStatus = 'pending',
  [string]$VerifierAgentId = '',
  [string]$PriorReceiptRef = '',
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if ($SourceRef.Count -eq 0 -or [string]::IsNullOrWhiteSpace($ConclusionSummary) -or [string]::IsNullOrWhiteSpace($DataTimeRange) -or [string]::IsNullOrWhiteSpace($MethodRef)) { throw 'Evidence receipt is missing required evidence fields.' }
if ($VerificationStatus -eq 'passed' -and [string]::IsNullOrWhiteSpace($VerifierAgentId)) { throw 'Passed evidence requires an independent VerifierAgentId.' }
function Test-SafeRef([string]$Value) { return -not ([IO.Path]::IsPathRooted($Value) -or $Value -match '(^|[\\/])\.\.([\\/]|$)') }
foreach ($value in @($SourceRef) + @($MethodRef) + @($ArtifactRef) + @($PriorReceiptRef)) { if (-not (Test-SafeRef $value)) { throw 'Evidence references must be logical or workspace-relative.' } }
$forbidden = @('api_key', 'access_token', 'refresh_token', 'password', 'cookie', 'authorization:')
foreach ($value in @($ConclusionSummary) + @($SourceRef) + @($Assumption) + @($Uncertainty) + @($MethodRef) + @($ArtifactRef)) { foreach ($needle in $forbidden) { if ($value -match [regex]::Escape($needle)) { throw 'Evidence receipts cannot contain secrets or authorization material.' } } }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$receiptRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\evidence-receipts')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $receiptRoot "$ReceiptId.json" }
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFullPath.StartsWith($receiptRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Evidence receipts must be written under .qianlima/run-traces/evidence-receipts.' }
if (Test-Path -LiteralPath $outputFullPath) { throw "Evidence receipt already exists; create a new receipt_id: $ReceiptId" }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputFullPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $outputFullPath) -Force | Out-Null }
$receipt = [ordered]@{
  schema_version = 1; receipt_type = 'qianlima_evidence_receipt'; receipt_id = $ReceiptId; task_id = $TaskId; grant_id = $GrantId; agent_id = $AgentId
  conclusion_summary = $ConclusionSummary; source_refs = @($SourceRef); data_time_range = $DataTimeRange; assumptions = @($Assumption); uncertainties = @($Uncertainty); method_ref = $MethodRef
  artifact_ref = $ArtifactRef; integrity_hash = $IntegrityHash; source_classification = $SourceClassification; verification_status = $VerificationStatus; verifier_agent_id = if ($VerifierAgentId) { $VerifierAgentId } else { $null }; prior_receipt_ref = if ($PriorReceiptRef) { $PriorReceiptRef } else { $null }; created_at = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($outputFullPath, ($receipt | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
if ($PassThru) { $receipt | ConvertTo-Json -Depth 8 } else { Write-Host "Evidence receipt created: $outputFullPath" }
