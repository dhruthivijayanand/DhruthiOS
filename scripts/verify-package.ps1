$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$manifestPath = Join-Path $root 'SHA256SUMS.json'
if (!(Test-Path -LiteralPath $manifestPath)) { throw 'Run this script from an extracted submission package.' }
$entries = @(Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json)
$prefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $entries) {
    $target = [IO.Path]::GetFullPath((Join-Path $root $entry.path))
    if (!$target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or !$seen.Add($target)) {
        throw "Invalid or repeated manifest path: $($entry.path)"
    }
    if (!(Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing file: $($entry.path)" }
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -cne $entry.sha256) {
        throw "Checksum mismatch: $($entry.path)"
    }
}
Write-Output "PASS: $($entries.Count) packaged files match recorded SHA-256 checksums."
Write-Output 'Checksums detect file changes; they are not a digital signature.'
