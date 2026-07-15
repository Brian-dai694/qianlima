<#
.SYNOPSIS
    Stage-0 quick classifier for an incoming natural-language request.
.DESCRIPTION
    Loads the compact router (codex-router.json) and response policy, then
    matches the request text against route signals plus built-in high-risk,
    business, and small-talk signal sets. Emits a service level (L0-L4),
    selected route, risk status, evidence grade, and recommended next action.
.PARAMETER Request
    The user request text to classify.
.PARAMETER Freshness
    Freshness hint (live, fresh, cache, ...) used to derive the evidence grade.
.PARAMETER KnownFact
    A known fact that lets a request resolve at L1 without loading evidence.
.PARAMETER Json
    Emit the classification result as JSON instead of formatted host output.
.EXAMPLE
    ./new-staged-response.ps1 -Request "check ACoS for this ASIN" -Freshness cache -Json
#>
param(
  [Parameter(Mandatory)]
  [string]$Request,
  [string]$Root = '',
  [string]$SessionId = 'current',
  [string]$KnownFact = '',
  [string]$Freshness = 'unknown',
  [string]$ObjectId = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$policyPath = Join-Path $Root 'response-policy.yaml'
$routerPath = Join-Path $Root 'codex-router.json'
if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
  throw "Missing response policy: $policyPath"
}
if (-not (Test-Path -LiteralPath $routerPath -PathType Leaf)) {
  throw "Missing compact router: $routerPath. Run start-qianlima.ps1 first."
}

