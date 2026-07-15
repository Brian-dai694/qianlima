<#
.SYNOPSIS
Boots the Qianlima workspace, rebuilding its index and fast router.
.DESCRIPTION
Fingerprints workspace source files and directories and compares them against
startup-cache.json. On a fresh cache hit it exits immediately; otherwise it runs
bootstrap, optional validation, and the fast-router compiler, then rewrites the
cache. Prints the elapsed startup time and the key files each agent should read.
.PARAMETER SkipValidation
Skips the workspace skeleton validation step during a refresh.
.PARAMETER Force
Ignores the startup cache and forces a full rebuild.
.PARAMETER Quiet
Suppresses informational console output.
.EXAMPLE
.\start-qianlima.ps1 -Force
#>
param(
  [switch]$SkipValidation,
  [switch]$Force,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$startupStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$ProjectRoot = $PSScriptRoot
$QianlimaRoot = Join-Path $ProjectRoot '.qianlima'
$BootstrapScript = Join-Path $QianlimaRoot 'scripts/bootstrap-qianlima.ps1'
$ValidateScript = Join-Path $QianlimaRoot 'scripts/validate-qianlima.ps1'
$CompileRouterScript = Join-Path $QianlimaRoot 'scripts/compile-fast-router.ps1'
$CachePath = Join-Path $QianlimaRoot 'startup-cache.json'
$IndexPath = Join-Path $QianlimaRoot 'WORKSPACE_INDEX.md'
$MachineIndexPath = Join-Path $QianlimaRoot 'workspace-index.json'
$RouterIndexPath = Join-Path $QianlimaRoot 'codex-router.json'

function Get-QianlimaStartupSourceState {
  $excludedDirectories = @(
    'archive',
    'context-summaries',
    'evaluations',
    'exports',
    'feedback',
    'inbox',
    'local-data',
    'logs',
    'run-traces',
    'usage-ledger',
    'working'
  )
  $generatedFiles = @(
    'WORKSPACE_INDEX.md',
    'workspace-index.json',
    'startup-cache.json',
    'codex-router.json'
  )
  $sourceExtensions = @('.md', '.ps1', '.ws', '.yaml', '.yml', '.csv')
  $files = New-Object System.Collections.Generic.List[System.IO.FileInfo]
  $directories = New-Object System.Collections.Generic.List[System.IO.DirectoryInfo]

  foreach ($file in @(
    (Join-Path $ProjectRoot 'README.md'),
    (Join-Path $ProjectRoot 'AGENTS.md'),
    (Join-Path $ProjectRoot 'AI_START_HERE.md'),
    $PSCommandPath
  )) {
    if (Test-Path -LiteralPath $file -PathType Leaf) {
      $files.Add((Get-Item -LiteralPath $file))
    }
  }

  $directories.Add((Get-Item -LiteralPath $QianlimaRoot -Force))
  Get-ChildItem -LiteralPath $QianlimaRoot -Recurse -Force | ForEach-Object {
    $relativePath = $_.FullName.Substring($QianlimaRoot.Length).TrimStart('\', '/')
    $pathParts = $relativePath -split '[\\/]'
    if ($pathParts | Where-Object { $_ -in $excludedDirectories }) {
      return
    }
    # Candidate drafts are shadow-only and must not invalidate the production startup cache.
    if (($relativePath -replace '\\', '/') -match '^evolution/candidates(?:/|$)') {
      return
    }
    if ($_.PSIsContainer) {
      $directories.Add($_)
      return
    }
    if ($relativePath -in $generatedFiles) {
      return
    }
    if ($_.Extension -in $sourceExtensions) {
      $files.Add($_)
    }
  }

  $fileManifest = @($files | Sort-Object FullName -Unique | ForEach-Object {
    $relativePath = $_.FullName.Substring($ProjectRoot.Length).TrimStart('\', '/')
    [PSCustomObject]@{
      path = $relativePath
      length = $_.Length
      last_write_ticks = $_.LastWriteTimeUtc.Ticks
    }
  })
  function Get-ManagedChildrenFingerprint([string]$DirectoryPath) {
    $names = @(Get-ChildItem -LiteralPath $DirectoryPath -Force | Where-Object {
      $relativePath = $_.FullName.Substring($QianlimaRoot.Length).TrimStart('\', '/')
      $pathParts = $relativePath -split '[\\/]'
      if ($pathParts | Where-Object { $_ -in $excludedDirectories }) { return $false }
      if (($relativePath -replace '\\', '/') -match '^evolution/candidates(?:/|$)') { return $false }
      if (-not $_.PSIsContainer -and $relativePath -in $generatedFiles) { return $false }
      return $true
    } | Sort-Object Name | ForEach-Object {
      if ($_.PSIsContainer) { "D:$($_.Name)" } else { "F:$($_.Name)" }
    })
    $payload = [Text.Encoding]::UTF8.GetBytes(($names -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
      return ([BitConverter]::ToString($sha.ComputeHash($payload))).Replace('-', '').ToLowerInvariant()
    } finally {
      $sha.Dispose()
    }
  }

  $directoryManifest = @($directories | Sort-Object FullName -Unique | ForEach-Object {
    $relativePath = $_.FullName.Substring($ProjectRoot.Length).TrimStart('\', '/')
    [PSCustomObject]@{
      path = if ([string]::IsNullOrWhiteSpace($relativePath)) { '.' } else { $relativePath }
      children_fingerprint = Get-ManagedChildrenFingerprint $_.FullName
    }
  })
  $entries = $fileManifest | ForEach-Object {
    "$($_.path)|$($_.length)|$($_.last_write_ticks)"
  }
  $payload = [Text.Encoding]::UTF8.GetBytes(($entries -join "`n"))
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return [PSCustomObject]@{
      fingerprint = ([BitConverter]::ToString($sha256.ComputeHash($payload))).Replace('-', '').ToLowerInvariant()
      source_manifest = $fileManifest
      directory_manifest = $directoryManifest
    }
  } finally {
    $sha256.Dispose()
  }
}

function Test-QianlimaStartupCache([object]$Cache) {
  if (-not $Cache -or $Cache.schema_version -ne 2 -or -not $Cache.source_manifest -or -not $Cache.directory_manifest) {
    return $false
  }
  foreach ($entry in @($Cache.source_manifest)) {
    $path = Join-Path $ProjectRoot $entry.path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    $item = Get-Item -LiteralPath $path
    if ($item.Length -ne [int64]$entry.length -or $item.LastWriteTimeUtc.Ticks -ne [int64]$entry.last_write_ticks) { return $false }
  }
  foreach ($entry in @($Cache.directory_manifest)) {
    $path = if ($entry.path -eq '.') { $ProjectRoot } else { Join-Path $ProjectRoot $entry.path }
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { return $false }
    $names = @(Get-ChildItem -LiteralPath $path -Force | Where-Object {
      $relativePath = $_.FullName.Substring($QianlimaRoot.Length).TrimStart('\', '/')
      $pathParts = $relativePath -split '[\\/]'
      if ($pathParts | Where-Object { $_ -in @('archive', 'context-summaries', 'evaluations', 'exports', 'feedback', 'inbox', 'local-data', 'logs', 'run-traces', 'usage-ledger', 'working') }) { return $false }
      if (($relativePath -replace '\\', '/') -match '^evolution/candidates(?:/|$)') { return $false }
      if (-not $_.PSIsContainer -and $relativePath -in @('WORKSPACE_INDEX.md', 'workspace-index.json', 'startup-cache.json', 'codex-router.json')) { return $false }
      return $true
    } | Sort-Object Name | ForEach-Object {
      if ($_.PSIsContainer) { "D:$($_.Name)" } else { "F:$($_.Name)" }
    })
    $payload = [Text.Encoding]::UTF8.GetBytes(($names -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
      $currentFingerprint = ([BitConverter]::ToString($sha.ComputeHash($payload))).Replace('-', '').ToLowerInvariant()
    } finally {
      $sha.Dispose()
    }
    if ($currentFingerprint -ne $entry.children_fingerprint) { return $false }
  }
  return $true
}

function Invoke-QianlimaScript {
  param([string]$Path)

  $global:LASTEXITCODE = 0
  & $Path
  if ($LASTEXITCODE -ne 0) {
    throw "Qianlima script failed with exit code ${LASTEXITCODE}: $Path"
  }
}

if (-not (Test-Path -LiteralPath $BootstrapScript -PathType Leaf)) {
  throw "Missing bootstrap script: $BootstrapScript"
}

$cache = $null
if (Test-Path -LiteralPath $CachePath -PathType Leaf) {
  try {
    $cache = Get-Content -LiteralPath $CachePath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    $cache = $null
  }
}

$isCacheFresh = -not $Force -and
  (Test-QianlimaStartupCache $cache) -and
  (Test-Path -LiteralPath $IndexPath -PathType Leaf) -and
  (Test-Path -LiteralPath $MachineIndexPath -PathType Leaf) -and
  (Test-Path -LiteralPath $RouterIndexPath -PathType Leaf)

if ($isCacheFresh) {
  $startupStopwatch.Stop()
  if (-not $Quiet) {
    Write-Host 'Qianlima startup: cache hit. Reusing validated index and fast router.'
    Write-Host "Startup mode: cached (generated $($cache.generated_at))"
    Write-Host "Startup elapsed: $([math]::Round($startupStopwatch.Elapsed.TotalMilliseconds, 1)) ms"
    Write-Host 'For direct low-risk routing, read .qianlima/codex-router.json and the short boot file.'
  }
  exit 0
}

$sourceState = Get-QianlimaStartupSourceState

if (-not $Quiet) {
  Write-Host 'Qianlima startup: rebuilding index and fast router...'
}
Invoke-QianlimaScript $BootstrapScript

if (-not $SkipValidation) {
  if (-not (Test-Path -LiteralPath $ValidateScript -PathType Leaf)) {
    throw "Missing validation script: $ValidateScript"
  }

  if (-not $Quiet) {
    Write-Host 'Qianlima startup: validating workspace skeleton...'
  }
  Invoke-QianlimaScript $ValidateScript
}

if (-not (Test-Path -LiteralPath $CompileRouterScript -PathType Leaf)) {
  throw "Missing fast router compiler: $CompileRouterScript"
}
Invoke-QianlimaScript $CompileRouterScript

[PSCustomObject]@{
  schema_version = 2
  fingerprint = $sourceState.fingerprint
  source_manifest = $sourceState.source_manifest
  directory_manifest = $sourceState.directory_manifest
  generated_at = (Get-Date).ToString('o')
  validation_skipped = [bool]$SkipValidation
  workspace_index = '.qianlima/WORKSPACE_INDEX.md'
  fast_router = '.qianlima/codex-router.json'
} | ConvertTo-Json | Set-Content -LiteralPath $CachePath -Encoding UTF8

if (-not $Quiet) {
  $startupStopwatch.Stop()
  Write-Host ''
  Write-Host 'Qianlima startup complete (mode: refreshed).'
  Write-Host "Startup elapsed: $([math]::Round($startupStopwatch.Elapsed.TotalMilliseconds, 1)) ms"
  Write-Host 'Read for Claude Code: CLAUDE.md'
  Write-Host 'Read for Manus: MANUS.md'
  Write-Host 'Read for Manus boot: .qianlima/MANUS_BOOT.md'
  Write-Host 'Read for desktop agents: DESKTOP_AGENT_BRIEF.md'
  Write-Host 'Read for evaluation layer: .qianlima/qianlima-eval.yaml'
  Write-Host 'Read first: .qianlima/CODEX_BOOT.md'
  Write-Host 'Fast route index: .qianlima/codex-router.json'
  Write-Host 'Full workspace index: .qianlima/WORKSPACE_INDEX.md'
}
