$scripts = Join-Path $PSScriptRoot '..\.qianlima\scripts'
$snapScript = Join-Path $scripts 'get-snapshot-decision.ps1'
$usageScript = Join-Path $scripts 'new-usage-record.ps1'
$tmp = Join-Path $env:TEMP ("snaptest-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$fail = 0
function Check($n, $c) { if ($c) { Write-Host "PASS: $n" } else { Write-Host "FAIL: $n"; $script:fail++ } }

function New-Snap($name, $quality, $ageSeconds, $ttl) {
  $gen = [datetimeoffset]::Now.AddSeconds(-$ageSeconds).ToString('o')
  $obj = [PSCustomObject]@{
    route = 'test_route'; quality_status = $quality; generated_at = $gen; ttl_seconds = $ttl
    facts = @('f1'); anomalies = @(); source_refs = @('s1')
  }
  $p = Join-Path $tmp "$name.json"
  $obj | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $p -Encoding UTF8
  return $p
}

# get-snapshot-decision
$d = & $snapScript -SnapshotPath (New-Snap 'fresh' 'passed' 10 900) -Json | ConvertFrom-Json
Check "fresh -> serve_snapshot_and_refresh / B" ($d.decision -eq 'serve_snapshot_and_refresh' -and $d.evidence_grade -eq 'B')
$d = & $snapScript -SnapshotPath (New-Snap 'stale' 'passed' 2000 900) -SWRSeconds 3600 -Json | ConvertFrom-Json
Check "stale window -> serve_stale / C" ($d.decision -eq 'serve_stale_snapshot_and_refresh_before_final' -and $d.evidence_grade -eq 'C')
$d = & $snapScript -SnapshotPath (New-Snap 'expired' 'passed' 10000 900) -SWRSeconds 3600 -Json | ConvertFrom-Json
Check "beyond SWR -> live_evidence_required" ($d.decision -eq 'live_evidence_required')
$d = & $snapScript -SnapshotPath (New-Snap 'bad' 'failed' 10 900) -Json | ConvertFrom-Json
Check "quality not passed -> live_evidence_required / C" ($d.decision -eq 'live_evidence_required' -and $d.evidence_grade -eq 'C')
$threw = $false; try { & $snapScript -SnapshotPath (Join-Path $tmp 'nope.json') -Json 2>$null } catch { $threw = $true }
Check "missing snapshot throws" $threw

# new-usage-record
function Read-Ledger($runId) {
  $safe = $runId -replace '[^A-Za-z0-9_.-]', '-'
  Get-Content -LiteralPath (Join-Path $tmp "usage-ledger\$safe.yaml") -Raw
}
& $usageScript -Root $tmp -RunId 'overlimit' -EstimatedCost 5 -CostLimit 1 -Force | Out-Null
$y = Read-Ledger 'overlimit'
Check "over_limit status" ($y -match 'cost_status: over_limit')
Check "over_limit -> needs_confirmation" ($y -match 'continue_or_stop: needs_confirmation')
& $usageScript -Root $tmp -RunId 'baseguard' -EstimatedCost 3 -BaselineCost 1 -Force | Out-Null
$y = Read-Ledger 'baseguard'
Check "over_baseline_guard status" ($y -match 'cost_status: over_baseline_guard')
& $usageScript -Root $tmp -RunId 'precedence' -EstimatedCost 5 -CostLimit 1 -BaselineCost 1 -Force | Out-Null
$y = Read-Ledger 'precedence'
Check "over_limit precedence over baseline_guard" ($y -match 'cost_status: over_limit')
& $usageScript -Root $tmp -RunId 'normal' -EstimatedCost 1 -BaselineCost 10 -Force | Out-Null
$y = Read-Ledger 'normal'
Check "normal stays continue" ($y -match 'continue_or_stop: continue' -and $y -match 'cost_status: estimate')
Check "savings computed (10-1=9)" ($y -match 'estimated_savings: 9')
$threw = $false; try { & $usageScript -Root $tmp -RunId 'neg' -EstimatedCost -1 -Force 2>$null } catch { $threw = $true }
Check "negative cost throws" $threw
& $usageScript -Root $tmp -RunId 'a/b c' -EstimatedCost 1 -Force | Out-Null
Check "runid sanitized to a-b-c.yaml" (Test-Path (Join-Path $tmp 'usage-ledger\a-b-c.yaml'))
$threw = $false; try { & $usageScript -Root $tmp -RunId 'normal' -EstimatedCost 1 2>$null } catch { $threw = $true }
Check "existing without -Force throws" $threw

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "TOTAL FAILURES: $fail"
