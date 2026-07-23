<##
.SYNOPSIS
  Tests Qianlima execution planning, read-only CSV execution, and EVR convergence.
##>
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$planScript = Join-Path $PSScriptRoot 'new-qianlima-execution-plan.ps1'
$runnerScript = Join-Path $PSScriptRoot 'invoke-qianlima-readonly-runner.ps1'
$evrScript = Join-Path $PSScriptRoot 'invoke-qianlima-evr.ps1'
$testId = 'execution-plan-test-' + [Guid]::NewGuid().ToString('n')
$planPath = Join-Path $root ".qianlima\run-traces\execution-plans\$testId.json"
$csvPath = Join-Path $root ".qianlima\tmp\$testId.csv"
$stepsPath = Join-Path $root ".qianlima\tmp\$testId-steps.json"
$eventPath = Join-Path $root ".qianlima\run-traces\evr\$testId.jsonl"
$artifactPath = Join-Path $root ".qianlima\run-traces\readonly-runner\$testId-aggregate.json"
$metricsPath = Join-Path $root ".qianlima\run-traces\readonly-runner\$testId-aggregate-metrics.json"
$checks = [System.Collections.Generic.List[object]]::new()
function Check([string]$Name, [bool]$Passed) { [void]$checks.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
function Run([string]$Script, [string[]]$Arguments, [int]$ExpectedCode = 0) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1); $code = $LASTEXITCODE } finally { $ErrorActionPreference = $old }
  if ($code -ne $ExpectedCode) { throw "Unexpected exit code $code, expected $ExpectedCode. Output: $($output -join "`n")" }
  return $output
}
try {
  New-Item -ItemType Directory -Path (Split-Path -Parent $csvPath) -Force | Out-Null
  [IO.File]::WriteAllText($csvPath, "campaign,spend,sales`nalpha,10,50`nbeta,5,20`n", (New-Object Text.UTF8Encoding($false)))
  $steps = @(@{ step_id = 'aggregate'; action = 'read_selected_sources'; input_refs = @('.qianlima/tmp/' + $testId + '.csv'); allowed_tools = @('local_csv_reader', 'compute_metrics'); expected_output = 'numeric_summary'; verification = 'row count and metric fields are present' })
  $stepsJson = $steps | ConvertTo-Json -Depth 8 -Compress
  [IO.File]::WriteAllText($stepsPath, $stepsJson, (New-Object Text.UTF8Encoding($false)))
  Run $planScript @('-PlanId',$testId,'-TaskId',$testId,'-Workflow','daily_ad_report','-Goal','Aggregate a selected local CSV.','-DataScope','.qianlima/tmp','-StepsPath',$stepsPath,'-RiskLevel','L2') | Out-Null
  Check 'execution_plan_created' (Test-Path -LiteralPath $planPath -PathType Leaf)
  $createdPlan = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Check 'task_state_machine_is_declared' (@($createdPlan.task_state_machine.states) -contains 'frozen' -and @($createdPlan.task_state_machine.states) -contains 'stopped')
  Check 'plan_is_replayable' ($createdPlan.replayable -eq $true -and $createdPlan.task_state_machine.replay_inputs_are_references_only -eq $true)
  Run $evrScript @('-Action','execute','-PlanPath',$planPath,'-PassThru') | Out-Null
  Run $runnerScript @('-PlanPath',$planPath,'-StepId','aggregate','-InputPath',$csvPath,'-NumericColumn','spend,sales','-GroupBy','campaign','-PassThru') | Out-Null
  Run $evrScript @('-Action','verify','-PlanPath',$planPath,'-PassThru') | Out-Null
  $statusOutput = Run $evrScript @('-Action','status','-PlanPath',$planPath,'-PassThru')
  $statusText = ($statusOutput -join "`n"); $start = $statusText.IndexOf('{'); $end = $statusText.LastIndexOf('}'); $status = $statusText.Substring($start, $end - $start + 1) | ConvertFrom-Json
  Check 'evr_converges_after_verified_step' ($status.state -eq 'completed')
  Check 'readonly_artifact_created' (Test-Path -LiteralPath $artifactPath -PathType Leaf)
  Check 'step_result_created' (@(Get-ChildItem -LiteralPath (Join-Path $root '.qianlima\run-traces\step-results') -File -Filter "$testId-*.json" -ErrorAction SilentlyContinue).Count -eq 1)
  $badSteps = @(@{ step_id = 'bad'; action = 'read_selected_sources'; input_refs = @('x'); allowed_tools = @('network'); expected_output = 'x'; verification = 'x' }) | ConvertTo-Json -Depth 8 -Compress
  Run $planScript @('-PlanId',($testId + '-bad'),'-TaskId',$testId,'-Workflow','bad','-Goal','bad','-DataScope','.qianlima/tmp','-StepsJson',$badSteps) -ExpectedCode 1 | Out-Null
  Check 'forbidden_tool_plan_denied' $true
} catch {
  Check 'unexpected_test_error' $false
  Write-Error $_
} finally {
  Remove-Item -LiteralPath $planPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $csvPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $stepsPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $eventPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $artifactPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $metricsPath -Force -ErrorAction SilentlyContinue
  Get-ChildItem -LiteralPath (Join-Path $root '.qianlima\run-traces\step-results') -File -Filter "$testId-*.json" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}
$failed = @($checks | Where-Object { -not $_.passed })
$checks | ForEach-Object { Write-Host ("{0}: {1}" -f $_.name, $(if ($_.passed) { 'PASS' } else { 'FAIL' })) }
if ($failed.Count -gt 0) { exit 1 }
