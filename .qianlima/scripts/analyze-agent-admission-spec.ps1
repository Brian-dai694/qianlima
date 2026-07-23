<##
.SYNOPSIS
  Performs the Analyze phase against the North Star protocol.
##>
param(
  [Parameter(Mandatory = $true)] [string]$SpecPath,
  [Parameter(Mandatory = $true)] [string]$ComplexityProposalPath,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$specRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\specifications')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$analysisRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\spec-analyses')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$complexityValidator = Join-Path $PSScriptRoot 'validate-complexity-admission.ps1'
$protocol = Get-Content -LiteralPath (Join-Path $projectRoot '.qianlima\specifications\north-star-protocol.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$complexityOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $complexityValidator -ProposalPath $ComplexityProposalPath -PassThru 2>&1)
$complexityCode = $LASTEXITCODE
$complexityText = ($complexityOutput -join "`n")
$complexityResult = $null
$complexityStart = $complexityText.IndexOf('{'); $complexityEnd = $complexityText.LastIndexOf('}')
if ($complexityStart -ge 0 -and $complexityEnd -gt $complexityStart) { try { $complexityResult = $complexityText.Substring($complexityStart, $complexityEnd - $complexityStart + 1) | ConvertFrom-Json } catch { } }
$fullSpecPath = (Resolve-Path -LiteralPath $SpecPath -ErrorAction Stop).Path
if (-not $fullSpecPath.StartsWith($specRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Spec must be inside the governed specifications directory.' }
$spec = Get-Content -LiteralPath $fullSpecPath -Raw -Encoding UTF8 | ConvertFrom-Json
$violations = [System.Collections.Generic.List[string]]::new()
$complexityPassed = $complexityCode -eq 0 -and $null -ne $complexityResult -and $complexityResult.status -eq 'passed'
if (-not $complexityPassed) { [void]$violations.Add('complexity_admission_required_or_failed') }
$required = @('spec_id','spec_version','north_star_protocol_version','agent_id','goal','risk_level','data_scope','allowed_tools','runner_id','budget','verification','stop_conditions','rollback_plan','approval_state')
foreach ($field in $required) { if ($null -eq $spec.$field -or ([string]$spec.$field).Length -eq 0) { [void]$violations.Add("missing_$field") } }
if ($spec.north_star_protocol_version -ne $protocol.protocol_version) { [void]$violations.Add('north_star_version_mismatch') }
if ([string]$spec.risk_level -notin @('L0','L1','L2','L3','L4')) { [void]$violations.Add('invalid_risk_level') }
if ([string]$spec.data_scope -notin @('public','internal_sanitized','confidential_reference_only')) { [void]$violations.Add('invalid_data_scope') }
if ([int]$spec.budget.max_steps -lt 1 -or [int]$spec.budget.max_tool_calls -lt 1 -or [int]$spec.budget.timeout_ms -lt 1) { [void]$violations.Add('invalid_budget') }
if (@($spec.forbidden_capabilities | Where-Object { $_ -notin @('network_access','write_access','file_export','web_access','erp_access','arbitrary_mcp','direct_agent_to_agent','secrets_in_prompt') }).Count -gt 0) { [void]$violations.Add('unknown_forbidden_capability') }
if ([string]$spec.risk_level -eq 'L4') {
  if ($spec.rollback_plan.required -ne $true -or $spec.rollback_plan.preflight_snapshot -ne $true) { [void]$violations.Add('L4_rollback_or_snapshot_missing') }
  if ($spec.approval_state.human_confirmation_required -ne $true) { [void]$violations.Add('L4_confirmation_missing') }
}
$raw = Get-Content -LiteralPath $fullSpecPath -Raw -Encoding UTF8
if ($raw -match '(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|password|cookie|authorization:)\s*[:=]') { [void]$violations.Add('secret_pattern_detected') }
$status = if ($violations.Count -eq 0) { 'passed' } else { 'blocked' }
if (-not (Test-Path -LiteralPath $analysisRoot -PathType Container)) { New-Item -ItemType Directory -Path $analysisRoot -Force | Out-Null }
$analysisId = "spec-analysis-$($spec.spec_id)-$([Guid]::NewGuid().ToString('n').Substring(0, 12))"; $analysisPath = Join-Path $analysisRoot "$analysisId.json"
$analysis = [ordered]@{ schema_version=1; analysis_id=$analysisId; spec_id=$spec.spec_id; spec_version=$spec.spec_version; north_star_protocol_version=$protocol.protocol_version; status=$status; violation_ids=@($violations); complexity_admission=$complexityResult; core_harness_modified=$false; production_change=$false; analyzed_at=(Get-Date).ToUniversalTime().ToString('o') }
[IO.File]::WriteAllText($analysisPath, ($analysis | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$audit = Join-Path $PSScriptRoot 'write-audit-event.ps1'; $decision = if ($status -eq 'passed') { 'complete' } else { 'freeze' }
& $audit -EventType specification_analyzed -Decision $decision -Reason "Spec $($spec.spec_id) analysis $status; core Harness remains read-only." 6>$null | Out-Null
$result = [ordered]@{ status=$status; analysis_id=$analysisId; analysis_path=$analysisPath; spec_id=$spec.spec_id; violations=@($violations); complexity_admission=$complexityResult; core_harness_modified=$false }
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List }
if ($status -ne 'passed') { exit 1 }
