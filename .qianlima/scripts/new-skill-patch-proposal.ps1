<#
.SYNOPSIS
    Creates a candidate-only skill patch proposal markdown file.
.DESCRIPTION
    Records a proposed change to a skill's routing, instruction, or resource
    layer as a timestamped document under feedback/skill-evolution. Captures
    the problem, proposed change, evidence paths, a success metric, and a
    rollback plan. The proposal is candidate_only and applies no change.
.PARAMETER SkillId
    Identifier of the skill being patched; sanitized for use in the file name.
.PARAMETER TargetLayer
    Layer to change: routing, instruction, or resource.
.PARAMETER ProposedChange
    Description of the concrete change being proposed.
.PARAMETER SuccessMetric
    Metric used to validate the candidate against the current version.
.EXAMPLE
    ./new-skill-patch-proposal.ps1 -SkillId keyword-diag -TargetLayer instruction -TargetFile skill.md -ProblemStatement "misroutes" -ProposedChange "add signal" -SuccessMetric "route accuracy +5%"
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$SkillId,
  [Parameter(Mandatory = $true)]
  [ValidateSet('routing', 'instruction', 'resource')]
  [string]$TargetLayer,
  [Parameter(Mandatory = $true)]
  [string]$TargetFile,
  [Parameter(Mandatory = $true)]
  [string]$ProblemStatement,
  [Parameter(Mandatory = $true)]
  [string]$ProposedChange,
  [Parameter(Mandatory = $true)]
  [string]$SuccessMetric,
  [string]$RollbackPlan = 'Restore the prior skill version and keep this proposal as rejected evidence.',
  [string[]]$EvidencePath = @(),
  [string]$Root = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
$safeId = $SkillId -replace '[^A-Za-z0-9_.-]', '-'
$dir = Join-Path $Root 'feedback\skill-evolution'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$path = Join-Path $dir "$(Get-Date -Format 'yyyy-MM-dd-HHmmss')-$safeId-proposal.md"
$evidence = if ($EvidencePath.Count -gt 0) { ($EvidencePath | ForEach-Object { '- `' + $_ + '`' }) -join [Environment]::NewLine } else { '- No evidence path provided.' }

$content = @"
# Skill Patch Proposal

- Skill: $safeId
- Target layer: $TargetLayer
- Target file: $TargetFile
- Status: candidate_only

## Problem

$ProblemStatement

## Proposed Change

$ProposedChange

## Evidence

$evidence

## Validation

- Success metric: $SuccessMetric
- Compare the current version with the candidate on held-out cases.
- Reject if risk gates regress or cost rises more than 20%.

## Rollback

$RollbackPlan
"@

[IO.File]::WriteAllText($path, $content, (New-Object Text.UTF8Encoding($false)))
Write-Host "Skill patch proposal created: $path"
