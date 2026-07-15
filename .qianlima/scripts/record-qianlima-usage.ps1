<#
.SYNOPSIS
    Appends a single run's usage metrics as one JSON line to the ledger.
.DESCRIPTION
    Builds a usage record (tokens, tool calls, latency breakdowns, cost, and
    outcome) for a workflow run and appends it as one compact JSON object to
    .qianlima/usage-ledger/runs.jsonl. Generates a run id when none is given
    and creates the ledger directory if needed. Append-only for safe incremental use.
.PARAMETER WorkflowId
    Lowercase workflow identifier (validated pattern); required.
.PARAMETER RunId
    Run identifier; auto-generated from the workflow id and timestamp if empty.
.PARAMETER Status
    Run outcome: completed, partial, failed, or cancelled.
.PARAMETER PassThru
    Return the ledger path, run id, and record object instead of host messages.
.EXAMPLE
    ./record-qianlima-usage.ps1 -WorkflowId keyword_diagnosis -InputTokens 1200 -OutputTokens 340 -ToolCalls 3
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9][a-z0-9_-]*$')]
  [string]$WorkflowId,

  [string]$RunId = '',
  [string]$Provider = 'local',
  [string]$Model = 'local-script',
  [ValidateRange(0, [double]::MaxValue)]
  [double]$InputTokens = 0,
  [ValidateRange(0, [double]::MaxValue)]
  [double]$OutputTokens = 0,
  [ValidateRange(0, [double]::MaxValue)]
  [double]$CacheHitTokens = 0,
  [ValidateRange(0, [int]::MaxValue)]
  [int]$ToolCalls = 0,
  [ValidateRange(0, [int]::MaxValue)]
  [int]$RowsRead = 0,
  [ValidateRange(0, [double]::MaxValue)]
  [double]$DurationSeconds = 0,
  [ValidateRange(0, [double]::MaxValue)]
  [double]$StartupMs = 0,
  [ValidateRange(0, [double]::MaxValue)]
  [double]$RoutingMs = 0,
  [ValidateRange(0, [double]::MaxValue)]
  [double]$ContextLoadMs = 0,
  [ValidateRange(0, [double]::MaxValue)]
  [double]$ToolMs = 0,
  [ValidateRange(0, [double]::MaxValue)]
  [double]$ModelMs = 0,
  [ValidateRange(0, [double]::MaxValue)]
  [double]$FirstUsefulOutputMs = 0,
  [ValidateRange(0, [double]::MaxValue)]
  [double]$EstimatedCostUsd = 0,
  [ValidateRange(0, [int]::MaxValue)]
  [int]$OutcomeUnits = 0,
  [string]$OutcomeUnit = '',
  [ValidateSet('completed', 'partial', 'failed', 'cancelled')]
  [string]$Status = 'completed',
  [string]$Notes = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ledgerDirectory = Join-Path $projectRoot '.qianlima\usage-ledger'
$ledgerPath = Join-Path $ledgerDirectory 'runs.jsonl'

if ([string]::IsNullOrWhiteSpace($RunId)) {
  $RunId = "$WorkflowId-$((Get-Date).ToString('yyyyMMdd-HHmmss-fff'))"
}

if (-not (Test-Path -LiteralPath $ledgerDirectory -PathType Container)) {
  New-Item -ItemType Directory -Path $ledgerDirectory -Force | Out-Null
}

$record = [ordered]@{
  schema_version = 1
  run_id = $RunId
  workflow_id = $WorkflowId
  provider = $Provider
  model = $Model
  input_tokens = $InputTokens
  output_tokens = $OutputTokens
  cache_hit_tokens = $CacheHitTokens
  tool_calls = $ToolCalls
  rows_read = $RowsRead
  duration_seconds = $DurationSeconds
  startup_ms = $StartupMs
  routing_ms = $RoutingMs
  context_load_ms = $ContextLoadMs
  tool_ms = $ToolMs
  model_ms = $ModelMs
  first_useful_output_ms = $FirstUsefulOutputMs
  estimated_cost_usd = $EstimatedCostUsd
  outcome_units = $OutcomeUnits
  outcome_unit = $OutcomeUnit
  status = $Status
  notes = $Notes
  recorded_at = (Get-Date).ToUniversalTime().ToString('o')
}

# One JSON object per line makes the ledger append-only and safe to process incrementally.
$json = $record | ConvertTo-Json -Compress -Depth 4
[System.IO.File]::AppendAllText($ledgerPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

if ($PassThru) {
  [PSCustomObject]@{
    LedgerPath = $ledgerPath
    RunId = $RunId
    Record = [PSCustomObject]$record
  }
} else {
  Write-Host "Usage ledger appended: $ledgerPath"
  Write-Host "Run ID: $RunId"
}
