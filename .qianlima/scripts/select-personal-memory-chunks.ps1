<##
.SYNOPSIS
  Selects a small, task-relevant personal memory pack.
.DESCRIPTION
  This selector only reads the personal chunk store. It never grants tools,
  changes permissions, promotes temporary context, or returns full records.
##>
param(
  [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$TaskText,
  [string]$TaskId = '',
  [ValidateSet('auto', 'chat', 'learning', 'read_only_business', 'high_risk')] [string]$TaskClass = 'auto',
  [ValidateSet('auto', 'global', 'general', 'learning', 'commerce', 'documents', 'planning')] [string]$TaskDomain = 'auto',
  [ValidateRange(1, 8)] [int]$MaxChunks = 8,
  [string]$ChunkPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$defaultPath = Join-Path $projectRoot '.qianlima\working\personal-memory-chunks.json'
if ([string]::IsNullOrWhiteSpace($ChunkPath)) { $ChunkPath = $defaultPath }
$chunkCandidate = if ([IO.Path]::IsPathRooted($ChunkPath)) { $ChunkPath } else { Join-Path $projectRoot $ChunkPath }
$chunkFullPath = [IO.Path]::GetFullPath($chunkCandidate)
$workingRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\working')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$tmpRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\tmp')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (-not $chunkFullPath.StartsWith($workingRoot, [StringComparison]::OrdinalIgnoreCase) -and -not $chunkFullPath.StartsWith($tmpRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Personal chunk store must be inside the governed personal working or test scope.' }

function HasAny([string]$Text, [object[]]$Terms) {
  foreach ($term in @($Terms)) { if (-not [string]::IsNullOrWhiteSpace([string]$term) -and $Text.IndexOf([string]$term, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true } }
  return $false
}
function AsList($Value) { if ($null -eq $Value) { return @() }; return @($Value) }
function ResolveMemoryTier($Chunk, [string]$Type, [double]$AgeDays) {
  if (-not [string]::IsNullOrWhiteSpace([string]$Chunk.memory_tier)) { return [string]$Chunk.memory_tier }
  if ($Type -in @('current_task_state', 'temporary_context')) { return 'hot' }
  if ([double]$AgeDays -le 7 -or [int]$Chunk.access_count -ge 5) { return 'hot' }
  if ($Type -in @('stable_preference', 'task_habit') -or [double]$AgeDays -le 30) { return 'warm' }
  return 'cold'
}
function GetAgeDays($Chunk, [datetime]$Now) {
  if ([string]::IsNullOrWhiteSpace([string]$Chunk.observed_at)) { return 9999.0 }
  try { return [Math]::Max(0.0, ($Now - [DateTime]::Parse([string]$Chunk.observed_at).ToUniversalTime()).TotalDays) } catch { return 9999.0 }
}

$normalizedText = $TaskText.Trim()
if ($TaskClass -eq 'auto') {
  if (HasAny $normalizedText @('delete', 'overwrite', 'write_back', 'change_price', 'change_bid', 'change_budget', 'purchase_order', 'send', 'publish')) { $TaskClass = 'high_risk' }
  elseif (HasAny $normalizedText @('learn', 'study', 'explain')) { $TaskClass = 'learning' }
  elseif (HasAny $normalizedText @('ASIN', 'Amazon', 'FBA', 'ACoS', 'ads', 'Listing')) { $TaskClass = 'read_only_business' }
  else { $TaskClass = 'chat' }
}
if ($TaskDomain -eq 'auto') {
  if (HasAny $normalizedText @('learn', 'study', 'explain')) { $TaskDomain = 'learning' }
  elseif (HasAny $normalizedText @('ASIN', 'Amazon', 'FBA', 'ACoS', 'ads', 'Listing')) { $TaskDomain = 'commerce' }
  elseif (HasAny $normalizedText @('document', 'PDF', 'Word', 'Excel')) { $TaskDomain = 'documents' }
  else { $TaskDomain = 'general' }
}

$store = if (Test-Path -LiteralPath $chunkFullPath -PathType Leaf) { Get-Content -LiteralPath $chunkFullPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [PSCustomObject]@{ chunks = @() } }
$chunks = if ($null -ne $store.chunks) { @($store.chunks) } else { @($store) }
$now = [DateTime]::UtcNow
$selected = [System.Collections.Generic.List[object]]::new()
foreach ($chunk in $chunks) {
  if ($null -eq $chunk -or [string]$chunk.chunk_type -notin @('stable_preference', 'task_habit', 'current_task_state', 'local_experience', 'temporary_context')) { continue }
  if ([string]::IsNullOrWhiteSpace([string]$chunk.chunk_id) -or [string]::IsNullOrWhiteSpace([string]$chunk.summary)) { continue }
  if ([string]$chunk.state -in @('revoked', 'superseded', 'disputed', 'expired')) { continue }
  if ($chunk.classification -eq 'sensitive' -or $chunk.allow_injection -eq $false) { continue }
  if ($chunk.expires_at) { try { if ([DateTime]::Parse([string]$chunk.expires_at).ToUniversalTime() -le $now) { continue } } catch { continue } }

  $type = [string]$chunk.chunk_type
  $score = 0
  $reason = ''
  $matchesTask = HasAny $normalizedText (AsList $chunk.keywords)
  $matchesDomain = @((AsList $chunk.task_domains) | ForEach-Object { [string]$_ }) -contains $TaskDomain
  $matchesClass = @((AsList $chunk.task_classes) | ForEach-Object { [string]$_ }) -contains $TaskClass
  $taskBonus = if ($matchesTask) { 20 } else { 0 }
  $domainBonus = if ($matchesDomain) { 10 } else { 0 }
  $ageDays = GetAgeDays $chunk $now
  $tier = ResolveMemoryTier $chunk $type $ageDays
  $tierBonus = switch ($tier) { 'hot' { 15 } 'warm' { 8 } default { 0 } }
  $recencyBonus = if ($ageDays -le 7) { 12 } elseif ($ageDays -le 30) { 6 } else { 0 }
  $frequencyBonus = [Math]::Min(10, [Math]::Max(0, [int]$chunk.access_count))
  $include = $true
  switch ($type) {
    'stable_preference' {
      if ($chunk.user_confirmed -ne $true -or [string]$chunk.state -notin @('current', 'validated')) { $include = $false }
      if ($include -and @($chunk.domains) -and @($chunk.domains | ForEach-Object { [string]$_ }) -notcontains $TaskDomain -and @($chunk.domains | ForEach-Object { [string]$_ }) -notcontains 'global') { $include = $false }
      if ($include) { $score = 80 + $domainBonus; $reason = 'confirmed_stable_preference' }
    }
    'task_habit' {
      if ($chunk.user_confirmed -ne $true -or ([string]$chunk.state -notin @('current', 'validated')) -or (-not $matchesTask -and -not $matchesDomain -and -not $matchesClass)) { $include = $false }
      if ($include) { $score = 70 + $taskBonus + $domainBonus; $reason = 'task_habit_match' }
    }
    'current_task_state' {
      if ([string]::IsNullOrWhiteSpace($TaskId) -or [string]$chunk.task_id -ne $TaskId -or [string]$chunk.state -notin @('current', 'transitional')) { $include = $false }
      if ($include) { $score = 100; $reason = 'current_task_match' }
    }
    'local_experience' {
      if ([string]::IsNullOrWhiteSpace([string]$chunk.source_ref) -or $chunk.reproducible -ne $true -or (-not $matchesTask -and -not $matchesDomain)) { $include = $false }
      if ($include) { $score = 60 + $taskBonus + $domainBonus; $reason = 'reproducible_experience_match' }
    }
    'temporary_context' {
      if ([string]::IsNullOrWhiteSpace($TaskId) -or [string]$chunk.task_id -ne $TaskId -or -not $chunk.expires_at) { $include = $false }
      if ($include) { $score = 90; $reason = 'task_bound_temporary_context' }
    }
  }
  if ($include) {
    $score += $tierBonus + $recencyBonus + $frequencyBonus
    $selected.Add([PSCustomObject]@{ chunk = $chunk; score = $score; reason = $reason; tier = $tier; age_days = [Math]::Round($ageDays, 2); access_count = [int]$chunk.access_count })
  }
}
$selected = @($selected | Sort-Object -Property @{Expression = 'score'; Descending = $true}, @{Expression = {$_.chunk.observed_at}; Descending = $true} | Select-Object -First $MaxChunks)
$pack = [ordered]@{
  schema_version = 1
  status = 'selected'
  task_class = $TaskClass
  task_domain = $TaskDomain
  task_id = $(if ($TaskId) { $TaskId } else { $null })
  max_chunks = $MaxChunks
  selected_count = $selected.Count
  injection_mode = 'minimal_summary_and_provenance'
  authority = 'none'
  permissions_changed = $false
  data_scope_changed = $false
  confirmation_requirement_changed = $false
  temporary_context_auto_promoted = $false
  selected_chunks = @($selected | ForEach-Object {
    [ordered]@{
      chunk_id = [string]$_.chunk.chunk_id
      chunk_type = [string]$_.chunk.chunk_type
      summary = [string]$_.chunk.summary
      source_ref = [string]$_.chunk.source_ref
      observed_at = [string]$_.chunk.observed_at
      expires_at = [string]$_.chunk.expires_at
      retrieval_tier = $_.tier
      access_count = $_.access_count
      age_days = $_.age_days
      retrieval_score = $_.score
      relevance_reason = $_.reason
    }
  })
  omitted_count = [Math]::Max(0, $chunks.Count - $selected.Count)
  external_calls = $false
}
if ($PassThru) { $pack | ConvertTo-Json -Depth 10 } else { $pack | Format-List }
