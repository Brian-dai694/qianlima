param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Get-FirstHeading([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return ''
  }
  $line = Get-Content -LiteralPath $Path -Encoding UTF8 -TotalCount 20 | Where-Object { $_ -match '^#\s+' } | Select-Object -First 1
  if ($line) {
    return ($line -replace '^#\s+', '').Trim()
  }
  return ''
}

$ProjectRoot = (Resolve-Path (Join-Path $Root '..')).Path
$generatedAt = (Get-Date).ToString('o')

$requiredStartupFiles = @(
  'README.md',
  'work.ws',
  'workflow-index.yaml',
  'risk-rules.yaml',
  'context-policy.yaml',
  'communication-protocol.yaml',
  'model-adapters.yaml'
)

$startup = foreach ($file in $requiredStartupFiles) {
  $path = Join-Path $Root $file
  [PSCustomObject]@{
    path = ".qianlima/$file"
    exists = (Test-Path -LiteralPath $path -PathType Leaf)
    heading = Get-FirstHeading $path
  }
}

function Get-IndexedFiles([string]$Dir, [string]$Filter, [string]$Prefix) {
  if (-not (Test-Path -LiteralPath $Dir -PathType Container)) {
    return @()
  }
  return @(Get-ChildItem -LiteralPath $Dir -File -Filter $Filter | Sort-Object Name | ForEach-Object {
    [PSCustomObject]@{
      file = "$Prefix/$($_.Name)"
      name = $_.BaseName
      size_bytes = $_.Length
    }
  })
}

$taskCards = Get-IndexedFiles (Join-Path $Root 'task-cards') '*.yaml' '.qianlima/task-cards'
$workflows = Get-IndexedFiles (Join-Path $Root 'workflows') '*.yaml' '.qianlima/workflows'
$templates = Get-IndexedFiles (Join-Path $Root 'templates') '*' '.qianlima/templates'
$playbooks = Get-IndexedFiles (Join-Path $Root 'playbooks') '*.yaml' '.qianlima/playbooks'
$docs = Get-IndexedFiles (Join-Path $ProjectRoot 'docs') '*.md' 'docs'
$rootDocs = Get-ChildItem -LiteralPath $ProjectRoot -File -Filter '*.md' | Sort-Object Name | ForEach-Object {
  [PSCustomObject]@{
    file = $_.Name
    name = $_.BaseName
    size_bytes = $_.Length
  }
}

$governanceFiles = @(
  'work.ws',
  'work-hub.ws',
  'workflow-index.yaml',
  'data-sources.yaml',
  'file-registry.yaml',
  'naming-rules.yaml',
  'risk-rules.yaml',
  'user-preferences.yaml',
  'context-policy.yaml',
  'communication-protocol.yaml',
  'model-adapters.yaml',
  'observability.yaml',
  'evaluation-tasks.yaml',
  'improvement-loop.yaml'
) | ForEach-Object {
  $path = Join-Path $Root $_
  [PSCustomObject]@{
    file = ".qianlima/$_"
    exists = (Test-Path -LiteralPath $path -PathType Leaf)
    size_bytes = if (Test-Path -LiteralPath $path -PathType Leaf) { (Get-Item -LiteralPath $path).Length } else { 0 }
  }
}

$indexObject = [PSCustomObject]@{
  generated_at = $generatedAt
  project_root = '.'
  qianlima_root = '.qianlima'
  startup_files = $startup
  governance_files = $governanceFiles
  task_cards = $taskCards
  workflows = $workflows
  templates = $templates
  playbooks = $playbooks
  docs = $docs
  root_docs = $rootDocs
  startup_instruction = 'Read .qianlima/WORKSPACE_INDEX.md first, then follow startup_files in order.'
}

$jsonPath = Join-Path $Root 'workspace-index.json'
$indexObject | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$mdPath = Join-Path $Root 'WORKSPACE_INDEX.md'
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Qianlima Workspace Index')
$lines.Add('')
$lines.Add("Generated at: $generatedAt")
$lines.Add('')
$lines.Add('## Startup Order')
$lines.Add('')
$lines.Add('A model opening this workspace must generate this index first, read this file, then read the startup files below in order.')
$lines.Add('')
$lines.Add('Recommended command from project root:')
$lines.Add('')
$lines.Add('```powershell')
$lines.Add('powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"')
$lines.Add('```')
$lines.Add('')
foreach ($item in $startup) {
  $status = if ($item.exists) { 'OK' } else { 'MISSING' }
  $lines.Add("- [$status] $($item.path)")
}
$lines.Add('')
$lines.Add('## Required Rules')
$lines.Add('')
$lines.Add('- Do not read the whole workspace at once.')
$lines.Add('- Load files by task-card and workflow.')
$lines.Add('- Compress long files and multi-file tasks using context-policy.yaml.')
$lines.Add('- Use communication-protocol.yaml for cross-file, cross-project, model-handoff, and event references.')
$lines.Add('- Reload source sections before high-risk decisions.')
$lines.Add('- Use model-adapters.yaml for DeepSeek, OpenAI, Anthropic, Google, and local models.')
$lines.Add('')
$lines.Add('## Task Cards')
$lines.Add('')
foreach ($item in $taskCards) {
  $lines.Add("- $($item.name): $($item.file)")
}
$lines.Add('')
$lines.Add('## Root Documents')
$lines.Add('')
foreach ($item in $rootDocs) {
  $lines.Add("- $($item.name): $($item.file)")
}
$lines.Add('')
$lines.Add('## Docs')
$lines.Add('')
foreach ($item in $docs) {
  $lines.Add("- $($item.name): $($item.file)")
}
$lines.Add('')
$lines.Add('## Workflows')
$lines.Add('')
foreach ($item in $workflows) {
  $lines.Add("- $($item.name): $($item.file)")
}
$lines.Add('')
$lines.Add('## Templates')
$lines.Add('')
foreach ($item in $templates) {
  $lines.Add("- $($item.name): $($item.file)")
}
$lines.Add('')
$lines.Add('## Playbooks')
$lines.Add('')
foreach ($item in $playbooks) {
  $lines.Add("- $($item.name): $($item.file)")
}
$lines.Add('')
$lines.Add('## Machine Index')
$lines.Add('')
$lines.Add('The machine-readable version is .qianlima/workspace-index.json.')

Set-Content -LiteralPath $mdPath -Value $lines -Encoding UTF8

$logDir = Join-Path $Root 'logs'
if (Test-Path -LiteralPath $logDir -PathType Container) {
  $logPath = Join-Path $logDir 'bootstrap-qianlima-latest.json'
  [PSCustomObject]@{
    generated_at = $generatedAt
    workspace_index = '.qianlima/WORKSPACE_INDEX.md'
    machine_index = '.qianlima/workspace-index.json'
    startup_file_count = $startup.Count
    task_card_count = $taskCards.Count
    workflow_count = $workflows.Count
    template_count = $templates.Count
    playbook_count = $playbooks.Count
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $logPath -Encoding UTF8
}

Write-Host "Workspace index generated: $mdPath"
Write-Host "Machine index generated: $jsonPath"
