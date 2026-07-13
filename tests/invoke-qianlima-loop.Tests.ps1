BeforeAll {
  $script:ScriptPath = Join-Path $PSScriptRoot '..\.qianlima\scripts\invoke-qianlima-loop.ps1'
  $script:TmpDir = Join-Path $env:TEMP ("looppester-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:TmpDir -Force | Out-Null
  function script:Run { param($p) & $script:ScriptPath @p | Out-Null }
  function script:St { param($sp) Get-Content -LiteralPath $sp -Raw | ConvertFrom-Json }
  function script:NewSp { param($n) Join-Path $script:TmpDir ($n + '.json') }
}

AfterAll {
  Remove-Item -Recurse -Force $script:TmpDir -ErrorAction SilentlyContinue
}

Describe 'invoke-qianlima-loop state machine' {
  Context 'EVR (backward compatible)' {
    It 'starts at execute and completes on verify_pass' {
      $sp = NewSp 'evr'
      Run @{ WorkflowId = 'daily_ad_report'; LoopType = 'EVR'; Action = 'Start'; StatePath = $sp }
      (St $sp).current_state | Should -Be 'execute'
      Run @{ WorkflowId = 'x'; Action = 'Advance'; Outcome = 'execute_complete'; StatePath = $sp }
      Run @{ WorkflowId = 'x'; Action = 'Advance'; Outcome = 'verify_pass'; StatePath = $sp }
      (St $sp).status | Should -Be 'completed'
    }

    It 'freezes at max iterations on repeated verify_issues' {
      $sp = NewSp 'evr2'
      Run @{ WorkflowId = 'x'; LoopType = 'EVR'; Action = 'Start'; StatePath = $sp; MaxIterations = 1 }
      Run @{ WorkflowId = 'x'; Action = 'Advance'; Outcome = 'execute_complete'; StatePath = $sp }
      Run @{ WorkflowId = 'x'; Action = 'Advance'; Outcome = 'verify_issues'; StatePath = $sp }
      (St $sp).current_state | Should -Be 'refine'
      Run @{ WorkflowId = 'x'; Action = 'Advance'; Outcome = 'refine_complete'; StatePath = $sp }
      Run @{ WorkflowId = 'x'; Action = 'Advance'; Outcome = 'verify_issues'; StatePath = $sp }
      (St $sp).status | Should -Be 'frozen'
    }
  }

  Context 'SDR' {
    It 'retries scan on blind spots then completes' {
      $sp = NewSp 'sdr'
      Run @{ WorkflowId = 'keyword_rank_scan'; LoopType = 'SDR'; Action = 'Start'; StatePath = $sp }
      (St $sp).current_state | Should -Be 'scan'
      Run @{ WorkflowId = 'k'; Action = 'Advance'; Outcome = 'scan_complete'; StatePath = $sp }
      Run @{ WorkflowId = 'k'; Action = 'Advance'; Outcome = 'doubt_complete'; StatePath = $sp }
      Run @{ WorkflowId = 'k'; Action = 'Advance'; Outcome = 'reconcile_blind_spots'; StatePath = $sp }
      (St $sp).current_state | Should -Be 'scan'
      (St $sp).iteration | Should -Be 1
    }
  }

  Context 'PBV' {
    It 'defaults max iterations to 2 and retries plan on verify_issues' {
      $sp = NewSp 'pbv'
      Run @{ WorkflowId = 'listing_optimization'; LoopType = 'PBV'; Action = 'Start'; StatePath = $sp }
      (St $sp).max_iterations | Should -Be 2
      Run @{ WorkflowId = 'l'; Action = 'Advance'; Outcome = 'plan_ready'; StatePath = $sp }
      Run @{ WorkflowId = 'l'; Action = 'Advance'; Outcome = 'build_complete'; StatePath = $sp }
      Run @{ WorkflowId = 'l'; Action = 'Advance'; Outcome = 'verify_issues'; StatePath = $sp }
      (St $sp).current_state | Should -Be 'plan'
    }
  }

  Context 'EDA' {
    It 'runs explore->decide->act->observe to completion' {
      $sp = NewSp 'eda'
      Run @{ WorkflowId = 'competitor_comparison'; LoopType = 'EDA'; Action = 'Start'; StatePath = $sp }
      Run @{ WorkflowId = 'c'; Action = 'Advance'; Outcome = 'explore_complete'; StatePath = $sp }
      Run @{ WorkflowId = 'c'; Action = 'Advance'; Outcome = 'decide_ok'; StatePath = $sp }
      Run @{ WorkflowId = 'c'; Action = 'Advance'; Outcome = 'act_complete'; StatePath = $sp }
      (St $sp).current_state | Should -Be 'observe'
      Run @{ WorkflowId = 'c'; Action = 'Advance'; Outcome = 'observe_complete'; StatePath = $sp }
      (St $sp).status | Should -Be 'completed'
    }
  }

  Context 'validation' {
    It 'rejects an outcome that is invalid for the loop type' {
      $sp = NewSp 'inv'
      Run @{ WorkflowId = 'x'; LoopType = 'SDR'; Action = 'Start'; StatePath = $sp }
      { & $script:ScriptPath -WorkflowId 'x' -Action 'Advance' -Outcome 'verify_pass' -StatePath $sp } |
        Should -Throw
    }
  }
}
