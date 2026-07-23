<##
.SYNOPSIS
  Creates a bounded read-only Service/Repository source request.
##>
param(
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')] [string]$RequestId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,120}$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{2,120}$')] [string]$SourceId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{2,120}$')] [string]$ServiceId,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{2,120}$')] [string]$RepositoryId,
  [Parameter(Mandatory = $true)] [string]$ProjectScopeRef,
  [Parameter(Mandatory = $true)] [string]$Purpose,
  [Parameter(Mandatory = $true)] [string[]]$SelectedField,
  [Parameter(Mandatory = $true)] [string]$DataTimeRange,
  [string]$OutputPath = '',
  [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$requestRoot = [IO.Path]::GetFullPath((Join-Path $root '.qianlima\run-traces\source-requests')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
 $selectedFields = @($SelectedField | ForEach-Object { [string]$_ -split ',' } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
if ($selectedFields.Count -eq 0) { throw 'At least one selected field is required.' }
foreach ($value in @($ProjectScopeRef, $Purpose, $DataTimeRange) + @($selectedFields)) { if ([regex]::IsMatch([string]$value, '(?i)(api[_-]?key|token|password|cookie|https?://|whole_workspace|unbounded)')) { throw 'Source request contains a forbidden credential, URL, or unbounded scope.' } }
$scopeFull = [IO.Path]::GetFullPath((Join-Path $root ($ProjectScopeRef -replace '/', '\')))
$scopePrefix = [IO.Path]::GetFullPath($root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (-not $scopeFull.StartsWith($scopePrefix, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $scopeFull -PathType Leaf)) { throw 'ProjectScopeRef must point to an existing workspace scope reference.' }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $requestRoot "$RequestId.json" }
$fullOutput = [IO.Path]::GetFullPath($OutputPath)
if (-not $fullOutput.StartsWith($requestRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputPath must remain under source-requests.' }
if (Test-Path -LiteralPath $fullOutput) { throw "Source request already exists: $RequestId" }
$request = [ordered]@{ request_id = $RequestId; task_id = $TaskId; source_id = $SourceId; service_id = $ServiceId; repository_id = $RepositoryId; project_scope_ref = $ProjectScopeRef; purpose = $Purpose; selected_fields = @($selectedFields); data_time_range = $DataTimeRange; access_mode = 'read_only'; query_bound = 'selected_fields_and_time_range'; network_access = $false; business_write = $false; raw_credentials = $false; raw_rows_in_request = $false; created_at = (Get-Date).ToUniversalTime().ToString('o') }
New-Item -ItemType Directory -Path (Split-Path -Parent $fullOutput) -Force | Out-Null
[IO.File]::WriteAllText($fullOutput, ($request | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
if ($PassThru) { $request | ConvertTo-Json -Depth 8 } else { Write-Host "Qianlima source request created: $fullOutput" }
