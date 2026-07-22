<# Discover-only Gemini CLI adapter. It becomes executable only after command-contract approval. #>
param(
  [Parameter(Mandatory = $true)] [string]$GrantPath,
  [Parameter(Mandatory = $true)] [ValidatePattern('^[A-Za-z0-9._-]{3,100}$')] [string]$TaskId,
  [Parameter(Mandatory = $true)] [string]$Prompt,
  [switch]$PassThru
)
& (Join-Path $PSScriptRoot 'invoke-governed-cli.ps1') -AdapterId gemini_cli_worker -GrantPath $GrantPath -TaskId $TaskId -Prompt $Prompt -PassThru:$PassThru
exit $LASTEXITCODE
