<#
.SYNOPSIS
  Render a user-facing realtime cost card.
.DESCRIPTION
  Computes savings and savings rate from an estimated cost against a baseline
  cost, then prints an ASCII cost card (cost, baseline, savings, savings source,
  cost status, continue-or-stop). Uses ASCII output to avoid Windows PowerShell
  encoding issues. Throws if any cost value is negative. Savings and savings rate
  are auto-derived from BaselineCost when not supplied.
.PARAMETER EstimatedCost
  Estimated cost of the task (>= 0).
.PARAMETER BaselineCost
  Reference/naive baseline cost used to compute savings (>= 0).
.PARAMETER SavingsSource
  Short label for where the savings come from (e.g. context_reduction).
.PARAMETER ContinueOrStop
  Recommendation string surfaced on the card: continue | stop.
.EXAMPLE
  ...new-cost-card.ps1 -EstimatedCost 0.03 -BaselineCost 0.10 -SavingsSource context_reduction
#>
param(
  [decimal]$EstimatedCost = 0,
  [decimal]$BaselineCost = 0,
  [decimal]$EstimatedSavings = 0,
  [decimal]$SavingsRatePct = 0,
  [decimal]$CostLimit = 0,
  [string]$Currency = 'USD',
  [string]$CostStatus = 'estimate',
  [string]$SavingsSource = 'unknown',
  [string]$ContinueOrStop = 'continue',
  [string]$Note = 'Cost is estimated until exact model and tool metering is available.'
)

$ErrorActionPreference = 'Stop'

foreach ($value in @($EstimatedCost, $BaselineCost, $CostLimit)) {
  if ($value -lt 0) {
    throw 'EstimatedCost, BaselineCost, and CostLimit must be zero or greater.'
  }
}

$computedSavings = $EstimatedSavings
if (($computedSavings -eq 0) -and ($BaselineCost -gt 0)) {
  $computedSavings = $BaselineCost - $EstimatedCost
}

$computedSavingsRate = $SavingsRatePct
if (($computedSavingsRate -eq 0) -and ($BaselineCost -gt 0)) {
  $computedSavingsRate = [decimal]::Round(($computedSavings / $BaselineCost) * 100, 2)
}

$computedCostStatus = $CostStatus
$computedContinueOrStop = $ContinueOrStop
$exceedsBaselineGuard = ($BaselineCost -gt 0) -and ($EstimatedCost -gt ($BaselineCost * 2))
if (($CostLimit -gt 0) -and ($EstimatedCost -gt $CostLimit)) {
  $computedCostStatus = 'over_limit'
  if ($computedContinueOrStop -eq 'continue') {
    $computedContinueOrStop = 'needs_confirmation'
  }
} elseif ($exceedsBaselineGuard) {
  $computedCostStatus = 'over_baseline_guard'
  if ($computedContinueOrStop -eq 'continue') {
    $computedContinueOrStop = 'needs_confirmation'
  }
}

$limitText = if ($CostLimit -gt 0) { "$CostLimit $Currency" } else { 'not_set' }
$continueText = switch ($computedContinueOrStop) {
  'continue' { 'continue' }
  'stop' { 'stop' }
  'needs_confirmation' { 'needs_confirmation' }
  default { $computedContinueOrStop }
}

@"
Cost status:
- Current estimate: $EstimatedCost $Currency ($computedCostStatus)
- Cost limit: $limitText
- Savings vs baseline: $computedSavings $Currency / $computedSavingsRate%
- Primary savings source: $SavingsSource
- Continue or stop: $continueText
- Note: $Note
"@
