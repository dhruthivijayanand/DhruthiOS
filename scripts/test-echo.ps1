param([string]$LlvmBin, [string]$QemuDir, [ValidateSet('echo','monitor')][string]$Mode = 'echo')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/tools.ps1"
$QemuDir = Resolve-QemuDirectory $QemuDir
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & "$PSScriptRoot/build.ps1" -LlvmBin $LlvmBin -Mode $Mode
    $qemu = Join-Path $QemuDir 'qemu-system-x86_64.exe'
    $firmware = Join-Path $QemuDir 'share/edk2-x86_64-code.fd'
    $logDirectory = ("build/$Mode/test-") + [guid]::NewGuid().ToString('N')
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
    foreach ($ram in @('128M', '256M')) {
        $pipeName = 'dhruthios-echo-' + [guid]::NewGuid().ToString('N')
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $qemu
        $start.WorkingDirectory = (Get-Location).Path
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardError = $true
        $machine = if ($Mode -eq 'monitor') { 'pc,hpet=off' } else { 'pc' }
        $start.Arguments = "-machine $machine -accel tcg -m $ram -smp 1 -drive `"if=pflash,format=raw,readonly=on,file=$firmware`" -drive format=raw,snapshot=on,file=fat:build/$Mode/esp -display none -serial pipe:$pipeName -monitor none -net none -no-reboot"
        $process = [Diagnostics.Process]::Start($start)
        $errorRead = $process.StandardError.ReadToEndAsync()
        $client = $null
        $transcript = [Text.StringBuilder]::new()
        $logPath = "$logDirectory/serial-$ram.log"
        try {
            $connectionTimer = [Diagnostics.Stopwatch]::StartNew()
            while (!$client -and $connectionTimer.Elapsed.TotalSeconds -lt 10) {
                if ($process.HasExited) { throw 'QEMU exited before serial connection.' }
                $candidate = [IO.Pipes.NamedPipeClientStream]::new('.', $pipeName, [IO.Pipes.PipeDirection]::InOut, [IO.Pipes.PipeOptions]::Asynchronous)
                try {
                    $candidate.Connect(500)
                    $client = $candidate
                } catch {
                    $candidate.Dispose()
                    Start-Sleep -Milliseconds 50
                }
            }
            if (!$client) { throw 'Timed out connecting to QEMU serial port.' }
            $stream = $client

            $bytes = New-Object byte[] 4096

            $readState = @{ Task = $null }
            function Read-SerialAvailable {
                if (!$readState.Task) {
                    $readState.Task = $stream.ReadAsync($bytes, 0, $bytes.Length)
                }
                while ($readState.Task.IsCompleted) {
                    $count = $readState.Task.GetAwaiter().GetResult()
                    if ($count -eq 0) { throw 'Serial connection closed.' }
                    [void]$transcript.Append([Text.Encoding]::ASCII.GetString($bytes, 0, $count))
                    $readState.Task = $stream.ReadAsync($bytes, 0, $bytes.Length)
                }
            }
            function Wait-SerialText {
                param([int]$Offset, [string]$Expected)
                $waitTimer = [Diagnostics.Stopwatch]::StartNew()
                while ($waitTimer.Elapsed.TotalSeconds -lt 30) {
                    Read-SerialAvailable
                    $received = $transcript.ToString().Substring($Offset)
                    if ($received.Contains('PANIC:') -or $received.Contains('FAIL:')) {
                        throw "Kernel failure: $received"
                    }
                    if ($received.Contains($Expected)) {
                        Start-Sleep -Milliseconds 100
                        Read-SerialAvailable
                        return $transcript.ToString().Substring($Offset)
                    }
                    if ($process.HasExited) { throw 'QEMU exited during serial test.' }
                    Start-Sleep -Milliseconds 20
                }
                throw "Timeout waiting for '$Expected'. Log: $logPath"
            }
            $ready = if ($Mode -eq 'monitor') { "DhruthiOS monitor ready. Type help.`r`nDhruthiOS> " } else { "ECHO: type a short line, then press Enter`r`n" }
            $boot = Wait-SerialText -Offset 0 -Expected $ready
            if (!$boot.Contains('DhruthiOS: IDT loaded')) { throw 'Missing startup marker.' }
            $prompt = 'DhruthiOS> '
            $help = "Commands:`r`n  help  - list commands`r`n  about - describe DhruthiOS`r`n"
            $about = "DhruthiOS: an educational x86-64 kernel.`r`nWritten in C and Assembly; running inside QEMU.`r`nThis command interface runs inside the kernel.`r`n"
            if ($Mode -eq 'monitor') {
                $help += "  memory - show page counts`r`n  memtest - test two pages and return them`r`n  ticks - show delivered timer interrupts`r`n"
                $about = "DhruthiOS: an educational x86-64 kernel.`r`nAssembly interrupt entry, C services, C++ monitor.`r`nRunning inside QEMU; commands execute in the kernel.`r`n"
            }
            $unknown = "Unknown command. Try help.`r`n"
            $empty = "No command entered.`r`n"
            $limit = '1234567890123456789012345678901'
            $overflow = "`r`nLine too long. Press Enter to try again.`r`n"
            $cases = @(
                @{ Name='help CR'; Input="help`r"; Expected="help`r`n$help$prompt" },
                @{ Name='about LF'; Input="about`n"; Expected="about`r`n$about$prompt" },
                @{ Name='unknown suffix'; Input="abouts`r"; Expected="abouts`r`n$unknown$prompt" },
                @{ Name='empty CRLF'; Input="`r`n"; Expected="`r`n$empty$prompt" },
                @{ Name='help CRLF'; Input="help`r`n"; Expected="help`r`n$help$prompt" },
                @{ Name='Backspace correction'; Input="helx`bp`r"; Expected="helx`b `bp`r`n$help$prompt" },
                @{ Name='DEL correction'; Input=("helx" + [char]127 + "p`r"); Expected="helx`b `bp`r`n$help$prompt" },
                @{ Name='Backspace at empty'; Input="`b`bhelp`r"; Expected="help`r`n$help$prompt" },
                @{ Name='erase whole line'; Input="abc`b`b`b`r"; Expected="abc`b `b`b `b`b `b`r`n$empty$prompt" },
                @{ Name='31 characters accepted'; Input="$limit`r"; Expected="$limit`r`n$unknown$prompt" },
                @{ Name='32nd character rejected'; Input=($limit + "2`r"); Expected="$limit$overflow$prompt" },
                @{ Name='rejected suffix discarded'; Input=($limit + "2help`r`n"); Expected="$limit$overflow$prompt" },
                @{ Name='help after rejection'; Input="help`r"; Expected="help`r`n$help$prompt" },
                @{ Name='edit at capacity'; Input=($limit + "`bX`r"); Expected=($limit + "`b `bX`r`n$unknown$prompt") }
            )
            foreach ($case in $cases) {
                Read-SerialAvailable
                $offset = $transcript.Length
                $inputBytes = [Text.Encoding]::ASCII.GetBytes($case.Input)
                $writeTask = $stream.WriteAsync($inputBytes, 0, $inputBytes.Length)
                if (!$writeTask.Wait(5000)) { throw 'Serial write timed out.' }
                [void]$writeTask.GetAwaiter().GetResult()
                $actual = Wait-SerialText -Offset $offset -Expected $prompt
                if ($actual -cne $case.Expected) {
                    throw "Output mismatch: $($case.Name). Log: $logPath"
                }
                Write-Output "PASS: serial $($case.Name), RAM $ram"
            }
            if ($Mode -eq 'monitor') {
                function Invoke-MonitorCommand([string]$Command) {
                    Read-SerialAvailable
                    $offset = $transcript.Length
                    $inputBytes = [Text.Encoding]::ASCII.GetBytes($Command + "`r")
                    $writeTask = $stream.WriteAsync($inputBytes, 0, $inputBytes.Length)
                    if (!$writeTask.Wait(5000)) { throw 'Monitor write timed out.' }
                    [void]$writeTask.GetAwaiter().GetResult()
                    return Wait-SerialText -Offset $offset -Expected $prompt
                }
                function Read-MonitorTicks {
                    $reply = Invoke-MonitorCommand 'ticks'
                    $tickMatch = [regex]::Match($reply, '\Aticks\r\nTimer interrupts received: (\d+) \(nominal 100 Hz; not a wall clock\)\.\r\nDhruthiOS> \z')
                    if (!$tickMatch.Success) { throw "Invalid tick report: $reply" }
                    return [uint64]$tickMatch.Groups[1].Value
                }
                $firstTicks = Read-MonitorTicks
                Start-Sleep -Milliseconds 150
                $secondTicks = Read-MonitorTicks
                if ($firstTicks -eq 0 -or $secondTicks -le $firstTicks) { throw 'Timer did not advance while idle.' }
                $initial = Invoke-MonitorCommand 'memory'
                $pattern = '\Amemory\r\nMemory \(4096-byte pages\): managed=(\d+) free=(\d+) used=(\d+) excluded=(\d+)\r\nPhysical address limit: 1 GiB; kernel and reserved regions excluded\.\r\nDhruthiOS> \z'
                $match = [regex]::Match($initial, $pattern)
                if (!$match.Success) { throw "Invalid memory report: $initial" }
                $managed = [uint64]$match.Groups[1].Value
                $free = [uint64]$match.Groups[2].Value
                $used = [uint64]$match.Groups[3].Value
                if ($managed -lt 2 -or $managed -ne $free -or $used -ne 0 -or $managed -gt 262144) {
                    throw 'Implausible initial memory counts.'
                }
                foreach ($command in @('memoryx','memtestx','ticksx')) {
                    $actual = Invoke-MonitorCommand $command
                    if ($actual -cne ($command + "`r`n" + $unknown + $prompt)) {
                        throw "Prefix matching error for $command"
                    }
                }
                for ($iteration = 1; $iteration -le 10; ++$iteration) {
                    $actual = Invoke-MonitorCommand 'memtest'
                    if ($actual -cne "memtest`r`nMEMTEST PASS: two pages written, verified and returned.`r`n$prompt") {
                        throw "Memory test $iteration failed: $actual"
                    }
                    if ((Invoke-MonitorCommand 'memory') -cne $initial) { throw 'Memory counts changed after test.' }
                }
                if ((Read-MonitorTicks) -le $secondTicks) { throw 'Timer stopped after memory commands.' }
                Write-Output "PASS: timer idle/wake and continued delivery after memory tests, RAM $ram"
                Write-Output "PASS: monitor counts, exact command matching and 10 leak-free memory tests, RAM $ram"
            }
        } finally {
            if ($client) { $client.Dispose() }
            if (!$process.HasExited) { $process.Kill(); $process.WaitForExit() }
            $stderr = $errorRead.GetAwaiter().GetResult()
            [IO.File]::WriteAllText((Join-Path (Get-Location) $logPath), $transcript.ToString())
            [IO.File]::WriteAllText((Join-Path (Get-Location) "$logDirectory/stderr-$ram.log"), $stderr)
            $process.Dispose()
        }
        if ($stderr) { throw "QEMU stderr: $stderr" }
        Write-Output "PASS: 14 serial scenarios at $ram. Log: $logPath"
    }
} finally { Pop-Location }