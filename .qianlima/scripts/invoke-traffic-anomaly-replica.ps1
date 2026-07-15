<#
.SYNOPSIS
Diagnose Amazon traffic-anomaly risk from local CSV snapshots.
.DESCRIPTION
Reads traffic-history CSV snapshots for a given ASIN, marketplace and date, then
computes organic and sponsored visibility proxies using CTR and freshness weights
and scores SERP Top-10 competitor pressure. Classifies risk (organic, sponsored,
seasonal or competitor) and writes a Markdown diagnosis report, printing its path.
.PARAMETER Asin
Target product ASIN to diagnose.
.PARAMETER Marketplace
Marketplace code such as US (default US).
.PARAMETER Date
Snapshot date to analyze, yyyy-MM-dd (default today).
.PARAMETER HistoryDir
Directory of traffic-history CSVs (default .qianlima/local-data/traffic-history).
.EXAMPLE
.\invoke-traffic-anomaly-replica.ps1 -Asin B0ABCDE123 -Marketplace US -Date 2026-07-13
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Asin,

    [string]$Marketplace = "US",

    [string]$Date = (Get-Date -Format "yyyy-MM-dd"),

    [string]$HistoryDir = ".qianlima/local-data/traffic-history",

    [string]$OutputDir = "reports",

    [string]$Version = "V0.2"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-CsvIfExists {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return @(Import-Csv -LiteralPath $Path -Encoding UTF8)
    }
    return @()
}

function To-Number {
    param([object]$Value)
    if ($null -eq $Value) { return 0.0 }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return 0.0 }
    $clean = $text -replace '[^\d\.\-]', ''
    if ([string]::IsNullOrWhiteSpace($clean)) { return 0.0 }
    return [double]::Parse($clean, [Globalization.CultureInfo]::InvariantCulture)
}

function Get-AbsoluteRank {
    param([object]$Page, [object]$Position)
    $p = [int](To-Number $Page)
    $pos = [int](To-Number $Position)
    if ($p -le 0 -or $pos -le 0) { return 0 }
    return (($p - 1) * 48) + $pos
}

function Get-CtrWeight {
    param([int]$Rank)
    if ($Rank -le 0) { return 0.0 }
    if ($Rank -le 3) { return 1.0 }
    if ($Rank -le 10) { return 0.65 }
    if ($Rank -le 20) { return 0.35 }
    if ($Rank -le 48) { return 0.12 }
    if ($Rank -le 96) { return 0.04 }
    return 0.0
}

function Get-FreshnessWeight {
    param([string]$SeenAt, [datetime]$RunDate)
    if ([string]::IsNullOrWhiteSpace($SeenAt)) { return 0.0 }
    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParse($SeenAt, [ref]$parsed)) { return 0.0 }
    $days = [math]::Max(0, ($RunDate.Date - $parsed.Date).Days)
    if ($days -le 2) { return 1.0 }
    if ($days -le 7) { return 0.60 }
    if ($days -le 14) { return 0.30 }
    return 0.10
}

function Format-Number {
    param([double]$Value)
    return $Value.ToString("0.##", [Globalization.CultureInfo]::InvariantCulture)
}

$runDate = [datetime]::Parse($Date)
$historyRoot = Resolve-Path -LiteralPath $HistoryDir
$asinSnapshots = Read-CsvIfExists (Join-Path $historyRoot "asin_snapshot_daily.csv")
$terms = Read-CsvIfExists (Join-Path $historyRoot "traffic_terms_snapshot.csv")
$serp = Read-CsvIfExists (Join-Path $historyRoot "serp_competitor_snapshot.csv")

$targetTerms = @($terms | Where-Object { $_.asin -eq $Asin -and $_.marketplace -eq $Marketplace -and $_.date -eq $Date })
$snapshotMatch = $asinSnapshots | Where-Object { $_.asin -eq $Asin -and $_.marketplace -eq $Marketplace -and $_.date -eq $Date } | Select-Object -Last 1
$targetSnapshot = @($snapshotMatch)

