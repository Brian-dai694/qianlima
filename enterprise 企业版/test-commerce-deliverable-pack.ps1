<##
.SYNOPSIS
  Regression tests for the governed commerce deliverable pack.
##>
param([switch]$PassThru)
$ErrorActionPreference='Stop';$contract=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'commerce-deliverable-contract.json') -Raw -Encoding UTF8|ConvertFrom-Json;$creator=Join-Path $PSScriptRoot 'new-commerce-deliverable-pack.ps1';$cases=[System.Collections.Generic.List[object]]::new();function Add-Case([string]$Name,[bool]$Passed){$cases.Add([PSCustomObject]@{name=$Name;passed=$Passed})}
$pack=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $creator -TaskId task1 -TraceId trace1 -ProductId product1 -Marketplace US -OwnerId owner1 -PassThru|ConvertFrom-Json
Add-Case 'all_five_deliverables_present' (@('profitability','title','main_image','bullet_points','long_description'|Where-Object{$null-eq $pack.$_}).Count-eq 0)
Add-Case 'profitability_requires_source_and_time' (@($contract.deliverables.profitability.required_fields)-contains'source_refs'-and @($contract.deliverables.profitability.required_fields)-contains'data_as_of')
Add-Case 'five_bullets_required' ($contract.deliverables.bullet_points.item_count-eq 5)
Add-Case 'listing_assets_start_pending' ($pack.title.status-eq'pending'-and $pack.main_image.status-eq'pending'-and $pack.long_description.status-eq'pending')
Add-Case 'incomplete_pack_is_partial' ($pack.completion_status-eq'partial')
Add-Case 'creation_grants_no_external_authority' ($pack.external_upload_authorized-eq$false-and $pack.price_change_authorized-eq$false)
$failed=@($cases|Where-Object{-not $_.passed});$result=[PSCustomObject]@{passed=($failed.Count-eq 0);cases=@($cases);files_written=$false;external_calls=$false};if($PassThru){$result|ConvertTo-Json -Depth 8}else{$cases|Format-Table -AutoSize};if($failed.Count-gt 0){throw "Commerce deliverable regression failed: $($failed.name-join', ')"}
