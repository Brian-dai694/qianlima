param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$ArtifactId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [string]$Name,
  [Parameter(Mandatory = $true)] [string]$MediaType,
  [Parameter(Mandatory = $true)] [string]$Reference,
  [Parameter(Mandatory = $true)] [ValidatePattern('^sha256:[0-9a-f]{64}$')] [string]$IntegrityHash,
  [Parameter(Mandatory = $true)] [ValidateSet('public', 'internal_sanitized', 'confidential_reference_only')] [string]$SourceClassification,
  [ValidateSet('pending', 'passed', 'failed')] [string]$VerificationStatus = 'pending',
  [string]$ExpiresAt = '',
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if ([IO.Path]::IsPathRooted($Reference) -or $Reference -match '(^|[\\/])\.\.([\\/]|$)') { throw 'Artifact references must be logical or workspace-relative.' }
$forbidden = @('api_key', 'access_token', 'refresh_token', 'password', 'cookie', 'authorization:')
foreach ($value in @($Name, $Reference, $ExpiresAt)) {
  foreach ($needle in $forbidden) { if ($value -match [regex]::Escape($needle)) { throw 'Artifact receipts cannot contain secrets or authorization material.' } }
}
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$receiptRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\artifact-receipts')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $receiptRoot "$ArtifactId.json" }
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFullPath.StartsWith($receiptRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Artifact receipts must be written under .qianlima/run-traces/artifact-receipts.' }
if (Test-Path -LiteralPath $outputFullPath) { throw "Artifact receipt already exists; create a new artifact_id for replacements: $ArtifactId" }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputFullPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $outputFullPath) -Force | Out-Null }
$receipt = [ordered]@{
  schema_version = 1
  receipt_type = 'qianlima_artifact_receipt'
  artifact_id = $ArtifactId
  task_id = $TaskId
  name = $Name
  media_type = $MediaType
  reference = $Reference
  integrity_hash = $IntegrityHash
  source_classification = $SourceClassification
  verification_status = $VerificationStatus
  expires_at = if ($ExpiresAt) { $ExpiresAt } else { $null }
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($outputFullPath, ($receipt | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
if ($PassThru) { $receipt | ConvertTo-Json -Depth 8 } else { Write-Host "Artifact receipt created: $outputFullPath" }
