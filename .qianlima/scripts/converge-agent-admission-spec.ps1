<##
.SYNOPSIS
  Performs the Converge phase without modifying the core Harness.
##>
param(
  [Parameter(Mandatory = $true)] [string]$SpecPath,
  [Parameter(Mandatory = $true)] [string]$AnalysisPath,
  [ValidateSet('Shadow','Promote','Freeze')] [string]$Mode = 'Shadow',
  [ValidateSet('passed','partial','missing')] [string]$EvidenceStatus = 'missing',
  [ValidateSet('validated_dry_run','completed','missing')] [string]$RunnerStatus = 'missing',
  [string]$HumanApprovalRef = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$convergenceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\spec-convergence')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$analysis = Get-Content -LiteralPath $AnalysisPath -Raw -Encoding UTF8 | ConvertFrom-Json
$violations = [System.Collections.Generic.List[string]]::new()
if ($analysis.status -ne 'passed') { [void]$violations.Add('analysis_not_passed') }
if ($Mode -eq 'Shadow' -and $RunnerStatus -ne 'validated_dry_run') { [void]$violations.Add('shadow_requires_validated_dry_run') }
if ($Mode -eq 'Shadow' -and $EvidenceStatus -notin @('passed','partial')) { [void]$violations.Add('shadow_requires_evidence_result') }
if ($Mode -eq 'Promote' -and [string]::IsNullOrWhiteSpace($HumanApprovalRef)) { [void]$violations.Add('human_approval_ref_required') }
$status = if ($violations.Count -gt 0) { 'frozen' } elseif ($Mode -eq 'Shadow') { 'shadow_converged' } else { 'promotion_candidate' }
if (-not (Test-Path -LiteralPath $convergenceRoot -PathType Container)) { New-Item -ItemType Directory -Path $convergenceRoot -Force | Out-Null }
$id = "spec-convergence-$($analysis.spec_id)-$([Guid]::NewGuid().ToString('n').Substring(0, 12))"; $outPath = Join-Path $convergenceRoot "$id.json"
$record = [ordered]@{ schema_version=1; convergence_id=$id; spec_id=$analysis.spec_id; analysis_id=$analysis.analysis_id; mode=$Mode; status=$status; evidence_status=$EvidenceStatus; runner_status=$RunnerStatus; human_approval_ref=if($HumanApprovalRef){$HumanApprovalRef}else{$null}; violation_ids=@($violations); core_harness_modified=$false; production_change=$false; created_at=(Get-Date).ToUniversalTime().ToString('o') }
[IO.File]::WriteAllText($outPath, ($record | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$audit = Join-Path $PSScriptRoot 'write-audit-event.ps1'; $decision = if ($status -eq 'frozen') { 'freeze' } else { 'complete' }
& $audit -EventType specification_converged -Decision $decision -Reason "Spec $($analysis.spec_id) convergence status: $status; core Harness unchanged." 6>$null | Out-Null
$result = [ordered]@{ status=$status; convergence_id=$id; convergence_path=$outPath; spec_id=$analysis.spec_id; violations=@($violations); production_change=$false; core_harness_modified=$false }
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List }
if ($violations.Count -gt 0) { exit 1 }
