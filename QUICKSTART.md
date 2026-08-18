# QUICKSTART.md

## 🚀 Build Your Firmware in 3 Steps

### Step 1: Configure (One-time)
```bash
cd Armbian

# Edit your settings
nano config.env
```

Save and close. Check these are filled in:
- `BUILD_SERVER_HOST` = your Ubuntu machine
- `WIFI_SSID` and `WIFI_PASSWORD`
- `ROOT_PASSWORD`

### Step 2: Validate
```bash
chmod +x setup-validate.sh
./setup-validate.sh
```

You should see: `✅ All Checks Passed!`

### Step 3: Build
```bash
chmod +x build-enhanced.sh
./build-enhanced.sh
```

Wait ~30 minutes. Image downloads when done.

---

## 📝 Output

After a successful build, you'll have:
- `Armbian-unofficial_*_rk3308bs-evb_jammy_*.img` in the Armbian folder
- WiFi pre-configured (SSID: YOUR_WIFI_SSID)
- Root password set (no interactive prompt)

---

## 💾 Flash to Device

### Windows
1. Download [balenaEtcher](https://www.balena.io/etcher/)
2. Open, select image + microSD card
3. Click "Flash"
4. Insert microSD into RK3308BS board

### Linux
```bash
sudo dd if=Armbian-*.img of=/dev/sdX bs=4M status=progress && sync
```

---

## 🔧 After Flashing

1. Insert microSD into board
2. Connect power + USB
3. Wait ~30 seconds for boot
4. Check WiFi: `ping google.com` (should work)
5. SSH as root:
   ```bash
   ssh root@BOARD_IP  # Password from config.env
   ```

---

## 📖 For More Info
- README.md - Full documentation
- IMPROVEMENTS.md - What changed & why
- GITHUB_SETUP.md - Optional GitHub sync

---

## ⚡ Tips

**Quick rebuild after editing DTS:**
```bash
./build-enhanced.sh kernel
```
(Much faster, ~25 min instead of 45)

**Change WiFi later:**
```bash
ssh root@BOARD_IP
nano /etc/netplan/01-rk3308bs-wlan0.yaml
netplan apply
```

**View build log:**
```bash
tail -f build-remote.log
```

---

**Stuck?** See README.md "Troubleshooting"
