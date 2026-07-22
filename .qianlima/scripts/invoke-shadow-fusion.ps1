<#
.SYNOPSIS
  Produces a non-authoritative fusion observation from validated Claim Packs.
.DESCRIPTION
  This is an offline shadow aggregator. It never invokes a model, tool, MCP
  server, network endpoint, or business write. Conflicts are preserved in the
  report and always prevent automatic adoption.
#>
param(
  [Parameter(Mandatory = $true)] [string]$FusionPlanPath,
  [Parameter(Mandatory = $true)] [string[]]$ClaimPackPath,
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$fusionValidator = Join-Path $PSScriptRoot 'validate-fusion-plan.ps1'
$claimValidator = Join-Path $PSScriptRoot 'validate-claim-pack.ps1'
$plan = Get-Content -LiteralPath $FusionPlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
$planResult = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fusionValidator -PlanPath $FusionPlanPath -PassThru | ConvertFrom-Json
if ($planResult.status -notin @('approved', 'needs_human')) { throw 'Fusion Plan is not eligible for shadow aggregation.' }
if (@($ClaimPackPath).Count -ne @($plan.selected_models).Count) { throw 'Every selected model requires exactly one Claim Pack.' }

$packs = @()
foreach ($path in $ClaimPackPath) {
  $claimResult = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $claimValidator -ClaimPackPath $path -PassThru | ConvertFrom-Json
  if ($claimResult.status -ne 'accepted_as_candidate') { throw "Claim Pack rejected: $path" }
  $pack = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($pack.fusion_id -ne $plan.fusion_id -or $pack.task_id -ne $plan.task_id) { throw 'Claim Pack lineage does not match the Fusion Plan.' }
  if (@($plan.selected_models | Where-Object { $_ -eq $pack.producer_model_id }).Count -ne 1) { throw 'Claim Pack producer is not selected by the Fusion Plan.' }
  $packs += $pack
}
if (@($packs.producer_model_id | Select-Object -Unique).Count -ne @($plan.selected_models).Count) { throw 'Claim Packs must come from distinct selected model IDs.' }

$claimIndex = @{}
foreach ($pack in $packs) {
  foreach ($claim in @($pack.claims)) {
    if (-not $claimIndex.ContainsKey($claim.claim_id)) { $claimIndex[$claim.claim_id] = @() }
    $claimIndex[$claim.claim_id] += [PSCustomObject]@{ model_id = $pack.producer_model_id; statement = [string]$claim.statement; source_refs = @($claim.source_refs) }
  }
}
$conflicts = @()
$sharedClaims = 0
$agreedClaims = 0
foreach ($claimId in $claimIndex.Keys) {
  $entries = @($claimIndex[$claimId])
  if ($entries.Count -lt 2) { continue }
  $sharedClaims++
  $statements = @($entries.statement | ForEach-Object { $_.Trim().ToLowerInvariant() } | Select-Object -Unique)
  if ($statements.Count -eq 1) { $agreedClaims++; continue }
  $conflicts += [PSCustomObject]@{ claim_id = $claimId; kind = 'statement_mismatch'; candidates = $entries }
}

$metrics = @($packs | ForEach-Object { $_.metrics } | Where-Object { $null -ne $_ })
$totalCost = [double](@($metrics | ForEach-Object { if ($null -ne $_.estimated_cost_usd) { [double]$_.estimated_cost_usd } else { 0 } }) | Measure-Object -Sum).Sum
$maxLatency = [double](@($metrics | ForEach-Object { if ($null -ne $_.total_latency_ms) { [double]$_.total_latency_ms } else { 0 } }) | Measure-Object -Maximum).Maximum
$reportId = "shadow-fusion-$([Guid]::NewGuid().ToString('n'))"
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $traceRoot "$reportId.json" }
$fullOutputPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $fullOutputPath.StartsWith($traceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Shadow fusion reports must be written under .qianlima/run-traces.' }
if (Test-Path -LiteralPath $fullOutputPath) { throw 'Shadow fusion reports are immutable; choose a new output path.' }

$report = [ordered]@{
  schema_version = 1
  report_type = 'qianlima_shadow_fusion_report'
  report_id = $reportId
  fusion_id = $plan.fusion_id
  task_id = $plan.task_id
  risk_level = $plan.risk_level
  candidate_model_ids = @($packs.producer_model_id)
  claim_pack_refs = @($ClaimPackPath | ForEach-Object { Split-Path -Leaf $_ })
  candidate_count = @($packs).Count
  claim_count = @($packs | ForEach-Object { @($_.claims).Count } | Measure-Object -Sum).Sum
  evidence_completeness = 1.0
  shared_claim_count = $sharedClaims
  agreed_claim_count = $agreedClaims
  agreement_rate = if ($sharedClaims -gt 0) { [math]::Round($agreedClaims / $sharedClaims, 4) } else { 0.0 }
  material_conflicts = @($conflicts)
  estimated_cost_usd = $totalCost
  total_latency_ms = $maxLatency
  shadow_status = if ($conflicts.Count -gt 0 -or $plan.risk_level -eq 'L4') { 'needs_human' } else { 'shadow_complete' }
  adoption_authority = 'none'
  primary_result_affected = $false
  external_calls = $false
  permissions_granted = $false
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($fullOutputPath, ($report | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
if ($PassThru) { $report | ConvertTo-Json -Depth 12 } else { [PSCustomObject]$report | Format-List }
