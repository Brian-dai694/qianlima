<#
.SYNOPSIS
  Load a cached Qianlima memory card and report its freshness.
.DESCRIPTION
  Resolves memory\cards\<EntityType>\<EntityId>.json under the project root and reads it
  as JSON. Compares the card's expires_at against current UTC time to mark it fresh or
  stale and to flag whether a source reload is required. Throws if the card file is missing.
.PARAMETER EntityType
  Card category: asin, sku, campaign, or keyword.
.PARAMETER EntityId
  File-safe identifier of the card to load.
.PARAMETER AsJson
  Emit the full result including the card as JSON.
.EXAMPLE
  .\get-qianlima-memory-card.ps1 -EntityType asin -EntityId B0ABC12345 -AsJson
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('asin', 'sku', 'campaign', 'keyword')]
  [string]$EntityType,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$')]
  [string]$EntityId,
  [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cardPath = Join-Path $projectRoot "memory\cards\$EntityType\$EntityId.json"
if (-not (Test-Path -LiteralPath $cardPath -PathType Leaf)) {
  throw "Memory card not found: $cardPath"
}
$card = Get-Content -LiteralPath $cardPath -Raw -Encoding UTF8 | ConvertFrom-Json
$isFresh = ([datetime]$card.expires_at).ToUniversalTime() -gt (Get-Date).ToUniversalTime()
$result = [PSCustomObject]@{
  card_path = $cardPath
  freshness = if ($isFresh) { 'fresh' } else { 'stale' }
  reload_source_required = -not $isFresh
  card = $card
}
if ($AsJson) { $result | ConvertTo-Json -Depth 8 }
else {
  Write-Host "Memory card: $($card.entity_type)/$($card.entity_id) ($($result.freshness))"
  Write-Host "Source reload required: $($result.reload_source_required)"
}
