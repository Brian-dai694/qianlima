<##
.SYNOPSIS
  Creates a structured result for one Qianlima execution step.
##>
param(
  [Parameter(Mandatory = $true)] [string]$PlanPath,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{2,120}$')] [string]$StepId,
  [Parameter(Mandatory = $true)] [ValidateSet('completed', 'partial', 'failed', 'blocked')] [string]$StepStatus,
  [string[]]$SourceFile = @(),
  [int]$RowsRead = 0,
  [string]$ComputedMetricsJson = '{}',
  [string]$ComputedMetricsPath = '',
  [string[]]$Warning = @(),
  [string[]]$PendingVerification = @(),
  [string]$ArtifactHash = '',
  [string]$OutputRef = '',
  [int]$DurationMs = 0,
  [int]$ToolCalls = 0,
  [string]$OutputPath = '',
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$planRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\execution-plans')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$resolvedPlan = Resolve-Path -LiteralPath $PlanPath -ErrorAction Stop
$planFull = [IO.Path]::GetFullPath([string]$resolvedPlan.Path)
if (-not $planFull.StartsWith($planRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'PlanPath must be inside execution-plans.' }
$plan = Get-Content -LiteralPath $planFull -Raw -Encoding UTF8 | ConvertFrom-Json
$step = @($plan.steps | Where-Object { [string]$_.step_id -eq $StepId }) | Select-Object -First 1
if ($null -eq $step) { throw "Step does not exist in plan: $StepId" }
if ($RowsRead -lt 0 -or $DurationMs -lt 0 -or $ToolCalls -lt 0) { throw 'Numeric result fields cannot be negative.' }
if ($ComputedMetricsPath) {
  $metricsResolved = Resolve-Path -LiteralPath $ComputedMetricsPath -ErrorAction Stop
  $metricsFull = [IO.Path]::GetFullPath([string]$metricsResolved.Path)
  $rootPrefix = [IO.Path]::GetFullPath($root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $metricsFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'ComputedMetricsPath must remain inside the Qianlima project workspace.' }
  $ComputedMetricsJson = Get-Content -LiteralPath $metricsFull -Raw -Encoding UTF8
}
try { $metrics = $ComputedMetricsJson | ConvertFrom-Json } catch { throw 'ComputedMetricsJson or ComputedMetricsPath must be valid JSON.' }
if ($ArtifactHash -and $ArtifactHash -notmatch '^sha256:[0-9a-f]{64}$') { throw 'ArtifactHash must use sha256:<64 lowercase hex>.' }
if ($StepStatus -eq 'completed' -and ([string]::IsNullOrWhiteSpace($OutputRef) -or [string]::IsNullOrWhiteSpace($ArtifactHash))) { throw 'Completed results require OutputRef and ArtifactHash.' }
foreach ($ref in @($SourceFile) + @($OutputRef)) { if ($ref -match '^[A-Za-z]:[\\/]|^/|(^|[\\/])\.\.([\\/]|$)') { throw 'Result references must be relative or logical.' } }
$serializedMetrics = $metrics | ConvertTo-Json -Depth 12 -Compress
if (($serializedMetrics + ($Warning -join ' ') + ($PendingVerification -join ' ')) -match '(?i)(raw_prompt|hidden_reasoning|credential_value|api[_-]?key|access_token|password|raw_source_content)') { throw 'Step results cannot contain private or credential content.' }
$resultRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\step-results')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $resultRoot "$($plan.plan_id)-$StepId-$([Guid]::NewGuid().ToString('n')).json" }
$resultFull = [IO.Path]::GetFullPath($OutputPath)
if (-not $resultFull.StartsWith($resultRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Step results must be written under .qianlima/run-traces/step-results.' }
New-Item -ItemType Directory -Path (Split-Path -Parent $resultFull) -Force | Out-Null
$result = [ordered]@{
  schema_version = 1; result_type = 'qianlima_step_execution_result'; result_id = 'step-result-' + [Guid]::NewGuid().ToString('n'); plan_id = [string]$plan.plan_id; task_id = [string]$plan.task_id; step_id = $StepId; step_status = $StepStatus
  source_files = @($SourceFile); rows_read = $RowsRead; computed_metrics = $metrics; warnings = @($Warning); pending_verification = @($PendingVerification); artifact_hash = if ($ArtifactHash) { $ArtifactHash } else { $null }; output_ref = if ($OutputRef) { $OutputRef } else { $null }; duration_ms = $DurationMs; tool_calls = $ToolCalls; created_at = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($resultFull, ($result | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { Write-Host "Step result created: $resultFull" }
