param([string]$LlvmBin, [string]$QemuDir)
$ErrorActionPreference = 'Stop'
& "$PSScriptRoot/build.ps1" -LlvmBin $LlvmBin -Mode monitor
& "$PSScriptRoot/run-echo.ps1" -QemuDir $QemuDir -Mode monitor