# RK3308BS thermal (TSADC)  -  factory vs Armbian 6.18

Your Artillery M1 Pro S1-SOC uses **RK3308BS** silicon (`chip_id:330800` in preloader; GRF chip ID **0x3308C**). The “SOC is barely warm but kernel reboots for temperature” bug is a **driver conversion-table mismatch**, not a broken sensor or missing flash.

## What factory firmware does (kernel 5.10)

Factory uses the vendor **`rockchip-thermal`** driver, not mainline as-shipped in vanilla 6.18.

| Piece | Factory behavior |
|-------|------------------|
| DTB | `tsadc@ff1f0000` + `otp@ff210000` + `thermal-zones/soc-thermal` with 115°C **critical** trip |
| OTP in DTB | `cpu-leakage@17`, `logic-leakage@18`, `id@7`  -  used for **CPU OPP / cpuinfo**, **not** TSADC trim cells in the factory DTB |
| TSADC trim in DTB | **None**  -  no `trim_l` / `trim_h` / `trim` on the tsadc node |
| Driver secret | On probe, vendor code calls `soc_is_rk3308bs()` and **replaces** the chip profile with `rk3308bs_tsadc_data` |

Vendor `rk3308bs_tsadc_data` (Rockchip 5.10 `drivers/thermal/rockchip_thermal.c`):

- **Linear conversion**: `kNum = 2699`, `bNum = 2796` (not the rk3328 lookup table)
- **One channel** (`chn_num = 1`) for BS
- **No** `get_trim_code`  -  trim from OTP is not required for BS when using this table
- dmesg: `rockchip-thermal ff1f0000.tsadc: tsadc is probed successfully!`

So factory “handles it” by **BS-specific math inside the kernel**, not by extra OTP nodes in the DTB you already ship.

## What Armbian 6.18 does today

Armbian’s `rockchip,rk3308-tsadc` support (backport of mainline/rpardini work) uses:

- **`rk3328_code_table`** lookup  -  correct for RK3328, **wrong for RK3308BS**
- Mainline 6.18 **`chip_tsadc_table` has no `kNum`/`bNum`** (vendor still has them)
- Same factory DTB  ->  raw ADC codes map to **absurdly high °C**  ->  instant `soc-thermal: critical` (115°C) or hardware TSHUT (~120°C)

That is why v9 - v11 (“factory OTP DTB”) still rebooted, and why v12 (passive critical trip) boots.

## Proper fix (match factory behavior)

Requires a **kernel patch**, then rebuild `linux-image-current-rockchip64` (or full Armbian image). DTB-only changes cannot fix the conversion table.

### Option A  -  Recommended (match vendor 5.10)

1. Patch `drivers/thermal/rockchip_thermal.c`:
   - Restore **`kNum` / `bNum`** in `struct chip_tsadc_table` and the linear paths in `rk_tsadcv2_code_to_temp` / `rk_tsadcv2_temp_to_code` (copy from Rockchip `develop-5.10`).
   - Add **`rk3308bs_tsadc_data`** with `kNum=2699`, `bNum=2796`, `chn_num=1`.
   - Either:
     - add compatible **`rockchip,rk3308bs-tsadc`**, or
     - on `rockchip,rk3308-tsadc` probe, read **GRF chip ID** at `0xff000800` and select BS table when ID is **0x3308C** (same as vendor `soc_is_rk3308bs()`).

2. Patch factory/resource DTB (optional): set tsadc compatible to `rockchip,rk3308bs-tsadc` if using separate compatible string.

3. **Remove** v12 `--disable-thermal-critical` so factory 115°C critical trip works again.

4. Rebuild boot.img + monolithic `.img`.

Patch template: `patches/0002-thermal-rockchip-rk3308bs-tsadc.patch` (apply under `userpatches/kernel/rockchip64-current/`).

### Option B  -  Workaround only (current v12)

- Keep `soc-crit` as passive / very high temp so Linux never emergency-reboots.
- Sensor readings in `/sys/class/thermal/` may still be nonsense; fine for Klipper if the board stays up.
- Hardware TSHUT may still exist if ADC reads stay above ~120°C  -  if you see reboot **after** `Welcome to Armbian`, next step is raising `rockchip,hw-tshut-temp` or disabling hw tshut in DTB.

## Verify after kernel fix

On serial (factory-style, should **not** trip at 1 s on a cold board):

```text
# cold boot, no "critical temperature reached" in first 5 s
cat /sys/class/thermal/thermal_zone0/temp   # expect ~30000 - 50000 (30 - 50°C) at idle
```

Compare with factory audit dmesg: `.cursor/rk3308_factory_audit/dmesg_full.txt` line 128  -  tsadc probes cleanly, no thermal panic.

## References in this repo

- Factory DTB: `factory_fresh/05_dts/rk3308-factory.dts` (`tsadc@ff1f0000`, `otp@ff210000`, trips)
- Factory dmesg: `.cursor/rk3308_factory_audit/dmesg_full.txt`
- v12 workaround: `tools/patch-dtb-bootargs.py --disable-thermal-critical`
- Board audit script (run on booted board): `RK3308_FACTORY_AUDIT.SH`
