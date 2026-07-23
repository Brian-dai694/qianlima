$ErrorActionPreference = 'Stop'
$grantScript = Join-Path $PSScriptRoot 'new-delegation-grant.ps1'
$receiptScript = Join-Path $PSScriptRoot 'new-evidence-receipt.ps1'
$hash = 'sha256:' + ('a' * 64)
$stamp = (Get-Date).ToString('yyyyMMddHHmmssfff')
$grantId = "broker-smoke-grant-$stamp"
$taskId = "broker-smoke-task-$stamp"
$orderId = "broker-smoke-order-$stamp"
$receiptId = "broker-smoke-receipt-$stamp"
$grant = powershell.exe -NoProfile -ExecutionPolicy Bypass -File $grantScript -GrantId $grantId -AgentId 'evidence_checker' -TaskId $taskId -WorkOrderId $orderId -DataRef 'artifact-sanitized' -AllowedTool 'read_selected_sources' -RiskCeiling L2 -VerifierAgentId 'evidence_checker' -PassThru | ConvertFrom-Json
if ($grant.can_delegate -ne $false -or $grant.network_access -ne 'none' -or $grant.status -ne 'issued') { throw 'delegation grant invariants failed' }
 $receipt = powershell.exe -NoProfile -ExecutionPolicy Bypass -File $receiptScript -ReceiptId $receiptId -TaskId $taskId -GrantId $grantId -AgentId 'evidence_checker' -ConclusionSummary 'Bounded evidence check completed.' -SourceRef 'artifact-sanitized' -DataTimeRange '2026-07-16' -Assumption 'Source is sanitized.' -Uncertainty 'No live refresh.' -MethodRef 'verification_rule_v1' -ArtifactRef "run-traces/a2a-mock-$stamp.json" -IntegrityHash $hash -SourceClassification internal_sanitized -VerificationStatus passed -VerifierAgentId evidence_checker -PassThru | ConvertFrom-Json
if ($receipt.verification_status -ne 'passed' -or $receipt.grant_id -ne $grantId) { throw 'evidence receipt invariants failed' }
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$badL4 = powershell.exe -NoProfile -ExecutionPolicy Bypass -File $grantScript -GrantId "broker-smoke-l4-$stamp" -AgentId 'executor' -TaskId $taskId -WorkOrderId $orderId -DataRef 'artifact-sanitized' -AllowedTool 'approved_tool_only' -RiskCeiling L4 -VerifierAgentId 'evidence_checker' 2>&1
$badL4Exit = $LASTEXITCODE
$duplicate = powershell.exe -NoProfile -ExecutionPolicy Bypass -File $grantScript -GrantId $grantId -AgentId 'evidence_checker' -TaskId $taskId -WorkOrderId $orderId -DataRef 'artifact-sanitized' -AllowedTool 'read_selected_sources' -RiskCeiling L2 -VerifierAgentId 'evidence_checker' 2>&1
$duplicateExit = $LASTEXITCODE
$ErrorActionPreference = $previousPreference
if ($badL4Exit -eq 0) { throw 'L4 grant without confirmation accepted' }
if ($duplicateExit -eq 0) { throw 'duplicate grant accepted' }
Write-Host 'Broker contract regression passed: grant, evidence receipt, L4 gate, immutability.'
