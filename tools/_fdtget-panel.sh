#!/bin/bash
REL="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0"
D="$REL/_fac-dtb-v39.dtb"
fdtget "$D" /panel compatible
fdtget "$D" /panel backlight 2>&1
fdtget "$D" /panel bus-format 2>&1
fdtget "$D" /panel/panel-timing clock-frequency hactive vactive 2>&1
fdtget "$D" /backlight compatible 2>&1
