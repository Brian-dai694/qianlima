<# Qianlima-governed Raven worker adapter. #>
param(
  [Parameter(Mandatory = $true)] [string]$GrantPath,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [string]$Prompt,
  [string]$AttestationPath = '',
  [ValidateSet('Plan', 'Execute')] [string]$Mode = 'Plan',
  [switch]$Start,
  [switch]$Execute,
  [switch]$SandboxReady,
  [switch]$PassThru
)
& (Join-Path $PSScriptRoot 'invoke-governed-cli.ps1') -AdapterId raven_worker -GrantPath $GrantPath -TaskId $TaskId -Prompt $Prompt -AttestationPath $AttestationPath -Mode $Mode -Start:$Start -Execute:$Execute -SandboxReady:$SandboxReady -PassThru:$PassThru
exit $LASTEXITCODE
