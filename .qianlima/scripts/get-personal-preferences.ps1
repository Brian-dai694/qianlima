param([switch]$PassThru)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$storePath = Join-Path $projectRoot '.qianlima\working\personal-preferences.json'
$store = if (Test-Path -LiteralPath $storePath -PathType Leaf) { Get-Content -LiteralPath $storePath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [PSCustomObject]@{ schema_version = 1; profile = 'personal'; preferences = @() } }
$safe = [PSCustomObject]@{ status = 'ok'; profile = 'personal'; preferences = @($store.preferences | ForEach-Object { [PSCustomObject]@{ key = $_.key; value = $_.value; state = $_.state; source = $_.source; observation_count = $_.observation_count; user_confirmed = $_.user_confirmed; updated_at = $_.updated_at } }); sensitive_values_returned = $false }
if ($PassThru) { $safe | ConvertTo-Json -Depth 8 } else { $safe | Format-List }
