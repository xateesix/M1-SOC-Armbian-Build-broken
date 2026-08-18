#!/bin/bash
REL="$PROJECT_ROOT/output/releases/1.0.0"
D="$REL/_fac-dtb-v39.dtb"
fdtget "$D" /panel compatible
fdtget "$D" /panel backlight 2>&1
fdtget "$D" /panel bus-format 2>&1
fdtget "$D" /panel/panel-timing clock-frequency hactive vactive 2>&1
fdtget "$D" /backlight compatible 2>&1
