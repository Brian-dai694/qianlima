param(
  [Parameter(Mandatory = $true)]
  [string]$WorkflowId,

  [Parameter(Mandatory = $true)]
  [string]$ReportPath,

  [string]$UserGoal = '',
  [string]$TracePath = '',
  [string]$UsagePath = '',
  [double]$EstimatedCostUsd = -1,
  [double]$BaselineCostUsd = -1,
  [double]$CostLimitUsd = -1,
  [string]$RunId = '',
  [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

function Get-ResolvedOrOriginal([string]$PathValue) {
  if ([string]::IsNullOrWhiteSpace($PathValue)) {
    return ''
  }
  try {
    return (Resolve-Path -LiteralPath $PathValue).Path
  } catch {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
}

function Test-AnyPattern([string]$Text, [string[]]$Patterns) {
  foreach ($pattern in $Patterns) {
    if ($Text -match $pattern) {
      return $true
    }
  }
  return $false
}

function Get-Ratio([bool[]]$Checks) {
  if ($Checks.Count -eq 0) {
    return 0.0
  }
  $passed = @($Checks | Where-Object { $_ }).Count
  return [Math]::Round($passed / $Checks.Count, 3)
}

function Format-Status([bool]$Value) {
  if ($Value) { return 'ok' }
  return 'missing'
}

function Test-FileReferencesReport([string]$EvidencePath, [string]$ReportPath) {
  if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) { return $false }
  $reportName = [IO.Path]::GetFileName($ReportPath)
  if ([string]::IsNullOrWhiteSpace($reportName)) { return $false }
  $text = Get-Content -LiteralPath $EvidencePath -Encoding UTF8 -Raw
  return $text -match [regex]::Escape($reportName)
}

function Test-UsageMetering([string]$UsageText) {
  $requiredPatterns = @('(?m)^\s*input_tokens:\s*\d+', '(?m)^\s*output_tokens:\s*\d+', '(?m)^\s*estimated_cost:\s*\d+')
  return @($requiredPatterns | Where-Object { $UsageText -notmatch $_ }).Count -eq 0
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$qianlimaRoot = Join-Path $projectRoot '.qianlima'
$today = Get-Date -Format 'yyyy-MM-dd'

if ([string]::IsNullOrWhiteSpace($RunId)) {
  $RunId = "$WorkflowId-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $outDir = Join-Path $qianlimaRoot 'reports'
  $OutputPath = Join-Path $outDir "eval-$WorkflowId-$today.md"
}

$reportFullPath = Get-ResolvedOrOriginal $ReportPath
$traceFullPath = Get-ResolvedOrOriginal $TracePath
$usageFullPath = Get-ResolvedOrOriginal $UsagePath
$outputFullPath = Get-ResolvedOrOriginal $OutputPath

$reportExists = Test-Path -LiteralPath $reportFullPath -PathType Leaf
$traceExists = (-not [string]::IsNullOrWhiteSpace($TracePath)) -and (Test-Path -LiteralPath $traceFullPath -PathType Leaf)
$usageExists = (-not [string]::IsNullOrWhiteSpace($UsagePath)) -and (Test-Path -LiteralPath $usageFullPath -PathType Leaf)

$content = ''
if ($reportExists) {
  $content = Get-Content -LiteralPath $reportFullPath -Encoding UTF8 -Raw
}
$usageContent = ''
if ($usageExists) {
  $usageContent = Get-Content -LiteralPath $usageFullPath -Encoding UTF8 -Raw
}
$traceReferencesReport = $traceExists -and (Test-FileReferencesReport $traceFullPath $reportFullPath)
$usageReferencesReport = $usageExists -and (Test-FileReferencesReport $usageFullPath $reportFullPath)
$usageHasMetering = $usageExists -and (Test-UsageMetering $usageContent)
$traceEvidenceMismatch = $traceExists -and (-not $traceReferencesReport)
$usageEvidenceMismatch = $usageExists -and (-not $usageReferencesReport)

$hasGoal = (-not [string]::IsNullOrWhiteSpace($UserGoal)) -or (Test-AnyPattern $content @('\u76ee\u6807', '\u4efb\u52a1', '\u9700\u6c42', 'User Goal', 'Goal'))
$hasWorkflow = $content -match [regex]::Escape($WorkflowId)
$hasAssumption = Test-AnyPattern $content @('\u5047\u8bbe', '\u524d\u63d0', '\u5f85\u786e\u8ba4', '\u5f85\u9a8c\u8bc1', 'Assumption', 'Pending')
$hasAnswer = Test-AnyPattern $content @('\u7ed3\u8bba', '\u6458\u8981', '\u5efa\u8bae', '\u4e0b\u4e00\u6b65', '\u884c\u52a8', 'Conclusion', 'Recommendation', 'Next')

$headingCount = ([regex]::Matches($content, '(?m)^#{1,6}\s+')).Count
$hasStructure = $headingCount -ge 3
$hasTableOrList = (Test-AnyPattern $content @('(?m)^\s*-\s+', '(?m)^\|.+\|'))
$hasSource = Test-AnyPattern $content @('\u6765\u6e90', '\u6570\u636e\u6e90', '\u8bc1\u636e', '\u5f15\u7528', 'Source', 'Evidence')
$hasPending = Test-AnyPattern $content @('\u5f85\u9a8c\u8bc1', '\u5f85\u786e\u8ba4', 'pending verification', 'manual confirmation')
$credentialPattern = '(?i)(api[_-]?key|secret|password|cookie|bearer\s+[a-z0-9._-]{12,}|token\s*[:=]\s*[a-z0-9._-]{12,})'
$credentialsDetected = $content -match $credentialPattern

$hasGate = Test-AnyPattern $content @('\u9a8c\u8bc1', '\u6821\u9a8c', 'gate', 'quality', '\u8d28\u91cf')
$hasFailureRecord = Test-AnyPattern $content @('\u5931\u8d25', '\u5f02\u5e38', '\u7f3a\u53e3', '\u98ce\u9669', 'blocked', 'warning', 'error')
$hasToolEvidence = $hasSource -or $traceExists
$hasResumeState = Test-AnyPattern $content @('\u4e0b\u4e00\u6b65', '\u5f85\u529e', 'resume', 'next')

$hasCost = Test-AnyPattern $content @('\u6210\u672c', 'cost', 'token', '\u8282\u7ea6', 'savings')
$underLimit = $true
if ($CostLimitUsd -ge 0 -and $EstimatedCostUsd -ge 0) {
  $underLimit = $EstimatedCostUsd -le $CostLimitUsd
}
$hasSavings = $false
if ($BaselineCostUsd -ge 0 -and $EstimatedCostUsd -ge 0) {
  $hasSavings = $EstimatedCostUsd -le $BaselineCostUsd
}
$hasContextPolicy = Test-AnyPattern $content @('context-policy', '\u4e0a\u4e0b\u6587', '\u538b\u7f29', 'compression')

$highRiskMentioned = Test-AnyPattern $content @('\u8c03\u4ef7', '\u7ade\u4ef7', '\u9884\u7b97', '\u5199\u56de', '\u5220\u9664', '\u53d1\u9001\u5230\u7fa4', 'change_bid', 'change_budget', 'write_back', 'delete')
$hasConfirmation = Test-AnyPattern $content @('\u786e\u8ba4', '\u4e8c\u6b21\u786e\u8ba4', 'manual confirmation', 'approval', 'confirmed')
$writeBackWithoutConfirmation = $highRiskMentioned -and (-not $hasConfirmation)

$intentScore = Get-Ratio @($reportExists, $hasGoal, $hasWorkflow, $hasAssumption, $hasAnswer)
$staticScore = Get-Ratio @($reportExists, $hasStructure, $hasTableOrList, $hasSource, $hasPending, (-not $credentialsDetected))
$dynamicScore = Get-Ratio @($traceExists, $usageExists, $traceReferencesReport, $usageReferencesReport, $hasGate, $hasFailureRecord, $hasToolEvidence, $hasResumeState)
$costScore = Get-Ratio @($hasCost, $usageHasMetering, $underLimit, $hasSavings, $hasContextPolicy)
$riskScore = Get-Ratio @(((-not $highRiskMentioned) -or $hasConfirmation), (-not $writeBackWithoutConfirmation), (-not $credentialsDetected), $hasPending)

$weightedScore = [Math]::Round(
  ($intentScore * 0.25) +
  ($staticScore * 0.25) +
  ($dynamicScore * 0.25) +
  ($costScore * 0.15) +
  ($riskScore * 0.10),
  3
)

$hardBlocks = New-Object System.Collections.Generic.List[string]
if (-not $reportExists) { $hardBlocks.Add('missing_report_artifact') }
if ($credentialsDetected) { $hardBlocks.Add('credentials_detected') }
if ($writeBackWithoutConfirmation) { $hardBlocks.Add('high_risk_action_without_confirmation') }
if ($traceEvidenceMismatch) { $hardBlocks.Add('trace_does_not_reference_report') }
if ($usageEvidenceMismatch) { $hardBlocks.Add('usage_ledger_does_not_reference_report') }

$status = 'pass'
if ($hardBlocks.Count -gt 0) {
  $status = 'blocked'
} elseif ($weightedScore -lt 0.60) {
  $status = 'blocked'
} elseif ($weightedScore -lt 0.80) {
  $status = 'review'
}

$pendingItems = New-Object System.Collections.Generic.List[string]
if (-not $traceExists) { $pendingItems.Add('Trace file missing or not provided.') }
if (-not $usageExists) { $pendingItems.Add('Usage ledger file missing or not provided.') }
if ($usageExists -and (-not $usageHasMetering)) { $pendingItems.Add('Usage ledger has no parseable token or cost metering.') }
if ($traceEvidenceMismatch) { $pendingItems.Add('Trace does not reference the evaluated report.') }
if ($usageEvidenceMismatch) { $pendingItems.Add('Usage ledger does not reference the evaluated report.') }
if (-not $hasSource) { $pendingItems.Add('Source or evidence section is missing.') }
if (-not $hasCost) { $pendingItems.Add('Cost card is missing.') }
if ($pendingItems.Count -eq 0) { $pendingItems.Add('None.') }

$nextItems = New-Object System.Collections.Generic.List[string]
if ($intentScore -lt 0.8) { $nextItems.Add('Restate user goal, assumptions, and the workflow match.') }
if ($staticScore -lt 0.8) { $nextItems.Add('Add source citations, pending verification, and a clearer report structure.') }
if ($dynamicScore -lt 0.8) { $nextItems.Add('Attach trace logs and verification gate results.') }
if ($costScore -lt 0.8) { $nextItems.Add('Add visible cost card and savings versus baseline.') }
if ($riskScore -lt 0.8) { $nextItems.Add('List high-risk actions and confirmation status explicitly.') }
if ($nextItems.Count -eq 0) { $nextItems.Add('Keep as baseline candidate for future private shadow evaluation.') }

$hardBlockText = if ($hardBlocks.Count -gt 0) {
  ($hardBlocks | ForEach-Object { "- $_" }) -join [Environment]::NewLine
} else {
  '- None.'
}

$pendingText = ($pendingItems | ForEach-Object { "- $_" }) -join [Environment]::NewLine
$nextText = ($nextItems | ForEach-Object { "- $_" }) -join [Environment]::NewLine

$costValue = if ($EstimatedCostUsd -ge 0) { ('$' + $EstimatedCostUsd.ToString('0.0000')) } else { 'not provided' }
$costStatus = if ($underLimit) { 'ok' } else { 'over_limit' }

$markdown = @"
# QianlimaEval Report

~~~yaml
workflow_id: $WorkflowId
run_id: $RunId
date: $today
source_inspiration: MiniAppBench / MiniAppEval
evaluation_mode: intent_static_dynamic_cost_risk
status: $status
weighted_score: $weightedScore
~~~

## User Goal

$UserGoal

## Evidence Pack

| Item | Path / Value | Status |
|---|---|---|
| Report | $reportFullPath | $(Format-Status $reportExists) |
| Trace | $traceFullPath | $(Format-Status $traceExists) |
| Usage | $usageFullPath | $(Format-Status $usageExists) |
| Evidence consistency | trace=$traceReferencesReport; usage=$usageReferencesReport | $(Format-Status ((-not $traceEvidenceMismatch) -and (-not $usageEvidenceMismatch))) |
| Cost | $costValue | $costStatus |

## Scores

| Dimension | Weight | Score | Notes |
|---|---:|---:|---|
| Intent Alignment | 0.25 | $intentScore | goal=$hasGoal; assumptions=$hasAssumption; answer=$hasAnswer |
| Evidence / Static Quality | 0.25 | $staticScore | headings=$headingCount; source=$hasSource; credentials_detected=$credentialsDetected |
| Dynamic Execution Quality | 0.25 | $dynamicScore | trace=$traceExists; usage=$usageExists; trace_refs_report=$traceReferencesReport; usage_refs_report=$usageReferencesReport; gate=$hasGate; resume=$hasResumeState |
| Cost Savings / Efficiency | 0.15 | $costScore | cost_card=$hasCost; metering=$usageHasMetering; under_limit=$underLimit; savings=$hasSavings |
| Risk Control | 0.10 | $riskScore | high_risk=$highRiskMentioned; confirmation=$hasConfirmation |

## Hard Blocks

$hardBlockText

## Pending Verification

$pendingText

## Next Optimization

$nextText
"@

$outputDir = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outputFullPath, $markdown, $utf8NoBom)

Write-Host "QianlimaEval report generated: $outputFullPath"
Write-Host "Status: $status"
Write-Host "Weighted score: $weightedScore"
