<#
.SYNOPSIS
  Load a cached Qianlima memory card and report its freshness.
.DESCRIPTION
  Compatibility shell for the governed Memory Broker. A task-bound RequestPath
  and GrantPath are mandatory; direct memory reads are no longer supported.
.PARAMETER EntityType
  Card category: asin, sku, campaign, or keyword.
.PARAMETER EntityId
  File-safe identifier of the card to load.
.PARAMETER AsJson
  Emit the broker result as JSON.
.EXAMPLE
  .\get-qianlima-memory-card.ps1 -EntityType asin -EntityId B0ABC12345 -RequestPath .qianlima\run-traces\memory-read-tests\request.json -GrantPath .qianlima\run-traces\delegation-grants\grant.json -AsJson
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('asin', 'sku', 'campaign', 'keyword')]
  [string]$EntityType,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$')]
  [string]$EntityId,
  [Parameter(Mandatory = $true)]
  [string]$RequestPath,
  [Parameter(Mandatory = $true)]
  [string]$GrantPath,
  [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cardPath = Join-Path $projectRoot "memory\cards\$EntityType\$EntityId.json"
if (-not (Test-Path -LiteralPath $cardPath -PathType Leaf)) {
  throw "Memory card not found: $cardPath"
}
$brokerScript = Join-Path $PSScriptRoot 'invoke-memory-broker.ps1'
$brokerOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $brokerScript -RequestPath $RequestPath -GrantPath $GrantPath -MemoryPath $cardPath -PassThru 2>&1)
$brokerCode = $LASTEXITCODE
$brokerText = ($brokerOutput -join "`n")
$jsonStart = $brokerText.IndexOf('{'); $jsonEnd = $brokerText.LastIndexOf('}')
$result = $null
if ($jsonStart -ge 0 -and $jsonEnd -gt $jsonStart) { try { $result = $brokerText.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json } catch { } }
if ($brokerCode -ne 0 -or $null -eq $result -or $result.status -ne 'allowed') { throw 'Memory Broker denied the card read.' }
if ($AsJson) { $result | ConvertTo-Json -Depth 8 }
else {
  Write-Host "Memory Broker allowed: $($result.memory_pack.memory_id) ($($result.state_view))"
  Write-Host "Source reload required: $($result.source_reload_required)"
}
