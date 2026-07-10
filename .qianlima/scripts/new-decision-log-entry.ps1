param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$RunId = "$(Get-Date -Format 'yyyy-MM-dd')_manual_001",
  [string]$DecisionId = "decision-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
  [string]$Scenario = 'replace_me',
  [string]$WorkflowId = 'replace_me',
  [string]$ActionType = 'replace_me',
  [ValidateSet('low', 'medium', 'high', 'critical')]
  [string]$RiskLevel = 'medium',
  [string]$Recommendation = 'replace_me',
  [string]$ExpectedImpact = 'replace_me',
  [string]$ExpectedRisks = 'replace_me',
  [string[]]$SourceRefs = @('replace_me'),
  [string]$UserConfirmationRef = '',
  [string]$VerificationGateId = 'replace_me',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$highRiskActions = @('change_bid', 'change_budget', 'change_price', 'purchase_order', 'update_listing', 'write_back', 'delete_data', 'send_to_group')
if (($ActionType -in $highRiskActions) -and [string]::IsNullOrWhiteSpace($UserConfirmationRef)) {
  throw "High-risk action requires -UserConfirmationRef before a decision log can be created: $ActionType"
}

$logsDir = Join-Path $Root 'logs'
if (-not (Test-Path -LiteralPath $logsDir -PathType Container)) {
  New-Item -ItemType Directory -Path $logsDir | Out-Null
}

$safeRunId = $RunId -replace '[^A-Za-z0-9_.-]', '-'
$safeDecisionId = $DecisionId -replace '[^A-Za-z0-9_.-]', '-'
$path = Join-Path $logsDir "$($safeRunId)_decision-log.yaml"
if ((Test-Path -LiteralPath $path -PathType Leaf) -and (-not $Force)) {
  throw "Decision log already exists: $path. Re-run with -Force to overwrite."
}

$createdAt = (Get-Date).ToString('o')
$sourceYaml = ($SourceRefs | ForEach-Object { "        - $_" }) -join "`n"
if ([string]::IsNullOrWhiteSpace($sourceYaml)) { $sourceYaml = '        - replace_me' }
$confirmation = if ([string]::IsNullOrWhiteSpace($UserConfirmationRef)) { 'null' } else { $UserConfirmationRef }

$content = @"
decision_log_entry:
  decision_id: $safeDecisionId
  run_id: $safeRunId
  created_at: "$createdAt"
  scenario: $Scenario
  workflow_id: $WorkflowId
  action_type: $ActionType
  risk_level: $RiskLevel
  status: proposed
  actor:
    agent_role: execution_agent
    user_confirmation_ref: $confirmation
  evidence:
    source_refs:
$sourceYaml
    data_window: pending
    key_metrics_before: null
    source_quality_notes: pending
  decision:
    recommendation: $Recommendation
    expected_impact: $ExpectedImpact
    expected_risks: $ExpectedRisks
    rollback_or_stop_condition: pending
  execution:
    tool_name: null
    target_system: null
    target_ref: null
    requested_change: null
    raw_output_ref: null
    summary_ref: null
  verification:
    required: true
    gate_id: $VerificationGateId
    verification_window: pending
    expected_evidence:
      - source_reload
      - readback_or_user_confirmation
    actual_result: pending
    verified_at: null
    verification_ref: null
  outcome:
    final_status: pending
    user_visible_summary: pending
    follow_up_required: true
    loop_learning_ref: null
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
Write-Host "Decision log created: $path"