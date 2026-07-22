<# .SYNOPSIS Tests all four Enterprise API and Agent deployment modes. #>
param([switch]$PassThru)
$ErrorActionPreference = 'Stop'
$selector = Join-Path $PSScriptRoot 'select-enterprise-deployment-mode.ps1'
$policy = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'deployment-mode-policy.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$matrix = @(
  @{ api='yes'; agent='yes'; expected='E1' },
  @{ api='yes'; agent='no'; expected='E2' },
  @{ api='no'; agent='yes'; expected='E3' },
  @{ api='no'; agent='no'; expected='E4' }
)
$cases = [System.Collections.Generic.List[object]]::new()
foreach ($item in $matrix) {
  $actual = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $selector -EnterpriseApi $item.api -EnterpriseAgent $item.agent -PassThru | ConvertFrom-Json
  $cases.Add([PSCustomObject]@{ name = 'maps_' + $item.expected; passed = ($actual.deployment_mode -eq $item.expected) })
  $cases.Add([PSCustomObject]@{ name = 'no_implicit_authority_' + $item.expected; passed = (-not $actual.execution_authorized -and -not $actual.mcp_authorized -and -not $actual.internal_data_authorized) })
}
$cases.Add([PSCustomObject]@{ name='E2_is_default'; passed=($policy.default_mode -eq 'E2') })
$cases.Add([PSCustomObject]@{ name='E4_starts_T1'; passed=($policy.modes.E4.initial_trust_ceiling -eq 'T1') })
$cases.Add([PSCustomObject]@{ name='all_modes_use_secret_refs'; passed=(@($policy.modes.PSObject.Properties.Value | Where-Object { $_.credential_mode -notmatch 'secret_ref' }).Count -eq 0) })
$cases.Add([PSCustomObject]@{ name='writes_remain_L4'; passed=(@($policy.invariants | Where-Object { $_ -match 'L4' }).Count -gt 0) })
$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ passed=($failed.Count -eq 0); cases=@($cases); external_calls=$false; permissions_granted=$false }
if ($PassThru) { $result | ConvertTo-Json -Depth 5 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw ('Deployment mode regression failed: ' + (($failed.name) -join ', ')) }
