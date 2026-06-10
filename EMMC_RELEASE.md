# RK3308BS eMMC release pipeline

Repeatable path from Armbian build to monolithic RKDevTool flash image with
**custom rootfs** (not factory rootfs), factory-compatible hardware support,
and version stamping for upgrades.

## Architecture (two phases)

| Phase | boot.img | rootfs | Status |
|-------|----------|--------|--------|
| **A (now)** | Factory LZ4 kernel + factory DTB | Custom Armbian + hardware overlay | Implemented |
| **B (next)** | Armbian kernel in Rockchip LZ4 + custom DTB in resource.img | Same custom rootfs | TODO |

Phase A keeps factory `boot.img` (only cmdline patched) because RK3308 U-Boot
requires LZ4 kernel inside the Android boot image format. Rootfs is fully yours.

Hardware in Phase A:
- Display/touch/LED/PWM: factory kernel + DTB (same as OEM)
- WiFi: `8189fs.ko` injected from factory rootfs into your rootfs at pack time
- Console: `ttyFIQ0` @ 1500000 (serial-getty enabled in rootfs overlay)

## Workflow for other users (same board)

### 1. One-time setup
```bash
# Extract WiFi module from factory dump (uses factory_fresh/03_partitions/rootfs.img)
./tools/extract-factory-modules.sh
```

### 2. Build custom rootfs (Armbian)
```bash
./build-enhanced.sh          # remote or local Armbian compile
```
Produces `Armbian-rk3308bs-*.img` with board DTS, WiFi, root password, hardware packages.

### 3. Pack monolithic eMMC update
```bash
./build-emmc-release.sh \
  --armbian ./Armbian-rk3308bs-*.img \
  --version 1.0.0
```
Creates:
- `releases/1.0.0/pack_input/` — staging (MiniLoader, parameter, manifest, **custom rootfs**)
- `releases/1.0.0/rk3308bs-1.0.0-emmc.img` — flash this in RKDevTool

Options:
- `--shrink` (default): smaller rootfs.img → faster flash
- `--skip-modules`: skip 8189fs injection (debug only)
- `--pack-only`: WSL staging only; run `windows-pack-update.ps1` on Windows

### 4. Flash
RKDevTool → **Upgrade Firmware** → `rk3308bs-1.0.0-emmc.img`

Use stable USB; allow **5–8 minutes** for rootfs write.

### 5. Verify on board
```bash
cat /etc/rk3308bs-release
cat /etc/rk3308bs/upgrade-manifest.txt
sudo ./RK3308_FACTORY_AUDIT.SH
```

## What is NOT in new images anymore

- Smoke v2 images used **factory rootfs.img** — valid for repack testing only
- New releases always use **Armbian-built rootfs** from step 2

## Upgrade path

Bump `--version 1.0.1`, rebuild rootfs if needed, re-run `build-emmc-release.sh`.
Full monolithic flash replaces rootfs + boot cmdline; same `parameter.txt` /
PARTUUID keeps partition layout stable.

## Files

| File | Purpose |
|------|---------|
| `build-enhanced.sh` | Build Armbian rootfs with board DTS + overlays |
| `pack-armbian-for-emmc.sh` | Extract rootfs, stamp version, stage pack_input |
| `build-emmc-release.sh` | Orchestrator (modules + pack + monolithic img) |
| `windows-pack-update.ps1` | AFPTool + RKImageMaker |
| `tools/extract-factory-modules.sh` | Pull 8189fs.ko for Phase A WiFi |
| `overlay-user/` | systemd getty, serial baud |
| `userpatches-chroot/20-rk3308bs-hardware.sh` | apt packages in rootfs |
| `factory_fresh/03_partitions/` | Bootloader blobs only (not rootfs) |
