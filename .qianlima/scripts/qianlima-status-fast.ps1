param(
  [switch]$AsJson,
  [string[]]$RelevantPath = @()
)

$ErrorActionPreference = 'Stop'
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$qianlimaRoot = Join-Path $projectRoot '.qianlima'
$cachePath = Join-Path $qianlimaRoot 'startup-cache.json'
$artifacts = @(
  '.qianlima\CODEX_BOOT.md',
  '.qianlima\codex-router.json',
  '.qianlima\WORKSPACE_INDEX.md'
)

$cache = $null
$cacheReadable = $false
if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
  try {
    $cache = Get-Content -LiteralPath $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $cacheReadable = $true
  } catch {
    $cacheReadable = $false
  }
}

$artifactStatus = @($artifacts | ForEach-Object {
  [PSCustomObject]@{
    path = $_
    exists = Test-Path -LiteralPath (Join-Path $projectRoot $_) -PathType Leaf
  }
})
$artifactsReady = @($artifactStatus | Where-Object { -not $_.exists }).Count -eq 0
$schemaValid = $cacheReadable -and $cache.schema_version -eq 2
$normalizedRelevantPaths = @($RelevantPath | ForEach-Object { $_ -split '[,;]' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$freshnessSources = @(
  'AGENTS.md',
  '.qianlima\CODEX_BOOT.md',
  '.qianlima\natural-language-router.yaml',
  '.qianlima\agent-runtime-policy.yaml',
  '.qianlima\latency-policy.yaml',
  '.qianlima\session-lease-policy.yaml',
  'start-qianlima.ps1'
) + $normalizedRelevantPaths
$invalidRelevantPaths = @($normalizedRelevantPaths | Where-Object {
  $resolved = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $_))
  -not $resolved.StartsWith($projectRoot, [System.StringComparison]::OrdinalIgnoreCase)
})
if ($invalidRelevantPaths.Count -gt 0) {
  throw 'RelevantPath must stay inside the Qianlima project workspace.'
}
$missingRelevantPaths = @($normalizedRelevantPaths | Where-Object {
  -not (Test-Path -LiteralPath (Join-Path $projectRoot $_) -PathType Leaf)
})
$cacheGeneratedAt = if ($cacheReadable -and $cache.generated_at) { [datetime]$cache.generated_at } else { [datetime]::MinValue }
$staleSources = @($freshnessSources | Where-Object {
  $path = Join-Path $projectRoot $_
  (Test-Path -LiteralPath $path -PathType Leaf) -and (Get-Item -LiteralPath $path).LastWriteTimeUtc -gt $cacheGeneratedAt.ToUniversalTime()
})
$ready = $schemaValid -and $artifactsReady -and $staleSources.Count -eq 0 -and $missingRelevantPaths.Count -eq 0

$stopwatch.Stop()
$status = [PSCustomObject]@{
  status = if ($ready) { 'ready' } else { 'needs_startup' }
  cache_schema_valid = $schemaValid
  cache_generated_at = if ($cacheReadable) { $cache.generated_at } else { $null }
  artifacts = $artifactStatus
  stale_sources = $staleSources
  relevant_paths_checked = $normalizedRelevantPaths
  missing_relevant_paths = $missingRelevantPaths
  full_startup_required = -not $ready
  high_risk_requires_force_startup = $true
  elapsed_ms = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 1)
  note = 'Readiness only. start-qianlima.ps1 remains the source-of-truth for detecting source changes.'
}

if ($AsJson) {
  $status | ConvertTo-Json -Depth 4
} else {
  Write-Host "Qianlima fast status: $($status.status) ($($status.elapsed_ms) ms)"
  Write-Host "Cache generated: $($status.cache_generated_at)"
  Write-Host "Full startup required: $($status.full_startup_required)"
  Write-Host 'High-risk task: always run start-qianlima.ps1 -Force.'
}
