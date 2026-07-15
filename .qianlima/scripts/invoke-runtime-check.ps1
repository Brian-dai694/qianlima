<#
.SYNOPSIS
  Runtime safety gate for Qianlima workflow phases.
.DESCRIPTION
  Enforces runtime policy at each lifecycle phase. Blocks high-risk actions
  (e.g. change_bid, change_budget) unless -Confirmed is passed, validates source
  citation, and checks usage-ledger / decision-log requirements. Exits non-zero
  when a gate fails; CI relies on this to assert unconfirmed high-risk actions
  are blocked.
.PARAMETER Phase
  Lifecycle phase: SessionStart | BeforeToolUse | AfterToolUse | FinalCheck.
.PARAMETER Action
  The action about to run (e.g. change_bid); high-risk actions require -Confirmed.
.PARAMETER Confirmed
  Marks a high-risk action as explicitly user-confirmed, allowing it to pass.
.PARAMETER WorkflowId
  Workflow being executed, used for policy lookup.
.EXAMPLE
  ...invoke-runtime-check.ps1 -Phase BeforeToolUse -Action change_bid -Confirmed
#>
param(
  [ValidateSet('SessionStart', 'BeforeToolUse', 'AfterToolUse', 'FinalCheck')]
  [string]$Phase,
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$WorkflowId = '',
  [string]$Action = '',
  [string]$OutputPath = '',
  [string]$RunId = '',
  [string]$UsageLedgerPath = '',
  [string]$DecisionLogPath = '',
  [switch]$AllowUnmeteredUsage,
  [switch]$Confirmed
)

$ErrorActionPreference = 'Stop'

$Issues = New-Object System.Collections.Generic.List[string]
function Add-Issue([string]$Message) { $Issues.Add($Message) }
function Test-Leaf([string]$RelativePath) { Test-Path -LiteralPath (Join-Path $Root $RelativePath) -PathType Leaf }
function Resolve-QianlimaPath([string]$PathValue) {
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return '' }
  if ([IO.Path]::IsPathRooted($PathValue)) { return $PathValue }
  $normalized = $PathValue -replace '/', '\'
  if ($normalized -match '^\.qianlima\\(.+)$') {
    return Join-Path $Root $Matches[1]
  }
  return Join-Path $Root $PathValue
}
function Test-SourceCitation([string]$PathValue) {
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return $true }
  $fullPath = Resolve-QianlimaPath $PathValue
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { return $false }
  $text = Get-Content -LiteralPath $fullPath -Encoding UTF8 -Raw
  return ($text -match '(?i)(source|sources|source_refs|data_sources_used|数据来源|来源|引用)')
}
function Find-UsageLedgerByRunId([string]$RunIdValue) {
  if ([string]::IsNullOrWhiteSpace($RunIdValue)) { return '' }
  $ledgerDir = Join-Path $Root 'usage-ledger'
  if (-not (Test-Path -LiteralPath $ledgerDir -PathType Container)) { return '' }
  $match = Get-ChildItem -LiteralPath $ledgerDir -File -Filter "*$RunIdValue*.yaml" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($match) { return $match.FullName }
  return ''
}
function Test-UsageLedger([string]$PathValue) {
  $text = Get-Content -LiteralPath $PathValue -Encoding UTF8 -Raw
  $required = @('run_id:', 'workflow_id:', 'input_tokens:', 'output_tokens:', 'estimated_cost:', 'cost_status:', 'continue_or_stop:')
  $missing = @($required | Where-Object { $text -notmatch [regex]::Escape($_) })
  $zeroUsage = ($text -match '(?m)^\s*model_provider:\s*unknown\s*$') -and
    ($text -match '(?m)^\s*input_tokens:\s*0\s*$') -and
    ($text -match '(?m)^\s*output_tokens:\s*0\s*$') -and
    ($text -match '(?m)^\s*estimated_cost:\s*0(?:\.0+)?\s*$')
  [PSCustomObject]@{
    Valid = ($missing.Count -eq 0)
    Missing = $missing
    Unmetered = $zeroUsage
  }
}

