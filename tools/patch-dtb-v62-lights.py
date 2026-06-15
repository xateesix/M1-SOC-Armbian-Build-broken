#!/usr/bin/env python3
"""Enable white LED light bar (PWM0) on factory RK3308 DTB.

Light bar: LED +/- header, PWM0 @ ff160000 (GPIO0_B5 / gpio line 13).
NeoPixel DATA: GPIO0_A1 (gpio line 1) on 3-pin header  -  userspace test script.
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


def _run(cmd: list[str]) -> None:
    subprocess.check_call(cmd)


def decompile(dtb: Path, dts: Path) -> None:
    _run(["dtc", "-I", "dtb", "-O", "dts", "-o", str(dts), str(dtb)])


def compile_dts(dts: Path, dtb: Path) -> None:
    _run(
        [
            "dtc", "-I", "dts", "-O", "dtb", "-o", str(dtb), str(dts),
            "-Wno-unit_address_vs_reg", "-Wno-graph_child_address",
        ]
    )


def _remove_subnode(text: str, name: str) -> str:
    needle = f"{name} {{"
    start = text.find(needle)
    if start < 0:
        return text
    line_start = text.rfind("\n", 0, start) + 1
    depth = 0
    i = text.find("{", start)
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                while end < len(text) and text[end] in " \t":
                    end += 1
                if end < len(text) and text[end] == ";":
                    end += 1
                if end < len(text) and text[end] == "\n":
                    end += 1
                return text[:line_start] + text[end:]
        i += 1
    return text


def _trim_bloat(text: str) -> str:
    for node in ("bluetooth-sound", "spdif-rx-sound", "spdif-tx-sound"):
        text = _remove_subnode(text, node)
    text = text.replace('\t\t\tdefault-state = "on";\n', "")
    return text


def _label_pwm0(text: str) -> str:
    if re.search(r"^\s*pwm0:\s*pwm@ff160000", text, re.M):
        return text
    return re.sub(r"(\s*)pwm@ff160000\s*\{", r"\1pwm0: pwm@ff160000 {", text, count=1)


def _enable_pwm0(text: str) -> str:
    m = re.search(r"(pwm0:\s*pwm@ff160000\s*\{)(.*?)(\n\t\};)", text, re.S)
    if not m:
        m = re.search(r"(pwm@ff160000\s*\{)(.*?)(\n\t\};)", text, re.S)
    if not m:
        raise RuntimeError("pwm@ff160000 node not found")
    head, inner, tail = m.group(1), m.group(2), m.group(3)
    if 'status = "okay"' not in inner:
        inner = re.sub(r'status\s*=\s*"disabled"\s*;', 'status = "okay";', inner, count=1)
        if 'status = "okay"' not in inner:
            inner = inner.rstrip() + '\n\t\tstatus = "okay";'
    return text[: m.start()] + head + inner + tail + text[m.end() :]


def _insert_lightbar(text: str) -> str:
    if "lightbar:white" in text:
        return text
    node = (
        "\n\tlightbar {\n"
        "\t\tcompatible = \"pwm-leds\";\n"
        "\t\tled-bar {\n"
        "\t\t\tlabel = \"lightbar:white\";\n"
        "\t\t\tpwms = <&pwm0 0 10000 0>;\n"
        "\t\t};\n"
        "\t};\n\n"
    )
    marker = '\n\tleds {\n\t\tcompatible = "gpio-leds";'
    if marker not in text:
        raise RuntimeError("root gpio-leds node not found")
    return text.replace(marker, node + marker, 1)


def patch(text: str) -> str:
    text = _trim_bloat(text)
    text = _label_pwm0(text)
    text = _enable_pwm0(text)
    text = _insert_lightbar(text)
    return text


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dtb", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()
    if not shutil.which("dtc"):
        print("error: dtc not found", file=sys.stderr)
        return 1
    dts = args.output.with_suffix(".lights.dts")
    decompile(args.dtb, dts)
    patched = patch(dts.read_text())
    dts.write_text(patched)
    compile_dts(dts, args.output)
    dts.unlink(missing_ok=True)
    print(f"v62 lights DTB: {args.output} ({args.output.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