function Test-AnyMatch([string]$Text, [object[]]$Signals) {
  foreach ($signal in $Signals) {
    if ($signal -and $Text.IndexOf([string]$signal, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
      return $true
    }
  }
  return $false
}

function Get-EvidenceGrade([string]$FreshnessValue) {
  switch -Regex ($FreshnessValue) {
    '^(live|real_time)' { return 'A' }
    '^(fresh|recent|cache)' { return 'B' }
    default { return 'C' }
  }
}

function ConvertFrom-CodePoints([int[]]$CodePoints) {
  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

$router = Get-Content -LiteralPath $routerPath -Raw -Encoding UTF8 | ConvertFrom-Json
$requestText = $Request.Trim()
$highRiskSignals = @(
  (ConvertFrom-CodePoints @(35843, 31454, 20215)),
  (ConvertFrom-CodePoints @(35843, 39044, 31639)),
  (ConvertFrom-CodePoints @(25913, 20215)),
  (ConvertFrom-CodePoints @(37319, 36141)),
  (ConvertFrom-CodePoints @(21024, 38500)),
  (ConvertFrom-CodePoints @(20889, 22238)),
  (ConvertFrom-CodePoints @(25552, 20132)),
  (ConvertFrom-CodePoints @(20445, 23384)),
  (ConvertFrom-CodePoints @(21457, 24067)),
  (ConvertFrom-CodePoints @(21457, 36865)),
  'change_bid', 'change_budget', 'change_price', 'purchase_order', 'write_back', 'delete'
)
$controlledTargets = @(
  (ConvertFrom-CodePoints @(31454, 20115)),
  (ConvertFrom-CodePoints @(39044, 31639)),
  (ConvertFrom-CodePoints @(20215, 26684)),
  (ConvertFrom-CodePoints @(37319, 36141))
)
$adjustmentVerbs = @(
  (ConvertFrom-CodePoints @(35843)),
  (ConvertFrom-CodePoints @(25552, 39640)),
  (ConvertFrom-CodePoints @(38477, 20302)),
  (ConvertFrom-CodePoints @(20462, 25913)),
  (ConvertFrom-CodePoints @(35774, 32622))
)
$businessSignals = @(
  (ConvertFrom-CodePoints @(24191, 21578)),
  'ACoS',
  (ConvertFrom-CodePoints @(20851, 38190, 35789)),
  (ConvertFrom-CodePoints @(25490, 21517)),
  'ASIN', 'Listing',
  (ConvertFrom-CodePoints @(21033, 28070)),
  (ConvertFrom-CodePoints @(34917, 36135)),
  (ConvertFrom-CodePoints @(24211, 23384)),
  (ConvertFrom-CodePoints @(31454, 21697)),
  (ConvertFrom-CodePoints @(36873, 21697)),
  (ConvertFrom-CodePoints @(39046, 26143)),
  'Pangolinfo', 'Sorftime', 'Excel',
  (ConvertFrom-CodePoints @(25991, 26723)),
  (ConvertFrom-CodePoints @(36164, 26009)),
  (ConvertFrom-CodePoints @(32593, 39029))
)
$chatSignals = @(
  (ConvertFrom-CodePoints @(20320, 22909)),
  (ConvertFrom-CodePoints @(35874, 35874)),
  (ConvertFrom-CodePoints @(29616, 22312, 20960, 28857)),
  (ConvertFrom-CodePoints @(20026, 20160, 20040, 24930)),
  (ConvertFrom-CodePoints @(24590, 20040, 29992)),
  (ConvertFrom-CodePoints @(35299, 37322)),
  (ConvertFrom-CodePoints @(26159, 20160, 20040))
)
$routeMatches = @()

foreach ($route in $router.routes) {
  $signals = @($route.strong_signals)
  $matched = @($signals | Where-Object {
    $_ -and $requestText.IndexOf([string]$_, [StringComparison]::OrdinalIgnoreCase) -ge 0
  })
  if ($matched.Count -gt 0) {
    $routeMatches += [PSCustomObject]@{ route = $route; score = $matched.Count; matched_signals = $matched }
  }
}

$selected = $routeMatches | Sort-Object score -Descending | Select-Object -First 1
$isControlAdjustment = (Test-AnyMatch $requestText $controlledTargets) -and (Test-AnyMatch $requestText $adjustmentVerbs)
$isHighRisk = (Test-AnyMatch $requestText $highRiskSignals) -or $isControlAdjustment
$isBusiness = Test-AnyMatch $requestText $businessSignals
$isSimpleChat = (Test-AnyMatch $requestText $chatSignals) -and -not $isBusiness -and -not $isHighRisk

if ($isHighRisk) {
  $serviceLevel = 'L4'
  $riskStatus = 'blocked_pending_confirmation'
} elseif ($selected) {
  $serviceLevel = if ($selected.route.risk -eq 'low') { 'L2' } else { 'L3' }
  $riskStatus = 'read_only_or_local_draft'
} elseif ($isSimpleChat) {
  $serviceLevel = 'L0'
  $riskStatus = 'none'
} elseif ($KnownFact) {
  $serviceLevel = 'L1'
  $riskStatus = 'none'
} else {
  $serviceLevel = 'L2'
  $riskStatus = 'needs_route_clarification'
}

$routeId = if ($selected) { $selected.route.route_id } elseif ($isSimpleChat) { 'direct_answer' } else { 'unclassified' }
$workflow = if ($selected) { $selected.route.workflow } else { $null }
$evidenceGrade = Get-EvidenceGrade $Freshness
$knownOrExclusion = if ($KnownFact) { $KnownFact } elseif ($serviceLevel -eq 'L0') { 'This is a direct-answer request; no operations data will be loaded.' } elseif ($serviceLevel -eq 'L4') { 'A high-risk action was detected; execution remains blocked until explicit confirmation.' } elseif ($selected) { "Matched route: $routeId. No decision fact is claimed until evidence is loaded." } else { 'No confident route or current fact is available yet.' }
$nextAction = switch ($serviceLevel) {
  'L0' { 'Answer directly without workspace loading.' }
  'L1' { 'Reuse the hot state, then refresh only if the stated freshness is insufficient.' }
  'L2' { 'Load the selected task card and only the route-specific inputs.' }
  'L3' { 'Collect and filter the required evidence; deliver updates as each decision-relevant fact arrives.' }
  'L4' { 'Prepare the decision package and request explicit confirmation before any external action.' }
}

$result = [PSCustomObject]@{
  schema_version = 1
  generated_at = (Get-Date).ToString('o')
  session_id = $SessionId
  object_id = $ObjectId
  stage = 'stage_0_quick_classification'
  service_level = $serviceLevel
  route = $routeId
  workflow = $workflow
  risk_status = $riskStatus
  evidence_grade = $evidenceGrade
  freshness = $Freshness
  known_fact_or_exclusion = $knownOrExclusion
  matched_signals = [object[]]$(if ($selected) { @($selected.matched_signals) } else { @() })
  next_action = $nextAction
  pending_checks = [object[]]$(if ($serviceLevel -in @('L2', 'L3', 'L4')) { @('Load route-specific evidence before making a decision-final claim.') } else { @() })
}

if ($Json) {
  $result | ConvertTo-Json -Depth 5
  exit 0
}

Write-Host "[Stage 0 | $($result.service_level) | $($result.route)]"
Write-Host "Known: $($result.known_fact_or_exclusion)"
Write-Host "Evidence: $($result.evidence_grade) | Freshness: $($result.freshness)"
Write-Host "Risk: $($result.risk_status)"
Write-Host "Next: $($result.next_action)"
