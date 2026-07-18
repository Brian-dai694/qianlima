<##
.SYNOPSIS
  Scans a text Artifact before it can be accepted by the Broker.
.DESCRIPTION
  The scanner returns rule IDs and hashes only. It never writes matched
  content to a receipt or audit event. Binary/unsupported media is rejected
  for manual review rather than treated as clean.
##>
param(
  [Parameter(Mandatory = $true)] [string]$ArtifactPath,
  [Parameter(Mandatory = $true)] [ValidateSet('text/plain', 'text/markdown', 'application/json', 'text/csv', 'text/yaml', 'application/yaml', 'text/html', 'application/xml', 'text/xml')] [string]$MediaType,
  [Parameter(Mandatory = $true)] [ValidateSet('public', 'internal_sanitized', 'confidential_reference_only')] [string]$SourceClassification,
  [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$TaskId = 'artifact-scan',
  [string]$ExpectedHash = '',
  [ValidateRange(1, 20)] [int]$MaxMegabytes = 5,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$audit = Join-Path $PSScriptRoot 'write-audit-event.ps1'
$scanRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces\artifact-scans')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$allowedRoots = [System.Collections.Generic.List[string]]::new()
[void]$allowedRoots.Add(([IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\run-traces')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar))
[void]$allowedRoots.Add(([IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\reports\generated')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar))
[void]$allowedRoots.Add(([IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\evolution\candidates')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar))
function Test-AllowedPath([string]$Path) {
  $candidate = ([string]$Path).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  foreach ($root in @($allowedRoots)) {
    $normalizedRoot = ([string]$root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if ($candidate.StartsWith($normalizedRoot, [StringComparison]::OrdinalIgnoreCase)) { return $true }
  }
  return $false
}
function Emit([string]$Status, [string[]]$Rules, [string]$Hash, [string]$Reason) {
  if (-not (Test-Path -LiteralPath (Split-Path -Parent $scanRoot) -PathType Container)) { New-Item -ItemType Directory -Path (Split-Path -Parent $scanRoot) -Force | Out-Null }
  if (-not (Test-Path -LiteralPath $scanRoot -PathType Container)) { New-Item -ItemType Directory -Path $scanRoot -Force | Out-Null }
  $scanId = "artifact-scan-$TaskId-$([Guid]::NewGuid().ToString('n').Substring(0, 12))"
  $outPath = Join-Path $scanRoot "$scanId.json"
  $record = [ordered]@{ schema_version = 1; scan_id = $scanId; task_id = $TaskId; artifact_path = (Split-Path -Leaf $ArtifactPath); media_type = $MediaType; source_classification = $SourceClassification; status = $Status; rule_ids = @($Rules); integrity_hash = $Hash; reason = $Reason; raw_content_recorded = $false; created_at = (Get-Date).ToUniversalTime().ToString('o') }
  [IO.File]::WriteAllText($outPath, ($record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
  $decision = if ($Status -eq 'passed') { 'complete' } else { 'deny' }
  & $audit -EventType artifact_scan_completed -Decision $decision -TaskId $TaskId -Reason "Artifact scan $Status; rule IDs only, raw content excluded." 6>$null | Out-Null
  if ($PassThru) { $record | ConvertTo-Json -Depth 8 } else { $record | Format-List }
  return
}

$resolvedArtifact = Resolve-Path -LiteralPath $ArtifactPath -ErrorAction Stop
$fullPath = [string]$resolvedArtifact.Path
if (-not (Test-AllowedPath $fullPath)) { Emit 'rejected' @('path_outside_artifact_scope') '' 'Artifact is outside an approved artifact root.'; exit 1 }
$item = Get-Item -LiteralPath $fullPath
if ($item.Length -gt ($MaxMegabytes * 1MB)) { Emit 'rejected' @('artifact_size_limit') '' 'Artifact exceeds the scan size limit.'; exit 1 }
$bytes = [IO.File]::ReadAllBytes($fullPath)
$sha = [Security.Cryptography.SHA256]::Create(); $hash = 'sha256:' + (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
if ($ExpectedHash -and $ExpectedHash -ne $hash) { Emit 'rejected' @('integrity_mismatch') $hash 'Artifact hash does not match the expected hash.'; exit 1 }
$text = [Text.Encoding]::UTF8.GetString($bytes)
$findings = [System.Collections.Generic.List[string]]::new()
$patterns = [ordered]@{
  secret_assignment = '(?i)\b(api[_-]?key|access[_-]?token|refresh[_-]?token|password|client[_-]?secret)\b\s*[:=]\s*["''`]?[A-Za-z0-9+/=_-]{8,}'
  bearer_token = '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{20,}'
  private_key = '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
  aws_access_key = '\bAKIA[0-9A-Z]{16}\b'
  authorization_header = '(?i)\b(authorization|cookie)\s*[:=]\s*[^\r\n]{8,}'
  user_home_path = '(?i)([A-Z]:\\Users\\|/Users/|/home/)[^\s"'']+'
}
foreach ($entry in $patterns.GetEnumerator()) { if ($text -match $entry.Value) { [void]$findings.Add($entry.Key) } }
$status = if ($findings.Count -eq 0) { 'passed' } else { 'rejected' }
$reason = if ($status -eq 'passed') { 'No governed secret or private-path pattern detected.' } else { 'Artifact contains one or more blocked content patterns.' }
Emit $status @($findings) $hash $reason
if ($status -ne 'passed') { exit 1 }
