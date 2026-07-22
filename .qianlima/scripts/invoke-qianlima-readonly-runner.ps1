<##
.SYNOPSIS
  Runs the Qianlima local read-only data adapter.
.DESCRIPTION
  CSV uses the existing deterministic summarizer. XLSX and Python are
  recognized for plan preflight but remain blocked until a separately verified
  local adapter exists; this script never installs dependencies or uses network.
##>
param(
  [Parameter(Mandatory = $true)] [string]$PlanPath,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{2,120}$')] [string]$StepId,
  [Parameter(Mandatory = $true)] [string]$InputPath,
  [string[]]$NumericColumn = @(),
  [string[]]$GroupBy = @(),
  [switch]$Preflight,
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$planRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\execution-plans')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$planResolved = Resolve-Path -LiteralPath $PlanPath -ErrorAction Stop
$planFull = [IO.Path]::GetFullPath([string]$planResolved.Path)
if (-not $planFull.StartsWith($planRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'PlanPath must be inside execution-plans.' }
$plan = Get-Content -LiteralPath $planFull -Raw -Encoding UTF8 | ConvertFrom-Json
$step = @($plan.steps | Where-Object { [string]$_.step_id -eq $StepId }) | Select-Object -First 1
if ($null -eq $step) { throw "Step does not exist in plan: $StepId" }
$inputResolved = Resolve-Path -LiteralPath $InputPath -ErrorAction Stop
$inputFull = [IO.Path]::GetFullPath([string]$inputResolved.Path)
$rootPrefix = [IO.Path]::GetFullPath($root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (-not $inputFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'InputPath must remain inside the Qianlima project workspace.' }
function Get-RelativePath([string]$BasePath, [string]$FullPath) { $base = [IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar; $baseUri = New-Object Uri ($base); $fullUri = New-Object Uri ([IO.Path]::GetFullPath($FullPath)); return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($fullUri).ToString()).Replace('\', '/') }
$extension = [IO.Path]::GetExtension($inputFull).ToLowerInvariant()
$kind = switch ($extension) { '.csv' { 'csv' } '.xlsx' { 'xlsx' } '.py' { 'python' } default { 'unknown' } }
$requiredTool = switch ($kind) { 'csv' { 'local_csv_reader' } 'xlsx' { 'local_xlsx_reader' } 'python' { 'local_python_readonly' } default { '' } }
if ($requiredTool -and @($step.allowed_tools) -notcontains $requiredTool) { throw "Plan step does not allow the required read-only tool: $requiredTool" }
$capability = switch ($kind) { 'csv' { 'ready' } 'xlsx' { 'preflight_only' } 'python' { 'preflight_only' } default { 'unsupported' } }
$response = [ordered]@{ status = if ($capability -eq 'ready') { 'eligible' } else { 'blocked' }; plan_id = $plan.plan_id; task_id = $plan.task_id; step_id = $StepId; input_ref = Get-RelativePath $root $inputFull; format = $kind; capability = $capability; network_access = $false; source_overwrite = $false; package_install = $false; reason = if ($capability -eq 'ready') { $null } elseif ($kind -eq 'xlsx') { 'xlsx adapter is preflight-only without dependency installation or implicit Excel automation.' } elseif ($kind -eq 'python') { 'Python execution requires a separately verified allowlisted runner.' } else { 'Unsupported input format.' }; external_calls = $false }
if ($Preflight -or $capability -ne 'ready') { if ($PassThru -or $Preflight) { $response | ConvertTo-Json -Depth 8 } else { $response | Format-List }; if ($capability -ne 'ready') { exit 1 }; exit 0 }
$runnerRoot = Join-Path $root '.qianlima\run-traces\readonly-runner'
New-Item -ItemType Directory -Path $runnerRoot -Force | Out-Null
$artifactPath = Join-Path $runnerRoot "$($plan.plan_id)-$StepId.json"
$summarizer = Join-Path $PSScriptRoot 'summarize-csv.ps1'
$summaryText = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $summarizer -InputPath $inputFull -NumericColumn $NumericColumn -GroupBy $GroupBy -OutputPath $artifactPath -Json 2>&1)
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) { throw "CSV adapter failed: $($summaryText -join "`n")" }
$summary = Get-Content -LiteralPath $artifactPath -Raw -Encoding UTF8 | ConvertFrom-Json
$hash = 'sha256:' + (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
$resultScript = Join-Path $PSScriptRoot 'new-qianlima-step-result.ps1'
$metrics = [ordered]@{ row_count = $summary.row_count; headers = @($summary.headers); numeric_summary = @($summary.numeric_summary); top_groups = @($summary.top_groups) } | ConvertTo-Json -Depth 12 -Compress
$metricsPath = Join-Path $runnerRoot "$($plan.plan_id)-$StepId-metrics.json"
[IO.File]::WriteAllText($metricsPath, $metrics, (New-Object Text.UTF8Encoding($false)))
$sourceRef = Get-RelativePath $root $inputFull
$outputRef = '.qianlima/run-traces/readonly-runner/' + [IO.Path]::GetFileName($artifactPath)
$resultText = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $resultScript -PlanPath $planFull -StepId $StepId -StepStatus completed -SourceFile $sourceRef -RowsRead ([int]$summary.row_count) -ComputedMetricsPath $metricsPath -ArtifactHash $hash -OutputRef $outputRef -PassThru 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Step result creation failed: $($resultText -join "`n")" }
$response.status = 'completed'; $response.capability = 'ready'; $response.artifact_ref = $outputRef; $response.artifact_hash = $hash; $response.rows_read = [int]$summary.row_count
if ($PassThru) { $response | ConvertTo-Json -Depth 10 } else { $response | Format-List }
