<#
.SYNOPSIS
Save a short-lived operational snapshot as JSON.
.DESCRIPTION
Writes a route-keyed snapshot JSON containing facts, anomalies and source refs to
working/snapshots (or a custom OutputPath). Rejects any value that looks like a
sensitive field (api key, token, cookie, password, account id, email, phone) and
requires the route to be a short file-safe identifier. Records a TTL and quality status.
.PARAMETER Route
Short file-safe identifier used as the snapshot key and file name.
.PARAMETER Fact
One or more fact strings to store in the snapshot.
.PARAMETER TtlSeconds
Time-to-live in seconds, 60-86400 (default 900).
.PARAMETER QualityStatus
Quality gate result, passed or failed (default passed).
.EXAMPLE
.\new-operational-snapshot.ps1 -Route asin-b012 -Fact "bsr rose 12%" -TtlSeconds 1800
#>
param(
  [Parameter(Mandatory)]
  [string]$Route,
  [Parameter(Mandatory)]
  [string[]]$Fact,
  [string[]]$Anomaly = @(),
  [string[]]$SourceRef = @(),
  [ValidateRange(60, 86400)]
  [int]$TtlSeconds = 900,
  [ValidateSet('passed', 'failed')]
  [string]$QualityStatus = 'passed',
  [string]$Root = '',
  [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
if ($Route -match '[\\/:*?"<>|]' -or $Route.Length -gt 80) {
  throw 'Route must be a short file-safe identifier.'
}

$forbidden = '(?i)(api[_-]?key|token|cookie|password|private[_-]?url|account[_-]?id|customer|email|phone)'
foreach ($value in @($Fact + $Anomaly + $SourceRef)) {
  if ($value -match $forbidden) {
    throw 'Snapshot cannot store sensitive fields or values.'
  }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $snapshotDir = Join-Path (Join-Path $Root 'working') 'snapshots'
  if (-not (Test-Path -LiteralPath $snapshotDir -PathType Container)) {
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
  }
  $OutputPath = Join-Path $snapshotDir "snapshot-$Route.json"
}

$snapshot = [PSCustomObject]@{
  schema_version = 1
  generated_at = (Get-Date).ToUniversalTime().ToString('o')
  ttl_seconds = $TtlSeconds
  route = $Route
  quality_status = $QualityStatus
  evidence_grade = 'B'
  facts = [object[]]$Fact
  anomalies = [object[]]$Anomaly
  source_refs = [object[]]$SourceRef
}
$snapshot | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Operational snapshot saved: $OutputPath"
