<#
.SYNOPSIS
  Enforces collaboration, lineage, and error-independence gates before shadow fusion.
#>
param(
  [Parameter(Mandatory = $true)] [string]$CollaborationPath,
  [Parameter(Mandatory = $true)] [string]$FusionPlanPath,
  [Parameter(Mandatory = $true)] [string[]]$ClaimPackPath,
  [Parameter(Mandatory = $true)] [string]$ErrorCorrelationPath,
  [string]$OutputPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$collaborationValidator = Join-Path $PSScriptRoot 'validate-employee-agent-collaboration.ps1'
$independenceEvaluator = Join-Path $PSScriptRoot 'evaluate-error-independence.ps1'
$shadowRunner = Join-Path $PSScriptRoot 'invoke-shadow-fusion.ps1'

$collaborationResult = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $collaborationValidator -ContractPath $CollaborationPath -PassThru | ConvertFrom-Json
if ($collaborationResult.status -ne 'validated') { throw 'Employee Agent collaboration contract was rejected.' }
$independenceResult = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $independenceEvaluator -InputPath $ErrorCorrelationPath -PassThru | ConvertFrom-Json
if ($independenceResult.status -in @('rejected', 'reselect_required')) { throw "Candidate independence gate rejected the team: $($independenceResult.status)" }

$collaboration = Get-Content -LiteralPath $CollaborationPath -Raw -Encoding UTF8 | ConvertFrom-Json
$plan = Get-Content -LiteralPath $FusionPlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
$packs = @($ClaimPackPath | ForEach-Object { Get-Content -LiteralPath $_ -Raw -Encoding UTF8 | ConvertFrom-Json })
if ($collaboration.task_id -ne $plan.task_id -or $collaboration.fusion_id -ne $plan.fusion_id) { throw 'Collaboration and Fusion Plan lineage mismatch.' }
if ($collaboration.risk_level -ne $plan.risk_level) { throw 'Collaboration and Fusion Plan risk mismatch.' }

$candidateParticipants = @($collaboration.participants | Where-Object { $_.role -eq 'candidate' })
if ($packs.Count -ne $candidateParticipants.Count) { throw 'Every candidate participant requires exactly one Claim Pack.' }
$correlation = Get-Content -LiteralPath $ErrorCorrelationPath -Raw -Encoding UTF8 | ConvertFrom-Json
$candidateModelIds = @($candidateParticipants.model_id | Sort-Object -Unique)
$correlationModelIds = @($correlation.members.id | Sort-Object -Unique)
if (($candidateModelIds -join '|') -ne ($correlationModelIds -join '|')) { throw 'Error-correlation members do not match collaboration candidates.' }
foreach ($member in @($correlation.members)) {
  $participant = @($candidateParticipants | Where-Object { $_.model_id -eq $member.id })
  if ($participant.Count -ne 1 -or $participant[0].error_group -ne $member.error_group) { throw "Error-group lineage mismatch for candidate: $($member.id)" }
}
foreach ($pack in $packs) {
  $matches = @($candidateParticipants | Where-Object {
    $_.employee_id -eq $pack.producer_employee_id -and
    $_.agent_id -eq $pack.producer_agent_id -and
    $_.model_id -eq $pack.producer_model_id -and
    $_.model_version -eq $pack.producer_model_version -and
    $_.work_order_ref -eq $pack.work_order_ref -and
    $_.grant_ref -eq $pack.grant_ref
  })
  if ($matches.Count -ne 1) { throw "Claim Pack producer lineage is not bound to one candidate participant: $($pack.claim_pack_id)" }
}

$receiptId = "collaboration-outcome-$([Guid]::NewGuid().ToString('n'))"
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $traceRoot "$receiptId.json" }
$fullOutputPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $fullOutputPath.StartsWith($traceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Collaboration outcome receipts must be written under .qianlima/run-traces.' }
if (Test-Path -LiteralPath $fullOutputPath) { throw 'Collaboration outcome receipts are immutable; choose a new output path.' }
$shadow = & $shadowRunner -FusionPlanPath $FusionPlanPath -ClaimPackPath $ClaimPackPath -PassThru | ConvertFrom-Json

$unresolved = @($shadow.material_conflicts | ForEach-Object { $_.claim_id })
$status = if ($unresolved.Count -gt 0) { 'disputed_outcome' } elseif ($independenceResult.status -eq 'shadow_only_insufficient_history') { 'partial_outcome' } else { 'verified_outcome' }
$acceptedClaimRefs = @()
if ($status -eq 'verified_outcome') { $acceptedClaimRefs = @($packs | ForEach-Object { $_.claims } | ForEach-Object { $_.claim_id } | Select-Object -Unique) }
$shadowReportPath = Join-Path $traceRoot "$($shadow.report_id).json"
if (-not (Test-Path -LiteralPath $shadowReportPath -PathType Leaf)) { throw 'Shadow report is missing before outcome receipt creation.' }
$shadowReportHash = (Get-FileHash -LiteralPath $shadowReportPath -Algorithm SHA256).Hash.ToLowerInvariant()
$receipt = [ordered]@{
  schema_version = 1
  receipt_id = $receiptId
  collaboration_id = $collaboration.collaboration_id
  fusion_id = $plan.fusion_id
  task_id = $plan.task_id
  final_outcome_ref = $shadow.report_id
  accepted_claim_refs = @($acceptedClaimRefs)
  rejected_claim_refs = @()
  unresolved_claim_refs = $unresolved
  human_adopter = if ($status -eq 'disputed_outcome') { 'required' } else { 'none' }
  observed_at = (Get-Date).ToUniversalTime().ToString('o')
  policy_version = 'north-star-v1'
  supersedes = $null
  status = $status
  independence_status = $independenceResult.status
  shadow_report_ref = Split-Path -Leaf $shadow.report_id
  shadow_report_sha256 = $shadowReportHash
  adoption_authority = 'none'
  primary_result_affected = $false
  permission_change = 'none'
  budget_change = 'none'
  external_calls = $false
  permissions_granted = $false
}
[IO.File]::WriteAllText($fullOutputPath, ($receipt | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
if ($PassThru) { $receipt | ConvertTo-Json -Depth 12 } else { [PSCustomObject]$receipt | Format-List }
