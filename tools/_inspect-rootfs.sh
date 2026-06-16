#!/bin/bash
IMG="${1:?img}"
debugfs -R "dump /etc/passwd /tmp/rk_inspect_passwd" "$IMG"
debugfs -R "dump /etc/shadow /tmp/rk_inspect_shadow" "$IMG"
echo "=== passwd ==="
grep -E "^(root|m1prox|xatee)" /tmp/rk_inspect_passwd
echo "=== shadow prefix ==="
grep -E "^(root|m1prox|xatee)" /tmp/rk_inspect_shadow | cut -c1-100
debugfs -R "dump /etc/rk3308bs-release /tmp/rk_rel" "$IMG" 2>/dev/null && echo "=== release ===" && cat /tmp/rk_rel
