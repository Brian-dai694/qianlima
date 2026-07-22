<#
.SYNOPSIS
  Strict public-safe verification for the Qianlima workspace.
.DESCRIPTION
  Checks that required public-safe files, runtime directories, and project files
  exist; that the workspace index is fresh; that workflow-index references resolve
  and every task-card id has a matching workflow-index entry. Warns (does not fail)
  when private local files are present so you can confirm they stay gitignored.
  Exits non-zero when any Issue is found; used locally before commit and in CI.
.PARAMETER Root
  The .qianlima workspace root. Defaults to the parent of this script's folder.
.PARAMETER MaxIndexAgeHours
  Maximum allowed age of the generated workspace index before it is flagged stale.
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\.qianlima\scripts\verify-qianlima.ps1
.OUTPUTS
  Human-readable pass/fail summary with Issues and Warnings counts.
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [int]$MaxIndexAgeHours = 24
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $Root '..')).Path
$Issues = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]

function Add-Issue([string]$Message) { $Issues.Add($Message) }
function Add-Warning([string]$Message) { $Warnings.Add($Message) }
function Test-Leaf([string]$RelativePath) { Test-Path -LiteralPath (Join-Path $Root $RelativePath) -PathType Leaf }
function Test-ProjectLeaf([string]$RelativePath) { Test-Path -LiteralPath (Join-Path $ProjectRoot $RelativePath) -PathType Leaf }

foreach ($file in @('WORKSPACE_INDEX.md', 'workspace-index.json', 'CODEX_BOOT.md', 'workflow-index.yaml', 'risk-rules.yaml', 'context-policy.yaml', 'model-adapters.yaml', 'model-pricing.json', 'skill-evolution.yaml', 'response-policy.yaml', 'task-runtime.yaml', 'world-model.yaml', 'data-sources.example.yaml', 'work.example.ws', 'specifications/skill-self-evolution-contract.json', 'specifications/qianlima-execution-plan-contract.json', 'specifications/qianlima-step-result-contract.json', 'specifications/qianlima-evr-contract.json', 'specifications/qianlima-readonly-runner-contract.json', 'specifications/qianlima-desired-state-diff-contract.json', 'specifications/qianlima-evidence-pack-contract.json', 'scripts/get-model-cost.ps1', 'scripts/new-staged-response.ps1', 'scripts/save-hot-state.ps1', 'scripts/new-task-contract.ps1', 'scripts/set-task-control.ps1', 'scripts/check-task-contract.ps1', 'scripts/get-snapshot-decision.ps1', 'scripts/summarize-csv.ps1', 'scripts/update-tool-health.ps1', 'scripts/write-experience-event.ps1', 'scripts/get-quality-dashboard.ps1', 'scripts/new-skill-feedback-record.ps1', 'scripts/new-skill-patch-proposal.ps1', 'scripts/invoke-skill-self-evolution.ps1', 'scripts/test-skill-self-evolution.ps1', 'scripts/new-qianlima-execution-plan.ps1', 'scripts/new-qianlima-step-result.ps1', 'scripts/invoke-qianlima-evr.ps1', 'scripts/invoke-qianlima-readonly-runner.ps1', 'scripts/test-qianlima-execution-plan.ps1', 'scripts/new-qianlima-desired-state-diff.ps1', 'scripts/new-qianlima-evidence-pack.ps1', 'scripts/test-qianlima-state-diff.ps1', 'workflows/skill_evolution.yaml', 'task-cards/skill-evolution.yaml', 'templates/operational-snapshot_template.json', 'templates/experience-event_template.json', 'templates/token-usage-record_template.yaml')) {
  if (-not (Test-Leaf $file)) { Add-Issue "Missing required public-safe Qianlima file: $file" }
}
foreach ($dir in @('logs', 'usage-ledger')) {
  if (-not (Test-Path -LiteralPath (Join-Path $Root $dir) -PathType Container)) { Add-Issue "Missing required runtime directory: $dir" }
}
foreach ($file in @('AGENTS.md', 'AI_START_HERE.md', 'start-qianlima.ps1', 'README.md')) {
  if (-not (Test-ProjectLeaf $file)) { Add-Issue "Missing required project file: $file" }
}
foreach ($file in @('work.ws', 'data-sources.yaml', 'work-hub.ws', 'user-preferences.yaml')) {
  if (Test-Leaf $file) { Add-Warning "Private local file exists; verify it is ignored and not committed: $file" }
}

