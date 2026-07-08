param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $Root '..')).Path

$requiredProjectFiles = @(
  'README.md',
  'AGENTS.md',
  'AI_START_HERE.md',
  'start-qianlima.ps1'
)

$requiredFiles = @(
  'work.ws',
  'work-hub.ws',
  'file-registry.yaml',
  'data-sources.yaml',
  'naming-rules.yaml',
  'workflow-index.yaml',
  'user-preferences.yaml',
  'risk-rules.yaml',
  'model-adapters.yaml',
  'context-policy.yaml',
  'WORKSPACE_INDEX.md',
  'workspace-index.json',
  'rules/work-governance-rules.yaml',
  'workflows/daily_ad_report.yaml',
  'playbooks/context-compression-playbook.yaml',
  'scripts/bootstrap-qianlima.ps1',
  'templates/ad-ops_daily-report_template.md'
)

$requiredDirs = @(
  'inbox',
  'working',
  'reports',
  'templates',
  'archive',
  'logs',
  'usage-ledger',
  'context-summaries',
  'feedback',
  'workflows',
  'rules',
  'scripts',
  'playbooks'
)

$issues = New-Object System.Collections.Generic.List[string]

function Add-Issue([string]$Message) {
  $script:issues.Add($Message)
}

function Get-YamlListItemsAfterKey([string[]]$Lines, [string]$KeyPattern) {
  $items = New-Object System.Collections.Generic.List[string]
  $inBlock = $false
  foreach ($line in $Lines) {
    if ($line -match $KeyPattern) {
      $inBlock = $true
      continue
    }
    if ($inBlock -and $line -match '^\s*-\s*(\S+)') {
      $items.Add($Matches[1].Trim('"'))
      continue
    }
    if ($inBlock -and $line -match '^\s*[A-Za-z_]+:') {
      $inBlock = $false
    }
  }
  return @($items)
}

foreach ($dir in $requiredDirs) {
  $path = Join-Path $Root $dir
  if (-not (Test-Path -LiteralPath $path -PathType Container)) {
    Add-Issue "Missing directory: $dir"
  }
}

foreach ($file in $requiredProjectFiles) {
  $path = Join-Path $ProjectRoot $file
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Issue "Missing project file: $file"
  }
}

foreach ($file in $requiredFiles) {
  $path = Join-Path $Root $file
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Issue "Missing file: $file"
  }
}

$sampleCsv = Join-Path $Root 'inbox/2026-06-23_ad-data_raw_US_V1.csv'
if (Test-Path -LiteralPath $sampleCsv -PathType Leaf) {
  $rows = Import-Csv -LiteralPath $sampleCsv
  $headers = @()
  if ($rows.Count -gt 0) {
    $headers = $rows[0].PSObject.Properties.Name
  }
  $requiredHeaders = @('date', 'campaign_name', 'ad_group_name', 'spend', 'sales', 'orders', 'clicks', 'impressions')
  foreach ($header in $requiredHeaders) {
    if ($header -notin $headers) {
      Add-Issue "Sample CSV missing required field: $header"
    }
  }
} else {
  Add-Issue 'Missing sample CSV'
}

