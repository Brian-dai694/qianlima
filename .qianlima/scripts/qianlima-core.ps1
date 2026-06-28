# qianlima-core.ps1 — 千里马计划工作区核心逻辑
# 共享常量 + 两个函数，被 bootstrap / validate / start 三个脚本 dot-source 复用。
# 目的：单一数据源（骨架只定义一份）+ 同进程执行（消除多余子进程）。
# 注意：函数内不调用 exit，避免 dot-source 时误杀宿主进程；退出码由各 wrapper 自行处理。

$ErrorActionPreference = 'Stop'

# ── 工作区骨架（唯一定义处） ──
$QianlimaFixedDirs = @(
  'inbox', 'working', 'reports', 'exports', 'archive',
  'logs', 'usage-ledger', 'feedback', 'workflows', 'rules',
  'templates', 'task-cards', 'playbooks'
)

$QianlimaGovernanceFiles = @(
  'work.ws', 'work-hub.ws', 'data-sources.yaml', 'notebooks.yaml',
  'file-registry.yaml', 'naming-rules.yaml', 'risk-rules.yaml',
  'user-preferences.yaml', 'workflow-index.yaml', 'observability.yaml',
  'evaluation-tasks.yaml', 'improvement-loop.yaml'
)

$QianlimaGeneratedFiles = @('WORKSPACE_INDEX.md', 'workspace-index.json')

# 从 YAML 列表项里抽取 id + 同块内首个 name/status。
# 这些文件结构规整，逐块正则提取足够稳健，避免引入 YAML 解析依赖。
function Get-QianlimaListEntries([string]$Text) {
  $entries = @()
  if (-not $Text) { return $entries }
  $current = $null
  foreach ($line in ($Text -split "`r?`n")) {
    if ($line -match '^\s*-\s+id:\s*(.+?)\s*$') {
      if ($current) { $entries += $current }
      $current = [ordered]@{ id = $Matches[1].Trim(); name = ''; status = '' }
    }
    elseif ($current) {
      if ($line -match '^\s+name:\s*(.+?)\s*$'   -and -not $current.name)   { $current.name   = $Matches[1].Trim() }
      elseif ($line -match '^\s+status:\s*(.+?)\s*$' -and -not $current.status) { $current.status = $Matches[1].Trim() }
    }
  }
  if ($current) { $entries += $current }
  return $entries
}

