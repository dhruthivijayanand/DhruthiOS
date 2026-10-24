param([string]$LlvmBin, [string]$QemuDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/tools.ps1"
$QemuDir = Resolve-QemuDirectory $QemuDir
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & "$PSScriptRoot/build.ps1" -LlvmBin $LlvmBin -Mode echo
    $qemu = Join-Path $QemuDir 'qemu-system-x86_64.exe'
    $firmware = Join-Path $QemuDir 'share/edk2-x86_64-code.fd'
    $logDirectory = 'build/echo/test-' + [guid]::NewGuid().ToString('N')
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
    foreach ($ram in @('128M', '256M')) {
        $pipeName = 'dhruthios-echo-' + [guid]::NewGuid().ToString('N')
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $qemu
        $start.WorkingDirectory = (Get-Location).Path
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardError = $true
        $start.Arguments = "-machine pc -accel tcg -m $ram -smp 1 -drive `"if=pflash,format=raw,readonly=on,file=$firmware`" -drive format=raw,snapshot=on,file=fat:build/echo/esp -display none -serial pipe:$pipeName -monitor none -net none -no-reboot"
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
            $boot = Wait-SerialText -Offset 0 -Expected "ECHO: type a short line, then press Enter`r`n"
            if (!$boot.Contains('DhruthiOS: IDT loaded')) { throw 'Missing startup marker.' }
            $prompt = 'DhruthiOS> '
            $help = "Commands:`r`n  help  - list commands`r`n  about - describe DhruthiOS`r`n"
            $about = "DhruthiOS: an educational x86-64 kernel.`r`nWritten in C and Assembly; running inside QEMU.`r`nThis command interface runs inside the kernel.`r`n"
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
                $writeTask.GetAwaiter().GetResult()
                $actual = Wait-SerialText -Offset $offset -Expected $prompt
                if ($actual -cne $case.Expected) {
                    throw "Output mismatch: $($case.Name). Log: $logPath"
                }
                Write-Output "PASS: serial $($case.Name), RAM $ram"
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