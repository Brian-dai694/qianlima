<##
.SYNOPSIS
  Regression tests for the core Harness freeze boundary.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$checker = Join-Path $PSScriptRoot 'check-harness-boundary.ps1'
$cases = [System.Collections.Generic.List[object]]::new()
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
function Invoke-ExpectedFailure([scriptblock]$Action, [string]$Needle) {
  $output=@(); $exitCode=0
  try { $old=$ErrorActionPreference; $ErrorActionPreference='Continue'; $output=@(& $Action 2>&1); $exitCode=$LASTEXITCODE; $ErrorActionPreference=$old } catch { $output += $_ | Out-String; $exitCode=1 }
  return ($exitCode -ne 0 -and ($output -join "`n") -match $Needle)
}
$baseline = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -PassThru | ConvertFrom-Json
Add-Case 'current_core_baseline_unchanged' ($baseline.status -eq 'pass' -and $baseline.core_read_only -eq $true)
$overlay = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -CandidatePath '.qianlima/enterprise-governance-framework.json' -PassThru | ConvertFrom-Json
Add-Case 'overlay_candidate_allowed' ($overlay.status -eq 'pass')
Add-Case 'core_candidate_blocked' (Invoke-ExpectedFailure { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -CandidatePath 'AGENTS.md' -PassThru } 'candidate_core_protected')
Add-Case 'unapproved_candidate_blocked' (Invoke-ExpectedFailure { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -CandidatePath '.qianlima/risk-rules.yaml' -PassThru } 'candidate_core_protected')
$failed=@($cases | Where-Object { -not $_.passed })
$result=[PSCustomObject]@{ passed=($failed.Count -eq 0); cases=@($cases); core_files_changed_by_test=$false }
if($PassThru){$result|ConvertTo-Json -Depth 8}else{$cases|Format-Table -AutoSize}
if($failed.Count -gt 0){throw "Harness boundary regression failed: $($failed.name -join ', ')"}