if ($targetTerms.Count -eq 0) {
    throw "No traffic term snapshot found for $Asin $Marketplace on $Date."
}

$organicScore = 0.0
$sponsoredScore = 0.0
$keywordRows = New-Object System.Collections.Generic.List[object]

foreach ($term in $targetTerms) {
    $searchVolume = To-Number $term.search_volume
    $organicRank = Get-AbsoluteRank $term.organic_page $term.organic_position
    $sponsoredRank = Get-AbsoluteRank $term.sponsored_page $term.sponsored_position
    $organicWeight = Get-CtrWeight $organicRank
    $sponsoredWeight = Get-CtrWeight $sponsoredRank
    $organicFreshness = Get-FreshnessWeight $term.organic_seen_at $runDate
    $sponsoredFreshness = Get-FreshnessWeight $term.sponsored_seen_at $runDate
    $organicContribution = $searchVolume * $organicWeight * $organicFreshness
    $sponsoredContribution = $searchVolume * $sponsoredWeight * $sponsoredFreshness
    $organicScore += $organicContribution
    $sponsoredScore += $sponsoredContribution

    $risk = "watch"
    if ($organicRank -gt 48 -or $organicRank -eq 0) { $risk = "weak_organic_rank" }
    if ($sponsoredFreshness -gt 0 -and $sponsoredFreshness -le 0.30) { $risk = "stale_sponsored_seen" }
    if ($term.keyword -match "father|dad|gift") { $risk = "seasonal_gift_term" }

    $keywordRows.Add([pscustomobject]@{
        keyword = $term.keyword
        searchVolume = $searchVolume
        organicRank = $organicRank
        sponsoredRank = $sponsoredRank
        organicContribution = $organicContribution
        sponsoredContribution = $sponsoredContribution
        risk = $risk
    })
}

$targetPrice = 0.0
$targetStar = 0.0
$targetReviews = 0.0
if ($targetSnapshot.Count -gt 0) {
    $targetPrice = To-Number $targetSnapshot[0].price
    $targetStar = To-Number $targetSnapshot[0].star
    $targetReviews = To-Number $targetSnapshot[0].review_count
}

$serpRows = @($serp | Where-Object { $_.marketplace -eq $Marketplace -and $_.date -eq $Date })
$competitorPressure = 0.0
$topCompetitors = New-Object System.Collections.Generic.List[object]
foreach ($row in $serpRows) {
    $rank = [int](To-Number $row.rank)
    if ($rank -le 0 -or $rank -gt 10) { continue }
    $score = 0.0
    if (([string]$row.sponsored) -eq "1") { $score += 2.0 }
    $price = To-Number $row.price
    $star = To-Number $row.star
    $reviews = To-Number $row.review_count
    if ($targetPrice -gt 0 -and $price -gt 0 -and $price -le ($targetPrice * 0.90)) { $score += 1.0 }
    if ($targetStar -gt 0 -and $star -ge ($targetStar + 0.2) -and $reviews -gt $targetReviews) { $score += 1.0 }
    $competitorPressure += $score
    $topCompetitors.Add([pscustomobject]@{
        keyword = $row.keyword
        rank = $rank
        asin = $row.asin
        sponsored = $row.sponsored
        price = $price
        star = $star
        reviews = $reviews
        score = $score
        title = $row.title
    })
}

$diagnosis = New-Object System.Collections.Generic.List[string]
if (@($keywordRows | Where-Object { $_.organicRank -gt 48 -or $_.organicRank -eq 0 }).Count -ge 2) {
    $diagnosis.Add("organic_side_risk")
}
if (@($keywordRows | Where-Object { $_.sponsoredRank -eq 0 -or $_.risk -eq "stale_sponsored_seen" }).Count -ge 2) {
    $diagnosis.Add("sponsored_coverage_risk")
}
if (@($keywordRows | Where-Object { $_.risk -eq "seasonal_gift_term" }).Count -ge 2) {
    $diagnosis.Add("seasonal_gift_term_dependency")
}
if ($competitorPressure -ge 5) {
    $diagnosis.Add("competitor_pressure")
}
if ($diagnosis.Count -eq 0) {
    $diagnosis.Add("no_strong_signal_in_current_snapshot")
}

