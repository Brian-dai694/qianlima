<##
.SYNOPSIS
  Validates a task-scoped memory read against a live Delegation Grant.
.DESCRIPTION
  This Overlay gate checks identity, expiry, revocation, state view, scope,
  and minimum retrieval size. It returns metadata only and never returns memory
  contents or starts a provider.
##>
param(
  [Parameter(Mandatory = $true)] [string]$RequestPath,
  [Parameter(Mandatory = $true)] [string]$GrantPath,
  [Parameter(Mandatory = $true)] [string]$MemoryPath,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$contract = Get-Content -LiteralPath (Join-Path $projectRoot '.qianlima\specifications\memory-read-contract.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$memoryRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'memory\cards')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$grantRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\delegation-grants')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$request = Get-Content -LiteralPath (Resolve-Path -LiteralPath $RequestPath -ErrorAction Stop) -Raw -Encoding UTF8 | ConvertFrom-Json
$grantFull = (Resolve-Path -LiteralPath $GrantPath -ErrorAction Stop).Path
if (-not $grantFull.StartsWith($grantRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Grant must be inside the governed delegation-grants scope.' }
$grant = Get-Content -LiteralPath $grantFull -Raw -Encoding UTF8 | ConvertFrom-Json
$memoryFull = (Resolve-Path -LiteralPath $MemoryPath -ErrorAction Stop).Path
if (-not $memoryFull.StartsWith($memoryRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Memory must be inside the private memory/cards scope.' }
$memory = Get-Content -LiteralPath $memoryFull -Raw -Encoding UTF8 | ConvertFrom-Json
$rawRequest = Get-Content -LiteralPath (Resolve-Path -LiteralPath $RequestPath).Path -Raw -Encoding UTF8
$violations = [System.Collections.Generic.List[string]]::new()
function Add-Violation([string]$Id) { [void]$violations.Add($Id) }
function Has-Value($Object, [string]$Name) {
  if ($null -eq $Object) { return $false }
  $property = @($Object.PSObject.Properties | Where-Object { $_.Name -eq $Name }) | Select-Object -First 1
  if ($null -eq $property -or $null -eq $property.Value) { return $false }
  if ($property.Value -is [string]) { return -not [string]::IsNullOrWhiteSpace([string]$property.Value) }
  return $true
}
foreach ($field in @($contract.required_fields)) { if (-not (Has-Value $request $field)) { Add-Violation "missing_$field" } }
if ((Has-Value $request 'requested_state_view') -and @($contract.allowed_state_views).IndexOf([string]$request.requested_state_view) -lt 0) { Add-Violation 'invalid_state_view' }
if ((Has-Value $request 'risk_level') -and @($contract.allowed_risk_levels).IndexOf([string]$request.risk_level) -lt 0) { Add-Violation 'invalid_risk_level' }
if ((Has-Value $request 'max_items') -and ([int]$request.max_items -lt 1 -or [int]$request.max_items -gt 20)) { Add-Violation 'max_items_out_of_bounds' }
if ((Has-Value $request 'memory_refs') -and @($request.memory_refs).Count -gt [int]$request.max_items) { Add-Violation 'memory_item_budget_exceeded' }
if ([string]$request.task_id -ne [string]$grant.task_id) { Add-Violation 'task_grant_mismatch' }
if ([string]$request.grant_id -ne [string]$grant.grant_id) { Add-Violation 'grant_id_mismatch' }
if ([string]$request.agent_id -ne [string]$grant.agent_id) { Add-Violation 'agent_grant_mismatch' }
if ([string]$grant.status -ne 'issued') { Add-Violation "grant_not_issued_$($grant.status)" }
if ((Get-Date).ToUniversalTime() -ge [DateTime]::Parse($grant.expires_at).ToUniversalTime()) { Add-Violation 'grant_expired' }
$revocationPath = Join-Path $projectRoot '.qianlima\run-traces\grant-revocations.jsonl'
if (Test-Path -LiteralPath $revocationPath -PathType Leaf) { foreach ($line in @(Get-Content -LiteralPath $revocationPath -Encoding UTF8)) { if ([string]::IsNullOrWhiteSpace($line)) { continue }; try { $revocation = $line | ConvertFrom-Json; if ([string]$revocation.grant_id -eq [string]$grant.grant_id) { Add-Violation 'grant_revoked' } } catch { Add-Violation 'revocation_log_invalid' } } }
foreach ($ref in @($request.memory_refs)) { if (@($grant.data_refs | ForEach-Object { [string]$_ }) -notcontains [string]$ref) { Add-Violation "memory_ref_outside_grant_$ref" } }
if ([string]$request.requested_state_view -eq 'current' -and [string]$memory.state -ne 'current') { Add-Violation 'non_current_memory_in_current_view' }
if ([string]$request.requested_state_view -eq 'audit' -and [string]$request.risk_level -eq 'L4') { Add-Violation 'audit_view_cannot_authorize_L4_decision' }
if ([string]$request.risk_level -eq 'L4') { Add-Violation 'L4_requires_original_source_reload' }
if ([string]$memory.state -eq 'revoked') { Add-Violation 'revoked_memory_unusable' }
if ([string]$memory.classification -notin @($contract.allowed_classifications)) { Add-Violation 'memory_classification_not_allowed' }
foreach ($field in @($contract.prohibited_fields)) { if ($rawRequest -match ('(?i)"' + [regex]::Escape($field) + '"\s*:')) { Add-Violation "prohibited_request_field_$field" } }
$status = if ($violations.Count -eq 0) { 'allowed' } else { 'denied' }
$result = [ordered]@{ status = $status; request_id = $request.request_id; task_id = $request.task_id; grant_id = $request.grant_id; agent_id = $request.agent_id; state_view = $request.requested_state_view; memory_state = $memory.state; items_returned = if ($status -eq 'allowed') { 1 } else { 0 }; contents_returned = $false; source_reload_required = ([string]$request.risk_level -eq 'L4'); violations = @($violations); external_calls = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List }
if ($status -ne 'allowed') { exit 1 }
