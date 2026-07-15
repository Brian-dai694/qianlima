BeforeAll {
  $script:ScriptPath = Join-Path $PSScriptRoot '..\.qianlima\scripts\get-snapshot-decision.ps1'
  $script:TmpDir = Join-Path $env:TEMP ("snappester-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:TmpDir -Force | Out-Null
  function script:NewSnap { param($name, $quality, $ageSeconds, $ttl)
    $gen = [datetimeoffset]::Now.AddSeconds(-$ageSeconds).ToString('o')
    $p = Join-Path $script:TmpDir "$name.json"
    [PSCustomObject]@{ route = 'r'; quality_status = $quality; generated_at = $gen
      ttl_seconds = $ttl; facts = @('f'); anomalies = @(); source_refs = @('s') } |
      ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $p -Encoding UTF8
    return $p
  }
  function script:Decide { param($p, $swr = 3600) & $script:ScriptPath -SnapshotPath $p -SWRSeconds $swr -Json | ConvertFrom-Json }
}

AfterAll { Remove-Item -Recurse -Force $script:TmpDir -ErrorAction SilentlyContinue }

Describe 'get-snapshot-decision' {
  It 'serves a fresh snapshot within TTL (grade B)' {
    $d = Decide (NewSnap 'fresh' 'passed' 10 900)
    $d.decision | Should -Be 'serve_snapshot_and_refresh'
    $d.evidence_grade | Should -Be 'B'
  }
  It 'serves stale within the SWR window (grade C)' {
    $d = Decide (NewSnap 'stale' 'passed' 2000 900)
    $d.decision | Should -Be 'serve_stale_snapshot_and_refresh_before_final'
    $d.evidence_grade | Should -Be 'C'
  }
  It 'requires live evidence beyond the SWR window' {
    (Decide (NewSnap 'expired' 'passed' 10000 900)).decision | Should -Be 'live_evidence_required'
  }
  It 'requires live evidence when quality is not passed' {
    $d = Decide (NewSnap 'bad' 'failed' 10 900)
    $d.decision | Should -Be 'live_evidence_required'
    $d.evidence_grade | Should -Be 'C'
  }
  It 'throws when the snapshot file is missing' {
    { & $script:ScriptPath -SnapshotPath (Join-Path $script:TmpDir 'nope.json') -Json } | Should -Throw
  }
}
