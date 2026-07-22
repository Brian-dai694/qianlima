<##
.SYNOPSIS
  Regression tests for the declared Agent pipeline contract.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $PSScriptRoot 'validate-agent-pipeline.ps1'
$traceRoot = Join-Path $projectRoot '.qianlima\run-traces\pipeline-tests'
$stamp=(Get-Date).ToString('yyyyMMddHHmmssfff');New-Item -ItemType Directory -Path $traceRoot -Force|Out-Null
function Invoke-Json([string]$Path) { return (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -PipelinePath $Path -PassThru | ConvertFrom-Json) }
function Invoke-Fail([string]$Path) { $output=@();$code=0;try{$old=$ErrorActionPreference;$ErrorActionPreference='Continue';$output=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -PipelinePath $Path -PassThru 2>&1);$code=$LASTEXITCODE;$ErrorActionPreference=$old}catch{$output+=$_|Out-String;$code=1};return ($code -ne 0 -and ($output -join "`n") -match 'blocked|missing|exceeded|mismatch|forbidden') }
function New-Pipeline([string]$Name) {
  $path=Join-Path $traceRoot "$Name-$stamp.json"
  $pipeline=[ordered]@{pipeline_id=$Name;pipeline_version='1.0.0';task_id="pipeline-task-$stamp";agent_id='codewhale_worker';agent_version='0.8.67';runner_id='docker_local_mock';stages=@('input_reference','classify_and_minimize','authorize','execute','artifact_scan','independent_verify','adopt_or_freeze'|ForEach-Object{[ordered]@{id=$_;status='completed'}});artifact_metadata=[ordered]@{task_id="pipeline-task-$stamp";grant_id='pipeline-grant';agent_id='codewhale_worker';agent_version='0.8.67';runner_id='docker_local_mock';input_hash=('sha256:' + ('a'*64));source_classification='internal_sanitized';created_at=(Get-Date).ToUniversalTime().ToString('o');budget_snapshot=[ordered]@{max_tool_calls=2};verification_status='passed';verifier_id='evidence_checker'};budget=[ordered]@{max_steps=7;max_tool_calls=2;timeout_ms=30000;max_concurrent_agents=1;max_failed_attempts=0;steps_used=7;tool_calls_used=2;failed_attempts=0};backpressure=[ordered]@{on_exhaustion='freeze_and_revoke';on_verifier_backlog='stop_upstream_generation'};final_decision='completed'}
  [IO.File]::WriteAllText($path,($pipeline|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false));return $path
}
$cases=[System.Collections.Generic.List[object]]::new();$validPath=New-Pipeline 'valid';$valid=Invoke-Json $validPath;$cases.Add([PSCustomObject]@{name='valid_declarative_pipeline';passed=($valid.status -eq 'passed' -and $valid.external_calls -eq $false)})
$badPath=New-Pipeline 'bad-order';$bad=Get-Content $badPath -Raw|ConvertFrom-Json;$bad.stages=@($bad.stages|Where-Object{$_.id -ne 'artifact_scan'});[IO.File]::WriteAllText($badPath,($bad|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false));$cases.Add([PSCustomObject]@{name='stage_skip_blocked';passed=(Invoke-Fail $badPath)})
$metadataPath=New-Pipeline 'bad-metadata';$meta=Get-Content $metadataPath -Raw|ConvertFrom-Json;$meta.artifact_metadata.runner_id=$null;[IO.File]::WriteAllText($metadataPath,($meta|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false));$cases.Add([PSCustomObject]@{name='metadata_missing_blocked';passed=(Invoke-Fail $metadataPath)})
$budgetPath=New-Pipeline 'bad-budget';$budget=Get-Content $budgetPath -Raw|ConvertFrom-Json;$budget.budget.tool_calls_used=3;[IO.File]::WriteAllText($budgetPath,($budget|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false));$cases.Add([PSCustomObject]@{name='backpressure_budget_freeze';passed=(Invoke-Fail $budgetPath)})
$secretPath=New-Pipeline 'bad-event';$secret=Get-Content $secretPath -Raw|ConvertFrom-Json;Add-Member -InputObject $secret -MemberType NoteProperty -Name event_fields -Value @('event_id','raw_prompt');[IO.File]::WriteAllText($secretPath,($secret|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false));$cases.Add([PSCustomObject]@{name='sensitive_event_field_blocked';passed=(Invoke-Fail $secretPath)})
$failed=@($cases|Where-Object{-not $_.passed});$result=[PSCustomObject]@{passed=($failed.Count -eq 0);cases=@($cases);external_calls=$false;core_files_changed_by_test=$false};if($PassThru){$result|ConvertTo-Json -Depth 10}else{$cases|Format-Table -AutoSize};if($failed.Count -gt 0){throw "Agent pipeline regression failed: $($failed.name -join ', ')"}
