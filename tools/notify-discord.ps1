param(
    [Parameter(Mandatory = $true)]
    [string] $Message
)
$Webhook = 'https://discord.com/api/webhooks/1515772395624071278/V3EfBQJEK9QZivzRUoE7Za7Ubb9gp3pVlCGqQsNJmVaPuIYX_G401AmWJ_2B_VIYYvWc'
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
