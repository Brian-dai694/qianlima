<##
.SYNOPSIS
  Regression tests for Qianlima desired-state diffs and evidence packs.
##>
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$tmp = Join-Path $root '.qianlima\tmp'
$diffScript = Join-Path $PSScriptRoot 'new-qianlima-desired-state-diff.ps1'
$packScript = Join-Path $PSScriptRoot 'new-qianlima-evidence-pack.ps1'
$id = 'state-diff-' + [Guid]::NewGuid().ToString('n')
$currentPath = Join-Path $tmp "$id-current.json"
$desiredPath = Join-Path $tmp "$id-desired.json"
$diffPath = Join-Path $root ".qianlima\run-traces\state-diffs\$id.json"
$packId = $id + '-pack'
$packPath = Join-Path $root ".qianlima\run-traces\evidence-packs\$packId.json"
$utf8 = New-Object Text.UTF8Encoding($false)
$checks = [System.Collections.Generic.List[object]]::new()
function Check([string]$Name, [bool]$Passed) { [void]$checks.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
try {
  [IO.File]::WriteAllText($currentPath, (@{ acos = 0.42; daily_budget = 20; orders = 2 } | ConvertTo-Json), $utf8)
  [IO.File]::WriteAllText($desiredPath, (@{ acos = 0.30; daily_budget = 20; orders = 2 } | ConvertTo-Json), $utf8)
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $diffScript -DiffId $id -TaskId $id -Workflow daily_ad_report -CurrentStatePath $currentPath -DesiredStatePath $desiredPath -SourceRef 'synthetic:ads' -DataTimeRange 'synthetic' -FormulaRef 'daily_ad_report.acos' | Out-Null
  $diff = Get-Content -LiteralPath $diffPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Check 'diff_created' (Test-Path -LiteralPath $diffPath -PathType Leaf)
  Check 'diff_detects_acos_change' (@($diff.differences | Where-Object { $_.field -eq 'acos' }).Count -eq 1)
  Check 'diff_never_executes_business_write' (-not $diff.execution.business_write -and -not $diff.execution.external_calls)
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $packScript -EvidencePackId $packId -TaskId $id -Workflow daily_ad_report -Conclusion 'Current ACoS exceeds target; diagnose before any change.' -CurrentStateRef $diffPath -DesiredStateRef $desiredPath -DiffRef $diffPath -SourceRef 'synthetic:ads' -DataTimeRange 'synthetic' -FormulaRef 'daily_ad_report.acos' -WorkflowVersion 'v3.0' -Uncertainty 'Synthetic data only.' -PendingVerification 'Confirm source freshness.' -ReplayCommand 'test-qianlima-state-diff.ps1' -PassThru | Out-Null
  $pack = Get-Content -LiteralPath $packPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Check 'evidence_pack_created' (Test-Path -LiteralPath $packPath -PathType Leaf)
  Check 'evidence_pack_has_formula_and_sources' (@($pack.source_refs).Count -gt 0 -and @($pack.formula_refs).Count -gt 0)
  Check 'evidence_pack_has_hash' ([string]$pack.artifact_hash -match '^sha256:[0-9a-f]{64}$')
  $withoutHash = [ordered]@{}; foreach ($property in $pack.PSObject.Properties) { if ($property.Name -ne 'artifact_hash') { $withoutHash[$property.Name] = $property.Value } }
  $recomputedHex = -join ([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes(($withoutHash | ConvertTo-Json -Depth 12 -Compress))) | ForEach-Object { $_.ToString('x2') })
  $recomputed = 'sha256:' + $recomputedHex
  Check 'evidence_pack_hash_recomputes' ($pack.artifact_hash -eq $recomputed)
  Check 'evidence_pack_is_candidate' ($pack.verification_status -eq 'candidate' -and -not $pack.business_write)
  $badCode = 0; $oldPreference = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $packScript -EvidencePackId ($packId + '-bad') -TaskId $id -Workflow daily_ad_report -Conclusion 'bad' -CurrentStateRef $diffPath -DesiredStateRef $desiredPath -DiffRef $diffPath -SourceRef 'https://example.invalid' -DataTimeRange 'synthetic' -FormulaRef 'formula' -WorkflowVersion 'v3.0' -ReplayCommand 'test' 2>$null } finally { $ErrorActionPreference = $oldPreference }; $badCode = $LASTEXITCODE
  Check 'network_reference_rejected' ($badCode -ne 0)
} catch { Check 'unexpected_test_error' $false; Write-Error $_ }
finally {
  Remove-Item -LiteralPath $currentPath,$desiredPath,$diffPath,$packPath -Force -ErrorAction SilentlyContinue
}
$failed = @($checks | Where-Object { -not $_.passed })
$checks | ForEach-Object { Write-Host ("{0}: {1}" -f $_.name, $(if ($_.passed) { 'PASS' } else { 'FAIL' })) }
if ($failed.Count -gt 0) { exit 1 }
