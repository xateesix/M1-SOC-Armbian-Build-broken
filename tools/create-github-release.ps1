# Create GitHub release v0.64.1 (requires gh auth login)
Set-Location $PSScriptRoot\..
$body = @"
## Summary
- Public release v0.64.1 for A3D M1 Pro X1 (RK3308BS) experimental Armbian eMMC firmware
- Interactive configure.sh prompts for passwords and WiFi; no secrets in repository
- GPIO documentation, boot logo guide, safety warnings, on-device docs for m1prox1
- Case light bar pin: GPIO2_B3 (gpiochip2 line 11); RGB NeoPixel deferred

## Configure and build
``````bash
git clone https://github.com/xateesix/M1-SOC-Armbian-Build.git
cd M1-SOC-Armbian-Build
./configure.sh
bash tools/build-release-v64.sh
``````

Flash with RKDevTool Upgrade Firmware. See README.md and FLASH_RKDEVTOOL.md.

## Warning
Experimental firmware. Void warranty. High voltage wiring risk. Not affiliated with Artillery 3D.
"@
$body | Out-File -Encoding utf8 release-notes-v0.64.1.md
gh release create v0.64.1 --title "v0.64.1 - Public experimental release" --notes-file release-notes-v0.64.1.md
Write-Host "Release URL:" (gh release view v0.64.1 --json url -q .url)
