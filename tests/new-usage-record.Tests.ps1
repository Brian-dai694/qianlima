BeforeAll {
  $script:ScriptPath = Join-Path $PSScriptRoot '..\.qianlima\scripts\new-usage-record.ps1'
  $script:TmpDir = Join-Path $env:TEMP ("usagepester-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:TmpDir -Force | Out-Null
  function script:Make { param($p) & $script:ScriptPath -Root $script:TmpDir @p | Out-Null }
  function script:Ledger { param($runId)
    $safe = $runId -replace '[^A-Za-z0-9_.-]', '-'
    Get-Content -LiteralPath (Join-Path $script:TmpDir "usage-ledger\$safe.yaml") -Raw
  }
}

AfterAll { Remove-Item -Recurse -Force $script:TmpDir -ErrorAction SilentlyContinue }

Describe 'new-usage-record cost guard' {
  It 'flags over_limit and needs_confirmation when cost exceeds the limit' {
    Make @{ RunId = 'overlimit'; EstimatedCost = 5; CostLimit = 1; Force = $true }
    $y = Ledger 'overlimit'
    $y | Should -Match 'cost_status: over_limit'
    $y | Should -Match 'continue_or_stop: needs_confirmation'
  }
  It 'flags over_baseline_guard when cost exceeds 2x baseline' {
    Make @{ RunId = 'baseguard'; EstimatedCost = 3; BaselineCost = 1; Force = $true }
    Ledger 'baseguard' | Should -Match 'cost_status: over_baseline_guard'
  }
  It 'prioritizes over_limit over the baseline guard' {
    Make @{ RunId = 'prec'; EstimatedCost = 5; CostLimit = 1; BaselineCost = 1; Force = $true }
    Ledger 'prec' | Should -Match 'cost_status: over_limit'
  }
  It 'stays continue and computes savings for a normal run' {
    Make @{ RunId = 'normal'; EstimatedCost = 1; BaselineCost = 10; Force = $true }
    $y = Ledger 'normal'
    $y | Should -Match 'continue_or_stop: continue'
    $y | Should -Match 'estimated_savings: 9'
  }
  It 'sanitizes the run id into the file name' {
    Make @{ RunId = 'a/b c'; EstimatedCost = 1; Force = $true }
    Test-Path (Join-Path $script:TmpDir 'usage-ledger\a-b-c.yaml') | Should -BeTrue
  }
  It 'throws on negative cost' {
    { & $script:ScriptPath -Root $script:TmpDir -RunId 'neg' -EstimatedCost -1 -Force } | Should -Throw
  }
  It 'throws when the ledger exists and -Force is absent' {
    Make @{ RunId = 'dup'; EstimatedCost = 1; Force = $true }
    { & $script:ScriptPath -Root $script:TmpDir -RunId 'dup' -EstimatedCost 1 } | Should -Throw
  }
}
