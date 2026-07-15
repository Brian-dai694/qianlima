<#
.SYNOPSIS
  Export a Git-safe Obsidian vault from public Qianlima docs.
.DESCRIPTION
  Builds a numbered vault folder tree under OutputRoot, then copies public entry docs,
  agent entrypoints, workflows, task-cards, rules, and templates into it. Validates the
  resolved vault path before writing and refuses unsafe targets. Fails if the vault
  exists unless -Force is given, and writes a Qianlima-Home MOC note.
.PARAMETER OutputRoot
  Directory that will contain the qianlima-git-safe-vault folder.
.PARAMETER Force
  Overwrite an existing vault instead of refusing.
.EXAMPLE
  powershell -NoProfile -File .\export-obsidian-vault.ps1 -Force
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$OutputRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path 'obsidian-export'),
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $Root '..')).Path
$outputFullPath = [System.IO.Path]::GetFullPath($OutputRoot)
$vaultRoot = Join-Path $outputFullPath 'qianlima-git-safe-vault'
$vaultFullPath = [System.IO.Path]::GetFullPath($vaultRoot)
$expectedLeaf = 'qianlima-git-safe-vault'

if ((Split-Path -Leaf $vaultFullPath) -ne $expectedLeaf) {
  throw "Refusing to export: vault path must end with $expectedLeaf."
}

if (-not $vaultFullPath.StartsWith($outputFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing to export: vault path is outside OutputRoot."
}

if ($vaultFullPath.Length -lt 20) {
  throw "Refusing to export: resolved vault path is unexpectedly short."
}

New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null

if ((Test-Path -LiteralPath $vaultRoot) -and (-not $Force)) {
  throw "Vault already exists: $vaultRoot. Re-run with -Force to overwrite."
}

if (Test-Path -LiteralPath $vaultFullPath) {
  Remove-Item -LiteralPath $vaultFullPath -Recurse -Force
}

$dirs = @(
  '00-entry',
  '01-workflows',
  '02-task-cards',
  '03-rules',
  '04-cost-savings',
  '05-risk-confirmation',
  '06-agent-entrypoints',
  '07-report-summaries',
  '08-decision-logs',
  '99-archive'
)

foreach ($dir in $dirs) {
  New-Item -ItemType Directory -Path (Join-Path $vaultFullPath $dir) -Force | Out-Null
}

function Copy-SafeFile {
  param(
    [string]$Source,
    [string]$DestinationDirectory,
    [string]$Name
  )

  if (Test-Path -LiteralPath $Source -PathType Leaf) {
    $destName = if ($Name) { $Name } else { Split-Path -Leaf $Source }
    Copy-Item -LiteralPath $Source -Destination (Join-Path $DestinationDirectory $destName) -Force
  }
}

$entryDir = Join-Path $vaultFullPath '00-entry'
$agentDir = Join-Path $vaultFullPath '06-agent-entrypoints'

Copy-SafeFile -Source (Join-Path $projectRoot 'README.md') -DestinationDirectory $entryDir -Name 'README.md'
Copy-SafeFile -Source (Join-Path $projectRoot 'DESKTOP_AGENT_BRIEF.md') -DestinationDirectory $entryDir -Name 'DESKTOP_AGENT_BRIEF.md'
Copy-SafeFile -Source (Join-Path $projectRoot 'OBSIDIAN.md') -DestinationDirectory $entryDir -Name 'OBSIDIAN.md'
Copy-SafeFile -Source (Join-Path $Root 'README.md') -DestinationDirectory $entryDir -Name 'QIANLIMA_README.md'
Copy-SafeFile -Source (Join-Path $Root 'WORKSPACE_INDEX.md') -DestinationDirectory $entryDir -Name 'WORKSPACE_INDEX.md'

foreach ($name in @('CLAUDE.md', 'MANUS.md', 'QODER.md', 'LINGMA.md', 'LINKAI.md', 'OBSIDIAN.md')) {
  Copy-SafeFile -Source (Join-Path $projectRoot $name) -DestinationDirectory $agentDir -Name $name
}
Copy-SafeFile -Source (Join-Path $Root 'CODEX_BOOT.md') -DestinationDirectory $agentDir -Name 'CODEX_BOOT.md'
Copy-SafeFile -Source (Join-Path $Root 'MANUS_BOOT.md') -DestinationDirectory $agentDir -Name 'MANUS_BOOT.md'

Copy-Item -LiteralPath (Join-Path $Root 'workflows') -Destination (Join-Path $vaultFullPath '01-workflows') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $Root 'task-cards') -Destination (Join-Path $vaultFullPath '02-task-cards') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $Root 'rules') -Destination (Join-Path $vaultFullPath '03-rules') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $Root 'templates') -Destination (Join-Path $vaultFullPath '04-cost-savings') -Recurse -Force

$homeContent = @"
---
qianlima_version: v2.6.6
type: moc
source: git-safe
private_data: false
---

# Qianlima Home

- [[README]]
- [[WORKSPACE_INDEX]]
- [[Workflow Map]]
- [[Task Card Map]]
- [[Cost Savings Map]]
- [[Risk Rules Map]]
- [[Agent Entry Map]]

This vault is public-safe. Do not add private ASINs, tokens, account data, local paths, reports, screenshots, or usage ledgers.
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $entryDir 'Qianlima-Home.md'), $homeContent, $utf8NoBom)

Write-Host "Obsidian Git-safe vault exported: $vaultFullPath"
