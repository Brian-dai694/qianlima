<#
.SYNOPSIS
Summarizes a local CSV into numeric stats and group counts.
.DESCRIPTION
Imports the CSV and produces a schema-versioned report: per-column numeric
summaries (valid/invalid counts, sum, average, min, max) for each NumericColumn,
and top group row counts for each GroupBy field. Reports missing columns and
records a rerun command. Emits JSON to OutputPath and/or stdout.
.PARAMETER InputPath
Path to the source .csv file; must exist and have a .csv extension.
.PARAMETER NumericColumn
Columns to aggregate numerically; accepts comma-separated values.
.PARAMETER GroupBy
Columns to group rows by for top-count reporting.
.PARAMETER OutputPath
Optional file to write the JSON result to; stdout is used when omitted.
.EXAMPLE
.\summarize-csv.ps1 -InputPath data\ads.csv -NumericColumn spend,sales -GroupBy campaign
#>
param(
  [Parameter(Mandatory)]
  [string]$InputPath,
  [string[]]$NumericColumn = @(),
  [string[]]$GroupBy = @(),
  [int]$TopAnomalyCount = 10,
  [string]$FormulaVersion = 'v1',
  [string]$OutputPath = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
  throw "CSV input not found: $InputPath"
}
if ([IO.Path]::GetExtension($InputPath) -ne '.csv') {
  throw 'Only CSV input is supported by this local aggregator.'
}
if ($TopAnomalyCount -lt 1 -or $TopAnomalyCount -gt 100) {
  throw 'TopAnomalyCount must be between 1 and 100.'
}

# PowerShell -File callers often pass comma-separated values as one argument.
$NumericColumn = @($NumericColumn | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$GroupBy = @($GroupBy | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$rows = @(Import-Csv -LiteralPath $InputPath)
$headers = if ($rows.Count -gt 0) { @($rows[0].PSObject.Properties.Name) } else { @() }
$missingNumeric = @($NumericColumn | Where-Object { $_ -notin $headers })
$missingGroups = @($GroupBy | Where-Object { $_ -notin $headers })

$numericSummary = @()
foreach ($column in $NumericColumn | Where-Object { $_ -in $headers }) {
  $values = New-Object System.Collections.Generic.List[double]
  $invalidCount = 0
  foreach ($row in $rows) {
    $parsed = 0.0
    if ([double]::TryParse([string]$row.$column, [ref]$parsed)) { $values.Add($parsed) } else { $invalidCount++ }
  }
  $ordered = @($values | Sort-Object)
  $numericSummary += [PSCustomObject]@{
    column = $column
    valid_count = $ordered.Count
    invalid_or_blank_count = $invalidCount
    sum = if ($ordered.Count) { [math]::Round(($ordered | Measure-Object -Sum).Sum, 4) } else { $null }
    average = if ($ordered.Count) { [math]::Round(($ordered | Measure-Object -Average).Average, 4) } else { $null }
    min = if ($ordered.Count) { $ordered[0] } else { $null }
    max = if ($ordered.Count) { $ordered[$ordered.Count - 1] } else { $null }
  }
}

$groupSummary = @()
if ($GroupBy.Count -gt 0 -and $rows.Count -gt 0) {
  $groupSummary = @($rows | Group-Object -Property $GroupBy | Sort-Object Count -Descending | Select-Object -First $TopAnomalyCount | ForEach-Object {
    [PSCustomObject]@{
      group = $_.Name
      row_count = $_.Count
    }
  })
}

$result = [PSCustomObject]@{
  schema_version = 1
  aggregation_formula_version = $FormulaVersion
  raw_input_path = $InputPath
  rerun_command = "powershell -NoProfile -ExecutionPolicy Bypass -File .qianlima/scripts/summarize-csv.ps1 -InputPath <csv>"
  row_count = $rows.Count
  headers = [object[]]$headers
  missing_numeric_columns = [object[]]$missingNumeric
  missing_group_columns = [object[]]$missingGroups
  numeric_summary = [object[]]$numericSummary
  top_groups = [object[]]$groupSummary
}

$serialized = $result | ConvertTo-Json -Depth 7
if ($OutputPath) { $serialized | Set-Content -LiteralPath $OutputPath -Encoding UTF8 }
if ($Json -or -not $OutputPath) { $serialized }
