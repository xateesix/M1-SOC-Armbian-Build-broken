# A3D M1 Pro X1 â€” Armbian eMMC Firmware (RK3308BS)

**Version v0.64.1** â€” experimental community firmware for the Artillery M1 Pro S1-SOC control board.

> ## WARNING â€” READ FIRST
>
> - **Experimental** â€” not supported by Artillery 3D; no warranty.
> - **Void warranty** â€” flashing and hardware mods void manufacturer warranty.
> - **Dangerous voltages** â€” printer has **mains AC** and **24 V DC**. Wrong wiring can cause fire, shock, or damage. Work unplugged unless qualified.
> - **Extra hardware required** â€” USB-serial adapter, RKDevTool + Windows PC, possible eMMC flash setup, etc.
> - **You assume all risk** â€” authors are not liable for damage or injury.
> - **Alternative CNC Mainboard and Toolhead board is highly recomended (I used a BTT Manta 4p and a Fysetc H36 for mine)
> - **Still working on a Z probe solution with eddy planned, this will require modifying the toolhead cover and possibly more.

---

## What this is

Armbian-based replacement firmware for the **RK3308BS** SoC on the **Artillery M1 Pro X1** (S1-SOC). It targets a lean Linux host for Klipper development, with display and serial console working. It is **not** a drop-in factory UI replacement.

## Quick start

```bash
git clone https://github.com/xateesix/M1-SOC-Armbian-Build.git
cd M1-SOC-Armbian-Build
./configure.sh          # prompts for passwords, WiFi, user m1prox1
./setup-validate.sh     # optional checks
bash tools/build-release-v64.sh   # WSL/Linux â†’ eMMC image
```

Flash with **RKDevTool â†’ Upgrade Firmware** (see `FLASH_RKDEVTOOL.md`). Do not use balenaEtcher for eMMC.

## Configuration (no secrets in git)

| File | Purpose |
|------|---------|
| `config.env.example` | Placeholders only â€” safe to commit |
| `configure.sh` | **Interactive** â€” creates `config.env` with your passwords |
| `config.env` | **Git-ignored** â€” never commit |

`configure.sh` prompts for:

- `ROOT_PASSWORD` / `USER_NAME` (default **m1prox1**) / `USER_PASSWORD`
- `WIFI_SSID` / `WIFI_PASSWORD` (optional â€” leave blank to configure on device)
- Build server SSH (optional)

## Feature status (v0.64.1)

| Feature | Status |
|---------|--------|
| eMMC boot + RKDevTool flash | **Working** |
| Display + boot logo | **Working** |
| Serial `ttyFIQ0` @ 1500000 | **Working** |
| WiFi | Build-time or on-device setup |
| MOTD / board name **A3D M1 Pro X1** | **Working** |
| Case light bar (+LED-) | **Pin confirmed** GPIO2_B3 â€” driver **pending** |
| RGB pebbles (WS2812, 5V/G/S) | **Not supported** â€” deferred |
| Klipper / Moonraker | Bring your own config |
| Factory Makerbase UI | Not included |

## GPIO and hardware map

### Confirmed

| Function | Rockchip | libgpiod | sysfs |
|----------|----------|----------|-------|
| Case light bar (+LED-) | GPIO2_B3 | gpiochip2 line 11 | gpio75 |
| Onboard blue LED | GPIO0_A5 | gpiochip0 line 5 | â€” |
| Onboard green LED | GPIO0_A6 | gpiochip0 line 6 | â€” |
| Display | LCDC RGB | gpio1/gpio2 | backlight PWM |
| SD / eMMC | SDIO/eMMC | gpio3/gpio4 | â€” |

**Light bar:** factory uses **24 V digital enable** on GPIO2_B3, not PWM0. Current DTB still targets PWM0 â€” fix planned.

### RGB NeoPixel (deferred)

| Candidate | libgpiod | Notes |
|-----------|----------|-------|
| SPI1 MOSI m1 | gpiochip2 line 5 | WS2812-via-SPI |
| SPI1 MOSI m0 | gpiochip3 line 12 | Alt route |
| GPIO bitbang | gpiochip0 line 1 | Test default |

Factory image has no working `[neopixel]` / Moonraker `[wled]` path. S header often sits at ~5 V with no data driver.

### On-board tools

```bash
sudo factory-led-audit.sh
sudo gpio-dmm-probe.sh gpiochip2 11 45 5
```

## Custom boot logo

1. `python3 tools/make-logo-bmp.py --input logo.png --output logo.bmp` (480Ã—272 grayscale BMP)
2. `python3 tools/patch-resource-logos.py --template <resource.img> --logo logo.bmp --output out.img`
3. Rebuild boot: `bash tools/build-boot-v64.sh` then repack eMMC image

See `docs/BOOT_LOGO.md`.

## On-device documentation

When built with `tools/patch-rootfs-public.sh`, docs install to:

```
/home/m1prox1/docs/
  README.md
  WARNING.md
  GPIO_AND_HARDWARE.md
  BOOT_LOGO.md
  CONFIGURE_AND_BUILD.md
```

Default login user: **m1prox1** (password from `configure.sh`).

## Build pipeline

```
configure.sh â†’ config.env
build-release-v64.sh
  â”œâ”€â”€ build-boot-v64.sh      (kernel + DTB + boot logo resource)
  â”œâ”€â”€ patch-rootfs-v64-debugfs.sh
  â”œâ”€â”€ stage-pack-v64.sh
  â””â”€â”€ windows-pack-update.ps1 â†’ rk3308bs-1.0.0-emmc-fixed-v64.img
```

## Repository layout

| Path | Description |
|------|-------------|
| `tools/` | Build, patch, flash, GPIO audit scripts |
| `patches/` | Kernel/DTS patches |
| `factory_fresh/` | Factory reference images (not in git releases) |
| `releases/` | Built `.img` artifacts (git-ignored) |
| `docs/` | Public documentation |

## License and disclaimer

Provided as-is for research and self-hosting. Artillery, Makerbase, Klipper, and Armbian are trademarks of their respective owners. This project is not affiliated with Artillery 3D.

## Changelog

See `CHANGELOG.md` â€” **v0.64.1** public release with hardware documentation and build tooling.
