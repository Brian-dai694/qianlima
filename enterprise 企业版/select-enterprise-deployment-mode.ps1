<#
.SYNOPSIS
  Selects one of the four Enterprise API and Agent deployment modes.
.DESCRIPTION
  Answers two beginner-facing questions and returns governance configuration.
  It does not validate credentials, register Agents, or grant permissions.
#>
param(
  [ValidateSet('yes','no')][string]$EnterpriseApi = '',
  [ValidateSet('yes','no')][string]$EnterpriseAgent = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($EnterpriseApi)) {
  $EnterpriseApi = (Read-Host 'Does the enterprise centrally purchase and manage model API access? (yes/no)').Trim().ToLowerInvariant()
}
if ([string]::IsNullOrWhiteSpace($EnterpriseAgent)) {
  $EnterpriseAgent = (Read-Host 'Must employees use one enterprise-designated Agent? (yes/no)').Trim().ToLowerInvariant()
}
if ($EnterpriseApi -notin @('yes','no') -or $EnterpriseAgent -notin @('yes','no')) { throw 'Answers must be yes or no.' }

$mode = if ($EnterpriseApi -eq 'yes' -and $EnterpriseAgent -eq 'yes') { 'E1' }
  elseif ($EnterpriseApi -eq 'yes') { 'E2' }
  elseif ($EnterpriseAgent -eq 'yes') { 'E3' }
  else { 'E4' }
$policy = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'deployment-mode-policy.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$selected = $policy.modes.$mode
$result = [ordered]@{
  schema_version = 1
  deployment_mode = $mode
  enterprise_api = $selected.enterprise_api
  enterprise_agent = $selected.enterprise_agent
  provider_account = $selected.provider_account
  agent_selection = $selected.agent_selection
  credential_mode = $selected.credential_mode
  cost_owner = $selected.cost_owner
  initial_trust_ceiling = $selected.initial_trust_ceiling
  execution_authorized = $false
  mcp_authorized = $false
  internal_data_authorized = $false
  next_step = 'register provider reference and Agent identity, then run separate admission'
}
if ($PassThru) { $result | ConvertTo-Json -Depth 5 } else { [PSCustomObject]$result | Format-List }
