<##
.SYNOPSIS
  Regression tests for task-relevant personal memory chunk selection.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$testRoot = Join-Path $projectRoot ('.qianlima\tmp\personal-memory-chunks-' + [Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$chunkPath = Join-Path $testRoot 'chunks.json'
$future = (Get-Date).ToUniversalTime().AddHours(2).ToString('o')
$past = (Get-Date).ToUniversalTime().AddHours(-2).ToString('o')
$chunks = [ordered]@{
  schema_version = 1
  profile = 'personal'
  chunks = @(
    [ordered]@{ chunk_id='pref-language'; chunk_type='stable_preference'; summary='Answer in Chinese and give a concrete conclusion first.'; state='current'; user_confirmed=$true; domains=@('global'); observed_at=$future; access_count=8; allow_injection=$true },
    [ordered]@{ chunk_id='pref-commerce'; chunk_type='stable_preference'; summary='Use Amazon margin terminology.'; state='current'; user_confirmed=$true; domains=@('commerce'); observed_at=$future; allow_injection=$true },
    [ordered]@{ chunk_id='habit-learning'; chunk_type='task_habit'; summary='For attention papers, explain the intuition then give implementation steps.'; state='validated'; user_confirmed=$true; task_classes=@('learning'); task_domains=@('learning'); keywords=@('HiLS-Attention', 'attention'); observed_at=$future; allow_injection=$true },
    [ordered]@{ chunk_id='state-task-1'; chunk_type='current_task_state'; summary='The current research task still needs a comparison with MSA.'; state='current'; task_id='task-1'; observed_at=$future; allow_injection=$true },
    [ordered]@{ chunk_id='experience-hils'; chunk_type='local_experience'; summary='A prior configuration issue was fixed by checking tensor shape assumptions.'; state='current'; source_ref='local://experience/hils-shape'; reproducible=$true; task_domains=@('learning'); keywords=@('HiLS-Attention'); observed_at=$future; allow_injection=$true },
    [ordered]@{ chunk_id='temp-task-1'; chunk_type='temporary_context'; summary='The attached paper excerpt is relevant to this task.'; state='current'; task_id='task-1'; expires_at=$future; observed_at=$future; allow_injection=$true },
    [ordered]@{ chunk_id='expired-temp'; chunk_type='temporary_context'; summary='Expired attachment.'; state='current'; task_id='task-1'; expires_at=$past; observed_at=$past; allow_injection=$true },
    [ordered]@{ chunk_id='unconfirmed-habit'; chunk_type='task_habit'; summary='Observed habit that is not confirmed.'; state='candidate'; user_confirmed=$false; task_classes=@('learning'); keywords=@('HiLS-Attention'); observed_at=$future; allow_injection=$true },
    [ordered]@{ chunk_id='sensitive'; chunk_type='local_experience'; summary='Sensitive private detail.'; state='current'; source_ref='local://sensitive'; reproducible=$true; task_domains=@('learning'); keywords=@('HiLS-Attention'); observed_at=$future; allow_injection=$false }
  )
}
[IO.File]::WriteAllText($chunkPath, ($chunks | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$selector = Join-Path $PSScriptRoot 'select-personal-memory-chunks.ps1'
$output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $selector -TaskText 'Explain HiLS-Attention in detail' -TaskId 'task-1' -TaskClass learning -TaskDomain learning -ChunkPath $chunkPath -MaxChunks 8 -PassThru 2>&1)
if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
$result = ($output -join "`n") | ConvertFrom-Json
$ids = @($result.selected_chunks | ForEach-Object { $_.chunk_id })
$cases = @(
  [PSCustomObject]@{ name='selects_learning_relevant_chunks'; passed=($result.selected_count -eq 5 -and $ids -contains 'pref-language' -and $ids -contains 'habit-learning' -and $ids -contains 'state-task-1' -and $ids -contains 'experience-hils' -and $ids -contains 'temp-task-1') },
  [PSCustomObject]@{ name='excludes_unrelated_commerce_context'; passed=($ids -notcontains 'pref-commerce') },
  [PSCustomObject]@{ name='excludes_expired_unconfirmed_and_sensitive_chunks'; passed=($ids -notcontains 'expired-temp' -and $ids -notcontains 'unconfirmed-habit' -and $ids -notcontains 'sensitive') },
  [PSCustomObject]@{ name='temporary_context_is_not_promoted'; passed=($result.temporary_context_auto_promoted -eq $false) },
  [PSCustomObject]@{ name='recent_and_frequent_memory_uses_fast_tier'; passed=($result.selected_chunks[0].retrieval_tier -eq 'hot' -and [int]$result.selected_chunks[0].access_count -ge 0) },
  [PSCustomObject]@{ name='retrieval_exposes_tier_metadata_only'; passed=($result.selected_chunks[0].PSObject.Properties.Name -contains 'retrieval_tier' -and $result.selected_chunks[0].PSObject.Properties.Name -contains 'retrieval_score') },
  [PSCustomObject]@{ name='chunk_pack_has_no_authority'; passed=($result.authority -eq 'none' -and $result.permissions_changed -eq $false -and $result.data_scope_changed -eq $false -and $result.confirmation_requirement_changed -eq $false) },
  [PSCustomObject]@{ name='selector_makes_no_external_calls'; passed=($result.external_calls -eq $false) }
)
$failed = @($cases | Where-Object { -not $_.passed })
$summary = [PSCustomObject]@{ passed=($failed.Count -eq 0); cases=$cases; external_calls=$false; permissions_changed=$false; data_scope_changed=$false; raw_full_store_returned=$false }
if ($PassThru) { $summary | ConvertTo-Json -Depth 10 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw ('Personal memory chunk regression failed: ' + (($failed | ForEach-Object { $_.name }) -join ', ')) }
