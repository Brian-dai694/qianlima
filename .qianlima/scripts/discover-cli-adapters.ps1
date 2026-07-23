<#!
.SYNOPSIS
  Discover local CLI candidates without starting an Agent session.
.DESCRIPTION
  Default mode only resolves executables. -ProbeHelp explicitly runs a bounded
  --help probe and records a short, redacted result; it never upgrades a CLI
  from discover-only to executable.
#>
param(
  [switch]$ProbeHelp,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$candidates = @(
  [ordered]@{ id = 'mimo_cli_worker'; command = 'mimo' },
  [ordered]@{ id = 'kimi_cli_worker'; command = 'kimi' },
  [ordered]@{ id = 'gemini_cli_worker'; command = 'gemini' },
  [ordered]@{ id = 'aider_worker'; command = 'aider' },
  [ordered]@{ id = 'opencode_worker'; command = 'opencode' },
  [ordered]@{ id = 'goose_worker'; command = 'goose' }
)
$results = foreach ($candidate in $candidates) {
  $commandInfo = @(Get-Command $candidate.command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
  $item = [ordered]@{ id = $candidate.id; command = $candidate.command; installed = ($commandInfo.Count -gt 0); path = $null; version_probe = $null; help_probe = $null; dispatch = 'discover_only' }
  if ($commandInfo.Count -gt 0) {
    $item.path = $commandInfo[0].Source
    if ($ProbeHelp) {
      $helpOutput = @(& $commandInfo[0].Source --help 2>&1 | Select-Object -First 40)
      $item.help_probe = (($helpOutput -join "`n") -replace '(?i)(api[_-]?key|token|password|secret)\s*[:=]\s*\S+', '$1=<redacted>')
    }
    $versionOutput = @(& $commandInfo[0].Source --version 2>&1 | Select-Object -First 5)
    $item.version_probe = ($versionOutput -join "`n")
  }
  [PSCustomObject]$item
}
$report = [PSCustomObject]@{ generated_at = (Get-Date).ToUniversalTime().ToString('o'); results = @($results) }
if ($PassThru) { $report | ConvertTo-Json -Depth 8 } else { $results | Format-Table -AutoSize }
