#!/usr/bin/env python3
"""Fix panel enable GPIO when rk3308 patch 0008 disables pm_runtime."""
from __future__ import annotations

import sys
from pathlib import Path

PATH = Path(sys.argv[1] if len(sys.argv) > 1 else "drivers/gpu/drm/panel/panel-simple.c")
text = PATH.read_text()

old_unprepare = """static int panel_simple_unprepare(struct drm_panel *panel)
{
\tint ret;

\tpm_runtime_mark_last_busy(panel->dev);
\tret = pm_runtime_put_autosuspend(panel->dev);
\tif (ret < 0)
\t\treturn ret;

\treturn 0;
}"""

new_unprepare = """static int panel_simple_unprepare(struct drm_panel *panel)
{
\tint ret = 0;

\tif (pm_runtime_enabled(panel->dev)) {
\t\tpm_runtime_mark_last_busy(panel->dev);
\t\tret = pm_runtime_put_autosuspend(panel->dev);
\t\tif (ret < 0)
\t\t\treturn ret;
\t} else {
\t\tret = panel_simple_suspend(panel->dev);
\t\tif (ret < 0)
\t\t\treturn ret;
\t}

\treturn 0;
}"""

old_prepare = """static int panel_simple_prepare(struct drm_panel *panel)
{
\tint ret;

\tret = pm_runtime_get_sync(panel->dev);
\tif (ret < 0) {
\t\tpm_runtime_put_autosuspend(panel->dev);
\t\treturn ret;
\t}

\treturn 0;
}"""

new_prepare = """static int panel_simple_prepare(struct drm_panel *panel)
{
\tint ret;

\tif (pm_runtime_enabled(panel->dev)) {
\t\tret = pm_runtime_get_sync(panel->dev);
\t\tif (ret < 0) {
\t\t\tpm_runtime_put_autosuspend(panel->dev);
\t\t\treturn ret;
\t\t}
\t} else {
\t\tret = panel_simple_resume(panel->dev);
\t\tif (ret < 0)
\t\t\treturn ret;
\t}

\treturn 0;
}"""

probe_needle = "\tpm_runtime_disable(dev);\n\n\tdrm_panel_add(&panel->base);"
probe_repl = """\tpm_runtime_disable(dev);

\t/* GPIO/regulator enable normally happens in runtime resume */
\tif (panel->enable_gpio)
\t\tgpiod_set_value_cansleep(panel->enable_gpio, 1);
\tif (panel->supply)
\t\tregulator_enable(panel->supply);

\tdrm_panel_add(&panel->base);"""

for old, new, name in (
    (old_unprepare, new_unprepare, "unprepare"),
    (old_prepare, new_prepare, "prepare"),
):
    if old not in text:
        raise SystemExit(f"panel-simple.c: {name} block not found")
    text = text.replace(old, new, 1)

if probe_needle not in text:
    raise SystemExit("panel-simple.c: probe pm_runtime_disable block not found")
text = text.replace(probe_needle, probe_repl, 1)

PATH.write_text(text)
print(f"Patched {PATH}")
