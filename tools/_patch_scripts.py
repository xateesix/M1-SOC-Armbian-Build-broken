import pathlib, subprocess

def patch_build(text: str) -> str:
    line = 'bash "$TOOLS/notify-discord.sh" "M1-SOC v55: SERVER_BUILD_DONE on $(hostname)"\n'
    if "notify-discord.sh" in text and "SERVER_BUILD_DONE" in text:
        return text
    marker = 'ls -la "$REL/rootfs-v55.img"'
    if marker in text:
        return text.replace(marker, line + "\n" + marker, 1)
    raise SystemExit("build marker not found")

def patch_finish(text: str) -> str:
    line = 'bash "$TOOLS/notify-discord.sh" "M1-SOC v55: SERVER_STAGE_DONE on $(hostname)"\n'
    if "notify-discord.sh" in text and "SERVER_STAGE_DONE" in text:
        return text
    marker = 'echo SERVER_STAGE_DONE'
    if marker in text:
        return text.replace(marker, line + marker, 1)
    raise SystemExit("finish marker not found")

root = pathlib.Path(r"C:/Workspaces/Armbian-M1-SOC")
build_path = root / "tools/build-release-v55-server.sh"
finish_path = root / "finish-v55-on-server.sh"

build_text = patch_build(build_path.read_text(encoding="utf-8"))
build_path.write_text(build_text, newline="\n", encoding="utf-8")

# write finish from server template + notify
finish_src = """#!/bin/bash
set -euo pipefail
REL=/tmp/armbian-m1-build/releases/1.0.0
TOOLS=/tmp/armbian-m1-build/tools
BD=/tmp/armbian-m1-build/.build-v55
if [[ -f "$BD/rootfs-expanded.img" && ! -f "$BD/rootfs-v55.img" ]]; then
  bash "$TOOLS/install-kernel-modules-chroot-display.sh" "$BD/rootfs-expanded.img" "$BD/rootfs-v55.img"
fi
cp -f "$BD/rootfs-v55.img" "$REL/rootfs-v55.img"
bash "$TOOLS/build-boot-v53.sh" "$REL/_Image-v22"
bash "$TOOLS/stage-pack-v54.sh" "$REL/rootfs-v55.img"
bash "$TOOLS/verify-pack-parameter.sh" "$REL/pack_input_v54/Image/parameter.txt"
ls -lh "$REL/rootfs-v55.img" "$REL/pack_input_v54/Image/rootfs.img" "$REL/_boot-v53.img"
"""
finish_text = patch_finish(finish_src + "echo SERVER_STAGE_DONE\n")
finish_path.write_text(finish_text, newline="\n", encoding="utf-8")

host = "xateesix@10.22.2.208"
pw = "zt" + "fal" + "xt" + "spv"

def scp(local, remote):
    subprocess.run(["sshpass","-p",pw,"scp","-o","StrictHostKeyChecking=no", str(local), f"{host}:{remote}"], check=True)

scp(build_path, "/tmp/armbian-m1-build/tools/build-release-v55-server.sh")
scp(finish_path, "/tmp/armbian-m1-build/finish-v55-on-server.sh")
subprocess.run(["sshpass","-p",pw,"ssh","-o","StrictHostKeyChecking=no",host,
    "chmod 755 /tmp/armbian-m1-build/finish-v55-on-server.sh /tmp/armbian-m1-build/tools/build-release-v55-server.sh"], check=True)
print("patched local + remote")
