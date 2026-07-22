<##
.SYNOPSIS
  Probes a local Docker Runner without pulling images or enabling execution.
.DESCRIPTION
  This is fail-closed. The default mode only checks Docker CLI/daemon and the
  local image. -RunContainerProbe explicitly starts an ephemeral container with
  no network, a read-only task mount, dropped capabilities, and no secrets.
  An Attestation is written only with -IssueAttestation after all checks pass
  and only when the Runner is explicitly enabled in the registry.
##>
param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$AgentId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [string]$IsolationRoot,
  [string]$Image = 'alpine:3.20',
  [string]$RunnerId = 'docker_local_isolated',
  [switch]$RunContainerProbe,
  [switch]$IssueAttestation,
  [ValidateRange(1, 30)] [int]$ExpiresMinutes = 10,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$registryPath = Join-Path $projectRoot '.qianlima\execution-runners.json'
$attestationRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\sandbox-attestations')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$taskRootBase = [IO.Path]::GetFullPath((Join-Path $projectRoot ".qianlima\run-traces\sandbox-workspaces\$TaskId")).TrimEnd('\', '/')
$taskRoot = $taskRootBase + [IO.Path]::DirectorySeparatorChar
$isolationFullPath = [IO.Path]::GetFullPath($IsolationRoot)

function Finish([string]$Status, [string]$Reason, [hashtable]$Extra = @{}) {
  $result = [ordered]@{ status = $Status; runner_id = $RunnerId; agent_id = $AgentId; task_id = $TaskId; image = $Image; container_started = $false; attestation_path = $null; reason = $Reason }
  foreach ($key in $Extra.Keys) { $result[$key] = $Extra[$key] }
  if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List }
  return
}
function Test-Command([string]$Name) { return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }
function Invoke-Docker([string[]]$Arguments) {
  $output = @(& docker @Arguments 2>&1)
  [PSCustomObject]@{ exit_code = $LASTEXITCODE; output = ($output -join "`n") }
}

if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { Finish 'blocked' 'Runner registry is missing.'; exit 1 }
$registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$runner = @($registry.runners | Where-Object { $_.runner_id -eq $RunnerId }) | Select-Object -First 1
if ($null -eq $runner) { Finish 'blocked' "Unknown Runner: $RunnerId"; exit 1 }
if ($runner.provider -ne 'docker' -or $runner.execution_enabled -ne $false -and $runner.enabled -ne $true) { Finish 'blocked' 'Runner is not a Docker contract or is not safely registered.'; exit 1 }
if ($runner.image_policy -ne 'local_allowlist_only' -or @($runner.allowed_images) -notcontains $Image) { Finish 'blocked' 'Image is not in the local Runner allowlist.'; exit 1 }
if ($runner.isolation.host_workspace_mounted -ne $false -or $runner.network_policy -ne 'none' -or $runner.mcp_policy -ne 'allowlist_read_only' -or $runner.secret_policy -ne 'secret_ref_only') { Finish 'blocked' 'Runner registry violates the required isolation contract.'; exit 1 }
if ($isolationFullPath -ne $taskRootBase -and -not $isolationFullPath.StartsWith($taskRoot, [StringComparison]::OrdinalIgnoreCase)) { Finish 'blocked' 'IsolationRoot must be inside the task-specific sandbox workspace.'; exit 1 }
if (-not (Test-Path -LiteralPath $isolationFullPath -PathType Container)) { Finish 'blocked' 'IsolationRoot does not exist.'; exit 1 }
if ($Image.IndexOf([char]13) -ge 0 -or $Image.IndexOf([char]10) -ge 0 -or $Image -match '[;|&<>]') { Finish 'blocked' 'Image reference contains shell metacharacters.'; exit 1 }