$classification = ($diagnosis -join " + ")
$confidence = "medium_low"
if ($targetTerms.Count -ge 5 -and $serpRows.Count -ge 5) { $confidence = "medium" }

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$safeMarketplace = $Marketplace.ToUpperInvariant()
$outputPath = Join-Path $OutputDir ("{0}_traffic-anomaly-diagnosis_{1}_{2}_{3}.md" -f $Date, $Asin, $safeMarketplace, $Version)

$keywordTable = ($keywordRows | Sort-Object searchVolume -Descending | ForEach-Object {
    "| {0} | {1} | {2} | {3} | {4} | {5} |" -f $_.keyword, (Format-Number $_.searchVolume), $_.organicRank, $_.sponsoredRank, (Format-Number ($_.organicContribution + $_.sponsoredContribution)), $_.risk
}) -join "`n"

$competitorTable = ($topCompetitors | Sort-Object @{ Expression = "score"; Descending = $true }, @{ Expression = "rank"; Descending = $false } | Select-Object -First 10 | ForEach-Object {
    "| {0} | {1} | {2} | {3} | {4} | {5} | {6} |" -f $_.keyword, $_.rank, $_.asin, $_.sponsored, (Format-Number $_.price), ("{0}/{1}" -f (Format-Number $_.star), (Format-Number $_.reviews)), (Format-Number $_.score)
}) -join "`n"

$report = @"
# Traffic Anomaly Diagnosis Report

Date: $Date
Marketplace: $safeMarketplace
ASIN: $Asin
Compare window: local snapshot diagnosis
Data sources: local traffic-history CSV snapshots from Sorftime and Pangolinfo
Confidence: $confidence

## 1. Conclusion

Conclusion: $classification.

Most urgent action: prioritize the highest-search-volume core terms with weak organic rank or stale sponsored visibility; do not center budget decisions on seasonal gift terms only.

## 2. Root-Cause Chain

~~~mermaid
flowchart TD
  A[Current snapshot] --> B[Organic visibility proxy: $(Format-Number $organicScore)]
  A --> C[Sponsored visibility proxy: $(Format-Number $sponsoredScore)]
  A --> D[Competitor pressure proxy: $(Format-Number $competitorPressure)]
  B --> E[$classification]
  C --> E
  D --> E
  E --> F[Action: repair core-term ad coverage and organic visibility]
~~~

## 3. Proxy Metrics

| Metric | Current | Notes |
|---|---:|---|
| organic_visibility_score | $(Format-Number $organicScore) | Proxy only; not true organic traffic |
| sponsored_visibility_score | $(Format-Number $sponsoredScore) | Proxy only; not ad clicks or spend |
| competitor_pressure_score | $(Format-Number $competitorPressure) | SERP Top 10 competitor pressure proxy |

## 4. Keyword Evidence

| Keyword | Search volume | Organic absolute rank | Sponsored absolute rank | Proxy contribution | Risk |
|---|---:|---:|---:|---:|---|
$keywordTable

## 5. Competitor Evidence

| Keyword | Rank | Competitor ASIN | Sponsored | Price | Star/reviews | Pressure score |
|---|---:|---|---|---:|---|---:|
$competitorTable

## 6. Pending Verification

- This report uses local proxy metrics and does not include Xiyou's true daily organic or ad traffic.
- To confirm real traffic decline, connect Xiyou OpenAPI, ad backend, or Amazon Business Reports.
- With fewer than 7 days of local history, the script cannot auto-detect an anomaly window; it can only diagnose current risk.

## 7. Usage

- Read: asin_snapshot_daily.csv, traffic_terms_snapshot.csv, serp_competitor_snapshot.csv
- Wrote: $outputPath
"@

Set-Content -LiteralPath $outputPath -Value $report -Encoding UTF8
Write-Output $outputPath
