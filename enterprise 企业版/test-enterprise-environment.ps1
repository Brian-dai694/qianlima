<##
.SYNOPSIS
  Enforces the Qianlima Enterprise managed environment prerequisite gate.
.DESCRIPTION
  Performs read-only checks. It never installs packages, pulls images, enables
  Windows features, starts a container, or grants Agent execution authority.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$enterpriseRoot = $PSScriptRoot
$projectRoot = (Resolve-Path (Join-Path $enterpriseRoot '..')).Path
$runnerRegistryPath = Join-Path $projectRoot '.qianlima\execution-runners.json'
$cases = [System.Collections.Generic.List[object]]::new()

function Add-Case([string]$Name, [bool]$Passed, [string]$Remediation) {
  $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed; remediation = if ($Passed) { $null } else { $Remediation } })
}
function Test-Command([string]$Name) { return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }
function Invoke-DockerReadOnly([string[]]$Arguments) {
  $output = @(& docker @Arguments 2>&1)
  return [PSCustomObject]@{ passed = ($LASTEXITCODE -eq 0); output = ($output -join "`n") }
}

$isWindows = $env:OS -eq 'Windows_NT'
$isPwsh = $PSVersionTable.PSEdition -eq 'Core'
$hasDocker = Test-Command 'docker'
Add-Case 'docker_cli' $hasDocker 'Install the approved Docker Desktop or managed Docker Engine package.'

$daemonReady = $false
$linuxContainers = $false
$imageReady = $false
if ($hasDocker) {
  $version = Invoke-DockerReadOnly @('version', '--format', '{{json .}}')
  $daemonReady = $version.passed
  if ($daemonReady) {
    $info = Invoke-DockerReadOnly @('info', '--format', '{{.OSType}}')
    $linuxContainers = $info.passed -and $info.output.Trim() -eq 'linux'
    $image = Invoke-DockerReadOnly @('image', 'inspect', 'alpine:3.20')
    $imageReady = $image.passed
  }
}
Add-Case 'docker_daemon' $daemonReady 'Start Docker Desktop or the approved managed Docker daemon.'
Add-Case 'linux_container_backend' $linuxContainers 'Configure Docker to use its approved Linux container backend.'
Add-Case 'approved_local_image' $imageReady 'An administrator must preload the allowlisted alpine:3.20 image; startup never pulls images.'

$platformReady = $true
if ($isWindows) {
  $hasWsl = Test-Command 'wsl.exe'
  $hyperVAvailable = $false
  try {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction Stop
    $hyperVAvailable = $feature.State -eq 'Enabled'
  } catch { $hyperVAvailable = $false }
  $platformReady = $hasWsl -or $hyperVAvailable -or $daemonReady
  Add-Case 'windows_virtualization_backend' $platformReady 'Enable WSL2 or Hyper-V through the administrator deployment entrypoint, then reboot if requested.'
} else {
  Add-Case 'powershell_7' $isPwsh 'Install PowerShell 7 for the Enterprise launcher.'
}

$registryReady = Test-Path -LiteralPath $runnerRegistryPath -PathType Leaf
$runnerContractReady = $false
if ($registryReady) {
  try {
    $registry = Get-Content -LiteralPath $runnerRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $runner = @($registry.runners | Where-Object { $_.runner_id -eq 'docker_local_isolated' }) | Select-Object -First 1
    $runnerContractReady = $null -ne $runner -and $runner.provider -eq 'docker' -and $runner.network_policy -eq 'none' -and $runner.isolation.host_workspace_mounted -eq $false
  } catch { $runnerContractReady = $false }
}
Add-Case 'isolated_runner_contract' $runnerContractReady 'Restore or register the approved docker_local_isolated Runner contract.'

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{
  status = if ($failed.Count -eq 0) { 'ready' } else { 'blocked' }
  platform = if ($isWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } else { 'linux' }
  deployment_ready = ($failed.Count -eq 0)
  execution_authorized = $false
  external_calls = $false
  changes_made = $false
  cases = @($cases)
}
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
if ($failed.Count -gt 0) { exit 1 }
