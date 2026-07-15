$loop = Join-Path $PSScriptRoot '..\.qianlima\scripts\invoke-qianlima-loop.ps1'
$tmp = Join-Path $env:TEMP ("looptest-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$fail = 0
function Check($n, $c) { if ($c) { Write-Host "PASS: $n" } else { Write-Host "FAIL: $n"; $script:fail++ } }
function State($p) { Get-Content -LiteralPath $p -Raw | ConvertFrom-Json }

# EVR full pass (backward compat: execute->verify->pass)
$sp = Join-Path $tmp 'evr.json'
& $loop -WorkflowId daily_ad_report -LoopType EVR -Action Start -StatePath $sp | Out-Null
Check "EVR starts at execute" ((State $sp).current_state -eq 'execute')
& $loop -WorkflowId daily_ad_report -Action Advance -Outcome execute_complete -StatePath $sp | Out-Null
& $loop -WorkflowId daily_ad_report -Action Advance -Outcome verify_pass -StatePath $sp | Out-Null
Check "EVR completes on verify_pass" ((State $sp).status -eq 'completed')

# EVR refine loop + freeze at max
$sp = Join-Path $tmp 'evr2.json'
& $loop -WorkflowId x -LoopType EVR -Action Start -StatePath $sp -MaxIterations 1 | Out-Null
& $loop -WorkflowId x -Action Advance -Outcome execute_complete -StatePath $sp | Out-Null
& $loop -WorkflowId x -Action Advance -Outcome verify_issues -StatePath $sp | Out-Null
Check "EVR verify_issues -> refine (iter 1)" ((State $sp).current_state -eq 'refine' -and (State $sp).iteration -eq 1)
& $loop -WorkflowId x -Action Advance -Outcome refine_complete -StatePath $sp | Out-Null
& $loop -WorkflowId x -Action Advance -Outcome verify_issues -StatePath $sp | Out-Null
Check "EVR freezes at max iterations" ((State $sp).status -eq 'frozen')

# SDR: scan->doubt->reconcile->blind_spots retries to scan, then ok
$sp = Join-Path $tmp 'sdr.json'
& $loop -WorkflowId keyword_rank_scan -LoopType SDR -Action Start -StatePath $sp | Out-Null
Check "SDR starts at scan" ((State $sp).current_state -eq 'scan')
& $loop -WorkflowId k -Action Advance -Outcome scan_complete -StatePath $sp | Out-Null
& $loop -WorkflowId k -Action Advance -Outcome doubt_complete -StatePath $sp | Out-Null
Check "SDR at reconcile" ((State $sp).current_state -eq 'reconcile')
& $loop -WorkflowId k -Action Advance -Outcome reconcile_blind_spots -StatePath $sp | Out-Null
Check "SDR blind_spots retries to scan (iter 1)" ((State $sp).current_state -eq 'scan' -and (State $sp).iteration -eq 1)
& $loop -WorkflowId k -Action Advance -Outcome scan_complete -StatePath $sp | Out-Null
& $loop -WorkflowId k -Action Advance -Outcome doubt_complete -StatePath $sp | Out-Null
& $loop -WorkflowId k -Action Advance -Outcome reconcile_ok -StatePath $sp | Out-Null
Check "SDR completes on reconcile_ok" ((State $sp).status -eq 'completed')

# PBV: default max iterations = 2, plan->build->verify
$sp = Join-Path $tmp 'pbv.json'
& $loop -WorkflowId listing_optimization -LoopType PBV -Action Start -StatePath $sp | Out-Null
Check "PBV starts at plan, max=2" ((State $sp).current_state -eq 'plan' -and (State $sp).max_iterations -eq 2)
& $loop -WorkflowId l -Action Advance -Outcome plan_ready -StatePath $sp | Out-Null
& $loop -WorkflowId l -Action Advance -Outcome build_complete -StatePath $sp | Out-Null
& $loop -WorkflowId l -Action Advance -Outcome verify_issues -StatePath $sp | Out-Null
Check "PBV verify_issues retries to plan" ((State $sp).current_state -eq 'plan')

# EDA: explore->decide->act->observe
$sp = Join-Path $tmp 'eda.json'
& $loop -WorkflowId competitor_comparison -LoopType EDA -Action Start -StatePath $sp | Out-Null
& $loop -WorkflowId c -Action Advance -Outcome explore_complete -StatePath $sp | Out-Null
& $loop -WorkflowId c -Action Advance -Outcome decide_ok -StatePath $sp | Out-Null
& $loop -WorkflowId c -Action Advance -Outcome act_complete -StatePath $sp | Out-Null
Check "EDA at observe" ((State $sp).current_state -eq 'observe')
& $loop -WorkflowId c -Action Advance -Outcome observe_complete -StatePath $sp | Out-Null
Check "EDA completes on observe_complete" ((State $sp).status -eq 'completed')

# Invalid outcome rejected
$sp = Join-Path $tmp 'inv.json'
& $loop -WorkflowId x -LoopType SDR -Action Start -StatePath $sp | Out-Null
$threw = $false; try { & $loop -WorkflowId x -Action Advance -Outcome verify_pass -StatePath $sp 2>$null } catch { $threw = $true }
Check "invalid outcome for loop rejected" $threw

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "TOTAL FAILURES: $fail"
