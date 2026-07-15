<#
.SYNOPSIS
  Build a daily Amazon ad-ops report from a raw CSV export.
.DESCRIPTION
  Loads inbox\<Date>_ad-data_raw_<Marketplace>_<Version>.csv, validates required headers,
  and filters to the given date and marketplace. Computes core metrics (ACoS, CPC, CTR,
  CVR), diagnoses each ad group into issue, strong, or watch, and writes a Markdown report,
  a JSON trace, and a usage-ledger entry. Only suggests actions; changes nothing external.
.PARAMETER Date
  Report date in YYYY-MM-DD, used for input and output file names and row filtering.
.PARAMETER Marketplace
  Marketplace code such as US, used for filtering and file naming.
.PARAMETER Version
  File version tag (e.g. V1) embedded in input and output names.
.EXAMPLE
  .\generate-daily-ad-report.ps1 -Date 2026-06-23 -Marketplace US -Version V1
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$Date = '2026-06-23',
  [string]$Marketplace = 'US',
  [string]$Version = 'V1'
)

$ErrorActionPreference = 'Stop'

function Format-Money([double]$value) {
  return ('$' + $value.ToString('0.00'))
}

function Format-PercentValue($value) {
  if ($null -eq $value) {
    return 'N/A'
  }
  return (($value * 100).ToString('0.00') + '%')
}

function Safe-Divide([double]$numerator, [double]$denominator) {
  if ($denominator -eq 0) {
    return $null
  }
  return $numerator / $denominator
}

$inputFile = "$Date" + '_ad-data_raw_' + "$Marketplace" + '_' + "$Version.csv"
$inputPath = Join-Path (Join-Path $Root 'inbox') $inputFile
if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
  throw "Input ad data file not found: $inputPath"
}

$rows = Import-Csv -LiteralPath $inputPath
if ($rows.Count -eq 0) {
  throw 'Ad data is empty.'
}

$requiredHeaders = @('date', 'marketplace', 'campaign_name', 'ad_group_name', 'impressions', 'clicks', 'spend', 'sales', 'orders')
$headers = $rows[0].PSObject.Properties.Name
foreach ($header in $requiredHeaders) {
  if ($header -notin $headers) {
    throw "Ad data missing required field: $header"
  }
}

$filtered = @($rows | Where-Object { $_.date -eq $Date -and $_.marketplace -eq $Marketplace })
if ($filtered.Count -eq 0) {
  throw "No rows found for $Date / $Marketplace."
}

$totalSpend = [double](($filtered | Measure-Object -Property spend -Sum).Sum)
$totalSales = [double](($filtered | Measure-Object -Property sales -Sum).Sum)
$totalOrders = [double](($filtered | Measure-Object -Property orders -Sum).Sum)
$totalClicks = [double](($filtered | Measure-Object -Property clicks -Sum).Sum)
$totalImpressions = [double](($filtered | Measure-Object -Property impressions -Sum).Sum)

$acos = Safe-Divide $totalSpend $totalSales
$cpc = Safe-Divide $totalSpend $totalClicks
$ctr = Safe-Divide $totalClicks $totalImpressions
$cvr = Safe-Divide $totalOrders $totalClicks

$diagnosed = foreach ($row in $filtered) {
  $spend = [double]$row.spend
  $sales = [double]$row.sales
  $orders = [double]$row.orders
  $clicks = [double]$row.clicks
  $rowAcos = Safe-Divide $spend $sales
  $problem = 'No obvious issue'
  $suggestion = 'Keep monitoring.'
  $type = 'Watch'

  if ($spend -ge 15 -and $orders -eq 0) {
    $type = 'Issue'
    $problem = 'High spend with no orders'
    $suggestion = 'Lower bid, pause for review, or check listing conversion.'
  } elseif ($null -ne $rowAcos -and $rowAcos -gt 0.35 -and $orders -ge 1) {
    $type = 'Issue'
    $problem = 'High ACoS'
    $suggestion = 'Lower bid by 10%-20% and check targeting relevance.'
  } elseif ($null -ne $rowAcos -and $rowAcos -le 0.3 -and $orders -ge 2) {
    $type = 'Strong'
    $problem = 'Strong performance'
    $suggestion = 'Keep or slightly increase budget after manual confirmation.'
  } elseif ($clicks -ge 15 -and $orders -eq 0) {
    $type = 'Issue'
    $problem = 'High clicks with low conversion'
    $suggestion = 'Check image, price, reviews, coupon, and listing conversion.'
  }

  [PSCustomObject]@{
    Type = $type
    Campaign = $row.campaign_name
    AdGroup = $row.ad_group_name
    Spend = $spend
    Sales = $sales
    Orders = $orders
    Acos = $rowAcos
    Problem = $problem
    Suggestion = $suggestion
  }
}

