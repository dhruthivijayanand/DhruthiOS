param([string]$LlvmBin = 'D:\Program Files\LLVM\bin')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    $clang = Join-Path $LlvmBin 'clang.exe'
    $linker = Join-Path $LlvmBin 'ld.lld.exe'
    foreach ($required in @($clang, $linker, 'vendor/limine/BOOTX64.EFI')) {
        if (!(Test-Path -LiteralPath $required)) { throw "Missing required file: $required" }
    }
    $expectedHash = 'D257ADD3B8CA480470C50BA5E55899702F19B10D9B29DC8D4A5DB97FC4FB8B19'
    if ((Get-FileHash vendor/limine/BOOTX64.EFI -Algorithm SHA256).Hash -ne $expectedHash) {
        throw 'The bootloader differs from the recorded dependency.'
    }
    New-Item -ItemType Directory -Force build/esp/EFI/BOOT | Out-Null
    & $clang --target=x86_64-unknown-none-elf -std=c11 -ffreestanding -fno-stack-protector -fno-pic -fno-pie -mno-red-zone -mgeneral-regs-only -mcmodel=kernel -fno-unwind-tables -fno-asynchronous-unwind-tables -Wall -Wextra -Werror -O2 -g -c src/kernel/main.c -o build/main.o
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $LASTEXITCODE" }
    & $linker -nostdlib -static -z max-page-size=0x1000 -T config/kernel.ld -o build/kernel.elf build/main.o
    if ($LASTEXITCODE -ne 0) { throw "Linking failed: $LASTEXITCODE" }
    Copy-Item -LiteralPath build/kernel.elf -Destination build/esp/kernel.elf
    Copy-Item -LiteralPath config/limine.conf -Destination build/esp/limine.conf
    Copy-Item -LiteralPath vendor/limine/BOOTX64.EFI -Destination build/esp/EFI/BOOT/BOOTX64.EFI
    Write-Output 'BUILD OK: build/kernel.elf and build/esp'
} finally { Pop-Location }
