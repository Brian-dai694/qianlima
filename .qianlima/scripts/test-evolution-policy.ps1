param([switch]$PassThru)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$qianlimaRoot = Join-Path $projectRoot '.qianlima'
$policyPath = Join-Path $qianlimaRoot 'evolution\policy.yaml'
$manifestPath = Join-Path $qianlimaRoot 'evolution\eval-cases\manifest.yaml'
$candidateTemplatePath = Join-Path $qianlimaRoot 'evolution\candidates\candidate-template.yaml'
$logPath = Join-Path $qianlimaRoot 'evolution\promotion-log.jsonl'
$loopPath = Join-Path $qianlimaRoot 'improvement-loop.yaml'
$runtimePath = Join-Path $qianlimaRoot 'agent-runtime-policy.yaml'
$evalPath = Join-Path $qianlimaRoot 'qianlima-eval.yaml'
$loopText = Get-Content -LiteralPath $loopPath -Raw -Encoding UTF8 -Force
$runtimeText = Get-Content -LiteralPath $runtimePath -Raw -Encoding UTF8 -Force
$evalText = Get-Content -LiteralPath $evalPath -Raw -Encoding UTF8 -Force
$logSchema = Get-Content -LiteralPath $logPath -Raw -Encoding UTF8 -Force | ConvertFrom-Json
$checks = @(
  [PSCustomObject]@{ name = 'evolution_policy_exists'; passed = Test-Path -LiteralPath $policyPath -PathType Leaf }
  [PSCustomObject]@{ name = 'four_suite_manifest_exists'; passed = Test-Path -LiteralPath $manifestPath -PathType Leaf }
  [PSCustomObject]@{ name = 'candidate_template_exists'; passed = Test-Path -LiteralPath $candidateTemplatePath -PathType Leaf }
  [PSCustomObject]@{ name = 'promotion_log_schema_exists'; passed = $logSchema.record_type -eq 'schema' -and $logSchema.required_fields -contains 'candidate_id' }
  [PSCustomObject]@{ name = 'improvement_loop_disables_auto_apply'; passed = $loopText -notmatch '(?m)^\s*auto_apply:\s*true\s*$' -and $loopText -match 'candidate_only_until_promoted:\s*true' }
  [PSCustomObject]@{ name = 'runtime_excludes_candidate_context'; passed = $runtimeText -match 'candidate directories are excluded from normal context loading' }
  [PSCustomObject]@{ name = 'promotion_requires_l4_and_latency_gates'; passed = $evalText -match 'L4_gate_is_not_weakened' -and $evalText -match 'first_useful_output_is_not_slower' }
)
$failed = @($checks | Where-Object { -not $_.passed })
$result = [PSCustomObject]@{ passed = $failed.Count -eq 0; checks = $checks }
if ($PassThru) { $result | ConvertTo-Json -Depth 4 } else { $checks | ForEach-Object { Write-Host ("{0}: {1}" -f $_.name, $(if ($_.passed) { 'passed' } else { 'FAILED' })) }; Write-Host ("Evolution policy regression: {0}" -f $(if ($result.passed) { 'passed' } else { 'FAILED' })) }
if (-not $result.passed) { exit 1 }
