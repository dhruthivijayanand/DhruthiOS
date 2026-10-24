param([string]$QemuDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/tools.ps1"
$QemuDir = Resolve-QemuDirectory $QemuDir
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    $qemu = Join-Path $QemuDir 'qemu-system-x86_64.exe'
    $firmware = Join-Path $QemuDir 'share/edk2-x86_64-code.fd'
    foreach ($required in @($qemu, $firmware, 'build/echo/esp/kernel.elf',
            'build/echo/esp/EFI/BOOT/BOOTX64.EFI', 'build/echo/esp/limine.conf')) {
        if (!(Test-Path -LiteralPath $required)) { throw "Missing file: $required. Build with -Mode echo first." }
    }
    Write-Output 'In QEMU press Ctrl+Alt+2 for the serial console. Close its window to exit.'
    & $qemu -machine pc -accel tcg -m 128M -smp 1 -drive "if=pflash,format=raw,readonly=on,file=$firmware" -drive 'format=raw,snapshot=on,file=fat:build/echo/esp' -display sdl -serial vc -monitor none -net none -no-reboot
    if ($LASTEXITCODE -ne 0) { throw "QEMU exited with code $LASTEXITCODE" }
} finally { Pop-Location }