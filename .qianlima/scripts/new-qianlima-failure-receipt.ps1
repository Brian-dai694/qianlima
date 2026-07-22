<##
.SYNOPSIS
  Records a structured, public-safe Qianlima workflow failure.
##>
param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')] [string]$FailureId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')] [string]$RunId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [string]$Workflow,
  [Parameter(Mandatory = $true)] [string]$Phase,
  [Parameter(Mandatory = $true)] [string]$FailureLocation,
  [Parameter(Mandatory = $true)] [ValidateSet('transient','task','verifier','needs_human')] [string]$Category,
  [Parameter(Mandatory = $true)] [string]$Reason,
  [string[]]$SourceRef = @(),
  [ValidateRange(1, 1000000)] [int]$OccurrenceCount = 1,
  [Parameter(Mandatory = $true)] [string]$RecoveryAction,
  [Parameter(Mandatory = $true)] [ValidateSet('continue','retry_limited','frozen','stopped')] [string]$SafeState,
  [string]$OutputPath = '',
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$failureRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\failures')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
foreach ($value in @($Reason, $RecoveryAction, $FailureLocation) + @($SourceRef)) { if ([regex]::IsMatch([string]$value, '(?i)(api[_-]?key|token\s*[:=]|password\s*[:=]|cookie\s*[:=]|https?://|BEGIN PRIVATE KEY)')) { throw 'Failure receipt contains a secret or network value.' } }
if ($Category -eq 'needs_human' -and $SafeState -eq 'continue') { throw 'needs_human failures cannot continue automatically.' }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $failureRoot "$FailureId.json" }
$fullOutput = [IO.Path]::GetFullPath($OutputPath); if (-not $fullOutput.StartsWith($failureRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputPath must remain under failures.' }
if (Test-Path -LiteralPath $fullOutput) { throw "Failure receipt already exists: $FailureId" }
$receipt = [ordered]@{ failure_id = $FailureId; run_id = $RunId; task_id = $TaskId; workflow = $Workflow; phase = $Phase; failure_location = $FailureLocation; category = $Category; reason = $Reason; source_refs = @($SourceRef); occurrence_count = $OccurrenceCount; recovery_action = $RecoveryAction; safe_state = $SafeState; retry_allowed = ($SafeState -eq 'retry_limited'); terminal = ($SafeState -in @('frozen','stopped')); external_calls = $false; business_write = $false; created_at = (Get-Date).ToUniversalTime().ToString('o') }
New-Item -ItemType Directory -Path (Split-Path -Parent $fullOutput) -Force | Out-Null
[IO.File]::WriteAllText($fullOutput, ($receipt | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
if ($PassThru) { $receipt | ConvertTo-Json -Depth 10 } else { Write-Host "Qianlima failure receipt created: $fullOutput" }
