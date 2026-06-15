# Flash / GPT debug notes (RK3308BS M1 Pro)

Updated: 2026-06-13

## Symptom

After wipe + full v45 flash (rk3308bs-1.0.0-emmc-fixed-v45.img):

- Boot GPT: boot @ 0xe800 size 0x8a00 (correct)
- Part 6 @ 0x17200 size 0xe28e00 NO NAME (wrong - expect rootfs @ 0x311800)
- Kernel cmdline: PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 + console=ttyFIQ0
- Panic: VFS Unable to mount root fs on PARTUUID

## RKDevTool log (good full flash)

- total=1677655552, Gpt=1
- rootfs offset=0x17200 size=1647312896 (~47-48 sec)

Bad partial flash: total=30342656, no rootfs line.

## Root cause hypothesis

v45 parameter.txt uses explicit: 0x00311800@0x00017200(rootfs)
Factory uses grow: -@0x00013000(rootfs:grow) + uuid:rootfs=614e0000-...

RKDevTool v3.32 writes rootfs data but on-device GPT is unnamed grow 0xe28e00.
Without name rootfs, uuid:rootfs line may not bind PARTUUID.

## Fix (v46 planned)

Use -@0x00017200(rootfs:grow) in patch-parameter-boot-size.py (factory pattern).

## Indexed references

- factory_fresh/03_partitions/parameter.txt
- ../reference/CB1/ and ../reference/BTT-build/
- Downloads/RKDevTool_Release_v3.32/.../Log/

## v46 fix applied

- stage-pack-v39.sh: removed `--rootfs` explicit size
- parameter: `-@0x00017200(rootfs:grow)` + uuid:rootfs
- Image: `rk3308bs-1.0.0-emmc-fixed-v46.img` ({now})
