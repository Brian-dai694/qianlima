# validate-qianlima.ps1 — 校验工作区骨架（薄 wrapper）
# 核心逻辑在 qianlima-core.ps1。退出码 0 = 通过；1 = 有缺失。
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'qianlima-core.ps1')

$QianlimaRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$missing = Test-QianlimaWorkspace $QianlimaRoot

if ($missing.Count -gt 0) {
  Write-Host '校验未通过，存在以下问题：' -ForegroundColor Red
  foreach ($m in $missing) { Write-Host "  - $m" -ForegroundColor Red }
  exit 1
}

Write-Host "校验通过：$($QianlimaFixedDirs.Count) 个目录、$($QianlimaGovernanceFiles.Count) 个治理文件、索引已生成。" -ForegroundColor Green
exit 0

