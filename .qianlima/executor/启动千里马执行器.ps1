# 启动千里马执行器.ps1
# 用户友好入口，检查 Python 环境并启动执行器

$ErrorActionPreference = 'Stop'

$ExecutorDir = $PSScriptRoot
$ExecutorScript = Join-Path $ExecutorDir 'executor.py'

Write-Host "千里马计划 - 任务执行器" -ForegroundColor Cyan
Write-Host "=" * 60

# 检查 Python
$pythonCmd = $null
foreach ($cmd in @('python', 'python3', 'py')) {
  try {
    $version = & $cmd --version 2>&1
    if ($LASTEXITCODE -eq 0) {
      $pythonCmd = $cmd
      Write-Host "✓ 找到 Python: $version" -ForegroundColor Green
      break
    }
  } catch {}
}

if (-not $pythonCmd) {
  Write-Host ""
  Write-Host "❌ 未找到 Python 环境" -ForegroundColor Red
  Write-Host ""
  Write-Host "请先安装 Python 3.11+:" -ForegroundColor Yellow
  Write-Host "  方式 1: 访问 https://www.python.org/downloads/" -ForegroundColor Yellow
  Write-Host "  方式 2: 运行 'winget install Python.Python.3.11'" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "详细说明见: INSTALL.md" -ForegroundColor Yellow
  Write-Host ""
  Read-Host "按回车键退出"
  exit 1
}

# 检查依赖
Write-Host "检查依赖..." -ForegroundColor Cyan
$requirementsFile = Join-Path $ExecutorDir 'requirements.txt'

try {
  $testImport = @"
import sys
try:
    import yaml
    import anthropic
    import jinja2
    sys.exit(0)
except ImportError as e:
    print(f'缺少依赖: {e.name}')
    sys.exit(1)
"@
  $testImport | & $pythonCmd 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ 依赖已安装" -ForegroundColor Green
  } else {
    Write-Host ""
    Write-Host "❌ 缺少依赖包，正在安装..." -ForegroundColor Yellow
    & $pythonCmd -m pip install -r $requirementsFile
    if ($LASTEXITCODE -ne 0) {
      Write-Host ""
      Write-Host "依赖安装失败，请手动运行：" -ForegroundColor Red
      Write-Host "  pip install -r requirements.txt" -ForegroundColor Yellow
      Read-Host "按回车键退出"
      exit 1
    }
    Write-Host "✓ 依赖安装完成" -ForegroundColor Green
  }
} catch {
  Write-Host "⚠️  依赖检查跳过（无法验证）" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "启动执行器..." -ForegroundColor Cyan
Write-Host "=" * 60
Write-Host ""

# 启动执行器
& $pythonCmd $ExecutorScript $args

if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "执行器退出，代码: $LASTEXITCODE" -ForegroundColor Yellow
  Read-Host "按回车键退出"
}

