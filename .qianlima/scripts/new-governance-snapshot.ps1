param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$SnapshotId,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$snapshotRoot = Join-Path $projectRoot ".qianlima\snapshots\$SnapshotId"
$sources = @('AGENTS.md', '.qianlima/CODEX_BOOT.md', '.qianlima/risk-rules.yaml', '.qianlima/agent-runtime-policy.yaml', '.qianlima/protected-invariants.yaml', '.qianlima/scripts/check-command-safety.ps1', 'start-qianlima.ps1')
if (Test-Path -LiteralPath $snapshotRoot) { throw "Snapshot already exists: $SnapshotId" }
New-Item -ItemType Directory -Path $snapshotRoot -Force | Out-Null
$manifest = @()
foreach ($relative in $sources) {
  $source = Join-Path $projectRoot ($relative -replace '/', '\')
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
  $destination = Join-Path $snapshotRoot ($relative -replace '/', '\')
  $destinationFull = [IO.Path]::GetFullPath($destination)
  $snapshotPrefix = [IO.Path]::GetFullPath($snapshotRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $destinationFull.StartsWith($snapshotPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Invalid snapshot destination: $relative" }
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Force
  $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
  $manifest += [PSCustomObject]@{ path = $relative; sha256 = $hash }
}
$metadata = [PSCustomObject]@{ schema_version = 1; snapshot_id = $SnapshotId; created_at = (Get-Date).ToUniversalTime().ToString('o'); files = @($manifest) }
$metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $snapshotRoot 'manifest.json') -Encoding UTF8
if ($PassThru) { $metadata | ConvertTo-Json -Depth 6 } else { Write-Host "Governance snapshot created: $snapshotRoot" }
