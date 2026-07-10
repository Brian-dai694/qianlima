param(
  [switch]$SkipValidation
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$QianlimaRoot = Join-Path $ProjectRoot '.qianlima'
$BootstrapScript = Join-Path $QianlimaRoot 'scripts/bootstrap-qianlima.ps1'
$ValidateScript = Join-Path $QianlimaRoot 'scripts/validate-qianlima.ps1'

if (-not (Test-Path -LiteralPath $BootstrapScript -PathType Leaf)) {
  throw "Missing bootstrap script: $BootstrapScript"
}

Write-Host 'Qianlima startup: generating workspace index...'
& powershell -NoProfile -ExecutionPolicy Bypass -File $BootstrapScript

if (-not $SkipValidation) {
  if (-not (Test-Path -LiteralPath $ValidateScript -PathType Leaf)) {
    throw "Missing validation script: $ValidateScript"
  }

  Write-Host 'Qianlima startup: validating workspace skeleton...'
  & powershell -NoProfile -ExecutionPolicy Bypass -File $ValidateScript
}

Write-Host ''
Write-Host 'Qianlima startup complete.'
Write-Host 'Read for Claude Code: CLAUDE.md'
Write-Host 'Read for Manus: MANUS.md'
Write-Host 'Read for Manus boot: .qianlima/MANUS_BOOT.md'
Write-Host 'Read for Qoder CN: QODER.md'
Write-Host 'Read for Lingma: LINGMA.md'
Write-Host 'Read for LinkAI Cloud: LINKAI.md'
Write-Host 'Read for Obsidian vault: OBSIDIAN.md'
Write-Host 'Read for desktop agents: DESKTOP_AGENT_BRIEF.md'
Write-Host 'Read for evaluation layer: .qianlima/qianlima-eval.yaml'
Write-Host 'Read first: .qianlima/CODEX_BOOT.md'
Write-Host 'Then read: .qianlima/WORKSPACE_INDEX.md'
Write-Host 'Machine index: .qianlima/workspace-index.json'
