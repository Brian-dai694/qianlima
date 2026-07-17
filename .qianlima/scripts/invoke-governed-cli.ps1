<#
.SYNOPSIS
  Runs a registered CLI Agent through the Qianlima Broker contract.
.DESCRIPTION
  This adapter is deliberately dry-run by default. It validates the one-time
  Delegation Grant before constructing a vendor command. Real execution also
  requires both -Execute and -SandboxReady; the latter is an explicit runtime
  assertion and is never inferred from the vendor installation.
#>
param(
  [Parameter(Mandatory = $true)] [ValidateSet('codex_supervisor', 'codewhale_worker', 'claude_code_worker', 'raven_worker', 'mimo_cli_worker', 'kimi_cli_worker', 'gemini_cli_worker', 'aider_worker', 'opencode_worker', 'goose_worker')] [string]$AdapterId,
  [Parameter(Mandatory = $true)] [string]$GrantPath,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [string]$Prompt,
  [string]$AttestationPath = '',
  [ValidateSet('Plan', 'Execute')] [string]$Mode = 'Plan',
  [switch]$Start,
  [switch]$Execute,
  [switch]$SandboxReady,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$effectiveMode = if ($Execute) { 'Execute' } else { $Mode }
if ($Execute -and $Mode -ne 'Execute') { $effectiveMode = 'Execute' }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$auditScript = Join-Path $PSScriptRoot 'write-audit-event.ps1'
$revocationPath = Join-Path $projectRoot '.qianlima\run-traces\grant-revocations.jsonl'
$grantRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\delegation-grants')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$attestationRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\sandbox-attestations')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar

