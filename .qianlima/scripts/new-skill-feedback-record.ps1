param(
  [Parameter(Mandatory = $true)]
  [string]$SkillId,
  [Parameter(Mandatory = $true)]
  [ValidateSet('routing', 'instruction', 'resource', 'unknown')]
  [string]$LayerCandidate = 'unknown',
  [Parameter(Mandatory = $true)]
  [ValidateSet('correction', 'rejection', 'failure', 'request', 'acceptance')]
  [string]$FeedbackType,
  [Parameter(Mandatory = $true)]
  [string]$FeedbackSummary,
  [string]$RunId = '',
  [string[]]$EvidencePath = @(),
  [decimal]$Confidence = 0.5,
  [string]$Root = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
if ($Confidence -lt 0 -or $Confidence -gt 1) { throw 'Confidence must be between 0 and 1.' }

function Protect-Text([string]$Text) {
  $safe = $Text
  $safe = $safe -replace '(?i)(api[_-]?key|token|password)\s*[:=]\s*\S+', '$1: [REDACTED]'
  $safe = $safe -replace '(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', '[REDACTED_EMAIL]'
  $safe = $safe -replace '(?<!\d)1\d{10}(?!\d)', '[REDACTED_PHONE]'
  return $safe
}

$safeId = $SkillId -replace '[^A-Za-z0-9_.-]', '-'
$dir = Join-Path $Root 'feedback\skill-evolution'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$path = Join-Path $dir "$(Get-Date -Format 'yyyy-MM-dd-HHmmss')-$safeId.yaml"
$safeSummary = Protect-Text $FeedbackSummary
$safeEvidence = @($EvidencePath | ForEach-Object { Protect-Text $_ })
$evidenceLines = if ($safeEvidence.Count -gt 0) { ($safeEvidence | ForEach-Object { "  - '$($_ -replace "'", "''")'" }) -join [Environment]::NewLine } else { '  - none_provided' }
$summaryLines = ($safeSummary -split "`r?`n" | ForEach-Object { "    $_" }) -join [Environment]::NewLine

$content = @"
skill_feedback:
  recorded_at: $(Get-Date -Format 'o')
  skill_id: $safeId
  layer_candidate: $LayerCandidate
  feedback_type: $FeedbackType
  source_run_id: $RunId
  confidence: $Confidence
  feedback_summary: |
$summaryLines
  evidence_paths:
$evidenceLines
  status: observed
  next_action: classify_and_propose_only
"@

[IO.File]::WriteAllText($path, $content, (New-Object Text.UTF8Encoding($false)))
Write-Host "Skill feedback record created: $path"
