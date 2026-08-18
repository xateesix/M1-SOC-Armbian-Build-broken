# Resume Here  -  RK3308BS Armbian (M1 Pro S1-SOC)

**Read this first** after a break, a failed build, or a new Cursor session.

## Project goal

Build a **distributable, reproducible, lean Armbian OS** for the Artillery M1 Pro S1-SOC (RK3308BS) that:

- **Fully supports onboard hardware**  -  LCD, touch, WiFi, serial, thermal, eMMC (everything needed on the printer)
- **Targets Klipper**  -  minimal rootfs, reliable boot, display + network for a printer host (not a general desktop)
- **Armbian-first by default**  -  normal first-boot user creation flow is the default. Optional pre-bake mode can inject username/password/WiFi from `config.env` when explicitly enabled.
- **Reproducible**  -  scripted pipeline from Armbian source  ->  patched rootfs  ->  monolithic eMMC image; same inputs produce the same output
- **Published publicly on GitHub**  -  `https://github.com/xateesix/M1-SOC-Armbian-Build.git` for others to fork, customize `config.env`, and build their own image

**Design principles:** lean (no bloat), hardware-complete, script-driven, config-driven, documented flash path. Current recovered baseline is the v67 thermal-fix packaging line reconstructed from surviving logs and artifacts after a lost agent session.

**Workspace assumption:** this environment is unstable; VS Code or the userspace may disappear at any time. Save durable state in tracked files and session artifacts, not only in live agent memory.

### Hardware support checklist (target state)

| Component | Status | Notes |
|-----------|--------|-------|
| eMMC boot/flash | Working | RKDevTool monolithic `.img`, 17 MB boot slot, Linux packer path recovered |
| Serial console | Reconfirm | Recovered v67 artifacts use UART3 @ 1500000 with **ttyS3** bootargs; older docs mention `ttyFIQ0` |
| 480x272 LCD | In progress | Factory boot path retained; on-device reconfirmation still needed |
| Goodix GT911 touch | Target | I2C3  -  verify on next v67 flash |
| RTL8189FS WiFi | In progress | Module baked; credentials from `config.env` |
| RK3308BS thermal | Recovered fix | Kernel patch `0002-thermal-rockchip-rk3308bs-tsadc.patch`; verify on-device again |
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

Public exports must be sanitized: no usernames, passwords, Wi-Fi data, IPs, hostnames, serial logs, or proprietary firmware blobs.

## Workspace

| | Path |
|---|------|
| **Windows** | `C:\Workspaces\Armbian-M1-SOC` |
| **WSL** | `/mnt/c/Workspaces/Armbian-M1-SOC` |
| **Recovered Linux workspace** | `/home/xateesix/scratch/Projects/rk3308bs-workspace/M1-SOC-Armbian-Build` |
| **Linux flash host** | `flashpc` / `10.22.2.22` |
| **Git remote** | `https://github.com/xateesix/M1-SOC-Armbian-Build.git` |

**Deprecated (do not use):** `C:\Users\john.X86\Downloads\RKDevTool_Release_v2.86\...\Output\Armbian`

## Hardware

- Board: Artillery M1 Pro S1-SOC (RK3308BS)
- Flash tool: RKDevTool v2.86  ->  tab **Upgrade Firmware** (monolithic `.img` only)
- Serial: **UART3 @ 1500000**; recovered v67 artifacts currently use **`ttyS3`** (older factory notes mention `ttyFIQ0`)
- LCD: 480x272 RGB panel-dpi
- WiFi: RTL8189FS (`8189fs.ko`)

## Current firmware line

| Item | Value |
|------|-------|
| **Target version** | **v67** (recovered thermal-fix line) |
| **Why v67** | Latest recovered eMMC artifact after the lost session; packaging completed on 2026-07-22 |
| **Thermal basis** | `0002-thermal-rockchip-rk3308bs-tsadc.patch` + rebuilt Armbian image |
| **Flash image** | `/home/xateesix/scratch/Projects/pack/releases/v67/rk3308bs-1.0.0-v67-emmc.img` |
| **Staging dir** | `/home/xateesix/scratch/Projects/pack/releases/v67/pack_input/` |

**Do not flash v43**  -  known `Authentication failure` / `bogus i_mode (644)`.

## Recovered state after lost session (2026-08-17)

