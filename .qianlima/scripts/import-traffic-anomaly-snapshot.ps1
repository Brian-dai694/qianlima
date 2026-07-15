<#
.SYNOPSIS
Import a traffic snapshot JSON into local traffic-history CSV files.
.DESCRIPTION
Reads a snapshot JSON and appends rows to asin_snapshot_daily.csv,
traffic_terms_snapshot.csv, keyword_rank_history.csv and
serp_competitor_snapshot.csv under HistoryDir, creating headers when files are
missing or empty. Requires date and asin, CSV-escapes all values, and returns a
JSON summary of how many rows were written to each file.
.PARAMETER InputJson
Path to the snapshot JSON file to import.
.PARAMETER HistoryDir
Directory holding the traffic-history CSV files (default .qianlima/local-data/traffic-history).
.EXAMPLE
.\import-traffic-anomaly-snapshot.ps1 -InputJson .\snapshots\2026-07-13.json
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$InputJson,

    [string]$HistoryDir = ".qianlima/local-data/traffic-history"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Escape-Csv {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    $text = [string]$Value
    if ($text.Contains('"')) { $text = $text.Replace('"', '""') }
    if ($text -match '[,"\r\n]') { return '"' + $text + '"' }
    return $text
}

function Add-CsvLine {
    param(
        [string]$Path,
        [string[]]$Fields
    )
    $line = ($Fields | ForEach-Object { Escape-Csv $_ }) -join ","
    Add-Content -LiteralPath $Path -Value $line -Encoding UTF8
}

function Ensure-CsvFile {
    param(
        [string]$Path,
        [string]$Header
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        Set-Content -LiteralPath $Path -Value $Header -Encoding UTF8
        return
    }
    $item = Get-Item -LiteralPath $Path
    if ($item.Length -eq 0) {
        Set-Content -LiteralPath $Path -Value $Header -Encoding UTF8
    }
}

function Get-Prop {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default = ""
    )
    if ($null -eq $Object) { return $Default }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $Default }
    if ($null -eq $prop.Value) { return $Default }
    return $prop.Value
}

if (-not (Test-Path -LiteralPath $InputJson)) {
    throw "Input JSON not found: $InputJson"
}

Ensure-Directory $HistoryDir
$snapshot = Get-Content -LiteralPath $InputJson -Raw -Encoding UTF8 | ConvertFrom-Json

$date = Get-Prop $snapshot "date"
$marketplace = Get-Prop $snapshot "marketplace" "US"
$asin = Get-Prop $snapshot "asin"
$source = Get-Prop $snapshot "source" "manual_snapshot"

if ([string]::IsNullOrWhiteSpace([string]$date)) { throw "Snapshot date is required." }
if ([string]::IsNullOrWhiteSpace([string]$asin)) { throw "Snapshot asin is required." }

$asinPath = Join-Path $HistoryDir "asin_snapshot_daily.csv"
$termsPath = Join-Path $HistoryDir "traffic_terms_snapshot.csv"
$rankPath = Join-Path $HistoryDir "keyword_rank_history.csv"
$serpPath = Join-Path $HistoryDir "serp_competitor_snapshot.csv"

Ensure-CsvFile $asinPath "date,marketplace,asin,title,brand,price,star,review_count,monthly_sales,monthly_revenue,bsr_main,bsr_leaf,seller,variant_count,source"
Ensure-CsvFile $termsPath "date,marketplace,asin,keyword,search_volume,bid_suggested,exposure_type,organic_page,organic_position,organic_seen_at,sponsored_page,sponsored_position,sponsored_seen_at,source"
Ensure-CsvFile $rankPath "observed_at,date,marketplace,asin,keyword,rank_type,page,position,absolute_rank,total_on_page,source"
Ensure-CsvFile $serpPath "date,marketplace,keyword,rank,asin,title,sponsored,price,star,review_count,sales_badge,source"

$product = Get-Prop $snapshot "product" $null
if ($null -ne $product) {
    Add-CsvLine $asinPath @(
        $date,
        $marketplace,
        $asin,
        (Get-Prop $product "title"),
        (Get-Prop $product "brand"),
        (Get-Prop $product "price"),
        (Get-Prop $product "star"),
        (Get-Prop $product "review_count"),
        (Get-Prop $product "monthly_sales"),
        (Get-Prop $product "monthly_revenue"),
        (Get-Prop $product "bsr_main"),
        (Get-Prop $product "bsr_leaf"),
        (Get-Prop $product "seller"),
        (Get-Prop $product "variant_count"),
        (Get-Prop $product "source" $source)
    )
}

$trafficTerms = @(Get-Prop $snapshot "traffic_terms" @())
foreach ($term in $trafficTerms) {
    Add-CsvLine $termsPath @(
        $date,
        $marketplace,
        $asin,
        (Get-Prop $term "keyword"),
        (Get-Prop $term "search_volume"),
        (Get-Prop $term "bid_suggested"),
        (Get-Prop $term "exposure_type"),
        (Get-Prop $term "organic_page"),
        (Get-Prop $term "organic_position"),
        (Get-Prop $term "organic_seen_at"),
        (Get-Prop $term "sponsored_page"),
        (Get-Prop $term "sponsored_position"),
        (Get-Prop $term "sponsored_seen_at"),
        (Get-Prop $term "source" $source)
    )
}

$rankHistory = @(Get-Prop $snapshot "keyword_rank_history" @())
foreach ($rank in $rankHistory) {
    Add-CsvLine $rankPath @(
        (Get-Prop $rank "observed_at" $date),
        $date,
        $marketplace,
        $asin,
        (Get-Prop $rank "keyword"),
        (Get-Prop $rank "rank_type"),
        (Get-Prop $rank "page"),
        (Get-Prop $rank "position"),
        (Get-Prop $rank "absolute_rank"),
        (Get-Prop $rank "total_on_page"),
        (Get-Prop $rank "source" $source)
    )
}

$serpSnapshots = @(Get-Prop $snapshot "serp_competitors" @())
foreach ($row in $serpSnapshots) {
    Add-CsvLine $serpPath @(
        $date,
        $marketplace,
        (Get-Prop $row "keyword"),
        (Get-Prop $row "rank"),
        (Get-Prop $row "asin"),
        (Get-Prop $row "title"),
        (Get-Prop $row "sponsored"),
        (Get-Prop $row "price"),
        (Get-Prop $row "star"),
        (Get-Prop $row "review_count"),
        (Get-Prop $row "sales_badge"),
        (Get-Prop $row "source" $source)
    )
}

[pscustomobject]@{
    input = $InputJson
    date = $date
    marketplace = $marketplace
    asin = $asin
    product_rows = if ($null -ne $product) { 1 } else { 0 }
    traffic_term_rows = $trafficTerms.Count
    rank_rows = $rankHistory.Count
    serp_rows = $serpSnapshots.Count
} | ConvertTo-Json -Depth 4
