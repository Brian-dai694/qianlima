<#
.SYNOPSIS
Build a Markdown cost dashboard from the JSONL run ledger.
.DESCRIPTION
Reads .qianlima/usage-ledger/runs.jsonl and optional baselines.json, filters runs
to the last N days, and computes total and last-7-day cost, per-workflow cost with
baseline overrun flags, a daily trend with bar chart, cost per outcome unit, and a
latency breakdown. Writes a UTF-8 (no BOM) Markdown report to OutputPath.
.PARAMETER Days
Size of the reporting window in days, 1-365 (default 30).
.PARAMETER OutputPath
Output Markdown path; defaults to .qianlima/reports/cost-dashboard.md.
.EXAMPLE
.\new-qianlima-cost-dashboard.ps1 -Days 14
#>
param(
  [ValidateRange(1, 365)]
  [int]$Days = 30,
  [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

function Get-Bar([double]$Value, [double]$Maximum) {
  if ($Maximum -le 0 -or $Value -le 0) { return '' }
  return ('#' * [math]::Max(1, [math]::Ceiling(($Value / $Maximum) * 20)))
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ledgerDirectory = Join-Path $projectRoot '.qianlima\usage-ledger'
$ledgerPath = Join-Path $ledgerDirectory 'runs.jsonl'
$baselinePath = Join-Path $ledgerDirectory 'baselines.json'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $projectRoot '.qianlima\reports\cost-dashboard.md'
}

$runs = @()
if (Test-Path -LiteralPath $ledgerPath -PathType Leaf) {
  $runs = @(Get-Content -LiteralPath $ledgerPath -Encoding UTF8 |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object {
      try { $_ | ConvertFrom-Json } catch { Write-Warning "Skipping invalid ledger line: $($_.Exception.Message)" }
    })
}

$cutoff = (Get-Date).ToUniversalTime().AddDays(-($Days - 1)).Date
$periodRuns = @($runs | Where-Object {
  $_.recorded_at -and ([datetime]$_.recorded_at).ToUniversalTime() -ge $cutoff
})
$completedRuns = @($periodRuns | Where-Object { $_.status -eq 'completed' })
$totalCost = [math]::Round((@($periodRuns | Measure-Object -Property estimated_cost_usd -Sum).Sum), 6)
$weekCutoff = (Get-Date).ToUniversalTime().AddDays(-6).Date
$weekCost = [math]::Round((@($periodRuns | Where-Object { ([datetime]$_.recorded_at).ToUniversalTime() -ge $weekCutoff } | Measure-Object -Property estimated_cost_usd -Sum).Sum), 6)
$maxDailyCost = 0.0

$baselines = $null
if (Test-Path -LiteralPath $baselinePath -PathType Leaf) {
  $baselineDocument = Get-Content -LiteralPath $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($baselineDocument.PSObject.Properties.Name -contains 'workflows') { $baselines = $baselineDocument.workflows }
}

$daily = @($periodRuns | Group-Object { ([datetime]$_.recorded_at).ToUniversalTime().ToString('yyyy-MM-dd') } | ForEach-Object {
  [PSCustomObject]@{ Date = $_.Name; Cost = [math]::Round((@($_.Group | Measure-Object -Property estimated_cost_usd -Sum).Sum), 6); Runs = $_.Count }
} | Sort-Object Date)
if ($daily.Count -gt 0) { $maxDailyCost = [double](($daily | Measure-Object -Property Cost -Maximum).Maximum) }

$workflowRows = @($periodRuns | Group-Object workflow_id | ForEach-Object {
  $cost = [math]::Round((@($_.Group | Measure-Object -Property estimated_cost_usd -Sum).Sum), 6)
  $baselineProperty = if ($null -ne $baselines) { $baselines.PSObject.Properties[$_.Name] } else { $null }
  $baseline = if ($null -ne $baselineProperty) { [double]$baselineProperty.Value.baseline_cost_usd } else { $null }
  $overruns = if ($null -ne $baseline -and $baseline -gt 0) { @($_.Group | Where-Object { [double]$_.estimated_cost_usd -gt ($baseline * 2) }).Count } else { 0 }
  [PSCustomObject]@{ Workflow = $_.Name; Runs = $_.Count; Cost = $cost; Baseline = $baseline; Overruns = $overruns }
} | Sort-Object Cost -Descending)

$dailyRows = if ($daily.Count -eq 0) { '| No records | $0.000000 | 0 | |' } else {
  ($daily | ForEach-Object { "| $($_.Date) | `$$($_.Cost.ToString('0.000000')) | $($_.Runs) | $(Get-Bar $_.Cost $maxDailyCost) |" }) -join "`n"
}
$workflowTable = if ($workflowRows.Count -eq 0) { '| No records | 0 | $0.000000 | not set | 0 |' } else {
  ($workflowRows | ForEach-Object {
    $baselineText = if ($null -eq $_.Baseline) { 'not set' } else { '$' + $_.Baseline.ToString('0.000000') }
    "| $($_.Workflow) | $($_.Runs) | `$$($_.Cost.ToString('0.000000')) | $baselineText | $($_.Overruns) |"
  }) -join "`n"
}

$outcomeRows = @($completedRuns | Where-Object { $_.outcome_units -gt 0 } | Group-Object workflow_id | ForEach-Object {
  $units = [int](($_.Group | Measure-Object -Property outcome_units -Sum).Sum)
  $cost = [double](($_.Group | Measure-Object -Property estimated_cost_usd -Sum).Sum)
  $unitName = @($_.Group | Select-Object -ExpandProperty outcome_unit -Unique | Where-Object { $_ }) -join ', '
  [PSCustomObject]@{ Workflow = $_.Name; Units = $units; UnitName = $unitName; CostPerOutcome = if ($units -gt 0) { $cost / $units } else { 0 } }
})
$outcomeTable = if ($outcomeRows.Count -eq 0) { '| No completed outcome units recorded yet | - | - | - |' } else {
  ($outcomeRows | ForEach-Object { "| $($_.Workflow) | $($_.Units) | $($_.UnitName) | `$$($_.CostPerOutcome.ToString('0.000000')) |" }) -join "`n"
}

$latencyFields = @('startup_ms', 'routing_ms', 'context_load_ms', 'tool_ms', 'model_ms', 'first_useful_output_ms')
$latencyRows = foreach ($field in $latencyFields) {
  $values = @($periodRuns | ForEach-Object {
    $property = $_.PSObject.Properties[$field]
    if ($null -ne $property -and [double]$property.Value -gt 0) { [double]$property.Value }
  })
  $label = ($field -replace '_', ' ')
  if ($values.Count -gt 0) {
    [PSCustomObject]@{ Label = $label; Samples = $values.Count; Average = [math]::Round((($values | Measure-Object -Average).Average), 1) }
  }
}
$latencyTable = if (@($latencyRows).Count -eq 0) { '| No latency samples recorded yet | 0 | - |' } else {
  ($latencyRows | ForEach-Object { "| $($_.Label) | $($_.Samples) | $($_.Average) ms |" }) -join "`n"
}

$markdown = @"
# Qianlima Cost Dashboard

Generated at: $((Get-Date).ToUniversalTime().ToString('o'))
Window: last $Days days
Ledger: `.qianlima/usage-ledger/runs.jsonl` (private, append-only)

## Cost Card

| Metric | Value |
|---|---:|
| Runs recorded | $($periodRuns.Count) |
| Completed runs | $($completedRuns.Count) |
| Last 7 days cost | `$$($weekCost.ToString('0.000000')) |
| Last $Days days cost | `$$($totalCost.ToString('0.000000')) |
| Workflows above 2x baseline | $([int](($workflowRows | Measure-Object -Property Overruns -Sum).Sum)) |

## Workflow Cost

| Workflow | Runs | Cost | Baseline per run | >2x baseline |
|---|---:|---:|---:|---:|
$workflowTable

## Daily Trend

| Date | Cost | Runs | Trend |
|---|---:|---:|---|
$dailyRows

## Cost Per Outcome

| Workflow | Outcome units | Unit | Cost per outcome |
|---|---:|---|---:|
$outcomeTable

## Latency Breakdown

| Stage | Samples | Average |
|---|---:|---:|
$latencyTable

## Interpretation

- A baseline is calculated only from completed real runs; no sample cost is invented.
- A run is flagged when its cost exceeds twice its workflow baseline.
- Zero-cost local scripts are retained as execution evidence but do not substitute for model usage.
- Latency averages use only records that supplied the corresponding measured field.
"@

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
  New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
[System.IO.File]::WriteAllText($OutputPath, $markdown, [System.Text.UTF8Encoding]::new($false))
Write-Host "Cost dashboard generated: $OutputPath"
