# Companion setup: KlipperScreen + Crowsnest on the S1-SOC

The factory **S1-SOC** (this Armbian image) is a **secondary host**. It does **not** run Klipper for printer motion. It runs **KlipperScreen** and **Crowsnest** and talks to the **main Klipper host** (e.g. BTT Manta M4P + FYSETC H36) over the network.

Decouple UI and camera from the main instance: Moonraker stays on the motion stack; the companion only serves display and webcam streams.

**Status:** v0.64.1 provides the base OS, display, and network. KlipperScreen and Crowsnest install and autostart are **work in progress** on this image. The configuration below is the intended layout once those packages are on the companion.

## Prerequisites

| Item | Where |
|------|--------|
| Main Klipper + **Moonraker** running | Motion host (Manta M4P, etc.) |
| Companion image flashed | S1-SOC eMMC (`rk3308bs-1.0.0-emmc-fixed-v64.img`) |
| Same LAN | Both hosts reachable (WiFi or Ethernet) |
| Webcam (for Crowsnest) | USB camera on **companion** or routed as your build requires |

Note the **IP addresses**:

- `<MAIN_HOST_IP>`  -  Manta / Moonraker (example `192.168.1.50`)
- `<COMPANION_IP>`  -  S1-SOC (example `192.168.1.51`)

## Step 1: KlipperScreen on the companion (S1-SOC)

KlipperScreen only needs the **Moonraker API**. Do **not** install a Klipper MCU stack on the S1-SOC for printer control.

1. Install KlipperScreen on the companion (on Debian/Armbian, follow [KlipperScreen](https://github.com/KlipperScreen/KlipperScreen) docs or [KIAUH](https://github.com/dw-0/kiauh) if compatible with your image).
2. Edit KlipperScreen config (location varies by install; common paths):
   - `~/KlipperScreen/KlipperScreen.conf`
   - `~/.config/KlipperScreen.conf`
3. Point at the **main** Moonraker instance:

```ini
[printer M1ProX1]
moonraker_host: <MAIN_HOST_IP>
moonraker_port: 7125
```

4. Restart KlipperScreen. The **480x272** panel on the S1-SOC should show telemetry and controls for the printer on the motion host.

Multi-printer / remote Moonraker patterns: [KlipperScreen documentation](https://github.com/KlipperScreen/KlipperScreen) and guides on controlling multiple printers via Moonraker host settings.

## Step 2: Crowsnest on the companion (S1-SOC)

Crowsnest is an independent streaming server. It can run on the second host with **no Klipper** on that host.

References: [Running crowsnest on an external device (Mainsail Crew #2252)](https://github.com/orgs/mainsail-crew/discussions/2252)

1. Install Crowsnest on the S1-SOC (see [crowsnest](https://github.com/mainsail-crew/crowsnest) / KIAUH).
2. Edit `/etc/crowsnest.conf` on the **companion**  -  camera device, resolution, and stream port (commonly **8080**).
3. Start or restart Crowsnest and confirm the stream is live:

```text
http://<COMPANION_IP>:8080/webcam/?action=stream
```

## Step 3: Point Mainsail / Fluidd at the companion stream

Your **web UI runs on the main host** (or your usual browser target). Add the companion camera as an **external** webcam URL.

1. Open **Mainsail** or **Fluidd** (connected to Moonraker on `<MAIN_HOST_IP>`).
2. **Settings**  ->  **Webcams**  ->  add camera.
3. Stream URL:

```text
http://<COMPANION_IP>:8080/webcam/?action=stream
```

4. Save and refresh the dashboard.

The motion host serves Klipper/Moonraker; the companion serves video. Same pattern as multi-camera setups with a separate streaming device.

## Summary

```text
  [ Manta M4P + H36 ]          LAN          [ S1-SOC companion ]
  Klipper + Moonraker  <----------------->  KlipperScreen  ->  Moonraker API
       :7125                                  Crowsnest     ->  :8080 stream
       Mainsail/Fluidd  ----browser---->  webcam URL = COMPANION_IP:8080
```

## Related docs

- [`UPGRADE_PATH.md`](UPGRADE_PATH.md)  -  motion stack (Manta + H36)
- [`README.md`](README.md)  -  project overview
- [`SERIAL_CONSOLE.md`](SERIAL_CONSOLE.md)  -  debug without display/WiFi