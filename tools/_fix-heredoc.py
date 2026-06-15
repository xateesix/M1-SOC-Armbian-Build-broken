from pathlib import Path
p = Path(r"/mnt/c/Workspaces/Armbian-M1-SOC/tools/install-kernel-modules-chroot-display.sh")
text = p.read_text()
text = text.replace("<<'\"'\"'EOF'\"'\"'", "<<'EOF'")
text = text.replace("awk '\"'\"'{print $1}'\"'\"'", "awk '{print $1}'")
text = text.replace("printf '\"'\"'%s\\n\\n'\"'\"'", "printf '%s\\n\\n'")
p.write_text(text)
print('fixed')
