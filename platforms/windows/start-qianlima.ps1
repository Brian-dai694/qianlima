param(
  [switch]$SkipValidation
)

$ErrorActionPreference = 'Stop'

$ProjectRoot  = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$QianlimaRoot = Join-Path $ProjectRoot '.qianlima'
$CoreScript   = Join-Path $QianlimaRoot 'scripts/qianlima-core.ps1'

if (-not (Test-Path -LiteralPath $CoreScript -PathType Leaf)) {
  throw "Missing core script: $CoreScript"
}

# 同进程加载核心逻辑，避免为每一步另开 powershell 子进程。
. $CoreScript

Write-Host 'Qianlima startup: generating workspace index...'
Invoke-QianlimaBootstrap $QianlimaRoot

if (-not $SkipValidation) {
  Write-Host 'Qianlima startup: validating workspace skeleton...'
  $missing = Test-QianlimaWorkspace $QianlimaRoot
  if ($missing.Count -gt 0) {
    Write-Host '校验未通过，存在以下问题：' -ForegroundColor Red
    foreach ($m in $missing) { Write-Host "  - $m" -ForegroundColor Red }
    throw 'Workspace validation failed.'
  }
  Write-Host "校验通过：$($QianlimaFixedDirs.Count) 个目录、$($QianlimaGovernanceFiles.Count) 个治理文件、索引已生成。" -ForegroundColor Green
}

Write-Host ''
Write-Host 'Qianlima startup complete.'
Write-Host 'Read first: .qianlima/WORKSPACE_INDEX.md'
Write-Host 'Machine index: .qianlima/workspace-index.json'

