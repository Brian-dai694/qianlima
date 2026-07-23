<##
.SYNOPSIS
  Offline regression for the personal ad-operations loop.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$testRoot = Join-Path $projectRoot '.qianlima\working\personal-ad-ops-tests'
$runner = Join-Path $PSScriptRoot 'invoke-personal-ad-ops-loop.ps1'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmssfff')
$baselinePath = Join-Path $testRoot "baseline-$stamp.csv"
$readbackPath = Join-Path $testRoot "readback-$stamp.csv"
$invalidPath = Join-Path $testRoot "invalid-$stamp.csv"
$rows = @(
  [ordered]@{ date='2026-07-23'; marketplace='US'; campaign_name='Campaign-A'; ad_group_name='NoOrder'; search_term='bad-keyword'; impressions=1000; clicks=20; spend=12; sales=0; orders=0; budget=20; current_bid=1.10 },
  [ordered]@{ date='2026-07-23'; marketplace='US'; campaign_name='Campaign-B'; ad_group_name='HighAcos'; search_term='expensive-keyword'; impressions=800; clicks=10; spend=15; sales=20; orders=1; budget=25; current_bid=1.20 },
  [ordered]@{ date='2026-07-23'; marketplace='US'; campaign_name='Campaign-C'; ad_group_name='Strong'; search_term='good-keyword'; impressions=1200; clicks=20; spend=6; sales=40; orders=2; budget=10; current_bid=0.80 }
)
$readbackRows = @(
  [ordered]@{ date='2026-07-23'; marketplace='US'; campaign_name='Campaign-A'; ad_group_name='NoOrder'; search_term='bad-keyword'; impressions=1100; clicks=22; spend=12; sales=10; orders=1; budget=20; current_bid=1.10 },
  [ordered]@{ date='2026-07-23'; marketplace='US'; campaign_name='Campaign-B'; ad_group_name='HighAcos'; search_term='expensive-keyword'; impressions=850; clicks=11; spend=15; sales=30; orders=2; budget=25; current_bid=1.20 },
  [ordered]@{ date='2026-07-23'; marketplace='US'; campaign_name='Campaign-C'; ad_group_name='Strong'; search_term='good-keyword'; impressions=1300; clicks=22; spend=6; sales=45; orders=2; budget=10; current_bid=0.80 }
)
function Write-Csv([string]$Path, [object[]]$Data) {
  $objects = @($Data | ForEach-Object { [pscustomobject]$_ })
  [IO.File]::WriteAllText($Path, (($objects | ConvertTo-Csv -NoTypeInformation) -join "`r`n"), [Text.UTF8Encoding]::new($false))
}
Write-Csv $baselinePath $rows
Write-Csv $readbackPath $readbackRows
[IO.File]::WriteAllText($invalidPath, "date,marketplace,spend`r`n2026-07-23,US,1", [Text.UTF8Encoding]::new($false))

function Invoke-Json([string[]]$Arguments) {
  $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner @Arguments 2>&1)
  if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
  return (($output -join "`n") | ConvertFrom-Json)
}
function Invoke-ExpectedFailure([string]$Path) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $null = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -CsvPath $Path -Date '2026-07-23' -Marketplace US 2>&1); $code = $LASTEXITCODE } finally { $ErrorActionPreference = $old }
  return $code -ne 0
}
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
$cases = [System.Collections.Generic.List[object]]::new()
$result = Invoke-Json @('-CsvPath', $baselinePath, '-Date', '2026-07-23', '-Marketplace', 'US', '-ReadbackCsvPath', $readbackPath, '-TaskId', "test-$stamp", '-PassThru')
$receipt = Get-Content -LiteralPath $result.receipt_path -Raw -Encoding UTF8 | ConvertFrom-Json

Add-Case 'readonly_loop_completes' ($result.status -eq 'completed_readonly' -and $result.external_calls -eq $false -and $result.business_writes -eq $false)
Add-Case 'metrics_and_diagnostics_are_recorded' ($result.rows_read -eq 3 -and $result.diagnostic_count -eq 3 -and $result.action_candidate_count -eq 3)
Add-Case 'receipt_has_source_and_artifact_hash' (-not [string]::IsNullOrWhiteSpace($receipt.input_hash) -and -not [string]::IsNullOrWhiteSpace($receipt.artifact_hash) -and $receipt.rows_read -eq 3)
Add-Case 'high_impact_candidate_is_not_executed' (@($receipt.action_candidates | Where-Object { $_.type -eq 'decrease_bid' -and $_.requires_confirmation -eq $true -and $_.executed -eq $false }).Count -eq 2 -and $receipt.executed_actions.Count -eq 0)
Add-Case 'readback_delta_is_available' ($result.readback_status -eq 'compared' -and $receipt.readback_delta.orders -eq 2 -and $receipt.readback_delta.sales -eq 25)
Add-Case 'action_card_has_required_sections' (@($receipt.action_candidates | Where-Object { $_.problem -and $_.evidence -and $_.recommendation -and $_.impact -and $_.permissions -and $_.rollback -and $_.verification }).Count -eq 3)
Add-Case 'action_card_identifies_campaign_and_target' (@($receipt.action_candidates | Where-Object { $_.problem.campaign -and $_.problem.target -match 'search' -or $_.problem.target -match 'keyword' }).Count -eq 3)
Add-Case 'action_card_has_rollback_baseline' (@($receipt.action_candidates | Where-Object { $_.rollback.snapshot_required -eq $true -and $null -ne $_.rollback.original_budget }).Count -eq 3)
Add-Case 'action_card_has_fixed_verification_windows' (@($receipt.action_candidates | Where-Object { (@($_.verification.windows) -join ',') -eq '3d,7d' -and $_.verification.readback_required }).Count -eq 2)
Add-Case 'next_step_stays_in_control_plane' ($receipt.next_step -match 'control plane' -and $receipt.permissions_granted -eq $false -and $receipt.action_card_contract_version -eq '1.0.0')
Add-Case 'invalid_schema_is_rejected' (Invoke-ExpectedFailure $invalidPath)
Add-Case 'all_side_effects_are_false' ($receipt.external_calls -eq $false -and $receipt.business_writes -eq $false -and $receipt.permissions_granted -eq $false -and $receipt.executed_actions.Count -eq 0)

$failed = @($cases | Where-Object { -not $_.passed })
$summary = [PSCustomObject]@{ suite = 'personal_ad_ops_loop'; passed = ($failed.Count -eq 0); total = $cases.Count; passed_count = ($cases.Count - $failed.Count); external_calls = $false; business_writes = $false; cases = @($cases) }
if ($PassThru) { $summary | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize; Write-Host ("Personal ad ops loop: {0}/{1} PASS" -f $summary.passed_count, $summary.total) }
if ($failed.Count -gt 0) { throw ('Personal ad ops loop failed: ' + (($failed | ForEach-Object { $_.name }) -join ', ')) }
