param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$root = Join-Path $projectRoot ('.qianlima\tmp\personal-learning-boundary-' + [Guid]::NewGuid().ToString('n'))
$checker = Join-Path $PSScriptRoot 'check-personal-learning-plan.ps1'
New-Item -ItemType Directory -Path $root -Force | Out-Null
$cases = New-Object System.Collections.Generic.List[object]
function Write-Plan([string]$Name, [hashtable]$Overrides = @{}) {
  $plan = [ordered]@{ schema_version = 1; task_id = "learning-$Name"; delivery_mode = 'summary_only'; stage_sequence = @('resource_summary', 'local_plan', 'readonly_execute', 'verify_and_converge'); source_refs = @('source:provided_material'); proposed_tools = @('local_summary'); auto_start = $false; background_task = $false; network_access = 'none'; write_access = 'none'; can_delegate = $false; stop_conditions = @('evidence_sufficient', 'user_requested_continue') }
  foreach ($key in $Overrides.Keys) { $plan[$key] = $Overrides[$key] }
  $path = Join-Path $root "$Name.json"
  [IO.File]::WriteAllText($path, ($plan | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
  return $path
}
function Invoke-Check([string]$Path) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -PlanPath $Path -PassThru 2>&1; $code = $LASTEXITCODE } finally { $ErrorActionPreference = $old }
  [PSCustomObject]@{ code = $code; output = ($output -join "`n") }
}
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
$summary = Invoke-Check (Write-Plan 'summary')
Add-Case 'summary_is_proposal_only' ($summary.code -eq 0 -and $summary.output -match 'proposal_only')
$readonlyPlan = Write-Plan 'readonly' @{ delivery_mode = 'readonly_evidence'; proposed_tools = @('qianlima_readonly_evidence_task'); explicit_start = $true; grant_required = $true }
$readonly = Invoke-Check $readonlyPlan
Add-Case 'readonly_requires_explicit_grant' ($readonly.code -eq 0 -and $readonly.output -match 'matching_grant_only')
Add-Case 'auto_start_rejected' ((Invoke-Check (Write-Plan 'auto' @{ auto_start = $true })).code -ne 0)
Add-Case 'network_rejected' ((Invoke-Check (Write-Plan 'network' @{ network_access = 'allow' })).code -ne 0)
Add-Case 'remote_field_rejected' ((Invoke-Check (Write-Plan 'remote' @{ endpoint = 'https://example.invalid' })).code -ne 0)
Add-Case 'executor_tool_rejected' ((Invoke-Check (Write-Plan 'executor' @{ proposed_tools = @('ssh') })).code -ne 0)
$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ suite = 'personal_learning_boundary'; passed = ($failed.Count -eq 0); total = $cases.Count; passed_count = ($cases.Count - $failed.Count); cases = $cases; external_calls = $false; background_tasks = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize; Write-Host ("Personal learning boundary: {0}/{1} PASS" -f $result.passed_count, $result.total) }
if ($failed.Count -gt 0) { throw "Personal learning boundary failed: $($failed.name -join ', ')" }