$workflowIndexPath = Join-Path $Root 'workflow-index.yaml'
if (Test-Path -LiteralPath $workflowIndexPath -PathType Leaf) {
  $workflowLines = Get-Content -LiteralPath $workflowIndexPath -Encoding UTF8
  $workflowIds = @($workflowLines | ForEach-Object {
    if ($_ -match '^\s*-\s*id:\s*(\S+)') { $Matches[1].Trim('"') }
  })

  $pathRefs = New-Object System.Collections.Generic.List[string]
  foreach ($line in $workflowLines) {
    if ($line -match '^\s*(definition|template|task_card):\s*(.+?)\s*$') {
      $pathRefs.Add($Matches[2].Trim('"'))
    }
    if ($line -match '^\s*-\s*(rules/.+?)\s*$') {
      $pathRefs.Add($Matches[1].Trim('"'))
    }
  }
  foreach ($ref in ($pathRefs | Sort-Object -Unique)) {
    $refPath = Join-Path $Root $ref
    if (-not (Test-Path -LiteralPath $refPath -PathType Leaf)) {
      Add-Issue "Workflow index references missing file: $ref"
    }
  }

  $dataSourcesPath = Join-Path $Root 'data-sources.yaml'
  if (Test-Path -LiteralPath $dataSourcesPath -PathType Leaf) {
    $dataSourceLines = Get-Content -LiteralPath $dataSourcesPath -Encoding UTF8
    $registeredSources = @($dataSourceLines | ForEach-Object {
      if ($_ -match '^\s*-\s*source_id:\s*(\S+)') { $Matches[1].Trim('"') }
    })
    $requiredSources = Get-YamlListItemsAfterKey $workflowLines '^\s*required_data_sources:\s*$'
    foreach ($source in ($requiredSources | Sort-Object -Unique)) {
      if ($source -notin $registeredSources) {
        Add-Issue "Workflow index requires unregistered data source: $source"
      }
    }
  }

  $workPath = Join-Path $Root 'work.ws'
  if (Test-Path -LiteralPath $workPath -PathType Leaf) {
    $workLines = Get-Content -LiteralPath $workPath -Encoding UTF8
    $declaredWorkflows = New-Object System.Collections.Generic.List[string]
    $declaredSources = New-Object System.Collections.Generic.List[string]
    foreach ($line in $workLines) {
      if ($line -match 'workflows:\s*\[(.*?)\]') {
        foreach ($item in $Matches[1].Split(',')) { $declaredWorkflows.Add($item.Trim()) }
      }
      if ($line -match 'data_sources:\s*\[(.*?)\]') {
        foreach ($item in $Matches[1].Split(',')) { $declaredSources.Add($item.Trim()) }
      }
    }
    foreach ($workflow in ($declaredWorkflows | Sort-Object -Unique)) {
      if ($workflow -and $workflow -notin $workflowIds) {
        Add-Issue "work.ws declares workflow not in workflow-index.yaml: $workflow"
      }
    }
    if (Test-Path -LiteralPath $dataSourcesPath -PathType Leaf) {
      $dataSourceLines = Get-Content -LiteralPath $dataSourcesPath -Encoding UTF8
      $registeredSources = @($dataSourceLines | ForEach-Object {
        if ($_ -match '^\s*-\s*source_id:\s*(\S+)') { $Matches[1].Trim('"') }
      })
      foreach ($source in ($declaredSources | Sort-Object -Unique)) {
        if ($source -and $source -notin $registeredSources) {
          Add-Issue "work.ws declares data source not in data-sources.yaml: $source"
        }
      }
    }
  }
}

$privacyScanFiles = @()
try {
  $privacyScanFiles = @(git -C $ProjectRoot -c core.quotePath=false ls-files -- .gitignore .qianlima 2>$null)
} catch {
  $privacyScanFiles = @()
}

if ($privacyScanFiles.Count -eq 0) {
  $privacyScanFiles = @(
    '.gitignore',
    '.qianlima/file-registry.yaml',
    '.qianlima/workflow-index.yaml',
    '.qianlima/rules/amazon-listing-title-subtitle-2026.md'
  )
}

$privacyPatterns = @(
  @{ Name = 'Windows user path'; Pattern = '([A-Za-z]:[\\/](Users|用户)[\\/]|C:[\\/]Users[\\/])' },
  @{ Name = 'WeChat cache id'; Pattern = ('wxid' + '_[A-Za-z0-9_]+') },
  @{ Name = 'Known local person name'; Pattern = ([string]([char]0x6234) + [string]([char]0x6668) + [string]([char]0x6C11)) },
  @{ Name = 'Raw Lark spreadsheet token'; Pattern = 'spreadsheet_token:\s*[A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9]' }
)

foreach ($relative in $privacyScanFiles) {
  $scanPath = Join-Path $ProjectRoot $relative
  if (-not (Test-Path -LiteralPath $scanPath -PathType Leaf)) {
    continue
  }
  $content = Get-Content -LiteralPath $scanPath -Encoding UTF8 -Raw
  foreach ($privacyPattern in $privacyPatterns) {
    if ($content -match $privacyPattern.Pattern) {
      Add-Issue "Privacy guard failed ($($privacyPattern.Name)): $relative"
    }
  }
}

if ($issues.Count -gt 0) {
  Write-Host 'Qianlima skeleton validation failed.'
  foreach ($issue in $issues) {
    Write-Host "- $issue"
  }
  exit 1
}

Write-Host 'Qianlima skeleton validation passed.'
Write-Host "Root: $Root"
Write-Host "Project files checked: $($requiredProjectFiles.Count)"
Write-Host "Files checked: $($requiredFiles.Count)"
Write-Host "Directories checked: $($requiredDirs.Count)"
