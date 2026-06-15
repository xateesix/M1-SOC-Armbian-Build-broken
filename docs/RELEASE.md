# GitHub Releases

## Firmware image

| Asset | Description |
|-------|-------------|
| `rk3308bs-1.0.0-emmc-fixed-v64.img` | Ready-to-flash monolithic eMMC image |

| Account | Username | Password |
|---------|----------|----------|
| Normal user | `m1prox1` | `m1prox1` |
| Root | `root` | `m1prox1` |

WiFi is not pre-configured. Change passwords after first boot.

## Build artifacts tarball

| Asset | Description |
|-------|-------------|
| `build-artifacts-v0.64.1.tar.gz` | GPL corresponding inputs for `build-release-v64.sh` |

```bash
./configure.sh                    # set BUILD_ARTIFACTS_URL
bash setup-validate.sh
bash tools/build-release-v64.sh
```

Tarball layout:

```text
releases/1.0.0/_Image-v22
releases/1.0.0/rootfs-v61.img
releases/1.0.0/_uboot-memlayout.img
releases/1.0.0/_modules_6.18.0-dirty/...
partition_templates/03_partitions/...
partition_templates/04_boot_unpacked/resource.img
```