# Push live-display-fix.sh to RK3308BS and run it (no reflash).
param(
    [string]$SocHost = "",
    [string]$Password = "ztfalxtspv",
    [string]$User = "root"
)

$Plink = "C:\Program Files\PuTTY\plink.exe"
$Script = Join-Path $PSScriptRoot "live-display-fix.sh"
$Candidates = @(
    "10.22.30.172",
    "10.22.30.171",
    "10.22.2.208"  # sometimes same subnet as build server
)

if (-not (Test-Path $Plink)) { throw "PuTTY plink not found at $Plink" }
if (-not (Test-Path $Script)) { throw "Missing $Script" }

function Test-SshPort($ip) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect($ip, 22, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(1500, $false)
        if ($ok -and $tcp.Connected) { $tcp.Close(); return $true }
        $tcp.Close()
    } catch {}
    return $false
}

if ($SocHost) {
    $Target = $SocHost
} else {
    $Target = $null
    foreach ($ip in $Candidates) {
        if (Test-SshPort $ip) {
            $r = & $Plink -batch -pw $Password "${User}@${ip}" "hostname 2>/dev/null" 2>&1
            if ($LASTEXITCODE -eq 0 -and ($r -match "rk3308")) {
                $Target = $ip
                break
            }
            if ($LASTEXITCODE -eq 0) { $Target = $ip; break }
        }
    }
    if (-not $Target) {
        Write-Host "SoC not found. Power it on and pass -SocHost <ip> or ensure WiFi (OurIOT) is up."
        exit 1
    }
}

Write-Host "Using ${User}@${Target}"
Get-Content $Script -Raw | & $Plink -batch -pw $Password "${User}@${Target}" "bash -s"
