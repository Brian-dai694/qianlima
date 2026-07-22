<##
.SYNOPSIS
  Creates a five-view Enterprise task brief without executing the task.
##>
param(
  [Parameter(Mandatory=$true)][string]$TaskId,
  [Parameter(Mandatory=$true)][string]$TraceId,
  [Parameter(Mandatory=$true)][string]$Goal,
  [Parameter(Mandatory=$true)][string]$BusinessOwnerId,
  [Parameter(Mandatory=$true)][string]$DepartmentId,
  [Parameter(Mandatory=$true)][string]$ProjectId,
  [Parameter(Mandatory=$true)][string]$CostCenter,
  [ValidateSet('L0','L1','L2','L3','L4')][string]$RiskLevel='L1',
  [Parameter(Mandatory=$true)][string]$ExpectedValue,
  [Parameter(Mandatory=$true)][string]$Deadline,
  [switch]$PassThru
)
$ErrorActionPreference='Stop'
$task=[ordered]@{
  schema_version=1;task_id=$TaskId;trace_id=$TraceId;created_at=(Get-Date).ToUniversalTime().ToString('o')
  business=[ordered]@{goal=$Goal;business_owner_id=$BusinessOwnerId;department_id=$DepartmentId;project_id=$ProjectId;cost_center=$CostCenter;risk_level=$RiskLevel;expected_value=$ExpectedValue;deadline=$Deadline}
  outcome=[ordered]@{status='pending';artifact_refs=@();evidence_refs=@();verification_status='pending';business_result=$null;adoption_status='pending'}
  failure=[ordered]@{status='none';category=$null;failed_stage=$null;impact_scope=$null;retry_eligible=$false;partial_artifact_refs=@();incident_ref=$null}
  core_issue=[ordered]@{status='pending';problem_statement=$null;root_cause=$null;evidence_refs=@();confidence=0;unknowns=@();recurrence_key=$null}
  handling=[ordered]@{status='unassigned';responsible_role=$null;responsible_person_id=$null;next_action=$null;due_at=$null;approval_profile='none';containment=$null;rollback_or_compensation_ref=$null}
}
if($PassThru){$task|ConvertTo-Json -Depth 10}else{$task|Format-List}
