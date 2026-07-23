<##
.SYNOPSIS
  Regression tests for Qianlima project scope, source boundary, health checks, and failure receipts.
##>
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scopeScript = Join-Path $PSScriptRoot 'new-qianlima-project-scope.ps1'
$sourceScript = Join-Path $PSScriptRoot 'new-qianlima-source-request.ps1'
$healthScript = Join-Path $PSScriptRoot 'invoke-qianlima-health-check.ps1'
$failureScript = Join-Path $PSScriptRoot 'new-qianlima-failure-receipt.ps1'
$id = 'ops-controls-' + [Guid]::NewGuid().ToString('n')
$scopeRef = ".qianlima/run-traces/project-scopes/$id.json"
$sourceRef = ".qianlima/run-traces/source-requests/$id.json"
$scopePath = Join-Path $root ($scopeRef -replace '/', '\')
$sourcePath = Join-Path $root ($sourceRef -replace '/', '\')
$healthPath = Join-Path $root ".qianlima\run-traces\health-checks\$id.json"
$failurePath = Join-Path $root ".qianlima\run-traces\failures\$id.json"
$checks = [System.Collections.Generic.List[object]]::new()
function Check([string]$Name, [bool]$Passed) { [void]$checks.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
try {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scopeScript -ScopeId $id -StoreId store-test -Marketplace US -Brand 'Test Brand' -ProductLine 'Test Line' | Out-Null
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $sourceScript -RequestId $id -TaskId $id -SourceId ads-test -ServiceId ads-service -RepositoryId ads-repository -ProjectScopeRef $scopeRef -Purpose 'Read selected ad metrics' -SelectedField spend,sales,orders -DataTimeRange 'synthetic' | Out-Null
  $scope = Get-Content -LiteralPath $scopePath -Raw -Encoding UTF8 | ConvertFrom-Json
  $source = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8 | ConvertFrom-Json
  Check 'project_scope_created' ($scope.store_id -eq 'store-test' -and $scope.marketplace -eq 'US')
  Check 'source_request_is_read_only' ($source.access_mode -eq 'read_only' -and -not $source.business_write -and @($source.selected_fields).Count -eq 3)
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $healthScript -Mode pre_l4 -WorkflowId daily_ad_report -ProjectScopePath $scopeRef -SourceRequestPath $sourceRef -MaxIndexAgeHours 100000 -OutputPath $healthPath -PassThru | Out-Null
  $health = Get-Content -LiteralPath $healthPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Check 'pre_l4_health_passed' ($health.outcome -eq 'passed' -and -not $health.network_calls)
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $failureScript -FailureId $id -RunId $id -TaskId $id -Workflow daily_ad_report -Phase verify -FailureLocation 'metrics.acos' -Category verifier -Reason 'Source freshness is missing.' -SourceRef 'synthetic:ads' -OccurrenceCount 2 -RecoveryAction 'Reload the source and verify the formula.' -SafeState retry_limited -PassThru | Out-Null
  $failure = Get-Content -LiteralPath $failurePath -Raw -Encoding UTF8 | ConvertFrom-Json
  Check 'failure_receipt_has_location_and_count' ($failure.failure_location -eq 'metrics.acos' -and $failure.occurrence_count -eq 2)
  Check 'failure_receipt_is_bounded' ($failure.retry_allowed -and -not $failure.external_calls -and -not $failure.business_write)
  $badCode = 0; $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $failureScript -FailureId ($id + '-bad') -RunId $id -TaskId $id -Workflow daily_ad_report -Phase verify -FailureLocation 'metrics' -Category needs_human -Reason 'needs confirmation' -RecoveryAction 'wait' -SafeState continue 2>$null } finally { $ErrorActionPreference = $old }; $badCode = $LASTEXITCODE
  Check 'needs_human_cannot_continue' ($badCode -ne 0)
} catch { Check 'unexpected_test_error' $false; Write-Error $_ }
finally { Remove-Item -LiteralPath $scopePath,$sourcePath,$healthPath,$failurePath -Force -ErrorAction SilentlyContinue }
$failed = @($checks | Where-Object { -not $_.passed })
$checks | ForEach-Object { Write-Host ("{0}: {1}" -f $_.name, $(if ($_.passed) { 'PASS' } else { 'FAIL' })) }
if ($failed.Count -gt 0) { exit 1 }
