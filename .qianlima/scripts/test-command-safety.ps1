$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$guardScript = Join-Path $PSScriptRoot 'check-command-safety.ps1'
$cases = @(
  [PSCustomObject]@{ Name = 'read_only'; Command = 'Get-Content .qianlima\CODEX_BOOT.md'; Expected = 'allow' },
  [PSCustomObject]@{ Name = 'controlled_cleanup'; Command = 'Remove-Item -LiteralPath ''.qianlima\tmp\old.txt'''; Expected = 'confirmation_required' },
  [PSCustomObject]@{ Name = 'rm_recursive_root'; Command = 'rm -rf C:\'; Expected = 'deny' },
  [PSCustomObject]@{ Name = 'remove_item_recursive_user_root'; Command = 'Remove-Item -Recurse -Force ''C:\Users\example-user'''; Expected = 'deny' },
  [PSCustomObject]@{ Name = 'del_batch'; Command = 'del /f /s /q ''C:\OutsideWorkspace\*'''; Expected = 'deny' },
  [PSCustomObject]@{ Name = 'rd_batch'; Command = 'rd /s /q ''D:\'''; Expected = 'deny' },
  [PSCustomObject]@{ Name = 'home_variable'; Command = 'Remove-Item -Recurse $HOME'; Expected = 'deny' },
  [PSCustomObject]@{ Name = 'userprofile_variable'; Command = 'Remove-Item -Recurse %USERPROFILE%'; Expected = 'deny' },
  [PSCustomObject]@{ Name = 'wildcard_target'; Command = 'Remove-Item ''.qianlima\tmp\*'''; Expected = 'deny' },
  [PSCustomObject]@{ Name = 'parent_traversal'; Command = 'Clear-Content -LiteralPath ''..\notes.md'''; Expected = 'deny' },
  [PSCustomObject]@{ Name = 'move_outside_workspace'; Command = 'Move-Item ''.qianlima\tmp\file.txt'' ''C:\OutsideWorkspace\file.txt'''; Expected = 'deny' }
)

$results = foreach ($case in $cases) {
  $result = & $guardScript -Command $case.Command -AsJson -NoExit | ConvertFrom-Json
  [PSCustomObject]@{
    name = $case.Name
    expected = $case.Expected
    actual = $result.classification
    passed = $result.classification -eq $case.Expected
  }
}

$failed = @($results | Where-Object { -not $_.passed })
$results | Format-Table -AutoSize
if ($failed.Count -gt 0) {
  throw "Command safety regression failed: $($failed.name -join ', ')"
}
Write-Host "Command safety regression passed: $($results.Count) cases."
