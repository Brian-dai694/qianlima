<##
.SYNOPSIS
  Creates a specification before an Agent admission or dispatch plan.
##>
param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$SpecId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$AgentId,
  [Parameter(Mandatory = $true)] [string]$Goal,
  [ValidateSet('L0','L1','L2','L3','L4')] [string]$RiskLevel = 'L1',
  [ValidateSet('public','internal_sanitized','confidential_reference_only')] [string]$DataScope = 'internal_sanitized',
  [string[]]$AllowedTool = @('read_selected_sources'),
  [string]$RunnerId = 'docker_local_mock',
  [int]$MaxSteps = 4,
  [int]$MaxToolCalls = 3,
  [int]$TimeoutMs = 90000,
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Goal)) { throw 'Goal is required.' }
if ($MaxSteps -lt 1 -or $MaxToolCalls -lt 1 -or $TimeoutMs -lt 1) { throw 'Specification budgets must be positive.' }
foreach ($value in @($Goal) + @($AllowedTool)) { if ($value -match '(?i)(api[_-]?key|access[_-]?token|password|cookie|authorization:)') { throw 'Specifications cannot contain secret material.' } }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$specRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\specifications\drafts')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $specRoot "$SpecId.json" }
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $outputFullPath.StartsWith($specRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Admission specs must be written under .qianlima/specifications/drafts.' }
if (Test-Path -LiteralPath $outputFullPath) { throw "Spec already exists; create a new spec_id: $SpecId" }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputFullPath) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $outputFullPath) -Force | Out-Null }
$spec = [ordered]@{
  schema_version = 1; spec_type = 'qianlima_agent_admission_spec'; spec_id = $SpecId; spec_version = '1.0.0'; north_star_protocol_version = '1.0.0'; lifecycle_state = 'specified'; agent_id = $AgentId; goal = $Goal; risk_level = $RiskLevel; data_scope = $DataScope; allowed_tools = @($AllowedTool); runner_id = $RunnerId
  budget = [ordered]@{ max_steps = $MaxSteps; max_tool_calls = $MaxToolCalls; timeout_ms = $TimeoutMs }
  verification = [ordered]@{ verifier_agent_id = 'evidence_checker'; pass_condition = 'evidence_receipt_passed'; required_fields = @('source_refs','data_time_range','assumptions','uncertainties','integrity_hash','verifier_id') }
  stop_conditions = @('evidence_sufficient','budget_exhausted','authorization_missing','conflict_found')
  rollback_plan = [ordered]@{ required = ($RiskLevel -eq 'L4'); preflight_snapshot = ($RiskLevel -eq 'L4'); reference = if ($RiskLevel -eq 'L4') { 'pending_snapshot_ref' } else { $null } }
  forbidden_capabilities = @('network_access','write_access','file_export','web_access','erp_access','arbitrary_mcp','direct_agent_to_agent','secrets_in_prompt')
  approval_state = [ordered]@{ human_confirmation_required = ($RiskLevel -eq 'L4'); status = 'pending_analysis'; reference = $null }
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($outputFullPath, ($spec | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
if ($PassThru) { $spec | ConvertTo-Json -Depth 12 } else { Write-Host "Agent admission spec created: $outputFullPath" }
