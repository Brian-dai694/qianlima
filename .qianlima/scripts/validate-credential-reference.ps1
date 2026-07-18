<##
.SYNOPSIS
  Validates a credential reference without reading or printing its secret value.
##>
param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$CredentialId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$ConsumerId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$TaskId,
  [switch]$RequirePresent,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$policyPath = Join-Path $projectRoot '.qianlima\credential-policy.json'
$audit = Join-Path $PSScriptRoot 'write-audit-event.ps1'
$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
$ref = @($policy.references | Where-Object { $_.credential_id -eq $CredentialId }) | Select-Object -First 1
function Deny([string]$Reason) {
  & $audit -EventType credential_reference_rejected -Decision deny -TaskId $TaskId -AgentId $ConsumerId -Reason $Reason 6>$null | Out-Null
  $result = [ordered]@{ status = 'denied'; credential_id = $CredentialId; consumer_id = $ConsumerId; task_id = $TaskId; secret_value_exposed = $false; reason = $Reason }
  if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
  exit 1
}
if ($null -eq $ref) { Deny 'Credential reference is not registered.' }
if ($ref.enabled -ne $true) { Deny 'Credential reference is disabled pending human approval.' }
if (@($ref.allowed_consumers) -notcontains $ConsumerId) { Deny 'Consumer is not allowed for this credential reference.' }
if ([string]::IsNullOrWhiteSpace($ref.environment_variable) -or $ref.environment_variable -match '(?i)(key|token|secret|password)\s*[:=]') { Deny 'Credential policy contains an unsafe environment reference.' }
$present = $false
if ($RequirePresent) { $present = -not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($ref.environment_variable)); if (-not $present) { Deny 'Required credential reference is not present in the Runner environment.' } }
$result = [ordered]@{ status = 'validated'; credential_id = $CredentialId; provider = $ref.provider; consumer_id = $ConsumerId; task_id = $TaskId; environment_variable = $ref.environment_variable; scope = $ref.scope; present = $present; secret_value_exposed = $false; task_end_revoke = [bool]$policy.runtime_rules.task_end_revoke }
& $audit -EventType credential_reference_validated -Decision allow -TaskId $TaskId -AgentId $ConsumerId -Reason 'Credential reference contract validated without exposing a secret value.' 6>$null | Out-Null
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
