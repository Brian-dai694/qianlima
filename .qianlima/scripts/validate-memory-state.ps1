<##
.SYNOPSIS
  Validates a memory entry and applies an explicit current/historical query view.
##>
param(
  [Parameter(Mandatory = $true)] [string]$MemoryPath,
  [Parameter(Mandatory = $true)] [ValidateSet('current','historical','audit')] [string]$View,
  [ValidateSet('L0','L1','L2','L3','L4')] [string]$RiskLevel = 'L1',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$memoryRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'memory\cards')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$contract = Get-Content -LiteralPath (Join-Path $projectRoot '.qianlima\specifications\memory-state-contract.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$resolved = Resolve-Path -LiteralPath $MemoryPath -ErrorAction Stop
$fullPath = [string]$resolved.Path
if (-not $fullPath.StartsWith($memoryRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Memory entry must be inside the private memory/cards scope.' }
$entry = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8 | ConvertFrom-Json
$violations = [System.Collections.Generic.List[string]]::new()
function Add-Violation([string]$Id) { [void]$violations.Add($Id) }
function Has-Value($Object, [string]$Name) {
  if ($null -eq $Object) { return $false }
  $property = @($Object.PSObject.Properties | Where-Object { $_.Name -eq $Name }) | Select-Object -First 1
  if ($null -eq $property -or $null -eq $property.Value) { return $false }
  if ($property.Value -is [string]) { return -not [string]::IsNullOrWhiteSpace([string]$property.Value) }
  return $true
}
foreach ($field in @($contract.required_entry_fields)) { if (-not (Has-Value $entry $field)) { Add-Violation "missing_$field" } }
if ((Has-Value $entry 'state')) { $entryState = [string]$entry.state; if (@('current','historical','transitional','superseded','disputed','revoked').IndexOf($entryState) -lt 0) { Add-Violation 'invalid_state' } }
if ((Has-Value $entry 'kind')) { $entryKind = [string]$entry.kind; if (@('fact','preference','task_state','learned_rule').IndexOf($entryKind) -lt 0) { Add-Violation 'invalid_kind' } }
if ((Has-Value $entry 'classification')) { $entryClass = [string]$entry.classification; if (@('public','internal_sanitized','confidential_reference_only').IndexOf($entryClass) -lt 0) { Add-Violation 'invalid_classification' } }
if ((Has-Value $entry 'source_refs') -and @($entry.source_refs).Count -eq 0) { Add-Violation 'source_refs_empty' }
if ((Has-Value $entry 'confidence')) { $entryConfidence = [string]$entry.confidence; if (@('high','medium','low').IndexOf($entryConfidence) -lt 0) { Add-Violation 'invalid_confidence' } }
if (Has-Value $entry 'valid_from' -and Has-Value $entry 'valid_to') {
  if ([datetime]::Parse($entry.valid_to).ToUniversalTime() -lt [datetime]::Parse($entry.valid_from).ToUniversalTime()) { Add-Violation 'validity_range_inverted' }
}
$viewRule = $contract.query_views.$View
$state = [string]$entry.state
if (@($viewRule.exclude_states).IndexOf($state) -ge 0) { Add-Violation "state_excluded_from_$View`_view" }
if (@($viewRule.allowed_states).IndexOf($state) -lt 0) { Add-Violation "state_not_allowed_in_$View`_view" }
if ($View -eq 'current' -and $state -ne 'current') { Add-Violation 'current_view_requires_current_state' }
if ($View -eq 'current' -and $RiskLevel -eq 'L4') { Add-Violation 'L4_requires_original_source_reload' }
if ($state -eq 'transitional' -or $state -eq 'disputed') { Add-Violation 'not_decision_ready' }
if ($state -eq 'revoked') { Add-Violation 'revoked_memory_unusable' }
$raw = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8
foreach ($forbidden in @($contract.prohibited_fields)) { if ($raw -match [regex]::Escape($forbidden)) { Add-Violation "prohibited_field_$forbidden" } }
$status = if ($violations.Count -eq 0) { 'usable' } else { 'blocked_or_pending' }
$result = [ordered]@{ status=$status; memory_id=$entry.memory_id; view=$View; state=$state; decision_ready=($status -eq 'usable' -and $state -eq 'current' -and $View -eq 'current'); pending_verification=($state -in @('transitional','disputed') -or $RiskLevel -eq 'L4'); source_reload_required=($RiskLevel -eq 'L4' -or $state -in @('transitional','disputed')); violations=@($violations); raw_memory_recorded=$false }
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List }
if ($status -ne 'usable') { exit 1 }
