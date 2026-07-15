<#
.SYNOPSIS
    Orchestrates import and replica-report generation for a traffic snapshot.
.DESCRIPTION
    Reads a snapshot JSON, validates its date and asin, then invokes the
    importer (unless -SkipImport) to store it in the history directory and the
    reporter to build the traffic-anomaly replica report. Emits a JSON summary
    of the input, whether it imported, the import result, and the report path.
.PARAMETER InputJson
    Path to the snapshot JSON file to process (must exist).
.PARAMETER HistoryDir
    Traffic history directory passed to the importer and reporter.
.PARAMETER OutputDir
    Directory where the replica report is written.
.PARAMETER SkipImport
    Skip the import step and only regenerate the report.
.EXAMPLE
    ./run-traffic-anomaly-replica.ps1 -InputJson snapshot-2026-07-13-B0XXXX.json -OutputDir reports
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$InputJson,

    [string]$HistoryDir = ".qianlima/local-data/traffic-history",

    [string]$OutputDir = "reports",

    [string]$Version = "V0.3",

    [switch]$SkipImport
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-JsonProp {
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

$snapshot = Get-Content -LiteralPath $InputJson -Raw -Encoding UTF8 | ConvertFrom-Json
$date = [string](Get-JsonProp $snapshot "date")
$marketplace = [string](Get-JsonProp $snapshot "marketplace" "US")
$asin = [string](Get-JsonProp $snapshot "asin")

if ([string]::IsNullOrWhiteSpace($date)) { throw "Snapshot date is required." }
if ([string]::IsNullOrWhiteSpace($asin)) { throw "Snapshot asin is required." }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$importer = Join-Path $scriptDir "import-traffic-anomaly-snapshot.ps1"
$reporter = Join-Path $scriptDir "invoke-traffic-anomaly-replica.ps1"

if (-not (Test-Path -LiteralPath $importer)) { throw "Importer script not found: $importer" }
if (-not (Test-Path -LiteralPath $reporter)) { throw "Reporter script not found: $reporter" }

$importResult = $null
if (-not $SkipImport) {
    $importResult = & powershell -NoProfile -ExecutionPolicy Bypass -File $importer -InputJson $InputJson -HistoryDir $HistoryDir
}

$reportPath = & powershell -NoProfile -ExecutionPolicy Bypass -File $reporter -Asin $asin -Marketplace $marketplace -Date $date -HistoryDir $HistoryDir -OutputDir $OutputDir -Version $Version

[pscustomobject]@{
    input = $InputJson
    imported = (-not $SkipImport)
    import_result = $importResult
    report = $reportPath
} | ConvertTo-Json -Depth 8
