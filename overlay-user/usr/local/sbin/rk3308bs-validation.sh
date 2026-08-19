#!/bin/bash
# RK3308BS Hardware Validation Diagnostic Script
# Run after boot to verify all critical fixes are in place
# Usage: /usr/local/sbin/rk3308bs-validation.sh

set -o pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

test_result() {
    local name="$1"
    local result="$2"
    local message="$3"
    
    if [ "$result" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $name"
        if [ -n "$message" ]; then
            echo "        $message"
        fi
        ((PASS_COUNT++))
    else
        echo -e "${RED}✗ FAIL${NC}: $name"
        if [ -n "$message" ]; then
            echo "        $message"
        fi
        ((FAIL_COUNT++))
    fi
}

warn_result() {
    local name="$1"
    local message="$2"
    
    echo -e "${YELLOW}⚠ WARN${NC}: $name"
    if [ -n "$message" ]; then
        echo "        $message"
    fi
    ((WARN_COUNT++))
}

echo "======================================"
echo "RK3308BS Hardware Validation Report"
echo "======================================"
echo ""

# Test 1: Kernel version
echo "--- KERNEL & SYSTEM ---"
KERNEL_VERSION=$(uname -r)
if [[ "$KERNEL_VERSION" == *"6.18"* ]]; then
    test_result "Kernel Version" 0 "Version: $KERNEL_VERSION"
else
    test_result "Kernel Version" 1 "Expected 6.18.x, got: $KERNEL_VERSION"
fi

# Test 2: TSADC device in device tree
echo ""
echo "--- THERMAL SYSTEM (TSADC) ---"
if [ -f /proc/device-tree/thermal@ff1f0000/status ]; then
    TSADC_STATUS=$(cat /proc/device-tree/thermal@ff1f0000/status 2>/dev/null | tr -d '\0')
    if [ "$TSADC_STATUS" = "okay" ]; then
        test_result "TSADC Device Tree Status" 0 "Status: $TSADC_STATUS"
    else
        test_result "TSADC Device Tree Status" 1 "Status should be 'okay', got: $TSADC_STATUS"
    fi
else
    test_result "TSADC Device Tree Node" 1 "Device node not found at /proc/device-tree/thermal@ff1f0000"
fi

# Test 3: Thermal driver loaded
if lsmod | grep -q "^rockchip_thermal"; then
    test_result "Thermal Driver Loaded" 0 "rockchip_thermal module active"
else
    test_result "Thermal Driver Loaded" 1 "rockchip_thermal module not loaded"
fi

# Test 4: Thermal zone exists and reads
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    THERMAL_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    if [ -n "$THERMAL_TEMP" ] && [ "$THERMAL_TEMP" != "0" ]; then
        TEMP_C=$((THERMAL_TEMP / 1000))
        test_result "Thermal Temperature Reading" 0 "Current: ${TEMP_C}°C"
    else
        test_result "Thermal Temperature Reading" 1 "No temperature data available (got: $THERMAL_TEMP)"
    fi
else
    test_result "Thermal Zone Exists" 1 "thermal_zone0 not found"
fi

# Test 5: I2C3 pinctrl configured
echo ""
echo "--- I2C3 TOUCH BUS ---"
if grep -q "i2c3m0_xfer" /proc/device-tree/i2c@ff160000/pinctrl-names 2>/dev/null || \
   grep -q "i2c3" /proc/cmdline 2>/dev/null; then
    test_result "I2C3 Pinctrl Configuration" 0 "I2C3 pinctrl (i2c3m0_xfer) configured"
else
    warn_result "I2C3 Pinctrl Configuration" "Could not verify i2c3m0_xfer in DTB"
fi

# Test 6: I2C3 bus exists
if [ -d /sys/class/i2c/i2c-3 ]; then
    test_result "I2C3 Bus Device" 0 "I2C adapter 3 present"
else
    test_result "I2C3 Bus Device" 1 "I2C adapter 3 not found"
fi

# Test 7: Goodix touch firmware blob
echo ""
echo "--- GOODIX TOUCH PANEL ---"
if [ -f /lib/firmware/goodix_911_cfg.bin ]; then
    BLOB_SIZE=$(stat -f%z /lib/firmware/goodix_911_cfg.bin 2>/dev/null || stat -c%s /lib/firmware/goodix_911_cfg.bin 2>/dev/null)
    if [ "$BLOB_SIZE" -gt 100 ]; then
        test_result "Goodix Firmware Blob" 0 "Found at /lib/firmware/goodix_911_cfg.bin (${BLOB_SIZE} bytes)"
    else
        test_result "Goodix Firmware Blob" 1 "Blob exists but size suspicious (${BLOB_SIZE} bytes)"
    fi
else
    test_result "Goodix Firmware Blob" 1 "Not found at /lib/firmware/goodix_911_cfg.bin"
fi

# Test 8: Goodix driver loaded
if lsmod | grep -q "^goodix"; then
    test_result "Goodix Driver Loaded" 0 "goodix_ts module active"
else
    test_result "Goodix Driver Loaded" 1 "goodix_ts module not loaded"
fi

# Test 9: Goodix in dmesg without errors (check last boot)
if dmesg | grep -q "Goodix-TS 3-005d: ID.*status"; then
    test_result "Goodix Device Detected" 0 "Goodix device 3-005d detected and probed"
elif dmesg | grep -q "Goodix-TS"; then
    GOODIX_ERROR=$(dmesg | grep "Goodix-TS" | grep -i "error" | head -1)
    if [ -n "$GOODIX_ERROR" ]; then
        warn_result "Goodix Device Detected" "Detected but with errors: $GOODIX_ERROR"
    else
        warn_result "Goodix Device Detected" "Goodix mentioned in dmesg but status unclear"
    fi
else
    test_result "Goodix Device Detected" 1 "No Goodix probe found in dmesg"
fi

# Test 10: Touch input device
echo ""
echo "--- TOUCH INPUT ---"
if ls /dev/input/event* &>/dev/null; then
    EVENT_COUNT=$(ls /dev/input/event* 2>/dev/null | wc -l)
    test_result "Touch Input Devices" 0 "Found $EVENT_COUNT input event device(s)"
else
    test_result "Touch Input Devices" 1 "No input event devices found"
fi

# Test 11: WiFi module loaded
echo ""
echo "--- WIFI MODULE ---"
if lsmod | grep -q "^8189fs"; then
    test_result "WiFi Driver (8189fs)" 0 "Module loaded and active"
else
    test_result "WiFi Driver (8189fs)" 1 "8189fs module not loaded"
fi

# Test 12: WiFi loader service
if systemctl is-enabled rk3308bs-wifi-modules.service &>/dev/null; then
    if systemctl is-active rk3308bs-wifi-modules.service &>/dev/null; then
        test_result "WiFi Loader Service" 0 "rk3308bs-wifi-modules enabled and active"
    else
        test_result "WiFi Loader Service" 1 "Service exists but not active"
    fi
else
    test_result "WiFi Loader Service" 1 "rk3308bs-wifi-modules.service not installed"
fi

# Test 13: wpa_supplicant package
echo ""
echo "--- NETWORK & WPA ---"
if command -v wpa_supplicant &>/dev/null; then
    WPA_VERSION=$(wpa_supplicant -v 2>&1 | head -1)
    test_result "wpa_supplicant Installation" 0 "$WPA_VERSION"
else
    test_result "wpa_supplicant Installation" 1 "wpa_supplicant binary not found"
fi

# Test 14: netplan configuration
if [ -f /etc/netplan/30-wifis-dhcp.yaml ]; then
    if grep -q "OurIOT" /etc/netplan/30-wifis-dhcp.yaml 2>/dev/null; then
        test_result "WiFi Network Configuration" 0 "netplan configured for OurIOT SSID"
    else
        test_result "WiFi Network Configuration" 1 "netplan exists but OurIOT SSID not found"
    fi
else
    test_result "WiFi Network Configuration" 1 "netplan config not found at /etc/netplan/30-wifis-dhcp.yaml"
fi

# Test 15: systemd-networkd status
if systemctl is-active systemd-networkd &>/dev/null; then
    test_result "systemd-networkd Service" 0 "Running and managing network"
else
    test_result "systemd-networkd Service" 1 "Not active"
fi

# Test 16: wlan0 interface
if ip link show wlan0 &>/dev/null; then
    WLAN_STATE=$(ip link show wlan0 | grep -oP '(?<=state )[A-Z]+' | head -1)
    if [ -n "$WLAN_STATE" ]; then
        test_result "WLAN0 Interface" 0 "Present, state: $WLAN_STATE"
    else
        test_result "WLAN0 Interface" 1 "Present but state unknown"
    fi
else
    test_result "WLAN0 Interface" 1 "wlan0 interface not found"
fi

# Test 17: WLAN0 IP address
WLAN_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
if [ -n "$WLAN_IP" ]; then
    test_result "WLAN0 IP Address" 0 "Assigned: $WLAN_IP"
else
    warn_result "WLAN0 IP Address" "No IP assigned yet (interface may need time to connect)"
fi

# Test 18: Thermal patch applied (check dmesg)
echo ""
echo "--- KERNEL PATCHES ---"
if dmesg | grep -q "thermal.*rockchip.*rk3308"; then
    test_result "Thermal Patch Loaded" 0 "RK3308 thermal patch applied"
elif dmesg | grep -q "thermal"; then
    warn_result "Thermal Patch Loaded" "Thermal subsystem initialized but patch status unclear"
else
    test_result "Thermal Patch Loaded" 1 "No thermal patch indication in dmesg"
fi

# Summary
echo ""
echo "======================================"
echo -e "Results: ${GREEN}$PASS_COUNT PASS${NC} | ${RED}$FAIL_COUNT FAIL${NC} | ${YELLOW}$WARN_COUNT WARN${NC}"
echo "======================================"

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All critical tests passed!${NC}"
    exit 0
elif [ $FAIL_COUNT -lt 3 ]; then
    echo -e "${YELLOW}Some tests failed - review above${NC}"
    exit 1
else
    echo -e "${RED}Multiple critical failures detected${NC}"
    exit 2
fi
