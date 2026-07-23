<##
.SYNOPSIS
  Regression tests for stateful memory views.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $PSScriptRoot 'validate-memory-state.ps1'
$root = Join-Path $projectRoot 'memory\cards\asin'
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
New-Item -ItemType Directory -Path $root -Force | Out-Null
function New-Entry([string]$Name, [string]$State, [string]$Classification='internal_sanitized') {
  $path=Join-Path $root "$Name-$stamp.json"
  $entry=[ordered]@{memory_id="memory-$Name-$stamp";kind='fact';state=$State;fact='Synthetic sanitized test fact';source_refs=@('synthetic-source');observed_at=(Get-Date).ToUniversalTime().ToString('o');valid_from=(Get-Date).ToUniversalTime().AddHours(-1).ToString('o');valid_to=(Get-Date).ToUniversalTime().AddHours(1).ToString('o');scope='task_selected_sources_only';confidence='high';classification=$Classification;created_by='test-harness';version=1}
  [IO.File]::WriteAllText($path,($entry|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false));return $path
}
function Invoke-Fail([string]$Path,[string]$View,[string]$Risk='L1'){$out=@();$code=0;try{$old=$ErrorActionPreference;$ErrorActionPreference='Continue';$out=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -MemoryPath $Path -View $View -RiskLevel $Risk -PassThru 2>&1);$code=$LASTEXITCODE;$ErrorActionPreference=$old}catch{$out+=$_|Out-String;$code=1};return($code -ne 0 -and ($out-join "`n")-match 'blocked|pending|requires|unusable|excluded')}
$cases=[System.Collections.Generic.List[object]]::new()
$current=New-Entry 'current' 'current';$currentResult=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -MemoryPath $current -View current -PassThru|ConvertFrom-Json;$cases.Add([PSCustomObject]@{name='current_view_usable';passed=($currentResult.status -eq 'usable' -and $currentResult.decision_ready -eq $true)})
$historical=New-Entry 'historical' 'historical';$cases.Add([PSCustomObject]@{name='historical_blocked_in_current';passed=(Invoke-Fail $historical current)})
$superseded=New-Entry 'superseded' 'superseded';$supersededResult=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -MemoryPath $superseded -View historical -PassThru|ConvertFrom-Json;$cases.Add([PSCustomObject]@{name='superseded_historical_not_decision_ready';passed=($supersededResult.status -eq 'usable' -and $supersededResult.decision_ready -eq $false)})
$transitional=New-Entry 'transitional' 'transitional';$cases.Add([PSCustomObject]@{name='transitional_pending';passed=(Invoke-Fail $transitional historical)})
$disputed=New-Entry 'disputed' 'disputed';$cases.Add([PSCustomObject]@{name='disputed_pending';passed=(Invoke-Fail $disputed historical)})
$revoked=New-Entry 'revoked' 'revoked';$cases.Add([PSCustomObject]@{name='revoked_unusable';passed=(Invoke-Fail $revoked audit)})
$l4=New-Entry 'l4' 'current';$cases.Add([PSCustomObject]@{name='l4_requires_reload';passed=(Invoke-Fail $l4 current L4)})
$failed=@($cases|Where-Object{-not $_.passed});$result=[PSCustomObject]@{passed=($failed.Count -eq 0);cases=@($cases);raw_memory_recorded=$false;external_calls=$false};if($PassThru){$result|ConvertTo-Json -Depth 10}else{$cases|Format-Table -AutoSize};if($failed.Count -gt 0){throw "Memory state regression failed: $($failed.name -join ', ')"}