if (-not (Test-Command 'docker')) { Finish 'blocked' 'Docker CLI is not installed or is not on PATH.'; exit 1 }
$version = Invoke-Docker @('version', '--format', '{{json .}}')
if ($version.exit_code -ne 0) { Finish 'blocked' 'Docker daemon is unavailable.' @{ docker_output = $version.output }; exit 1 }
$info = Invoke-Docker @('info', '--format', '{{json .}}')
if ($info.exit_code -ne 0) { Finish 'blocked' 'Docker daemon health check failed.' @{ docker_output = $info.output }; exit 1 }
$imageProbe = Invoke-Docker @('image', 'inspect', $Image)
if ($imageProbe.exit_code -ne 0) { Finish 'blocked' 'Required image is not available locally; no image pull was attempted.' @{ docker_output = $imageProbe.output }; exit 1 }

if (-not $RunContainerProbe) {
  if ($IssueAttestation) { Finish 'blocked' 'IssueAttestation requires -RunContainerProbe.'; exit 1 }
  Finish 'ready_for_explicit_probe' 'Docker daemon and local image are available; no container was started.' @{ docker_info_checked = $true; image_checked = $true }
  exit 0
}

$mount = "type=bind,source=$isolationFullPath,target=/workspace,readonly"
$probeArgs = @('run', '--rm', '--network', 'none', '--read-only', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges', '--pids-limit', '128', '--memory', '256m', '--cpus', '1', '--mount', $mount, '--workdir', '/workspace', $Image, 'sh', '-c', 'test -r /workspace && test ! -w /workspace && ! grep -q "00000000" /proc/net/route')
$containerProbe = Invoke-Docker $probeArgs
if ($containerProbe.exit_code -ne 0) { Finish 'blocked' 'Container isolation probe failed.' @{ container_started = $true; docker_output = $containerProbe.output }; exit 1 }

$evidence = [ordered]@{ runner_id = $RunnerId; provider = 'docker'; agent_id = $AgentId; task_id = $TaskId; image = $Image; isolation_root = $isolationFullPath; probe = 'network_none_read_only_bind_no_caps_no_new_privileges'; checked_at = (Get-Date).ToUniversalTime().ToString('o') }
$evidenceJson = $evidence | ConvertTo-Json -Depth 10 -Compress
$sha = [Security.Cryptography.SHA256]::Create(); $evidenceHash = 'sha256:' + (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($evidenceJson)) | ForEach-Object { $_.ToString('x2') }) -join '')
if (-not $IssueAttestation) {
  Finish 'probe_passed' 'Container isolation probe passed; no Attestation was written.' @{ container_started = $true; evidence_hash = $evidenceHash }
  exit 0
}
if ($runner.enabled -ne $true) { Finish 'blocked' 'Runner is not enabled; probe evidence cannot authorize execution.' @{ container_started = $true; evidence_hash = $evidenceHash }; exit 1 }

$attestationId = "sandbox-docker-$TaskId-$([Guid]::NewGuid().ToString('n').Substring(0, 12))"
$outPath = Join-Path $attestationRoot "$attestationId.json"
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $outPath) -Force | Out-Null }
$attestation = [ordered]@{
  schema_version = 1; contract_type = 'qianlima_sandbox_attestation'; attestation_id = $attestationId; runner_id = $RunnerId; provider = 'docker'; agent_id = $AgentId; task_id = $TaskId; status = 'verified'; sandbox_type = 'docker-container'
  isolation_root = $isolationFullPath; host_workspace_mounted = $false; agent_network = 'none'; provider_egress = 'model-provider-allowlist-only'; mcp_mode = 'allowlist_read_only'; mcp_servers = @(); file_export = $false; web_access = $false; erp_access = $false; secret_mode = 'secret_ref_only'; expires_at = (Get-Date).ToUniversalTime().AddMinutes($ExpiresMinutes).ToString('o'); evidence_hash = $evidenceHash
}
[IO.File]::WriteAllText($outPath, ($attestation | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
Finish 'attested' 'Docker isolation probe passed and a task-bound Attestation was written.' @{ container_started = $true; attestation_path = $outPath; attestation_id = $attestationId; evidence_hash = $evidenceHash }
exit 0
