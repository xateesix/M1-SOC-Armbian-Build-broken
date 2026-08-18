# Configure and build (v0.64.1)

Companion image for S1-SOC (KlipperScreen + Crowsnest). Motion Klipper runs on Manta/H36.

During build, the pipeline also bakes in the custom boot logo and stages companion software source trees (KIAUH, Klipper, Moonraker, KlipperScreen, Crowsnest) under `/opt/rk3308bs/companion-stack`.

```bash
./configure.sh
bash setup-validate.sh
bash tools/build-release-v64.sh
```

After flash, see [`COMPANION_SETUP.md`](COMPANION_SETUP.md) for Moonraker/Crowsnest wiring.

See [`README.md`](README.md) and [`FLASH_RKDEVTOOL.md`](FLASH_RKDEVTOOL.md).