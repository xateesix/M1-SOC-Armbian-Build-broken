#!/bin/bash
# RK3308 OS Audit Script

OUTPUT_DIR="rk3308_system_audit"
mkdir -p "$OUTPUT_DIR"
echo "Starting audit of your RK3308 board..."

# 1. Basic System Info
uname -a > "$OUTPUT_DIR/os_version.txt"
cat /etc/*-release > "$OUTPUT_DIR/distro_info.txt"

# 2. Hardware Inventory
echo "Grabbing hardware list..."
lshw -json > "$OUTPUT_DIR/hardware_inventory.json" 2>/dev/null
lsusb -v > "$OUTPUT_DIR/usb_devices.txt" 2>/dev/null
lspci -nnk > "$OUTPUT_DIR/pci_devices.txt" 2>/dev/null

# 3. CPU and Storage Info
cat /proc/cpuinfo > "$OUTPUT_DIR/proc_cpuinfo.txt"
cat /proc/meminfo > "$OUTPUT_DIR/proc_meminfo.txt"
lsblk -a > "$OUTPUT_DIR/block_devices.txt"

# 4. Driver and Module Secrets
echo "Exporting loaded drivers and modules..."
lsmod > "$OUTPUT_DIR/loaded_modules.txt"
ls -la /sys/class/ > "$OUTPUT_DIR/sys_class_devices.txt"

# 5. Export Current Device Tree (.dts states from Sysfs)
# The running state of the hardware is exposed dynamically by the kernel here
echo "Exporting running Device Tree configuration..."
if [ -d "/sys/firmware/devicetree/base" ]; then
    mkdir -p "$OUTPUT_DIR/device_tree"
    cp -r /sys/firmware/devicetree/base/* "$OUTPUT_DIR/device_tree/" 2>/dev/null
else
    echo "Device Tree structure is not exposed via sysfs on this kernel."
fi

# 6. Kernel Configuration & Log
cat /proc/cmdline > "$OUTPUT_DIR/kernel_cmdline.txt"
zcat /proc/config.gz > "$OUTPUT_DIR/kernel_config.txt" 2>/dev/null
dmesg > "$OUTPUT_DIR/dmesg_boot_log.txt"

# 7. Running Software/Services
echo "Listing running software and processes..."
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem > "$OUTPUT_DIR/running_processes.txt"
systemctl list-units --type=service --state=running > "$OUTPUT_DIR/running_services.txt"

# 8. Pin Control & GPIOs (Specific to SoC Pinmux)
echo "Grabbing current Pinmux/GPIO configuration..."
cat /sys/kernel/debug/pinctrl/*/pins > "$OUTPUT_DIR/pinctrl_pins.txt" 2>/dev/null
cat /sys/kernel/debug/pinctrl/*/pingroups > "$OUTPUT_DIR/pinctrl_pingroups.txt" 2>/dev/null
cat /sys/kernel/debug/pinctrl/*/pinmux-functions > "$OUTPUT_DIR/pinctrl_pinmux.txt" 2>/dev/null

echo "Audit complete! All logs and configuration files saved to ./$OUTPUT_DIR/"
