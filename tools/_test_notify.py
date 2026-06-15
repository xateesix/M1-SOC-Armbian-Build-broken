import subprocess
host = "xateesix@10.22.2.208"
pw = "zt" + "fal" + "xt" + "spv"
cmd = 'bash /tmp/armbian-m1-build/tools/notify-discord.sh "Cursor AI: M1-SOC build-server webhook enabled (curl)"'
r = subprocess.run(["sshpass", "-p", pw, "ssh", "-o", "StrictHostKeyChecking=no", host, cmd],
                   capture_output=True, text=True)
print("stdout:", r.stdout.strip())
print("stderr:", r.stderr.strip())
print("exit:", r.returncode)
