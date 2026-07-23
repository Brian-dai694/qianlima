<##
.SYNOPSIS
  Enforces the Skill self-evolution state machine.
.DESCRIPTION
  This manager joins sanitized feedback, public evaluation evidence, a rule
  abstraction, an isolated candidate, independent validation, and a human
  release decision. It appends metadata-only events and never edits a
  production Skill, Harness, permission rule, or runtime file.
##>
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('record_feedback', 'collect_evidence', 'abstract_rule', 'create_patch', 'validate', 'auto_release', 'rollback', 'status')]
  [string]$Action,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')]
  [string]$CandidateId,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9._-]{2,120}$')]
  [string]$SkillId,
  [string]$FeedbackPath = '',
  [string[]]$EvidencePath = @(),
  [string]$RuleSummary = '',
  [string]$CandidatePath = '',
  [string]$ApprovalRef = '',
  [ValidateSet('approve', 'reject')]
  [string]$Decision = '',
  [string]$ReleaseRef = '',
  [string]$RollbackRef = '',
  [string]$Reason = '',
  [string]$Root = '',
  [string]$EventLogPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$qianlimaRoot = Join-Path $Root '.qianlima'
$contractPath = Join-Path $qianlimaRoot 'specifications\skill-self-evolution-contract.json'
$contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($EventLogPath)) { $EventLogPath = Join-Path $qianlimaRoot 'evolution\skill-self-evolution-events.jsonl' }
$eventRoot = [IO.Path]::GetFullPath((Join-Path $qianlimaRoot 'evolution')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$eventFullPath = [IO.Path]::GetFullPath($EventLogPath)
if (-not $eventFullPath.StartsWith($eventRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'EventLogPath must remain inside .qianlima/evolution.' }

function Normalize-Path([string]$Value) { return (($Value -replace '\\', '/') -replace '/+', '/').TrimStart('./') }
function Get-RelativePath([string]$BasePath, [string]$FullPath) {
  $base = [IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  $full = [IO.Path]::GetFullPath($FullPath)
  $baseUri = New-Object Uri ($base)
  $fullUri = New-Object Uri ($full)
  return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($fullUri).ToString()).Replace('\', '/')
}
function Resolve-Safe([string]$Path, [string]$RootPath, [string]$Label) {
  $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
  $full = [IO.Path]::GetFullPath([string]$resolved.Path)
  $rootFull = [IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) { throw "$Label must remain inside $RootPath." }
  return $full
}
function Test-AllowedRef([string]$Path, [string]$ExpectedRoot, [switch]$RejectPrivateNames) {
  $normalized = Normalize-Path $Path
  $prefix = (Normalize-Path $ExpectedRoot).TrimEnd('/') + '/'
  if (-not $normalized.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $false }
  if ($RejectPrivateNames -and $normalized -match '(?i)(private|raw|secret|confidential|customer|browser[_-]?export|credential)') { return $false }
  return $true
}
function Get-State([string]$Id, [string]$LogPath) {
  if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) { return 'none' }
  $events = @(Get-Content -LiteralPath $LogPath -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.candidate_id -eq $Id })
  if ($events.Count -eq 0) { return 'none' }
  return [string]$events[-1].to_state
}
function Get-LastEvent([string]$Id, [string]$LogPath) {
  if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) { return $null }
  $events = @(Get-Content -LiteralPath $LogPath -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.candidate_id -eq $Id })
  if ($events.Count -eq 0) { return $null }
  return $events[-1]
}
function Require-Value([string]$Value, [string]$Name) { if ([string]::IsNullOrWhiteSpace($Value)) { throw "$Name is required for $Action." } }
function Get-FileSha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-StringSha([string]$Value) { $bytes = [Text.Encoding]::UTF8.GetBytes($Value); return ([Security.Cryptography.SHA256]::Create().ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '' }
function Add-Event([hashtable]$Fields) {
  $dir = Split-Path -Parent $EventLogPath
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $event = [ordered]@{
    event_id = 'skill-evolution-' + [Guid]::NewGuid().ToString('n')
    recorded_at = (Get-Date).ToUniversalTime().ToString('o')
    candidate_id = $CandidateId
    skill_id = $SkillId
    action = $Action
    from_state = $Fields.from_state
    to_state = $Fields.to_state
    feedback_ref = $Fields.feedback_ref
    evidence_refs = @($Fields.evidence_refs)
    candidate_ref = $Fields.candidate_ref
    candidate_sha256 = $Fields.candidate_sha256
    approval_ref = $Fields.approval_ref
    rule_summary_sha256 = $Fields.rule_summary_sha256
    decision = $Fields.decision
    release_ref = $Fields.release_ref
    rollback_ref = $Fields.rollback_ref
    reason = $Fields.reason
    production_change = $false
    automatic_promotion = [bool]$Fields.automatic_promotion
    external_calls = $false
  }
  [IO.File]::AppendAllText($EventLogPath, (($event | ConvertTo-Json -Depth 12 -Compress) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
  return $event
}

$state = Get-State $CandidateId $EventLogPath
if ($Action -eq 'status') {
  $result = [ordered]@{ status = 'ok'; candidate_id = $CandidateId; skill_id = $SkillId; state = $state; event_log = Normalize-Path (Get-RelativePath $Root $EventLogPath); production_change = $false; automatic_promotion = $false }
  if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
  exit 0
}
$rule = $contract.transition_rules.$Action
if ($null -eq $rule) { throw "Action is not defined by the contract: $Action" }
if (@($rule.from) -notcontains $state) { throw "Invalid transition: $Action requires $(@($rule.from) -join ', '), current state is $state." }

$feedbackRef = $null
$evidenceRefs = @()
$candidateRef = $null
$candidateSha = $null
$ruleSummarySha = $null
switch ($Action) {
  'record_feedback' {
    Require-Value $FeedbackPath 'FeedbackPath'
    $feedbackFull = Resolve-Safe $FeedbackPath (Join-Path $qianlimaRoot 'feedback\skill-evolution') 'FeedbackPath'
    $feedbackText = Get-Content -LiteralPath $feedbackFull -Raw -Encoding UTF8
    if ($feedbackText -match '(?i)(-----BEGIN .*PRIVATE KEY-----|sk-[A-Za-z0-9_-]{20,}|api[_-]?key\s*[:=]\s*(?!\[REDACTED\])|password\s*[:=]\s*(?!\[REDACTED\])|token\s*[:=]\s*(?!\[REDACTED\])|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})') { throw 'FeedbackPath contains raw private evidence.' }
    $feedbackRef = Normalize-Path (Get-RelativePath $Root $feedbackFull)
    if (-not (Test-AllowedRef $feedbackRef '.qianlima/feedback/skill-evolution')) { throw 'FeedbackPath must be a sanitized skill-evolution feedback record.' }
  }
  'collect_evidence' {
    if ($EvidencePath.Count -eq 0) { throw 'At least one sanitized evidence path is required.' }
    foreach ($path in $EvidencePath) {
      $full = Resolve-Safe $path (Join-Path $qianlimaRoot 'evolution\eval-cases') 'EvidencePath'
      $evidenceText = Get-Content -LiteralPath $full -Raw -Encoding UTF8
      if ($evidenceText -match '(?i)(-----BEGIN .*PRIVATE KEY-----|sk-[A-Za-z0-9_-]{20,}|api[_-]?key\s*[:=]\s*(?!\[REDACTED\])|password\s*[:=]\s*(?!\[REDACTED\])|token\s*[:=]\s*(?!\[REDACTED\])|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}|[A-Z]:\\Users\\|/Users/|/home/)') { throw "EvidencePath contains raw private evidence: $path" }
      $ref = Normalize-Path (Get-RelativePath $Root $full)
      if (-not (Test-AllowedRef $ref '.qianlima/evolution/eval-cases' -RejectPrivateNames)) { throw "EvidencePath is not an approved sanitized case: $path" }
      $evidenceRefs += $ref
    }
  }
  'abstract_rule' { Require-Value $RuleSummary 'RuleSummary'; if ($RuleSummary -match '(?i)(api[_-]?key|token|password|secret|private key|raw_prompt|hidden_reasoning)') { throw 'RuleSummary contains a prohibited secret or raw-trace marker.' }; $ruleSummarySha = Get-StringSha $RuleSummary }
  'create_patch' {
    Require-Value $CandidatePath 'CandidatePath'
    $candidateFull = Resolve-Safe $CandidatePath (Join-Path $qianlimaRoot 'evolution\candidates') 'CandidatePath'
    $candidateRef = Normalize-Path (Get-RelativePath $Root $candidateFull)
    $candidate = Get-Content -LiteralPath $candidateFull -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$candidate.candidate_id -ne $CandidateId) { throw 'CandidateId does not match the candidate file.' }
    if ($candidate.permission_impact.expands_permissions -eq $true -or [string]$candidate.permission_impact.attack_surface_change -notin @('none', 'decreased')) { throw 'Skill self-evolution cannot expand permissions or attack surface.' }
    $candidateSha = Get-FileSha $candidateFull
  }
  'validate' {
    Require-Value $CandidatePath 'CandidatePath'
    $candidateFull = Resolve-Safe $CandidatePath (Join-Path $qianlimaRoot 'evolution\candidates') 'CandidatePath'
    $candidateRef = Normalize-Path (Get-RelativePath $Root $candidateFull)
    $candidate = Get-Content -LiteralPath $candidateFull -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$candidate.candidate_id -ne $CandidateId) { throw 'CandidateId does not match the candidate file.' }
    if ($candidate.permission_impact.expands_permissions -eq $true -or [string]$candidate.permission_impact.attack_surface_change -notin @('none', 'decreased')) { throw 'Skill self-evolution cannot expand permissions or attack surface.' }
    $validator = Join-Path $qianlimaRoot 'scripts\validate-improvement-candidate.ps1'
    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -CandidatePath $candidateFull -PassThru 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($output -join "`n")
    $start = $text.IndexOf('{'); $end = $text.LastIndexOf('}')
    $validation = $null
    if ($start -ge 0 -and $end -gt $start) { try { $validation = $text.Substring($start, $end - $start + 1) | ConvertFrom-Json } catch {} }
    if ($exitCode -ne 0 -or $null -eq $validation -or $validation.status -ne 'passed') {
      $frozen = Add-Event @{ from_state = $state; to_state = 'frozen'; candidate_ref = $candidateRef; candidate_sha256 = Get-FileSha $candidateFull; reason = 'Independent candidate validation failed.'; evidence_refs = @(); feedback_ref = $null }
      $result = [ordered]@{ status = 'frozen'; state = 'frozen'; candidate_id = $CandidateId; validation = $validation; event_id = $frozen.event_id; production_change = $false }
      if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
      exit 1
    }
    if ([string]$candidate.lifecycle_state -ne 'shadow_converged') { throw 'Candidate must be shadow_converged before replay validation.' }
    $candidateSha = Get-FileSha $candidateFull
  }
  'auto_release' {
    Require-Value $CandidatePath 'CandidatePath'
    $candidateFull = Resolve-Safe $CandidatePath (Join-Path $qianlimaRoot 'evolution\candidates') 'CandidatePath'
    $candidateRef = Normalize-Path (Get-RelativePath $Root $candidateFull)
    $candidate = Get-Content -LiteralPath $candidateFull -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$candidate.candidate_id -ne $CandidateId) { throw 'CandidateId does not match the candidate file.' }
    if ([string]$candidate.target_layer -notin @('skill', 'router', 'task_card', 'workflow')) { throw 'Only low-risk Skill, router, task-card, and workflow changes may auto-release.' }
    if ($candidate.permission_impact.expands_permissions -eq $true -or [string]$candidate.permission_impact.attack_surface_change -notin @('none', 'decreased')) { throw 'Automatic release cannot expand permissions or attack surface.' }
    if ([string]$candidate.proposed_change.apply_mode -ne 'auto_release') { throw 'Candidate must explicitly opt into auto_release mode.' }
    $prior = Get-LastEvent $CandidateId $EventLogPath
    if ($null -eq $prior -or $prior.action -ne 'validate') { throw 'Automatic release requires a successful independent validation event.' }
    if ([string]::IsNullOrWhiteSpace($ReleaseRef)) { $ReleaseRef = 'auto-release:' + $CandidateId + ':' + [string]$candidate.candidate_version }
    $candidateSha = Get-FileSha $candidateFull
  }
  'rollback' { Require-Value $RollbackRef 'RollbackRef'; Require-Value $Reason 'Reason'; $prior = Get-LastEvent $CandidateId $EventLogPath; if ($null -eq $prior -or $prior.action -ne 'auto_release') { throw 'Rollback must reference the latest automatic release event.' } }
  'status' { }
}

$autoPromotion = $Action -eq 'auto_release'
$event = Add-Event @{ from_state = $state; to_state = [string]$rule.to; feedback_ref = $feedbackRef; evidence_refs = $evidenceRefs; candidate_ref = $candidateRef; candidate_sha256 = $candidateSha; rule_summary_sha256 = $ruleSummarySha; approval_ref = $ApprovalRef; decision = $Decision; release_ref = $ReleaseRef; rollback_ref = $RollbackRef; reason = $Reason; automatic_promotion = $autoPromotion }
$result = [ordered]@{ status = 'accepted'; action = $Action; candidate_id = $CandidateId; state = [string]$rule.to; event_id = $event.event_id; release_ref = $ReleaseRef; production_change = $false; automatic_promotion = $autoPromotion; external_calls = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
