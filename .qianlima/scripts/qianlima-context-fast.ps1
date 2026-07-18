param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$TaskText,

  [ValidateSet('L1', 'L2', 'L3', 'L4')]
  [string]$ContextLevel = 'L1',

  [string[]]$RelevantPath = @(),
  [ValidatePattern('^[A-Za-z0-9_-]{1,80}$')]
  [string]$SessionId = '',
  [ValidateRange(1, 120)]
  [int]$LeaseMinutes = 30,
  [switch]$InvalidateLease,
  [switch]$AutoStart,
  [string]$MemoryRequestPath = '',
  [string]$MemoryGrantPath = '',
  [string]$MemoryPath = '',
  [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$qianlimaRoot = Join-Path $projectRoot '.qianlima'
$bootPath = Join-Path $qianlimaRoot 'CODEX_BOOT.md'
$routerPath = Join-Path $qianlimaRoot 'codex-router.json'
$cachePath = Join-Path $qianlimaRoot 'startup-cache.json'
$leaseDirectory = Join-Path $qianlimaRoot 'session-leases'

function Get-ShortExcerpt([string]$Path, [int]$MaximumCharacters = 1800) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ($content.Length -le $MaximumCharacters) { return $content }
  return $content.Substring(0, $MaximumCharacters) + "`n[excerpt truncated]"
}

function Resolve-WorkspaceFile([string]$RelativePath) {
  $candidate = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $RelativePath))
  $workspacePrefix = $projectRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  if (-not $candidate.StartsWith($workspacePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "RelevantPath must stay inside the Qianlima project workspace: $RelativePath"
  }
  return $candidate
}

function Get-PowerShellExecutable() {
  if ($PSVersionTable.PSEdition -eq 'Core') {
    return 'pwsh'
  }
  return 'powershell'
}

function Test-ContainsAny([string]$Text, [string[]]$Terms) {
  foreach ($term in $Terms) {
    if (-not [string]::IsNullOrWhiteSpace($term) -and
      $Text.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
      return $true
    }
  }
  return $false
}

function Get-InlineFastStatus([string[]]$RelevantPaths) {
  $artifacts = @(
    '.qianlima\CODEX_BOOT.md',
    '.qianlima\codex-router.json',
    '.qianlima\WORKSPACE_INDEX.md'
  )
  $cache = $null
  $cacheReadable = $false
  if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
    try {
      $cache = Get-Content -LiteralPath $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json
      $cacheReadable = $true
    } catch {
      $cacheReadable = $false
    }
  }
  $cacheGeneratedAt = if ($cacheReadable -and $cache.generated_at) { [datetime]$cache.generated_at } else { [datetime]::MinValue }
  $artifactReady = @($artifacts | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $projectRoot $_) -PathType Leaf)
  }).Count -eq 0
  $freshnessSources = @(
    'AGENTS.md',
    '.qianlima\CODEX_BOOT.md',
    '.qianlima\natural-language-router.yaml',
    '.qianlima\agent-runtime-policy.yaml',
    '.qianlima\latency-policy.yaml',
    '.qianlima\session-lease-policy.yaml',
    'start-qianlima.ps1'
  ) + @($RelevantPaths)
  $staleSources = @($freshnessSources | Where-Object {
    $sourcePath = Join-Path $projectRoot $_
    (Test-Path -LiteralPath $sourcePath -PathType Leaf) -and
      (Get-Item -LiteralPath $sourcePath).LastWriteTimeUtc -gt $cacheGeneratedAt.ToUniversalTime()
  })
  $missingRelevant = @($RelevantPaths | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $projectRoot $_) -PathType Leaf)
  })
  [PSCustomObject]@{
    status = if ($cacheReadable -and $cache.schema_version -eq 2 -and $artifactReady -and $staleSources.Count -eq 0 -and $missingRelevant.Count -eq 0) { 'ready' } else { 'needs_startup' }
    cache_generated_at = if ($cacheReadable) { $cache.generated_at } else { $null }
    stale_sources = $staleSources
    missing_relevant_paths = $missingRelevant
    full_startup_required = -not ($cacheReadable -and $cache.schema_version -eq 2 -and $artifactReady -and $staleSources.Count -eq 0 -and $missingRelevant.Count -eq 0)
  }
}

