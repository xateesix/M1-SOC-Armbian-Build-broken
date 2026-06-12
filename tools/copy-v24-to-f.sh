#!/usr/bin/env bash
set -euo pipefail
F=/mnt/f/rk3308bs-v24
rm -rf "$F"
mkdir -p "$F"
cp -a /tmp/rk3308bs-v24-build/pack_input_v16 "$F/"
cp /tmp/rk3308bs-v24-build/rootfs-v24.img "$F/"
ls -la "$F/pack_input_v16/Image/"
