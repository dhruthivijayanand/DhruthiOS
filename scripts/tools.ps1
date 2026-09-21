# Shared discovery only; sourcing this file does not change the caller's location.
function Resolve-ToolDirectory {
    param(
        [string]$Directory,
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string]$EnvironmentVariable,
        [Parameter(Mandatory)][string]$DefaultDirectory
    )
    if (!$Directory) { $Directory = [Environment]::GetEnvironmentVariable($EnvironmentVariable) }
    if (!$Directory) {
        $command = Get-Command $Executable -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $Directory = Split-Path -Parent $command.Source }
    }
    if (!$Directory) { $Directory = $DefaultDirectory }
    if (![IO.File]::Exists([IO.Path]::Combine($Directory, $Executable))) {
        throw "Cannot find $Executable in '$Directory'. Add it to PATH, set $EnvironmentVariable, or pass the tool directory explicitly."
    }
    return (Resolve-Path -LiteralPath $Directory).Path
}

function Resolve-LlvmDirectory {
    param([string]$Directory)
    Resolve-ToolDirectory -Directory $Directory -Executable clang.exe -EnvironmentVariable LLVM_BIN -DefaultDirectory "$env:ProgramFiles\LLVM\bin"
}

function Resolve-QemuDirectory {
    param([string]$Directory)
    Resolve-ToolDirectory -Directory $Directory -Executable qemu-system-x86_64.exe -EnvironmentVariable QEMU_DIR -DefaultDirectory "$env:ProgramFiles\qemu"
}
