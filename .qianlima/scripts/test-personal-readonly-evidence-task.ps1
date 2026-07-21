param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = Join-Path $projectRoot '.qianlima\run-traces'
$grantRoot = Join-Path $traceRoot 'delegation-grants'
$adapter = Join-Path $PSScriptRoot 'invoke-personal-readonly-evidence-task.ps1'
New-Item -ItemType Directory -Path $grantRoot -Force | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmssfff')
$cases = New-Object System.Collections.Generic.List[object]

function Write-JsonFile([string]$Path, $Value) {
  [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
}
function New-Envelope([string]$TaskId, [hashtable]$Extra = @{}) {
  $envelope = [ordered]@{
    schema_version = 1
    contract_type = 'qianlima_personal_local_stdio_task'
    task_id = $TaskId
    context_id = "context-$TaskId"
    agent_id = 'local-readonly-evidence-checker'
    tool_id = 'qianlima_readonly_evidence_task'
    input_refs = @([ordered]@{ artifact_id = "sanitized-$TaskId"; source_classification = 'internal_sanitized' })
  }
  foreach ($key in $Extra.Keys) { $envelope[$key] = $Extra[$key] }
  $path = Join-Path $traceRoot "personal-envelope-$TaskId.json"
  Write-JsonFile $path $envelope
  return $path
}
function New-Grant([string]$GrantId, [string]$TaskId, [hashtable]$Extra = @{}) {
  $grant = [ordered]@{
    schema_version = 1
    grant_id = $GrantId
    task_id = $TaskId
    agent_id = 'local-readonly-evidence-checker'
    tool_id = 'qianlima_readonly_evidence_task'
    status = 'issued'
    revoked = $false
    expires_at = (Get-Date).ToUniversalTime().AddMinutes(5).ToString('o')
    allowed_tools = @('qianlima_readonly_evidence_task')
    network_access = 'none'
    write_access = 'none'
    can_delegate = $false
    risk_ceiling = 'L2'
  }
  foreach ($key in $Extra.Keys) { $grant[$key] = $Extra[$key] }
  $path = Join-Path $grantRoot "$GrantId.json"
  Write-JsonFile $path $grant
  return $path
}
function Invoke-Tool([string]$EnvelopePath, [string]$GrantPath, [switch]$Explicit) {
  $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $adapter, '-EnvelopePath', $EnvelopePath, '-GrantPath', $GrantPath, '-PassThru')
  if ($Explicit) { $args += '-ExplicitStart' }
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = & powershell.exe @args 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
  }
  return [PSCustomObject]@{ exit_code = $exitCode; output = ($output -join "`n") }
}
function Add-Pass([string]$Name, [bool]$Passed, [string]$Detail = '') { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed; detail = $Detail }) }
function Expect-Failure([string]$Name, [string]$EnvelopePath, [string]$GrantPath, [switch]$Explicit) {
  $run = Invoke-Tool $EnvelopePath $GrantPath -Explicit:$Explicit
  Add-Pass $Name ($run.exit_code -ne 0) $run.output
}

$validTask = "stdio-valid-$stamp"
$validEnvelope = New-Envelope $validTask
$validGrant = New-Grant "grant-$validTask" $validTask
$validRun = Invoke-Tool $validEnvelope $validGrant -Explicit
Add-Pass 'valid_explicit_stdio_task' ($validRun.exit_code -eq 0 -and $validRun.output -match 'qianlima_readonly_evidence_task' -and $validRun.output -match 'evidence_receipt') $validRun.output

$task = "missing-grant-$stamp"; Expect-Failure 'grant_required' (New-Envelope $task) (Join-Path $grantRoot "missing-$task.json") -Explicit
$task = "no-explicit-start-$stamp"; Expect-Failure 'explicit_start_required' (New-Envelope $task) (New-Grant "grant-$task" $task)
$task = "task-mismatch-$stamp"; Expect-Failure 'grant_task_mismatch' (New-Envelope $task) (New-Grant "grant-$task" "other-$task") -Explicit
$task = "expired-$stamp"; $grant = New-Grant "grant-$task" $task @{ expires_at = (Get-Date).ToUniversalTime().AddMinutes(-1).ToString('o') }; Expect-Failure 'expired_grant_rejected' (New-Envelope $task) $grant -Explicit
$task = "revoked-$stamp"; $grant = New-Grant "grant-$task" $task @{ revoked = $true }; Expect-Failure 'revoked_grant_rejected' (New-Envelope $task) $grant -Explicit
$task = "network-$stamp"; $grant = New-Grant "grant-$task" $task @{ network_access = 'allow' }; Expect-Failure 'network_permission_rejected' (New-Envelope $task) $grant -Explicit
$task = "write-$stamp"; $grant = New-Grant "grant-$task" $task @{ write_access = 'business' }; Expect-Failure 'write_permission_rejected' (New-Envelope $task) $grant -Explicit
$task = "delegate-$stamp"; $grant = New-Grant "grant-$task" $task @{ can_delegate = $true }; Expect-Failure 'delegation_rejected' (New-Envelope $task) $grant -Explicit
$task = "wrong-tool-$stamp"; $grant = New-Grant "grant-$task" $task @{ allowed_tools = @('other_tool') }; Expect-Failure 'only_tool_allowed' (New-Envelope $task) $grant -Explicit
$task = "endpoint-$stamp"; Expect-Failure 'endpoint_rejected' (New-Envelope $task @{ endpoint = 'https://example.invalid'; port = 443 }) (New-Grant "grant-$task" $task) -Explicit

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ suite = 'personal_readonly_evidence_task'; passed = ($failed.Count -eq 0); total = $cases.Count; passed_count = ($cases.Count - $failed.Count); cases = $cases }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $cases | Select-Object name, passed | Format-Table -AutoSize; Write-Host ("Personal read-only stdio regression: {0}/{1} PASS" -f $result.passed_count, $result.total) }
if ($failed.Count -gt 0) { throw "Personal read-only stdio regression failed: $($failed.name -join ', ')" }
