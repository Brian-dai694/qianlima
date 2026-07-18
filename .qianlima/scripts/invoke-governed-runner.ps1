<##
.SYNOPSIS
  Validates and dispatches a worker to a registered Qianlima execution Runner.
.DESCRIPTION
  The first implementation is contract-only. docker_local_mock returns a
  dry-run receipt and never starts Docker or a vendor CLI. Execute is denied
  until a real Runner is enabled and produces a matching Attestation.
##>
param(
  [Parameter(Mandatory = $true)] [string]$RunnerId,
  [Parameter(Mandatory = $true)] [string]$WorkOrderPath,
  [Parameter(Mandatory = $true)] [string]$GrantPath,
  [Parameter(Mandatory = $true)] [string]$AttestationPath,
  [ValidateSet('DryRun', 'Execute')] [string]$Mode = 'DryRun',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$registryPath = Join-Path $projectRoot '.qianlima\execution-runners.json'
$auditScript = Join-Path $PSScriptRoot 'write-audit-event.ps1'
$workOrderRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\work-orders')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$grantRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\delegation-grants')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$attestationRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\sandbox-attestations')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$receiptRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\runner-receipts')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$revocationPath = Join-Path $projectRoot '.qianlima\run-traces\grant-revocations.jsonl'

function Test-PathUnderRoot([string]$Path, [string]$Root) {
  return ([IO.Path]::GetFullPath($Path)).StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)
}
function Get-RiskRank([string]$Risk) {
  switch ($Risk) { 'L0' { return 0 } 'L1' { return 1 } 'L2' { return 2 } 'L3' { return 3 } 'L4' { return 4 } default { return 99 } }
}
function Deny([string]$Reason, [string]$TaskId = '', [string]$GrantId = '', [string]$AgentId = '') {
  & $auditScript -EventType runner_dispatch_rejected -Decision deny -TaskId $TaskId -GrantId $GrantId -AgentId $AgentId -Reason $Reason 6>$null | Out-Null
  throw $Reason
}
function Read-JsonFile([string]$Path, [string]$Root, [string]$Label) {
  $full = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  if (-not (Test-PathUnderRoot $full $Root)) { throw "$Label must be inside its governed run-traces directory." }
  return [PSCustomObject]@{ Path = $full; Value = (Get-Content -LiteralPath $full -Raw -Encoding UTF8 | ConvertFrom-Json) }
}

if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { throw 'Execution Runner registry is missing.' }
$registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$runner = @($registry.runners | Where-Object { $_.runner_id -eq $RunnerId }) | Select-Object -First 1
if ($null -eq $runner) { Deny "Unknown execution Runner: $RunnerId" }
if ($runner.enabled -ne $true) { Deny "Execution Runner is disabled: $RunnerId" }
if ($runner.host_workspace_mounted -eq $true -or $runner.isolation.host_workspace_mounted -ne $false) { Deny 'Runner must not mount the host workspace.' }
if ($runner.network_policy -ne 'none' -or $runner.mcp_policy -ne 'allowlist_read_only' -or $runner.secret_policy -ne 'secret_ref_only' -or $runner.file_export -ne $false -or $runner.web_access -ne $false -or $runner.erp_access -ne $false) { Deny 'Runner policy is broader than the current zero-egress read-only contract.' }

$orderDoc = Read-JsonFile $WorkOrderPath $workOrderRoot 'Work order'
$grantDoc = Read-JsonFile $GrantPath $grantRoot 'Delegation Grant'
$order = $orderDoc.Value
$grant = $grantDoc.Value
$taskId = [string]$grant.task_id
$agentId = [string]$grant.agent_id
if ([string]::IsNullOrWhiteSpace($taskId)) { Deny 'Grant task_id is required.' }
if ($grant.work_order_id -ne $order.work_order_id) { Deny 'Grant and work order are not bound to the same work_order_id.' $taskId $grant.grant_id $agentId }
if ($order.agent_id -ne $agentId) { Deny 'Grant and work order are not bound to the same Agent.' $taskId $grant.grant_id $agentId }
if (@($runner.supported_agents) -notcontains $agentId) { Deny "Runner does not support Agent: $agentId" $taskId $grant.grant_id $agentId }
if ($grant.status -ne 'issued') { Deny "Grant is not issued: $($grant.status)" $taskId $grant.grant_id $agentId }
if ($grant.can_delegate -ne $false -or $grant.network_access -ne 'none' -or $grant.write_access -ne 'none') { Deny 'Grant is broader than the Runner read-only policy.' $taskId $grant.grant_id $agentId }
if ((Get-RiskRank $grant.risk_ceiling) -gt 2 -or (Get-RiskRank $order.risk_ceiling) -gt 2) { Deny 'Runner dispatch is limited to L0-L2.' $taskId $grant.grant_id $agentId }
if ((Get-Date).ToUniversalTime() -ge [DateTime]::Parse($grant.expires_at).ToUniversalTime()) { Deny 'Delegation Grant has expired.' $taskId $grant.grant_id $agentId }
if (@($grant.allowed_tools | Where-Object { @($order.allowed_tools) -notcontains $_ }).Count -gt 0) { Deny 'Grant contains a tool outside the work order allowlist.' $taskId $grant.grant_id $agentId }
if (@($grant.data_refs | Where-Object { @($order.input_refs) -notcontains $_ }).Count -gt 0) { Deny 'Grant contains a data reference outside the work order input refs.' $taskId $grant.grant_id $agentId }
if (Test-Path -LiteralPath $revocationPath -PathType Leaf) {
  foreach ($line in Get-Content -LiteralPath $revocationPath -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $revocation = $line | ConvertFrom-Json
    if ($revocation.grant_id -eq $grant.grant_id) { Deny 'Delegation Grant has been revoked.' $taskId $grant.grant_id $agentId }
  }
}

