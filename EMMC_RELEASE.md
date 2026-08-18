# RK3308BS eMMC release pipeline

Repeatable path from Armbian build to monolithic RKDevTool flash image with
**custom rootfs** and **custom boot.img** (Phase B).

## Architecture

| Phase | boot.img | rootfs | Status |
|-------|----------|--------|--------|
| **B (default)** | Armbian 6.18 kernel (LZ4) + custom DTB in resource.img | Custom Armbian + hardware overlay | **Implemented** |
| **A (legacy)** | Factory LZ4 kernel + factory DTB (cmdline patch only) | Same rootfs + factory `8189fs.ko` inject | `--factory-kernel` |

Phase B builds a Rockchip-format `boot.img` from your Armbian `Image` and
`rk3308bs-evb-amic-v11.dtb`. Factory is used only for bootloader blobs
(MiniLoader, uboot, parameter) and as a **template** for `resource.img` layout.

## Prerequisites (one-time)

```bash
cd factory_fresh
chmod +x unpack-boot.sh
./unpack-boot.sh    # creates 04_boot_unpacked/resource.img template
```

Install in WSL: `lz4`, `python3`, `device-tree-compiler`, `e2fsprogs`.

## Workflow

### 1. Build Armbian (kernel + rootfs + DTB)

```bash
./build-enhanced.sh
```

Produces `../Armbian-unofficial_*_Rk3308bs-evb_bookworm_*.img`.

**Important:** After DTS changes, rebuild Armbian so the image contains an
updated `rk3308bs-evb-amic-v11.dtb` (recovered v67 uses `ttyS3`; older factory notes mention `ttyFIQ0`).

### 2. Pack monolithic eMMC update (Phase B default)

```bash
sudo -v
./build-emmc-release.sh \
  --armbian ../Armbian-unofficial_*_Rk3308bs-evb_bookworm_*.img \
  --version 1.0.0
```

Creates:
- `releases/1.0.0/boot.img`  -  Armbian kernel + your DTB
- `releases/1.0.0/rootfs.img`  -  your Armbian rootfs
- `releases/1.0.0/rk3308bs-1.0.0-emmc.img`  -  flash in RKDevTool

Options:
- `--factory-kernel`  -  Phase A (factory boot.img + 8189fs module extract)
- `--no-shrink`  -  skip `resize2fs -M`
- `--pack-only`  -  WSL staging only; run `windows-pack-update.ps1` on Windows

### 3. Flash

RKDevTool  ->  **Upgrade Firmware**  ->  `rk3308bs-1.0.0-emmc.img`

Serial: **UART3 @ 1500000**, console **`ttyS3`** on recovered v67 artifacts (older factory notes mention `ttyFIQ0`).

### 4. Verify

```bash
cat /etc/rk3308bs-release    # BOOT_PHASE=armbian-kernel-custom-rootfs
uname -r                     # 6.18.x-current-rockchip64
sudo ./RK3308_FACTORY_AUDIT.SH
```

## Phase B tools

| Tool | Purpose |
|------|---------|
| `tools/build-armbian-bootimg.sh` | LZ4 kernel + resource.img + boot.img |
| `tools/pack-rockchip-bootimg.py` | Android boot image assembler |
| `tools/pack-resource-img.py` | Replace DTB inside factory resource.img template |
| `tools/extract-armbian-boot-artifacts.sh` | Pull Image + DTB from Armbian .img |

## WiFi (Phase B)

No factory `8189fs.ko` injection. WiFi comes from the **Armbian kernel**
(`rtl8189fs` / `8189fs.ko`) plus `firmware-realtek` matching rootfs
`/lib/modules/6.18.x-*`.

If WiFi fails after first boot, verify the RTL8189CS driver is enabled in the
Armbian kernel config and rebuild (`./build-enhanced.sh` or `./compile.sh kernel`).

## Legacy Phase A

```bash
./build-emmc-release.sh --factory-kernel --armbian ... --version 1.0.0
```

Uses factory kernel 5.10.160, `ttyFIQ0`, and optional factory module extract.