function Test-PathUnderRoot([string]$Path, [string]$Root) {
  return ([IO.Path]::GetFullPath($Path)).StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)
}
function Quote-ProcessArgument([string]$Value) {
  if ($Value -notmatch '[\s"]') { return $Value }
  return '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}
function Test-SafePrompt([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) { throw 'Prompt cannot be empty.' }
  if ($Value.Length -gt 12000) { throw 'Prompt exceeds the adapter input budget.' }
  if ($Value -match '(?i)([A-Z]:[\\/]|\\\\|(^|\s)\.\.(?:[\\/]|\s|$)|\$HOME|%USERPROFILE%|/Users/|/home/)') { throw 'Prompt cannot contain absolute, parent-traversal, or user-home paths.' }
  foreach ($needle in @('api_key', 'access_token', 'refresh_token', 'password', 'cookie', 'authorization:')) {
    if ($Value -match [regex]::Escape($needle)) { throw 'Prompt appears to contain secret material.' }
  }
}

Test-SafePrompt $Prompt
$grantFullPath = (Resolve-Path -LiteralPath $GrantPath -ErrorAction Stop).Path
if (-not (Test-PathUnderRoot $grantFullPath $grantRoot)) { throw 'Grant must be inside .qianlima/run-traces/delegation-grants.' }
$grant = Get-Content -LiteralPath $grantFullPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($grant.task_id -ne $TaskId) { throw 'Grant task binding does not match TaskId.' }
if ($grant.status -ne 'issued') { throw "Grant is not issued: $($grant.status)" }
if ($grant.can_delegate -ne $false -or $grant.network_access -ne 'none' -or $grant.write_access -ne 'none') { throw 'Grant is broader than the CLI adapter policy.' }
if ($grant.risk_ceiling -notin @('L0', 'L1', 'L2')) { throw 'CLI adapters reject L3/L4 execution grants.' }
if ((Get-Date).ToUniversalTime() -ge [DateTime]::Parse($grant.expires_at).ToUniversalTime()) { throw 'Delegation grant has expired.' }
if (Test-Path -LiteralPath $revocationPath -PathType Leaf) {
  foreach ($line in Get-Content -LiteralPath $revocationPath -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $revocation = $line | ConvertFrom-Json
    if ($revocation.grant_id -eq $grant.grant_id) {
      & $auditScript -EventType adapter_grant_rejected_revoked -Decision deny -TaskId $TaskId -GrantId $grant.grant_id -AgentId $grant.agent_id -Reason 'CLI adapter grant was revoked before dispatch.' 6>$null | Out-Null
      throw 'Delegation grant has been revoked.'
    }
  }
}

$known = @{
  codex_supervisor = [ordered]@{ command = 'codex'; prefix = @('exec'); output = 'text'; role = 'supervisor' }
  codewhale_worker = [ordered]@{ command = 'codewhale'; prefix = @('exec'); output = 'stream-json'; role = 'worker' }
  claude_code_worker = [ordered]@{ command = 'claude'; prefix = @('-p'); output = 'text'; role = 'worker' }
  raven_worker = [ordered]@{ command = 'raven'; prefix = @('agent'); output = 'text'; role = 'worker' }
  mimo_cli_worker = [ordered]@{ command = 'mimo'; prefix = @('chat'); output = 'text'; role = 'worker' }
  kimi_cli_worker = [ordered]@{ command = 'kimi'; prefix = @('--print'); output = 'text'; role = 'worker' }
  gemini_cli_worker = [ordered]@{ command = 'gemini'; prefix = @('--prompt'); output = 'text'; role = 'worker' }
  aider_worker = [ordered]@{ command = 'aider'; prefix = @('--message'); output = 'text'; role = 'worker' }
  opencode_worker = [ordered]@{ command = 'opencode'; prefix = @('run'); output = 'text'; role = 'worker' }
  goose_worker = [ordered]@{ command = 'goose'; prefix = @('run'); output = 'text'; role = 'worker' }
}
$adapter = $known[$AdapterId]
if ($null -eq $adapter) { throw "Unknown adapter: $AdapterId" }
if ($grant.agent_id -ne $AdapterId) { throw 'Grant AgentId does not match the selected adapter.' }
$commandArgs = [System.Collections.Generic.List[string]]::new()
foreach ($arg in $adapter.prefix) { [void]$commandArgs.Add($arg) }
if ($AdapterId -eq 'codewhale_worker') {
  [void]$commandArgs.Add('--output-format'); [void]$commandArgs.Add('stream-json')
}
if ($AdapterId -eq 'claude_code_worker' -and $effectiveMode -eq 'Plan') {
  [void]$commandArgs.Add('--permission-mode'); [void]$commandArgs.Add('plan')
  [void]$commandArgs.Add('--tools=')
}
if ($AdapterId -eq 'raven_worker') {
  [void]$commandArgs.Add('--no-logs')
  [void]$commandArgs.Add('--no-markdown')
  [void]$commandArgs.Add('--workspace')
  [void]$commandArgs.Add($projectRoot)
  [void]$commandArgs.Add('--message')
  [void]$commandArgs.Add($Prompt)
}
if ($AdapterId -in @('mimo_cli_worker', 'kimi_cli_worker', 'gemini_cli_worker', 'aider_worker', 'opencode_worker', 'goose_worker')) {
  throw "Adapter $AdapterId is registered for discovery only until its local CLI contract is verified."
}
if ($AdapterId -eq 'codex_supervisor' -and $effectiveMode -eq 'Plan') {
  [void]$commandArgs.Add('--sandbox'); [void]$commandArgs.Add('read-only')
  [void]$commandArgs.Add('--ask-for-approval'); [void]$commandArgs.Add('never')
}
if ($AdapterId -ne 'raven_worker') { [void]$commandArgs.Add($Prompt) }
$displayArgs = @($commandArgs | ForEach-Object { if ($_ -eq $Prompt) { '<prompt-redacted>' } else { $_ } })

& $auditScript -EventType adapter_grant_checked -Decision allow -TaskId $TaskId -GrantId $grant.grant_id -AgentId $AdapterId -DataRef @($grant.data_refs) -Reason 'Grant matched adapter, task, expiry, risk, and no-network/no-write policy.' 6>$null | Out-Null
if (-not $Start -and -not $Execute) {
  $plan = [ordered]@{ status = 'dry_run'; adapter_id = $AdapterId; role = $adapter.role; command = $adapter.command; arguments = $displayArgs; grant_id = $grant.grant_id; task_id = $TaskId; network = 'none'; write_access = 'none'; sandbox_required_for_execute = $true; note = 'No vendor process was started.' }
  & $auditScript -EventType adapter_dry_run -Decision complete -TaskId $TaskId -GrantId $grant.grant_id -AgentId $AdapterId -DataRef @($grant.data_refs) -Reason 'Dry run completed; vendor process was not started.' 6>$null | Out-Null
  if ($PassThru) { $plan | ConvertTo-Json -Depth 8 } else { $plan | Format-List }
  exit 0
}
if ($effectiveMode -eq 'Execute' -or $AdapterId -eq 'raven_worker') {
  if ([string]::IsNullOrWhiteSpace($AttestationPath)) { throw "Adapter $AdapterId requires a Sandbox Attestation; -SandboxReady alone is not sufficient." }
  $attestationFullPath = (Resolve-Path -LiteralPath $AttestationPath -ErrorAction Stop).Path
  if (-not $attestationFullPath.StartsWith($attestationRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Sandbox Attestation must be inside .qianlima/run-traces/sandbox-attestations.' }
  $attestation = Get-Content -LiteralPath $attestationFullPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($attestation.status -ne 'verified' -or $attestation.task_id -ne $TaskId -or $attestation.agent_id -ne $AdapterId) { throw 'Sandbox Attestation does not match the task, Agent, or verified status.' }
  if ($attestation.host_workspace_mounted -ne $false -or $attestation.agent_network -ne 'none' -or $attestation.secret_mode -ne 'secret_ref_only') { throw 'Sandbox Attestation violates isolation, network, or secret policy.' }
  if (-not (Test-Path -LiteralPath $attestation.isolation_root -PathType Container)) { throw 'Sandbox isolation root is unavailable.' }
  if ((Get-Date).ToUniversalTime() -ge [DateTime]::Parse($attestation.expires_at).ToUniversalTime()) { throw 'Sandbox Attestation has expired.' }
  & $auditScript -EventType sandbox_attestation_checked -Decision allow -TaskId $TaskId -GrantId $grant.grant_id -AgentId $AdapterId -Reason 'Verified task-bound sandbox attestation accepted.' 6>$null | Out-Null
}

$resolved = $null
if ($AdapterId -eq 'claude_code_worker') {
  $claudeCandidates = @(
    (Join-Path $env:APPDATA 'npm\claude.cmd'),
    (Join-Path $env:APPDATA 'npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe')
  )
  foreach ($candidate in $claudeCandidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      $resolved = [PSCustomObject]@{ Source = $candidate; IsCmd = $true; UseCall = ($candidate -like '*.cmd') }
      break
    }
  }
}
if ($null -eq $resolved -and $AdapterId -eq 'raven_worker') {
  $ravenPath = Join-Path $env:USERPROFILE '.local\bin\raven.exe'
  if (Test-Path -LiteralPath $ravenPath -PathType Leaf) { $resolved = [PSCustomObject]@{ Source = $ravenPath; IsCmd = $false } }
}
if ($null -eq $resolved) {
  $pathCommand = @(Get-Command $adapter.command -CommandType Application -ErrorAction SilentlyContinue | Where-Object { $_.Source -and $_.Source -notmatch '\.ps1$' } | Select-Object -First 1)
  if ($pathCommand.Count -gt 0) { $resolved = [PSCustomObject]@{ Source = $pathCommand[0].Source; IsCmd = ($pathCommand[0].Source -like '*.cmd') } }
}
if ($null -eq $resolved) {
  throw "Adapter executable not found: $($adapter.command). Refresh PATH or install the vendor CLI."
}
$psi = [Diagnostics.ProcessStartInfo]::new()
$processArgs = (($commandArgs | ForEach-Object { Quote-ProcessArgument $_ }) -join ' ')
if ($AdapterId -eq 'claude_code_worker' -and $effectiveMode -eq 'Plan') {
  $processArgs = '-p --permission-mode plan --tools= ' + (Quote-ProcessArgument $Prompt)
}
if ($resolved.IsCmd) {
  $psi.FileName = Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\cmd.exe'
  $psi.Arguments = '/d /c call ' + (Quote-ProcessArgument $resolved.Source) + ' ' + $processArgs
} else {
  $psi.FileName = $resolved.Source
  $psi.Arguments = $processArgs
}
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$process = [Diagnostics.Process]::new()
$process.StartInfo = $psi
& $auditScript -EventType adapter_execution_started -Decision allow -TaskId $TaskId -GrantId $grant.grant_id -AgentId $AdapterId -DataRef @($grant.data_refs) -Reason "Started in $effectiveMode mode with bounded adapter arguments." 6>$null | Out-Null
if (-not $process.Start()) { throw "Unable to start adapter process: $AdapterId" }
$finished = $process.WaitForExit(120000)
if (-not $finished) {
  try { $process.Kill() } catch { }
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  & $auditScript -EventType adapter_execution_timeout -Decision freeze -TaskId $TaskId -GrantId $grant.grant_id -AgentId $AdapterId -DataRef @($grant.data_refs) -Reason 'Vendor process exceeded the fixed 120-second adapter budget.' 6>$null | Out-Null
  $timeoutResult = [ordered]@{ status = 'frozen'; adapter_id = $AdapterId; task_id = $TaskId; grant_id = $grant.grant_id; exit_code = 124; stdout = $stdout; stderr = $stderr; pending_verification = 'Vendor process timed out.' }
  if ($PassThru) { $timeoutResult | ConvertTo-Json -Depth 8 } else { $timeoutResult | Format-List }
  exit 124
}
$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()
$decision = if ($process.ExitCode -eq 0) { 'complete' } else { 'freeze' }
& $auditScript -EventType adapter_execution_finished -Decision $decision -TaskId $TaskId -GrantId $grant.grant_id -AgentId $AdapterId -DataRef @($grant.data_refs) -Reason "Vendor process exited with code $($process.ExitCode)." 6>$null | Out-Null
$result = [ordered]@{ status = if ($process.ExitCode -eq 0) { 'completed' } else { 'failed' }; adapter_id = $AdapterId; task_id = $TaskId; grant_id = $grant.grant_id; exit_code = $process.ExitCode; stdout = $stdout; stderr = $stderr }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
if ($process.ExitCode -ne 0) { exit $process.ExitCode }
