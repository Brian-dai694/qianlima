<##
.SYNOPSIS
  Regression test for the one-call brokered context entrypoint.
  The L1 case deliberately omits memory paths to preserve the fast path.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'invoke-brokered-context.ps1'
$output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -TaskText 'Synthetic low-risk read-only context check.' -ContextLevel L1 -AutoStart -PassThru 2>&1)
$code = $LASTEXITCODE
$text = ($output -join "`n"); $start = $text.IndexOf('{'); $end = $text.LastIndexOf('}'); $result = $null
if ($start -ge 0 -and $end -gt $start) { try { $result = $text.Substring($start, $end - $start + 1) | ConvertFrom-Json } catch { } }
$passed = $code -eq 0 -and $null -ne $result -and $result.status -eq 'ready' -and $result.memory_gate_used -eq $false -and $result.external_calls -eq $false -and $result.raw_memory_recorded -eq $false
$summary = [PSCustomObject]@{ passed = $passed; cases = @([PSCustomObject]@{ name = 'l1_fast_path_without_memory_gate'; passed = $passed }); memory_gate_used = if ($null -ne $result) { $result.memory_gate_used } else { $null }; external_calls = $false; raw_memory_recorded = $false; startup_completed = if ($null -ne $result.context) { $result.context.startup_completed } else { $null } }
if ($PassThru) { $summary | ConvertTo-Json -Depth 12 } else { $summary | Format-List }; if (-not $passed) { throw 'Brokered context regression failed.' }
