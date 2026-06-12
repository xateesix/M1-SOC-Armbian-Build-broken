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
static struct panel_desc *panel_simple_desc_from_timing(struct device *dev,
\t\t\t\t\t\tstruct display_timing *timing)
{
\tstruct panel_desc *desc;
\tstruct videomode vm;
\tunsigned int bus_flags;
\tu32 bus_format;

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

static struct panel_desc *panel_simple_from_display_timings(struct device *dev)
{
\tstruct device_node *timings_np;
\tstruct display_timings *timings;
\tstruct display_timing *timing;
\tstruct panel_desc *desc;
\tstatic const char * const fallback_names[] = { "timing3", "timing0", NULL };
\tint i;

\ttimings = of_get_display_timings(dev->of_node);
\tif (timings) {
\t\ttiming = display_timings_get(timings, timings->native_mode);
\t\tif (!timing)
\t\t\ttiming = display_timings_get(timings, 0);
\t\tif (!timing) {
\t\t\tdisplay_timings_release(timings);
\t\t\tdev_err(dev, "display-timings: no usable mode\\n");
\t\t\treturn ERR_PTR(-EINVAL);
\t\t}

\t\ttiming = devm_kmemdup(dev, timing, sizeof(*timing), GFP_KERNEL);
\t\tdisplay_timings_release(timings);
\t\tif (!timing)
\t\t\treturn ERR_PTR(-ENOMEM);

\t\treturn panel_simple_desc_from_timing(dev, timing);
\t}

\ttimings_np = of_get_child_by_name(dev->of_node, "display-timings");
\tif (!timings_np) {
\t\tdev_err(dev, "missing display-timings node\\n");
\t\treturn ERR_PTR(-ENODEV);
\t}

\ttiming = devm_kzalloc(dev, sizeof(*timing), GFP_KERNEL);
\tif (!timing) {
\t\tof_node_put(timings_np);
\t\treturn ERR_PTR(-ENOMEM);
\t}

\tfor (i = 0; fallback_names[i]; i++) {
\t\tif (!of_get_display_timing(timings_np, fallback_names[i], timing))
\t\t\tbreak;
\t}
\tof_node_put(timings_np);

\tif (fallback_names[i]) {
\t\tdesc = panel_simple_desc_from_timing(dev, timing);
\t\tif (!IS_ERR(desc))
\t\t\tdev_info(dev, "using fallback timing %s\\n", fallback_names[i]);
\t\treturn desc;
\t}

\tdev_err(dev, "failed to parse display-timings\\n");
\treturn ERR_PTR(-ENODEV);
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
