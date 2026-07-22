<##
.SYNOPSIS
  Creates an employee lifecycle request without changing identity or access.
##>
param(
  [ValidateSet('join','activate','transfer','suspend','offboard','emergency_offboard')][string]$Action,
  [Parameter(Mandatory=$true)][string]$EmployeeId,[Parameter(Mandatory=$true)][string]$OrganizationId,
  [string]$CurrentDepartmentId='',[string]$NewDepartmentId='',[string]$CurrentManagerApprovalRef='',[string]$NewManagerApprovalRef='',
  [string]$HRApprovalRef='',[string]$SecurityApprovalRef='',[string]$HandoverOwnerId='',[string]$EffectiveAt='',
  [switch]$PassThru
)
$ErrorActionPreference='Stop';if([string]::IsNullOrWhiteSpace($EffectiveAt)){$EffectiveAt=(Get-Date).ToUniversalTime().ToString('o')}
$request=[ordered]@{schema_version=1;request_id='employee-lifecycle-'+[Guid]::NewGuid().ToString('n');action=$Action;employee_id=$EmployeeId;organization_id=$OrganizationId;current_department_id=if($CurrentDepartmentId){$CurrentDepartmentId}else{$null};new_department_id=if($NewDepartmentId){$NewDepartmentId}else{$null};approvals=[ordered]@{current_manager=$CurrentManagerApprovalRef;new_manager=$NewManagerApprovalRef;HR=$HRApprovalRef;security=$SecurityApprovalRef};handover_owner_id=if($HandoverOwnerId){$HandoverOwnerId}else{$null};effective_at=$EffectiveAt;status='requested';changes_applied=$false;created_at=(Get-Date).ToUniversalTime().ToString('o')}
if($PassThru){$request|ConvertTo-Json -Depth 8}else{$request|Format-List}
