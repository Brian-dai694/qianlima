<#
.SYNOPSIS
  Regression tests for role-layered beginner manuals.
.DESCRIPTION
  Keeps UTF-8 document names and patterns in JSON so Windows PowerShell 5.1
  can parse this script without relying on a UTF-8 BOM.
#>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$expectationsPath = Join-Path $root 'manual-regression-expectations.json'
$expectations = Get-Content -LiteralPath $expectationsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$documents = @{}
$cases = [System.Collections.Generic.List[object]]::new()

foreach ($property in $expectations.documents.PSObject.Properties) {
  $path = Join-Path $root ([string]$property.Value)
  $documents[$property.Name] = if (Test-Path -LiteralPath $path -PathType Leaf) {
    Get-Content -LiteralPath $path -Raw -Encoding UTF8
  } else {
    ''
  }
}

foreach ($case in $expectations.cases) {
  $content = [string]$documents[[string]$case.document]
  $passed = -not [string]::IsNullOrWhiteSpace($content)
  foreach ($pattern in @($case.patterns)) {
    if (-not $content.Contains([string]$pattern)) { $passed = $false; break }
  }
  $cases.Add([PSCustomObject]@{ name = [string]$case.name; passed = $passed })
}

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ passed = ($failed.Count -eq 0); cases = @($cases); files_written = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw ('Layered manual regression failed: ' + (($failed.name) -join ', ')) }
