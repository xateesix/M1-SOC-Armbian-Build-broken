# 📖 Armbian Build System  -  Complete Guide

## 🎯 What You Get

A **complete, professional Armbian build system** for your RK3308BS EVB that:
- ✅ Pre-configures WiFi (no manual setup needed)
- ✅ Sets root password automatically (no interactive prompt)
- ✅ Caches build files on server (2nd builds: 25 min vs 1st: 45 min)
- ✅ One config file for everything (`config.env`)
- ✅ Validates setup before building
- ✅ Handles all complexity automatically

---

## 📂 Files in This Folder

| File | Purpose |
|------|---------|
| **RESUME_HERE.md** ⭐ | **Session pickup**  -  where we left off, v45 pipeline, troubleshooting |
| **QUICKSTART.md** ⭐ | **First build**  -  3-step Armbian compile guide |
| **config.env** | Configuration (WiFi, password, server) |
| **build-enhanced.sh** | Main build script (automatic WiFi + password setup) |
| **setup-validate.sh** | Pre-build checker (before first build) |
| **README.md** | Complete documentation & troubleshooting |
| **IMPROVEMENTS.md** | What changed vs old build system |
| **GITHUB_SETUP.md** | Optional GitHub sync for collaboration |
| **rk3308bs-evb.conf** | Board metadata for Armbian |
| **rk3308bs-evb-amic-v11.dts** | Hardware device tree |
| **0001-*.patch** | Kernel patch to add DTB to build |
| **build.sh** | Old build script (keep for reference) |

---

## ⚡ Quick Start (5 Minutes)

### 1️⃣ Configure
```bash
cd Armbian
nano config.env

# Edit:
# - BUILD_SERVER_HOST = your Ubuntu machine name
# - WIFI_SSID / WIFI_PASSWORD = your network
# - ROOT_PASSWORD = your choice
```

### 2️⃣ Validate  
```bash
chmod +x setup-validate.sh
./setup-validate.sh
```

You should see: `✅ All Checks Passed!`

### 3️⃣ Build
```bash
chmod +x build-enhanced.sh
./build-enhanced.sh
```

Wait ~30 minutes. Image downloads when done.

### 4️⃣ Flash
Use **balenaEtcher** or Linux `dd` command (see QUICKSTART.md)

### 5️⃣ Boot
- Insert microSD into RK3308BS
- Connect power + USB
- WiFi auto-connects
- SSH: `ssh root@BOARD_IP` (password from config.env)

---

## 🔧 What's Different From Old System?

### Problem  ->  Solution

| Problem | Old Way | New Way |
|---------|---------|---------|
| **Long builds** | 45-90 min every time | 1st: 45 min, 2nd+: 25 min (caching) |
| **No WiFi config** | Manual SSH setup | Pre-configured, auto-connects |
| **No root password** | Interactive prompt | Pre-set, direct login |
| **Config scattered** | Multiple files | Single `config.env` |
| **Can't validate** | Hope it works | `setup-validate.sh` checks everything |

---

## 📊 Build Timeline

```
First Build:
  1. setup-validate.sh ........... 2 min (checks everything)
  2. build-enhanced.sh ........... 45 min (downloads toolchains+builds)
  3. Download image locally ....... 5 min
  ────────────────────────────────────
  Total: ~50 minutes

Later Builds (after DTS edits):
  1. ./build-enhanced.sh kernel .. 25 min (reuses cached toolchain)
  2. Download image .............. 5 min
  ────────────────────────────────────
  Total: ~30 minutes

Manual WiFi/password changes:
  (No rebuild needed - edit on device after boot)
```

---

## 🚨 Troubleshooting

**Q: SSH connection fails**
- Check Ubuntu server is running
- Verify hostname in config.env
- Run: `ssh xateesix@ubuntu-server` manually

**Q: Build takes forever**
- First build downloads ~2GB of toolchains (normal)
- Later builds much faster (cached)
- Check: `ssh xateesix@ubuntu-server tail -f ~/armbian-build/output/logs/*.log`

**Q: No serial output after flashing**
- Check UART3 connection (not UART0)
- Verify baud: 1500000 (unusual but correct)
- See README.md "Troubleshooting" section

