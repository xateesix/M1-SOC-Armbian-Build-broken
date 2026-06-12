#!/usr/bin/env python3
"""Generate 0004-panel-simple patch by editing kernel tree and running git diff."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

KERNEL = Path.home() / "linux-v13-build"
PANEL = KERNEL / "drivers/gpu/drm/panel/panel-simple.c"
OUT = Path(__file__).resolve().parents[1] / "patches/0004-panel-simple-simple-panel-compat.patch"

FUNC = """
/* Factory RK3308 DT uses legacy "simple-panel" + display-timings (5.10 binding). */
static struct panel_desc *panel_simple_from_display_timings(struct device *dev)
{
\tstruct display_timings *timings;
\tstruct display_timing *timing;
\tstruct panel_desc *desc;
\tstruct videomode vm;
\tunsigned int bus_flags;
\tu32 bus_format;

\ttimings = of_get_display_timings(dev->of_node);
\tif (!timings)
\t\treturn ERR_PTR(-ENODEV);

\ttiming = display_timings_get(timings, timings->native_mode);
\tif (!timing)
\t\ttiming = display_timings_get(timings, 0);
\tif (!timing) {
\t\tdisplay_timings_release(timings);
\t\treturn ERR_PTR(-EINVAL);
\t}

\ttiming = devm_kmemdup(dev, timing, sizeof(*timing), GFP_KERNEL);
\tdisplay_timings_release(timings);
\tif (!timing)
\t\treturn ERR_PTR(-ENOMEM);

\tdesc = devm_kzalloc(dev, sizeof(*desc), GFP_KERNEL);
\tif (!desc)
\t\treturn ERR_PTR(-ENOMEM);

\tdesc->timings = timing;
\tdesc->num_timings = 1;
\tdesc->bpc = 8;
\tdesc->connector_type = DRM_MODE_CONNECTOR_DPI;
\tif (!of_property_read_u32(dev->of_node, "bus-format", &bus_format))
\t\tdesc->bus_format = bus_format;

\tvideomode_from_timing(timing, &vm);
\tdrm_bus_flags_from_videomode(&vm, &bus_flags);
\tdesc->bus_flags = bus_flags;

\tof_property_read_u32(dev->of_node, "width-mm", &desc->size.width);
\tof_property_read_u32(dev->of_node, "height-mm", &desc->size.height);

\treturn desc;
}

"""


def main() -> int:
    subprocess.check_call(["git", "-C", str(KERNEL), "checkout", "-f", "v6.18"])
    text = PANEL.read_text()
    needle = "\treturn desc;\n}\n\n#define PANEL_SIMPLE_BOUNDS_CHECK"
    if needle not in text:
        print("needle1 missing", file=sys.stderr)
        return 1
    text = text.replace(needle, "\treturn desc;\n}\n\n" + FUNC + "#define PANEL_SIMPLE_BOUNDS_CHECK", 1)
    needle2 = (
        '\t\t\tif (of_device_is_compatible(dev->of_node, "panel-dpi"))\n'
        "\t\t\t\treturn panel_dpi_probe(dev);\n"
        "\t\t\telse\n"
        "\t\t\t\treturn ERR_PTR(-ENODEV);"
    )
    repl2 = (
        '\t\t\tif (of_device_is_compatible(dev->of_node, "panel-dpi"))\n'
        "\t\t\t\treturn panel_dpi_probe(dev);\n"
        '\t\t\tif (of_device_is_compatible(dev->of_node, "simple-panel"))\n'
        "\t\t\t\treturn panel_simple_from_display_timings(dev);\n"
        "\t\t\telse\n"
        "\t\t\t\treturn ERR_PTR(-ENODEV);"
    )
    if needle2 not in text:
        print("needle2 missing", file=sys.stderr)
        return 1
    text = text.replace(needle2, repl2, 1)
    text = text.replace(
        '\tpanel->supply = devm_regulator_get(dev, "power");',
        '\tpanel->supply = devm_regulator_get_optional(dev, "power");',
        1,
    )
    needle3 = (
        "\t}, {\n"
        "\t\t/* Must be the last entry */\n"
        '\t\t.compatible = "panel-dpi",\n'
    )
    repl3 = (
        "\t}, {\n"
        '\t\t.compatible = "simple-panel",\n'
        "\t\t.data = NULL,\n"
        "\t}, {\n"
        "\t\t/* Must be the last entry */\n"
        '\t\t.compatible = "panel-dpi",\n'
    )
    if needle3 not in text:
        print("needle3 missing", file=sys.stderr)
        return 1
    text = text.replace(needle3, repl3, 1)
    PANEL.write_text(text)
    diff = subprocess.check_output(
        ["git", "-C", str(KERNEL), "diff", "drivers/gpu/drm/panel/panel-simple.c"],
        text=True,
    )
    OUT.write_text(diff)
    print(f"Wrote {OUT} ({len(diff.splitlines())} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
