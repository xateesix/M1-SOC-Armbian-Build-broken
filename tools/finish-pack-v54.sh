#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
[[ -f "$REL/_boot-v53.img" ]] || bash "$TOOLS/build-boot-v53.sh"
bash "$TOOLS/patch-rootfs-v54-all.sh" "$REL/rootfs-v52.img" "$REL/rootfs-v54.img"
bash "$TOOLS/stage-pack-v54.sh" "$REL/rootfs-v54.img"
bash "$TOOLS/verify-pack-parameter.sh" "$REL/pack_input_v54/Image/parameter.txt"
echo "Run windows pack next"
