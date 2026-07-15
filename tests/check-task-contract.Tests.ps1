BeforeAll {
  $script:ScriptPath = Join-Path $PSScriptRoot '..\.qianlima\scripts\check-task-contract.ps1'
  $script:TmpDir = Join-Path $env:TEMP ("ctrpester-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path (Join-Path $script:TmpDir 'working') -Force | Out-Null
  function script:NewContract { param($id, $control, $state, $deadlineOffsetSec)
    $deadline = [datetimeoffset]::Now.AddSeconds($deadlineOffsetSec).ToString('o')
    $p = Join-Path $script:TmpDir "working\task-contract-$id.json"
    [PSCustomObject]@{ request_id = $id; control = $control; state = $state
      deadline_at = $deadline; pending_checks = @('c1') } |
      ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $p -Encoding UTF8
  }
  function script:Eval { param($id) & $script:ScriptPath -RequestId $id -Root $script:TmpDir -Json | ConvertFrom-Json }
}

AfterAll { Remove-Item -Recurse -Force $script:TmpDir -ErrorAction SilentlyContinue }

Describe 'check-task-contract' {
  It 'lets a running contract with a future deadline continue' {
    NewContract 'run1' 'continue' 'running' 3600
    $c = Eval 'run1'
    $c.continue_external_reads | Should -BeTrue
    $c.delivery_mode | Should -Be 'continue'
  }
  It 'cancels when control is cancel' {
    NewContract 'cancel1' 'cancel' 'running' 3600
    $c = Eval 'cancel1'
    $c.state | Should -Be 'cancelled'
    $c.delivery_mode | Should -Be 'cancelled'
    $c.continue_external_reads | Should -BeFalse
  }
  It 'freezes and flags timed_out past the deadline' {
    NewContract 'timeout1' 'continue' 'running' -3600
    $c = Eval 'timeout1'
    $c.timed_out | Should -BeTrue
    $c.state | Should -Be 'frozen'
    $c.delivery_mode | Should -Be 'conclusion_only_with_pending_checks'
  }
  It 'freezes when control is stop_deep_dive' {
    NewContract 'stop1' 'stop_deep_dive' 'running' 3600
    (Eval 'stop1').state | Should -Be 'frozen'
  }
  It 'throws on an unsafe RequestId' {
    { & $script:ScriptPath -RequestId 'bad/id' -Root $script:TmpDir -Json } | Should -Throw
  }
  It 'throws when the contract file is missing' {
    { & $script:ScriptPath -RequestId 'ghost' -Root $script:TmpDir -Json } | Should -Throw
  }
}
