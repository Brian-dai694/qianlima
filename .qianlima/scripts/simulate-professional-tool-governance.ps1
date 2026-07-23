<##
.SYNOPSIS
  Simulates personal-edition governance for a professional MCP tool.
.DESCRIPTION
  This is a design-learning adapter only. It reads a sanitized tool manifest,
  classifies its capabilities, and returns a decision. It never installs a
  package, starts a runtime, opens a listener, calls a tool, or grants access.
##>
param(
  [Parameter(Mandatory = $true)] [string]$ManifestPath,
  [ValidateSet('reverse-readonly', 'reverse-triage', 'reverse-edit', 'reverse-debug')] [string]$Profile = 'reverse-readonly',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$contractPath = Join-Path $projectRoot '.qianlima\specifications\personal-professional-tool-governance.json'
$simulationRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\working\professional-tool-simulation')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar

function Get-Field($Object, [string]$Name) {
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}
function Add-Issue([System.Collections.Generic.List[string]]$List, [string]$Value) {
  if (-not $List.Contains($Value)) { [void]$List.Add($Value) }
}

$issues = [System.Collections.Generic.List[string]]::new()
$contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json
$manifest = $null
$toolId = ''
$targetRef = ''
try {
  $manifestFullPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ManifestPath -ErrorAction Stop).Path)
  if (-not $manifestFullPath.StartsWith($simulationRoot, [StringComparison]::OrdinalIgnoreCase)) { Add-Issue $issues 'manifest_outside_simulation_scope' }
  $manifest = Get-Content -LiteralPath $manifestFullPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $toolId = [string](Get-Field $manifest 'tool_id')
  $targetRef = [string](Get-Field $manifest 'target_ref')
} catch {
  Add-Issue $issues 'manifest_unreadable'
}

if ($null -eq $manifest) {
  $toolId = 'unknown'
} else {
  if ([string]::IsNullOrWhiteSpace($toolId)) { Add-Issue $issues 'tool_id_required' }
  if ([string](Get-Field $manifest 'transport') -ne 'stdio') { Add-Issue $issues 'stdio_required' }
  foreach ($field in @('url', 'endpoint', 'remote_endpoint', 'host', 'port')) {
    if ($null -ne $manifest.PSObject.Properties[$field]) { Add-Issue $issues "forbidden_transport_field_$field" }
  }
  if ([string]::IsNullOrWhiteSpace($targetRef)) { Add-Issue $issues 'target_ref_required' }
  if ($targetRef -match '(^[A-Za-z]:[\\/])|(^[\\/])|(^\\\\)') { Add-Issue $issues 'absolute_target_ref_forbidden' }
  if ($targetRef -and $targetRef -notmatch '^(binary|database|workspace)-ref:') { Add-Issue $issues 'reference_target_required' }
  $capabilities = @((Get-Field $manifest 'capabilities') | ForEach-Object { [string]$_ })
  $allCapabilities = @()
  foreach ($tier in $contract.capability_tiers.PSObject.Properties) { $allCapabilities += @($tier.Value) }
  foreach ($capability in $capabilities) {
    if ($allCapabilities -notcontains $capability) { Add-Issue "unknown_capability_$capability" }
  }
  $profileConfig = $contract.profiles.PSObject.Properties[$Profile].Value
  $allowedCapabilities = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($tierName in $profileConfig.allowed_tiers) {
    $tierProperty = $contract.capability_tiers.PSObject.Properties[$tierName]
    if ($null -eq $tierProperty) {
      Add-Issue $issues "unknown_capability_tier_$tierName"
    } else {
      foreach ($allowedCapability in $tierProperty.Value) { [void]$allowedCapabilities.Add([string]$allowedCapability) }
    }
  }
  foreach ($capability in $capabilities) {
    if (-not $allowedCapabilities.Contains([string]$capability)) { Add-Issue $issues "capability_not_allowed_by_$Profile" }
  }
  if ((Get-Field $manifest 'network') -and [string](Get-Field $manifest 'network') -ne 'none') { Add-Issue 'network_must_be_none' }
  if ((Get-Field $manifest 'write') -and [string](Get-Field $manifest 'write') -ne 'none') { Add-Issue 'write_must_be_none_for_learning' }
}

$profileConfig = $contract.profiles.PSObject.Properties[$Profile].Value
$decision = 'denied'
$status = 'rejected'
if ($issues.Count -eq 0) {
  if ([string]$profileConfig.personal_learning_status -eq 'blocked_learning_only') {
    $decision = 'blocked_learning_only'
    $status = 'blocked'
    Add-Issue $issues 'profile_is_not_enabled_in_personal_learning_mode'
  } else {
    $decision = 'allowed_for_simulation'
    $status = 'simulation_only'
  }
}

$result = [ordered]@{
  status = $status
  tool_id = $toolId
  profile = $Profile
  target_ref = $targetRef
  decision = $decision
  issues = @($issues)
  installation_performed = $false
  execution_started = $false
  external_calls = $false
  permissions_granted = $false
  runtime_enabled = $false
  transport = 'stdio-design-only'
  contract_ref = '.qianlima/specifications/personal-professional-tool-governance.json'
}
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List }
