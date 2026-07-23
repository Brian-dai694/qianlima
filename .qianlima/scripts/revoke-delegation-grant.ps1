param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$GrantId,
  [Parameter(Mandatory = $true)] [string]$Reason,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$grantRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\delegation-grants')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$grantPath = Join-Path $grantRoot "$GrantId.json"
if (-not (Test-Path -LiteralPath $grantPath -PathType Leaf)) { throw "Delegation grant not found: $GrantId" }
$grant = Get-Content -LiteralPath $grantPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($grant.grant_id -ne $GrantId) { throw 'Grant ID does not match its file.' }
$revocationPath = Join-Path $projectRoot '.qianlima\run-traces\grant-revocations.jsonl'
$revocation = [ordered]@{ schema_version = 1; event_id = [Guid]::NewGuid().ToString('n'); grant_id = $GrantId; task_id = $grant.task_id; agent_id = $grant.agent_id; reason = $Reason; revoked_at = (Get-Date).ToUniversalTime().ToString('o') }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $revocationPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $revocationPath) -Force | Out-Null }
[IO.File]::AppendAllText($revocationPath, (($revocation | ConvertTo-Json -Depth 6 -Compress) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
$audit = Join-Path $PSScriptRoot 'write-audit-event.ps1'
& $audit -EventType grant_revoked -Decision revoke -TaskId $grant.task_id -GrantId $GrantId -AgentId $grant.agent_id -Reason $Reason | Out-Null
if ($PassThru) { $revocation | ConvertTo-Json -Depth 6 } else { Write-Host "Delegation grant revoked: $GrantId" }
