$d = Join-Path $PSScriptRoot '..\.qianlima\scripts'
$fail = 0
function Check($name, $cond) {
  if ($cond) { Write-Host "PASS: $name" } else { Write-Host "FAIL: $name"; $script:fail++ }
}
$r = & "$d\get-model-cost.ps1" -Provider deepseek -Model deepseek-v4-flash -InputTokens 1000000 -OutputTokens 1000000 -AsJson | ConvertFrom-Json
Check "priced status" ($r.status -eq 'priced')
Check "estimated_cost=3" ($r.estimated_cost -eq 3)
$r2 = & "$d\get-model-cost.ps1" -Provider anthropic -Model claude-opus-4-8 -InputTokens 1000 -OutputTokens 1000 -AsJson | ConvertFrom-Json
Check "source_only" ($r2.status -eq 'source_only')
$t = $false; try { & "$d\get-model-cost.ps1" -Provider deepseek -Model deepseek-v4-flash -InputTokens -1 -AsJson 2>$null } catch { $t = $true }
Check "neg tokens throws" $t
$t = $false; try { & "$d\get-model-cost.ps1" -Provider deepseek -Model deepseek-v4-flash -InputTokens 100 -CachedInputTokens 200 -AsJson 2>$null } catch { $t = $true }
Check "cached>input throws" $t
$ru = & "$d\get-model-cost.ps1" -Provider nobody -Model ghost-1 -InputTokens 10 -OutputTokens 10 -AsJson | ConvertFrom-Json
Check "unknown model source_only" ($ru.status -eq 'source_only' -and [string]::IsNullOrEmpty($ru.source_url))
$s = & "$d\check-command-safety.ps1" -Command 'Get-ChildItem' -AsJson -NoExit | ConvertFrom-Json
Check "benign allow" ($s.classification -eq 'allow' -and $s.required_action -eq 'may_continue')
$s2 = & "$d\check-command-safety.ps1" -Command 'Remove-Item -Recurse -Force C:\Windows' -AsJson -NoExit | ConvertFrom-Json
Check "sys delete deny" ($s2.classification -eq 'deny' -and $s2.destructive)
$s3 = & "$d\check-command-safety.ps1" -Command 'del important.txt' -AsJson -NoExit | ConvertFrom-Json
Check "del destructive not-allow" ($s3.destructive -and $s3.classification -ne 'allow')
& "$d\check-command-safety.ps1" -Command 'Remove-Item -Recurse -Force C:\Windows' -AsJson | Out-Null
Check "deny exit=20" ($LASTEXITCODE -eq 20)
Write-Host ""
Write-Host "TOTAL FAILURES: $fail"
