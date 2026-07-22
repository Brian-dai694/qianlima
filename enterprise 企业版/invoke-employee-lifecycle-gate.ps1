<##
.SYNOPSIS
  Validates an employee lifecycle request and emits required actions.
.DESCRIPTION
  This gate never calls HR, SSO, SCIM, device, Agent, MCP, or credential systems.
##>
param([Parameter(Mandatory=$true)][string]$RequestJson,[switch]$PassThru)
$ErrorActionPreference='Stop';$request=$RequestJson|ConvertFrom-Json;$reasons=[System.Collections.Generic.List[string]]::new();$actions=[System.Collections.Generic.List[string]]::new()
function Require([string]$Name,[object]$Value){if($null-eq$Value-or[string]::IsNullOrWhiteSpace([string]$Value)){[void]$reasons.Add("missing_$Name")}}
Require 'employee_id' $request.employee_id;Require 'organization_id' $request.organization_id;Require 'effective_at' $request.effective_at
switch([string]$request.action){
  'join'{Require 'new_department_id' $request.new_department_id;Require 'new_manager_approval_ref' $request.approvals.new_manager;@('create_invited_identity','assign_default_employee_role','set_department_scope','deny_MCP_until_approved')|ForEach-Object{[void]$actions.Add($_)}}
  'activate'{Require 'new_department_id' $request.new_department_id;Require 'new_manager_approval_ref' $request.approvals.new_manager;@('activate_identity','start_device_enrollment','keep_Agent_T0_until_admission')|ForEach-Object{[void]$actions.Add($_)}}
  'transfer'{Require 'current_department_id' $request.current_department_id;Require 'new_department_id' $request.new_department_id;Require 'current_manager_approval_ref' $request.approvals.current_manager;Require 'new_manager_approval_ref' $request.approvals.new_manager;if($request.current_department_id-eq$request.new_department_id){[void]$reasons.Add('new_department_must_differ')};@('freeze_new_work','revoke_old_department_grants','revoke_direct_MCP_sessions','handover_open_tasks','change_department','recalculate_scope')|ForEach-Object{[void]$actions.Add($_)}}
  'suspend'{if([string]::IsNullOrWhiteSpace($request.approvals.current_manager)-and[string]::IsNullOrWhiteSpace($request.approvals.HR)-and[string]::IsNullOrWhiteSpace($request.approvals.security)){[void]$reasons.Add('manager_HR_or_security_approval_required')};@('disable_new_login','freeze_new_work','revoke_active_grants','revoke_direct_MCP_sessions','preserve_history')|ForEach-Object{[void]$actions.Add($_)}}
  'offboard'{Require 'HR_approval_ref' $request.approvals.HR;Require 'current_manager_approval_ref' $request.approvals.current_manager;Require 'handover_owner_id' $request.handover_owner_id;@('disable_identity','terminate_Agent_sessions','revoke_all_grants','revoke_direct_MCP_sessions','revoke_credentials','isolate_or_recover_devices','transfer_tasks_and_artifacts','stop_cost_attribution','preserve_history')|ForEach-Object{[void]$actions.Add($_)}}
  'emergency_offboard'{Require 'security_approval_ref' $request.approvals.security;@('disable_identity_immediately','terminate_Agent_sessions','revoke_all_grants','revoke_direct_MCP_sessions','isolate_devices','create_incident_and_follow_up_handover')|ForEach-Object{[void]$actions.Add($_)}}
  default{[void]$reasons.Add('unknown_lifecycle_action')}
}
$result=[PSCustomObject]@{status=if($reasons.Count-eq 0){'approved_plan'}else{'blocked'};action=$request.action;employee_id=$request.employee_id;required_actions=@($actions);reasons=@($reasons);changes_applied=$false;external_calls=$false};if($PassThru){$result|ConvertTo-Json -Depth 8}else{$result|Format-List};if($reasons.Count-gt 0-and-not $PassThru){exit 1}
