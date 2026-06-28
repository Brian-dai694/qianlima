$ErrorActionPreference = 'Stop'

$Script = Join-Path $PSScriptRoot 'start-qianlima.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $Script

