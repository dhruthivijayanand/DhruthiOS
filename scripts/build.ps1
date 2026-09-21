param(
    [string]$LlvmBin,
    [ValidateSet('normal', 'ud2', 'timer', 'timer-masked')][string]$Mode = 'normal'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/tools.ps1"
$LlvmBin = Resolve-LlvmDirectory $LlvmBin
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    $clang = Join-Path $LlvmBin 'clang.exe'
    $linker = Join-Path $LlvmBin 'ld.lld.exe'
    $nm = Join-Path $LlvmBin 'llvm-nm.exe'
    foreach ($required in @($clang, $linker, $nm, 'vendor/limine/BOOTX64.EFI')) {
        if (!(Test-Path -LiteralPath $required)) { throw "Missing required file: $required" }
    }
    $expectedHash = 'D257ADD3B8CA480470C50BA5E55899702F19B10D9B29DC8D4A5DB97FC4FB8B19'
    if ((Get-FileHash vendor/limine/BOOTX64.EFI -Algorithm SHA256).Hash -ne $expectedHash) {
        throw 'The bootloader differs from the recorded dependency.'
    }
    $outputDir = if ($Mode -eq 'normal') { 'build' } else { "build/$Mode" }
    New-Item -ItemType Directory -Force "$outputDir/esp/EFI/BOOT" | Out-Null
    $flags = @('--target=x86_64-unknown-none-elf', '-std=c11', '-ffreestanding',
        '-fno-stack-protector', '-fno-pic', '-fno-pie', '-mno-red-zone',
        '-mgeneral-regs-only', '-mcmodel=kernel', '-fno-unwind-tables',
        '-fno-asynchronous-unwind-tables', '-Wall', '-Wextra', '-Werror', '-O2', '-g', '-Iinclude')
    if ($Mode -eq 'ud2') { $flags += '-DDHRUTHIOS_TEST_UD2=1' }
    if ($Mode -like 'timer*') { $flags += '-DDHRUTHIOS_TEST_TIMER=1' }
    if ($Mode -eq 'timer-masked') { $flags += '-DDHRUTHIOS_TIMER_MASKED=1' }
    if ($Mode -ne 'normal') { $flags += '-Itests/kernel' }
    $sources = @(
        @{ Path = 'src/kernel/main.c'; Object = 'main.o' },
        @{ Path = 'src/drivers/serial.c'; Object = 'serial.o' },
        @{ Path = 'src/arch/x86_64/exceptions.c'; Object = 'exceptions.o' },
        @{ Path = 'src/arch/x86_64/exceptions.S'; Object = 'exception-entry.o' },
        @{ Path = 'src/arch/x86_64/timer.c'; Object = 'timer.o' },
        @{ Path = 'src/arch/x86_64/timer.S'; Object = 'timer-entry.o' }
    )
    if ($Mode -eq 'ud2') { $sources += @{ Path = 'tests/kernel/ud2.S'; Object = 'ud2-test.o' } }
    if ($Mode -like 'timer*') { $sources += @{ Path = 'tests/kernel/timer-probe.S'; Object = 'timer-probe.o' } }
    $objects = @()
    foreach ($source in $sources) {
        $object = "$outputDir/$($source.Object)"
        $compileFlags = if ($source.Path.EndsWith('.S')) { @('--target=x86_64-unknown-none-elf', '-g') } else { $flags }
        & $clang @compileFlags -c $source.Path -o $object
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $($source.Path) (exit $LASTEXITCODE)" }
        $objects += $object
    }
    & $linker -nostdlib -static -z max-page-size=0x1000 -T config/kernel.ld -o "$outputDir/kernel.elf" @objects
    if ($LASTEXITCODE -ne 0) { throw "Linking failed: $LASTEXITCODE" }
    $undefined = & $nm --undefined-only "$outputDir/kernel.elf"
    if ($LASTEXITCODE -ne 0 -or $undefined) { throw "ELF symbol validation failed: $undefined" }
    Copy-Item -LiteralPath "$outputDir/kernel.elf" -Destination "$outputDir/esp/kernel.elf"
    Copy-Item -LiteralPath config/limine.conf -Destination "$outputDir/esp/limine.conf"
    Copy-Item -LiteralPath vendor/limine/BOOTX64.EFI -Destination "$outputDir/esp/EFI/BOOT/BOOTX64.EFI"
    Write-Output "BUILD OK ($Mode): $outputDir/kernel.elf and $outputDir/esp"
} finally { Pop-Location }