$indexPath = Join-Path $Root 'WORKSPACE_INDEX.md'
if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
  $indexText = Get-Content -LiteralPath $indexPath -Encoding UTF8 -Raw
  $generatedLine = ($indexText -split "`r?`n" | Where-Object { $_ -match '^Generated at:' } | Select-Object -First 1)
  if ($generatedLine -match '^Generated at:\s*(.+)$') {
    try {
      $generatedAt = [datetimeoffset]::Parse($Matches[1])
      $ageHours = ([datetimeoffset]::Now - $generatedAt).TotalHours
      if ($ageHours -gt $MaxIndexAgeHours) { Add-Warning ("WORKSPACE_INDEX.md is older than {0} hours: {1:N1}h" -f $MaxIndexAgeHours, $ageHours) }
    } catch { Add-Warning 'Could not parse WORKSPACE_INDEX.md generated timestamp.' }
  } else { Add-Warning 'WORKSPACE_INDEX.md has no generated timestamp.' }
}

$workflowIndexPath = Join-Path $Root 'workflow-index.yaml'
if (Test-Path -LiteralPath $workflowIndexPath -PathType Leaf) {
  $workflowText = Get-Content -LiteralPath $workflowIndexPath -Encoding UTF8 -Raw
  foreach ($match in [regex]::Matches($workflowText, 'definition:\s*(?<path>workflows/[^\s"'']+)')) {
    $relative = $match.Groups['path'].Value -replace '/', [IO.Path]::DirectorySeparatorChar
    if (-not (Test-Leaf $relative)) { Add-Issue "workflow-index references missing workflow definition: $($match.Groups['path'].Value)" }
  }
  foreach ($match in [regex]::Matches($workflowText, '(?m)^\s*(template|task_card):\s*(?<path>[^\s"'']+)')) {
    $relative = $match.Groups['path'].Value -replace '/', [IO.Path]::DirectorySeparatorChar
    if (-not (Test-Leaf $relative)) { Add-Issue "workflow-index references missing file: $($match.Groups['path'].Value)" }
  }

  $taskCardDir = Join-Path $Root 'task-cards'
  if (Test-Path -LiteralPath $taskCardDir -PathType Container) {
    Get-ChildItem -LiteralPath $taskCardDir -File -Filter '*.yaml' | ForEach-Object {
      $taskText = Get-Content -LiteralPath $_.FullName -Encoding UTF8 -Raw
      $id = $_.BaseName
      if ($taskText -match '(?m)^\s*id:\s*([^\s]+)') { $id = $Matches[1].Trim() }
      if ($workflowText -notmatch "(?m)^\s*-\s*id:\s*$([regex]::Escape($id))\s*$") { Add-Warning "Task card has no workflow-index entry: $id" }
    }
  }
}

$secretPatterns = @(
  'sk-[A-Za-z0-9_-]{20,}',
  'AKIA[0-9A-Z]{16}',
  '(?i)(api[_-]?key|secret|token|password)\s*[:=]\s*[''\"]?[A-Za-z0-9_./+=-]{16,}',
  '(?i)(aws_access_key_id|aws_secret_access_key)\s*[:=]'
)
$files = @(git -C $ProjectRoot -c core.quotePath=false ls-files 2>$null)
foreach ($relative in $files) {
  if ($relative -match '(^|/)\.qianlima/WORKSPACE_INDEX\.md$|(^|/)\.qianlima/workspace-index\.json$|(^|/)\.qianlima/usage-ledger/|(^|/)\.qianlima/logs/') { continue }
  $path = Join-Path $ProjectRoot $relative
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
  $item = Get-Item -LiteralPath $path -Force
  if ($item.Length -gt 1048576) { continue }
  if ($item.Extension -notin @('.md', '.yaml', '.yml', '.ps1', '.json', '.txt', '.gitignore')) { continue }
  try { $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) } catch { Add-Warning "Could not read tracked public-safe file; skipped secret scan: $relative"; continue }
  foreach ($pattern in $secretPatterns) {
    if ($text -match $pattern) {
      Add-Issue "Potential secret-like value found in public-safe scan: $relative"
      break
    }
  }
}

if ($Issues.Count -eq 0) { Write-Host 'Qianlima verification passed.' } else {
  Write-Host 'Qianlima verification failed.'
  foreach ($issue in $Issues) { Write-Host "- ERROR: $issue" }
}
foreach ($warning in $Warnings) { Write-Host "- WARN: $warning" }
Write-Host "Issues: $($Issues.Count)"
Write-Host "Warnings: $($Warnings.Count)"
if ($Issues.Count -gt 0) { exit 1 }
