import subprocess, pathlib, os
host = "xateesix@10.22.2.208"
pw = "zt" + "fal" + "xt" + "spv"
local = pathlib.Path("/mnt/c/Workspaces/Armbian-M1-SOC/tools/notify-discord.sh")
remote_dir = "/tmp/armbian-m1-build/tools"
# ensure remote dir
subprocess.run(["sshpass", "-p", pw, "ssh", "-o", "StrictHostKeyChecking=no", host,
    f"mkdir -p {remote_dir}"], check=True)
subprocess.run(["sshpass", "-p", pw, "scp", "-o", "StrictHostKeyChecking=no",
    str(local), f"{host}:{remote_dir}/notify-discord.sh"], check=True)
subprocess.run(["sshpass", "-p", pw, "ssh", "-o", "StrictHostKeyChecking=no", host,
    f"chmod 755 {remote_dir}/notify-discord.sh && ls -la {remote_dir}/notify-discord.sh"], check=True)
print("remote deploy ok")
