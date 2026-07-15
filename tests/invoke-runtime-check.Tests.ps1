BeforeAll {
  $script:ScriptPath = Join-Path $PSScriptRoot '..\.qianlima\scripts\invoke-runtime-check.ps1'
  $script:TmpDir = Join-Path $env:TEMP ("rtpester-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:TmpDir -Force | Out-Null
  # Run in a child process so the script's `exit` cannot terminate the Pester host.
  function script:RtExit { param($params)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ScriptPath @params *> $null
    return $LASTEXITCODE
  }
}

AfterAll { Remove-Item -Recurse -Force $script:TmpDir -ErrorAction SilentlyContinue }

Describe 'invoke-runtime-check phase gate' {
  It 'blocks an unconfirmed high-risk action (exit 1)' {
    RtExit @('-Phase', 'BeforeToolUse', '-Action', 'change_bid') | Should -Be 1
  }
  It 'allows a confirmed high-risk action (exit 0)' {
    RtExit @('-Phase', 'BeforeToolUse', '-Action', 'change_bid', '-Confirmed') | Should -Be 0
  }
  It 'allows a benign action (exit 0)' {
    RtExit @('-Phase', 'BeforeToolUse', '-Action', 'read_data') | Should -Be 0
  }
  It 'fails AfterToolUse when the output ref does not exist (exit 1)' {
    $ghost = Join-Path $script:TmpDir 'no-such-output.md'
    RtExit @('-Phase', 'AfterToolUse', '-OutputPath', $ghost) | Should -Be 1
  }
  It 'requires a usage ledger at FinalCheck (exit 1)' {
    RtExit @('-Phase', 'FinalCheck') | Should -Be 1
  }
}
