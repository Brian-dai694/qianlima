<#
.SYNOPSIS
Validates the Qianlima workspace skeleton and privacy guards.
.DESCRIPTION
Checks that required directories, project files, and public template files exist,
warning about expected-absent private files. Verifies that paths referenced by
workflow-index.yaml resolve, then scans tracked text files for leaked Windows
user paths and secrets. Exits 1 and lists issues on any failure.
.PARAMETER Root
Path to the .qianlima workspace root; defaults to the parent of this script.
.EXAMPLE
.\validate-qianlima.ps1
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $Root '..')).Path
$issues = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Issue([string]$Message) { $script:issues.Add($Message) }
function Add-Warning([string]$Message) { $script:warnings.Add($Message) }
function Test-QFile([string]$RelativePath) { Test-Path -LiteralPath (Join-Path $Root $RelativePath) -PathType Leaf }
function Test-QDir([string]$RelativePath) { Test-Path -LiteralPath (Join-Path $Root $RelativePath) -PathType Container }
function Test-PFile([string]$RelativePath) { Test-Path -LiteralPath (Join-Path $ProjectRoot $RelativePath) -PathType Leaf }

$requiredProjectFiles = @(
  'README.md',
  'AGENTS.md',
  'AI_START_HERE.md',
  'start-qianlima.ps1'
)

$requiredPublicFiles = @(
  'file-registry.yaml',
  'data-sources.example.yaml',
  'naming-rules.yaml',
  'workflow-index.yaml',
  'risk-rules.yaml',
  'model-adapters.yaml',
  'model-pricing.json',
  'skill-evolution.yaml',
  'world-model.yaml',
  'context-policy.yaml',
  'WORKSPACE_INDEX.md',
  'workspace-index.json',
  'rules/work-governance-rules.yaml',
  'workflows/daily_ad_report.yaml',
  'playbooks/context-compression-playbook.yaml',
  'scripts/bootstrap-qianlima.ps1',
  'scripts/get-model-cost.ps1',
  'scripts/new-skill-feedback-record.ps1',
  'scripts/new-skill-patch-proposal.ps1',
  'workflows/skill_evolution.yaml',
  'task-cards/skill-evolution.yaml',
  'templates/ad-ops_daily-report_template.md',
  'templates/token-usage-record_template.yaml',
  'CODEX_BOOT.md'
)

$optionalPrivateFiles = @(
  'work.ws',
  'work-hub.ws',
  'data-sources.yaml',
  'user-preferences.yaml'
)

$requiredDirs = @(
  'templates',
  'logs',
  'usage-ledger',
  'workflows',
  'rules',
  'scripts',
  'playbooks',
  'task-cards'
)

foreach ($dir in $requiredDirs) {
  if (-not (Test-QDir $dir)) { Add-Issue "Missing directory: $dir" }
}
foreach ($file in $requiredProjectFiles) {
  if (-not (Test-PFile $file)) { Add-Issue "Missing project file: $file" }
}
foreach ($file in $requiredPublicFiles) {
  if (-not (Test-QFile $file)) { Add-Issue "Missing public template file: $file" }
}
foreach ($file in $optionalPrivateFiles) {
  if (-not (Test-QFile $file)) { Add-Warning "Private local file is absent, as expected for Git-safe template: $file" }
}

$workflowIndexPath = Join-Path $Root 'workflow-index.yaml'
if (Test-Path -LiteralPath $workflowIndexPath -PathType Leaf) {
  $workflowText = Get-Content -LiteralPath $workflowIndexPath -Encoding UTF8 -Raw
  $pathRefs = New-Object System.Collections.Generic.List[string]
  foreach ($match in [regex]::Matches($workflowText, '(?m)^\s*(definition|template|task_card):\s*(?<path>[^\s"'']+)')) {
    $pathRefs.Add($match.Groups['path'].Value.Trim())
  }
  foreach ($match in [regex]::Matches($workflowText, '(?m)^\s*-\s*(?<path>rules/[^\s"'']+)')) {
    $pathRefs.Add($match.Groups['path'].Value.Trim())
  }
  foreach ($ref in ($pathRefs | Sort-Object -Unique)) {
    $refPath = Join-Path $Root ($ref -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $refPath -PathType Leaf)) {
      Add-Issue "Workflow index references missing file: $ref"
    }
  }
}

$privacyScanFiles = @()
try {
  $privacyScanFiles = @(git -C $ProjectRoot -c core.quotePath=false ls-files 2>$null)
} catch {
  $privacyScanFiles = @()
}

if ($privacyScanFiles.Count -eq 0) {
  $privacyScanFiles = @(Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -Include *.md,*.yaml,*.yml,*.ps1,*.json | ForEach-Object { $_.FullName.Substring($ProjectRoot.Length + 1) })
}

$privacyPatterns = @(
  @{ Name = 'Windows user path'; Pattern = '([A-Za-z]:[\/](Users|用户)[\/]|C:[\/]Users[\/])' },
  @{ Name = 'OpenAI-style secret'; Pattern = 'sk-[A-Za-z0-9_-]{20,}' },
  @{ Name = 'AWS access key'; Pattern = 'AKIA[0-9A-Z]{16}' },
  @{ Name = 'Raw Lark spreadsheet token'; Pattern = 'spreadsheet_token:\s*[A-Za-z0-9]{10,}' }
)

foreach ($relative in $privacyScanFiles) {
  if ($relative -match '(^|/)\.git/|(^|/)\.qianlima/WORKSPACE_INDEX\.md$|(^|/)\.qianlima/workspace-index\.json$|(^|/)\.qianlima/usage-ledger/|(^|/)\.qianlima/logs/') { continue }
  $scanPath = Join-Path $ProjectRoot $relative
  if (-not (Test-Path -LiteralPath $scanPath -PathType Leaf)) { continue }
  $item = Get-Item -LiteralPath $scanPath -Force
  if ($item.Length -gt 1048576) { continue }
  if ($item.Extension -notin @('.md', '.yaml', '.yml', '.ps1', '.json', '.txt', '.gitignore', '.gitattributes')) { continue }
  $content = Get-Content -LiteralPath $scanPath -Encoding UTF8 -Raw -Force
  foreach ($privacyPattern in $privacyPatterns) {
    if ($content -match $privacyPattern.Pattern) {
      Add-Issue "Privacy guard failed ($($privacyPattern.Name)): $relative"
    }
  }
}

if ($issues.Count -gt 0) {
  Write-Host 'Qianlima skeleton validation failed.'
  foreach ($issue in $issues) { Write-Host "- $issue" }
  foreach ($warning in $warnings) { Write-Host "- WARN: $warning" }
  exit 1
}

Write-Host 'Qianlima skeleton validation passed.'
Write-Host "Root: $Root"
Write-Host "Project files checked: $($requiredProjectFiles.Count)"
Write-Host "Public files checked: $($requiredPublicFiles.Count)"
Write-Host "Directories checked: $($requiredDirs.Count)"
foreach ($warning in $warnings) { Write-Host "- WARN: $warning" }
