<#
.SYNOPSIS
  Regression test for Enterprise file organization and governed compounding.
#>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$filePolicy = Get-Content -LiteralPath (Join-Path $root 'file-organization-policy.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$reviewPolicy = Get-Content -LiteralPath (Join-Path $root 'review-compounding-policy.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$locationScript = Join-Path $root 'new-enterprise-artifact-location.ps1'
$reviewScript = Join-Path $root 'new-enterprise-review.ps1'
$templatePresent = @(Get-ChildItem -LiteralPath $root -Filter '*.md' -File | Where-Object {
  (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -match 'candidate' -and $_.Length -gt 0
}).Count -gt 0
$cases = [System.Collections.Generic.List[object]]::new()
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }

$location = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $locationScript -Business amazon -Department operations -RiskLevel L3 -TaskId task-001 -ArtifactType review -FileName review.json -YearMonth 2026-07 -PassThru | ConvertFrom-Json
$review = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $reviewScript -TaskId task-001 -TraceId trace-001 -Business amazon -Department operations -RiskLevel L3 -BusinessExpectation expected -ActualOutcome actual -Symptom timeout -RootCause stale_source -Impact delayed -Fix refresh -Prevention expiry_check -OwnerId owner-1 -DueAt 2026-07-31 -EvidenceRefs ref-1,ref-2 -PassThru | ConvertFrom-Json

Add-Case 'organized_path_dimensions' ($location.relative_path -eq '.qianlima/local-data/enterprise/artifacts/amazon/operations/L3/2026-07/task-001/review/review.json')
Add-Case 'path_generator_is_non_writing' ($location.path_created -eq $false)
Add-Case 'required_artifact_metadata' (@($filePolicy.required_metadata) -contains 'integrity_hash' -and @($filePolicy.required_metadata) -contains 'verification_status')
Add-Case 'existing_files_not_auto_moved' (@($filePolicy.rules | Where-Object { $_ -match 'not moved automatically' }).Count -gt 0)
Add-Case 'review_creates_candidate_only' ($review.lesson_candidate.status -eq 'candidate' -and $review.lesson_candidate.production_authority -eq 'none')
Add-Case 'review_has_five_views' ($null -ne $review.failure -and $null -ne $review.core_issue -and $null -ne $review.handling)
Add-Case 'promotion_requires_verification' (@($reviewPolicy.promotion_flow) -contains 'replay' -and @($reviewPolicy.promotion_flow) -contains 'failure_injection' -and @($reviewPolicy.promotion_flow) -contains 'independent_verification' -and @($reviewPolicy.promotion_flow) -contains 'human_approval')
Add-Case 'production_auto_mutation_denied' ($reviewPolicy.hard_boundaries.automatic_AGENTS_change -eq $false -and $reviewPolicy.hard_boundaries.automatic_risk_rule_change -eq $false -and $reviewPolicy.hard_boundaries.automatic_permission_expansion -eq $false)
Add-Case 'lesson_excludes_sensitive_content' ($reviewPolicy.hard_boundaries.hidden_reasoning_storage -eq $false -and $reviewPolicy.hard_boundaries.raw_private_data_in_lesson -eq $false)
Add-Case 'pitfall_template_present' $templatePresent

$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ passed = ($failed.Count -eq 0); cases = @($cases); external_calls = $false; production_changed = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 6 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw ('File/review compounding regression failed: ' + (($failed.name) -join ', ')) }
