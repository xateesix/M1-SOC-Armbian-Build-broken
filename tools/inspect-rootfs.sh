#!/usr/bin/env bash
IMG="${1:?rootfs img}"
echo "=== /etc/rk3308bs-release ==="
debugfs -R "cat /etc/rk3308bs-release" "$IMG" 2>/dev/null || echo "(missing)"
echo "=== serial-getty autologin ==="
debugfs -R "cat /etc/systemd/system/serial-getty@.service.d/autologin.conf" "$IMG" 2>/dev/null || echo "(missing)"
echo "=== serial-getty ttyS3 baud ==="
debugfs -R "cat /etc/systemd/system/serial-getty@ttyS3.service.d/baud1500000.conf" "$IMG" 2>/dev/null || echo "(missing)"
echo "=== getty override ==="
debugfs -R "cat /etc/systemd/system/getty@.service.d/override.conf" "$IMG" 2>/dev/null || echo "(missing)"
echo "=== securetty ttyS3 ==="
debugfs -R "dump /etc/securetty /tmp/securetty.$$" "$IMG" 2>/dev/null && grep ttyS3 /tmp/securetty.$$ && rm -f /tmp/securetty.$$
echo "=== shadow root/xateesix lines ==="
debugfs -R "dump /etc/shadow /tmp/shadow.$$" "$IMG" 2>/dev/null && grep -E '^(root|xateesix):' /tmp/shadow.$$ && rm -f /tmp/shadow.$$
echo "=== firstrun/resiz links ==="
debugfs -R "ls -l /etc/systemd/system/armbian-firstrun.service" "$IMG" 2>/dev/null || true
debugfs -R "ls -l /etc/systemd/system/armbian-resize-filesystem.service" "$IMG" 2>/dev/null || true
