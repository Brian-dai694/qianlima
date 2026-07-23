<#
.SYNOPSIS
  Static regression for personal and enterprise memory separation.
#>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$path = Join-Path $projectRoot '.qianlima\specifications\edition-memory-learning-boundary.json'
$spec = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = @(
  [PSCustomObject]@{ name = 'personal_preferences_remain_user_controlled'; passed = ($spec.personal_edition.memory_classes.explicit_preference.user_editable -eq $true -and $spec.personal_edition.memory_classes.explicit_preference.user_deletable -eq $true) },
  [PSCustomObject]@{ name = 'observed_habits_are_not_auto_promoted'; passed = ($spec.personal_edition.memory_classes.observed_habit.write -eq 'shadow_candidate_only' -and $spec.personal_edition.memory_classes.observed_habit.promotion -eq 'repeated_behavior_plus_user_confirmation') },
  [PSCustomObject]@{ name = 'personal_memory_cannot_expand_authority'; passed = (@($spec.personal_edition.must_not_influence | Where-Object { $_ -in @('grant_scope','tool_authority','external_access','write_permission','deletion_confirmation') }).Count -eq 5) },
  [PSCustomObject]@{ name = 'enterprise_learning_requires_independent_human_gate'; passed = (@($spec.enterprise_edition.learning_lifecycle | Where-Object { $_ -eq 'independent_verification' }).Count -eq 1 -and @($spec.enterprise_edition.learning_lifecycle | Where-Object { $_ -eq 'human_approval' }).Count -eq 1) },
  [PSCustomObject]@{ name = 'cross_edition_memory_flow_denied'; passed = ($spec.cross_edition_rules.personal_to_enterprise -eq 'deny' -and $spec.cross_edition_rules.enterprise_knowledge_becomes_personal_profile -eq $false) },
  [PSCustomObject]@{ name = 'scope_and_revocation_fail_closed'; passed = ($spec.failure_actions.scope_mismatch -eq 'deny_before_read' -and $spec.failure_actions.revoked_record -eq 'deny_before_read') }
)
$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ passed = ($failed.Count -eq 0); cases = $cases; external_calls = $false; permissions_granted = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 6 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw "Edition memory boundary regression failed: $($failed.name -join ', ')" }
