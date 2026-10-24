param([string]$LlvmBin, [string]$QemuDir)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/tools.ps1"
$LlvmBin = Resolve-LlvmDirectory $LlvmBin
$QemuDir = Resolve-QemuDirectory $QemuDir
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    $dirty = @(git status --porcelain)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect Git state.' }
    if ($dirty.Count) { throw 'Commit the reviewed source changes before packaging.' }
    $commit = (git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot identify source commit.' }
    $releaseId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $commit.Substring(0, 7)
    $destination = Join-Path (Get-Location) "build/releases/$releaseId"
    New-Item -ItemType Directory -Path $destination | Out-Null
    $sourceZip = Join-Path $destination 'DhruthiOS-source.zip'
    & git archive --format=zip --prefix=DhruthiOS/ -o $sourceZip HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Source archive failed.' }
    $verificationRoot = Join-Path $destination 'verification'
    Expand-Archive -LiteralPath $sourceZip -DestinationPath $verificationRoot
    $checkout = Join-Path $verificationRoot 'DhruthiOS'
    $validationLog = Join-Path $destination 'validation.txt'
    Write-Output "Checking clean source commit $commit"
    & "$checkout/scripts/check.ps1" -LlvmBin $LlvmBin -QemuDir $QemuDir |
        Tee-Object -FilePath $validationLog
    if (!(Select-String -LiteralPath $validationLog -SimpleMatch 'PASS: all 23 QEMU runs completed')) {
        throw 'Complete validation marker missing; no submission archive produced.'
    }

    $packageRoot = Join-Path $destination 'package'
    Expand-Archive -LiteralPath $sourceZip -DestinationPath $packageRoot
    $package = Join-Path $packageRoot 'DhruthiOS'
    $prebuilt = Join-Path $package 'build/monitor'
    New-Item -ItemType Directory -Path $prebuilt -Force | Out-Null
    Copy-Item -LiteralPath "$checkout/build/monitor/esp" -Destination $prebuilt -Recurse
    Copy-Item -LiteralPath "$checkout/build/monitor/kernel.elf" -Destination $prebuilt
    $evidence = Join-Path $package 'validation'
    New-Item -ItemType Directory -Path $evidence | Out-Null
    Copy-Item -LiteralPath $validationLog -Destination "$evidence/summary.txt"
    foreach ($log in Get-ChildItem -LiteralPath "$checkout/build" -Filter '*.log' -File -Recurse) {
        $relative = $log.FullName.Substring(("$checkout/build").Length + 1)
        $target = Join-Path $evidence $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $log.FullName -Destination $target
    }
    $compilerVersion = & (Join-Path $LlvmBin 'clang.exe') --version
    if ($LASTEXITCODE -ne 0) { throw 'Cannot identify compiler.' }
    $qemuVersion = & (Join-Path $QemuDir 'qemu-system-x86_64.exe') --version
    if ($LASTEXITCODE -ne 0) { throw 'Cannot identify QEMU.' }
    $metadata = [ordered]@{
        project = 'DhruthiOS'
        sourceCommit = $commit
        verifiedUtc = [DateTime]::UtcNow.ToString('o')
        qemuRunsPassed = 23
        compiler = $compilerVersion[0]
        qemu = $qemuVersion[0]
        firmwareSha256 = (Get-FileHash -LiteralPath (Join-Path $QemuDir 'share/edk2-x86_64-code.fd') -Algorithm SHA256).Hash
        kernelSha256 = (Get-FileHash -LiteralPath "$prebuilt/kernel.elf" -Algorithm SHA256).Hash
        scope = 'Educational single-CPU x86-64 kernel under QEMU; see README and docs/release.md.'
    }
    [IO.File]::WriteAllText((Join-Path $package 'RELEASE.json'), ($metadata | ConvertTo-Json) + "`n", [Text.UTF8Encoding]::new($false))
    $manifest = foreach ($item in Get-ChildItem -LiteralPath $package -File -Recurse -Force | Sort-Object FullName) {
        [ordered]@{
            path = $item.FullName.Substring($package.Length + 1).Replace('\','/')
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        }
    }
    [IO.File]::WriteAllText((Join-Path $package 'SHA256SUMS.json'), (ConvertTo-Json -InputObject @($manifest)) + "`n", [Text.UTF8Encoding]::new($false))
    # ZipFile includes dotfiles; Compress-Archive may omit hidden source files.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $submissionZip = Join-Path $destination 'DhruthiOS-submission.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $submissionZip)
    $archiveHash = (Get-FileHash -LiteralPath $submissionZip -Algorithm SHA256).Hash
    [IO.File]::WriteAllText("$submissionZip.sha256", "$archiveHash  DhruthiOS-submission.zip`n", [Text.UTF8Encoding]::new($false))
    Write-Output "RELEASE OK: $submissionZip"
    Write-Output "SHA256: $archiveHash"
} finally { Pop-Location }
