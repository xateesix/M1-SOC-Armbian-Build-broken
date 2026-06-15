# Resume Here  -  RK3308BS Armbian (M1 Pro S1-SOC)

**Read this first** after a break, a failed build, or a new Cursor session.

## Project goal

Build a **distributable, reproducible, lean Armbian OS** for the Artillery M1 Pro S1-SOC (RK3308BS) that:

- **Fully supports onboard hardware**  -  LCD, touch, WiFi, serial, thermal, eMMC (everything needed on the printer)
- **Targets Klipper**  -  minimal rootfs, reliable boot, display + network for a printer host (not a general desktop)
- **Pre-configured before compile**  -  edit `config.env` once for username, password, WiFi, locale, timezone; baked into the image at build time (no first-boot wizard)
- **Reproducible**  -  scripted pipeline from Armbian source  ->  patched rootfs  ->  monolithic eMMC image; same inputs produce the same output
- **Published publicly on GitHub**  -  `https://github.com/xateesix/M1-SOC-Armbian-Build.git` for others to fork, customize `config.env`, and build their own image

**Design principles:** lean (no bloat), hardware-complete, script-driven, config-driven, documented flash path. Current work (v46 pipeline) is a stepping stone toward that release-quality image.

### Hardware support checklist (target state)

| Component | Status | Notes |
|-----------|--------|-------|
| eMMC boot/flash | Working | RKDevTool monolithic `.img`, 17 MB boot slot |
| Serial console | Working | UART3 @ 1500000, **ttyFIQ0** |
| 480x272 LCD | In progress | panel-dpi DTB + DRM modules in v46 |
| Goodix GT911 touch | Target | I2C3  -  verify after v46 flash |
| RTL8189FS WiFi | In progress | Module baked; credentials from `config.env` |
| RK3308BS thermal | Working | `rk3308bs-tsadc` kernel patch + DTB |
| Klipper host ready | Target | Lean Bookworm, SSH/serial login, WiFi, display |

### User customization (before compile)

Edit **`config.env`**  -  single file, no image editing:

| Setting | Variable |
|---------|----------|
| Username | `USER_NAME`, `USER_PASSWORD`, `USER_REALNAME` |
| Root password | `ROOT_PASSWORD` |
| WiFi | `WIFI_SSID`, `WIFI_PASSWORD`, `WIFI_COUNTRY` |
| Locale / timezone | `LOCALE`, `TIMEZONE` |
| Serial console | `SERIAL_GETTY`, `SERIAL_BAUD` |

For public GitHub: ship `config.env.example` with placeholders; keep real `config.env` local (see roadmap in `.cursor/STATE.md`).

## Workspace

| | Path |
|---|------|
| **Windows** | `C:\Workspaces\Armbian-M1-SOC` |
| **WSL** | `/mnt/c/Workspaces/Armbian-M1-SOC` |
| **Git remote** | `https://github.com/xateesix/M1-SOC-Armbian-Build.git` |

**Deprecated (do not use):** `C:\Users\john.X86\Downloads\RKDevTool_Release_v2.86\...\Output\Armbian`

## Hardware

- Board: Artillery M1 Pro S1-SOC (RK3308BS)
- Flash tool: RKDevTool v2.86  ->  tab **Upgrade Firmware** (monolithic `.img` only)
- Serial: **UART3 @ 1500000**, console **`ttyFIQ0`** (fiq-debugger  -  same header as factory)
- LCD: 480x272 RGB panel-dpi
- WiFi: RTL8189FS (`8189fs.ko`)

## Current firmware line

| Item | Value |
|------|-------|
| **Target version** | **v46** (`v46-systemcfg-chroot`) |
| **Why v46** | v43 rootfs used `debugfs set_inode_field`  ->  ext4 inode corruption  ->  login loop |
| **v44** | Never built  -  redirects to v46 |
| **Flash image** | `releases/1.0.0/rk3308bs-1.0.0-emmc-fixed-v46.img` |
| **Alias** | `releases/1.0.0/rk3308bs-1.0.0-emmc-fixed.img` (copy of latest) |

**Do not flash v43**  -  known `Authentication failure` / `bogus i_mode (644)`.

## Where we left off (2026-06-13)

