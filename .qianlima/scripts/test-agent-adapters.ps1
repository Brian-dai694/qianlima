<#!
.SYNOPSIS
  Regression tests for governed supervisor and CLI adapters.
.DESCRIPTION
  All positive cases are dry runs. This test never starts a vendor process and
  does not require vendor execution or a real sandbox.
#>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$grantScript = Join-Path $PSScriptRoot 'new-delegation-grant.ps1'
$revokeScript = Join-Path $PSScriptRoot 'revoke-delegation-grant.ps1'
$generic = Join-Path $PSScriptRoot 'invoke-governed-cli.ps1'
$wrappers = @{
  codex_supervisor = Join-Path $PSScriptRoot 'invoke-codex-supervisor.ps1'
  codewhale_worker = Join-Path $PSScriptRoot 'invoke-codewhale.ps1'
  claude_code_worker = Join-Path $PSScriptRoot 'invoke-claude-code.ps1'
  raven_worker = Join-Path $PSScriptRoot 'invoke-raven.ps1'
}
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
$cases = [System.Collections.Generic.List[object]]::new()

function New-TestGrant([string]$AgentId, [string]$GrantId, [string]$TaskId, [string]$Risk = 'L2') {
  $path = Join-Path $projectRoot ".qianlima\run-traces\delegation-grants\$GrantId.json"
  & $grantScript -GrantId $GrantId -AgentId $AgentId -TaskId $TaskId -WorkOrderId "adapter-order-$GrantId" -DataRef 'artifact-sanitized' -AllowedTool 'read_selected_sources' -RiskCeiling $Risk -VerifierAgentId 'codex_supervisor' | Out-Null
  return $path
}
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
function Invoke-ExpectedFailure([scriptblock]$Action, [string]$Needle) {
  $output = @()
  $exitCode = 0
  try {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = @(& $Action 2>&1)
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $old
  } catch {
    $output += $_ | Out-String
    $exitCode = 1
  }
  return ($exitCode -ne 0 -and ($output -join "`n") -match $Needle)
}

foreach ($agentId in $wrappers.Keys) {
  $taskId = "adapter-dry-$agentId-$stamp"
  $grantId = "adapter-grant-$agentId-$stamp"
  $grantPath = New-TestGrant $agentId $grantId $taskId
  $result = & $wrappers[$agentId] -GrantPath $grantPath -TaskId $taskId -Prompt 'Inspect the selected sanitized artifact and return a concise verification summary.' -PassThru | ConvertFrom-Json
  Add-Case "dry_run_$agentId" ($result.status -eq 'dry_run' -and $result.network -eq 'none' -and $result.write_access -eq 'none' -and $result.note -eq 'No vendor process was started.')
}

$l3Task = "adapter-l3-$stamp"
$l3Grant = New-TestGrant 'codewhale_worker' "adapter-l3-grant-$stamp" $l3Task 'L3'
Add-Case 'l3_rejected' (Invoke-ExpectedFailure { & $wrappers['codewhale_worker'] -GrantPath $l3Grant -TaskId $l3Task -Prompt 'Inspect selected sanitized evidence.' } 'L3')

$sandboxTask = "adapter-sandbox-$stamp"
$sandboxGrant = New-TestGrant 'codewhale_worker' "adapter-sandbox-grant-$stamp" $sandboxTask
Add-Case 'execute_requires_sandbox_attestation' (Invoke-ExpectedFailure { & $wrappers['codewhale_worker'] -GrantPath $sandboxGrant -TaskId $sandboxTask -Prompt 'Inspect selected sanitized evidence.' -Execute } 'Sandbox Attestation')
Add-Case 'manual_sandbox_flag_not_enough' (Invoke-ExpectedFailure { & $wrappers['codewhale_worker'] -GrantPath $sandboxGrant -TaskId $sandboxTask -Prompt 'Inspect selected sanitized evidence.' -Execute -SandboxReady } 'Sandbox Attestation')

$revokedTask = "adapter-revoked-$stamp"
$revokedGrantId = "adapter-revoked-grant-$stamp"
$revokedGrant = New-TestGrant 'claude_code_worker' $revokedGrantId $revokedTask
& $revokeScript -GrantId $revokedGrantId -Reason 'Adapter regression revocation.' | Out-Null
Add-Case 'revoked_grant_rejected' (Invoke-ExpectedFailure { & $wrappers['claude_code_worker'] -GrantPath $revokedGrant -TaskId $revokedTask -Prompt 'Inspect selected sanitized evidence.' } 'revoked')

$secretTask = "adapter-secret-$stamp"
$secretGrant = New-TestGrant 'codex_supervisor' "adapter-secret-grant-$stamp" $secretTask
Add-Case 'secret_prompt_rejected' (Invoke-ExpectedFailure { & $wrappers['codex_supervisor'] -GrantPath $secretGrant -TaskId $secretTask -Prompt 'Use api_key=do-not-send.' } 'secret')
Add-Case 'absolute_path_rejected' (Invoke-ExpectedFailure { & $wrappers['codex_supervisor'] -GrantPath $secretGrant -TaskId $secretTask -Prompt 'Read C:\Users\Example\private.txt.' } 'absolute')

$sourceText = Get-Content -LiteralPath $generic -Raw -Encoding UTF8
Add-Case 'no_loopback_or_auto_approval' (-not ($sourceText -match '127\.0\.0\.1|localhost|--auto'))
$ravenTask = "adapter-raven-sandbox-$stamp"
$ravenGrant = New-TestGrant 'raven_worker' "adapter-raven-sandbox-grant-$stamp" $ravenTask
Add-Case 'raven_requires_sandbox_attestation' (Invoke-ExpectedFailure { & $wrappers['raven_worker'] -GrantPath $ravenGrant -TaskId $ravenTask -Prompt 'Return a bounded status.' -Mode Plan -Start } 'Sandbox Attestation')

$discoverOnly = @{
  mimo_cli_worker = Join-Path $PSScriptRoot 'invoke-mimo-cli.ps1'
  kimi_cli_worker = Join-Path $PSScriptRoot 'invoke-kimi-cli.ps1'
  gemini_cli_worker = Join-Path $PSScriptRoot 'invoke-gemini-cli.ps1'
  aider_worker = Join-Path $PSScriptRoot 'invoke-aider.ps1'
  opencode_worker = Join-Path $PSScriptRoot 'invoke-opencode.ps1'
  goose_worker = Join-Path $PSScriptRoot 'invoke-goose.ps1'
}
foreach ($agentId in $discoverOnly.Keys) {
  $task = "adapter-discover-$agentId-$stamp"
  $grant = New-TestGrant $agentId "adapter-discover-grant-$agentId-$stamp" $task
  Add-Case "discover_only_$agentId" (Invoke-ExpectedFailure { & $discoverOnly[$agentId] -GrantPath $grant -TaskId $task -Prompt 'Return a bounded status.' } 'discovery only')
}
$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ passed = ($failed.Count -eq 0); cases = @($cases); vendor_processes_started = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw "Agent adapter regression failed: $($failed.name -join ', ')" }
