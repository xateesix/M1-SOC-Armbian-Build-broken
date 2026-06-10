# Armbian Build for RK3308BS EVB

Complete firmware build system with **persistent Armbian repository**, **WiFi pre-configuration**, and **automated root password setup**.

## Quick Start

### 1. **Configure Settings** (One-time)

Edit `config.env` with your build server, WiFi, and root password:

```bash
# USB build server details
BUILD_SERVER_HOST="ubuntu-server"
BUILD_SERVER_USER="xateesix"
BUILD_SERVER_PATH="/home/xateesix/armbian-build"

# WiFi credentials (pre-configured in image)
WIFI_SSID="OurIOT"
WIFI_PASSWORD="mNhTYTeh#p3LnRw^Ln*N3VwiD"

# Root password (no interactive prompt needed on first boot)
ROOT_PASSWORD="ztfalxtspv"
```

### 2. **Build Firmware**

From Windows (or any machine with SSH):

```bash
chmod +x build-enhanced.sh
./build-enhanced.sh
```

**What happens:**
- ✅ SSH connects to your Ubuntu build server
- ✅ Clones/updates persistent `~/armbian-build` (reuses across builds)
- ✅ Copies your board config, DTS, and kernel patch
- ✅ Creates WiFi overlay with your credentials
- ✅ Builds kernel + full image (~25 mins)
- ✅ Downloads final image locally

### 3. **Flash to Device**

#### Option A: Windows (Easiest)
1. **balenaEtcher**: Download & open, select image + microSD card, click Flash
2. **Or SharpAdbHelper**: File → Write Image to SD Card

#### Option B: Linux/Mac
```bash
# Identify your microSD device
lsblk

# Flash (be CAREFUL with device selection!)
sudo dd if=Armbian-*_rk3308bs-evb*.img of=/dev/sdX bs=4M status=progress && sync
```

### 4. **First Boot**

1. Insert microSD into RK3308BS board
2. Connect USB + power
3. Serial console (UART3, 1500000 baud) shows boot output
4. Root login with password from `config.env`
5. WiFi auto-connects (SSID: OurIOT)

**Check WiFi:**
```bash
ip addr show
iwconfig wlan0
```

---

## File Structure

```
Armbian/
├── config.env                                 # Configuration (EDIT THIS)
├── build-enhanced.sh                          # Main build script (NEW)
├── build.sh                                   # Old build script (keep for reference)
├── rk3308bs-evb.conf                          # Board metadata
│   ├── rk3308bs-evb-amic-v11.dts              # Device tree source
│   └── 0001-arm64-dts-rockchip-...patch       # Kernel patch
└── README.md                                  # This file
```

---

## Configuration Details

### Board Config (`rk3308bs-evb.conf`)
- **SoC**: Rockchip RK3308BS (ARM Cortex-A35, 1104 MHz)
- **RAM**: 512 MB DDR3
- **Storage**: eMMC + microSD
- **Console**: UART3 @ 1500000 baud
- **U-Boot**: `evb-rk3308_defconfig`
- **Kernel**: rockchip64 current branch (6.18+)

### Device Tree (`rk3308bs-evb-amic-v11.dts`)
Includes:
- Memory map and clocks
- All GPIO LEDs (power, heartbeat)
- 4.3" RGB LCD (480×272) with PWM backlight
- Goodix GT911 capacitive touch (I2C3)
- RTL8189CS WiFi (SDIO with power sequence)
- RK3308 internal ACODEC (I2S2, mic + speakers)
- USB ports (1× OTG, 2× host)
- All voltage regulators (core, 3.3V, 1.8V, 1.05V)

---

## Advanced Usage

### Rebuild Kernel Only (Fast)
```bash
./build-enhanced.sh kernel
```
Skips full image build, just recompiles DTB (~5 mins).

### Use Local Armbian (if already cloned)
```bash
ARMBIAN_PATH=$HOME/armbian-build ./build-enhanced.sh
# OR edit config.env: BUILD_SERVER=local
```

### SSH Into Build Server During Build
```bash
ssh xateesix@ubuntu-server
cd ~/armbian-build
tail -f output/logs/*.log
```

### Manual Kernel Rebuild on Server
```bash
ssh xateesix@ubuntu-server
cd ~/armbian-build
EXPERT=yes PREFER_DOCKER=no ./compile.sh kernel rockchip64-current
```

---

## Troubleshooting

### No Serial Output After Flash
1. Check serial connection (UART3, not UART0)
2. Verify baud: 1500000 (unusual but correct for this board)
3. Verify DTB in image:
   ```bash
   ssh xateesix@ubuntu-server
   cd ~/armbian-build/output/images
   mkdir -p /tmp/chk && mount -o loop,offset=$((32768*512)) *.img /tmp/chk
   ls /tmp/chk/boot/dtb-*/rockchip/ | grep rk3308bs-evb
   umount /tmp/chk
   ```

### Build Fails on Server
```bash
ssh xateesix@ubuntu-server
cd ~/armbian-build
tail -100 output/logs/build.log
```

### WiFi Not Connecting
1. SSH to board: `ssh root@<ip>`
2. Check config: `cat /etc/wpa_supplicant/wpa_supplicant.conf`
3. Restart: `systemctl restart wpa_supplicant`
4. Monitor: `wpa_cli status`

### Root Password Not Working
Check that the chroot script ran:
```bash
ssh root@<board-ip>
cat /etc/shadow | grep root
# Should show SHA512 hash, not blank
```

---

## GitHub Integration (Optional)

To sync build artifacts and configs to GitHub:

```bash
cd Armbian
git init .
git remote add origin https://github.com/YOUR_USER/rk3308bs-armbian.git
git add -A
git commit -m "RK3308BS Armbian firmware"
git push -u origin master
```

Then sync on server:
```bash
ssh xateesix@ubuntu-server
cd ~/armbian-build
git clone https://github.com/YOUR_USER/rk3308bs-armbian.git overlay
# Copy overlay/* to userpatches/
```

---

## Hardware Specs

| Component | Details |
|-----------|---------|
| **SoC** | Rockchip RK3308BS (Cortex-A35 ×4, 1104 MHz max) |
| **RAM** | 512 MB DDR3 1.8V |
| **Storage** | 8GB eMMC (1.8V) + microSD |
| **Console** | UART3 (1500000 baud) |
| **Display** | 4.3" 480×272 RGB LCD, PWM backlight (GPIO_PWM9) |
| **Touch** | Goodix GT911 (I2C3) |
| **Audio** | RK3308 internal ACODEC, I2S2 data path |
| **WiFi** | RTL8189CS (SDIO, GPIO power sequence) |
| **USB** | 1× OTG Type-C + 2× 5V host (USB-A) |

---

## Support

For issues:
1. Check this README
2. Review build logs: `build-remote.log`
3. Check Armbian docs: https://docs.armbian.com
4. Armbian forum: https://forum.armbian.com

---

**Created**: June 2026  
**Board**: RK3308BS EVB  
**Kernel**: Linux rockchip64  
**Distro**: Ubuntu Jammy (22.04 LTS)
