<##
.SYNOPSIS
  Converts a validated shadow candidate into a human-review promotion candidate.
.DESCRIPTION
  This is a fail-closed gate. It requires an explicit human approval reference,
  but never applies a production edit or changes a Harness file.
##>
param(
  [Parameter(Mandatory = $true)] [string]$CandidatePath,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._:/-]{3,200}$')] [string]$HumanApprovalRef,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $PSScriptRoot 'validate-improvement-candidate.ps1'
$candidate = Get-Content -LiteralPath (Resolve-Path -LiteralPath $CandidatePath -ErrorAction Stop) -Raw -Encoding UTF8 | ConvertFrom-Json
$validationOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -CandidatePath $CandidatePath -PassThru 2>&1)
$validationCode = $LASTEXITCODE
$validationText = ($validationOutput -join "`n")
$validation = $null
$start = $validationText.IndexOf('{'); $end = $validationText.LastIndexOf('}')
if ($start -ge 0 -and $end -gt $start) { try { $validation = $validationText.Substring($start, $end - $start + 1) | ConvertFrom-Json } catch { } }
if ($validationCode -ne 0 -or $null -eq $validation -or $validation.status -ne 'passed') {
  $blocked = [ordered]@{ status = 'blocked'; stage = 'candidate_validation'; reason = 'Candidate did not pass the independent evaluation gate.'; validation = $validation; production_change = $false; automatic_promotion = $false; external_calls = $false }
  if ($PassThru) { $blocked | ConvertTo-Json -Depth 12 } else { $blocked | Format-List }
  exit 1
}
if ([string]$candidate.lifecycle_state -ne 'shadow_converged') {
  $blocked = [ordered]@{ status = 'blocked'; stage = 'shadow_convergence'; reason = 'Only a shadow_converged candidate can enter promotion review.'; lifecycle_state = [string]$candidate.lifecycle_state; production_change = $false; automatic_promotion = $false; external_calls = $false }
  if ($PassThru) { $blocked | ConvertTo-Json -Depth 12 } else { $blocked | Format-List }
  exit 1
}
$result = [ordered]@{ status = 'promotion_candidate'; candidate_id = [string]$candidate.candidate_id; candidate_version = [string]$candidate.candidate_version; human_approval_ref = $HumanApprovalRef; approval_required = $true; production_change = $false; automatic_promotion = $false; next_step = 'Separate human release decision and a new production revision are required.'; external_calls = $false; core_harness_changed = $false; validated_by = 'validate-improvement-candidate.ps1' }
if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
