<#
.SYNOPSIS
Computes and stores a median cost baseline for a workflow.
.DESCRIPTION
Reads usage-ledger/runs.jsonl, selects the most recent completed runs for the
given workflow, and computes the median estimated_cost_usd over SampleSize runs.
Throws if fewer than SampleSize completed runs exist. Merges the resulting
baseline into usage-ledger/baselines.json, replacing any prior entry.
.PARAMETER WorkflowId
Lowercase workflow identifier to build the baseline for.
.PARAMETER SampleSize
Number of recent completed runs to use for the median (3 to 100, default 5).
.EXAMPLE
.\set-qianlima-cost-baseline.ps1 -WorkflowId daily_ad_report -SampleSize 7
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9][a-z0-9_-]*$')]
  [string]$WorkflowId,

  [ValidateRange(3, 100)]
  [int]$SampleSize = 5
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ledgerDirectory = Join-Path $projectRoot '.qianlima\usage-ledger'
$ledgerPath = Join-Path $ledgerDirectory 'runs.jsonl'
$baselinePath = Join-Path $ledgerDirectory 'baselines.json'

if (-not (Test-Path -LiteralPath $ledgerPath -PathType Leaf)) {
  throw "Usage ledger not found: $ledgerPath"
}

$runs = Get-Content -LiteralPath $ledgerPath -Encoding UTF8 |
  Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
  ForEach-Object { $_ | ConvertFrom-Json } |
  Where-Object { $_.workflow_id -eq $WorkflowId -and $_.status -eq 'completed' } |
  Sort-Object recorded_at -Descending |
  Select-Object -First $SampleSize

if (@($runs).Count -lt $SampleSize) {
  throw "Baseline needs $SampleSize completed runs for $WorkflowId; found $(@($runs).Count)."
}

$costs = @($runs | ForEach-Object { [double]$_.estimated_cost_usd } | Sort-Object)
$middle = [int][math]::Floor($costs.Count / 2)
$median = if ($costs.Count % 2 -eq 1) { $costs[$middle] } else { ($costs[$middle - 1] + $costs[$middle]) / 2 }

$document = [PSCustomObject]@{ schema_version = 1; workflows = [PSCustomObject]@{} }
if (Test-Path -LiteralPath $baselinePath -PathType Leaf) {
  $document = Get-Content -LiteralPath $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
}
if (-not ($document.PSObject.Properties.Name -contains 'workflows')) {
  $document | Add-Member -MemberType NoteProperty -Name workflows -Value ([PSCustomObject]@{})
}

$baseline = [PSCustomObject]@{
  baseline_cost_usd = [math]::Round($median, 6)
  sample_size = $SampleSize
  method = 'median_completed_run_cost'
  calculated_at = (Get-Date).ToUniversalTime().ToString('o')
}
$existing = $document.workflows.PSObject.Properties[$WorkflowId]
if ($null -eq $existing) {
  $document.workflows | Add-Member -MemberType NoteProperty -Name $WorkflowId -Value $baseline
} else {
  $existing.Value = $baseline
}

$document | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $baselinePath -Encoding UTF8
Write-Host "Baseline saved: $WorkflowId = `$$($median.ToString('0.000000'))"