1. v46 rebuilt with **ttyFIQ0** console (DTB + rootfs getty)
2. Flash image ready: `releases/1.0.0/rk3308bs-1.0.0-emmc-fixed-v46.img` (2026-06-13 10:54)
3. **Next:** flash to board and verify serial, LCD, WiFi, login

## Quick commands

### Rebuild v46 only (rootfs + pack; reuses existing kernel Image)

```bash
cd /mnt/c/Workspaces/Armbian-M1-SOC
sudo -v
bash tools/run-build-v46.sh
# or pack-only if rootfs/boot already exist:
bash tools/finish-pack-v46.sh
```

### Flash (Windows)

1. MASKROM  ->  RKDevTool  ->  **Upgrade Firmware**
2. Select `releases\1.0.0\rk3308bs-1.0.0-emmc-fixed-v46.img`
3. Log must show `Gpt=1`, `Download rootfs`, `Download Firmware Success`

### Verify on board (serial @ 1500000, ttyFIQ0)

```bash
cat /etc/rk3308bs-release
uname -r
lsblk
dmesg | grep -E 'mmc|drm|8189|tsadc'
systemctl status serial-getty@ttyFIQ0.service
```

## v46 fix

GPT uses factory `rootfs:grow` at `0x17200` (v45 explicit size caused unnamed partition + mount panic).

## Pipeline map (v46)

```
rootfs-v11.img
   ->  patch-rootfs-v46-mount.sh   (chroot: users, system.cfg, ttyFIQ0 getty)
   ->  install-kernel-modules-debugfs-all.sh  (WiFi + DRM modules)
   ->  rootfs-v46.img
build-boot-v39.sh               (factory DTB + panel-dpi + ttyFIQ0 bootargs)
   ->  _boot-v39.img
stage-pack-v39.sh               (pack_input_v39/)
windows-pack-update.ps1         (AFPTool + RKImageMaker)
   ->  rk3308bs-1.0.0-emmc-fixed-v46.img
```

## Config (single source of truth)

Edit **`config.env`** before every build  -  this is how end users customize the distributable image:

| Setting | Variable |
|---------|----------|
| Username / password | `USER_NAME`, `USER_PASSWORD`, `ROOT_PASSWORD` |
| WiFi | `WIFI_SSID`, `WIFI_PASSWORD`, `WIFI_COUNTRY` |
| Locale / timezone | `LOCALE`, `TIMEZONE` |
| Serial console | `SERIAL_GETTY`, `SERIAL_BAUD` |

Values are baked in at compile/patch time. For public GitHub: use `config.env.example` with placeholders.

## If something breaks

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Login loop / `bogus i_mode` | Flashed v43 or partial update over grown eMMC | **Full flash v46** |
| Silent serial | Wrong console (ttyS3) or wrong baud | Use **ttyFIQ0 @ 1500000** |
| U-Boot `=>` / PXE | Truncated boot.img or bad header | Use `-emmc-fixed` (17 MB boot slot) |
| `Invalid DTB hash` | resource.img RSCE hash stale | Rebuild boot-v39+ |
| Thermal reboot loop | TSADC uncalibrated | v46 uses `rk3308bs-tsadc` in DTB |
| Blank LCD | DRM modules missing | Re-run module install script |
| Build can't find files | Old Downloads paths | Use scripts with `$SCRIPT_DIR` (v46 pipeline) |
| `cp: pack_input/package-file` | Old stage-pack script | Use `stage-pack-v39.sh` (copies from `factory_fresh/03_partitions`) |

## Key docs

| File | When to read |
|------|--------------|
| **RESUME_HERE.md** | This file  -  session pickup |
| **`.cursor/STATE.md`** | Machine-readable snapshot (update after builds) |
| **FLASH_RKDEVTOOL.md** | Flash failures, log patterns, version history |
| **EMMC_RELEASE.md** | Full Phase A/B pipeline |
| **THERMAL_RK3308BS.md** | TSADC / thermal issues |
| **config.env** | Credentials and build server |
| **QUICKSTART.md** | Fresh Armbian compile from Ubuntu server |

## After each successful build

Update **`.cursor/STATE.md`**:

- `last_build`, `firmware_version`, artifact paths, git commit, next step.

## Factory recovery

If board is bricked: flash factory `KLP_IMG_ARTILLERY_M1_PRO_S1-SOC_20251126_Beta.img`, then re-flash latest `-emmc-fixed-vNN.img`.
