param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$EventType,
  [Parameter(Mandatory = $true)] [ValidateSet('allow', 'deny', 'revoke', 'complete', 'freeze')] [string]$Decision,
  [string]$TaskId = '',
  [string]$GrantId = '',
  [string]$AgentId = '',
  [Parameter(Mandatory = $true)] [string]$Reason,
  [string[]]$DataRef = @(),
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$forbidden = @('api_key', 'access_token', 'refresh_token', 'password', 'cookie', 'authorization:')
foreach ($value in @($Reason) + @($DataRef)) { foreach ($needle in $forbidden) { if ($value -match [regex]::Escape($needle)) { throw 'Audit events cannot contain secrets or authorization material.' } } }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$auditRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $auditRoot 'audit-events.jsonl' }
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFullPath.StartsWith($auditRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Audit events must be written under .qianlima/run-traces.' }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputFullPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $outputFullPath) -Force | Out-Null }
$event = [ordered]@{ schema_version = 1; event_id = [Guid]::NewGuid().ToString('n'); event_type = $EventType; decision = $Decision; actor = 'qianlima_broker'; task_id = if ($TaskId) { $TaskId } else { $null }; grant_id = if ($GrantId) { $GrantId } else { $null }; agent_id = if ($AgentId) { $AgentId } else { $null }; data_refs = @($DataRef); reason = $Reason; created_at = (Get-Date).ToUniversalTime().ToString('o') }
$line = ($event | ConvertTo-Json -Depth 8 -Compress) + [Environment]::NewLine
$written = $false
for ($attempt = 1; $attempt -le 3 -and -not $written; $attempt++) {
  try {
    [IO.File]::AppendAllText($outputFullPath, $line, [Text.UTF8Encoding]::new($false))
    $written = $true
  } catch [IO.IOException] {
    if ($attempt -eq 3) { throw }
    Start-Sleep -Milliseconds (50 * $attempt)
  }
}
if ($PassThru) { $event | ConvertTo-Json -Depth 8 } else { Write-Host "Audit event written: $($event.event_id)" }
