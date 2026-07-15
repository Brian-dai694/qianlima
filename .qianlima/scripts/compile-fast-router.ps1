<#
.SYNOPSIS
  Compile natural-language-router.yaml into a compact codex-router.json index.
.DESCRIPTION
  Parses .qianlima/natural-language-router.yaml line by line, extracting each route's
  id, intent, strong signals, skill, workflow, tools, and risk. Builds a trigger map
  from signals to route ids and writes a versioned codex-router.json. Throws if the
  source YAML is missing or no routes are compiled.
.PARAMETER Root
  Path to the .qianlima root holding the router YAML. Defaults to the script's parent.
.EXAMPLE
  powershell -NoProfile -File .\compile-fast-router.ps1
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $Root 'natural-language-router.yaml'
$outputPath = Join-Path $Root 'codex-router.json'

if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
  throw "Missing natural language router: $sourcePath"
}

function ConvertTo-StringList([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return @()
  }
  return @($Value -split ',' | ForEach-Object {
    $_.Trim().Trim('"').Trim("'")
  } | Where-Object { $_ })
}

$routes = New-Object System.Collections.Generic.List[object]
$current = $null
$inUseBlock = $false

foreach ($line in (Get-Content -LiteralPath $sourcePath -Encoding UTF8)) {
  if ($line -match '^    - route_id:\s*(\S+)\s*$') {
    if ($null -ne $current) {
      $routes.Add([PSCustomObject]$current)
    }
    $current = [ordered]@{
      route_id = $Matches[1].Trim('"').Trim("'")
      intent = ''
      strong_signals = @()
      skill = $null
      workflow = $null
      tools = @()
      risk = 'unknown'
    }
    $inUseBlock = $false
    continue
  }

  if ($null -eq $current) {
    continue
  }
  if ($line -match '^      intent:\s*(.+?)\s*$') {
    $current.intent = $Matches[1].Trim().Trim('"').Trim("'")
    continue
  }
  if ($line -match '^      strong_signals:\s*\[(.*)\]\s*$') {
    $current.strong_signals = ConvertTo-StringList $Matches[1]
    continue
  }
  if ($line -match '^      risk:\s*(\S+)\s*$') {
    $current.risk = $Matches[1].Trim('"').Trim("'")
    continue
  }
  if ($line -match '^      use:\s*$') {
    $inUseBlock = $true
    continue
  }
  if ($inUseBlock -and $line -match '^        skill:\s*(\S+)\s*$') {
    $current.skill = $Matches[1].Trim('"').Trim("'")
    continue
  }
  if ($inUseBlock -and $line -match '^        workflow:\s*(\S+)\s*$') {
    $current.workflow = $Matches[1].Trim('"').Trim("'")
    continue
  }
  if ($inUseBlock -and $line -match '^        tools:\s*\[(.*)\]\s*$') {
    $current.tools = ConvertTo-StringList $Matches[1]
    continue
  }
  if ($line -match '^      [A-Za-z_][A-Za-z_ ]*:\s*') {
    $inUseBlock = $false
  }
}

if ($null -ne $current) {
  $routes.Add([PSCustomObject]$current)
}

if ($routes.Count -eq 0) {
  throw 'No routes were compiled from natural-language-router.yaml'
}

$triggerMap = [ordered]@{}
foreach ($route in $routes) {
  foreach ($signal in $route.strong_signals) {
    if (-not $triggerMap.Contains($signal)) {
      $triggerMap[$signal] = @()
    }
    $triggerMap[$signal] += $route.route_id
  }
}

$compiledRoutes = @($routes.ToArray())
$compiledTriggerMap = [PSCustomObject]$triggerMap

[PSCustomObject]@{
  schema_version = 1
  generated_at = (Get-Date).ToString('o')
  source = '.qianlima/natural-language-router.yaml'
  routing_note = 'Use this compact index for low-risk direct routing. Read the source YAML for ambiguous, cross-domain, or high-risk tasks.'
  routes = $compiledRoutes
  trigger_map = $compiledTriggerMap
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outputPath -Encoding UTF8

Write-Host "Fast router generated: $outputPath ($($routes.Count) routes)"
