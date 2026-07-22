<##
.SYNOPSIS
  Regression tests for credentials, artifact scanning, and incident containment.
  All data is synthetic and local. No provider or external notification is used.
##>
param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$traceRoot = Join-Path $projectRoot '.qianlima\run-traces'
$workingRoot = Join-Path $traceRoot 'working\security-controls'
$scanner = Join-Path $PSScriptRoot 'scan-governed-artifact.ps1'
$credential = Join-Path $PSScriptRoot 'validate-credential-reference.ps1'
$incident = Join-Path $PSScriptRoot 'record-security-incident.ps1'
$grantScript = Join-Path $PSScriptRoot 'new-delegation-grant.ps1'
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
New-Item -ItemType Directory -Path $workingRoot -Force | Out-Null
$cases = [System.Collections.Generic.List[object]]::new()
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
function Invoke-ExpectedFailure([scriptblock]$Action, [string]$Needle) {
  $output = @(); $exitCode = 0
  try { $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $output = @(& $Action 2>&1); $exitCode = $LASTEXITCODE; $ErrorActionPreference = $old }
  catch { $output += $_ | Out-String; $exitCode = 1 }
  return ($exitCode -ne 0 -and ($output -join "`n") -match $Needle)
}

$safePath = Join-Path $workingRoot "safe-$stamp.md"
$secretPath = Join-Path $workingRoot "secret-$stamp.md"
[IO.File]::WriteAllText($safePath, "Sanitized evidence summary for a local regression case.", [Text.UTF8Encoding]::new($false))
$secretFixture = ('api' + '_key=' + ('X' * 24))
[IO.File]::WriteAllText($secretPath, $secretFixture, [Text.UTF8Encoding]::new($false))
$safeResult = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scanner -ArtifactPath $safePath -MediaType text/markdown -SourceClassification internal_sanitized -TaskId "security-safe-$stamp" -PassThru | ConvertFrom-Json
Add-Case 'safe_artifact_passed' ($safeResult.status -eq 'passed' -and $safeResult.raw_content_recorded -eq $false)
Add-Case 'secret_artifact_rejected' (Invoke-ExpectedFailure { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scanner -ArtifactPath $secretPath -MediaType text/markdown -SourceClassification internal_sanitized -TaskId "security-secret-$stamp" -PassThru } 'secret_assignment')
Add-Case 'credential_reference_disabled_by_default' (Invoke-ExpectedFailure { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $credential -CredentialId model_provider_openai -ConsumerId docker_local_isolated -TaskId "security-credential-$stamp" -PassThru } 'disabled')
Add-Case 'unknown_credential_denied' (Invoke-ExpectedFailure { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $credential -CredentialId unknown_ref -ConsumerId docker_local_isolated -TaskId "security-credential-unknown-$stamp" -PassThru } 'not registered')
$grantId = "security-incident-grant-$stamp"; $taskId = "security-incident-task-$stamp"; $recoveryTaskId = "security-recovery-task-$stamp"; $orderId = "security-incident-order-$stamp"
& $grantScript -GrantId $grantId -AgentId codewhale_worker -TaskId $taskId -WorkOrderId $orderId -DataRef artifact-sanitized -AllowedTool read_selected_sources -RiskCeiling L2 -VerifierAgentId codex_supervisor | Out-Null
$incidentResult = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $incident -IncidentId "incident-$stamp" -TaskId $taskId -RecoveryTaskId $recoveryTaskId -AgentId codewhale_worker -Trigger secret_exposure -Severity critical -EvidenceRef "artifact-scans/$stamp.json" -GrantId $grantId -PassThru | ConvertFrom-Json
$incidentPath = Join-Path $traceRoot "incidents/incident-$stamp.json"
$revocationPath = Join-Path $traceRoot 'grant-revocations.jsonl'
$revoked = (Get-Content -LiteralPath $revocationPath -Encoding UTF8 | Where-Object { $_ -match [regex]::Escape($grantId) }).Count -gt 0
Add-Case 'incident_frozen' ($incidentResult.status -eq 'frozen' -and $incidentResult.external_notification_sent -eq $false)
Add-Case 'incident_revoked_grant' ($revoked -and @($incidentResult.containment_actions) -contains 'grant_revoked')
Add-Case 'incident_recovery_reference' ($incidentResult.recovery_task_id -eq $recoveryTaskId -and (Test-Path -LiteralPath $incidentPath -PathType Leaf))
$failed = @($cases | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ passed = ($failed.Count -eq 0); cases = @($cases); external_calls = $false; secret_values_recorded = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 10 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw "Security controls regression failed: $($failed.name -join ', ')" }
