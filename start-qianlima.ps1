param(
  [switch]$SkipValidation
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$QianlimaRoot = Join-Path $ProjectRoot '.qianlima'
$BootstrapScript = Join-Path $QianlimaRoot 'scripts/bootstrap-qianlima.ps1'
$ValidateScript = Join-Path $QianlimaRoot 'scripts/validate-qianlima.ps1'

if (-not (Test-Path -LiteralPath $BootstrapScript -PathType Leaf)) {
  throw "Missing bootstrap script: $BootstrapScript"
}

Write-Host 'Qianlima startup: generating workspace index...'
& powershell -NoProfile -ExecutionPolicy Bypass -File $BootstrapScript

if (-not $SkipValidation) {
  if (-not (Test-Path -LiteralPath $ValidateScript -PathType Leaf)) {
    throw "Missing validation script: $ValidateScript"
  }

  Write-Host 'Qianlima startup: validating workspace skeleton...'
  & powershell -NoProfile -ExecutionPolicy Bypass -File $ValidateScript
}

Write-Host ''
Write-Host 'Qianlima startup complete.'
Write-Host 'Read first: .qianlima/WORKSPACE_INDEX.md'
Write-Host 'Machine index: .qianlima/workspace-index.json'
