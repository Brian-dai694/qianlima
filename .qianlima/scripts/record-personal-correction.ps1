<##
.SYNOPSIS
  Records an explicit user correction as a shadow-only preference candidate.
.DESCRIPTION
  This never changes active preferences, permissions, data scope, or risk rules.
  Sensitive or credential-like text is rejected instead of being stored.
##>
param(
  [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$CorrectionText,
  [ValidateSet('task', 'route', 'workflow', 'global')] [string]$Scope = 'task',
  [string]$SourceTaskId = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$candidateRoot = Join-Path $projectRoot '.qianlima\evolution\candidates'
$forbidden = '(?i)(api[_-]?key|secret|password|cookie|bearer\s+[a-z0-9._-]{12,}|token\s*[:=]\s*[a-z0-9._-]{12,}|\b\d{11,}\b)'
if ($CorrectionText -match $forbidden) { throw 'Sensitive or credential-like correction cannot be stored.' }
if (-not (Test-Path -LiteralPath $candidateRoot -PathType Container)) { New-Item -ItemType Directory -Path $candidateRoot -Force | Out-Null }
$candidateId = 'personal-correction-' + [Guid]::NewGuid().ToString('n')
$candidatePath = Join-Path $candidateRoot "$candidateId.json"
$candidate = [ordered]@{
  schema_version = 1
  candidate_id = $candidateId
  type = 'personal_preference_candidate'
  source_type = 'explicit_user_correction'
  correction = $CorrectionText.Trim()
  scope = $Scope
  source_task_id = if ($SourceTaskId) { $SourceTaskId } else { $null }
  observation_count = 1
  status = 'candidate'
  promotion_status = 'shadow_only'
  requires_user_confirmation = $true
  permission_change_allowed = $false
  data_scope_change_allowed = $false
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($candidatePath, ($candidate | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$result = [PSCustomObject]@{ status = 'candidate_recorded'; candidate_id = $candidateId; candidate_path = $candidatePath; active_preference_changed = $false; permission_changed = $false; data_scope_changed = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
