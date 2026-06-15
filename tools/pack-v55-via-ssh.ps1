param(
    [string]$ServerUser = "xateesix",
    [string]$ServerHost = "10.22.2.208",
    [string]$ServerPassword = $(if ($env:ARMBIAN_BUILD_SSH_PASS) { $env:ARMBIAN_BUILD_SSH_PASS } else { "" }),
    [switch]$SkipPull
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Rel = Join-Path $RepoRoot "releases\1.0.0"
$PackLocal = Join-Path $Rel "pack_input_v54"
$OutImage = "rk3308bs-1.0.0-emmc-fixed-v55.img"
$ServerRel = "/tmp/armbian-m1-build/releases/1.0.0"
$ServerPack = "$ServerRel/pack_input_v54"
$FinishLog = "/tmp/armbian-m1-build/finish-v55.log"

if (-not $ServerPassword) {
    throw "Set ARMBIAN_BUILD_SSH_PASS or pass -ServerPassword for xateesix@$ServerHost"
}

function Invoke-WslSsh {
    param([string]$RemoteCommand)
    $escaped = $RemoteCommand -replace "'", "'\''"
    $inner = "export SSHPASS='$ServerPassword'; sshpass -e ssh -o StrictHostKeyChecking=accept-new ${ServerUser}@${ServerHost} '$escaped'"
    $out = wsl -e bash -lc $inner 2>&1
    if ($LASTEXITCODE -ne 0) { throw "SSH failed: $out" }
    return ($out | Out-String).Trim()
}

function Resolve-RKDevToolBin {
    if ($env:RKDEVTOOL_BIN -and (Test-Path (Join-Path $env:RKDEVTOOL_BIN "AFPTool.exe"))) {
        return $env:RKDEVTOOL_BIN
    }
    $candidates = @(
        (Join-Path $env:USERPROFILE "Downloads\RKDevTool_Release_v3.32\RKDevTool_Release_v3.32\bin"),
        (Join-Path $env:USERPROFILE "Downloads\RKDevTool_Release_v2.86\RKDevTool_Release_v2.86\bin"),
        (Join-Path $RepoRoot "bin")
    )
    foreach ($dir in $candidates) {
        if (Test-Path (Join-Path $dir "AFPTool.exe")) { return $dir }
    }
    throw "AFPTool.exe not found. Set RKDEVTOOL_BIN to RKDevTool bin (e.g. Downloads\RKDevTool_Release_v3.32\...\bin)."
}

Write-Host "Verify server staging on ${ServerUser}@${ServerHost}..."
$logTail = Invoke-WslSsh "tail -n 30 $FinishLog 2>/dev/null || true"
if ($logTail -notmatch "SERVER_STAGE_DONE") {
    $probe = Invoke-WslSsh "test -d $ServerPack/Image && echo PACK_OK || echo PACK_MISSING"
    if ($probe -notmatch "PACK_OK") {
        throw "Server not staged: finish-v55.log missing SERVER_STAGE_DONE and $ServerPack missing."
    }
    Write-Warning "SERVER_STAGE_DONE not in log tail; pack_input exists — continuing."
} else {
    Write-Host "SERVER_STAGE_DONE confirmed."
}

if (-not $SkipPull) {
    Write-Host "Rsync pack_input_v54 from server..."
    $wslRel = "/mnt/c/Workspaces/Armbian-M1-SOC/releases/1.0.0"
    $rsyncInner = "export SSHPASS='$ServerPassword'; mkdir -p '$wslRel/pack_input_v54' && rsync -avz --delete -e 'sshpass -e ssh -o StrictHostKeyChecking=accept-new' ${ServerUser}@${ServerHost}:$ServerPack/ '$wslRel/pack_input_v54/'"
    wsl -e bash -lc $rsyncInner
    if ($LASTEXITCODE -ne 0) { throw "rsync from server failed (exit $LASTEXITCODE)" }
}
if (-not (Test-Path (Join-Path $PackLocal "Image\parameter.txt"))) {
    throw "Missing local pack input: $PackLocal\Image\parameter.txt"
}

$bin = Resolve-RKDevToolBin
Write-Host "RKDevTool bin: $bin"
$packScript = Join-Path $RepoRoot "windows-pack-update.ps1"
if (-not (Test-Path $packScript)) { throw "Missing $packScript" }

& $packScript -PackInput $PackLocal -Output $OutImage
$flash = Join-Path $Rel $OutImage
if (-not (Test-Path $flash)) { throw "Pack did not produce $flash" }
$item = Get-Item $flash
Write-Host "Flash image: $($item.FullName) ($($item.Length) bytes)"


