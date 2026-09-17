param(
    [string]$LlvmBin = 'D:\Program Files\LLVM\bin',
    [string]$QemuDir = 'C:\Program Files\qemu',
    [ValidateRange(1, 3)][int]$Runs = 2
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & "$PSScriptRoot/build.ps1" -LlvmBin $LlvmBin -Mode ud2
    $qemu = Join-Path $QemuDir 'qemu-system-x86_64.exe'
    $firmware = Join-Path $QemuDir 'share/edk2-x86_64-code.fd'
    $nm = Join-Path $LlvmBin 'llvm-nm.exe'
    foreach ($required in @($qemu, $firmware, $nm)) {
        if (!(Test-Path -LiteralPath $required)) { throw "Missing file: $required" }
    }
    $symbols = & $nm --defined-only build/ud2/kernel.elf
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the test executable.' }
    $symbol = @($symbols | Where-Object { $_ -match '^([0-9a-fA-F]{16})\s+T\s+exception_test_ud$' })
    if ($symbol.Count -ne 1) { throw 'Expected exactly one UD2 test entry symbol.' }
    $expectedRip = ($symbol[0] -split '\s+')[0].ToLowerInvariant()
    $logDir = 'build/ud2/test-' + [guid]::NewGuid().ToString('N')
    New-Item -ItemType Directory -Path $logDir | Out-Null
    for ($run = 1; $run -le $Runs; $run++) {
        $ram = if ($run -eq 2) { '256M' } else { '128M' }
        $serialLog = "$logDir/serial-$run.log"
        $cpuLog = "$logDir/cpu-$run.log"
        $start = [System.Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $qemu
        $start.WorkingDirectory = (Get-Location).Path
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardError = $true
        $start.Arguments = "-machine pc -accel tcg -m $ram -smp 1 -drive `"if=pflash,format=raw,readonly=on,file=$firmware`" -drive format=raw,snapshot=on,file=fat:build/ud2/esp -display none -serial file:$serialLog -monitor none -net none -no-reboot -d int -D $cpuLog"
        $process = [System.Diagnostics.Process]::Start($start)
        $errorRead = $process.StandardError.ReadToEndAsync()
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $observed = $false
        try {
            while ($timer.Elapsed.TotalSeconds -lt 30 -and !$process.HasExited) {
                if (Test-Path -LiteralPath $serialLog) {
                    $text = Get-Content -LiteralPath $serialLog -Raw
                    if ($text -and $text.Contains('DhruthiOS: exception handler reached; halting')) {
                        Start-Sleep -Milliseconds 300
                        $observed = !$process.HasExited
                        break
                    }
                }
                Start-Sleep -Milliseconds 250
            }
        } finally {
            if (!$process.HasExited) { $process.Kill(); $process.WaitForExit() }
            $stderr = $errorRead.GetAwaiter().GetResult()
            $process.Dispose()
        }
        if (!$observed -or $stderr) { throw "Exception test failed or timed out. Logs: $logDir. QEMU: $stderr" }
        $text = Get-Content -LiteralPath $serialLog -Raw
        $markers = @('DhruthiOS: kernel entered', 'DhruthiOS: IDT loaded',
            'TEST: triggering UD2', 'PANIC: #UD invalid opcode (vector 6)',
            "RIP: 0x$expectedRip", 'DhruthiOS: exception handler reached; halting')
        $position = -1
        foreach ($marker in $markers) {
            $found = $text.IndexOf($marker, $position + 1, [StringComparison]::Ordinal)
            if ($found -lt 0) { throw "Missing/out-of-order marker '$marker'. Log: $serialLog" }
            $position = $found
        }
        if ($text -match 'FAIL:|unsupported|PANIC: unhandled|boot protocol accepted; CPU halted') {
            throw "Unexpected execution path. Log: $serialLog"
        }
        $cpu = Get-Content -LiteralPath $cpuLog -Raw
        if ($cpu -notmatch "v=06[^\r\n]*IP=[0-9a-fA-F]+:$expectedRip" -or $cpu -match 'Triple fault') {
            throw "QEMU trace did not confirm #UD at the expected instruction. Log: $cpuLog"
        }
        Write-Output "PASS: #UD caught, fault address verified, RAM $ram; QEMU closed."
        Write-Output "  Logs: $serialLog and $cpuLog"
    }
    Write-Output 'Exception test complete. Normal boot files were not replaced.'
} finally { Pop-Location }
