<##
.SYNOPSIS
  Clears personal preference, Chunk, and candidate content after confirmation.
.DESCRIPTION
  Replaces active stores with empty stores and redacts candidate content while
  retaining only non-sensitive revocation metadata. It never changes grants,
  permissions, or enterprise data.
##>
param(
  [Parameter(Mandatory = $true)] [switch]$UserConfirmed,
  [string]$StorageRoot = '',
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
if (-not $UserConfirmed) { throw 'Explicit confirmation is required before clearing personal experience.' }
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workingRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\working')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$tmpRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\tmp')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$rootCandidate = if ([string]::IsNullOrWhiteSpace($StorageRoot)) { Join-Path $projectRoot '.qianlima\working' } elseif ([IO.Path]::IsPathRooted($StorageRoot)) { $StorageRoot } else { Join-Path $projectRoot $StorageRoot }
$root = [IO.Path]::GetFullPath($rootCandidate).TrimEnd('\', '/')
if (-not $root.StartsWith($workingRoot.TrimEnd('\', '/'), [StringComparison]::OrdinalIgnoreCase) -and -not $root.StartsWith($tmpRoot.TrimEnd('\', '/'), [StringComparison]::OrdinalIgnoreCase)) { throw 'StorageRoot must remain inside the personal working or test scope.' }
$now = (Get-Date).ToUniversalTime().ToString('o')
$cleared = [System.Collections.Generic.List[string]]::new()
$preferencePath = Join-Path $root 'personal-preferences.json'
$emptyPreferences = [ordered]@{ schema_version = 3; profile = 'personal'; preferences = @(); cleared_at = $now; content_cleared = $true }
[IO.File]::WriteAllText($preferencePath, ($emptyPreferences | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
[void]$cleared.Add('personal_preferences')
$chunkPath = Join-Path $root 'personal-memory-chunks.json'
if (Test-Path -LiteralPath $chunkPath -PathType Leaf) {
  $emptyChunks = [ordered]@{ schema_version = 2; profile = 'personal'; chunks = @(); cleared_at = $now; content_cleared = $true }
  [IO.File]::WriteAllText($chunkPath, ($emptyChunks | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
  [void]$cleared.Add('personal_memory_chunks')
}
$candidateRoot = if ($root -ieq $workingRoot.TrimEnd('\', '/')) { Join-Path $projectRoot '.qianlima\evolution\candidates' } else { Join-Path $root 'candidates' }
$candidateCount = 0
if (Test-Path -LiteralPath $candidateRoot -PathType Container) {
  foreach ($candidatePath in @(Get-ChildItem -LiteralPath $candidateRoot -Filter '*.json' -File -Force)) {
    try { $candidate = Get-Content -LiteralPath $candidatePath.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    if ($candidate.type -ne 'personal_preference_candidate') { continue }
    $redacted = [ordered]@{}
    foreach ($property in $candidate.PSObject.Properties) { $redacted[$property.Name] = $property.Value }
    $redacted['correction'] = $null; $redacted['status'] = 'revoked'; $redacted['promotion_status'] = 'revoked'; $redacted['content_cleared'] = $true; $redacted['revoked_at'] = $now
    [IO.File]::WriteAllText($candidatePath.FullName, ($redacted | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $candidateCount++
  }
}
$result = [PSCustomObject]@{ status='personal_experience_cleared'; cleared_items=@($cleared); redacted_candidate_count=$candidateCount; permissions_changed=$false; data_scope_changed=$false; grants_changed=$false; external_calls=$false; confirmation_received=$true }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
