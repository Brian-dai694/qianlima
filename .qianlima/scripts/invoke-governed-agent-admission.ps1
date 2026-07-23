<##
.SYNOPSIS
  Admission entry that requires a complexity decision before Agent analysis.
.DESCRIPTION
  This Overlay wrapper does not alter the existing admission scripts. It first
  validates a complexity proposal, then runs the existing Analyze phase for the
  Agent specification. No provider, Runner, Docker, or production file starts.
##>
param(
  [Parameter(Mandatory = $true)] [string]$ComplexityProposalPath,
  [Parameter(Mandatory = $true)] [string]$SpecPath,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$analyzer = Join-Path $PSScriptRoot 'analyze-agent-admission-spec.ps1'
function Parse-JsonResult([object[]]$Output) {
  $text = ($Output -join "`n"); $start = $text.IndexOf('{'); $end = $text.LastIndexOf('}')
  if ($start -ge 0 -and $end -gt $start) { try { return ($text.Substring($start, $end - $start + 1) | ConvertFrom-Json) } catch { } }
  return $null
}
$analysisOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $analyzer -SpecPath $SpecPath -ComplexityProposalPath $ComplexityProposalPath -PassThru 2>&1)
$analysisCode = $LASTEXITCODE
$analysis = Parse-JsonResult $analysisOutput
if ($analysisCode -ne 0 -or $null -eq $analysis -or $analysis.status -ne 'passed') {
  $blocked = [ordered]@{ status = 'blocked'; stage = if ($null -eq $analysis -or $analysis.complexity_admission.status -ne 'passed') { 'complexity_admission' } else { 'agent_specification' }; complexity = if ($analysis) { $analysis.complexity_admission } else { $null }; spec_analysis = $analysis; production_change = $false; external_calls = $false }
  if ($PassThru) { $blocked | ConvertTo-Json -Depth 12 } else { $blocked | Format-List }
  exit 1
}
$result = [ordered]@{ status = 'admission_analyzed'; stage = 'complexity_then_agent_spec'; complexity = $analysis.complexity_admission; spec_analysis = $analysis; production_change = $false; external_calls = $false; runner_started = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
