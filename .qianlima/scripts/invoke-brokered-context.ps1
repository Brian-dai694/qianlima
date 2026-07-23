<##
.SYNOPSIS
  One-call Overlay entry for fast context plus optional governed memory.
.DESCRIPTION
  Runs the existing fast context loader once. Memory validation and retrieval
  occur only when all three memory paths are explicitly supplied, preserving
  the zero-extra-work L0/L1 path.
##>
param(
  [Parameter(Mandatory = $true)] [string]$TaskText,
  [ValidateSet('L1', 'L2', 'L3', 'L4')] [string]$ContextLevel = 'L1',
  [string[]]$RelevantPath = @(),
  [ValidatePattern('^[A-Za-z0-9_-]{1,80}$')] [string]$SessionId = '',
  [ValidateRange(1, 120)] [int]$LeaseMinutes = 30,
  [switch]$InvalidateLease,
  [switch]$AutoStart,
  [string]$MemoryRequestPath = '',
  [string]$MemoryGrantPath = '',
  [string]$MemoryPath = '',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$contextScript = Join-Path $PSScriptRoot 'qianlima-context-fast.ps1'
function Parse-JsonResult([object[]]$Output) {
  $text = ($Output -join "`n"); $start = $text.IndexOf('{'); $end = $text.LastIndexOf('}')
  if ($start -ge 0 -and $end -gt $start) { try { return ($text.Substring($start, $end - $start + 1) | ConvertFrom-Json) } catch { } }
  return $null
}
$contextArgs = @('-TaskText', $TaskText, '-ContextLevel', $ContextLevel, '-AsJson')
foreach ($path in @($RelevantPath)) { $contextArgs += @('-RelevantPath', $path) }
if ($SessionId) { $contextArgs += @('-SessionId', $SessionId) }
$contextArgs += @('-LeaseMinutes', $LeaseMinutes)
if ($InvalidateLease) { $contextArgs += '-InvalidateLease' }
if ($AutoStart) { $contextArgs += '-AutoStart' }
$memoryRequested = $MemoryRequestPath -or $MemoryGrantPath -or $MemoryPath
if ($memoryRequested -and (-not $MemoryRequestPath -or -not $MemoryGrantPath -or -not $MemoryPath)) {
  $blocked = [ordered]@{ status = 'blocked'; stage = 'memory_request_binding'; reason = 'MemoryRequestPath, MemoryGrantPath, and MemoryPath must be supplied together.'; context = $null; memory = $null; external_calls = $false }
  if ($PassThru) { $blocked | ConvertTo-Json -Depth 12 } else { $blocked | Format-List }
  exit 1
}
if ($memoryRequested) { $contextArgs += @('-MemoryRequestPath', $MemoryRequestPath, '-MemoryGrantPath', $MemoryGrantPath, '-MemoryPath', $MemoryPath) }
$contextOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $contextScript @contextArgs 2>&1)
$contextCode = $LASTEXITCODE
$context = Parse-JsonResult $contextOutput
if ($contextCode -ne 0 -or $null -eq $context) {
  $blocked = [ordered]@{ status = 'blocked'; stage = 'context_loader'; context = $context; memory = $null; external_calls = $false }
  if ($PassThru) { $blocked | ConvertTo-Json -Depth 12 } else { $blocked | Format-List }
  exit 1
}
$result = [ordered]@{ status = if ([string]$context.status -eq 'ready') { 'ready' } else { [string]$context.status }; state = if ($memoryRequested) { 'context_and_memory_loaded' } else { [string]$context.state }; context = $context; memory = $context.memory; memory_gate_used = ($context.memory_gate_used -eq $true); external_calls = $false; raw_memory_recorded = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 15 } else { $result | Format-List }
