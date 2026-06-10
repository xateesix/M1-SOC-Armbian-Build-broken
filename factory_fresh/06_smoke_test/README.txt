Smoke test images v2 — fixes LZ4 kernel issue from v1
Updated: 2026-06-10

NOTE: Smoke images use FACTORY rootfs.img for repack/flash validation only.
Production releases must use build-emmc-release.sh with custom Armbian rootfs.
See EMMC_RELEASE.md in the repo root.

PROBLEM WITH v1 (SMOKE_TEST_serial_console.img)
  v1 rebuilt boot.img with mkbootimg + DECOMPRESSED kernel.
  Factory boot.img uses LZ4-compressed kernel — U-Boot expects that format.
  v1 likely did not boot or had no serial output.

v2 FIX
  Copy factory boot.img byte-for-byte, only patch the 512-byte cmdline field
  (offset 0x50). Kernel LZ4 + resource.img stay identical to factory.

FLASH ORDER (test in this order)

1) SMOKE_v2_repack_only.img
   boot.img = exact factory copy (empty cmdline in header, like original)
   Purpose: confirm repack/flash pipeline does not break a working system
   Expect: board behaves like factory firmware after flash

2) SMOKE_v2_fiq_console.img
   cmdline: console=ttyFIQ0 + earlycon (matches factory kernel CONFIG)
   Purpose: serial output on 3-pin header via fiq-debugger
   Serial: UART3 @ 1500000, jumper SERIAL

3) SMOKE_v2_ttyS3_console.img
   cmdline: console=ttyS3,1500000n8 + earlycon
   Purpose: standard Linux serial (Armbian-style)
   Serial: UART3 @ 1500000, jumper SERIAL

FLASH
  RKDevTool → Upgrade Firmware → pick image → Download Firmware Success

All files in: factory_fresh/06_smoke_test/
