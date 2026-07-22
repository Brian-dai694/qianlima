<##
.SYNOPSIS
  Restores an earlier personal preference as a new immutable version.
##>
param(
  [Parameter(Mandatory = $true)] [ValidateSet('communication_language', 'response_style', 'response_length', 'presentation_order', 'speed_preference', 'quality_preference', 'collaboration_style', 'architecture_preference', 'shadow_second_opinion', 'tool_preference', 'workflow_order', 'workflow_default_parameters')] [string]$PreferenceKey,
  [Parameter(Mandatory = $true)] [ValidateRange(1, 10000)] [int]$Version,
  [Parameter(Mandatory = $true)] [switch]$UserConfirmed,
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
if (-not $UserConfirmed) { throw 'User confirmation is required before restoring a preference.' }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$storePath = Join-Path $projectRoot '.qianlima\working\personal-preferences.json'
if (-not (Test-Path -LiteralPath $storePath -PathType Leaf)) { throw 'Preference history does not exist.' }
$store = Get-Content -LiteralPath $storePath -Raw -Encoding UTF8 | ConvertFrom-Json
$found = @($store.preferences | Where-Object { $_.key -eq $PreferenceKey })
function Get-Version($Entry) { if ($null -ne $Entry.version) { return [int]$Entry.version }; return 1 }
$target = @($found | Where-Object { (Get-Version $_) -eq $Version -and $_.state -ne 'revoked' } | Select-Object -First 1)
if ($target.Count -eq 0 -or [string]::IsNullOrWhiteSpace([string]$target[0].value)) { throw 'Requested preference version is not restorable.' }
$current = @($found | Where-Object { $_.state -eq 'validated' } | Select-Object -First 1)
$versions = @($found | ForEach-Object { if ($null -ne $_.version) { [int]$_.version } else { 1 } })
$nextVersion = (($versions | Measure-Object -Maximum).Maximum + 1)
$now = (Get-Date).ToUniversalTime()
$updated = @($store.preferences | ForEach-Object {
  if ($_.key -eq $PreferenceKey -and $_.state -eq 'validated') {
    $copy = [ordered]@{}
    foreach ($property in $_.PSObject.Properties) { $copy[$property.Name] = $property.Value }
    $copy['state'] = 'superseded'; $copy['superseded_at'] = $now.ToString('o'); $copy['superseded_by'] = "pref-$PreferenceKey-v$nextVersion"
    [PSCustomObject]$copy
  } else { $_ }
})
$restored = [ordered]@{ preference_id="pref-$PreferenceKey-v$nextVersion"; key=$PreferenceKey; version=$nextVersion; value=$target[0].value; state='validated'; domain=$target[0].domain; confidence=$target[0].confidence; source='rollback'; source_candidate_id=$target[0].source_candidate_id; supersedes_preference_id=$(if ($current.Count -gt 0) { $current[0].preference_id } else { $null }); rollback_from_preference_id=$target[0].preference_id; observation_count=$target[0].observation_count; user_confirmed=$true; last_used_at=$null; updated_at=$now.ToString('o'); expires_at=$target[0].expires_at }
$newStore = [ordered]@{ schema_version=2; profile='personal'; preferences=@($updated + [PSCustomObject]$restored); updated_at=$now.ToString('o') }
[IO.File]::WriteAllText($storePath, ($newStore | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$result = [PSCustomObject]@{ status='preference_restored'; preference_key=$PreferenceKey; restored_from_version=$Version; version=$nextVersion; rollback_available=$true; permission_changed=$false; data_scope_changed=$false; confirmation_requirement_changed=$false }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
