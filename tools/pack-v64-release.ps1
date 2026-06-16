# Pack staged pack_input_v64 into monolithic flash image (RKDevTool v2.86).
$ErrorActionPreference = "Stop"
$Repo = Split-Path $PSScriptRoot -Parent
$Rel = Join-Path $Repo "releases\1.0.0"
$env:RKDEVTOOL_BIN = Join-Path $env:LOCALAPPDATA "Temp\RKDevTool_v2.86\RKDevTool_Release_v2.86\bin"
if (-not (Test-Path (Join-Path $env:RKDEVTOOL_BIN "AFPTool.exe"))) {
    throw "AFPTool not found at $env:RKDEVTOOL_BIN - download RKDevTool v2.86 first"
}
& (Join-Path $Repo "windows-pack-update.ps1") `
  -PackInput (Join-Path $Rel "pack_input_v64") `
  -Output "rk3308bs-1.0.0-emmc-fixed-v64.img"
$out = Join-Path $Rel "rk3308bs-1.0.0-emmc-fixed-v64.img"
Get-Item $out | Format-List Name, Length, LastWriteTime
