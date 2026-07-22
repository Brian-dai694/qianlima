<##
.SYNOPSIS
  Creates a verifiable Qianlima business evidence pack from local references.
##>
param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')] [string]$EvidencePackId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [string]$Workflow,
  [Parameter(Mandatory = $true)] [string]$Conclusion,
  [Parameter(Mandatory = $true)] [string]$CurrentStateRef,
  [Parameter(Mandatory = $true)] [string]$DesiredStateRef,
  [Parameter(Mandatory = $true)] [string]$DiffRef,
  [Parameter(Mandatory = $true)] [string[]]$SourceRef,
  [Parameter(Mandatory = $true)] [string]$DataTimeRange,
  [Parameter(Mandatory = $true)] [string[]]$FormulaRef,
  [Parameter(Mandatory = $true)] [string]$WorkflowVersion,
  [string[]]$Assumption = @(),
  [string[]]$Uncertainty = @(),
  [string[]]$PendingVerification = @(),
  [Parameter(Mandatory = $true)] [string]$ReplayCommand,
  [ValidateSet('candidate','partial','passed','failed','blocked')] [string]$VerificationStatus = 'candidate',
  [string]$OutputPath = '',
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\evidence-packs')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$forbiddenPattern = '(?i)(api[_-]?key|access[_-]?token|password|secret\s*[:=]|BEGIN PRIVATE KEY|https?://)'
$sensitiveValues = @($Conclusion) + @($CurrentStateRef) + @($DesiredStateRef) + @($DiffRef) + @($ReplayCommand) + @($SourceRef) + @($FormulaRef)
foreach ($value in $sensitiveValues) { if ([regex]::IsMatch([string]$value, $forbiddenPattern)) { throw 'Evidence pack contains a forbidden credential or network reference.' } }
if ($SourceRef.Count -eq 0 -or $FormulaRef.Count -eq 0) { throw 'SourceRef and FormulaRef are required.' }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $traceRoot "$EvidencePackId.json" }
$fullOutput = [IO.Path]::GetFullPath($OutputPath)
if (-not $fullOutput.StartsWith($traceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputPath must remain under .qianlima/run-traces/evidence-packs.' }
if (Test-Path -LiteralPath $fullOutput) { throw "Evidence pack already exists: $EvidencePackId" }
$item = [ordered]@{ evidence_pack_id = $EvidencePackId; task_id = $TaskId; workflow = $Workflow; conclusion = $Conclusion; current_state_ref = $CurrentStateRef; desired_state_ref = $DesiredStateRef; diff_ref = $DiffRef; source_refs = @($SourceRef); data_time_range = $DataTimeRange; formula_refs = @($FormulaRef); workflow_version = $WorkflowVersion; assumptions = @($Assumption); uncertainties = @($Uncertainty); pending_verification = @($PendingVerification); replay_command = $ReplayCommand; verification_status = $VerificationStatus; created_at = (Get-Date).ToUniversalTime().ToString('o'); external_calls = $false; business_write = $false; network_access = $false }
New-Item -ItemType Directory -Path (Split-Path -Parent $fullOutput) -Force | Out-Null
[IO.File]::WriteAllText($fullOutput, ($item | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
$canonical = $item | ConvertTo-Json -Depth 12 -Compress
$hashHex = -join ([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical)) | ForEach-Object { $_.ToString('x2') })
$hash = 'sha256:' + $hashHex
$item.artifact_hash = $hash
[IO.File]::WriteAllText($fullOutput, ($item | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
if ($PassThru) { $item | ConvertTo-Json -Depth 12 } else { Write-Host "Qianlima evidence pack created: $fullOutput" }
