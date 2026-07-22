<##
.SYNOPSIS
  Beginner-friendly Qianlima Enterprise organization setup wizard.
.DESCRIPTION
  Creates a private local organization profile. It never overwrites an
  existing profile and never grants Agent execution authority.
##>
param(
  [string]$CompanyName = '',
  [string]$OwnerId = '',
  [string]$OwnerName = '',
  [string]$Departments = '',
  [string]$SecurityAdminId = '',
  [string]$SecurityAdminName = '',
  [string]$OutputPath = '',
  [switch]$NoWrite,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$enterpriseRoot = $PSScriptRoot
$projectRoot = (Resolve-Path (Join-Path $enterpriseRoot '..')).Path
$text = Get-Content -LiteralPath (Join-Path $enterpriseRoot 'onboarding-text.zh-CN.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($CompanyName)) { $CompanyName = Read-Host $text.prompts.company_name }
if ([string]::IsNullOrWhiteSpace($OwnerName)) { $OwnerName = Read-Host $text.prompts.owner_name }
if ([string]::IsNullOrWhiteSpace($OwnerId)) { $OwnerId = Read-Host $text.prompts.owner_id }
if ([string]::IsNullOrWhiteSpace($Departments)) { $Departments = Read-Host $text.prompts.departments }
if ([string]::IsNullOrWhiteSpace($CompanyName) -or [string]::IsNullOrWhiteSpace($OwnerId) -or [string]::IsNullOrWhiteSpace($OwnerName)) { throw $text.errors.required_owner_fields }

$departmentNames = @(($Departments -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
if ($departmentNames.Count -eq 0) { throw $text.errors.department_required }
if (-not [string]::IsNullOrWhiteSpace($SecurityAdminId) -and $SecurityAdminId -eq $OwnerId) { throw $text.errors.security_admin_must_differ }

$organizationId = 'org-' + ([regex]::Replace($CompanyName.ToLowerInvariant(), '[^a-z0-9]+', '-')).Trim('-')
if ($organizationId -eq 'org-') { $organizationId = 'org-' + [Guid]::NewGuid().ToString('n').Substring(0, 8) }
$members = [System.Collections.Generic.List[object]]::new()
$members.Add([PSCustomObject]@{ employee_id = $OwnerId; display_name = $OwnerName; role = 'business_owner'; departments = @(); enabled = $true })
if (-not [string]::IsNullOrWhiteSpace($SecurityAdminId)) {
  $members.Add([PSCustomObject]@{ employee_id = $SecurityAdminId; display_name = $SecurityAdminName; role = 'security_admin'; departments = @(); enabled = $true })
}
$profile = [ordered]@{
  schema_version = 1
  organization_id = $organizationId
  company_name = $CompanyName
  setup_status = if ([string]::IsNullOrWhiteSpace($SecurityAdminId)) { 'draft_needs_security_admin' } else { 'ready_for_employee_import' }
  departments = @($departmentNames | ForEach-Object { [ordered]@{ department_id = 'dept-' + ([Guid]::NewGuid().ToString('n').Substring(0, 8)); display_name = $_; enabled = $true } })
  members = @($members)
  defaults = [ordered]@{ new_employee_role = 'employee'; employee_scope = 'own_department_and_assigned_projects'; cross_department = 'deny'; execution_authorized = $false }
  next_steps = if ([string]::IsNullOrWhiteSpace($SecurityAdminId)) { @($text.next_steps.draft) } else { @($text.next_steps.ready) }
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}

if (-not $NoWrite) {
  if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $projectRoot '.qianlima\local-data\enterprise\organization.json' }
  $fullOutput = [IO.Path]::GetFullPath($OutputPath)
  $allowedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\local-data\enterprise')).TrimEnd('\') + '\'
  if (-not $fullOutput.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw $text.errors.output_scope }
  if (Test-Path -LiteralPath $fullOutput) { throw $text.errors.no_overwrite }
  New-Item -ItemType Directory -Path (Split-Path -Parent $fullOutput) -Force | Out-Null
  [IO.File]::WriteAllText($fullOutput, ($profile | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
}
if ($PassThru -or $NoWrite) { $profile | ConvertTo-Json -Depth 10 } else { Write-Host ($text.messages.created -f $OutputPath); Write-Host ($text.messages.status -f $profile.setup_status) }
