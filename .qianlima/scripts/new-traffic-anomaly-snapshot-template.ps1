<#
.SYNOPSIS
    Generates an empty traffic-anomaly snapshot JSON template for an ASIN.
.DESCRIPTION
    Builds a blank snapshot skeleton for one ASIN and marketplace on a given
    date, with empty product, traffic_terms, keyword_rank_history, and
    serp_competitors sections. Each supplied keyword (comma-separated values
    are split) seeds one row in each keyword section for later manual fill-in.
.PARAMETER Asin
    Target ASIN; upper-cased and used in the default output file name.
.PARAMETER Marketplace
    Marketplace code (default US).
.PARAMETER Keywords
    Keywords to scaffold; comma-separated entries are split into individual rows.
.PARAMETER OutputPath
    Destination JSON path; defaults to a snapshot file under traffic-history.
.EXAMPLE
    ./new-traffic-anomaly-snapshot-template.ps1 -Asin B0XXXXXXXX -Keywords "pet bottle","dog water"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Asin,

    [string]$Marketplace = "US",

    [string]$Date = (Get-Date -Format "yyyy-MM-dd"),

    [string[]]$Keywords = @(),

    [string]$OutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $safeAsin = $Asin.ToUpperInvariant()
    $OutputPath = ".qianlima/local-data/traffic-history/snapshot-$Date-$safeAsin.json"
}

$trafficTerms = @()
$rankHistory = @()
$serpCompetitors = @()
$normalizedKeywords = @()

foreach ($keyword in $Keywords) {
    if ([string]::IsNullOrWhiteSpace($keyword)) { continue }
    $parts = [string]$keyword -split ","
    foreach ($part in $parts) {
        $trimmed = $part.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            $normalizedKeywords += $trimmed
        }
    }
}

foreach ($keyword in $normalizedKeywords) {
    $trafficTerms += [ordered]@{
        keyword = $keyword
        search_volume = ""
        bid_suggested = ""
        exposure_type = ""
        organic_page = ""
        organic_position = ""
        organic_seen_at = ""
        sponsored_page = ""
        sponsored_position = ""
        sponsored_seen_at = ""
        source = "Sorftime product_traffic_terms"
    }
    $rankHistory += [ordered]@{
        observed_at = ""
        keyword = $keyword
        rank_type = "organic"
        page = ""
        position = ""
        absolute_rank = ""
        total_on_page = ""
        source = "Sorftime product_ranking_trend_by_keyword"
    }
    $serpCompetitors += [ordered]@{
        keyword = $keyword
        rank = ""
        asin = ""
        title = ""
        sponsored = ""
        price = ""
        star = ""
        review_count = ""
        sales_badge = ""
        source = "Pangolinfo search_amazon"
    }
}

$snapshot = [ordered]@{
    date = $Date
    marketplace = $Marketplace
    asin = $Asin.ToUpperInvariant()
    source = "Sorftime MCP + Pangolinfo MCP"
    product = [ordered]@{
        title = ""
        brand = ""
        price = ""
        star = ""
        review_count = ""
        monthly_sales = ""
        monthly_revenue = ""
        bsr_main = ""
        bsr_leaf = ""
        seller = ""
        variant_count = ""
        source = "Sorftime product_detail + Pangolinfo get_amazon_product"
    }
    traffic_terms = $trafficTerms
    keyword_rank_history = $rankHistory
    serp_competitors = $serpCompetitors
}

$dir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
}

$snapshot | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output $OutputPath
