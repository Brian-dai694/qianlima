param(
  [Parameter(Mandatory = $true)] [ValidateSet('communication_language', 'response_style', 'response_length', 'presentation_order', 'speed_preference', 'quality_preference', 'collaboration_style', 'architecture_preference', 'shadow_second_opinion', 'tool_preference', 'workflow_order', 'workflow_default_parameters', 'keyword_preference', 'report_format', 'analysis_habit')] [string]$PreferenceKey,
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$storePath = Join-Path $projectRoot '.qianlima\working\personal-preferences.json'
$store = if (Test-Path -LiteralPath $storePath -PathType Leaf) { Get-Content -LiteralPath $storePath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [PSCustomObject]@{ schema_version = 1; profile = 'personal'; preferences = @() } }
$found = @($store.preferences | Where-Object { $_.key -eq $PreferenceKey })
$current = @($found | Where-Object { $_.state -in @('validated', 'disabled') } | Select-Object -First 1)
if ($current.Count -eq 0) { throw 'Active preference does not exist.' }
$now = (Get-Date).ToUniversalTime()
$versions = @($found | ForEach-Object { if ($null -ne $_.version) { [int]$_.version } else { 1 } })
$nextVersion = (($versions | Measure-Object -Maximum).Maximum + 1)
$updated = @($store.preferences | ForEach-Object {
  if ($_.key -eq $PreferenceKey) {
    $copy = [ordered]@{}
    foreach ($property in $_.PSObject.Properties) { $copy[$property.Name] = $property.Value }
    $copy['value'] = $null
    if ($_.preference_id -eq $current[0].preference_id -or $_.state -eq 'validated') { $copy['state'] = 'superseded'; $copy['superseded_at'] = $now.ToString('o'); $copy['superseded_by'] = "pref-$PreferenceKey-v$nextVersion" }
    [PSCustomObject]$copy
  } else { $_ }
})
$revoked = [ordered]@{ preference_id="pref-$PreferenceKey-v$nextVersion"; key=$PreferenceKey; version=$nextVersion; value=$null; state='revoked'; domain=$current[0].domain; confidence=$current[0].confidence; source='user_remove'; source_candidate_id=$current[0].source_candidate_id; supersedes_preference_id=$current[0].preference_id; observation_count=$current[0].observation_count; user_confirmed=$current[0].user_confirmed; last_used_at=$null; updated_at=$now.ToString('o'); expires_at=$current[0].expires_at; revoked_at=$now.ToString('o'); content_cleared=$true }
$newStore = [ordered]@{ schema_version=2; profile='personal'; preferences=@($updated + [PSCustomObject]$revoked); updated_at=$now.ToString('o') }
[IO.File]::WriteAllText($storePath, ($newStore | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$result = [PSCustomObject]@{ status = 'preference_removed'; preference_key = $PreferenceKey; version=$nextVersion; rollback_available=$true; active_preference_changed = $true; remaining_count = @($newStore.preferences | Where-Object { $_.state -eq 'validated' }).Count }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
