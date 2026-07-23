<#
.SYNOPSIS
  Runs the registered local read-only A2A-compatible agent without a listener.
.DESCRIPTION
  This is the runtime entry point used by Qianlima after natural-language routing.
  It never requires an address from the user and delegates only to the bounded
  local evidence checker through the existing local contract mock.
#>
param(
  [Parameter(Mandatory = $true)] [string]$EnvelopePath,
  [ValidatePattern('^[A-Za-z0-9_-]{3,80}$')] [string]$AgentId = 'local-readonly-evidence-checker',
  [Parameter(Mandatory = $true)] [string]$GrantPath,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$registryPath = Join-Path $projectRoot '.qianlima\local-a2a-agents.json'
$mockScript = Join-Path $PSScriptRoot 'invoke-a2a-local-mock.ps1'
$auditScript = Join-Path $PSScriptRoot 'write-audit-event.ps1'
$evidenceScript = Join-Path $PSScriptRoot 'new-evidence-receipt.ps1'
$revocationPath = Join-Path $projectRoot '.qianlima\run-traces\grant-revocations.jsonl'
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { throw 'No local A2A agent is registered.' }
$grantFullPath = (Resolve-Path -LiteralPath $GrantPath -ErrorAction Stop).Path
$grantRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\delegation-grants')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (-not $grantFullPath.StartsWith($grantRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Grant must be inside .qianlima/run-traces/delegation-grants.' }
$grant = Get-Content -LiteralPath $grantFullPath -Raw -Encoding UTF8 | ConvertFrom-Json
$envelope = Get-Content -LiteralPath $EnvelopePath -Raw -Encoding UTF8 | ConvertFrom-Json
$registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$agent = @($registry.agents | Where-Object { $_.id -eq $AgentId }) | Select-Object -First 1
if ($null -eq $agent -or $agent.status -ne 'registered_local_only') { throw 'Requested local agent is not available.' }
if ($agent.dispatch_enabled -ne $false -or $agent.network_access -ne 'none' -or $agent.write_access -ne 'none') { throw 'Local agent registration violates the read-only policy.' }
if ($grant.agent_id -ne $AgentId -or $grant.task_id -ne $envelope.task_id) { throw 'Grant does not match Agent or task envelope.' }
if ($grant.status -ne 'issued' -or $grant.can_delegate -ne $false -or $grant.network_access -ne 'none' -or $grant.write_access -ne 'none') { throw 'Grant violates the local read-only policy.' }
if ((Get-Date).ToUniversalTime() -ge [DateTime]::Parse($grant.expires_at).ToUniversalTime()) { throw 'Delegation grant has expired.' }
if ($grant.risk_ceiling -eq 'L4') { throw 'Local read-only Agent rejects L4 grants.' }
if (Test-Path -LiteralPath $revocationPath -PathType Leaf) {
  foreach ($line in Get-Content -LiteralPath $revocationPath -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $revocation = $line | ConvertFrom-Json
    if ($revocation.grant_id -eq $grant.grant_id) {
      & $auditScript -EventType grant_rejected_revoked -Decision deny -TaskId $envelope.task_id -GrantId $grant.grant_id -AgentId $AgentId -Reason 'Grant was revoked before dispatch.' | Out-Null
      throw 'Delegation grant has been revoked.'
    }
  }
}
& $auditScript -EventType grant_checked -Decision allow -TaskId $envelope.task_id -GrantId $grant.grant_id -AgentId $AgentId -DataRef @($grant.data_refs) -Reason 'Grant matched Agent, task, expiry, and read-only policy.' | Out-Null

$result = & $mockScript -EnvelopePath $EnvelopePath -PassThru | ConvertFrom-Json
$sourceRefs = @($envelope.input_refs | ForEach-Object { $_.artifact_id })
$evidence = powershell.exe -NoProfile -ExecutionPolicy Bypass -File $evidenceScript -ReceiptId "evidence-$($envelope.task_id)" -TaskId $envelope.task_id -GrantId $grant.grant_id -AgentId $AgentId -ConclusionSummary 'Bounded local evidence contract completed.' -SourceRef $sourceRefs -DataTimeRange 'provided_by_input_artifact' -Assumption 'Input references are sanitized.' -Uncertainty 'No live refresh performed.' -MethodRef 'local_readonly_evidence_checker_v1' -ArtifactRef $result.artifact_ref -IntegrityHash $result.artifact_hash -SourceClassification internal_sanitized -VerificationStatus passed -VerifierAgentId $grant.verifier_agent_id -PassThru | ConvertFrom-Json
& $auditScript -EventType local_agent_completed -Decision complete -TaskId $envelope.task_id -GrantId $grant.grant_id -AgentId $AgentId -DataRef @($sourceRefs) -Reason 'Local Agent returned a verified bounded result.' | Out-Null
$result | Add-Member -NotePropertyName evidence_receipt -NotePropertyValue $evidence -Force
if ($PassThru) { $result | ConvertTo-Json -Depth 6 } else { $result | Format-List }
