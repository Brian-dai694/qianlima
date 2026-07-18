<##
.SYNOPSIS
  Reads a minimum, task-scoped memory pack after Broker validation.
.DESCRIPTION
  The validator is authoritative for grant, task, agent, view, expiry, and
  revocation checks. This wrapper returns only selected memory fields and never
  returns the raw memory record or full memory store.
##>
param(
  [Parameter(Mandatory = $true)] [string]$RequestPath,
  [Parameter(Mandatory = $true)] [string]$GrantPath,
  [Parameter(Mandatory = $true)] [string]$MemoryPath,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $PSScriptRoot 'validate-memory-read.ps1'
$validationOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -RequestPath $RequestPath -GrantPath $GrantPath -MemoryPath $MemoryPath -PassThru 2>&1)
$validationCode = $LASTEXITCODE
$validationText = ($validationOutput -join "`n")
$validation = $null
$jsonStart = $validationText.IndexOf('{'); $jsonEnd = $validationText.LastIndexOf('}')
if ($jsonStart -ge 0 -and $jsonEnd -gt $jsonStart) { try { $validation = $validationText.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json } catch { } }
if ($validationCode -ne 0 -or $null -eq $validation -or $validation.status -ne 'allowed') {
  $blocked = [ordered]@{ status = 'denied'; stage = 'memory_read_gate'; validation = $validation; contents_returned = $false; raw_memory_recorded = $false; external_calls = $false }
  if ($PassThru) { $blocked | ConvertTo-Json -Depth 12 } else { $blocked | Format-List }
  exit 1
}
$request = Get-Content -LiteralPath (Resolve-Path -LiteralPath $RequestPath -ErrorAction Stop) -Raw -Encoding UTF8 | ConvertFrom-Json
$memory = Get-Content -LiteralPath (Resolve-Path -LiteralPath $MemoryPath -ErrorAction Stop) -Raw -Encoding UTF8 | ConvertFrom-Json
$facts = @()
if ($null -ne $memory.facts) {
  foreach ($fact in @($memory.facts) | Select-Object -First ([int]$request.max_items)) {
    if ($null -ne $fact -and $null -ne $fact.key -and $null -ne $fact.value) { $facts += [ordered]@{ key = [string]$fact.key; value = [string]$fact.value } }
  }
}
$pack = [ordered]@{
  status = 'allowed'
  request_id = [string]$request.request_id
  task_id = [string]$request.task_id
  grant_id = [string]$request.grant_id
  agent_id = [string]$request.agent_id
  state_view = [string]$request.requested_state_view
  memory_pack = [ordered]@{ memory_id = [string]$memory.memory_id; state = [string]$memory.state; source_refs = @($memory.source_refs); valid_from = [string]$memory.valid_from; valid_to = [string]$memory.valid_to; scope = [string]$memory.scope; confidence = [string]$memory.confidence; classification = [string]$memory.classification; facts = @($facts) }
  source_reload_required = ($validation.source_reload_required -eq $true)
  contents_returned = $true
  full_memory_returned = $false
  raw_memory_recorded = $false
  external_calls = $false
}
if ($PassThru) { $pack | ConvertTo-Json -Depth 12 } else { $pack | Format-List }
