param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = Join-Path $projectRoot '.qianlima\run-traces'
$workingRoot = Join-Path $projectRoot '.qianlima\working'
$runner = Join-Path $PSScriptRoot 'invoke-personal-governed-loop.ps1'
$testRoot = Join-Path $workingRoot ('personal-governed-loop-test-' + [Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$cases = New-Object System.Collections.Generic.List[object]

function Invoke-Loop([string[]]$Arguments) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner @Arguments 2>&1; $code = $LASTEXITCODE } finally { $ErrorActionPreference = $old }
  if ($code -ne 0) { throw ($output -join "`n") }
  return (($output -join "`n") | ConvertFrom-Json)
}
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
function New-CheckerOutput([string]$Name) {
  $path = Join-Path $testRoot "$Name.txt"
  [IO.File]::WriteAllBytes($path, [Text.UTF8Encoding]::new($false).GetBytes("checker raw output: $Name`r`n原样保留"))
  return $path
}
function New-Run([string]$Name, [string]$Outcome, [string]$Checker = '') {
  $task = "loop-$Name-$([Guid]::NewGuid().ToString('n').Substring(0, 8))"
  $run = "run-$Name-$([Guid]::NewGuid().ToString('n').Substring(0, 8))"
  $start = Invoke-Loop @('-Action', 'Start', '-TaskId', $task, '-RunId', $run, '-PassThru')
  $args = @('-Action', 'Check', '-TaskId', $task, '-RunId', $run, '-Outcome', $Outcome, '-PassThru')
  if ($Checker) { $args += @('-CheckerOutputPath', $Checker) }
  $check = Invoke-Loop $args
  return [PSCustomObject]@{ task = $task; run = $run; start = $start; check = $check }
}

$rawPath = New-CheckerOutput 'raw-checker'
$rawRun = New-Run 'raw' 'all_green' $rawPath
$rawTrace = Join-Path $traceRoot "personal-loop-$($rawRun.run)\checker-1.txt"
$rawExpected = [Convert]::ToBase64String([IO.File]::ReadAllBytes($rawPath))
$rawActual = [Convert]::ToBase64String([IO.File]::ReadAllBytes($rawTrace))
Add-Case 'all_green_completes' ($rawRun.check.status -eq 'completed' -and $rawRun.check.stop_reason -eq 'all_green')
Add-Case 'checker_output_preserved_raw' ($rawRun.check.checker_output_ref -match 'checker-1\.txt' -and $rawExpected -eq $rawActual -and $rawRun.check.checker_output_hash -match '^sha256:[0-9a-f]{64}$')
Add-Case 'roles_and_permissions_bounded' ($rawRun.start.network_access -eq 'none' -and $rawRun.start.business_write_access -eq 'none' -and $rawRun.start.direct_agent_to_agent -eq $false)

$maxTask = "loop-max-$([Guid]::NewGuid().ToString('n').Substring(0, 8))"; $maxRun = "run-max-$([Guid]::NewGuid().ToString('n').Substring(0, 8))"; Invoke-Loop @('-Action', 'Start', '-TaskId', $maxTask, '-RunId', $maxRun, '-MaxRounds', '5', '-PassThru') | Out-Null
$maxChecks = @(); for ($i = 1; $i -le 5; $i++) { $maxChecks += Invoke-Loop @('-Action', 'Check', '-TaskId', $maxTask, '-RunId', $maxRun, '-Outcome', 'check_failed', '-PassThru') }
Add-Case 'max_five_rounds_freezes' ($maxChecks[-1].status -eq 'frozen' -and $maxChecks[-1].stop_reason -eq 'max_rounds' -and $maxChecks[-1].round -eq 5)

$sameTask = "loop-same-$([Guid]::NewGuid().ToString('n').Substring(0, 8))"; $sameRun = "run-same-$([Guid]::NewGuid().ToString('n').Substring(0, 8))"; Invoke-Loop @('-Action', 'Start', '-TaskId', $sameTask, '-RunId', $sameRun, '-PassThru') | Out-Null; Invoke-Loop @('-Action', 'Check', '-TaskId', $sameTask, '-RunId', $sameRun, '-Outcome', 'same_failure', '-FailureSignature', 'same-test', '-PassThru') | Out-Null; $sameFinal = Invoke-Loop @('-Action', 'Check', '-TaskId', $sameTask, '-RunId', $sameRun, '-Outcome', 'same_failure', '-FailureSignature', 'same-test', '-PassThru')
Add-Case 'same_failure_twice_freezes' ($sameFinal.status -eq 'frozen' -and $sameFinal.stop_reason -eq 'same_failure_twice')

$regression = New-Run 'regression' 'regression'; Add-Case 'regression_freezes' ($regression.check.status -eq 'frozen' -and $regression.check.stop_reason -eq 'regression')
$progressTask = "loop-progress-$([Guid]::NewGuid().ToString('n').Substring(0, 8))"; $progressRun = "run-progress-$([Guid]::NewGuid().ToString('n').Substring(0, 8))"; Invoke-Loop @('-Action', 'Start', '-TaskId', $progressTask, '-RunId', $progressRun, '-PassThru') | Out-Null; Invoke-Loop @('-Action', 'Check', '-TaskId', $progressTask, '-RunId', $progressRun, '-Outcome', 'no_progress', '-PassThru') | Out-Null; $progressFinal = Invoke-Loop @('-Action', 'Check', '-TaskId', $progressTask, '-RunId', $progressRun, '-Outcome', 'no_progress', '-PassThru')
Add-Case 'no_progress_twice_freezes' ($progressFinal.status -eq 'frozen' -and $progressFinal.stop_reason -eq 'no_progress_twice')
$cancelled = New-Run 'cancelled' 'user_cancel'; Add-Case 'user_cancel_stops' ($cancelled.check.status -eq 'stopped' -and $cancelled.check.stop_reason -eq 'user_cancel')

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ suite = 'personal_governed_loop'; passed = ($failed.Count -eq 0); total = $cases.Count; passed_count = ($cases.Count - $failed.Count); cases = $cases; network_calls = $false; background_tasks = $false; business_writes = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $cases | Format-Table -AutoSize; Write-Host ("Personal governed loop: {0}/{1} PASS" -f $result.passed_count, $result.total) }
if ($failed.Count -gt 0) { throw "Personal governed loop regression failed: $($failed.name -join ', ')" }
