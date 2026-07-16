param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$SnapshotId,
  [Parameter(Mandatory = $true)] [switch]$Confirmed,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if (-not $Confirmed) { throw 'Restoring governance files requires explicit confirmation.' }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$snapshotRoot = Join-Path $projectRoot ".qianlima\snapshots\$SnapshotId"
$manifestPath = Join-Path $snapshotRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Snapshot not found: $SnapshotId" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$projectPrefix = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$snapshotPrefix = [IO.Path]::GetFullPath($snapshotRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ($manifest.schema_version -ne 1 -or $null -eq $manifest.files) { throw 'Invalid governance snapshot manifest.' }
foreach ($entry in @($manifest.files)) {
  if ([string]::IsNullOrWhiteSpace($entry.path) -or [IO.Path]::IsPathRooted($entry.path)) { throw "Invalid snapshot path: $($entry.path)" }
  $source = Join-Path $snapshotRoot ($entry.path -replace '/', '\')
  $destination = Join-Path $projectRoot ($entry.path -replace '/', '\')
  $sourceFull = [IO.Path]::GetFullPath($source)
  $destinationFull = [IO.Path]::GetFullPath($destination)
  if (-not $sourceFull.StartsWith($snapshotPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Snapshot source escapes snapshot root: $($entry.path)" }
  if (-not $destinationFull.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Snapshot destination escapes project root: $($entry.path)" }
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Snapshot file missing: $($entry.path)" }
  $actual = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $entry.sha256) { throw "Snapshot checksum mismatch: $($entry.path)" }
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Force
}
$result = [PSCustomObject]@{ restored_snapshot = $SnapshotId; file_count = @($manifest.files).Count; restored_at = (Get-Date).ToUniversalTime().ToString('o') }
if ($PassThru) { $result | ConvertTo-Json -Depth 4 } else { Write-Host "Governance snapshot restored: $SnapshotId" }
