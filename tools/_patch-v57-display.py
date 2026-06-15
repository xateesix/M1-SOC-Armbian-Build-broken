from pathlib import Path
p = Path(r"/mnt/c/Workspaces/Armbian-M1-SOC/tools/install-kernel-modules-chroot-display.sh")
text = p.read_text()
lines = [
    "\techo 'for fb in /sys/class/graphics/fb*/blank; do'",
    "\techo '  [[ -f \"$fb\" ]] && echo 0 >\"$fb\"'",
    "\techo 'done'",
    "\techo 'if command -v setterm >/dev/null && [ -c /dev/tty0 ]; then'",
    "\techo '  setterm -blank 0 -powerdown 0 -powersave off </dev/tty0 >/dev/tty0 2>/dev/null || true'",
    "\techo 'fi'",
    "\techo 'log \"fb-blank=$(cat /sys/class/graphics/fb0/blank 2>/dev/null || echo na)\"'",
]
insert = "\n".join(lines) + "\n"
marker = "\techo 'log \"panel-drv="
if marker not in text:
    raise SystemExit('marker missing')
p.write_text(text.replace(marker, insert + marker, 1))
print('display install patched')
