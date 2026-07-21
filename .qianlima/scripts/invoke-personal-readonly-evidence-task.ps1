<##
.SYNOPSIS
  Explicitly invokes the only personal-edition local stdio evidence tool.
.DESCRIPTION
  This adapter is the personal Broker enforcement point. It accepts no address,
  listener, remote endpoint, network permission, business write, or delegation.
  A valid task-matching Grant is mandatory for every invocation.
##>
param(
  [Parameter(Mandatory = $true)] [string]$EnvelopePath,
  [Parameter(Mandatory = $true)] [string]$GrantPath,
  [Parameter(Mandatory = $true)] [switch]$ExplicitStart,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$grantRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\delegation-grants')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$registryPath = Join-Path $projectRoot '.qianlima\local-a2a-agents.json'
$workerScript = Join-Path $PSScriptRoot 'invoke-local-readonly-evidence-agent.ps1'
$auditScript = Join-Path $PSScriptRoot 'write-personal-audit-event.ps1'
$receiptScript = Join-Path $PSScriptRoot 'new-personal-evidence-receipt.ps1'
$taskId = ''
$grantId = ''
$agentId = ''

function Get-Field($Object, [string]$Name) {
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}
function Assert-TracePath([string]$Path, [string]$Root, [string]$Message) {
  $full = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  if (-not $full.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) { throw $Message }
  return $full
}
function Assert-NoTransportConfiguration($Object, [string]$ObjectName) {
  foreach ($property in $Object.PSObject.Properties) {
    if ($property.Name -match '^(url|endpoint|remote_endpoint|port|host|network_dispatch)$') { throw "$ObjectName cannot contain address or remote dispatch configuration." }
  }
}
function Write-Deny([string]$Reason) {
  try {
    $auditArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $auditScript, '-EventType', 'personal_tool_denied', '-Decision', 'deny', '-Reason', $Reason)
    if (-not [string]::IsNullOrWhiteSpace($taskId)) { $auditArgs += @('-TaskId', $taskId) }
    if (-not [string]::IsNullOrWhiteSpace($grantId)) { $auditArgs += @('-GrantId', $grantId) }
    if (-not [string]::IsNullOrWhiteSpace($agentId)) { $auditArgs += @('-AgentId', $agentId) }
    & powershell.exe @auditArgs | Out-Null
  } catch { }
}

try {
  if (-not $ExplicitStart) { throw 'Personal local stdio invocation requires explicit start.' }
  $envelopeFullPath = Assert-TracePath $EnvelopePath $traceRoot 'Evidence task envelope must stay under .qianlima/run-traces.'
  $grantFullPath = Assert-TracePath $GrantPath $grantRoot 'Grant must stay under .qianlima/run-traces/delegation-grants.'
  $envelope = Get-Content -LiteralPath $envelopeFullPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $grant = Get-Content -LiteralPath $grantFullPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $taskId = [string](Get-Field $envelope 'task_id')
  $grantId = [string](Get-Field $grant 'grant_id')
  $agentId = [string](Get-Field $envelope 'agent_id')
  Assert-NoTransportConfiguration $envelope 'Evidence task'
  Assert-NoTransportConfiguration $grant 'Grant'
  $registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $registration = @($registry.agents | Where-Object { (Get-Field $_ 'id') -eq 'local-readonly-evidence-checker' }) | Select-Object -First 1
  if ($null -eq $registration) { throw 'The local read-only evidence checker is not registered.' }
  if ((Get-Field $registration 'transport') -ne 'stdio' -or (Get-Field $registration 'dispatch_enabled') -ne $false -or (Get-Field $registration 'network_access') -ne 'none' -or (Get-Field $registration 'write_access') -ne 'none' -or (Get-Field $registration 'can_delegate') -ne $false) { throw 'Local Agent registration violates the personal read-only policy.' }
  if ((Get-Field $envelope 'tool_id') -ne 'qianlima_readonly_evidence_task') { throw 'Only qianlima_readonly_evidence_task is permitted.' }
  if ((Get-Field $envelope 'agent_id') -ne 'local-readonly-evidence-checker') { throw 'Only the registered local read-only evidence checker is permitted.' }
  if ((Get-Field $grant 'task_id') -ne $taskId -or (Get-Field $grant 'agent_id') -ne 'local-readonly-evidence-checker' -or (Get-Field $grant 'tool_id') -ne 'qianlima_readonly_evidence_task') { throw 'Grant does not match task, Agent, and tool.' }
  if ((Get-Field $grant 'status') -ne 'issued' -or (Get-Field $grant 'revoked') -eq $true) { throw 'Grant is not active.' }
  if ((Get-Field $grant 'network_access') -ne 'none' -or (Get-Field $grant 'write_access') -ne 'none' -or (Get-Field $grant 'can_delegate') -ne $false) { throw 'Grant violates no-network, no-write, and no-delegation policy.' }
  if ((Get-Field $grant 'risk_ceiling') -notin @('L0', 'L1', 'L2', 'L3')) { throw 'Personal local evidence tool rejects L4 or unknown risk ceilings.' }
  if ((Get-Date).ToUniversalTime() -ge [DateTime]::Parse((Get-Field $grant 'expires_at')).ToUniversalTime()) { throw 'Grant has expired.' }
  if (@((Get-Field $grant 'allowed_tools')) -notcontains 'qianlima_readonly_evidence_task' -or @((Get-Field $grant 'allowed_tools')).Count -ne 1) { throw 'Grant must allow only qianlima_readonly_evidence_task.' }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -EventType personal_tool_grant_checked -Decision allow -TaskId $taskId -GrantId $grantId -AgentId $agentId -Reason 'Explicit local stdio Grant matched the task and read-only policy.' | Out-Null
  $workerResult = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $workerScript -EnvelopePath $envelopeFullPath -PassThru | ConvertFrom-Json
  $sourceRefs = @((Get-Field $envelope 'input_refs') | ForEach-Object { Get-Field $_ 'artifact_id' })
  $receipt = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $receiptScript -ReceiptId "evidence-$taskId" -TaskId $taskId -GrantId $grantId -AgentId $agentId -SourceRef $sourceRefs -ArtifactRef (Get-Field $workerResult 'artifact_ref') -IntegrityHash (Get-Field $workerResult 'artifact_hash') -PassThru | ConvertFrom-Json
  $completionAudit = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $auditScript -EventType personal_tool_completed -Decision complete -TaskId $taskId -GrantId $grantId -AgentId $agentId -Reason 'Local read-only evidence Agent completed through stdio.' -PassThru | ConvertFrom-Json
  $result = [ordered]@{ tool_id = 'qianlima_readonly_evidence_task'; status = 'completed'; transport = 'stdio'; task_id = $taskId; grant_id = $grantId; agent_id = $agentId; artifact_ref = Get-Field $workerResult 'artifact_ref'; artifact_hash = Get-Field $workerResult 'artifact_hash'; evidence_receipt = $receipt; audit_event = $completionAudit }
  if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List }
} catch {
  Write-Deny $_.Exception.Message
  throw
}