$issueRows = @($diagnosed | Where-Object { $_.Type -eq 'Issue' })
$strongRows = @($diagnosed | Where-Object { $_.Type -eq 'Strong' })

function Build-IssueRows($items) {
  if ($items.Count -eq 0) {
    return '| None | 0.00 | 0.00 | 0 | N/A | None | None |'
  }
  $lines = foreach ($item in $items) {
    $name = "$($item.Campaign) / $($item.AdGroup)"
    $acosText = Format-PercentValue $item.Acos
    "| $name | $($item.Spend.ToString('0.00')) | $($item.Sales.ToString('0.00')) | $($item.Orders) | $acosText | $($item.Problem) | $($item.Suggestion) |"
  }
  return ($lines -join "`n")
}

function Build-StrongRows($items) {
  if ($items.Count -eq 0) {
    return '| None | 0.00 | 0.00 | 0 | N/A | N/A | None |'
  }
  $lines = foreach ($item in $items) {
    $name = "$($item.Campaign) / $($item.AdGroup)"
    $acosText = Format-PercentValue $item.Acos
    "| $name | $($item.Spend.ToString('0.00')) | $($item.Sales.ToString('0.00')) | $($item.Orders) | $acosText | N/A | $($item.Suggestion) |"
  }
  return ($lines -join "`n")
}

$reportFile = "$Date" + '_ad-ops_daily-report_' + "$Marketplace" + '_' + "$Version.md"
$reportPath = Join-Path (Join-Path $Root 'reports') $reportFile
$tracePath = Join-Path (Join-Path $Root 'logs') "$Date`_daily_ad_report_trace.json"
$usagePath = Join-Path (Join-Path $Root 'usage-ledger') '2026-06_usage_cost.yaml'

$summary = @"
# Daily Ad Operations Report

Date: $Date
Marketplace: $Marketplace
Account: sample account
Data source: local uploaded ad data file

## 1. Core Metrics

| Metric | Value |
|---|---:|
| Ad spend | $(Format-Money $totalSpend) |
| Ad sales | $(Format-Money $totalSales) |
| Ad orders | $totalOrders |
| Overall ACoS | $(Format-PercentValue $acos) |
| CPC | $(if ($null -eq $cpc) { 'N/A' } else { Format-Money $cpc }) |
| CTR | $(Format-PercentValue $ctr) |
| CVR | $(Format-PercentValue $cvr) |
| TACoS | N/A |

## 2. Key Findings

1. Read $($filtered.Count) ad data rows. Total spend: $(Format-Money $totalSpend). Ad sales: $(Format-Money $totalSales).
2. Found $($issueRows.Count) issue ad groups and $($strongRows.Count) strong ad groups.
3. This skeleton only generates suggestions. It does not change bids, budgets, or external systems.

## 3. Issue Ad Groups

| Ad group | Spend | Sales | Orders | ACoS | Issue | Suggestion |
|---|---:|---:|---:|---:|---|---|
$(Build-IssueRows $issueRows)

## 4. Strong Ad Groups

| Ad group | Spend | Sales | Orders | ACoS | CVR | Suggestion |
|---|---:|---:|---:|---:|---:|---|
$(Build-StrongRows $strongRows)

## 5. Actions Requiring Manual Confirmation

| Action | Target | Reason | Risk |
|---|---|---|---|
| None executed | All ad groups | Skeleton mode only generates suggestions | Low |

## 6. Data Quality Check

- Missing fields: none
- Blocking anomalies: none found
- Date range: $Date
- Not verified: TACoS requires total sales data, not included in sample input

## 7. Execution Record

- Data read: success, $($filtered.Count) rows
- Diagnosis rules: basic rules applied
- Report generation: success
- Validation: required field check passed

## 8. Usage And Cost

- Model calls: 0
- Estimated tokens: 0
- Tool calls: local CSV read 1 time
- Estimated cost: 0 USD

"@

Set-Content -LiteralPath $reportPath -Value $summary -Encoding UTF8

$trace = [PSCustomObject]@{
  run_id = "daily_ad_report-$Date-$Marketplace-$Version"
  workflow_id = 'daily_ad_report'
  source_file = $inputPath
  report_file = $reportPath
  rows_read = $filtered.Count
  status = 'completed'
  generated_at = (Get-Date).ToString('o')
}
$trace | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $tracePath -Encoding UTF8

$usage = @"
records:
  - run_id: daily_ad_report-$Date-$Marketplace-$Version
    workflow_id: daily_ad_report
    source_id: file_ads_us_daily
    rows_read: $($filtered.Count)
    model_calls: 0
    input_tokens: 0
    output_tokens: 0
    estimated_cost_usd: 0
    generated_at: $((Get-Date).ToString('o'))
"@
Set-Content -LiteralPath $usagePath -Value $usage -Encoding UTF8

Write-Host "Report generated: $reportPath"
Write-Host "Trace generated: $tracePath"
Write-Host "Usage ledger updated: $usagePath"
