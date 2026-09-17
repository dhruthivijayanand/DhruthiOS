param(
    [string]$LlvmBin = 'D:\Program Files\LLVM\bin',
    [ValidateSet('normal', 'ud2')][string]$Mode = 'normal'
)
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
    $outputDir = if ($Mode -eq 'normal') { 'build' } else { 'build/ud2' }
    New-Item -ItemType Directory -Force "$outputDir/esp/EFI/BOOT" | Out-Null
    $flags = @('--target=x86_64-unknown-none-elf', '-std=c11', '-ffreestanding',
        '-fno-stack-protector', '-fno-pic', '-fno-pie', '-mno-red-zone',
        '-mgeneral-regs-only', '-mcmodel=kernel', '-fno-unwind-tables',
        '-fno-asynchronous-unwind-tables', '-Wall', '-Wextra', '-Werror', '-O2', '-g', '-Iinclude')
    if ($Mode -eq 'ud2') { $flags += '-DDHRUTHIOS_TEST_UD2=1' }
    & $clang @flags -c src/kernel/main.c -o "$outputDir/main.o"
    if ($LASTEXITCODE -ne 0) { throw "Kernel compilation failed: $LASTEXITCODE" }
    & $clang @flags -c src/arch/x86_64/exceptions.c -o "$outputDir/exceptions.o"
    if ($LASTEXITCODE -ne 0) { throw "IDT compilation failed: $LASTEXITCODE" }
    & $clang --target=x86_64-unknown-none-elf -g -c src/arch/x86_64/exceptions.S -o "$outputDir/exception-entry.o"
    if ($LASTEXITCODE -ne 0) { throw "Assembly failed: $LASTEXITCODE" }
    & $linker -nostdlib -static -z max-page-size=0x1000 -T config/kernel.ld -o "$outputDir/kernel.elf" "$outputDir/main.o" "$outputDir/exceptions.o" "$outputDir/exception-entry.o"
    if ($LASTEXITCODE -ne 0) { throw "Linking failed: $LASTEXITCODE" }
    Copy-Item -LiteralPath "$outputDir/kernel.elf" -Destination "$outputDir/esp/kernel.elf"
    Copy-Item -LiteralPath config/limine.conf -Destination "$outputDir/esp/limine.conf"
    Copy-Item -LiteralPath vendor/limine/BOOTX64.EFI -Destination "$outputDir/esp/EFI/BOOT/BOOTX64.EFI"
    Write-Output "BUILD OK ($Mode): $outputDir/kernel.elf and $outputDir/esp"
} finally { Pop-Location }
