<##
.SYNOPSIS
  Records a local security incident and performs bounded containment actions.
.DESCRIPTION
  This script revokes the supplied Grant, records a frozen incident, preserves
  only logical evidence references, and creates a recovery-task reference.
  Notifications remain human-pending; no external message is sent.
##>
param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$IncidentId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$RecoveryTaskId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$AgentId,
  [Parameter(Mandatory = $true)] [ValidateSet('overreach_attempt', 'secret_exposure', 'host_mount_detected', 'network_escape_signal', 'audit_gap', 'unapproved_write', 'repeated_timeout')] [string]$Trigger,
  [ValidateSet('medium', 'high', 'critical')] [string]$Severity = 'high',
  [Parameter(Mandatory = $true)] [string]$EvidenceRef,
  [string]$GrantId = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
function Test-SafeRef([string]$Value) { return -not ([IO.Path]::IsPathRooted($Value) -or $Value -match '(^|[\/])\.\.([\/]|$)') }
if (-not (Test-SafeRef $EvidenceRef)) { throw 'EvidenceRef must be logical or workspace-relative.' }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$incidentRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\incidents')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$outPath = Join-Path $incidentRoot "$IncidentId.json"
if (Test-Path -LiteralPath $outPath) { throw "Incident already exists; records are append-only: $IncidentId" }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $outPath) -Force | Out-Null }
$actions = [System.Collections.Generic.List[string]]::new()
if ($GrantId) {
  $revoke = Join-Path $PSScriptRoot 'revoke-delegation-grant.ps1'
  & $revoke -GrantId $GrantId -Reason "Security incident $IncidentId containment: $Trigger" 6>$null | Out-Null
  [void]$actions.Add('grant_revoked')
} else { [void]$actions.Add('no_grant_supplied_requires_human_review') }
[void]$actions.Add('task_frozen')
[void]$actions.Add('evidence_reference_preserved')
[void]$actions.Add('recovery_task_reference_created')
[void]$actions.Add('human_notification_pending')
$incident = [ordered]@{
  schema_version = 1; incident_type = 'qianlima_security_incident'; incident_id = $IncidentId; task_id = $TaskId; recovery_task_id = $RecoveryTaskId; agent_id = $AgentId; trigger = $Trigger; severity = $Severity; status = 'frozen'; grant_id = if ($GrantId) { $GrantId } else { $null }; containment_actions = @($actions); evidence_refs = @($EvidenceRef); external_notification_sent = $false; human_notification_status = 'pending'; created_at = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($outPath, ($incident | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$audit = Join-Path $PSScriptRoot 'write-audit-event.ps1'
& $audit -EventType security_incident_recorded -Decision freeze -TaskId $TaskId -GrantId $GrantId -AgentId $AgentId -DataRef @($EvidenceRef) -Reason "Incident $IncidentId recorded; authority frozen and human notification pending." 6>$null | Out-Null
if ($PassThru) { $incident | ConvertTo-Json -Depth 10 } else { Write-Host "Security incident recorded: $outPath" }
