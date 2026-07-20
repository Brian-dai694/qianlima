<##
.SYNOPSIS
  Regression tests for the one-click personal experience clear operation.
##>
param([switch]$PassThru)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$testRoot = Join-Path $projectRoot ('.qianlima\tmp\personal-clear-' + [Guid]::NewGuid().ToString('n'))
$candidateRoot = Join-Path $testRoot 'candidates'
New-Item -ItemType Directory -Path $candidateRoot -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $testRoot 'personal-preferences.json'), (@{ schema_version=2; profile='personal'; preferences=@(@{ key='response_style'; value='private'; state='validated' }) } | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $testRoot 'personal-memory-chunks.json'), (@{ schema_version=1; profile='personal'; chunks=@(@{ chunk_id='private'; summary='private'; chunk_type='local_experience' }) } | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $candidateRoot 'candidate.json'), (@{ type='personal_preference_candidate'; candidate_id='candidate-1'; correction='private correction'; status='candidate' } | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$clear = Join-Path $PSScriptRoot 'clear-personal-experience.ps1'
$oldPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  $withoutConfirmation = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $clear -StorageRoot $testRoot -PassThru 2>&1)
  $withoutConfirmationBlocked = $LASTEXITCODE -ne 0
} finally { $ErrorActionPreference = $oldPreference }
$output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $clear -StorageRoot $testRoot -UserConfirmed -PassThru 2>&1)
if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
$result = ($output -join "`n") | ConvertFrom-Json
$preferences = Get-Content -LiteralPath (Join-Path $testRoot 'personal-preferences.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$chunks = Get-Content -LiteralPath (Join-Path $testRoot 'personal-memory-chunks.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$candidate = Get-Content -LiteralPath (Join-Path $candidateRoot 'candidate.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = @(
  [PSCustomObject]@{ name='requires_explicit_confirmation'; passed=$withoutConfirmationBlocked },
  [PSCustomObject]@{ name='clears_preference_store'; passed=($result.status -eq 'personal_experience_cleared' -and @($preferences.preferences).Count -eq 0 -and $preferences.content_cleared -eq $true) },
  [PSCustomObject]@{ name='clears_memory_chunks'; passed=(@($chunks.chunks).Count -eq 0 -and $chunks.content_cleared -eq $true) },
  [PSCustomObject]@{ name='redacts_candidate_content'; passed=($candidate.status -eq 'revoked' -and $null -eq $candidate.correction -and $candidate.content_cleared -eq $true) },
  [PSCustomObject]@{ name='does_not_change_authority'; passed=($result.permissions_changed -eq $false -and $result.data_scope_changed -eq $false -and $result.grants_changed -eq $false -and $result.external_calls -eq $false) }
)
$failed = @($cases | Where-Object { -not $_.passed })
$summary = [PSCustomObject]@{ passed=($failed.Count -eq 0); cases=$cases; external_calls=$false; permissions_changed=$false; grants_changed=$false }
if ($PassThru) { $summary | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw ('Personal clear regression failed: ' + (($failed | ForEach-Object { $_.name }) -join ', ')) }
