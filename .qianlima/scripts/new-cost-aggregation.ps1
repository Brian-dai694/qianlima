# new-cost-aggregation.ps1 -- Qianlima Cost Aggregation Dashboard
# Version: v1.0 | Created: 2026-07-11
# Usage: .\new-cost-aggregation.ps1 [-OutputPath <path>] [-DaysBack <int>]
# Scans usage-ledger/*.yaml, outputs Markdown cost dashboard.

<#
.SYNOPSIS
Generate a Markdown cost aggregation dashboard from usage-ledger YAML files.
.DESCRIPTION
Scans usage-ledger/*.yaml and parses each run's run/token/cost/result sections.
Aggregates estimated cost by week, month and a rolling window, then by workflow
and by day. Compares each run to a workflow baseline to compute total savings and
flag runs that exceed 2x baseline. Writes Markdown to OutputPath or to the console.
.PARAMETER OutputPath
File path for the Markdown report; when empty the report is written to the console.
.PARAMETER DaysBack
Number of days back to include when filtering ledger records (default 30).
.PARAMETER JsonOnly
Reserved switch; JSON export is not implemented and exits early.
.EXAMPLE
.\new-cost-aggregation.ps1 -DaysBack 7 -OutputPath .\reports\cost.md
#>
param(
    [string]$OutputPath = "",
    [int]$DaysBack = 30,
    [switch]$JsonOnly = $false
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LedgerDir = Join-Path (Join-Path $ScriptDir "..") "usage-ledger"

if (-not (Test-Path $LedgerDir)) {
    Write-Host "ERROR: usage-ledger directory not found at $LedgerDir"
    exit 1
}

# Parse all usage ledger YAML files
$records = @()
$parseErrors = @()

Get-ChildItem -Path $LedgerDir -Filter "*.yaml" | ForEach-Object {
    try {
        $content = Get-Content -Raw $_.FullName -Encoding UTF8
        $record = @{
            file_path = $_.FullName
            file_name = $_.Name
            file_date = $_.LastWriteTime
            run_id = ""
            date = ""
            workflow_id = ""
            task_name = ""
            model_provider = ""
            model_name = ""
            input_tokens = 0
            output_tokens = 0
            total_tokens = 0
            estimated_cost_usd = 0.0
            baseline_cost_usd = 0.0
            tier = ""
            notes = ""
            task_success = $false
        }

        $lines = $content -split '\r?\n'
        $section = "none"

        foreach ($line in $lines) {
            $t = $line.TrimStart()
            if ($t -match '^run:') { $section = "run"; continue }
            if ($t -match '^token_usage:') { $section = "token"; continue }
            if ($t -match '^cost:') { $section = "cost"; continue }
            if ($t -match '^result:') { $section = "result"; continue }
            if ($t -match '^context:') { $section = "context"; continue }

            if ($section -eq "run") {
                if ($t -match '^\s*run_id:\s*(.+)$') { $record.run_id = $matches[1].Trim() }
                if ($t -match '^\s*date:\s*(.+)$') { $record.date = $matches[1].Trim() }
                if ($t -match '^\s*task_name:\s*(.+)$') { $record.task_name = $matches[1].Trim() }
                if ($t -match '^\s*workflow_id:\s*(.+)$') { $record.workflow_id = $matches[1].Trim() }
                if ($t -match '^\s*model_provider:\s*(.+)$') { $record.model_provider = $matches[1].Trim() }
                if ($t -match '^\s*model_name:\s*(.+)$') { $record.model_name = $matches[1].Trim() }
            }
            if ($section -eq "token") {
                if ($t -match '^\s*input_tokens:\s*(\d+)') { $record.input_tokens = [int]$matches[1] }
                if ($t -match '^\s*output_tokens:\s*(\d+)') { $record.output_tokens = [int]$matches[1] }
                if ($t -match '^\s*total_tokens:\s*(\d+)') { $record.total_tokens = [int]$matches[1] }
            }
            if ($section -eq "cost") {
                if ($t -match '^\s*estimated_cost:\s*([\d.]+)') { $record.estimated_cost_usd = [double]$matches[1] }
                if ($t -match '^\s*estimated_cost_usd:\s*([\d.]+)') { $record.estimated_cost_usd = [double]$matches[1] }
                if ($t -match '^\s*baseline_cost_usd:\s*([\d.]+)') { $record.baseline_cost_usd = [double]$matches[1] }
                if ($t -match '^\s*tier:\s*(\S+)') { $record.tier = $matches[1].Trim() }
            }
            if ($section -eq "result") {
                if ($t -match '^\s*task_success:\s*(true|false)') { $record.task_success = ($matches[1] -eq 'true') }
                if ($t -match '^\s*notes:\s*(.+)$') { $record.notes = $matches[1].Trim() }
            }
        }

        $parsedDate = $record.file_date
        if ($record.date -match '^(\d{4}-\d{2}-\d{2})') {
            try { $parsedDate = [DateTime]::Parse($matches[1]) } catch {}
        }
        $record.parsed_date = $parsedDate

        $records += [PSCustomObject]$record
    } catch {
        $parseErrors += "$($_.Name): $_"
    }
}

if ($records.Count -eq 0) {
    Write-Host "No records found in usage-ledger."
    exit 0
}

# Time filters
$cutoff = (Get-Date).AddDays(-$DaysBack)
$filtered = $records | Where-Object { $_.parsed_date -ge $cutoff } | Sort-Object parsed_date

$now = Get-Date
$weekStart = $now.AddDays(-([int]$now.DayOfWeek)).Date
$monthStart = Get-Date -Year $now.Year -Month $now.Month -Day 1

$thisWeek = $filtered | Where-Object { $_.parsed_date -ge $weekStart }
$thisMonth = $filtered | Where-Object { $_.parsed_date -ge $monthStart }

# Aggregate helpers
function SumVal($arr, $propName) {
    $total = 0.0
    foreach ($item in $arr) {
        $v = $item.$propName
        if ($v) { $total += [double]$v }
    }
    return $total
}

function CountVal($arr) {
    if ($null -eq $arr) { return 0 }
    return @($arr).Count
}

$total30d = SumVal $filtered "estimated_cost_usd"
$totalWeek = SumVal $thisWeek "estimated_cost_usd"
$totalMonth = SumVal $thisMonth "estimated_cost_usd"
$cnt30d = CountVal $filtered
$cntWeek = CountVal $thisWeek
$cntMonth = CountVal $thisMonth
$successCnt = CountVal ($filtered | Where-Object { $_.task_success })
$avg30d = if ($cnt30d -gt 0) { [math]::Round($total30d / $cnt30d, 4) } else { 0 }
$avgWeek = if ($cntWeek -gt 0) { [math]::Round($totalWeek / $cntWeek, 4) } else { 0 }
$inputTokens30d = SumVal $filtered "input_tokens"
$outputTokens30d = SumVal $filtered "output_tokens"

# By workflow
$wfGroups = $filtered | Group-Object workflow_id
$byWorkflow = @()
foreach ($g in $wfGroups) {
    $cost = SumVal $g.Group "estimated_cost_usd"
    $cnt = CountVal $g.Group
    $avg = if ($cnt -gt 0) { [math]::Round($cost / $cnt, 4) } else { 0 }
    $pct = if ($total30d -gt 0) { [math]::Round(($cost / $total30d) * 100, 1) } else { 0 }
    $byWorkflow += [PSCustomObject]@{
        workflow_id = if ($g.Name) { $g.Name } else { "(unknown)" }
        run_count = $cnt
        total_cost = $cost
        avg_cost = $avg
        pct_of_total = $pct
    }
}
$byWorkflow = $byWorkflow | Sort-Object total_cost -Descending

# By day
$dayGroups = $filtered | Group-Object { $_.parsed_date.ToString("yyyy-MM-dd") }
$byDay = @()
foreach ($g in $dayGroups) {
    $cost = SumVal $g.Group "estimated_cost_usd"
    $byDay += [PSCustomObject]@{
        date = $g.Name
        run_count = CountVal $g.Group
        total_cost = $cost
    }
}
$byDay = $byDay | Sort-Object date

# Savings vs baseline
$defaultBaselines = @{
    "daily_ad_report" = 1.32
    "keyword_rank_scan" = 0.80
    "keyword_monitoring" = 0.60
    "sales_ledger" = 0.10
    "profit_check" = 0.15
    "competitor_comparison" = 2.50
    "listing_optimization" = 0.90
    "product_discovery" = 3.00
    "traffic_anomaly_diagnosis" = 0.70
    "inventory_alert" = 0.08
    "knowledge_digest" = 0.50
    "profit_review" = 0.40
    "strategy_exploration" = 1.50
    "startup_bootstrap" = 0.03
    "keyword_demand_lifecycle_timing" = 0.50
    "bid_suggestion_review" = 0.50
}

$totalSavings = 0.0
$recordsWithBaseline = 0
$savingsDetails = @()
$anomalies = @()

foreach ($rec in $filtered) {
    $wid = $rec.workflow_id
    if (-not $wid) { $wid = "" }
    $baseline = 0.0
    if ($rec.baseline_cost_usd -gt 0) {
        $baseline = $rec.baseline_cost_usd
    } elseif ($defaultBaselines.ContainsKey($wid)) {
        $baseline = $defaultBaselines[$wid]
    }

    if ($baseline -gt 0 -and $rec.estimated_cost_usd -gt 0) {
        $savings = $baseline - $rec.estimated_cost_usd
        $totalSavings += $savings
        $recordsWithBaseline++
        $rate = if ($baseline -gt 0) { [math]::Round(($savings / $baseline) * 100, 1) } else { 0 }
        $over = $rec.estimated_cost_usd -gt ($baseline * 2.0)

        $savingsDetails += [PSCustomObject]@{
            run_id = $rec.run_id
            date = $rec.date
            workflow_id = $wid
            estimated_cost = $rec.estimated_cost_usd
            baseline_cost = $baseline
            savings_usd = $savings
            savings_rate_pct = $rate
            is_over_baseline = $over
        }

        if ($over) { $anomalies += $rec }
    }
}

$totalSavings = [math]::Round($totalSavings, 4)

# Generate Markdown report
$sb = [System.Text.StringBuilder]::new()

[void]$sb.AppendLine("# Qianlima Cost Aggregation Dashboard")
[void]$sb.AppendLine("")
$genTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
[void]$sb.AppendLine("> Generated: $genTime")
if ($filtered.Count -gt 0) {
    $firstDate = $filtered[0].parsed_date.ToString("yyyy-MM-dd")
    $lastDate = $filtered[-1].parsed_date.ToString("yyyy-MM-dd")
    [void]$sb.AppendLine("> Date range: $firstDate ~ $lastDate ($cnt30d records)")
}
[void]$sb.AppendLine("> Data source: usage-ledger/")
[void]$sb.AppendLine("")

# Overview
[void]$sb.AppendLine("## Overview")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Metric | This Week | This Month | 30-Day |")
[void]$sb.AppendLine("|--------|-----------|------------|-------|")
[void]$sb.AppendLine("| Runs | $cntWeek | $cntMonth | $cnt30d |")
[void]$sb.AppendLine("| Successful | - | - | $successCnt |")
[void]$sb.AppendLine("| Total Cost | `$$totalWeek | `$$totalMonth | `$$total30d |")
[void]$sb.AppendLine("| Avg Cost/Run | `$$avgWeek | - | `$$avg30d |")
[void]$sb.AppendLine("| Input Tokens | - | - | $([math]::Round($inputTokens30d, 0).ToString('N0')) |")
[void]$sb.AppendLine("| Output Tokens | - | - | $([math]::Round($outputTokens30d, 0).ToString('N0')) |")
if ($recordsWithBaseline -gt 0) {
    [void]$sb.AppendLine("| Total Savings | - | - | `$$totalSavings |")
}
[void]$sb.AppendLine("")

# By workflow
[void]$sb.AppendLine("## By Workflow")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Workflow | Runs | Total Cost | Avg | Share |")
[void]$sb.AppendLine("|----------|------|------------|-----|-------|")
foreach ($w in $byWorkflow) {
    [void]$sb.AppendLine("| $($w.workflow_id) | $($w.run_count) | `$$($w.total_cost) | `$$($w.avg_cost) | $($w.pct_of_total)% |")
}
[void]$sb.AppendLine("")

# Savings
if ($recordsWithBaseline -gt 0) {
    [void]$sb.AppendLine("## Savings vs Baseline")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Total savings: `$$totalSavings  |  Records with baseline: $recordsWithBaseline")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Date | Workflow | Actual | Baseline | Savings | Rate | Status |")
    [void]$sb.AppendLine("|------|----------|--------|----------|---------|------|--------|")
    foreach ($s in $savingsDetails) {
        $status = "OK"
        if ($s.savings_usd -gt 0) { $status = "SAVED" }
        elseif ($s.savings_usd -lt 0) { $status = "OVER" }
        if ($s.is_over_baseline) { $status = "OVER 2x!" }
        [void]$sb.AppendLine("| $($s.date) | $($s.workflow_id) | `$$($s.estimated_cost) | `$$($s.baseline_cost) | `$$($s.savings_usd) | $($s.savings_rate_pct)% | $status |")
    }
    [void]$sb.AppendLine("")
}

# Daily trend
[void]$sb.AppendLine("## Daily Trend")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Date | Runs | Cost |")
[void]$sb.AppendLine("|------|------|------|")
foreach ($d in $byDay) {
    [void]$sb.AppendLine("| $($d.date) | $($d.run_count) | `$$($d.total_cost) |")
}
[void]$sb.AppendLine("")

# Anomalies
[void]$sb.AppendLine("## Anomalies")
[void]$sb.AppendLine("")
if ($anomalies.Count -gt 0) {
    [void]$sb.AppendLine("| Date | Workflow | Cost | Baseline | Ratio |")
    [void]$sb.AppendLine("|------|----------|------|----------|-------|")
    foreach ($a in $anomalies) {
        $bl = 0.0
        $wid = if ($a.workflow_id) { $a.workflow_id } else { "(unknown)" }
        if ($defaultBaselines.ContainsKey($wid)) { $bl = $defaultBaselines[$wid] }
        if ($a.baseline_cost_usd -gt 0) { $bl = $a.baseline_cost_usd }
        $ratio = if ($bl -gt 0) { [math]::Round($a.estimated_cost_usd / $bl, 1) } else { "N/A" }
        [void]$sb.AppendLine("| $($a.date) | $wid | `$$($a.estimated_cost_usd) | `$$bl | ${ratio}x |")
    }
    [void]$sb.AppendLine("")
    $ac = $anomalies.Count
    [void]$sb.AppendLine("> WARNING: $ac record(s) exceed baseline 2x. Check for valid reasons.")
} else {
    [void]$sb.AppendLine("OK - No cost anomalies in the past $DaysBack days.")
}
[void]$sb.AppendLine("")

# Data quality
$zeroCost = CountVal ($filtered | Where-Object { $_.estimated_cost_usd -eq 0 })
$unknownTier = CountVal ($filtered | Where-Object { -not $_.tier })
[void]$sb.AppendLine("## Data Quality")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Metric | Value |")
[void]$sb.AppendLine("|--------|-------|")
[void]$sb.AppendLine("| Total records | $cnt30d |")
[void]$sb.AppendLine("| Cost = $0 records | $zeroCost |")
[void]$sb.AppendLine("| Missing tier | $unknownTier |")
$peCount = $parseErrors.Count
[void]$sb.AppendLine("| Parse errors | $peCount |")
if ($peCount -gt 0) {
    $peDetails = $parseErrors -join "; "
    [void]$sb.AppendLine("| Error details | $peDetails |")
}
[void]$sb.AppendLine("")

# Footer
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("> Script: scripts/new-cost-aggregation.ps1 | Baselines: rules/cost-baselines.yaml | Routing: rules/model-routing-rules.yaml")
[void]$sb.AppendLine("> All baselines are `estimated` until calibrated. Upgrade to `measured` after N runs.")

$report = $sb.ToString()

if ($JsonOnly) {
    Write-Host "JSON export not implemented in this version."
    exit 0
}

if ($OutputPath) {
    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
    $report | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "Report saved to: $OutputPath"
} else {
    Write-Host $report
}
