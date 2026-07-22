<##
.SYNOPSIS
  Runs the personal Skill scan and installs only into a restricted local root.
.DESCRIPTION
  Low risk may install with -Install. Medium risk requires -Confirm. High risk
  is refused. This script never executes the Skill or grants permanent access.
##>
param(
  [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$SkillPath,
  [switch]$Install,
  [switch]$Confirm,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scanner = Join-Path $PSScriptRoot 'scan-personal-skill.ps1'
$policyPath = Join-Path $projectRoot '.qianlima\specifications\personal-skill-install-policy.json'
$scanText = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scanner -SkillPath $SkillPath -PolicyPath $policyPath -PassThru 2>&1)
$scanCode = $LASTEXITCODE
$scan = (($scanText -join "`n") | ConvertFrom-Json)
if ($scanCode -ne 0) { throw 'Skill static scan failed.' }
$result = [ordered]@{ status = $scan.verdict; risk_band = $scan.risk_band; findings = @($scan.findings); installed = $false; execution_performed = $false; network_calls = $false; personal_memory_written = $false; install_root = $null }
if ($scan.risk_band -eq 'high') { $result.status = 'high_risk_not_recommended'; if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }; exit 2 }
if (-not $Install) { if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }; exit 0 }
if ($scan.risk_band -eq 'medium' -and -not $Confirm) { $result.status = 'risk_needs_confirmation'; if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }; exit 3 }
$skillName = Split-Path -Leaf ([IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SkillPath).Path))
if ($skillName -notmatch '^[A-Za-z0-9._-]{1,80}$') { throw 'Skill directory name must be file-safe.' }
$installRoot = Join-Path $projectRoot '.qianlima\working\restricted-skills'
$destination = Join-Path $installRoot $skillName
if (Test-Path -LiteralPath $destination) { throw 'Restricted Skill destination already exists; installation is immutable.' }
New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
Copy-Item -LiteralPath ([IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SkillPath).Path)) -Destination $destination -Recurse -Force
$result.status = 'installed_restricted'
$result.installed = $true
$result.install_root = $destination
if ($PassThru) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
