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
  'communication-protocol.yaml',
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

foreach ($dir in $requiredDirs) {
  $path = Join-Path $Root $dir
  if (-not (Test-Path -LiteralPath $path -PathType Container)) {
    $issues.Add("Missing directory: $dir")
  }
}

foreach ($file in $requiredProjectFiles) {
  $path = Join-Path $ProjectRoot $file
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    $issues.Add("Missing project file: $file")
  }
}

foreach ($file in $requiredFiles) {
  $path = Join-Path $Root $file
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    $issues.Add("Missing file: $file")
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
      $issues.Add("Sample CSV missing required field: $header")
    }
  }
} else {
  $issues.Add('Missing sample CSV')
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
