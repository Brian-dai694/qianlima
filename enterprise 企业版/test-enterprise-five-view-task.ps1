<##
.SYNOPSIS
  Regression tests for the five-view Enterprise task contract.
##>
param([switch]$PassThru)
$ErrorActionPreference='Stop';$contract=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'five-view-task-contract.json') -Raw -Encoding UTF8|ConvertFrom-Json;$creator=Join-Path $PSScriptRoot 'new-five-view-task.ps1';$cases=[System.Collections.Generic.List[object]]::new();function Add-Case([string]$Name,[bool]$Passed){$cases.Add([PSCustomObject]@{name=$Name;passed=$Passed})}
$task=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $creator -TaskId task1 -TraceId trace1 -Goal 'Improve delivery quality' -BusinessOwnerId owner1 -DepartmentId dept1 -ProjectId project1 -CostCenter cc1 -RiskLevel L3 -ExpectedValue 'Verified result' -Deadline '2026-08-01' -PassThru|ConvertFrom-Json
Add-Case 'all_five_views_present' (@('business','outcome','failure','core_issue','handling'|Where-Object{$null-eq $task.$_}).Count-eq 0)
Add-Case 'single_task_and_trace_lineage' ($task.task_id-eq'task1'-and $task.trace_id-eq'trace1')
Add-Case 'outcome_starts_pending' ($task.outcome.status-eq'pending'-and $task.outcome.artifact_refs.Count-eq 0)
Add-Case 'failure_does_not_claim_failure_before_event' ($task.failure.status-eq'none'-and $task.failure.retry_eligible-eq$false)
Add-Case 'handling_requires_assignment' ($task.handling.status-eq'unassigned'-and $task.handling.approval_profile-eq'none')
Add-Case 'owner_view_is_summary_first' (@($contract.visibility_defaults.business_owner)-contains'business'-and @($contract.visibility_defaults.business_owner)-contains'outcome')
$failed=@($cases|Where-Object{-not $_.passed});$result=[PSCustomObject]@{passed=($failed.Count-eq 0);cases=@($cases);files_written=$false;execution_authorized=$false};if($PassThru){$result|ConvertTo-Json -Depth 8}else{$cases|Format-Table -AutoSize};if($failed.Count-gt 0){throw "Five-view task regression failed: $($failed.name-join', ')"}
