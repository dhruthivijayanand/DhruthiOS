param(
    [string]$LlvmBin,
    [string]$QemuDir,
    [ValidateRange(1, 3)][int]$Runs = 3
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/tools.ps1"
$QemuDir = Resolve-QemuDirectory $QemuDir
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & "$PSScriptRoot/build.ps1" -LlvmBin $LlvmBin -Mode memmap
    $qemu = Join-Path $QemuDir 'qemu-system-x86_64.exe'
    $firmware = Join-Path $QemuDir 'share/edk2-x86_64-code.fd'
    $logDirectory = 'build/memmap/test-' + [guid]::NewGuid().ToString('N')
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
    for ($run = 1; $run -le $Runs; $run++) {
        $ram = @('128M', '256M', '512M')[$run - 1]
        $log = "$logDirectory/boot-$run.log"
        $start = [System.Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $qemu
        $start.WorkingDirectory = (Get-Location).Path
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardError = $true
        $start.Arguments = "-machine pc -accel tcg -m $ram -smp 1 -drive `"if=pflash,format=raw,readonly=on,file=$firmware`" -drive format=raw,snapshot=on,file=fat:build/memmap/esp -display none -serial file:$log -monitor none -net none -no-reboot"
        $process = [System.Diagnostics.Process]::Start($start)
        $errorRead = $process.StandardError.ReadToEndAsync()
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $passed = $false
        try {
            while ($timer.Elapsed.TotalSeconds -lt 30 -and !$process.HasExited) {
                if (Test-Path -LiteralPath $log) {
                    $contents = Get-Content -LiteralPath $log -Raw
                    if ($contents -and $contents.Contains('DhruthiOS: kernel entered') -and
                        $contents.Contains('DhruthiOS: IDT loaded') -and
                        $contents.Contains('PASS: memory map inspected; no RAM allocated') -and
                        !$contents.Contains('DhruthiOS: unsupported') -and
                        !$contents.Contains('PANIC:') -and !$contents.Contains('FAIL:')) {
                        $position = -1
                        foreach ($marker in @('DhruthiOS: kernel entered', 'DhruthiOS: IDT loaded', 'PASS: memory map inspected; no RAM allocated')) {
                            $found = $contents.IndexOf($marker, $position + 1, [StringComparison]::Ordinal)
                            if ($found -lt 0) { throw "Missing/out-of-order marker '$marker'. Log: $log" }
                            $position = $found
                        }
                        $passed = !$process.HasExited
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
        if (!$passed -or $stderr) { throw "Boot $run failed. Log: $log. QEMU stderr: $stderr" }
        if (!$contents.Contains('PASS: memory validator completed (20 cases)')) {
            throw "Missing validator test result. Log: $log"
        }
        $summary = [regex]::Matches($contents, '(?m)^MEMORY: entries=(\d+) usable_bytes=(\d+) usable_pages=(\d+)\r?$')
        if ($summary.Count -ne 1) { throw "Expected one memory summary. Log: $log" }
        $rows = [regex]::Matches($contents, '(?m)^MAP: base=0x([0-9a-f]+) length=0x([0-9a-f]+) type=(\d+)\r?$')
        [decimal]$sum = 0
        foreach ($row in $rows) {
            if ($row.Groups[3].Value -eq '0') {
                $length = [UInt64]::Parse($row.Groups[2].Value, [Globalization.NumberStyles]::HexNumber)
                $sum += [decimal]$length
            }
        }
        $reported = [decimal]$summary[0].Groups[2].Value
        $pages = [decimal]$summary[0].Groups[3].Value
        $ramBytes = [decimal]($ram.TrimEnd('M')) * 1048576
        if ($rows.Count -ne [int]$summary[0].Groups[1].Value -or
            $sum -ne $reported -or $pages * 4096 -ne $sum -or
            $sum -le 0 -or $sum -ge $ramBytes) {
            throw "Memory summary disagrees with map or configured RAM. Log: $log"
        }
        if ($run -gt 1 -and $sum -le $previousUsable) {
            throw 'Usable RAM did not increase with configured RAM.'
        }
        $previousUsable = $sum
        Write-Output "PASS: memory map, RAM $ram, usable $sum bytes, 20 validator cases. Log: $log"
    }
} finally { Pop-Location }