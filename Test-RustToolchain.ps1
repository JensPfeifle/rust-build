[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $ToolchainVersion = '1.56.0.1',
    [String]
    $BuildTarget = "xtensa-esp32-espidf"
)

$ErrorActionPreference = "Stop"
$RustStdDemo = "rust-esp32-std-demo"

"Processing configuration:"
"-ToolchainVersion = ${ToolchainVersion}"

$ToolchainPrefix = "esp"
$ToolchainName = "${ToolchainPrefix}-${ToolchainVersion}"

./Instal-RustToolchain.ps1 `
    -ToolchainVersion ${ToolchainVersion}

if (-Not (Test-Path -Path ${RustStdDemo} -PathType Container)) {
    git clone https://github.com/ivmarkov/${RustStdDemo}.git
}

Push-Location ${RustStdDemo}
$env:RUST_ESP32_STD_DEMO_WIFI_SSID="rust"
$env:RUST_ESP32_STD_DEMO_WIFI_PASS="for-esp32"
Pop-Location

cargo +${ToolchainName} build --target ${BuildTarget}