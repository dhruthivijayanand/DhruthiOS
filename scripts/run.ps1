param([string]$QemuDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/tools.ps1"
$QemuDir = Resolve-QemuDirectory $QemuDir
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    $qemu = Join-Path $QemuDir 'qemu-system-x86_64.exe'
    $firmware = Join-Path $QemuDir 'share/edk2-x86_64-code.fd'
    foreach ($required in @($qemu, $firmware, 'build/esp/kernel.elf', 'build/esp/EFI/BOOT/BOOTX64.EFI', 'build/esp/limine.conf')) {
        if (!(Test-Path -LiteralPath $required)) { throw "Missing file: $required. Build the kernel first." }
    }
    Write-Output 'Starting DhruthiOS. To quit: press Ctrl+A, release, then press X.'
    & $qemu -machine pc -accel tcg -m 128M -smp 1 -drive "if=pflash,format=raw,readonly=on,file=$firmware" -drive 'format=raw,snapshot=on,file=fat:build/esp' -display none -serial mon:stdio -net none -no-reboot
    if ($LASTEXITCODE -ne 0) { throw "QEMU exited with code $LASTEXITCODE" }
} finally { Pop-Location }
