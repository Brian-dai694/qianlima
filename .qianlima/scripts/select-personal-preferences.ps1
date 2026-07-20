<##
.SYNOPSIS
  Selects a sparse, task-scoped preference pack for Codex context injection.
.DESCRIPTION
  Returns only confirmed, current, unexpired preferences that match the task
  class/domain. Preferences never grant tools, data access, network, or writes.
##>
param(
  [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$TaskText,
  [ValidateSet('auto', 'chat', 'learning', 'read_only_business', 'high_risk')] [string]$TaskClass = 'auto',
  [ValidateSet('auto', 'global', 'general', 'learning', 'commerce', 'documents', 'planning')] [string]$TaskDomain = 'auto',
  [ValidateRange(3, 8)] [int]$TopK = 5,
  [string]$PreferencePath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$defaultPath = Join-Path $projectRoot '.qianlima\working\personal-preferences.json'
if ([string]::IsNullOrWhiteSpace($PreferencePath)) { $PreferencePath = $defaultPath }

function HasAny([string]$Text, [string[]]$Terms) {
  foreach ($term in $Terms) { if ($Text.IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true } }
  return $false
}

$normalizedText = $TaskText.Trim()
if ($TaskClass -eq 'auto') {
  if (HasAny $normalizedText @('delete', 'overwrite', 'write_back', 'change_price', 'change_bid', 'change_budget', 'purchase_order', 'send', 'publish')) { $TaskClass = 'high_risk' }
  elseif (HasAny $normalizedText @('learn', 'study', 'explain', '教程', '学习', '解释')) { $TaskClass = 'learning' }
  elseif (HasAny $normalizedText @('ASIN', 'Amazon', 'FBA', 'ACoS', 'ads', '广告', '选品', '利润', '库存', 'Listing')) { $TaskClass = 'read_only_business' }
  else { $TaskClass = 'chat' }
}
if ($TaskDomain -eq 'auto') {
  if (HasAny $normalizedText @('learn', 'study', 'explain', '教程', '学习', '解释')) { $TaskDomain = 'learning' }
  elseif (HasAny $normalizedText @('ASIN', 'Amazon', 'FBA', 'ACoS', 'ads', '广告', '选品', '利润', '库存', 'Listing')) { $TaskDomain = 'commerce' }
  elseif (HasAny $normalizedText @('document', 'PDF', 'Word', 'Excel', '文档', '资料')) { $TaskDomain = 'documents' }
  else { $TaskDomain = 'general' }
}

$store = if (Test-Path -LiteralPath $PreferencePath -PathType Leaf) { Get-Content -LiteralPath $PreferencePath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [PSCustomObject]@{ preferences = @() } }
$now = [DateTime]::UtcNow
$selected = @()
foreach ($preference in @($store.preferences)) {
  if ($preference.state -ne 'validated' -or $preference.user_confirmed -ne $true) { continue }
  if ($preference.expires_at -and ([DateTime]$preference.expires_at -le $now)) { continue }
  if ($preference.domain -notin @('global', $TaskDomain)) { continue }
  $score = 0
  if ($preference.domain -eq $TaskDomain) { $score += 40 } else { $score += 20 }
  if ($preference.confidence -eq 'high') { $score += 20 }
  $score += [Math]::Min(20, [int]$preference.observation_count)
  if ($preference.last_used_at) { $score += 5 }
  $selected += [PSCustomObject]@{ preference = $preference; score = $score }
}
$selected = @($selected | Sort-Object -Property @{Expression='score';Descending=$true}, @{Expression={$_.preference.updated_at};Descending=$true} | Select-Object -First $TopK)
$pack = [ordered]@{
  schema_version = 1
  status = 'selected'
  task_class = $TaskClass
  task_domain = $TaskDomain
  top_k = $TopK
  selected_count = $selected.Count
  injection_mode = 'minimal_context_only'
  authority = 'none'
  permissions_changed = $false
  data_scope_changed = $false
  confirmation_requirement_changed = $false
  selected_preferences = @($selected | ForEach-Object { [ordered]@{ key = $_.preference.key; value = $_.preference.value; domain = $_.preference.domain; confidence = $_.preference.confidence; reason = if ($_.preference.domain -eq $TaskDomain) { 'task_domain_match' } else { 'global_preference' } } })
  omitted_count = [Math]::Max(0, @($store.preferences).Count - $selected.Count)
  external_calls = $false
}
if ($PassThru) { $pack | ConvertTo-Json -Depth 10 } else { $pack | Format-List }
