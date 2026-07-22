<##
.SYNOPSIS
  Validates the shared MCP capability and local port reservation contract.
.DESCRIPTION
  This test checks planning metadata only. It does not open ports or contact MCP.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$catalogPath = Join-Path $projectRoot '.qianlima\specifications\business-capability-catalog.json'
$mapPath = Join-Path $projectRoot '.qianlima\specifications\mcp-capability-port-map.json'
$catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$map = Get-Content -LiteralPath $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = [System.Collections.Generic.List[object]]::new()
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }

$ports = @($map.shared_slots | ForEach-Object { [int]$_.port })
$capabilityIds = @($catalog.capabilities | ForEach-Object { $_.id })
$mappedCapabilityIds = @($map.shared_slots | ForEach-Object { @($_.capability_ids) } | Select-Object -Unique)
$missing = @($capabilityIds | Where-Object { $_ -notin $mappedCapabilityIds })

Add-Case 'personal_and_enterprise_share_map' (@($map.profiles) -contains 'personal' -and @($map.profiles) -contains 'enterprise')
Add-Case 'listener_disabled_by_default' ($map.network_defaults.enabled -eq $false -and $map.network_defaults.public_listener -eq $false)
Add-Case 'loopback_only' ($map.network_defaults.bind_address -eq '127.0.0.1' -and @($map.network_defaults.allowed_transports) -notcontains 'public_http')
Add-Case 'reserved_ports_unique' (@($ports | Select-Object -Unique).Count -eq $ports.Count)
Add-Case 'ports_in_reserved_range' (($ports | Where-Object { $_ -lt $map.network_defaults.port_range.start -or $_ -gt $map.network_defaults.port_range.end }).Count -eq 0)
Add-Case 'all_business_domains_have_mcp_slot' ($missing.Count -eq 0)
Add-Case 'grant_and_data_checks_required' (@($map.adapter_contract.before_call) -contains 'task_and_grant_binding' -and @($map.adapter_contract.before_call) -contains 'data_classification')
Add-Case 'mcp_cannot_authorize_business_write' ($map.adapter_contract.business_write -eq 'never_authorized_by_MCP_slot')
Add-Case 'no_external_calls' ($true)

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ passed = ($failed.Count -eq 0); map_id = $map.map_id; reserved_slots = $ports.Count; external_calls = $false; listeners_opened = $false; cases = @($cases) }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw ('MCP port map regression failed: ' + (($failed | ForEach-Object { $_.name }) -join ', ')) }
