<#
.SYNOPSIS
    Creates a YAML usage-ledger record for a single run.
.DESCRIPTION
    Writes a per-run usage/cost ledger file under usage-ledger. Validates that
    token and cost inputs are non-negative, optionally prices the run from the
    model cost catalog (-AutoPrice), and computes savings and savings rate from
    the baseline. Flags cost_status as over_limit or over_baseline_guard and
    may switch continue_or_stop to needs_confirmation.
.PARAMETER RunId
    Run identifier; sanitized to form the YAML file name.
.PARAMETER AutoPrice
    Price the run from get-model-cost.ps1 instead of using manual estimates.
.PARAMETER CostLimit
    Cost ceiling; exceeding it marks the run over_limit.
.PARAMETER Force
    Overwrite an existing ledger file for the same run id.
.EXAMPLE
    ./new-usage-record.ps1 -RunId 2026-07-13_run_001 -ModelProvider openai -ModelName gpt-x -InputTokens 1000 -OutputTokens 500 -AutoPrice
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$RunId = "$(Get-Date -Format 'yyyy-MM-dd')_manual_001",
  [string]$TaskName = 'replace_me',
  [string]$WorkflowId = 'replace_me',
  [string]$ModelProvider = 'unknown',
  [string]$ModelName = 'unknown',
  [string]$OutputFile = 'replace_me',
  [int]$InputTokens = 0,
  [int]$OutputTokens = 0,
  [int]$CachedInputTokens = 0,
  [int]$ReasoningTokens = 0,
  [decimal]$EstimatedCost = 0,
  [decimal]$BaselineCost = 0,
  [decimal]$EstimatedSavings = 0,
  [decimal]$SavingsRatePct = 0,
  [decimal]$CostLimit = 0,
  [string]$Currency = 'USD',
  [switch]$AutoPrice,
  [string]$CostStatus = 'estimate',
  [string]$SavingsSource = 'unknown',
  [string]$ContinueOrStop = 'continue',
  [switch]$TaskSuccess,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

foreach ($value in @($InputTokens, $OutputTokens, $CachedInputTokens, $ReasoningTokens, $EstimatedCost, $BaselineCost, $CostLimit)) {
  if ($value -lt 0) {
    throw 'Token counts, EstimatedCost, BaselineCost, and CostLimit must be zero or greater.'
  }
}

$pricingCatalogVersion = ''
$pricingSourceUrl = ''
$pricingVerifiedAt = ''
$costMeteringMethod = 'manual_estimate'
if ($AutoPrice) {
  $priceScript = Join-Path $PSScriptRoot 'get-model-cost.ps1'
  $priced = & $priceScript -Provider $ModelProvider -Model $ModelName -InputTokens $InputTokens -OutputTokens $OutputTokens -CachedInputTokens $CachedInputTokens
  if ($priced.status -ne 'priced') {
    throw "No verified price for $ModelProvider/$ModelName. Source: $($priced.source_url)"
  }
  $EstimatedCost = [decimal]$priced.estimated_cost
  $Currency = $priced.currency
  $pricingCatalogVersion = $priced.catalog_version
  $pricingSourceUrl = $priced.source_url
  $pricingVerifiedAt = $priced.verified_at
  $costMeteringMethod = 'official_catalog'
  $CostStatus = 'exact_catalog_rate'
}

$ledgerDir = Join-Path $Root 'usage-ledger'
if (-not (Test-Path -LiteralPath $ledgerDir -PathType Container)) {
  New-Item -ItemType Directory -Path $ledgerDir | Out-Null
}

$safeRunId = $RunId -replace '[^A-Za-z0-9_.-]', '-'
$path = Join-Path $ledgerDir "$safeRunId.yaml"
if ((Test-Path -LiteralPath $path -PathType Leaf) -and (-not $Force)) {
  throw "Usage ledger already exists: $path. Re-run with -Force to overwrite."
}

# InputTokens and OutputTokens are provider totals. Cached and reasoning tokens are
# tracked as diagnostic breakdowns and must not be added again.
$totalTokens = $InputTokens + $OutputTokens
$computedSavings = $EstimatedSavings
if (($computedSavings -eq 0) -and ($BaselineCost -gt 0)) {
  $computedSavings = $BaselineCost - $EstimatedCost
}

$computedSavingsRate = $SavingsRatePct
if (($computedSavingsRate -eq 0) -and ($BaselineCost -gt 0)) {
  $computedSavingsRate = [decimal]::Round(($computedSavings / $BaselineCost) * 100, 2)
}

$computedCostStatus = $CostStatus
$exceedsBaselineGuard = ($BaselineCost -gt 0) -and ($EstimatedCost -gt ($BaselineCost * 2))
if (($CostLimit -gt 0) -and ($EstimatedCost -gt $CostLimit)) {
  $computedCostStatus = 'over_limit'
  if ($ContinueOrStop -eq 'continue') {
    $ContinueOrStop = 'needs_confirmation'
  }
} elseif ($exceedsBaselineGuard) {
  $computedCostStatus = 'over_baseline_guard'
  if ($ContinueOrStop -eq 'continue') {
    $ContinueOrStop = 'needs_confirmation'
  }
}

$date = (Get-Date).ToString('yyyy-MM-dd')
$successValue = if ($TaskSuccess) { 'true' } else { 'false' }

$content = @"
run:
  run_id: $safeRunId
  date: $date
  task_name: $TaskName
  workflow_id: $WorkflowId
  model_provider: $ModelProvider
  model_name: $ModelName

token_usage:
  actual:
    input_tokens: $InputTokens
    output_tokens: $OutputTokens
    cached_input_tokens: $CachedInputTokens
    reasoning_tokens: $ReasoningTokens
    total_tokens: $totalTokens

cost:
  currency: $Currency
  estimated_cost: $EstimatedCost
  baseline_cost: $BaselineCost
  estimated_savings: $computedSavings
  estimated_savings_rate_pct: $computedSavingsRate
  cost_limit: $CostLimit
  cost_status: $computedCostStatus
  savings_source: $SavingsSource
  continue_or_stop: $ContinueOrStop
  note: Replace placeholder values when exact model metering is available.

pricing:
  metering_method: $costMeteringMethod
  catalog_version: $pricingCatalogVersion
  source_url: $pricingSourceUrl
  verified_at: $pricingVerifiedAt

realtime_cost_card:
  visible_to_user: true
  template: .qianlima/templates/realtime-cost-card_template.md
  generator: .qianlima/scripts/new-cost-card.ps1
  currency: $Currency
  current_estimated_cost: $EstimatedCost
  cost_limit: $CostLimit
  baseline_cost: $BaselineCost
  estimated_savings: $computedSavings
  estimated_savings_rate_pct: $computedSavingsRate
  primary_savings_source: $SavingsSource
  continue_or_stop: $ContinueOrStop

context:
  startup_profile: unknown
  files_loaded: []
  compression_used: unknown
  context_policy: .qianlima/context-policy.yaml
  loaded_file_count: 0

result:
  output_file: $OutputFile
  data_sources_used: []
  user_visible_cost_summary: true
  savings_summary_present: true
  task_success: $successValue
  user_edit_required: unknown
  source_citation_present: unknown
  elapsed_seconds: 0
  performance_notes: replace_me
  notes: Generated by new-usage-record.ps1.
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
Write-Host "Usage ledger created: $path"
