<##
.SYNOPSIS
  Failure-injection regression for the governed Trace Envelope.
  All traces are synthetic; no Agent, provider, Docker, or business data is used.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $PSScriptRoot 'validate-run-trace.ps1'
$traceRoot = Join-Path $projectRoot '.qianlima\run-traces\trace-failure-tests'
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
New-Item -ItemType Directory -Path $traceRoot -Force | Out-Null
function New-Trace([string]$Name, [string]$Status = 'completed') {
  $trace = [ordered]@{
    trace_id = "trace-$Name-$stamp"; run_id = "run-$Name-$stamp"; task_id = "task-$Name-$stamp"; agent_id = 'codewhale_worker'; agent_version = '0.8.67'; approved_agent_version = '0.8.67'; runner_id = 'docker_local_mock'; policy_version = '1.0.0'; protocol_version = '1.0.0'; created_at = (Get-Date).ToUniversalTime().ToString('o'); terminal_status = $Status
    budget_snapshot = [ordered]@{ max_steps = 6; max_tool_calls = 3; timeout_ms = 90000; steps_used = 2; tool_calls_used = 1 }
    grant_ref = [ordered]@{ trace_id = "trace-$Name-$stamp"; task_id = "task-$Name-$stamp"; agent_id = 'codewhale_worker' }; artifact_refs = @(); evidence_refs = @(); audit_event_refs = @()
    linked_contracts = @([ordered]@{ trace_id = "trace-$Name-$stamp"; task_id = "task-$Name-$stamp"; agent_id = 'codewhale_worker' })
    events = @([ordered]@{ event_id = "event-$Name-$stamp"; event_type = 'session_start'; task_id = "task-$Name-$stamp"; agent_id = 'codewhale_worker'; created_at = (Get-Date).ToUniversalTime().ToString('o'); decision = 'allow' })
  }
  return $trace
}
function Write-Trace($Trace, [string]$Name) { $path = Join-Path $traceRoot "$Name-$stamp.json"; [IO.File]::WriteAllText($path, ($Trace | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false)); return $path }
function Invoke-Trace([string]$Path) { $output=@();$code=0;try{$old=$ErrorActionPreference;$ErrorActionPreference='Continue';$output=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -TracePath $Path -PassThru 2>&1);$code=$LASTEXITCODE;$ErrorActionPreference=$old}catch{$output+=$_|Out-String;$code=1};return [PSCustomObject]@{code=$code;text=($output -join "`n")}}
function Add-Case([System.Collections.Generic.List[object]]$Cases, [string]$Name, [bool]$Passed) { $Cases.Add([PSCustomObject]@{name=$Name;passed=$Passed}) }
$cases=[System.Collections.Generic.List[object]]::new()
$validPath=Write-Trace (New-Trace 'valid') 'valid';$valid=Invoke-Trace $validPath;Add-Case $cases 'valid_trace_passed' ($valid.code -eq 0)
$scenarios=@(
  @{name='expired_grant';action='deny_before_tool_use';status='rejected'},
  @{name='revoked_grant';action='deny_before_tool_use';status='rejected'},
  @{name='version_drift';action='trust_reset_and_freeze';status='frozen'},
  @{name='artifact_hash_mismatch';action='reject_artifact_and_freeze';status='frozen'},
  @{name='budget_exceeded';action='revoke_and_freeze';status='frozen'},
  @{name='verification_conflict';action='freeze_and_require_human';status='frozen'},
  @{name='cancelled_downstream';action='stop_pending_downstream';status='cancelled'}
)
foreach($scenario in $scenarios){$trace=New-Trace $scenario.name $scenario.status;$trace.failure_scenario=$scenario.name;$trace.failure_action=$scenario.action;if($scenario.name -eq 'artifact_hash_mismatch'){$trace.artifact_status='rejected'};if($scenario.name -eq 'cancelled_downstream'){$trace.pending_downstream=0};if($scenario.name -eq 'version_drift'){$trace.approved_agent_version='0.8.66'};if($scenario.name -eq 'budget_exceeded'){$trace.budget_snapshot.steps_used=7;$trace.budget_snapshot.max_steps=6};$path=Write-Trace $trace $scenario.name;$result=Invoke-Trace $path;$handled=($result.code -eq 0);if($scenario.name -in @('version_drift','budget_exceeded')){$jsonStart=$result.text.IndexOf('{');$jsonEnd=$result.text.LastIndexOf('}');$parsed=$null;if($jsonStart -ge 0 -and $jsonEnd -gt $jsonStart){try{$parsed=$result.text.Substring($jsonStart,$jsonEnd-$jsonStart+1)|ConvertFrom-Json}catch{}};$handled=($result.code -ne 0 -and $null -ne $parsed -and $parsed.terminal_status -eq 'frozen' -and $parsed.revoke_required -eq $true)};Add-Case $cases "failure_$($scenario.name)_handled" $handled}
$bad=New-Trace 'hash-mismatch-bad';$bad.failure_scenario='artifact_hash_mismatch';$bad.failure_action='revoke_and_freeze';$bad.artifact_status='completed';$badPath=Write-Trace $bad 'hash-mismatch-bad';$badResult=Invoke-Trace $badPath;Add-Case $cases 'failure_action_mismatch_blocked' ($badResult.code -ne 0)
$secret=New-Trace 'secret-event';$secretEvent=[ordered]@{event_id='event-secret';event_type='session_start';task_id=$secret.task_id;agent_id=$secret.agent_id;created_at=(Get-Date).ToUniversalTime().ToString('o');decision='allow';raw_prompt='SYNTHETIC_SHOULD_BLOCK'};$secret.events=@($secretEvent);$secretPath=Write-Trace $secret 'secret-event';$secretResult=Invoke-Trace $secretPath;Add-Case $cases 'prohibited_trace_field_blocked' ($secretResult.code -ne 0)
$failed=@($cases|Where-Object{-not $_.passed});$result=[PSCustomObject]@{passed=($failed.Count -eq 0);cases=@($cases);external_calls=$false;secret_values_recorded=$false;core_files_changed_by_test=$false};if($PassThru){$result|ConvertTo-Json -Depth 10}else{$cases|Format-Table -AutoSize};if($failed.Count -gt 0){throw "Trace failure-injection regression failed: $($failed.name -join ', ')"}
