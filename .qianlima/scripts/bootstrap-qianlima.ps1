# bootstrap-qianlima.ps1 — 生成工作区索引（薄 wrapper）
# 核心逻辑在 qianlima-core.ps1。本脚本可独立运行，也被 start-qianlima.ps1 复用。
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'qianlima-core.ps1')

$QianlimaRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Invoke-QianlimaBootstrap $QianlimaRoot

