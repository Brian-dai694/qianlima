<#
.SYNOPSIS
Writes a per-entity memory card JSON file with an expiry.
.DESCRIPTION
Builds a memory card for an ASIN, SKU, campaign, or keyword and saves it under
memory/cards/<EntityType>/<EntityId>.json. Facts are parsed from key=value
strings, all inputs are scanned for credential-like material and rejected, and
an expires_at timestamp is derived from FreshForHours.
.PARAMETER EntityType
Entity kind: asin, sku, campaign, or keyword (selects the target folder).
.PARAMETER EntityId
File-safe identifier for the entity; becomes the card file name.
.PARAMETER SourceRef
One or more source references backing the card's facts.
.PARAMETER Fact
Zero or more key=value strings stored as structured facts.
.EXAMPLE
.\set-qianlima-memory-card.ps1 -EntityType asin -EntityId B0EXAMPLE -SourceRef report#12 -Fact 'price=19.99'
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('asin', 'sku', 'campaign', 'keyword')]
  [string]$EntityType,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$')]
  [string]$EntityId,

  [Parameter(Mandatory = $true)]
  [string[]]$SourceRef,
  [string[]]$Fact = @(),
  [ValidateSet('high', 'medium', 'low')]
  [string]$Confidence = 'medium',
  [ValidateRange(1, 720)]
  [int]$FreshForHours = 24,
  [string]$Note = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cardDirectory = Join-Path $projectRoot "memory\cards\$EntityType"
$credentialPattern = '(?i)(api[_-]?key|secret|password|cookie|bearer\s+[a-z0-9._-]{12,}|token\s*[:=]\s*[a-z0-9._-]{12,})'

foreach ($value in @($SourceRef) + @($Fact) + @($Note)) {
  if ($value -match $credentialPattern) {
    throw 'Memory cards cannot contain credentials or authentication material.'
  }
}

$facts = @($Fact | ForEach-Object {
  $parts = $_ -split '=', 2
  if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0])) {
    throw "Fact must use key=value format: $_"
  }
  [PSCustomObject]@{ key = $parts[0].Trim(); value = $parts[1].Trim() }
})

if (-not (Test-Path -LiteralPath $cardDirectory -PathType Container)) {
  New-Item -ItemType Directory -Path $cardDirectory -Force | Out-Null
}
$now = (Get-Date).ToUniversalTime()
$card = [PSCustomObject]@{
  schema_version = 1
  entity_type = $EntityType
  entity_id = $EntityId
  source_refs = @($SourceRef)
  facts = $facts
  confidence = $Confidence
  note = $Note
  updated_at = $now.ToString('o')
  expires_at = $now.AddHours($FreshForHours).ToString('o')
}
$cardPath = Join-Path $cardDirectory "$EntityId.json"
[System.IO.File]::WriteAllText($cardPath, ($card | ConvertTo-Json -Depth 6), [System.Text.UTF8Encoding]::new($false))

if ($PassThru) {
  [PSCustomObject]@{ CardPath = $cardPath; Card = $card }
} else {
  Write-Host "Memory card saved: $cardPath"
  Write-Host "Expires: $($card.expires_at)"
}