switch ($Phase) {
  'SessionStart' {
    foreach ($file in @('WORKSPACE_INDEX.md', 'workflow-index.yaml', 'risk-rules.yaml', 'context-policy.yaml')) {
      if (-not (Test-Leaf $file)) { Add-Issue "SessionStart missing required file: $file" }
    }
    if ((-not (Test-Leaf 'work.ws')) -and (-not (Test-Leaf 'work.example.ws'))) {
      Add-Issue 'SessionStart requires work.ws or public-safe work.example.ws'
    }
    if ($WorkflowId) {
      $workflowIndex = Join-Path $Root 'workflow-index.yaml'
      if ((Test-Path -LiteralPath $workflowIndex -PathType Leaf) -and ((Get-Content -LiteralPath $workflowIndex -Encoding UTF8 -Raw) -notmatch "(?m)^\s*-\s*id:\s*$([regex]::Escape($WorkflowId))\s*$")) {
        Add-Issue "WorkflowId not registered in workflow-index.yaml: $WorkflowId"
      }
    }
  }
  'BeforeToolUse' {
    $riskRules = Join-Path $Root 'risk-rules.yaml'
    if (-not (Test-Path -LiteralPath $riskRules -PathType Leaf)) { Add-Issue 'Missing risk-rules.yaml' }
    $highRisk = @('change_bid', 'change_budget', 'delete_data', 'send_to_group', 'write_back', 'change_price', 'purchase_order', 'update_listing')
    if ($Action -and ($Action -in $highRisk) -and (-not $Confirmed)) {
      Add-Issue "High-risk action requires explicit confirmation: $Action"
    }
  }
  'AfterToolUse' {
    if ($OutputPath) {
      $fullPath = Resolve-QianlimaPath $OutputPath
      if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { Add-Issue "Tool output ref does not exist: $OutputPath" }
    }
  }
  'FinalCheck' {
    if (-not (Test-Leaf 'templates/token-usage-record_template.yaml')) { Add-Issue 'Missing usage ledger template.' }
    if ($OutputPath) {
      $fullPath = Resolve-QianlimaPath $OutputPath
      if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { Add-Issue "Final output does not exist: $OutputPath" }
      elseif (-not (Test-SourceCitation $OutputPath)) { Add-Issue "Final output is missing a source citation marker: $OutputPath" }
    }

    $ledgerFullPath = Resolve-QianlimaPath $UsageLedgerPath
    if ([string]::IsNullOrWhiteSpace($ledgerFullPath)) { $ledgerFullPath = Find-UsageLedgerByRunId $RunId }
    if ([string]::IsNullOrWhiteSpace($ledgerFullPath)) {
      Add-Issue 'Usage ledger is required for FinalCheck. Pass -UsageLedgerPath or -RunId.'
    } elseif (-not (Test-Path -LiteralPath $ledgerFullPath -PathType Leaf)) {
      Add-Issue "Usage ledger does not exist: $UsageLedgerPath"
    } else {
      $ledgerCheck = Test-UsageLedger $ledgerFullPath
      if (-not $ledgerCheck.Valid) { Add-Issue "Usage ledger is missing required fields: $($ledgerCheck.Missing -join ', ')" }
      if ($ledgerCheck.Unmetered -and (-not $AllowUnmeteredUsage)) { Add-Issue 'Usage ledger has zero or unknown metering. Add measured usage or explicitly pass -AllowUnmeteredUsage.' }
    }

    if ($Action -and ($Action -in @('change_bid', 'change_budget', 'delete_data', 'send_to_group', 'write_back', 'change_price', 'purchase_order', 'update_listing'))) {
      $decisionFullPath = Resolve-QianlimaPath $DecisionLogPath
      if ([string]::IsNullOrWhiteSpace($decisionFullPath)) { Add-Issue 'Decision log is required for high-risk FinalCheck. Pass -DecisionLogPath.' }
      elseif (-not (Test-Path -LiteralPath $decisionFullPath -PathType Leaf)) { Add-Issue "Decision log does not exist: $DecisionLogPath" }
    }
  }
}

if ($Issues.Count -eq 0) {
  Write-Host "Runtime check passed: $Phase"
} else {
  Write-Host "Runtime check failed: $Phase"
  foreach ($issue in $Issues) { Write-Host "- $issue" }
  exit 1
}
