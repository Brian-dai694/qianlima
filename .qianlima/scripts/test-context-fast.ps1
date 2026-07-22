param(
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$contextScript = Join-Path $PSScriptRoot 'qianlima-context-fast.ps1'
$startupScript = Join-Path $projectRoot 'start-qianlima.ps1'
$sessionId = "context-regression-$([guid]::NewGuid().ToString('N').Substring(0, 12))"
$chunkRoot = Join-Path $projectRoot ('.qianlima\tmp\context-chunks-' + [Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $chunkRoot -Force | Out-Null
$chunkPath = Join-Path $chunkRoot 'personal-memory-chunks.json'
[IO.File]::WriteAllText($chunkPath, (@{ schema_version=1; profile='personal'; chunks=@(@{ chunk_id='context-pref'; chunk_type='stable_preference'; summary='Give the current judgment before detail.'; state='current'; user_confirmed=$true; domains=@('global'); allow_injection=$true; observed_at=(Get-Date).ToUniversalTime().ToString('o') }) } | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

function Invoke-Context([string]$TaskText, [string]$ContextLevel = 'L2', [string[]]$RelevantPath = @(), [string]$PersonalChunkPath = '') {
  $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $contextScript,
    '-TaskText', $TaskText, '-ContextLevel', $ContextLevel, '-SessionId', $sessionId, '-AsJson')
  if ($RelevantPath.Count -gt 0) {
    $args += '-RelevantPath'
    $args += ($RelevantPath -join ';')
  }
  if ($PersonalChunkPath) { $args += '-PersonalMemoryChunkPath'; $args += $PersonalChunkPath }
  $args += '-AutoStart'
  return (& powershell @args | ConvertFrom-Json)
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $startupScript -Force | Out-Null
$first = Invoke-Context '广告日报' 'L2' @('.qianlima/workflows/daily_ad_report.yaml')
$second = Invoke-Context '广告日报' 'L2' @('.qianlima/workflows/daily_ad_report.yaml')
$withChunks = Invoke-Context '广告日报' 'L2' @('.qianlima/workflows/daily_ad_report.yaml') $chunkPath
$ambiguous = Invoke-Context '广告日报 广告消耗 关键词 排名' 'L2'
$highRisk = Invoke-Context '调预算' 'L2'

$checks = @(
  [PSCustomObject]@{ name = 'first_route_ready'; passed = $first.status -eq 'ready' -and $first.route.route_id -eq 'daily_ad_report' }
  [PSCustomObject]@{ name = 'lease_created_without_full_startup'; passed = -not $first.needs_full_startup -and -not $first.lease_valid }
  [PSCustomObject]@{ name = 'same_route_reuses_context'; passed = $second.context_reused -and $second.lease_reuse_allowed -and $second.relevant_file_count -eq 0 }
  [PSCustomObject]@{ name = 'context_fast_injects_task_relevant_chunks'; passed = $withChunks.memory_chunk_injection.status -eq 'selected' -and $withChunks.memory_chunk_injection.selected_count -eq 1 -and $withChunks.memory_chunk_injection.selected_chunks[0].chunk_id -eq 'context-pref' -and $withChunks.memory_chunk_injection.authority -eq 'none' }
  [PSCustomObject]@{ name = 'ambiguous_route_does_not_reuse_lease'; passed = $null -eq $ambiguous.route -and -not $ambiguous.lease_reuse_allowed -and $ambiguous.lease_invalid_reason -eq 'ambiguous_route' }
  [PSCustomObject]@{ name = 'high_risk_bypasses_lease'; passed = $highRisk.context_level -eq 'L4' -and $highRisk.force_startup_required -and $highRisk.startup_completed -and -not $highRisk.startup_command_required -and -not $highRisk.lease_reuse_allowed }
)

$failed = @($checks | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{
  passed = $failed.Count -eq 0
  checks = $checks
  first_elapsed_ms = $first.elapsed_ms
  second_elapsed_ms = $second.elapsed_ms
  ambiguous_elapsed_ms = $ambiguous.elapsed_ms
  high_risk_elapsed_ms = $highRisk.elapsed_ms
}

if ($PassThru) { $result | ConvertTo-Json -Depth 5 }
else {
  $checks | ForEach-Object {
    $checkStatus = if ($_.passed) { 'passed' } else { 'FAILED' }
    Write-Host ("{0}: {1}" -f $_.name, $checkStatus)
  }
  $overallStatus = if ($result.passed) { 'passed' } else { 'FAILED' }
  Write-Host "Context-fast regression: $overallStatus"
}
if (-not $result.passed) { exit 1 }
