# Local/build-host only — not exported to public repo.
param(
    [Parameter(Mandatory = $true)]
    [string] $Message
)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = Split-Path -Parent $ScriptDir
$Config = Join-Path $Repo 'config.env'
if (Test-Path $Config) {
    Get-Content $Config | ForEach-Object {
        if ($_ -match '^\s*DISCORD_WEBHOOK_URL\s*=\s*"?([^"#]+)"?\s*$') {
            $env:DISCORD_WEBHOOK_URL = $Matches[1].Trim()
        }
    }
}
$Webhook = $env:DISCORD_WEBHOOK_URL
if (-not $Webhook) {
    Write-Error 'Set DISCORD_WEBHOOK_URL in config.env or environment'
    exit 1
}
$body = @{ content = $Message } | ConvertTo-Json -Compress
try {
    $resp = Invoke-WebRequest -Uri $Webhook -Method Post -Body $body -ContentType 'application/json' -UseBasicParsing
    Write-Output "HTTP $($resp.StatusCode)"
} catch {
    if ($_.Exception.Response) {
        Write-Output "HTTP $($_.Exception.Response.StatusCode.value__)"
        exit 1
    }
    throw
}