# ── 生成索引：workspace-index.json + WORKSPACE_INDEX.md ──
function Invoke-QianlimaBootstrap([string]$QianlimaRoot) {
  $ProjectRoot = (Resolve-Path (Join-Path $QianlimaRoot '..')).Path

  function Read-FileText([string]$RelPath) {
    $full = Join-Path $QianlimaRoot $RelPath
    if (Test-Path -LiteralPath $full -PathType Leaf) {
      return (Get-Content -LiteralPath $full -Raw -Encoding UTF8)
    }
    return $null
  }

  $scenarios = @(Get-QianlimaListEntries (Read-FileText 'work.ws')             | Where-Object { $_.id })
  $workflows = @(Get-QianlimaListEntries (Read-FileText 'workflow-index.yaml') | Where-Object { $_.id })

  $dirStatus = foreach ($d in $QianlimaFixedDirs) {
    $full = Join-Path $QianlimaRoot $d
    $exists = Test-Path -LiteralPath $full -PathType Container
    $count = 0
    if ($exists) {
      $count = @(Get-ChildItem -LiteralPath $full -File -Force -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -ne '.gitkeep' }).Count
    }
    [ordered]@{ name = $d; present = $exists; files = $count }
  }

  $fileStatus = foreach ($f in $QianlimaGovernanceFiles) {
    [ordered]@{ name = $f; present = (Test-Path -LiteralPath (Join-Path $QianlimaRoot $f) -PathType Leaf) }
  }

  $generated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')

  $index = [ordered]@{
    generated       = $generated
    projectRoot     = $ProjectRoot
    qianlimaRoot    = $QianlimaRoot
    scenarios       = $scenarios
    workflows       = $workflows
    directories     = $dirStatus
    governanceFiles = $fileStatus
  }

  $jsonPath = Join-Path $QianlimaRoot 'workspace-index.json'
  ($index | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $jsonPath -Encoding UTF8

  $md = New-Object System.Text.StringBuilder
  [void]$md.AppendLine('# 千里马计划 · 工作区索引（自动生成）')
  [void]$md.AppendLine('')
  [void]$md.AppendLine("> 生成时间：$generated")
  [void]$md.AppendLine('> 本文件由 bootstrap 自动生成，请勿手工编辑。')
  [void]$md.AppendLine('> Agent 每次执行任务前先读 `work.ws`，再读本索引了解全局。')
  [void]$md.AppendLine('')
  [void]$md.AppendLine('## 场景（来自 work.ws）')
  [void]$md.AppendLine('')
  if ($scenarios.Count -gt 0) {
    [void]$md.AppendLine('| 场景 ID | 名称 | 状态 |')
    [void]$md.AppendLine('|---|---|---|')
    foreach ($s in $scenarios) { [void]$md.AppendLine("| $($s.id) | $($s.name) | $($s.status) |") }
  } else { [void]$md.AppendLine('_未解析到场景。_') }
  [void]$md.AppendLine('')
  [void]$md.AppendLine('## Workflow（来自 workflow-index.yaml）')
  [void]$md.AppendLine('')
  if ($workflows.Count -gt 0) {
    [void]$md.AppendLine('| Workflow ID | 名称 | 状态 |')
    [void]$md.AppendLine('|---|---|---|')
    foreach ($w in $workflows) { [void]$md.AppendLine("| $($w.id) | $($w.name) | $($w.status) |") }
  } else { [void]$md.AppendLine('_未解析到 workflow。_') }
  [void]$md.AppendLine('')
  [void]$md.AppendLine('## 固定目录')
  [void]$md.AppendLine('')
  [void]$md.AppendLine('| 目录 | 存在 | 文件数 |')
  [void]$md.AppendLine('|---|:---:|---:|')
  foreach ($d in $dirStatus) {
    $mark = if ($d.present) { '✅' } else { '❌' }
    [void]$md.AppendLine("| $($d.name)/ | $mark | $($d.files) |")
  }
  [void]$md.AppendLine('')
  [void]$md.AppendLine('## 核心治理文件')
  [void]$md.AppendLine('')
  [void]$md.AppendLine('| 文件 | 存在 |')
  [void]$md.AppendLine('|---|:---:|')
  foreach ($f in $fileStatus) {
    $mark = if ($f.present) { '✅' } else { '❌' }
    [void]$md.AppendLine("| $($f.name) | $mark |")
  }
  [void]$md.AppendLine('')

  $mdPath = Join-Path $QianlimaRoot 'WORKSPACE_INDEX.md'
  $md.ToString() | Set-Content -LiteralPath $mdPath -Encoding UTF8

  Write-Host "  scenarios: $($scenarios.Count)  workflows: $($workflows.Count)"
  Write-Host "  wrote: $jsonPath"
  Write-Host "  wrote: $mdPath"
}

# ── 校验骨架完整性，返回缺失项数组（空数组 = 通过） ──
function Test-QianlimaWorkspace([string]$QianlimaRoot) {
  $missing = @()

  foreach ($d in $QianlimaFixedDirs) {
    if (-not (Test-Path -LiteralPath (Join-Path $QianlimaRoot $d) -PathType Container)) {
      $missing += "目录缺失: $d/"
    }
  }
  foreach ($f in $QianlimaGovernanceFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $QianlimaRoot $f) -PathType Leaf)) {
      $missing += "治理文件缺失: $f"
    }
  }
  foreach ($f in $QianlimaGeneratedFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $QianlimaRoot $f) -PathType Leaf)) {
      $missing += "索引未生成: $f（请先运行 bootstrap）"
    }
  }

  return $missing
}


