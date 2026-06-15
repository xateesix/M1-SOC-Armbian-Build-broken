#!/usr/bin/env python3
"""NeoPixel pin sweep: solid RED on each candidate DATA pin."""
import mmap
import os
import struct
import sys
import time

GPIO0_BASE = 0xFF220000
GPIO_DR = 0x00
GPIO_DDR = 0x04
PAGE_SIZE = 4096
NUM_LEDS = int(sys.argv[1]) if len(sys.argv) > 1 else 66
HOLD_SEC = float(sys.argv[2]) if len(sys.argv) > 2 else 5.0
PINS = [int(x) for x in (sys.argv[3].split(",") if len(sys.argv) > 3 else ["1", "17", "18"])]


def ns_delay(ns: int) -> None:
    end = time.perf_counter_ns() + ns
    while time.perf_counter_ns() < end:
        pass


class Gpio:
    def __init__(self, pin: int) -> None:
        self.pin = pin
        page_base = GPIO0_BASE & ~(PAGE_SIZE - 1)
        off = GPIO0_BASE - page_base
        self._fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
        self._mem = mmap.mmap(self._fd, PAGE_SIZE, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE, offset=page_base)
        self._off = off
        ddr = struct.unpack("<I", self._mem[off + GPIO_DDR : off + GPIO_DDR + 4])[0]
        ddr |= 1 << pin
        self._mem[off + GPIO_DDR : off + GPIO_DDR + 4] = struct.pack("<I", ddr)

    def set(self, val: int) -> None:
        dr = struct.unpack("<I", self._mem[self._off + GPIO_DR : self._off + GPIO_DR + 4])[0]
        if val:
            dr |= 1 << self.pin
        else:
            dr &= ~(1 << self.pin)
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
    val = (r << 16) | (g << 8) | b  # RGB per WLED
    for i in range(23, -1, -1):
        ws2812_bit(gpio, (val >> i) & 1)
    ns_delay(300)


def fill(gpio: Gpio, r: int, g: int, b: int, n: int) -> None:
    for _ in range(n):
        ws2812_pixel(gpio, r, g, b)


def main() -> None:
    for pin in PINS:
        print(f"SWEEP_START line={pin} color=RED leds={NUM_LEDS} hold={HOLD_SEC}s", flush=True)
        gpio = Gpio(pin)
        try:
            fill(gpio, 255, 0, 0, NUM_LEDS)
            time.sleep(HOLD_SEC)
            fill(gpio, 0, 0, 0, NUM_LEDS)
        finally:
            gpio.close()
        print(f"SWEEP_DONE line={pin}", flush=True)
        time.sleep(2)
    print("PIN_SWEEP_COMPLETE")


if __name__ == "__main__":
    main()
