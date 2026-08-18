#!/bin/bash
# Download and stage companion-host software used by the S1-SOC image.
#
# This preloads source trees and baseline config for KIAUH, Klipper,
# Moonraker, KlipperScreen, and Crowsnest so the build output already
# contains the companion stack inputs.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

STACK_ROOT="${STACK_ROOT:-/opt/rk3308bs/companion-stack}"
REPOS_ROOT="$STACK_ROOT/repos"
COMPANION_USER="${COMPANION_USER:-m1prox1}"
MOONRAKER_HOST="${MOONRAKER_HOST:-<MAIN_HOST_IP>}"
MOONRAKER_PORT="${MOONRAKER_PORT:-7125}"
CROWSNEST_PORT="${CROWSNEST_PORT:-8080}"

echo "[rk3308bs] Installing companion-stack build prerequisites ..."
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    ca-certificates \
    curl \
    git \
    python3 \
    python3-pip \
    python3-venv \
    rsync \
    unzip

echo "[rk3308bs] Staging companion software under $STACK_ROOT ..."
mkdir -p "$REPOS_ROOT"

clone_repo() {
    local url="$1"
    local dest="$2"

    if [[ -d "$dest/.git" ]]; then
        git -C "$dest" fetch --depth 1 origin >/dev/null 2>&1 || true
        git -C "$dest" reset --hard FETCH_HEAD >/dev/null 2>&1 || true
        return 0
    fi

    rm -rf "$dest"
    git clone --depth 1 "$url" "$dest"
}

clone_repo https://github.com/dw-0/kiauh.git "$REPOS_ROOT/kiauh"
clone_repo https://github.com/Klipper3d/klipper.git "$REPOS_ROOT/klipper"
clone_repo https://github.com/Arksine/moonraker.git "$REPOS_ROOT/moonraker"
clone_repo https://github.com/KlipperScreen/KlipperScreen.git "$REPOS_ROOT/KlipperScreen"
clone_repo https://github.com/mainsail-crew/crowsnest.git "$REPOS_ROOT/crowsnest"

mkdir -p /etc/rk3308bs /etc/skel/.config

cat >/etc/rk3308bs/companion-stack.env <<EOF
COMPANION_USER=$COMPANION_USER
STACK_ROOT=$STACK_ROOT
KIAUH_DIR=$REPOS_ROOT/kiauh
KLIPPER_DIR=$REPOS_ROOT/klipper
MOONRAKER_DIR=$REPOS_ROOT/moonraker
KLIPPERSCREEN_DIR=$REPOS_ROOT/KlipperScreen
CROWSNEST_DIR=$REPOS_ROOT/crowsnest
MOONRAKER_HOST=$MOONRAKER_HOST
MOONRAKER_PORT=$MOONRAKER_PORT
CROWSNEST_PORT=$CROWSNEST_PORT
EOF

cat >/etc/skel/.config/KlipperScreen.conf <<EOF
[printer M1ProX1]
moonraker_host=$MOONRAKER_HOST
moonraker_port=$MOONRAKER_PORT
EOF

cat >/etc/rk3308bs/companion-stack-readme.txt <<EOF
Companion stack staged during image build.

Repos:
  - $REPOS_ROOT/kiauh
  - $REPOS_ROOT/klipper
  - $REPOS_ROOT/moonraker
  - $REPOS_ROOT/KlipperScreen
  - $REPOS_ROOT/crowsnest

Edit /etc/rk3308bs/companion-stack.env after first boot to point KlipperScreen at the main Moonraker host if you did not bake that value at build time.
EOF

chown -R "$COMPANION_USER:$COMPANION_USER" "$STACK_ROOT" 2>/dev/null || true

echo "[rk3308bs] Companion stack staged"