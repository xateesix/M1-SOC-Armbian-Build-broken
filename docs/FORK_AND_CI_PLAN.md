# Fork upstream sources and GitHub CI plan

Companion firmware for Artillery M1 Pro X1 S1-SOC (RK3308BS). This document plans owning the full source stack: forks, patch queues, and automated rebuild on GitHub.

## Current pipeline (today)

```text
[Ubuntu build server]  build-enhanced.sh / Armbian compile.sh
        |  kernel patches (patches/*.patch) + board config + userpatches
        v
  rootfs-v61.img, _Image-v22, modules, uboot  -->  build-artifacts tarball
        |
[WSL / Windows]  tools/build-release-v64.sh
        |  boot DTB patches, rootfs debugfs, stage-pack, RKDevTool pack
        v
  rk3308bs-1.0.0-emmc-fixed-v64.img
```

The v64 line **repatches and repacks** GPL inputs; it does not recompile the kernel from zero unless inputs are regenerated on the build server.

## Target architecture

```text
                    +------------------+
                    |  This repo       |
                    |  M1-SOC-Armbian  |
                    |  - board DTS     |
                    |  - patches/      |
                    |  - userpatches   |
                    |  - tools/v64     |
                    |  - GitHub Actions|
                    +--------+---------+
                             |
         +-------------------+-------------------+
         |                   |                   |
         v                   v                   v
 +---------------+   +---------------+   +------------------+
 | fork:         |   | fork:         |   | fork (optional): |
 | armbian/build |   | linux stable  |   | rockchip rkbin   |
 |               |   | v6.18.y       |   | MiniLoader, etc. |
 +---------------+   +---------------+   +------------------+
```

### Repos to fork (under `xateesix` or org)

| Fork | Upstream | Role |
|------|----------|------|
| `M1-SOC-armbian-build` | `github.com/armbian/build` | Image compile framework, `compile.sh`, board hooks |
| `M1-SOC-linux` | `github.com/gregkh/linux` branch `linux-6.18.y` | Kernel + our `patches/*.patch` as commits or quilt series |
| `M1-SOC-Armbian-Build` (existing private) | — | Board integration, v64 pack pipeline, docs, release scripts |
| `M1Pro-SOC-Armbian-Public` (existing public) | export of sanitized tree + Releases |

Optional: vendor `factory_fresh` partition templates in this repo or a small `M1-SOC-rk3308-factory` submodule (Rockchip loader binaries are redistributable per vendor terms; document provenance).

## Patch strategy

| Layer | Location today | Fork strategy |
|-------|----------------|---------------|
| Kernel DTS + drivers | `patches/0001-0009`, `dts/` | Apply as git commits on `M1-SOC-linux` or export quilt series synced by CI |
| Armbian board | `rk3308bs-evb.conf`, `userpatches-*` | Pin in `M1-SOC-armbian-build` fork or copy into `userpatches/` on each sync |
| Boot DTB (display, lights) | `tools/patch-dtb-*.py`, `build-boot-v64.sh` | Stay in integration repo; inputs = kernel Image + factory resource |
| Rootfs companion | `patch-rootfs-public-credentials-debugfs.sh`, v64 debugfs | Stay in integration repo; public `m1prox1` / no WiFi |

**Rule:** forks hold **upstream-shaped** changes; integration repo holds **product** scripts (v64 pack, companion docs, release).

## GitHub Actions (proposed)

### Workflow 1: `sync-upstream.yml` (weekly + manual)

- Checkout forks with `actions/checkout`
- Subtree or scripted merge from upstream tags (`armbian` release branch, `linux-6.18.y`)
- Re-apply patch queue (fail PR if conflicts)
- Open auto-PR `upstream-sync-YYYY-MM-DD` for human review

### Workflow 2: `build-artifacts.yml` (self-hosted Linux runner)

**Runner:** same class as `10.22.2.208` Ubuntu (label `rk3308-builder`) with cached `armbian-build` tree.

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  armbian-image:
    runs-on: [self-hosted, rk3308-builder]
    steps:
      - checkout integration repo
      - source config.env.public.example
      - ./build-enhanced.sh   # or compile.sh board target
      - tools/make-build-artifacts-tarball.sh v0.64.1
      - upload-artifact: build-artifacts-v0.64.1.tar.gz
```

### Workflow 3: `build-companion-image.yml` (Windows self-hosted or matrix)

**Runner:** Windows with RKDevTool v2.86 (`label: rk3308-pack`)

```yaml
  companion-v64:
    runs-on: [self-hosted, Windows, rk3308-pack]
    needs: armbian-image
    steps:
      - download build-artifacts tarball
      - bash tools/rebuild-from-scratch-v64.sh   # WSL on runner
      - upload-artifact: rk3308bs-1.0.0-emmc-fixed-v64.img (or split if >2GB)
```

### Workflow 4: `release.yml` (on tag `v*`)

- Attach tarball + `.img` to GitHub Release on **public** repo (or private staging first)
- Run `tools/push-to-public.sh` for source-only export
- **Gate:** manual approval / only after test flash job passes

### Secrets

| Secret | Use |
|--------|-----|
| `BUILD_SSH_KEY` | self-hosted runner registration |
| `DISCORD_WEBHOOK_URL` | optional build notify (private repo only) |

No WiFi or user passwords in CI — use `config.env.public.example` only.

## Migration phases

### Phase 1 — Now (local)

- [x] `tools/rebuild-from-scratch-v64.sh` — clean v64 rebuild from `rootfs-v61-private.bak` + public credentials
- [x] `tools/patch-rootfs-public-credentials-debugfs.sh` — no-sudo public bake
- [ ] Flash-test image before any Release upload
- [ ] Commit integration scripts + `docs/FORK_AND_CI_PLAN.md`

### Phase 2 — Forks

1. Fork `armbian/build` and `linux` on GitHub
2. Push kernel patches as commits; tag `m1pro-v6.18.1-r1`
3. Document `BRANCH` / `KERNELBRANCH` pins in `config.env.example`
4. Set `FETCH_ARMBIAN_SOURCE=1` / `FETCH_KERNEL_SOURCE=1` to clone forks instead of upstream

### Phase 3 — Self-hosted CI

1. Register Ubuntu builder + Windows pack runner
2. Implement `build-artifacts.yml` + artifact cache
3. Implement companion pack job with RKDevTool v2.86 path

### Phase 4 — Upstream sync automation

1. `sync-upstream.yml` with conflict PRs
2. Optional: Dependabot-style weekly kernel stable tag check

## File size / Release constraints

- Monolithic `.img` is ~6.4 GB — **exceeds GitHub single-asset 2 GB limit**
- Options: self-hosted release mirror, split download, Git LFS + billing, or OCI bucket (S3/R2) with Release linking URL only

Plan: CI uploads tarball to release; `.img` hosted on external mirror until GitHub Large File Storage or chunking is configured.

## Local commands (maintainer)

```bash
# Full v64 from scratch (public credentials, all v64 patches)
bash tools/rebuild-from-scratch-v64.sh

# Full Armbian recompile (Ubuntu server)
./build-enhanced.sh

# Public export (no firmware in git)
bash tools/push-to-public.sh
```

## Open decisions

1. **Org vs personal forks** — single `xateesix` org for all forks?
2. **Kernel line** — stay on 6.18.y vs track Armbian `current` branch?
3. **Image hosting** — where to put 6 GB `.img` for public users?
4. **Test gate** — manual flash checklist vs automated hardware test runner?