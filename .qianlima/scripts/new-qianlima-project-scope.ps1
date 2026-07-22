<##
.SYNOPSIS
  Creates a public-safe Qianlima Amazon project scope reference.
##>
param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')] [string]$ScopeId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{2,120}$')] [string]$StoreId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z]{2}$')] [string]$Marketplace,
  [Parameter(Mandatory = $true)] [string]$Brand,
  [Parameter(Mandatory = $true)] [string]$ProductLine,
  [ValidateSet('public','internal_sanitized','private_local')] [string]$Classification = 'private_local',
  [string]$OutputPath = '',
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scopeRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\project-scopes')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
foreach ($value in @($Brand, $ProductLine)) { if ([string]$value -match '(?i)(api[_-]?key|token|password|cookie|https?://|email|phone)') { throw 'Project scope labels cannot contain credentials, URLs, or personal contact data.' } }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $scopeRoot "$ScopeId.json" }
$fullOutput = [IO.Path]::GetFullPath($OutputPath)
if (-not $fullOutput.StartsWith($scopeRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputPath must remain under project-scopes.' }
if (Test-Path -LiteralPath $fullOutput) { throw "Project scope already exists: $ScopeId" }
$scope = [ordered]@{ scope_id = $ScopeId; store_id = $StoreId; marketplace = $Marketplace.ToUpperInvariant(); brand = $Brand; product_line = $ProductLine; classification = $Classification; source_policy = 'selected_refs_only'; network_access = $false; business_write = $false; created_at = (Get-Date).ToUniversalTime().ToString('o') }
New-Item -ItemType Directory -Path (Split-Path -Parent $fullOutput) -Force | Out-Null
[IO.File]::WriteAllText($fullOutput, ($scope | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
if ($PassThru) { $scope | ConvertTo-Json -Depth 8 } else { Write-Host "Qianlima project scope created: $fullOutput" }
