#!/usr/bin/env python3
from pathlib import Path

p = Path.home() / "linux-v13-build/drivers/gpu/drm/panel/panel-simple.c"
t = p.read_text()

t = t.replace(
    "\tpm_runtime_enable(dev);\n"
    "\tpm_runtime_set_autosuspend_delay(dev, 1000);\n"
    "\tpm_runtime_use_autosuspend(dev);",
    "\t/* rk3308: autosuspend fires ~1s later and panics in run_timer_softirq */\n"
    "\tpm_runtime_disable(dev);",
    1,
)

# Drop optional backlight pointer hack; leave backlight unset at probe.
t = t.replace(
    "\t{\n"
    "\t\tstruct device_node *bl_np;\n\n"
    "\t\tbl_np = of_parse_phandle(dev->of_node, \"backlight\", 0);\n"
    "\t\tif (bl_np) {\n"
    "\t\t\tstruct backlight_device *bd;\n\n"
    "\t\t\tbd = of_find_backlight_by_node(bl_np);\n"
    "\t\t\tof_node_put(bl_np);\n"
    "\t\t\tif (bd)\n"
    "\t\t\t\tpanel->base.backlight = bd;\n"
    "\t\t\telse\n"
    "\t\t\t\tdev_info(dev, \"backlight not ready yet, continuing\\n\");\n"
    "\t\t}\n"
    "\t}\n\n",
    "",
    1,
)

p.write_text(t)
print("patched panel-simple.c for 0008")
