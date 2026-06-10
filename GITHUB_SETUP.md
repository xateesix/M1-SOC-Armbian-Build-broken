# GitHub Setup for Cross-Device Collaboration

If you want to sync your Armbian build setup across devices or collaborate, use GitHub.

## One-Time Setup

### 1. Create GitHub Repository

Go to https://github.com/new

- **Repository name**: `rk3308bs-armbian` (or your preference)
- **Private**: ✓ (recommended for board configs)
- **Initialize with**: None (we'll push our files)

Copy the HTTPS URL: `https://github.com/YOUR_USER/rk3308bs-armbian.git`

### 2. Initialize Git in Armbian Folder

```bash
cd Armbian

# Initialize
git init

# Add all files
git add -A

# Commit
git commit -m "Initial RK3308BS Armbian firmware setup"

# Add remote (use your repo URL)
git remote add origin https://github.com/YOUR_USER/rk3308bs-armbian.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### 3. Update Build Script (Optional)

If using GitHub, add this to `build-enhanced.sh` for automatic GitHub sync:

```bash
# After successful build, push to GitHub
if [ -n "$GITHUB_REPO" ] && git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    cd "$SCRIPT_DIR"
    git add -A
    git commit --allow-empty -m "Build $(date +%Y-%m-%d_%H:%M:%S): WiFi=$WIFI_SSID kernel=6.18.35"
    git push origin main || warn "GitHub push failed (network?)"
fi
```

---

## Using on Build Server

### Clone on Ubuntu Server

```bash
ssh xateesix@ubuntu-server

# Clone your Armbian config repo
cd /tmp
git clone https://github.com/YOUR_USER/rk3308bs-armbian.git rk3308bs-conf

# Symlink into Armbian build
cd ~/armbian-build
ln -sf /tmp/rk3308bs-conf/userpatches/* userpatches/ 2>/dev/null || true
ln -sf /tmp/rk3308bs-conf/config/boards/* config/boards/ 2>/dev/null || true

# Done! Now all your overlays and board config is active
```

### Keep Sync'd

```bash
cd /tmp/rk3308bs-conf
git pull  # Get latest from your machine
```

---

## Collaborative Workflow

**You (Windows machine):**
```bash
cd Armbian
# Edit config.env or DTS
git add -A
git commit -m "Update WiFi config"
git push origin main
```

**Build server automatically syncs:**
```bash
ssh xateesix@ubuntu-server
cd /tmp/rk3308bs-conf && git pull
# Changes now live in ~/armbian-build
```

---

## Alternative: Push Build Outputs

To also store images in GitHub (if <100MB):

```bash
# In Armbian folder
git add Armbian-*_rk3308bs-evb*.img
git commit -m "Build output $(date)"
git push origin main
```

⚠️ For larger images, use GitHub Releases instead:
https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository

