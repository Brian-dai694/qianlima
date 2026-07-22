<##
.SYNOPSIS
  Starts Qianlima using the Enterprise Edition profile.
.DESCRIPTION
  This wrapper enforces the managed environment gate, validates the Enterprise
  profile, and then delegates to the shared start script. It never enables a
  Runner or changes the core Harness.
##>
param(
  [switch]$SkipValidation,
  [switch]$Force,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$enterpriseRoot = $PSScriptRoot
$projectRoot = (Resolve-Path (Join-Path $enterpriseRoot '..')).Path
$profilePath = Join-Path $enterpriseRoot 'edition.yaml'
$coreStart = Join-Path $projectRoot 'start-qianlima.ps1'
$profileTest = Join-Path $enterpriseRoot 'test-enterprise-profile.ps1'
$environmentTest = Join-Path $enterpriseRoot 'test-enterprise-environment.ps1'
if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) { throw 'Enterprise edition profile is missing.' }
if (-not (Test-Path -LiteralPath $coreStart -PathType Leaf)) { throw 'Shared Qianlima start script is missing.' }
if (-not (Test-Path -LiteralPath $environmentTest -PathType Leaf)) { throw 'Enterprise environment gate is missing.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $profileTest
if ($LASTEXITCODE -ne 0) { throw 'Enterprise edition profile validation failed.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $environmentTest
if ($LASTEXITCODE -ne 0) {
  throw "Enterprise managed environment is not ready. Run the administrator deployment entrypoint in '$enterpriseRoot'."
}
$args = @()
if ($SkipValidation) { $args += '-SkipValidation' }
if ($Force) { $args += '-Force' }
if ($Quiet) { $args += '-Quiet' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $coreStart @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not $Quiet) { Write-Host 'Qianlima Enterprise Edition: shared core ready; real execution remains policy-gated.' }
