param(
    [string]$LlvmBin,
    [string]$QemuDir
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/tools.ps1"
$QemuDir = Resolve-QemuDirectory $QemuDir
$LlvmBin = Resolve-LlvmDirectory $LlvmBin
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & "$PSScriptRoot/build.ps1" -LlvmBin $LlvmBin -Mode timer
    & "$PSScriptRoot/build.ps1" -LlvmBin $LlvmBin -Mode timer-masked
    $qemu = Join-Path $QemuDir 'qemu-system-x86_64.exe'
    $firmware = Join-Path $QemuDir 'share/edk2-x86_64-code.fd'
    foreach ($required in @($qemu, $firmware)) {
        if (!(Test-Path -LiteralPath $required)) { throw "Missing file: $required" }
    }
    $logDir = 'build/timer/test-' + [guid]::NewGuid().ToString('N')
    New-Item -ItemType Directory -Path $logDir | Out-Null
    $cases = @(
        @{ Mode = 'timer'; Ram = '128M' },
        @{ Mode = 'timer'; Ram = '256M' },
        @{ Mode = 'timer-masked'; Ram = '128M' }
    )
    $caseNumber = 0
    foreach ($case in $cases) {
        ++$caseNumber
        $mode = $case.Mode
        $ram = $case.Ram
        $negative = $mode -eq 'timer-masked'
        $serialLog = "$logDir/serial-$caseNumber.log"
        $cpuLog = "$logDir/cpu-$caseNumber.log"
        $start = [System.Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $qemu
        $start.WorkingDirectory = (Get-Location).Path
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardError = $true
        $start.Arguments = "-machine pc,hpet=off -accel tcg -m $ram -smp 1 -drive `"if=pflash,format=raw,readonly=on,file=$firmware`" -drive format=raw,snapshot=on,file=fat:build/$mode/esp -display none -serial file:$serialLog -monitor none -net none -no-reboot -d int -D $cpuLog"
        $process = [System.Diagnostics.Process]::Start($start)
        $errorRead = $process.StandardError.ReadToEndAsync()
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $readyAt = -1.0
        $observed = $false
        try {
            while ($timer.Elapsed.TotalSeconds -lt 30 -and !$process.HasExited) {
                if (Test-Path -LiteralPath $serialLog) {
                    $text = Get-Content -LiteralPath $serialLog -Raw
                    if ($text) {
                        if ($text -match 'FAIL:|PANIC:|unsupported') { break }
                        if ($readyAt -lt 0 -and $text.Contains('TEST: timer configured; waiting for IRQ0')) {
                            $readyAt = $timer.Elapsed.TotalSeconds
                        }
                        if ($negative -and $readyAt -ge 0 -and ($timer.Elapsed.TotalSeconds - $readyAt) -ge 2) {
                            $observed = $true
                            break
                        }
                        if (!$negative -and $text.Contains('PASS: five timer waits completed; kernel execution resumed')) {
                            Start-Sleep -Milliseconds 300
                            $observed = !$process.HasExited
                            break
                        }
                    }
                }
                Start-Sleep -Milliseconds 100
            }
        } finally {
            if (!$process.HasExited) { $process.Kill(); $process.WaitForExit() }
            $stderr = $errorRead.GetAwaiter().GetResult()
            $process.Dispose()
        }
        if (!$observed -or $stderr) { throw "Timer case $mode failed or timed out. Logs: $logDir. QEMU: $stderr" }
        $text = Get-Content -LiteralPath $serialLog -Raw
        $cpu = Get-Content -LiteralPath $cpuLog -Raw
        if ($text -match 'FAIL:|PANIC:|unsupported|boot protocol accepted; CPU halted' -or $cpu -match 'Triple fault') {
            throw "Unexpected execution path in $mode. Logs: $logDir"
        }
        $position = -1
        foreach ($marker in @('DhruthiOS: kernel entered', 'DhruthiOS: IDT loaded', 'TEST: timer configured; waiting for IRQ0')) {
            $found = $text.IndexOf($marker, $position + 1, [StringComparison]::Ordinal)
            if ($found -lt 0) { throw "Missing/out-of-order marker '$marker'. Log: $serialLog" }
            $position = $found
        }
        # Limit the CPU-trace check to vector 32 while executing higher-half kernel code.
        $irqCount = [regex]::Matches($cpu, 'v=20[^\r\n]*IP=[0-9a-fA-F]+:ffffffff[0-9a-fA-F]{8}').Count
        if ($negative) {
            if ($text.Contains('TICK:') -or $text.Contains('PASS:') -or $irqCount -ne 0) {
                throw "Masked IRQ0 unexpectedly delivered or test claimed success. Logs: $logDir"
            }
            Write-Output 'PASS: masked IRQ0 produced no ticks during observation; QEMU closed.'
        } else {
            $tickMarker = 'TICK: IRQ0 returned; registers and flags preserved'
            $tickCount = [regex]::Matches($text, [regex]::Escape($tickMarker)).Count
            if ($tickCount -ne 5 -or $irqCount -lt 5 -or !$text.Contains('PASS: five timer waits completed; kernel execution resumed')) {
                throw "Missing repeated timer-return evidence. Logs: $logDir"
            }
            Write-Output "PASS: five timer waits returned with saved state intact, RAM $ram; QEMU closed."
        }
        Write-Output "  Logs: $serialLog and $cpuLog"
    }
    Write-Output 'Timer test complete. Normal boot files were not replaced.'
} finally { Pop-Location }
