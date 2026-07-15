$scripts = Join-Path $PSScriptRoot '..\.qianlima\scripts'
$contractScript = Join-Path $scripts 'check-task-contract.ps1'
$runtimeScript = Join-Path $scripts 'invoke-runtime-check.ps1'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\.qianlima')).Path
$tmp = Join-Path $env:TEMP ("ctrtest-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $tmp 'working') -Force | Out-Null
$fail = 0
function Check($n, $c) { if ($c) { Write-Host "PASS: $n" } else { Write-Host "FAIL: $n"; $script:fail++ } }

function New-Contract($id, $control, $state, $deadlineOffsetSec) {
  $deadline = [datetimeoffset]::Now.AddSeconds($deadlineOffsetSec).ToString('o')
  $obj = [PSCustomObject]@{
    request_id = $id; control = $control; state = $state; deadline_at = $deadline; pending_checks = @('c1')
  }
  $p = Join-Path $tmp "working\task-contract-$id.json"
  $obj | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $p -Encoding UTF8
}
function Contract($id) { & $contractScript -RequestId $id -Root $tmp -Json | ConvertFrom-Json }
# Run runtime-check in a child process so `exit` can't kill this host; return exit code.
function RuntimeExit($params) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $runtimeScript @params *> $null
  return $LASTEXITCODE
}

# ── check-task-contract ──
New-Contract 'run1' 'continue' 'running' 3600
$c = Contract 'run1'
Check "running+future -> continue_external_reads true" ($c.continue_external_reads -eq $true -and $c.delivery_mode -eq 'continue')
New-Contract 'cancel1' 'cancel' 'running' 3600
$c = Contract 'cancel1'
Check "control=cancel -> state cancelled" ($c.state -eq 'cancelled' -and $c.delivery_mode -eq 'cancelled')
Check "cancelled -> no external reads" ($c.continue_external_reads -eq $false)
New-Contract 'timeout1' 'continue' 'running' -3600
$c = Contract 'timeout1'
Check "past deadline -> timed_out + frozen" ($c.timed_out -eq $true -and $c.state -eq 'frozen')
Check "frozen -> conclusion_only delivery" ($c.delivery_mode -eq 'conclusion_only_with_pending_checks')
New-Contract 'stop1' 'stop_deep_dive' 'running' 3600
Check "stop_deep_dive -> frozen" ((Contract 'stop1').state -eq 'frozen')
$threw = $false; try { & $contractScript -RequestId 'bad/id' -Root $tmp -Json 2>$null } catch { $threw = $true }
Check "unsafe RequestId throws" $threw
$threw = $false; try { & $contractScript -RequestId 'ghost' -Root $tmp -Json 2>$null } catch { $threw = $true }
Check "missing contract throws" $threw

# ── invoke-runtime-check (phase gate exit codes) ──
Check "BeforeToolUse high-risk unconfirmed -> exit 1" ((RuntimeExit @('-Phase','BeforeToolUse','-Action','change_bid')) -eq 1)
Check "BeforeToolUse high-risk confirmed -> exit 0" ((RuntimeExit @('-Phase','BeforeToolUse','-Action','change_bid','-Confirmed')) -eq 0)
Check "BeforeToolUse benign action -> exit 0" ((RuntimeExit @('-Phase','BeforeToolUse','-Action','read_data')) -eq 0)
$ghost = Join-Path $tmp 'no-such-output.md'
Check "AfterToolUse missing output -> exit 1" ((RuntimeExit @('-Phase','AfterToolUse','-OutputPath',$ghost)) -eq 1)
Check "FinalCheck without ledger -> exit 1" ((RuntimeExit @('-Phase','FinalCheck')) -eq 1)

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "TOTAL FAILURES: $fail"