$highRiskTerms = @('调价', '改价', '调竞价', '调预算', '采购', '删除', '覆盖', '递归移动', '写回', '提交', '发送外部')
$highRiskDetected = $ContextLevel -eq 'L4' -or (Test-ContainsAny $TaskText $highRiskTerms)
$normalizedRelevantPaths = @($RelevantPath | ForEach-Object { $_ -split '[,;]' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$normalizedRelevantPaths | ForEach-Object { [void](Resolve-WorkspaceFile $_) }

$fastStatus = Get-InlineFastStatus $normalizedRelevantPaths
$startupCompleted = $false
if ($AutoStart -and ($fastStatus.status -ne 'ready' -or $highRiskDetected)) {
  $startupScript = Join-Path $projectRoot 'start-qianlima.ps1'
  $startupArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $startupScript)
  if ($highRiskDetected) { $startupArgs += '-Force' }
  & (Get-PowerShellExecutable) @startupArgs | Out-Null
  $startupCompleted = $true
  $fastStatus = Get-InlineFastStatus $normalizedRelevantPaths
}
$router = if (Test-Path -LiteralPath $routerPath -PathType Leaf) {
  Get-Content -LiteralPath $routerPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
  $null
}

$candidates = @()
if ($null -ne $router) {
  foreach ($route in @($router.routes)) {
    $matchedSignals = @($route.strong_signals | Where-Object {
      -not [string]::IsNullOrWhiteSpace($_) -and
      $TaskText.IndexOf($_, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    })
    if ($matchedSignals.Count -gt 0) {
      $candidates += [PSCustomObject]@{
        route = $route
        matched_signals = $matchedSignals
        score = $matchedSignals.Count
      }
    }
  }
}

$sortedCandidates = @($candidates | Sort-Object -Property @{ Expression = 'score'; Descending = $true }, @{ Expression = { $_.route.route_id }; Descending = $false })
$selected = if ($sortedCandidates.Count -gt 0) { $sortedCandidates[0] } else { $null }
$ambiguous = $sortedCandidates.Count -gt 1 -and $sortedCandidates[0].score -eq $sortedCandidates[1].score
if ($ambiguous) { $selected = $null }

$leasePath = if ($SessionId) { Join-Path $leaseDirectory "$SessionId.json" } else { $null }
$lease = $null
if ($leasePath -and (Test-Path -LiteralPath $leasePath -PathType Leaf)) {
  try { $lease = Get-Content -LiteralPath $leasePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $lease = $null }
}

$bootVersion = if (Test-Path -LiteralPath $bootPath) { (Get-Item -LiteralPath $bootPath).LastWriteTimeUtc.Ticks } else { $null }
$routerVersion = if ($null -ne $router) { $router.generated_at } else { $null }
$leaseValid = $false
$leaseInvalidReason = $null
$contextRank = @{ L1 = 1; L2 = 2; L3 = 3; L4 = 4 }
$leaseContextSufficient = $false
if (-not $SessionId) { $leaseInvalidReason = 'no_session_id' }
elseif ($InvalidateLease) { $leaseInvalidReason = 'explicit_invalidation' }
elseif ($highRiskDetected) { $leaseInvalidReason = 'high_risk_request' }
elseif ($ambiguous) { $leaseInvalidReason = 'ambiguous_route' }
elseif ($fastStatus.status -ne 'ready') { $leaseInvalidReason = 'startup_cache_not_ready' }
elseif ($null -eq $lease) { $leaseInvalidReason = 'lease_missing' }
elseif ([datetime]$lease.expires_at -le [datetime]::UtcNow) { $leaseInvalidReason = 'lease_expired' }
elseif ($lease.startup_index_version -ne $fastStatus.cache_generated_at) { $leaseInvalidReason = 'startup_index_changed' }
elseif ($lease.boot_version -ne $bootVersion) { $leaseInvalidReason = 'boot_changed' }
elseif ($lease.router_version -ne $routerVersion) { $leaseInvalidReason = 'router_changed' }
elseif ($contextRank[$lease.approved_context_level] -lt $contextRank[$ContextLevel]) { $leaseInvalidReason = 'context_level_escalation' }
else { $leaseValid = $true; $leaseContextSufficient = $true }

$needsFullStartup = $highRiskDetected -or $fastStatus.status -ne 'ready'
$memoryRequested = $MemoryRequestPath -or $MemoryGrantPath -or $MemoryPath
if ($memoryRequested -and (-not $MemoryRequestPath -or -not $MemoryGrantPath -or -not $MemoryPath)) {
  $stopwatch.Stop()
  $blocked = [ordered]@{ status = 'blocked'; state = 'memory_request_binding'; reason = 'MemoryRequestPath, MemoryGrantPath, and MemoryPath must be supplied together.'; memory_gate_used = $false; memory = $null; external_calls = $false }
  if ($AsJson) { $blocked | ConvertTo-Json -Depth 8 } else { $blocked }
  exit 1
}
$memoryResult = $null
if ($memoryRequested) {
  $memoryScript = Join-Path $PSScriptRoot 'invoke-memory-broker.ps1'
  $memoryOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $memoryScript -RequestPath $MemoryRequestPath -GrantPath $MemoryGrantPath -MemoryPath $MemoryPath -PassThru 2>&1)
  $memoryCode = $LASTEXITCODE
  $memoryText = ($memoryOutput -join "`n")
  $memoryStart = $memoryText.IndexOf('{'); $memoryEnd = $memoryText.LastIndexOf('}')
  if ($memoryStart -ge 0 -and $memoryEnd -gt $memoryStart) { try { $memoryResult = $memoryText.Substring($memoryStart, $memoryEnd - $memoryStart + 1) | ConvertFrom-Json } catch { } }
  if ($memoryCode -ne 0 -or $null -eq $memoryResult -or $memoryResult.status -ne 'allowed') {
    $stopwatch.Stop()
    $blocked = [ordered]@{ status = 'blocked'; state = 'memory_read_gate'; memory_gate_used = $true; memory = $memoryResult; external_calls = $false }
    if ($AsJson) { $blocked | ConvertTo-Json -Depth 10 } else { $blocked }
    exit 1
  }
}

if ($selected) {
  $routeSummary = [PSCustomObject]@{
    route_id = $selected.route.route_id
    intent = $selected.route.intent
    workflow = $selected.route.workflow
    skill = $selected.route.skill
    risk = $selected.route.risk
    matched_signals = $selected.matched_signals
    confidence = [math]::Round([math]::Min(1.0, ([double]$selected.score / [double][math]::Max(1, @($selected.route.strong_signals).Count))), 2)
  }
} else {
  $routeSummary = $null
}

$sameRouteAsLease = $leaseValid -and $leaseContextSufficient -and $null -ne $routeSummary -and $lease.route_id -eq $routeSummary.route_id
$contextReused = $sameRouteAsLease -and -not $needsFullStartup
$relevantExcerpts = if ($contextReused) {
  @()
} else {
  @($normalizedRelevantPaths | Select-Object -First 3 | ForEach-Object {
    $resolvedPath = Resolve-WorkspaceFile $_
    [PSCustomObject]@{
      path = $_
      exists = Test-Path -LiteralPath $resolvedPath -PathType Leaf
      excerpt = Get-ShortExcerpt $resolvedPath 1200
    }
  })
}

$visibleUpdate = if ($highRiskDetected) {
  '已识别为 L4 高风险任务；正在完成规则与原始数据校验，执行前会请求明确确认。'
} elseif ($null -ne $routeSummary) {
  "已识别为 $($routeSummary.route_id)；正在加载最小上下文并准备初判。"
} else {
  '已收到任务；路由尚不唯一，先保持最小加载并仅补充必要信息。'
}

if (-not $needsFullStartup -and $SessionId -and $routeSummary -and -not $ambiguous -and (-not $leaseValid -or -not $sameRouteAsLease)) {
  if (-not (Test-Path -LiteralPath $leaseDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $leaseDirectory -Force | Out-Null
  }
  $newLease = [ordered]@{
    schema_version = 1
    session_id = $SessionId
    created_at = [datetime]::UtcNow.ToString('o')
    expires_at = [datetime]::UtcNow.AddMinutes($LeaseMinutes).ToString('o')
    startup_index_version = $fastStatus.cache_generated_at
    boot_version = $bootVersion
    router_version = $routerVersion
    approved_context_level = $ContextLevel
    route_id = if ($routeSummary) { $routeSummary.route_id } else { $null }
  }
  $newLease | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $leasePath -Encoding UTF8
}

$stopwatch.Stop()
$result = [PSCustomObject]@{
  status = if ($needsFullStartup) { 'needs_startup' } else { 'ready' }
  state = if ($needsFullStartup) { 'route_decided' } elseif ($ContextLevel -eq 'L1') { 'fast_result' } else { 'context_loaded' }
  visible_update = $visibleUpdate
  context_level = if ($highRiskDetected) { 'L4' } else { $ContextLevel }
  lease_valid = $leaseValid
  lease_invalid_reason = $leaseInvalidReason
  lease_reuse_allowed = $contextReused
  lease_expires_at = if ($lease) { $lease.expires_at } else { $null }
  context_reused = $contextReused
  context_reuse_mode = if ($contextReused) { 'same_route_short_pack' } elseif ($leaseValid) { 'version_valid_route_changed' } else { 'fresh_pack' }
  relevant_file_count = @($relevantExcerpts).Count
  force_startup_required = $highRiskDetected
  startup_completed = $startupCompleted
  startup_command_required = (-not $startupCompleted) -and ($fastStatus.status -ne 'ready' -or $highRiskDetected)
  needs_full_startup = $needsFullStartup
  route = $routeSummary
  candidate_routes = @($sortedCandidates | Select-Object -First 3 | ForEach-Object { $_.route.route_id })
  boot_excerpt = if ($needsFullStartup -or $contextReused) { $null } else { Get-ShortExcerpt $bootPath }
  relevant_files = $relevantExcerpts
  startup_cache_generated_at = $fastStatus.cache_generated_at
  memory_gate_used = $memoryRequested
  memory = $memoryResult
  elapsed_ms = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 1)
}

if ($AsJson) { $result | ConvertTo-Json -Depth 7 } else { $result }
