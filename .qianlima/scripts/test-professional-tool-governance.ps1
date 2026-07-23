<##
.SYNOPSIS
  Offline regression for the personal professional-tool learning adapter.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$simulationRoot = Join-Path $projectRoot '.qianlima\working\professional-tool-simulation'
$adapter = Join-Path $PSScriptRoot 'simulate-professional-tool-governance.ps1'
New-Item -ItemType Directory -Path $simulationRoot -Force | Out-Null
$cases = [System.Collections.Generic.List[object]]::new()

function Write-JsonFile([string]$Path, $Value) {
  [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
}
function New-Manifest([string]$Name, [hashtable]$Values) {
  $manifest = [ordered]@{ schema_version = 1; tool_id = "simulated-$Name"; transport = 'stdio'; target_ref = "binary-ref:$Name"; capabilities = @('function_list'); network = 'none'; write = 'none' }
  foreach ($key in $Values.Keys) { $manifest[$key] = $Values[$key] }
  $path = Join-Path $simulationRoot "$Name.json"
  Write-JsonFile $path $manifest
  return $path
}
function Invoke-Adapter([string]$Path, [string]$Profile) {
  $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $adapter -ManifestPath $Path -Profile $Profile -PassThru 2>&1)
  if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
  return (($output -join "`n") | ConvertFrom-Json)
}
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }

$readonly = Invoke-Adapter (New-Manifest 'readonly' @{ capabilities = @('function_list', 'decompile') }) 'reverse-readonly'
$triage = Invoke-Adapter (New-Manifest 'triage' @{ capabilities = @('strings', 'imports', 'xrefs') }) 'reverse-triage'
$modify = Invoke-Adapter (New-Manifest 'modify' @{ capabilities = @('function_list', 'rename') }) 'reverse-readonly'
$pyEval = Invoke-Adapter (New-Manifest 'py-eval' @{ capabilities = @('function_list', 'py_eval') }) 'reverse-triage'
$endpoint = Invoke-Adapter (New-Manifest 'endpoint' @{ endpoint = 'https://example.invalid'; capabilities = @('function_list') }) 'reverse-readonly'
$absolute = Invoke-Adapter (New-Manifest 'absolute' @{ target_ref = 'C:\sample\program.i64'; capabilities = @('function_list') }) 'reverse-readonly'
$edit = Invoke-Adapter (New-Manifest 'edit-profile' @{ capabilities = @('function_list', 'rename') }) 'reverse-edit'

Add-Case 'readonly_profile_is_simulation_only' ($readonly.status -eq 'simulation_only' -and $readonly.decision -eq 'allowed_for_simulation' -and $readonly.installation_performed -eq $false -and $readonly.execution_started -eq $false)
Add-Case 'triage_profile_is_read_only' ($triage.status -eq 'simulation_only' -and $triage.decision -eq 'allowed_for_simulation' -and $triage.permissions_granted -eq $false)
Add-Case 'modify_capability_is_denied_by_readonly' ($modify.status -eq 'rejected' -and @($modify.issues) -contains 'capability_not_allowed_by_reverse-readonly')
Add-Case 'py_eval_is_denied' ($pyEval.status -eq 'rejected' -and @($pyEval.issues) -contains 'capability_not_allowed_by_reverse-triage')
Add-Case 'endpoint_is_denied' ($endpoint.status -eq 'rejected' -and @($endpoint.issues) -contains 'forbidden_transport_field_endpoint' -and $endpoint.external_calls -eq $false)
Add-Case 'absolute_target_is_denied' ($absolute.status -eq 'rejected' -and @($absolute.issues) -contains 'absolute_target_ref_forbidden')
Add-Case 'edit_profile_never_starts_in_learning_mode' ($edit.status -eq 'blocked' -and $edit.decision -eq 'blocked_learning_only' -and $edit.runtime_enabled -eq $false)
Add-Case 'all_results_have_no_external_effects' (@($readonly, $triage, $modify, $pyEval, $endpoint, $absolute, $edit).Where({ $_.external_calls -or $_.installation_performed -or $_.execution_started -or $_.permissions_granted }).Count -eq 0)

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ suite = 'personal_professional_tool_governance'; passed = ($failed.Count -eq 0); total = $cases.Count; passed_count = ($cases.Count - $failed.Count); external_calls = $false; installations = $false; executions = $false; cases = @($cases) }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize; Write-Host ("Professional tool governance: {0}/{1} PASS" -f $result.passed_count, $result.total) }
if ($failed.Count -gt 0) { throw ('Professional tool governance failed: ' + (($failed | ForEach-Object { $_.name }) -join ', ')) }
