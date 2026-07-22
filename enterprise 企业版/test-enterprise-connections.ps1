<##
.SYNOPSIS
  Regression tests for responsibility-routed enterprise connections.
##>
param([switch]$PassThru)
$ErrorActionPreference='Stop';$gate=Join-Path $PSScriptRoot 'invoke-enterprise-connection-gate.ps1';$cases=[System.Collections.Generic.List[object]]::new()
function Run-Gate([string[]]$Arguments){$old=$ErrorActionPreference;$ErrorActionPreference='Continue';$output=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $gate @Arguments -PassThru 2>&1);$code=$LASTEXITCODE;$ErrorActionPreference=$old;$value=$null;try{$value=($output-join"`n")|ConvertFrom-Json}catch{};[PSCustomObject]@{exit_code=$code;value=$value}}
function Add-Case([string]$Name,[bool]$Passed){$cases.Add([PSCustomObject]@{name=$Name;passed=$Passed})}
$base=@('-Type','sharepoint_onedrive','-Enabled','-EndpointRef','site-ref','-CredentialRef','site-read-ref','-OwnerId','owner','-OrganizationId','org','-CostCenter','cc','-GrantId','g1','-AttestationStatus','verified')
$disabled=Run-Gate @('-Type','sharepoint_onedrive','-Operation','list_selected');Add-Case 'disabled_connection_denied' ($disabled.exit_code-ne 0)
$artifact=Run-Gate (@('-Operation','write_task_artifact')+$base);Add-Case 'task_artifact_write_is_L2' ($artifact.exit_code-eq 0-and $artifact.value.required_level-eq'L2')
$cleanup=Run-Gate (@('-Operation','delete_task_cache')+$base);Add-Case 'task_cache_cleanup_is_L2' ($cleanup.exit_code-eq 0-and $cleanup.value.required_level-eq'L2')
$internal=Run-Gate (@('-Operation','upload_internal_project')+$base);Add-Case 'internal_project_upload_is_L3' ($internal.exit_code-eq 0-and $internal.value.required_level-eq'L3')
$routine=Run-Gate (@('-Operation','overwrite_source','-ApprovalProfile','routine_reversible','-ApproverRoles','department_manager','-SnapshotOrIdempotencyRef','s1','-RollbackOrCompensationRef','r1')+$base);Add-Case 'formal_overwrite_routes_to_responsible_manager' ($routine.exit_code-eq 0-and $routine.value.business_owner_required-eq$false)
$batch=Run-Gate (@('-Operation','business_write','-ApprovalProfile','routine_reversible','-BatchApprovalId','b1','-BatchApprovalStatus','valid','-WithinApprovedThreshold','-SnapshotOrIdempotencyRef','i1','-RollbackOrCompensationRef','r1')+$base);Add-Case 'batch_approval_avoids_per_action_click' ($batch.exit_code-eq 0-and $batch.value.approval_route-eq'valid_batch_approval')
$external=Run-Gate (@('-Operation','send_external','-ApprovalProfile','data_external','-DataClassification','confidential_reference_only','-ApproverRoles','data_owner','-SnapshotOrIdempotencyRef','i1','-RollbackOrCompensationRef','r1')+$base);Add-Case 'confidential_external_send_adds_security' ($external.exit_code-ne 0-and @($external.value.reasons)-contains'security_approval_required_for_confidential_external_send')
$failed=@($cases|Where-Object{-not $_.passed});$result=[PSCustomObject]@{passed=($failed.Count-eq 0);cases=@($cases);network_opened=$false;files_written=$false};if($PassThru){$result|ConvertTo-Json -Depth 8}else{$cases|Format-Table -AutoSize};if($failed.Count-gt 0){throw "Enterprise connection regression failed: $($failed.name-join', ')"}