**Q: WiFi not connecting**
- Check SSID/password in config.env match your network
- SSH to board: `systemctl restart wpa_supplicant`
- Check: `wpa_cli status`

See **README.md** for more troubleshooting

---

## 🎓 How It Works (Overview)

```
Windows Machine (You)          Ubuntu Server (Build)
    |                               |
    ├─ setup-validate.sh ──────────▶| (Checks SSH, disk space)
    |                               |
    ├─ config.env ─────────────────▶| (Read your settings)
    |                               |
    ├─ rk3308bs-evb.conf ──────────▶|
    |  + DTS + patch               | (Copy files)
    |                               |
    ├─ build-enhanced.sh ──────────▶| (Start build)
    |                               |
    |                        [Armbian Build]
    |                        ├─ Clone/update armbian-build/ (persistent)
    |                        ├─ Apply your DTS patch
    |                        ├─ Create WiFi overlay
    |                        ├─ Create password script
    |                        ├─ Compile kernel
    |                        ├─ Package rootfs
    |                        └─ Create image
    |                               |
    |◀──── Download Image ──────────┤
    |
  [Image]
  ├─ Kernel with custom DTS
  ├─ WiFi pre-configured
  └─ Root password pre-set
```

---

## 📝 Files You Should Know

### `config.env`  -  Your Settings (EDIT THIS)
```bash
BUILD_SERVER_HOST="ubuntu-server"    # Where Armbian builds
BUILD_SERVER_USER="xateesix"
BUILD_SERVER_PATH="/home/xateesix/armbian-build"

WIFI_SSID="YOUR_WIFI_SSID"                   # Pre-configured in image
WIFI_PASSWORD="mNhTYTeh#..."

ROOT_PASSWORD="YOUR_PASSWORD"           # Pre-set in image
```

### `build-enhanced.sh`  -  Main Build Script (RUN THIS)
- Validates setup
- Copies files to server via SSH
- Creates WiFi overlay
- Creates password setup script
- Runs Armbian build
- Downloads image

### `setup-validate.sh`  -  Pre-Build Check (RUN THIS FIRST)
- Checks all files exist
- Verifies SSH works
- Checks disk space
- Tests server connectivity

### `rk3308bs-evb-amic-v11.dts`  -  Hardware Definition
- GPIO mappings
- LCD controller setup
- Audio codec (I2S)
- WiFi chip definition
- Touch screen
- USB ports
- Regulators
- **Don't edit unless you know hardware design**

---

## 🎯 Next Steps

1. ✅ **Read QUICKSTART.md** (3-step overview)
2. ✅ **Edit config.env** (set your server/WiFi/password)
3. ✅ **Run setup-validate.sh** (verify everything)
4. ✅ **Run build-enhanced.sh** (start build, wait 30 min)
5. ✅ **Flash image** (balenaEtcher recommended)
6. ✅ **Boot board** (WiFi auto-connects, SSH works immediately)

---

## 🆘 Need Help?

| Question | See |
|----------|-----|
| How do I build? | **QUICKSTART.md** |
| What is each file? | **README.md**  ->  File Structure |
| Why did you change things? | **IMPROVEMENTS.md** |
| How do I set up GitHub? | **GITHUB_SETUP.md** |
| Build failed, what now? | **README.md**  ->  Troubleshooting |
| I want to modify DTS | **README.md**  ->  Advanced Usage |

---

## 📞 Support

- **Armbian Docs**: https://docs.armbian.com
- **Armbian Forum**: https://forum.armbian.com
- **Rockchip**: https://github.com/torvalds/linux/tree/master/arch/arm64/boot/dts/rockchip

---

## ✨ Key Insight

**This build system is designed around your feedback:**
- ✅ Persistent Armbian (not rebuilt every time)
- ✅ WiFi pre-configured (no manual setup)
- ✅ Root password automatic (no interactive prompt)
- ✅ Everything in one config file
- ✅ Single build script does it all

**You configure once, build many times. Future builds are fast.**

---

**Ready to build?  ->  Start with QUICKSTART.md** 🚀
