param(
    [string]$QemuDir = 'C:\Program Files\qemu',
    [ValidateRange(1, 5)][int]$Runs = 3
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    $qemu = Join-Path $QemuDir 'qemu-system-x86_64.exe'
    $firmware = Join-Path $QemuDir 'share/edk2-x86_64-code.fd'
    $logDirectory = 'build/test-' + [guid]::NewGuid().ToString('N')
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
    for ($run = 1; $run -le $Runs; $run++) {
        $ram = if ($run -eq 2) { '256M' } else { '128M' }
        $log = "$logDirectory/boot-$run.log"
        $start = [System.Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $qemu
        $start.WorkingDirectory = (Get-Location).Path
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardError = $true
        $start.Arguments = "-machine pc -accel tcg -m $ram -smp 1 -drive `"if=pflash,format=raw,readonly=on,file=$firmware`" -drive format=raw,snapshot=on,file=fat:build/esp -display none -serial file:$log -monitor none -net none -no-reboot"
        $process = [System.Diagnostics.Process]::Start($start)
        $errorRead = $process.StandardError.ReadToEndAsync()
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $passed = $false
        try {
            while ($timer.Elapsed.TotalSeconds -lt 30 -and !$process.HasExited) {
                if (Test-Path -LiteralPath $log) {
                    $contents = Get-Content -LiteralPath $log -Raw
                    if ($contents -and $contents.Contains('DhruthiOS: kernel entered') -and
                        $contents.Contains('DhruthiOS: boot protocol accepted; CPU halted') -and
                        !$contents.Contains('DhruthiOS: unsupported')) {
                        $passed = $true
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
        Write-Output "PASS: boot $run, RAM $ram, both kernel markers received. Log: $log"
    }
} finally { Pop-Location }
