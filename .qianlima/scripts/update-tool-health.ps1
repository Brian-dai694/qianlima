<#
.SYNOPSIS
Records a tool invocation outcome and recomputes its health tier.
.DESCRIPTION
Updates working/tool-health.json for the named tool, accumulating attempts,
successes, timeouts, duration, and completeness. Recalculates success rate and
averages, then assigns a health tier: primary, fallback, or avoid based on
success rate, completeness, and timeout counts. Creates the file if missing.
.PARAMETER ToolName
File-safe name of the tool whose health record is updated.
.PARAMETER DurationMs
Duration of this invocation in milliseconds (0 to 3600000).
.PARAMETER Outcome
Result of this call: success or failure (default success).
.PARAMETER TimedOut
Marks this invocation as a timeout, raising the timeout count.
.EXAMPLE
.\update-tool-health.ps1 -ToolName search_amazon -DurationMs 1200 -Outcome success
#>
param(
  [Parameter(Mandatory)]
  [string]$ToolName,
  [ValidateRange(0, 3600000)]
  [int]$DurationMs,
  [ValidateSet('success', 'failure')]
  [string]$Outcome = 'success',
  [ValidateRange(0, 100)]
  [double]$CompletenessPct = 100,
  [switch]$TimedOut,
  [string]$Root = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
if ($ToolName -match '[\\/:*?"<>|]' -or $ToolName.Length -gt 80) {
  throw 'ToolName must be a short file-safe identifier.'
}

$workingPath = Join-Path $Root 'working'
if (-not (Test-Path -LiteralPath $workingPath -PathType Container)) {
  New-Item -ItemType Directory -Path $workingPath -Force | Out-Null
}
$healthPath = Join-Path $workingPath 'tool-health.json'

if (Test-Path -LiteralPath $healthPath -PathType Leaf) {
  $state = Get-Content -LiteralPath $healthPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
  $state = [PSCustomObject]@{ schema_version = 1; updated_at = ''; tools = @() }
}

$tools = @($state.tools)
$entry = @($tools | Where-Object { $_.tool_name -eq $ToolName } | Select-Object -First 1)
if ($entry.Count -eq 0) {
  $entry = [PSCustomObject]@{
    tool_name = $ToolName
    attempts = 0
    success_count = 0
    timeout_count = 0
    total_duration_ms = 0
    total_completeness_pct = 0.0
    success_rate = 0.0
    average_duration_ms = 0.0
    completeness_pct = 0.0
    health_tier = 'fallback'
  }
  $tools += $entry
} else {
  $entry = $entry[0]
}

$entry.attempts = [int]$entry.attempts + 1
if ($Outcome -eq 'success') { $entry.success_count = [int]$entry.success_count + 1 }
if ($TimedOut) { $entry.timeout_count = [int]$entry.timeout_count + 1 }
$entry.total_duration_ms = [int64]$entry.total_duration_ms + $DurationMs
$entry.total_completeness_pct = [double]$entry.total_completeness_pct + $CompletenessPct
$entry.success_rate = [math]::Round(($entry.success_count / $entry.attempts), 4)
$entry.average_duration_ms = [math]::Round(($entry.total_duration_ms / $entry.attempts), 2)
$entry.completeness_pct = [math]::Round(($entry.total_completeness_pct / $entry.attempts), 2)

if ($entry.success_rate -ge 0.90 -and $entry.completeness_pct -ge 80 -and $entry.timeout_count -eq 0) {
  $entry.health_tier = 'primary'
} elseif ($entry.success_rate -lt 0.60 -or $entry.completeness_pct -lt 50 -or $entry.timeout_count -ge 2) {
  $entry.health_tier = 'avoid'
} else {
  $entry.health_tier = 'fallback'
}

$state.tools = [object[]]$tools
$state.updated_at = (Get-Date).ToString('o')
$state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $healthPath -Encoding UTF8

if ($Json) { $entry | ConvertTo-Json -Depth 5 } else { $entry | Format-List }
