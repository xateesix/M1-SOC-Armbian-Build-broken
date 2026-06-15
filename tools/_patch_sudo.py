from pathlib import Path
p = Path(r"C:/Workspaces/Armbian-M1-SOC/tools/install-kernel-modules-chroot-display.sh")
text = p.read_text(encoding="utf-8")
needle = "sudo_cmd() {\n\tif sudo -n true"
insert = "sudo_cmd() {\n\tif [[ $EUID -eq 0 ]]; then\n\t\t\"$@\"\n\t\treturn 0\n\tfi\n\tif sudo -n true"
if needle not in text:
    raise SystemExit("needle not found")
p.write_text(text.replace(needle, insert, 1), encoding="utf-8", newline="\n")
print("patched")