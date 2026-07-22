param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$GrantId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$AgentId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$WorkOrderId,
  [Parameter(Mandatory = $true)] [string[]]$DataRef,
  [Parameter(Mandatory = $true)] [string[]]$AllowedTool,
  [ValidateSet('L0', 'L1', 'L2', 'L3', 'L4')] [string]$RiskCeiling = 'L1',
  [Parameter(Mandatory = $true)] [ValidatePattern('^[a-zA-Z0-9._-]+$')] [string]$VerifierAgentId,
  [ValidateRange(1, 30)] [int]$ExpiresMinutes = 10,
  [ValidateRange(1, 20)] [int]$MaxSteps = 3,
  [ValidateRange(1, 20)] [int]$MaxToolCalls = 2,
  [string]$ConfirmationRef = '',
  [string]$RollbackRef = '',
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if ($DataRef.Count -eq 0 -or $AllowedTool.Count -eq 0) { throw 'A grant requires at least one data reference and one allowed tool.' }
if ($RiskCeiling -eq 'L4' -and ([string]::IsNullOrWhiteSpace($ConfirmationRef) -or [string]::IsNullOrWhiteSpace($RollbackRef))) { throw 'L4 grants require ConfirmationRef and RollbackRef.' }
function Test-SafeRef([string]$Value) { return -not ([IO.Path]::IsPathRooted($Value) -or $Value -match '(^|[\\/])\.\.([\\/]|$)') }
foreach ($value in @($DataRef) + @($AllowedTool) + @($ConfirmationRef) + @($RollbackRef)) { if (-not (Test-SafeRef $value)) { throw 'Grant references must be logical or workspace-relative.' } }
$forbidden = @('api_key', 'access_token', 'refresh_token', 'password', 'cookie', 'authorization:')
foreach ($value in @($DataRef) + @($AllowedTool) + @($ConfirmationRef) + @($RollbackRef)) { foreach ($needle in $forbidden) { if ($value -match [regex]::Escape($needle)) { throw 'Grants cannot contain secrets or authorization material.' } } }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$localRegistryPath = Join-Path $PSScriptRoot '..\local-a2a-agents.json'
$cardsPath = Join-Path $PSScriptRoot '..\agent-cards.yaml'
$known = $false
if (Test-Path -LiteralPath $localRegistryPath) { $local = Get-Content -LiteralPath $localRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json; $known = @($local.agents | Where-Object { $_.id -eq $AgentId }).Count -gt 0 }
if (-not $known -and (Test-Path -LiteralPath $cardsPath)) { $known = Select-String -LiteralPath $cardsPath -Pattern "(?m)^\s*- id:\s*$([regex]::Escape($AgentId))\s*$" -Quiet }
if (-not $known) { throw "Unknown Agent capability contract: $AgentId" }
$grantRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\delegation-grants')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $grantRoot "$GrantId.json" }
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFullPath.StartsWith($grantRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Delegation grants must be written under .qianlima/run-traces/delegation-grants.' }
if (Test-Path -LiteralPath $outputFullPath) { throw "Grant already exists; create a new grant_id: $GrantId" }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputFullPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $outputFullPath) -Force | Out-Null }
$grant = [ordered]@{
  schema_version = 1; contract_type = 'qianlima_delegation_grant'; grant_id = $GrantId; agent_id = $AgentId; task_id = $TaskId; work_order_id = $WorkOrderId
  data_refs = @($DataRef); allowed_tools = @($AllowedTool); budget = [ordered]@{ max_steps = $MaxSteps; max_tool_calls = $MaxToolCalls }
  risk_ceiling = $RiskCeiling; expires_at = (Get-Date).ToUniversalTime().AddMinutes($ExpiresMinutes).ToString('o'); verifier_agent_id = $VerifierAgentId
  can_delegate = $false; network_access = 'none'; write_access = 'none'; confirmation_ref = if ($ConfirmationRef) { $ConfirmationRef } else { $null }; rollback_ref = if ($RollbackRef) { $RollbackRef } else { $null }; status = 'issued'; revocation = [ordered]@{ on_failure = 'revoke_and_shrink'; on_cancel = 'revoke'; on_expiry = 'revoke' }
}
[IO.File]::WriteAllText($outputFullPath, ($grant | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
if ($PassThru) { $grant | ConvertTo-Json -Depth 8 } else { Write-Host "Delegation grant created: $outputFullPath" }
