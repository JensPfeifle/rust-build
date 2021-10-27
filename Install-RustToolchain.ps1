[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $ExportFile = '',
    [String]
    $ToolchainVersion = '1.56.0.1'
)

$ErrorActionPreference = "Stop"
# Disable progress bar when downloading - speed up download - https://stackoverflow.com/questions/28682642/powershell-why-is-using-invoke-webrequest-much-slower-than-a-browser-download
$ProgressPreference = 'SilentlyContinue'
$ExportContent = ""
#Set-PSDebug -Trace 1

function InstallRustup() {
    Invoke-WebRequest https://win.rustup.rs/x86_64 -OutFile rustup-init.exe
    ./rustup-init.exe --default-toolchain stable -y
    $env:PATH+=";$env:USERPROFILE\.cargo\bin"
    $ExportContent+="`n" + '$env:PATH+=";$env:USERPROFILE\.cargo\bin"'
}

function InstallRustFmt() {
    rustup component add rustfmt --toolchain=stable
}

if (-Not (Get-Command 7z -ErrorAction SilentlyContinue)) {
    choco install 7zip
}

if (-Not (Get-Command rustup -ErrorAction SilentlyContinue)) {
    InstallRustup
}

if ((rustup show | Select-String -Pattern stable).Length -eq 0) {
    rustup toolchain install stable
}

# It seems there is a dependency on nightly for some reason only on Windows
# It might be caused by way of packaging to dist ZIP.
if ((rustup show | Select-String -Pattern nightly).Length -eq 0) {
    rustup toolchain install nightly
}

if (-Not (Get-Command rustfmt -errorAction SilentlyContinue)) {
    InstallRustFmt
}

if ((rustfmt --version | Select-String -Pattern stable).Length -eq 0) {
    InstallRustFmt
}

$Arch="x86_64-pc-windows-msvc"
$RustDist="rust-${ToolchainVersion}-${Arch}"
$RustDistZipUrl="https://github.com/esp-rs/rust-build/releases/download/v${ToolchainVersion}/${RustDist}.zip"
$ToolchainDestinationDir="${HOME}/.rustup/toolchains/esp"
$LlvmRelease="esp-12.0.1-20210914"
$IdfToolsPath="${HOME}/.espressif"
$IdfToolXtensaElfClang="${IdfToolsPath}/tools/xtensa-esp32-elf-clang/${LlvmRelease}-${Arch}"
$LlvmArch="win64"
$LlvmFile="xtensa-esp32-elf-llvm12_0_1-${LlvmRelease}-${LlvmArch}.zip"
$LlvmUrl="https://github.com/espressif/llvm-project/releases/download/${LlvmRelease}/${LlvmFile}"

if (Test-Path -Path ${ToolchainDestinationDir} -PathType Container) {
    "Previous installation of toolchain exist in: ${ToolchainDestinationDir}"
    "Please, remove the directory before new installation."
    exit 1
}

mkdir -p "${HOME}/.rustup/toolchains/" -ErrorAction SilentlyContinue
Push-Location "${HOME}/.rustup/toolchains"

"* installing esp toolchain"
if (-Not (Test-Path -Path "${RustDist}.zip" -PathType Leaf)) {
    "** downloading: ${RustDistZipUrl}"
    Invoke-WebRequest "${RustDistZipUrl}" -OutFile "${RustDist}.zip"
}
7z x .\${RustDist}.zip
"Toolchains:"
ls
Pop-Location

"* installing ${IdfToolXtensaElfClang}"
if (-Not (Test-Path -Path $IdfToolXtensaElfClang)) {
    if (-Not (Test-Path -Path ${LlvmFile} -PathType Leaf)) {
        "** downloading: ${LlvmUrl}"
        Invoke-WebRequest "${LlvmUrl}" -OutFile ${LlvmFile}
    }
    mkdir -p "${IdfToolsPath}/tools/xtensa-esp32-elf-clang/" -ErrorAction SilentlyContinue
    7z x ${LlvmFile}
    mv xtensa-esp32-elf-clang "${IdfToolXtensaElfClang}"
    "done"
} else {
    "already installed"
}

"Install common dependencies"
cargo install cargo-pio ldproxy

"Add following command to PowerShell profile"
$ExportContent+="`n" + '$env:PATH+=";' + "${IdfToolXtensaElfClang}/bin/" + '"'
$ExportContent+="`n" + '$env:LIBCLANG_PATH="' + "${IdfToolXtensaElfClang}/bin/libclang.dll" + '"'
$ExportContent

if ('' -ne $ExportFile) {
    Out-File -FilePath $ExportFile -InputObject $ExportContent
}
