import subprocess
host = "xateesix@10.22.2.208"
pw = "zt" + "fal" + "xt" + "spv"
for path in ["/tmp/armbian-m1-build/finish-v55-on-server.sh", "/tmp/armbian-m1-build/tools/build-release-v55-server.sh"]:
    r = subprocess.run(["sshpass","-p",pw,"ssh","-o","StrictHostKeyChecking=no",host,f"cat {path}"], capture_output=True, text=True)
    print("===== ", path, " =====")
    print(r.stdout)