1. Later work continued beyond the old v46 handoff; surviving artifacts show v64, v65, v66, and **v67** builds.
2. Latest recovered packaging success is logged in `output/smart-build/20260722-130656-2058017.summary.log`.
3. v67 succeeded via **Phase A factory boot.img cmdline patch** (`console=ttyS3,1500000n8` + root PARTUUID) and a 17 MB boot partition.
4. The full custom DTB/resource path hit a slot-size limit during recovery, so the final v67 artifact used the factory boot/resource path instead.
5. User-reported last lost-session outcome: successful eMMC image testing of the thermal management fix.
6. Linux flash host confirmed after recovery: **`flashpc` = `10.22.2.22`**.
7. **Next:** flash-test v67 again and record serial, LCD, Goodix, WiFi, and thermal behavior in `.cursor/STATE.md`.

## Quick commands

### Rebuild from source (current recovered path)

```bash
cd /home/xateesix/scratch/Projects/rk3308bs-workspace/M1-SOC-Armbian-Build
sudo -v
RELEASE_TAG=v68-next RK3308BS_TSADC=1 bash tools/build-from-source-linux.sh
# Re-pack an already staged release tag with Linux tools:
bash tools/pack-firmware-linux.sh v67 /home/xateesix/scratch/Projects/pack
```

### Flash (Windows)

1. MASKROM  ->  RKDevTool  ->  **Upgrade Firmware**
2. Copy `/home/xateesix/scratch/Projects/pack/releases/v67/rk3308bs-1.0.0-v67-emmc.img` to the Windows flash host and select that file in RKDevTool
3. Log must show `Gpt=1`, `Download rootfs`, `Download Firmware Success`

### Verify on board (serial @ 1500000, recovered v67 uses ttyS3)

```bash
cat /etc/rk3308bs-release
uname -r
lsblk
dmesg | grep -E 'mmc|drm|8189|tsadc'
cat /sys/class/thermal/thermal_zone0/temp
systemctl status serial-getty@ttyS3.service
```

## v67 packaging notes

Recovered v67 packaging keeps the factory-style `rootfs:grow` start at `0x17200`, expands boot to 17 MB, and patches the factory boot cmdline in place. This avoided the earlier GPT/mount problems and the later resource-slot overflow seen when trying to embed the larger custom DTB directly.

## Pipeline map (v67 recovered)

```
build-from-source-linux.sh      (injects 0001 DTS + 0002 thermal patch into Armbian build)
   ->  fresh Armbian image
build-emmc-release.sh --pack-only
   ->  rootfs.img + Phase A patched factory boot.img + pack_input/
pack-firmware-linux.sh
   ->  rk3308bs-1.0.0-v67-emmc.img
```

## Config (single source of truth)

Edit **`config.env`** before every build  -  this is how end users customize the distributable image:

| Setting | Variable |
|---------|----------|
| Username / password | `USER_NAME`, `USER_PASSWORD`, `ROOT_PASSWORD` |
| WiFi | `WIFI_SSID`, `WIFI_PASSWORD`, `WIFI_COUNTRY` |
| Locale / timezone | `LOCALE`, `TIMEZONE` |
| Serial console | `SERIAL_GETTY`, `SERIAL_BAUD` |

Default behavior keeps standard Armbian first-boot setup. To pre-bake credentials/WiFi, build with `--preconfigure-credentials` (or `PRECONFIGURE_CREDENTIALS=1`) and supply values via `config.env`.

## If something breaks

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Login loop / `bogus i_mode` | Flashed v43 or partial update over grown eMMC | **Do not use v43**; full flash recovered v67 |
| Silent serial | Wrong console or wrong baud | Recovered v67 uses **ttyS3 @ 1500000**; confirm before changing scripts |
| U-Boot `=>` / PXE | Truncated boot.img or bad header | Use monolithic v67 image with 17 MB boot slot |
| DTB/resource packing failure | Custom DTB exceeds factory resource slot | Use recovered Phase A factory boot path or shrink DTB |
| Thermal reboot loop | TSADC conversion mismatch | Rebuild with `0002-thermal-rockchip-rk3308bs-tsadc.patch` enabled |
| Blank LCD | DRM modules missing | Re-run module install script |
| Build can't find files | Old Downloads paths | Use scripts with `$SCRIPT_DIR` and current workspace paths |
| Missing monolithic pack output | Windows pack path drift or stale legacy tool path | Use `tools/pack-firmware-linux.sh` or verify `windows-pack-update.ps1` inputs |

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
