<#
.SYNOPSIS
  Validates an Obsidian connector request without reading a Vault or calling MCP.
#>
param(
  [ValidateSet('search_notes','read_selected_note','read_frontmatter','list_backlinks','list_selected_folder','prepare_note_draft_without_vault_write','create_note','update_note','move_note','delete_note','install_plugin','execute_command','export_entire_vault')]
  [Parameter(Mandatory=$true)][string]$Operation,
  [string]$ConnectorId='', [string]$TaskId='', [string]$AgentId='', [string]$GrantId='', [string]$VaultRef='',
  [string[]]$FolderRef=@(), [string[]]$NoteRef=@(), [string]$FileType='.md', [string]$DataClassification='',
  [string]$ApprovalProfile='', [string]$IdempotencyKey='', [string]$SnapshotRef='',
  [switch]$ConnectorEnabled, [switch]$VerifiedAttestation, [switch]$DedicatedWriteAdapter, [switch]$PassThru
)
$ErrorActionPreference='Stop';$reasons=[System.Collections.Generic.List[string]]::new()
foreach($f in @(@{n='connector_id';v=$ConnectorId},@{n='task_id';v=$TaskId},@{n='agent_id';v=$AgentId},@{n='grant_id';v=$GrantId},@{n='vault_ref';v=$VaultRef},@{n='data_classification';v=$DataClassification})){if([string]::IsNullOrWhiteSpace([string]$f.v)){[void]$reasons.Add("missing_$($f.n)")}}
if (-not $ConnectorEnabled) { [void]$reasons.Add('obsidian_connector_disabled') }
if (-not $VerifiedAttestation) { [void]$reasons.Add('verified_attestation_required') }
if ($VaultRef -match '^[A-Za-z]:[\\/]' -or $VaultRef.StartsWith('/') -or $VaultRef -match '\.\.') { [void]$reasons.Add('vault_must_be_reference_only') }
if ($DataClassification -notin @('public','internal_sanitized','confidential_reference_only')) { [void]$reasons.Add('data_classification_denied') }
if ($FileType -ne '.md') { [void]$reasons.Add('file_type_not_allowlisted') }
$alwaysDenied=@('delete_note','install_plugin','execute_command','export_entire_vault');$writes=@('create_note','update_note','move_note');$draft=$Operation-eq'prepare_note_draft_without_vault_write';$requiredLevel=if($writes-contains$Operation){'L4'}elseif($draft){'L3'}else{'L2'}
if ($alwaysDenied -contains $Operation) { [void]$reasons.Add('operation_always_denied') }
if (-not $draft -and @($FolderRef).Count -eq 0 -and @($NoteRef).Count -eq 0) { [void]$reasons.Add('selected_note_or_folder_scope_required') }
foreach ($ref in @($FolderRef) + @($NoteRef)) { if ([string]::IsNullOrWhiteSpace($ref) -or $ref -match '\.\.' -or $ref -match '(^|[\\/])\.(obsidian|git|trash)([\\/]|$)') { [void]$reasons.Add('note_scope_denied') } }
if ($writes -contains $Operation) { if (-not $DedicatedWriteAdapter) { [void]$reasons.Add('dedicated_obsidian_write_adapter_required') };if (@($NoteRef).Count -ne 1) { [void]$reasons.Add('exact_target_note_required') };foreach ($f in @(@{n='approval_profile';v=$ApprovalProfile},@{n='idempotency_key';v=$IdempotencyKey},@{n='snapshot_ref';v=$SnapshotRef})) { if ([string]::IsNullOrWhiteSpace([string]$f.v)) { [void]$reasons.Add("missing_$($f.n)") } } }
$result=[pscustomobject]@{status=if($reasons.Count){'blocked'}else{'allowed'};operation=$Operation;required_level=$requiredLevel;vault_accessed=$false;mcp_called=$false;network_opened=$false;write_performed=$false;reasons=@($reasons)};if($PassThru){$result|ConvertTo-Json -Depth 6}else{$result|Format-List};if($reasons.Count){exit 1}
