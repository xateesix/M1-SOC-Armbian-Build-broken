#!/usr/bin/env python3
"""WS2812/NeoPixel test via GPIO0_A1 (bit 1) register bitbang on RK3308."""
import mmap
import os
import struct
import sys
import time

GPIO0_BASE = 0xFF220000
GPIO_DR = 0x00
GPIO_DDR = 0x04
PIN = 1  # GPIO0_A1
NUM_LEDS = int(sys.argv[1]) if len(sys.argv) > 1 else 8
PAGE_SIZE = 4096


def ns_delay(ns: int) -> None:
    end = time.perf_counter_ns() + ns
    while time.perf_counter_ns() < end:
        pass


class Gpio:
    def __init__(self) -> None:
        page_base = GPIO0_BASE & ~(PAGE_SIZE - 1)
        off = GPIO0_BASE - page_base
        self._fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
        self._mem = mmap.mmap(
            self._fd, PAGE_SIZE, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE, offset=page_base
        )
        self._off = off
        ddr = struct.unpack("<I", self._mem[off + GPIO_DDR : off + GPIO_DDR + 4])[0]
        ddr |= 1 << PIN
        self._mem[off + GPIO_DDR : off + GPIO_DDR + 4] = struct.pack("<I", ddr)

    def set(self, val: int) -> None:
        dr = struct.unpack("<I", self._mem[self._off + GPIO_DR : self._off + GPIO_DR + 4])[0]
        if val:
            dr |= 1 << PIN
        else:
            dr &= ~(1 << PIN)
        self._mem[self._off + GPIO_DR : self._off + GPIO_DR + 4] = struct.pack("<I", dr)

    def close(self) -> None:
        self._mem.close()
        os.close(self._fd)


def ws2812_bit(gpio: Gpio, bit: int) -> None:
    if bit:
        gpio.set(1)
        ns_delay(400)
        gpio.set(0)
        ns_delay(850)
    else:
        gpio.set(1)
        ns_delay(800)
        gpio.set(0)
        ns_delay(450)


def ws2812_pixel(gpio: Gpio, r: int, g: int, b: int) -> None:
    val = (g << 16) | (r << 8) | b
    for i in range(23, -1, -1):
        ws2812_bit(gpio, (val >> i) & 1)
    ns_delay(300)


def main() -> None:
    if not os.path.exists("/dev/mem"):
        print("ERROR: /dev/mem missing")
        sys.exit(1)
    colors = [
        (255, 0, 0, "RED"),
        (0, 255, 0, "GREEN"),
        (0, 0, 255, "BLUE"),
        (64, 64, 64, "WHITE"),
        (0, 0, 0, "OFF"),
    ]
    gpio = Gpio()
    print(f"NeoPixel test GPIO0_A1 pin {PIN}, {NUM_LEDS} LED(s)")
    try:
        for r, g, b, name in colors:
            print("FILL", name)
            for _ in range(NUM_LEDS):
                ws2812_pixel(gpio, r, g, b)
            time.sleep(1)
        print("NEOPIXEL_TEST_DONE")
    finally:
        gpio.close()


if __name__ == "__main__":
    main()
