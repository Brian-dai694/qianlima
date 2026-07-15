<#
.SYNOPSIS
Chinese-named launcher that starts the Qianlima workspace.
.DESCRIPTION
Thin wrapper around start-qianlima.ps1 located in the same directory.
Resolves the sibling script path from $PSScriptRoot and invokes it in a
fresh powershell process with -NoProfile and -ExecutionPolicy Bypass so
startup runs consistently regardless of the caller's shell settings.
.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File .\启动千里马计划.ps1
#>
$ErrorActionPreference = 'Stop'

$Script = Join-Path $PSScriptRoot 'start-qianlima.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $Script
