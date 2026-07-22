<##
.SYNOPSIS
  Regression tests for beginner organization and personnel setup.
##>
param([switch]$PassThru)
$ErrorActionPreference = 'Stop'
$wizard = Join-Path $PSScriptRoot 'new-enterprise-organization.ps1'
$roles = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'organization-role-templates.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = [System.Collections.Generic.List[object]]::new()
function Add-Case([string]$Name, [bool]$Passed) { $cases.Add([PSCustomObject]@{ name = $Name; passed = $Passed }) }
$draft = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wizard -CompanyName Demo -OwnerId boss1 -OwnerName Boss -Departments 'Operations,Product' -NoWrite -PassThru | ConvertFrom-Json
Add-Case 'simple_draft_without_security_admin' ($draft.setup_status -eq 'draft_needs_security_admin' -and $draft.departments.Count -eq 2)
$ready = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wizard -CompanyName Demo -OwnerId boss1 -OwnerName Boss -Departments 'Operations,Product' -SecurityAdminId sec1 -SecurityAdminName Admin -NoWrite -PassThru | ConvertFrom-Json
Add-Case 'distinct_security_admin_ready' ($ready.setup_status -eq 'ready_for_employee_import' -and $ready.members.Count -eq 2)
Add-Case 'employee_defaults_department_scoped' ($ready.defaults.new_employee_role -eq 'employee' -and $ready.defaults.cross_department -eq 'deny')
$owner = @($roles.roles | Where-Object { $_.id -eq 'business_owner' }) | Select-Object -First 1
$security = @($roles.roles | Where-Object { $_.id -eq 'security_admin' }) | Select-Object -First 1
Add-Case 'owner_not_platform_admin' ($owner.platform_admin -eq $false -and $owner.may_approve_own_L4 -eq $false)
Add-Case 'security_admin_not_business_approver' ($security.platform_admin -eq $true -and $security.may_approve_business_L4 -eq $false)
$failed = @($cases | Where-Object { -not $_.passed }); $result = [PSCustomObject]@{ passed = ($failed.Count -eq 0); cases = @($cases); files_written = $false; execution_authorized = $false }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $cases | Format-Table -AutoSize }
if ($failed.Count -gt 0) { throw "Enterprise organization regression failed: $($failed.name -join ', ')" }
