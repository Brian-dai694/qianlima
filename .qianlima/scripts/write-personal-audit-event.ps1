param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]+$')] [string]$EventType,
  [Parameter(Mandatory = $true)] [ValidateSet('allow', 'deny', 'complete', 'revoke', 'freeze')] [string]$Decision,
  [string]$TaskId = '',
  [string]$GrantId = '',
  [string]$AgentId = '',
  [Parameter(Mandatory = $true)] [string]$Reason,
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $traceRoot 'personal-audit-events.jsonl' }
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFullPath.StartsWith($traceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Personal audit events must stay under .qianlima/run-traces.' }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputFullPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $outputFullPath) -Force | Out-Null }
$event = [ordered]@{
  schema_version = 1
  event_id = [Guid]::NewGuid().ToString('n')
  event_type = $EventType
  decision = $Decision
  actor = 'qianlima_personal_broker'
  task_id = if ($TaskId) { $TaskId } else { $null }
  grant_id = if ($GrantId) { $GrantId } else { $null }
  agent_id = if ($AgentId) { $AgentId } else { $null }
  reason = $Reason
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
$line = ($event | ConvertTo-Json -Depth 8 -Compress) + [Environment]::NewLine
[IO.File]::AppendAllText($outputFullPath, $line, [Text.UTF8Encoding]::new($false))
if ($PassThru) { $event | ConvertTo-Json -Depth 8 } else { Write-Host "Audit event written: $($event.event_id)" }
