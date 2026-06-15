#!/bin/bash
echo enRmYWx4dHNwdg== | base64 -d > /tmp/.sshpw
chmod 600 /tmp/.sshpw
export SSHPASS=$(cat /tmp/.sshpw)
/usr/bin/sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@10.22.30.171 bash -s < /mnt/c/Workspaces/Armbian-M1-SOC/tools/rk_diag_full.sh
rm -f /tmp/.sshpw
