param(
    [Parameter(Mandatory = $true)][string]$PackInput,
    [string]$Output = "Armbian-rk3308-emmc.img"
)

function Resolve-RKDevToolBin {
    if ($env:RKDEVTOOL_BIN -and (Test-Path (Join-Path $env:RKDEVTOOL_BIN "AFPTool.exe"))) {
        return $env:RKDEVTOOL_BIN
    }
    $candidates = @(
        (Join-Path $PSScriptRoot "bin"),
        (Join-Path $PSScriptRoot "..\..\bin"),
        (Join-Path $env:USERPROFILE "Downloads\RKDevTool_Release_v3.32\RKDevTool_v3.32_for_window\bin"),
        (Join-Path $env:USERPROFILE "Downloads\RKDevTool_Release_v2.86\RKDevTool_Release_v2.86\bin"),
        (Join-Path $env:TEMP "RKDevTool_v2.86\RKDevTool_Release_v2.86\bin")
    )
    foreach ($dir in $candidates) {
        if (Test-Path (Join-Path $dir "AFPTool.exe")) {
            return $dir
        }
    }
    throw "AFPTool.exe not found. Set RKDEVTOOL_BIN or install RKDevTool under Downloads."
}

$Bin = Resolve-RKDevToolBin
$OutDir = Split-Path -Parent $PackInput
$Firmware = Join-Path $OutDir "firmware.img"
$Loader = Join-Path $PackInput "Image\MiniLoaderAll.bin"
& (Join-Path $Bin "AFPTool.exe") -pack $PackInput $Firmware
& (Join-Path $Bin "RKImageMaker.exe") -RK3308 $Loader $Firmware (Join-Path $OutDir $Output) -os_type:androidos
Write-Host "Flash: $(Join-Path $OutDir $Output)"
