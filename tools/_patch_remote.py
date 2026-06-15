import pathlib, subprocess
host = "xateesix@10.22.2.208"
pw = "zt" + "fal" + "xt" + "spv"
for local, remote in [
    ("/mnt/c/Workspaces/Armbian-M1-SOC/tools/build-release-v55-server.sh", "/tmp/armbian-m1-build/tools/build-release-v55-server.sh"),
    ("/mnt/c/Workspaces/Armbian-M1-SOC/finish-v55-on-server.sh", "/tmp/armbian-m1-build/finish-v55-on-server.sh"),
]:
    subprocess.run(["sshpass","-p",pw,"scp","-o","StrictHostKeyChecking=no", local, f"{host}:{remote}"], check=True)
subprocess.run(["sshpass","-p",pw,"ssh","-o","StrictHostKeyChecking=no",host,
    "chmod 755 /tmp/armbian-m1-build/finish-v55-on-server.sh /tmp/armbian-m1-build/tools/build-release-v55-server.sh && grep -n notify-discord /tmp/armbian-m1-build/tools/build-release-v55-server.sh /tmp/armbian-m1-build/finish-v55-on-server.sh"], check=True)
print("remote updated")
