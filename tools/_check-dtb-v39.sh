#!/bin/bash
REL="$PROJECT_ROOT/output/releases/1.0.0"
wc -c "$REL/_fac-dtb-v39.dtb"
fdtget "$REL/_fac-dtb-v39.dtb" /panel compatible
fdtget "$REL/_fac-dtb-v39.dtb" /panel/panel-timing clock-frequency 2>&1
fdtget "$REL/_fac-dtb-v39.dtb" /panel/display-timings native-mode 2>&1
