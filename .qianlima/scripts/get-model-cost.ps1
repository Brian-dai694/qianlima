<#
.SYNOPSIS
  Compute the cost of a model call from the pricing catalog.
.DESCRIPTION
  Looks up (Provider, Model) in model-pricing.json and computes cost from input,
  output, and cached-input token counts. Validates that token counts are
  non-negative and that cached input does not exceed total input. Throws when the
  catalog is missing or the model is not found. Can emit JSON with -AsJson.
.PARAMETER Provider
  Model provider (e.g. anthropic). Mandatory.
.PARAMETER Model
  Model id (e.g. claude-opus-4-8). Mandatory.
.PARAMETER InputTokens
  Total input tokens (includes any cached input).
.PARAMETER CachedInputTokens
  Portion of input tokens served from cache; must be <= InputTokens.
.PARAMETER CatalogPath
  Path to the pricing catalog. Defaults to ..\model-pricing.json.
.PARAMETER AsJson
  Emit the result as JSON instead of a formatted summary.
.EXAMPLE
  ...get-model-cost.ps1 -Provider anthropic -Model claude-opus-4-8 -InputTokens 9000 -OutputTokens 1500
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Provider,
  [Parameter(Mandatory = $true)]
  [string]$Model,
  [int]$InputTokens = 0,
  [int]$OutputTokens = 0,
  [int]$CachedInputTokens = 0,
  [string]$CatalogPath = '',
  [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
  $CatalogPath = Join-Path $PSScriptRoot '..\model-pricing.json'
}

foreach ($value in @($InputTokens, $OutputTokens, $CachedInputTokens)) {
  if ($value -lt 0) { throw 'Token counts must be zero or greater.' }
}
if ($CachedInputTokens -gt $InputTokens) {
  throw 'CachedInputTokens cannot exceed InputTokens because cached input is part of total input.'
}
if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
  throw "Pricing catalog is missing: $CatalogPath"
}

$catalog = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$entry = @($catalog.models | Where-Object { $_.provider -eq $Provider -and $_.model -eq $Model } | Select-Object -First 1)
if ($entry.Count -eq 0) {
  $source = @($catalog.source_only_providers | Where-Object { $_.provider -eq $Provider } | Select-Object -First 1)
  $result = [PSCustomObject]@{
    status = 'source_only'
    provider = $Provider
    model = $Model
    source_url = if ($source.Count -gt 0) { $source[0].source_url } else { '' }
    message = 'No verified price is available. Refresh the official source before generating an exact cost.'
  }
} else {
  $price = $entry[0].pricing_per_million_tokens
  $uncachedInputTokens = $InputTokens - $CachedInputTokens
  $inputCost = ($uncachedInputTokens / 1000000.0) * [double]$price.input
  $cachedInputCost = ($CachedInputTokens / 1000000.0) * [double]$price.cached_input
  $outputCost = ($OutputTokens / 1000000.0) * [double]$price.output
  $result = [PSCustomObject]@{
    status = 'priced'
    provider = $Provider
    model = $Model
    currency = $entry[0].currency
    catalog_version = $catalog.catalog_version
    verified_at = $entry[0].verified_at
    source_url = $entry[0].source_url
    input_cost = [math]::Round($inputCost, 8)
    cached_input_cost = [math]::Round($cachedInputCost, 8)
    output_cost = [math]::Round($outputCost, 8)
    estimated_cost = [math]::Round(($inputCost + $cachedInputCost + $outputCost), 8)
  }
}

if ($AsJson) { $result | ConvertTo-Json -Depth 4 } else { $result }
