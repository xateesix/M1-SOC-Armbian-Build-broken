#!/usr/bin/env bash
set -euo pipefail
cd /tmp/armbian-m1-logo-v56
python3 make-logo-bmp.py source.png logo.bmp
cp logo.bmp logo_kernel.bmp
TEMPLATE=resource.img
test -f _resource-v53.img && TEMPLATE=_resource-v53.img
python3 patch-resource-logos.py --template " \
