param(
  [Parameter(Mandatory = $true)] [string]$PlanPath,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workingRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\working')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$tmpRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.qianlima\tmp')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$planFullPath = (Resolve-Path -LiteralPath $PlanPath -ErrorAction Stop).Path
if (-not $planFullPath.StartsWith($workingRoot, [StringComparison]::OrdinalIgnoreCase) -and -not $planFullPath.StartsWith($tmpRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Personal learning plans must stay under .qianlima/working or .qianlima/tmp.' }
$policyPath = Join-Path $projectRoot '.qianlima\specifications\personal-learning-pipeline.json'
$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
$plan = Get-Content -LiteralPath $planFullPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Get-Field($Object, [string]$Name) {
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}
function Require-Field($Object, [string]$Name) {
  $value = Get-Field $Object $Name
  if ($null -eq $value -or ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) { throw "Personal learning plan is missing required field: $Name" }
  return $value
}
function Assert-NoForbiddenProperty($Object) {
  if ($null -eq $Object -or $Object -is [string] -or $Object.GetType().IsValueType) { return }
  if ($Object -is [System.Collections.IEnumerable]) { foreach ($item in $Object) { Assert-NoForbiddenProperty $item }; return }
  foreach ($property in $Object.PSObject.Properties) {
    if ($property.Name -match '^(url|endpoint|remote_endpoint|port|host|network_dispatch|ssh|slurm|scnet|credential|secret)$') { throw "Learning plan contains forbidden transport or credential field: $($property.Name)" }
    Assert-NoForbiddenProperty $property.Value
  }
}

foreach ($field in @($policy.required_plan_fields)) { [void](Require-Field $plan ([string]$field)) }
Assert-NoForbiddenProperty $plan
$mode = [string](Get-Field $plan 'delivery_mode')
if ($mode -notin @('summary_only', 'proposal_only', 'readonly_evidence')) { throw 'Personal learning plan has an unsupported delivery_mode.' }
if ((Get-Field $plan 'auto_start') -ne $false -or (Get-Field $plan 'background_task') -ne $false) { throw 'Personal learning plans cannot auto-start or create background tasks.' }
if ((Get-Field $plan 'network_access') -ne 'none' -or (Get-Field $plan 'write_access') -ne 'none' -or (Get-Field $plan 'can_delegate') -ne $false) { throw 'Personal learning plans must be offline, read-only, and non-delegating.' }
$expectedStages = @($policy.stage_sequence | ForEach-Object { $_.id })
$actualStages = @((Get-Field $plan 'stage_sequence') | ForEach-Object { if ($_ -is [string]) { $_ } else { Get-Field $_ 'id' } })
if (($actualStages -join '|') -ne ($expectedStages -join '|')) { throw 'Personal learning stages must be resource_summary -> local_plan -> readonly_execute -> verify_and_converge.' }
$proposedTools = @((Get-Field $plan 'proposed_tools'))
foreach ($tool in $proposedTools) { if (@($policy.allowed_proposal_tools) -notcontains [string]$tool) { throw "Tool is outside the personal learning proposal boundary: $tool" } }
if ($mode -eq 'readonly_evidence' -and ((Get-Field $plan 'explicit_start') -ne $true -or (Get-Field $plan 'grant_required') -ne $true -or $proposedTools.Count -ne 1 -or $proposedTools[0] -ne 'qianlima_readonly_evidence_task')) { throw 'Readonly evidence mode requires explicit_start, grant_required, and the only approved tool.' }
if ($mode -ne 'readonly_evidence' -and ((Get-Field $plan 'explicit_start') -eq $true -or (Get-Field $plan 'grant_required') -eq $true)) { throw 'Summary and proposal modes cannot claim execution authority.' }
$result = [ordered]@{ schema_version = 1; status = 'allowed'; plan_id = 'personal-plan-' + [Guid]::NewGuid().ToString('n'); task_id = Get-Field $plan 'task_id'; delivery_mode = $mode; stages = $actualStages; proposed_tools = $proposedTools; auto_start = $false; background_task = $false; network_access = 'none'; write_access = 'none'; can_delegate = $false; execution_authority = if ($mode -eq 'readonly_evidence') { 'matching_grant_only' } else { 'proposal_only' }; checked_at = (Get-Date).ToUniversalTime().ToString('o') }
if ($PassThru) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List }
