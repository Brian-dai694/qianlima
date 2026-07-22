<##
.SYNOPSIS
  Installs mandatory Qianlima Enterprise prerequisites on Windows.
.DESCRIPTION
  This is an explicit administrator action. It never installs provider keys,
  enables Agent execution, changes Broker policy, or migrates business data.
##>
param(
  [switch]$Install,
  [switch]$AcceptDockerDesktopLicense
)

$ErrorActionPreference = 'Stop'
$enterpriseRoot = $PSScriptRoot
$preflight = Join-Path $enterpriseRoot 'test-enterprise-environment.ps1'
if (-not $Install) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $preflight -PassThru
  exit $LASTEXITCODE
}
if (-not $AcceptDockerDesktopLicense) { throw 'Docker Desktop license acceptance is required before managed installation.' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Administrator elevation is required. Reopen PowerShell as Administrator and rerun this command.'
}
if ($env:OS -ne 'Windows_NT') { throw 'This installer is for Windows only.' }
if ($null -eq (Get-Command winget.exe -ErrorAction SilentlyContinue)) { throw 'winget is required for the managed Windows deployment.' }

function Enable-RequiredFeature([string]$FeatureName) {
  $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName
  if ($feature.State -ne 'Enabled') {
    Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart | Out-Null
  }
}
function Install-WingetPackage([string]$PackageId) {
  & winget.exe install --exact --id $PackageId --accept-package-agreements --accept-source-agreements --disable-interactivity
  if ($LASTEXITCODE -ne 0) { throw "Managed package installation failed: $PackageId" }
}

Enable-RequiredFeature 'Microsoft-Windows-Subsystem-Linux'
Enable-RequiredFeature 'VirtualMachinePlatform'
Install-WingetPackage 'Microsoft.PowerShell'
Install-WingetPackage 'Docker.DockerDesktop'

$dockerCli = Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin\docker.exe'
$dockerDesktop = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
if (-not (Test-Path -LiteralPath $dockerCli -PathType Leaf)) {
  Write-Host 'Docker was installed but its CLI is not available yet. Reboot Windows, then rerun this command.'
  exit 1
}
if (Test-Path -LiteralPath $dockerDesktop -PathType Leaf) {
  Start-Process -FilePath $dockerDesktop -WindowStyle Hidden
}

$daemonReady = $false
for ($attempt = 0; $attempt -lt 24; $attempt++) {
  & $dockerCli info --format '{{.OSType}}' 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { $daemonReady = $true; break }
  Start-Sleep -Seconds 5
}
if (-not $daemonReady) {
  Write-Host 'Windows virtualization or Docker Desktop requires a reboot or first-run approval. Reboot, then rerun this same command.'
  exit 1
}

& $dockerCli pull 'alpine:3.20'
if ($LASTEXITCODE -ne 0) { throw 'Failed to preload the approved alpine:3.20 Runner image.' }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $preflight -PassThru
if ($LASTEXITCODE -ne 0) { throw 'Managed deployment completed partially; follow the reported remediation and rerun this command.' }
Write-Host 'Qianlima Enterprise managed environment is ready. Agent execution remains disabled until a task-bound Attestation and Grant are issued.'
