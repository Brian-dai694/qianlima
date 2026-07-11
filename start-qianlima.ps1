param(
  [switch]$SkipValidation,
  [switch]$Force,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$QianlimaRoot = Join-Path $ProjectRoot '.qianlima'
$BootstrapScript = Join-Path $QianlimaRoot 'scripts/bootstrap-qianlima.ps1'
$ValidateScript = Join-Path $QianlimaRoot 'scripts/validate-qianlima.ps1'
$CompileRouterScript = Join-Path $QianlimaRoot 'scripts/compile-fast-router.ps1'
$CachePath = Join-Path $QianlimaRoot 'startup-cache.json'
$IndexPath = Join-Path $QianlimaRoot 'WORKSPACE_INDEX.md'
$MachineIndexPath = Join-Path $QianlimaRoot 'workspace-index.json'
$RouterIndexPath = Join-Path $QianlimaRoot 'codex-router.json'

function Get-QianlimaStartupFingerprint {
  $excludedDirectories = @(
    'archive', 'context-summaries', 'evaluations', 'exports', 'feedback',
    'inbox', 'local-data', 'logs', 'run-traces', 'usage-ledger', 'working'
  )
  $generatedFiles = @(
    'WORKSPACE_INDEX.md', 'workspace-index.json',
    'startup-cache.json', 'codex-router.json'
  )
  $sourceExtensions = @('.md', '.ps1', '.ws', '.yaml', '.yml', '.csv')
  $files = New-Object System.Collections.Generic.List[System.IO.FileInfo]

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

  Get-ChildItem -LiteralPath $QianlimaRoot -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($QianlimaRoot.Length).TrimStart('\', '/')
    $pathParts = $relativePath -split '[\\/]'
    if ($pathParts | Where-Object { $_ -in $excludedDirectories }) { return }
    if ($relativePath -in $generatedFiles) { return }
    if ($_.Extension -in $sourceExtensions) { $files.Add($_) }
  }

  $entries = $files | Sort-Object FullName -Unique | ForEach-Object {
    $relativePath = $_.FullName.Substring($ProjectRoot.Length).TrimStart('\', '/')
    "$relativePath|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)"
  }
  $payload = [Text.Encoding]::UTF8.GetBytes(($entries -join [Environment]::NewLine))
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha256.ComputeHash($payload))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha256.Dispose()
  }
}

if (-not (Test-Path -LiteralPath $BootstrapScript -PathType Leaf)) {
  throw "Missing bootstrap script: $BootstrapScript"
}

function Invoke-QianlimaScript([string]$Path) {
  $global:LASTEXITCODE = 0
  & $Path
  if ($LASTEXITCODE -ne 0) {
    throw "Qianlima script failed with exit code ${LASTEXITCODE}: $Path"
  }
}

$fingerprint = Get-QianlimaStartupFingerprint
$cache = $null
if (Test-Path -LiteralPath $CachePath -PathType Leaf) {
  try {
    $cache = Get-Content -LiteralPath $CachePath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    $cache = $null
  }
}

$isCacheFresh = -not $Force -and
  $cache -and
  $cache.schema_version -eq 1 -and
  $cache.fingerprint -eq $fingerprint -and
  (Test-Path -LiteralPath $IndexPath -PathType Leaf) -and
  (Test-Path -LiteralPath $MachineIndexPath -PathType Leaf) -and
  (Test-Path -LiteralPath $RouterIndexPath -PathType Leaf)

if ($isCacheFresh) {
  if (-not $Quiet) {
    Write-Host 'Qianlima startup: cache hit. Reusing validated index and fast router.'
    Write-Host "Startup mode: cached (generated $($cache.generated_at))"
    Write-Host 'For direct low-risk routing, read .qianlima/codex-router.json and the short boot file.'
  }
  exit 0
}

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
  schema_version = 1
  fingerprint = $fingerprint
  generated_at = (Get-Date).ToString('o')
  validation_skipped = [bool]$SkipValidation
  workspace_index = '.qianlima/WORKSPACE_INDEX.md'
  fast_router = '.qianlima/codex-router.json'
} | ConvertTo-Json | Set-Content -LiteralPath $CachePath -Encoding UTF8

if (-not $Quiet) {
  Write-Host ''
  Write-Host 'Qianlima startup complete (mode: refreshed).'
  Write-Host 'Read core: .qianlima/CODEX_BOOT.md, .qianlima/codex-router.json, .qianlima/risk-rules.yaml'
  Write-Host 'Then select one task-card and load only its workflow, template, data, and deferred governance.'
  Write-Host 'Platform adapters and evaluation config are optional; load them only when the selected task needs them.'
  Write-Host 'Full machine index: .qianlima/workspace-index.json'
}
