param(
  [Parameter(Mandatory = $true)] [ValidateSet('communication_language', 'response_style', 'response_length', 'presentation_order', 'speed_preference', 'quality_preference', 'collaboration_style', 'architecture_preference', 'shadow_second_opinion', 'tool_preference', 'workflow_order', 'workflow_default_parameters', 'keyword_preference', 'report_format', 'analysis_habit')] [string]$PreferenceKey,
  [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$PreferenceValue,
  [switch]$UserConfirmed,
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
if (-not $UserConfirmed) { throw 'User confirmation is required before editing a preference.' }
if ($PreferenceValue -match '(?i)(api[_-]?key|secret|password|cookie|bearer\s+[a-z0-9._-]{12,}|token\s*[:=]\s*[a-z0-9._-]{12,}|\b\d{11,}\b)') { throw 'Sensitive preference values must remain reference-only.' }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$storePath = Join-Path $projectRoot '.qianlima\working\personal-preferences.json'
if (-not (Test-Path -LiteralPath $storePath -PathType Leaf)) { throw 'Preference does not exist.' }
$store = Get-Content -LiteralPath $storePath -Raw -Encoding UTF8 | ConvertFrom-Json
$found = @($store.preferences | Where-Object { $_.key -eq $PreferenceKey })
if ($found.Count -eq 0) { throw 'Preference does not exist.' }
$now = (Get-Date).ToUniversalTime()
$current = @($found | Where-Object { $_.state -eq 'validated' } | Select-Object -First 1)
if ($current.Count -eq 0) { throw 'Only an active preference can be edited.' }
$versions = @($found | ForEach-Object { if ($null -ne $_.version) { [int]$_.version } else { 1 } })
$nextVersion = (($versions | Measure-Object -Maximum).Maximum + 1)
$updated = @($store.preferences | ForEach-Object {
  if ($_.preference_id -eq $current[0].preference_id -or ($_.key -eq $PreferenceKey -and $_.state -eq 'validated')) {
    $copy = [ordered]@{}
    foreach ($property in $_.PSObject.Properties) { $copy[$property.Name] = $property.Value }
    $copy['state'] = 'superseded'; $copy['superseded_at'] = $now.ToString('o'); $copy['superseded_by'] = "pref-$PreferenceKey-v$nextVersion"
    [PSCustomObject]$copy
  } else { $_ }
})
$preference = [ordered]@{ preference_id="pref-$PreferenceKey-v$nextVersion"; key=$PreferenceKey; version=$nextVersion; value=$PreferenceValue.Trim(); state='validated'; domain=$current[0].domain; confidence=$current[0].confidence; source='user_edit'; source_candidate_id=$current[0].source_candidate_id; supersedes_preference_id=$current[0].preference_id; observation_count=$current[0].observation_count; user_confirmed=$true; last_used_at=$current[0].last_used_at; updated_at=$now.ToString('o'); expires_at=$current[0].expires_at }
$newStore = [ordered]@{ schema_version=2; profile='personal'; preferences=@($updated + [PSCustomObject]$preference); updated_at=$now.ToString('o') }
[IO.File]::WriteAllText($storePath, ($newStore | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$result = [PSCustomObject]@{ status='preference_edited'; preference_key=$PreferenceKey; version=$nextVersion; rollback_available=$true; permission_changed=$false; data_scope_changed=$false; confirmation_requirement_changed=$false }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
