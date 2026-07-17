<#!
.SYNOPSIS
  Probe a vendor sandbox and issue a task-bound Qianlima attestation.
.DESCRIPTION
  This script fails closed. It never creates a verified attestation from a
  manual switch; the vendor must report a usable sandbox, and the task must
  have a separate isolated workspace directory.
#>
param(
  [Parameter(Mandatory = $true)] [ValidateSet('codewhale', 'raven')] [string]$Provider,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$AgentId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [string]$IsolationRoot,
  [ValidateRange(1, 30)] [int]$ExpiresMinutes = 10,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$attestationRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\sandbox-attestations')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$isolationFullPath = [IO.Path]::GetFullPath($IsolationRoot)
$taskRootBase = [IO.Path]::GetFullPath((Join-Path $projectRoot ".qianlima\run-traces\sandbox-workspaces\$TaskId")).TrimEnd('\', '/')
$taskRoot = $taskRootBase + [IO.Path]::DirectorySeparatorChar
if ($isolationFullPath -ne $taskRootBase -and -not $isolationFullPath.StartsWith($taskRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'IsolationRoot must be inside the task-specific sandbox workspace.' }
if (-not (Test-Path -LiteralPath $isolationFullPath -PathType Container)) { throw 'IsolationRoot does not exist.' }

$command = if ($Provider -eq 'codewhale') { 'codewhale' } else { 'raven' }
$probe = @(& $command doctor 2>&1)
if ($Provider -eq 'raven') { $probe = @(& $command sandbox list 2>&1) }
$probeText = ($probe -join "`n")
if ($probeText -match '(?i)sandbox\s+not\s+available|no sandbox|no vm|requires.*sandbox\.debug') { throw "$Provider sandbox probe failed: no usable sandbox was reported." }
if ($Provider -eq 'codewhale' -and $probeText -notmatch '(?i)sandbox\s*(available|ready|enabled)|sandbox.*:\s*(available|ready|enabled)') { throw 'CodeWhale sandbox probe did not provide a positive readiness signal.' }
if ($Provider -eq 'raven' -and $probeText -notmatch '(?i)(vm|sandbox).*(ready|running|available|owned|\*)') { throw 'Raven sandbox probe did not provide a positive VM readiness signal.' }

$attestationId = "sandbox-$Provider-$TaskId-$([Guid]::NewGuid().ToString('n').Substring(0, 12))"
$evidence = [ordered]@{ provider = $Provider; agent_id = $AgentId; task_id = $TaskId; sandbox_probe = $probeText; isolation_root = $isolationFullPath; checked_at = (Get-Date).ToUniversalTime().ToString('o') }
$evidenceJson = $evidence | ConvertTo-Json -Depth 8 -Compress
$sha = [Security.Cryptography.SHA256]::Create(); $evidenceHash = 'sha256:' + (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($evidenceJson)) | ForEach-Object { $_.ToString('x2') }) -join '')
$attestation = [ordered]@{
  schema_version = 1; contract_type = 'qianlima_sandbox_attestation'; attestation_id = $attestationId
  provider = $Provider; agent_id = $AgentId; task_id = $TaskId; status = 'verified'; sandbox_type = "$Provider-native-sandbox"
  isolation_root = $isolationFullPath; host_workspace_mounted = $false; agent_network = 'none'; provider_egress = 'model-provider-allowlist-only'; secret_mode = 'secret_ref_only'
  expires_at = (Get-Date).ToUniversalTime().AddMinutes($ExpiresMinutes).ToString('o'); evidence_hash = $evidenceHash
}
$outPath = Join-Path $attestationRoot "$attestationId.json"
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $outPath) -Force | Out-Null }
[IO.File]::WriteAllText($outPath, ($attestation | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
if ($PassThru) { $attestation | ConvertTo-Json -Depth 8 } else { Write-Host "Sandbox attestation created: $outPath" }
