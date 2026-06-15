# Rockchip platform reference (factory vs public SDKs)

Updated: 2026-06-13

## Factory image (Artillery M1 Pro)  -  what we have

Extracted reference only (actory_fresh/). **Original vendor SDK is not public.**

| Field | Factory value |
|-------|---------------|
| Hostname | linaro-alip |
| OS | Debian 11 (bullseye) on Rockchip Linaro/ALIP-style rootfs |
| Kernel | 5.10.160  -  
k3308_linux_defconfig |
| DTB model | Rockchip RK3308B-S evb analog mic v11 board |
| Boot format | LZ4 kernel in Android oot.img + 
esource.img DTB bundle |
| Console | 	tyFIQ0 @ 1500000 (fiq-debugger / UART3) |
| Root | PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 |
| GPT | Rockchip parameter.txt  -  
ootfs:grow at vendor offset |

Audit sources: 
k3308_system_audit/os_version.txt, .cursor/rk3308_factory_audit/

## What we do NOT have

- Artillery / Klipper vendor Linaro Linux SDK source (customized Rockchip BSP)
- Exact menson build tree that produced factory 5.10.160

## Closest public substitutes

Use these for **kernel defconfig, driver diff, partition layout, boot-chain patterns**  -  **not DTB/DTS** (factory only)  -  not as a drop-in replacement for Artillery userspace.

### Radxa (Rock Pi S  -  same RK3308)

| Resource | URL |
|----------|-----|
| Kernel | https://github.com/radxa/kernel (stable, linux-5.10-gen-rkr8-* branches) |
| BSP tool | https://github.com/radxa/bsp  -  profile 
ock-pi-s |
| Docs | https://wiki.radxa.com/RockpiS |
| Defconfig | 
k3308_linux_defconfig (matches factory audit string) |
| DTB | 
k3308-rock-pi-s.dtb  -  compare with actory_fresh/05_dts/ |

Local images (Downloads, not indexed): 
ock-pi-s_debian_*, Armbian_*_Rockpi-s_*

### T-Firefly (ROC-RK3308B  -  same RK3308B silicon family)

| Resource | URL |
|----------|-----|
| Wiki | https://wiki.t-firefly.com/en/ROC-RK3308B-CC-PLUS/linux_compile.html |
| SDK | Firefly_Linux_SDK via repo (
k3308_linux_release.xml) |
| Defconfig | irefly-rk3308b_linux_defconfig |
| DTS | 
k3308b-roc-cc-plus-amic_emmc  -  **closest public analog-mic EVB** |

Firefly and factory both use RK3308**B**-S EVB-style DTS naming (evb analog mic).

## How this project uses each source

| Need | Use |
|------|-----|
| Partition / flash / GPT | actory_fresh/03_partitions/ (ground truth for M1 Pro) |
| Serial / fiq-debugger / DTB | actory_fresh/05_dts/, factory audit |
| Kernel 6.18 + modules | Armbian build in this repo (uild-boot-v39.sh) |
| Rockchip boot.img pack | 	ools/stage-pack-v39.sh, patch-parameter-boot-size.py |
| Driver / DTS patterns (5.10) | Radxa kernel + Firefly DTS as **diff reference** |
| Embedded host UX (WiFi, system.cfg) | 
eference/CB1/, 
eference/BTT-build/ |

## Indexed paths

- actory_fresh/  -  Artillery factory blobs + DTS
- ../reference/BTT-build/  -  BTT Armbian fork
- ../reference/CB1/  -  CB1 docs
- This file + FLASH_GPT_DEBUG.md + INDEXING.md

## SDK download workflows (public)

### T-Firefly  -  repo-based SDK

Firefly publishes Rockchip BSPs via 
epo sync. The workflow is the same across SoCs; swap the manifest for RK3308:

| SoC | Manifest (example) | Wiki |
|-----|-------------------|------|
| RK3588 | 
k3588_linux_release.xml | [Download Firefly_Linux_SDK](https://wiki.t-firefly.com/en/Core-3588J/linux_sdk_get.html) |
| RK3308B | 
k3308_linux_release.xml | [ROC-RK3308B compile](https://wiki.t-firefly.com/en/ROC-RK3308B-CC-PLUS/linux_compile.html) |

Typical init (RK3308B, from Firefly wiki):

`ash
mkdir -p ~/proj/rk3308_sdk && cd ~/proj/rk3308_sdk
repo init --no-clone-bundle \
  --repo-url https://gitlab.com/firefly-linux/git-repo.git \
  -u https://gitlab.com/firefly-linux/manifests.git \
  -b master -m rk3308_linux_release.xml
.repo/repo/repo sync -c --no-tags
`

BSP-only (smaller): 
k3308_linux_bsp_release.xml  -  device/rockchip, kernel, u-boot, rkbin, tools.

Requirements: Ubuntu 18.04 x86_64 host, normal user (not root). Same constraints as [Core-3588J SDK guide](https://wiki.t-firefly.com/en/Core-3588J/linux_sdk_get.html).

### Radxa  -  kernel repositories

| Repo | SoC / use |
|------|-----------|
| [radxa/kernel](https://github.com/radxa/kernel) | **RK3308 Rock Pi S**  -  stable, 
k3308_linux_defconfig (matches factory) |
| [radxa/linux-rockchip](https://github.com/radxa/linux-rockchip) | Older Radxa **Rock / Rock2** series  -  general Rockchip vendor-kernel patterns, not RK3308-specific |
| [radxa/bsp](https://github.com/radxa/bsp) | Modern build orchestration  -  profile 
ock-pi-s for RK3308 |

For M1 Pro (RK3308BS), prefer **radxa/kernel** + factory DTS diff. Use **linux-rockchip** only for legacy Rockchip driver/patch archaeology.


## DTB policy (hard rule)

Ship only factory-derived DTB from factory_fresh/04_boot_unpacked/resource.img, patched by patch-dtb-bootargs.py.

Radxa, Firefly, Rock Pi S, and generic Armbian DTBs are known not to work on the M1 Pro. Diff/reference only  -  never build inputs.
