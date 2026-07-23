<##
.SYNOPSIS
  Runs the personal edition local, read-only ad operations loop.
.DESCRIPTION
  Reads a local CSV export, computes deterministic metrics, creates evidence-
  backed action candidates, and optionally compares a later readback export.
  It never changes bids, budgets, campaigns, listings, or external systems.
##>
param(
  [Parameter(Mandatory = $true)] [string]$CsvPath,
  [Parameter(Mandatory = $true)] [string]$Date,
  [Parameter(Mandatory = $true)] [string]$Marketplace,
  [double]$TargetAcos = 0.30,
  [string]$EndDate = '',
  [string]$ReadbackCsvPath = '',
  [string]$TaskId = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$contractPath = Join-Path $projectRoot '.qianlima\specifications\personal-ad-ops-loop-contract.json'
$actionContractPath = Join-Path $projectRoot '.qianlima\specifications\personal-ad-action-card-contract.json'
$outputRoot = Join-Path $projectRoot '.qianlima\working\personal-ad-ops'
$contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
$actionContract = Get-Content -LiteralPath $actionContractPath -Raw -Encoding UTF8 | ConvertFrom-Json
try {
  $startDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
  $endDateValue = if ([string]::IsNullOrWhiteSpace($EndDate)) { $startDate } else { [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) }
} catch { throw 'Date and EndDate must use yyyy-MM-dd.' }
if ($endDateValue -lt $startDate) { throw 'EndDate cannot be earlier than Date.' }
$timeRange = if ($endDateValue -eq $startDate) { $Date } else { "$Date..$EndDate" }
if ([string]::IsNullOrWhiteSpace($TaskId)) { $TaskId = "personal-ad-ops-$Date-$Marketplace-$((Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmssfff'))" }

function Get-Number([object]$Value, [string]$Field) {
  $text = [string]$Value
  if ([string]::IsNullOrWhiteSpace($text)) { throw "Missing numeric value: $Field" }
  $parsed = 0.0
  if (-not [double]::TryParse($text, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) { throw "Invalid numeric value: $Field" }
  return $parsed
}
function Get-OptionalNumber([object]$Value, [string]$Field) {
  if ([string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
  return Get-Number $Value $Field
}
function Safe-Divide([double]$Numerator, [double]$Denominator) { if ($Denominator -eq 0) { return $null }; return $Numerator / $Denominator }
function Format-Percent($Value) { if ($null -eq $Value) { return 'N/A' }; return (($Value * 100).ToString('0.00') + '%') }
function Format-Money([double]$Value) { return ('$' + $Value.ToString('0.00')) }
function Get-LoopData([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "CSV file not found: $Path" }
  $rows = @(Import-Csv -LiteralPath $Path)
  $headers = if ($rows.Count -gt 0) { @($rows[0].PSObject.Properties.Name) } else { @() }
  foreach ($field in $contract.input.required_fields) { if ($headers -notcontains $field) { throw "CSV missing required field: $field" } }
  $selected = @(
    foreach ($row in $rows) {
      try { $rowDate = [datetime]::ParseExact([string]$row.date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) } catch { continue }
      if ($rowDate -ge $startDate -and $rowDate -le $endDateValue -and [string]$row.marketplace -eq $Marketplace) { $row }
    }
  )
  if ($selected.Count -eq 0) { throw "No rows found for $timeRange / $Marketplace in $Label." }
  $records = @(
    foreach ($row in $selected) {
      if ([string]::IsNullOrWhiteSpace([string]$row.campaign_name)) { throw 'CSV campaign_name cannot be empty.' }
      if ([string]::IsNullOrWhiteSpace([string]$row.search_term)) { throw 'CSV search_term cannot be empty.' }
      [PSCustomObject]@{
        campaign = [string]$row.campaign_name
        ad_group = [string]$row.ad_group_name
        search_term = [string]$row.search_term
        impressions = Get-Number $row.impressions 'impressions'
        clicks = Get-Number $row.clicks 'clicks'
        spend = Get-Number $row.spend 'spend'
        sales = Get-Number $row.sales 'sales'
        orders = Get-Number $row.orders 'orders'
        budget = Get-Number $row.budget 'budget'
        current_bid = Get-OptionalNumber $row.current_bid 'current_bid'
        source_date = [string]$row.date
      }
    }
  )
  $spend = [double](($records | Measure-Object -Property spend -Sum).Sum)
  $sales = [double](($records | Measure-Object -Property sales -Sum).Sum)
  $orders = [double](($records | Measure-Object -Property orders -Sum).Sum)
  $clicks = [double](($records | Measure-Object -Property clicks -Sum).Sum)
  $impressions = [double](($records | Measure-Object -Property impressions -Sum).Sum)
  return [PSCustomObject]@{
    label = $Label
    source_name = Split-Path -Leaf $Path
    rows_read = $records.Count
    spend = $spend
    sales = $sales
    orders = $orders
    clicks = $clicks
    impressions = $impressions
    acos = Safe-Divide $spend $sales
    cpc = Safe-Divide $spend $clicks
    ctr = Safe-Divide $clicks $impressions
    cvr = Safe-Divide $orders $clicks
    time_range = $timeRange
    records = $records
  }
}
function Write-Utf8([string]$Path, [string]$Content) { [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false)) }

$baseline = Get-LoopData $CsvPath 'baseline'
$inputHash = (Get-FileHash -LiteralPath $CsvPath -Algorithm SHA256).Hash.ToLowerInvariant()
$issues = [System.Collections.Generic.List[string]]::new()
$actions = [System.Collections.Generic.List[object]]::new()
$diagnostics = [System.Collections.Generic.List[object]]::new()
$index = 0
foreach ($record in $baseline.records) {
  $index++
  $rowAcos = Safe-Divide $record.spend $record.sales
  $diagnostic = $null
  $recommendation = 'keep'
  $reason = 'No high-priority anomaly under the selected rules.'
  $risk = 'low'
  $expectedEffect = 'Keep the current settings and continue monitoring.'
  $budgetImpact = 'No budget or bid change proposed.'
  $proposedChange = 'keep'
  if ($record.spend -ge 10 -and $record.orders -eq 0) {
    $diagnostic = 'high_spend_no_order'; $recommendation = 'decrease_bid'; $reason = 'Spend reached the threshold with no orders.'; $risk = 'high'
    $expectedEffect = 'Reduce continued spend while targeting and listing evidence are checked.'
    $budgetImpact = "Candidate reduction in spend exposure; current budget is $(Format-Money $record.budget)."
    $proposedChange = 'candidate decrease of 10%-20%; exact value requires preflight'
  } elseif ($null -ne $rowAcos -and $rowAcos -gt ($TargetAcos * 1.3) -and $record.orders -ge 1) {
    $diagnostic = 'high_acos'; $recommendation = 'decrease_bid'; $reason = 'ACoS exceeds the target by more than 30 percent.'; $risk = 'high'
    $expectedEffect = 'Reduce inefficient paid traffic while preserving a reversible change candidate.'
    $budgetImpact = "Candidate reduction in spend exposure; current budget is $(Format-Money $record.budget)."
    $proposedChange = 'candidate decrease of 10%-20%; exact value requires preflight'
  } elseif ($record.clicks -ge 15 -and $record.orders -eq 0) {
    $diagnostic = 'high_click_low_conversion'; $recommendation = 'pause'; $reason = 'Clicks reached the threshold with no orders.'; $risk = 'high'
    $expectedEffect = 'Stop additional clicks while listing and search-term relevance are checked.'
    $budgetImpact = "Candidate stop to further spend; current budget is $(Format-Money $record.budget)."
    $proposedChange = 'candidate pause; resume only after evidence review'
  } elseif ($null -ne $rowAcos -and $rowAcos -le $TargetAcos -and $record.orders -ge 2) {
    $diagnostic = 'strong_performance'; $recommendation = 'keep'; $reason = 'ACoS is within target with at least two orders.'; $risk = 'low'
    $expectedEffect = 'Preserve the current settings while collecting more stable evidence.'
    $budgetImpact = 'No budget or bid change proposed.'
    $proposedChange = 'keep'
  }
  $requiresConfirmation = ($recommendation -ne 'keep')
  $rollbackAvailable = ($null -ne $record.budget -or $null -ne $record.current_bid)
  if ($null -ne $diagnostic) { [void]$diagnostics.Add([ordered]@{ row = $index; campaign = $record.campaign; ad_group = $record.ad_group; search_term = $record.search_term; rule = $diagnostic; risk = $risk }) }
  $actionCard = [ordered]@{
    action_id = "action-$index"
    status = 'candidate'
    problem = [ordered]@{
      campaign = $record.campaign
      target = "$($record.ad_group) / $($record.search_term)"
      diagnostic = if ($null -eq $diagnostic) { 'no_priority_anomaly' } else { $diagnostic }
      statement = $reason
      time_range = $baseline.time_range
    }
    evidence = [ordered]@{
      source_name = $baseline.source_name
      input_hash = $inputHash
      rows = @([ordered]@{ row = $index; date = $record.source_date; campaign = $record.campaign; ad_group = $record.ad_group; search_term = $record.search_term })
      metrics = [ordered]@{ impressions = $record.impressions; clicks = $record.clicks; spend = $record.spend; sales = $record.sales; orders = $record.orders; acos = $rowAcos; cpc = (Safe-Divide $record.spend $record.clicks); ctr = (Safe-Divide $record.clicks $record.impressions); cvr = (Safe-Divide $record.orders $record.clicks); budget = $record.budget; current_bid = $record.current_bid }
      rule = if ($null -eq $diagnostic) { 'baseline_monitoring' } else { $diagnostic }
    }
    recommendation = [ordered]@{ action = $recommendation; rationale = $reason; proposed_change = $proposedChange; candidate_only = $true }
    impact = [ordered]@{ risk_level = $risk; budget_impact = $budgetImpact; expected_effect = $expectedEffect; assumptions = @('The local export is complete for the selected time range.', 'No action is executed by this personal workflow.') }
    permissions = [ordered]@{ mode = 'read_only'; write_status = if ($requiresConfirmation) { 'awaiting_confirmation' } else { 'not_needed' }; confirmation_required = $requiresConfirmation; control_plane_handoff = $requiresConfirmation; executed = $false }
    rollback = [ordered]@{ available = $rollbackAvailable; original_bid = $record.current_bid; original_budget = $record.budget; restore_instruction = if ($rollbackAvailable) { 'Before any approved write, snapshot these values; restore the original bid or budget through the control plane.' } else { 'Baseline bid and budget are incomplete; do not hand off a write.' }; snapshot_required = $true }
    verification = [ordered]@{ windows = @('3d', '7d'); metrics = @('spend', 'sales', 'orders', 'acos', 'cpc', 'ctr', 'cvr'); readback_required = $requiresConfirmation }
    target = "$($record.campaign) / $($record.ad_group) / $($record.search_term)"
    reason = $reason
    type = $recommendation
    risk = $risk
    requires_confirmation = $requiresConfirmation
    executed = $false
    control_plane_required = $requiresConfirmation
  }
  [void]$actions.Add($actionCard)
}

$readback = $null
$readbackDelta = $null
if (-not [string]::IsNullOrWhiteSpace($ReadbackCsvPath)) {
  $readback = Get-LoopData $ReadbackCsvPath 'readback'
  $readbackDelta = [ordered]@{
    spend = [Math]::Round($readback.spend - $baseline.spend, 4)
    sales = [Math]::Round($readback.sales - $baseline.sales, 4)
    orders = [Math]::Round($readback.orders - $baseline.orders, 4)
    acos = if ($null -eq $baseline.acos -or $null -eq $readback.acos) { $null } else { [Math]::Round($readback.acos - $baseline.acos, 6) }
    cvr = if ($null -eq $baseline.cvr -or $null -eq $readback.cvr) { $null } else { [Math]::Round($readback.cvr - $baseline.cvr, 6) }
  }
} else {
  [void]$issues.Add('post_action_readback_not_provided')
}

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$reportPath = Join-Path $outputRoot "$TaskId.md"
$receiptPath = Join-Path $outputRoot "$TaskId-receipt.json"
$actionDetails = ($actions | ForEach-Object {
@"
### $($_.action_id): $($_.problem.statement)

- Problem: $($_.problem.campaign) / $($_.problem.target) [$($_.problem.time_range)]
- Evidence: $($_.evidence.source_name), row(s) $((@($_.evidence.rows) | ForEach-Object { $_.row }) -join ', '); spend=$($_.evidence.metrics.spend), sales=$($_.evidence.metrics.sales), orders=$($_.evidence.metrics.orders), ACoS=$(Format-Percent $_.evidence.metrics.acos), CPC=$($_.evidence.metrics.cpc)
- Recommendation: $($_.recommendation.action) ($($_.recommendation.proposed_change))
- Impact: $($_.impact.risk_level); $($_.impact.budget_impact) $($_.impact.expected_effect)
- Permissions: $($_.permissions.mode); $($_.permissions.write_status); confirmation=$($_.permissions.confirmation_required); executed=$($_.permissions.executed)
- Rollback: bid=$($_.rollback.original_bid), budget=$($_.rollback.original_budget); $($_.rollback.restore_instruction)
- Verification: 3d and 7d readback of $((@($_.verification.metrics) -join ', '))
"@
}) -join "`n"
$report = @"
# Personal Ad Operations Loop

Task: $TaskId
Time range: $timeRange
Marketplace: $Marketplace
Source: $($baseline.source_name)
Input SHA256: $inputHash

## Current Judgment

Read $($baseline.rows_read) rows. Spend is $(Format-Money $baseline.spend), sales are $(Format-Money $baseline.sales), orders are $($baseline.orders), and ACoS is $(Format-Percent $baseline.acos). Detected $($diagnostics.Count) rule-backed signals.

## Action Candidates

$(if ($actions.Count -eq 0) { 'No action candidates.' } else { $actionDetails })

No bid, budget, campaign, listing, external message, or business-system write was executed by this personal workflow.

## Verification

- Evidence receipt: $receiptPath
- Pending verification: $(if ($issues.Count -gt 0) { ($issues -join '; ') } else { 'none' })
- Readback status: $(if ($null -eq $readback) { 'not provided; waiting for a later export' } else { 'compared' })
$(if ($null -ne $readbackDelta) { "- Readback delta: spend=$($readbackDelta.spend), sales=$($readbackDelta.sales), orders=$($readbackDelta.orders), ACoS=$($readbackDelta.acos), CVR=$($readbackDelta.cvr)" })

## Next Step

Review the evidence-backed candidates. Any bid or budget change must leave this personal workflow and enter the approved control plane; after the action, provide a new export for readback.
"@
Write-Utf8 $reportPath $report
$reportHash = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
$receipt = [ordered]@{
  schema_version = 1
  receipt_type = 'qianlima_personal_ad_ops_evidence_receipt'
  task_id = $TaskId
  workflow = 'personal_ad_ops_loop'
  action_card_contract_version = $actionContract.contract_version
  source_name = $baseline.source_name
  input_hash = $inputHash
  rows_read = $baseline.rows_read
  data_time_range = $baseline.time_range
  metrics = [ordered]@{ spend = $baseline.spend; sales = $baseline.sales; orders = $baseline.orders; acos = $baseline.acos; cpc = $baseline.cpc; ctr = $baseline.ctr; cvr = $baseline.cvr }
  diagnostic_count = $diagnostics.Count
  action_candidate_count = $actions.Count
  action_candidates = @($actions)
  artifact_hash = $reportHash
  verification_status = if ($issues.Count -eq 0) { 'passed' } else { 'passed_with_pending_verification' }
  pending_verification = @($issues)
  readback_status = if ($null -eq $readback) { 'pending' } else { 'compared' }
  readback_delta = $readbackDelta
  external_calls = $false
  business_writes = $false
  permissions_granted = $false
  executed_actions = @()
  next_step = 'Review the action cards. If a business write is approved elsewhere, snapshot the baseline, execute through the control plane, and supply 3d/7d exports for readback.'
}
Write-Utf8 $receiptPath ($receipt | ConvertTo-Json -Depth 12)
$result = [ordered]@{ status = 'completed_readonly'; task_id = $TaskId; report_path = $reportPath; receipt_path = $receiptPath; input_hash = $inputHash; rows_read = $baseline.rows_read; diagnostic_count = $diagnostics.Count; action_candidate_count = $actions.Count; readback_status = $receipt.readback_status; verification_status = $receipt.verification_status; external_calls = $false; business_writes = $false; permissions_granted = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List }
