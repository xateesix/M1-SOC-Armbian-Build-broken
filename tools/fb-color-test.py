#!/usr/bin/env python3
"""Fill /dev/fb0 with solid colors on RK3308 simple-panel + rockchipdrm.

Keep fbcon bound: unbinding vtcon freezes the panel scanout buffer.
Stop getty@tty1 before drawing; restore console afterward.
"""
import mmap
import os
import struct
import subprocess
import sys
import time

FB = "/dev/fb0"
BLANK = "/sys/class/graphics/fb0/blank"
GETTY = "getty@tty1.service"


def stop_getty():
    subprocess.run(
        ["systemctl", "stop", GETTY],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def start_getty():
    subprocess.run(["systemctl", "start", GETTY], check=False)


def reset_tty():
    try:
        with open("/dev/tty0", "w") as tty:
            tty.write("\033c\033[3J\033[0m\033[2J\033[H")
            tty.flush()
    except OSError as exc:
        print("warn: could not reset tty0:", exc)


def read_fb_info():
    name = open("/sys/class/graphics/fb0/name").read().strip()
    vs = open("/sys/class/graphics/fb0/virtual_size").read().strip()
    bpp = int(open("/sys/class/graphics/fb0/bits_per_pixel").read().strip())
    stride = int(open("/sys/class/graphics/fb0/stride").read().strip())
    w, h = map(int, vs.split(","))
    return name, w, h, bpp, stride


def fill_fb(rgb, w, h, bpp, stride):
    r, g, b = rgb
    with open(FB, "r+b", buffering=0) as f:
        if bpp == 32:
            row = struct.pack("BBBB", b, g, r, 0) * w
        elif bpp == 16:
            val = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
            row = struct.pack("<H", val) * w
        else:
            sys.exit("unsupported bpp %d" % bpp)
        size = stride * h
        mem = mmap.mmap(f.fileno(), size, mmap.MAP_SHARED, mmap.PROT_WRITE | mmap.PROT_READ)
        for y in range(h):
            off = y * stride
            mem[off : off + len(row)] = row
        mem.flush()
        os.fsync(f.fileno())


def prepare_display():
    stop_getty()
    reset_tty()
    if os.path.exists(BLANK):
        open(BLANK, "w").write("0")


def restore_console(w, h, bpp, stride):
    """Repaint a clean text console after raw framebuffer fills."""
    fill_fb((0, 0, 0), w, h, bpp, stride)
    reset_tty()
    start_getty()
    time.sleep(0.5)
    reset_tty()


def main():
    prepare_display()
    name, w, h, bpp, stride = read_fb_info()
    print("fb0: name=%s size=%dx%d bpp=%d stride=%d" % (name, w, h, bpp, stride))

    for label, rgb in [
        ("RED", (255, 0, 0)),
        ("GREEN", (0, 255, 0)),
        ("BLUE", (0, 0, 255)),
        ("WHITE", (255, 255, 255)),
    ]:
        print("FILL " + label)
        fill_fb(rgb, w, h, bpp, stride)
        time.sleep(2)

    print("COLOR_TEST_DONE")
    print("RESTORE_CONSOLE")
    restore_console(w, h, bpp, stride)
    print("CONSOLE_RESTORED")


if __name__ == "__main__":
    main()