$attestationDoc = Read-JsonFile $AttestationPath $attestationRoot 'Sandbox Attestation'
$attestation = $attestationDoc.Value
if ($runner.requires_attestation -ne $true) { Deny 'Runner registry must require an Attestation.' $taskId $grant.grant_id $agentId }
if ($attestation.status -ne 'verified' -or $attestation.runner_id -ne $RunnerId -or $attestation.task_id -ne $taskId -or $attestation.agent_id -ne $agentId) { Deny 'Sandbox Attestation is not verified for this Runner, task, or Agent.' $taskId $grant.grant_id $agentId }
if ($attestation.host_workspace_mounted -ne $false -or $attestation.agent_network -ne 'none' -or $attestation.mcp_mode -ne 'allowlist_read_only' -or $attestation.file_export -ne $false -or $attestation.web_access -ne $false -or $attestation.erp_access -ne $false -or $attestation.secret_mode -ne 'secret_ref_only') { Deny 'Sandbox Attestation violates the Runner isolation contract.' $taskId $grant.grant_id $agentId }
if (-not (Test-Path -LiteralPath $attestation.isolation_root -PathType Container)) { Deny 'Sandbox isolation root is unavailable.' $taskId $grant.grant_id $agentId }
$taskRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot ".qianlima\run-traces\sandbox-workspaces\$taskId")).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$isolationFull = [IO.Path]::GetFullPath($attestation.isolation_root)
if (-not $isolationFull.StartsWith($taskRoot, [StringComparison]::OrdinalIgnoreCase)) { Deny 'Sandbox isolation root is outside the task-specific workspace.' $taskId $grant.grant_id $agentId }
if ((Get-Date).ToUniversalTime() -ge [DateTime]::Parse($attestation.expires_at).ToUniversalTime()) { Deny 'Sandbox Attestation has expired.' $taskId $grant.grant_id $agentId }
if ([string]$attestation.evidence_hash -notmatch '^sha256:[0-9a-fA-F]{64}$') { Deny 'Sandbox Attestation evidence_hash is not a SHA-256 reference.' $taskId $grant.grant_id $agentId }

if ($Mode -eq 'Execute' -and $runner.execution_enabled -ne $true) { Deny "Execution is disabled for Runner $RunnerId; this release only supports dry-run/mock dispatch." $taskId $grant.grant_id $agentId }

$receiptId = "runner-$RunnerId-$taskId-$([Guid]::NewGuid().ToString('n').Substring(0, 12))"
$receiptPath = Join-Path $receiptRoot "$receiptId.json"
if (-not (Test-Path -LiteralPath (Split-Path -Parent $receiptPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $receiptPath) -Force | Out-Null }
$receipt = [ordered]@{
  schema_version = 1; receipt_type = 'qianlima_runner_dispatch_receipt'; receipt_id = $receiptId
  runner_id = $RunnerId; provider = $runner.provider; task_id = $taskId; work_order_id = $order.work_order_id; grant_id = $grant.grant_id; agent_id = $agentId
  mode = $Mode; status = if ($Mode -eq 'DryRun') { 'validated_dry_run' } else { 'rejected' }; policy_decision = if ($Mode -eq 'DryRun') { 'allow' } else { 'deny' }
  attestation_id = $attestation.attestation_id; process_started = $false; network = $runner.network_policy; write_access = 'none'; artifact_refs = @($order.expected_artifacts)
  created_at = (Get-Date).ToUniversalTime().ToString('o'); note = if ($Mode -eq 'DryRun') { 'Contract validated; Docker and vendor processes were not started.' } else { 'Execution is disabled until a real isolated Runner is separately approved.' }
}
[IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
& $auditScript -EventType runner_dispatch_validated -Decision complete -TaskId $taskId -GrantId $grant.grant_id -AgentId $agentId -DataRef @($grant.data_refs) -Reason "Runner $RunnerId passed work order, Grant, Attestation, and policy checks in $Mode mode." 6>$null | Out-Null
$result = [ordered]@{ status = $receipt.status; runner_id = $RunnerId; task_id = $taskId; grant_id = $grant.grant_id; attestation_id = $attestation.attestation_id; receipt_path = $receiptPath; process_started = $false; note = $receipt.note }
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List }
if ($Mode -eq 'Execute') { exit 1 }
