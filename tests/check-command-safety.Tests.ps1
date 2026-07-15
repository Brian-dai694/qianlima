BeforeAll {
  $script:ScriptPath = Join-Path $PSScriptRoot '..\.qianlima\scripts\check-command-safety.ps1'
}

Describe 'check-command-safety' {
  It 'allows a benign read-only command' {
    $r = & $script:ScriptPath -Command 'Get-ChildItem' -AsJson -NoExit | ConvertFrom-Json
    $r.classification | Should -Be 'allow'
    $r.destructive | Should -Be $false
    $r.required_action | Should -Be 'may_continue'
  }

  It 'denies recursive force-delete of a system path' {
    $r = & $script:ScriptPath -Command 'Remove-Item -Recurse -Force C:\Windows' -AsJson -NoExit | ConvertFrom-Json
    $r.classification | Should -Be 'deny'
    $r.destructive | Should -Be $true
  }

  It 'flags a destructive verb as not allow' {
    $r = & $script:ScriptPath -Command 'del important.txt' -AsJson -NoExit | ConvertFrom-Json
    $r.destructive | Should -Be $true
    $r.classification | Should -Not -Be 'allow'
  }

  It 'sets a non-zero exit code for deny without -NoExit' {
    & $script:ScriptPath -Command 'Remove-Item -Recurse -Force C:\Windows' -AsJson | Out-Null
    $LASTEXITCODE | Should -Be 20
  }
}
