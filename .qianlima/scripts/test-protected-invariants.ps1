$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'check-protected-invariants.ps1'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Invoke-Gate([string]$Path, [string]$Operation, [switch]$Confirmed) {
  $args = @('-TargetPath', $Path, '-Operation', $Operation, '-AsJson', '-NoExit')
  if ($Confirmed) { $args += '-Confirmed' }
  return (& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @args | ConvertFrom-Json)
}

$checks = @(
  [PSCustomObject]@{ name = 'risk_rules_blocked'; passed = (Invoke-Gate '.qianlima/risk-rules.yaml' 'modify').classification -eq 'deny' }
  [PSCustomObject]@{ name = 'safety_script_requires_confirmation'; passed = (Invoke-Gate '.qianlima/scripts/check-command-safety.ps1' 'modify').classification -eq 'confirmation_required' }
  [PSCustomObject]@{ name = 'confirmed_safety_script_allowed'; passed = (Invoke-Gate '.qianlima/scripts/check-command-safety.ps1' 'modify' -Confirmed).classification -eq 'allow' }
  [PSCustomObject]@{ name = 'ordinary_file_allowed'; passed = (Invoke-Gate '.qianlima/templates/knowledge-digest_template.md' 'modify').classification -eq 'allow' }
  [PSCustomObject]@{ name = 'outside_workspace_blocked'; passed = (Invoke-Gate '..\outside-file.txt' 'modify').classification -eq 'deny' }
)
$failed = @($checks | Where-Object { -not $_.passed })
$checks | ForEach-Object { Write-Host ("{0}: {1}" -f $_.name, $(if ($_.passed) { 'passed' } else { 'FAILED' })) }
Write-Host ("Protected invariant regression: {0}" -f $(if ($failed.Count -eq 0) { 'passed' } else { 'FAILED' }))
if ($failed.Count -gt 0) { exit 1 }
