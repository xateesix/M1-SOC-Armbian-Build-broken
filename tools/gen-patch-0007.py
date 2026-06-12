#!/usr/bin/env python3
from pathlib import Path

p = Path.home() / "linux-v13-build/drivers/gpu/drm/panel/panel-simple.c"
t = p.read_text()

if "#include <linux/backlight.h>" not in t:
    t = t.replace(
        "#include <linux/i2c.h>\n",
        "#include <linux/i2c.h>\n#include <linux/backlight.h>\n",
        1,
    )

t = t.replace(
    "dev_info(dev, \"panel-dpi %pOF %ux%u @ %lu Hz\\n\", np,\n"
    "\t\t timing->hactive.typ, timing->vactive.typ, timing->pixelclock);",
    "dev_info(dev, \"panel-dpi %pOF %ux%u @ %u Hz\\n\", np,\n"
    "\t\t timing->hactive.typ, timing->vactive.typ, timing->pixelclock.typ);",
)
t = t.replace(
    "\tvm.flags = timing->flags;\n"
    "\tdrm_bus_flags_from_videomode(&vm, &bus_flags);",
    "\tvideomode_from_timing(timing, &vm);\n"
    "\tdrm_bus_flags_from_videomode(&vm, &bus_flags);",
)

t = t.replace(
    "\tif (IS_ERR(desc))\n\t\treturn ERR_CAST(desc);\n\n\tpanel = devm_drm_panel_alloc",
    "\tif (IS_ERR(desc))\n\t\treturn ERR_CAST(desc);\n\n"
    "\tdev_info(dev, \"panel-simple probe %pOF\\n\", dev->of_node);\n"
    "\tpanel = devm_drm_panel_alloc",
    1,
)

t = t.replace(
    "\tpanel->enable_gpio = devm_gpiod_get_optional(dev, \"enable\",\n"
    "\t\t\t\t\t\t     GPIOD_OUT_LOW);\n"
    "\tif (IS_ERR(panel->enable_gpio))\n"
    "\t\treturn dev_err_cast_probe(dev, panel->enable_gpio,\n"
    "\t\t\t\t\t  \"failed to request GPIO\\n\");",
    "\tpanel->enable_gpio = devm_gpiod_get_optional(dev, \"enable\",\n"
    "\t\t\t\t\t\t     GPIOD_OUT_LOW);\n"
    "\tif (IS_ERR(panel->enable_gpio)) {\n"
    "\t\tif (PTR_ERR(panel->enable_gpio) == -EPROBE_DEFER) {\n"
    "\t\t\tdev_info(dev, \"enable GPIO defer, continuing without\\n\");\n"
    "\t\t\tpanel->enable_gpio = NULL;\n"
    "\t\t} else {\n"
    "\t\t\treturn dev_err_cast_probe(dev, panel->enable_gpio,\n"
    "\t\t\t\t\t\t  \"failed to request GPIO\\n\");\n"
    "\t\t}\n"
    "\t}",
    1,
)

t = t.replace(
    "\terr = drm_panel_of_backlight(&panel->base);\n"
    "\tif (err) {\n"
    "\t\tdev_err_probe(dev, err, \"Could not find backlight\\n\");\n"
    "\t\tgoto disable_pm_runtime;\n"
    "\t}\n\n"
    "\tdrm_panel_add(&panel->base);\n\n"
    "\treturn panel;",
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
    "\t}\n\n"
    "\tdrm_panel_add(&panel->base);\n"
    "\tdev_info(dev, \"panel-simple registered %pOF\\n\", dev->of_node);\n\n"
    "\treturn panel;",
    1,
)

p.write_text(t)
print("patched panel-simple.c for 0007")
