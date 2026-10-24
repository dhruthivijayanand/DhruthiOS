param([string]$LlvmBin, [string]$QemuDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/tools.ps1"
$LlvmBin = Resolve-LlvmDirectory $LlvmBin
$QemuDir = Resolve-QemuDirectory $QemuDir

& "$PSScriptRoot/build.ps1" -LlvmBin $LlvmBin
& "$PSScriptRoot/test-boot.ps1" -QemuDir $QemuDir
& "$PSScriptRoot/test-exception.ps1" -LlvmBin $LlvmBin -QemuDir $QemuDir
& "$PSScriptRoot/test-timer.ps1" -LlvmBin $LlvmBin -QemuDir $QemuDir
& "$PSScriptRoot/test-commands.ps1" -LlvmBin $LlvmBin -QemuDir $QemuDir
& "$PSScriptRoot/test-echo.ps1" -LlvmBin $LlvmBin -QemuDir $QemuDir
& "$PSScriptRoot/test-memmap.ps1" -LlvmBin $LlvmBin -QemuDir $QemuDir
& "$PSScriptRoot/test-pmm.ps1" -LlvmBin $LlvmBin -QemuDir $QemuDir
& "$PSScriptRoot/test-directmap.ps1" -LlvmBin $LlvmBin -QemuDir $QemuDir
Write-Output 'PASS: all 19 QEMU runs completed (8 regression, 2 command, 2 serial, 3 memory-map, 2 allocator, 2 direct-map).'
