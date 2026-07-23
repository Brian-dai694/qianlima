param(
  [Parameter(Mandatory = $true)]
  [string]$Reason,
  [string]$Phase = '',
  [ValidateSet('transient', 'task', 'verifier', 'needs_human')]
  [string]$Category = '',
  [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
$rules = Join-Path $PSScriptRoot '..\failure-policy.yaml'
if ([string]::IsNullOrWhiteSpace($Category)) {
  $lower = $Reason.ToLowerInvariant()
  if ($lower -match 'confirm|authoriz|permission|protected|risk|external write|write_back|conflict') { $Category = 'needs_human' }
  elseif ($lower -match 'verify|evidence|artifact|quality|validation') { $Category = 'verifier' }
  elseif ($lower -match 'input|parameter|unsupported|missing') { $Category = 'task' }
  else { $Category = 'transient' }
}
$retry = switch ($Category) { 'transient' { $true }; 'verifier' { 'limited' }; default { $false } }
$requiresHuman = $Category -eq 'needs_human'
$result = [PSCustomObject]@{
  category = $Category
  reason = $Reason
  phase = $Phase
  retry_allowed = $retry
  max_retries = if ($Category -eq 'transient') { 2 } elseif ($Category -eq 'verifier') { 1 } else { 0 }
  requires_human = $requiresHuman
  policy = '.qianlima/failure-policy.yaml'
}
if ($AsJson) { $result | ConvertTo-Json -Depth 5 } else { Write-Host ("Failure category: {0}; retry={1}; human={2}" -f $result.category, $result.retry_allowed, $result.requires_human) }
