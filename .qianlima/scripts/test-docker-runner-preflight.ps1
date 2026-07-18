<##
.SYNOPSIS
  Regression test for Docker Runner fail-closed preflight.
  It never pulls an image or starts a container.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$probe = Join-Path $PSScriptRoot 'probe-docker-runner.ps1'
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
$taskId = "docker-preflight-$stamp"
$isolation = Join-Path $projectRoot ".qianlima\run-traces\sandbox-workspaces\$taskId\container"
New-Item -ItemType Directory -Path $isolation -Force | Out-Null
$output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $probe -AgentId codewhale_worker -TaskId $taskId -IsolationRoot $isolation -Image 'alpine:3.20' -IssueAttestation -PassThru 2>&1)
$exitCode = $LASTEXITCODE
$text = $output -join "`n"
$blocked = $exitCode -ne 0 -and $text -match '(?i)(Docker CLI is not installed|Runner is not enabled|Required image is not available locally|Docker daemon is unavailable|IssueAttestation requires)'
$result = [PSCustomObject]@{ passed = $blocked; fail_closed = $blocked; container_started = $false; attestation_issued = $false; note = 'Preflight was denied before any image pull or container start.' }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
if (-not $result.passed) { throw "Docker Runner preflight regression failed: $text" }
