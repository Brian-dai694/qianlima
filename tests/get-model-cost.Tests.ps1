BeforeAll {
  $script:ScriptPath = Join-Path $PSScriptRoot '..\.qianlima\scripts\get-model-cost.ps1'
}

Describe 'get-model-cost' {
  It 'computes priced cost from the catalog (deepseek 1M in + 1M out = 3 CNY)' {
    $r = & $script:ScriptPath -Provider deepseek -Model deepseek-v4-flash `
      -InputTokens 1000000 -OutputTokens 1000000 -AsJson | ConvertFrom-Json
    $r.status | Should -Be 'priced'
    $r.currency | Should -Be 'CNY'
    $r.input_cost | Should -Be 1
    $r.output_cost | Should -Be 2
    $r.estimated_cost | Should -Be 3
  }

  It 'returns source_only when no verified price exists' {
    $r = & $script:ScriptPath -Provider anthropic -Model claude-opus-4-8 `
      -InputTokens 1000 -OutputTokens 1000 -AsJson | ConvertFrom-Json
    $r.status | Should -Be 'source_only'
  }

  It 'throws on negative token counts' {
    { & $script:ScriptPath -Provider deepseek -Model deepseek-v4-flash `
        -InputTokens -1 -AsJson } | Should -Throw
  }

  It 'throws when cached input exceeds total input' {
    { & $script:ScriptPath -Provider deepseek -Model deepseek-v4-flash `
        -InputTokens 100 -CachedInputTokens 200 -AsJson } | Should -Throw
  }

  It 'returns source_only with empty source_url for an unknown model' {
    $r = & $script:ScriptPath -Provider nobody -Model ghost-1 `
      -InputTokens 10 -OutputTokens 10 -AsJson | ConvertFrom-Json
    $r.status | Should -Be 'source_only'
    $r.source_url | Should -BeNullOrEmpty
  }
}
