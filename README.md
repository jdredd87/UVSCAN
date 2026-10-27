# UVScan

<img src="res/artwork/uvscan.svg" alt="UVScan icon" width="112" align="right">

A data logger and scan tool for GM vehicles on **J1850 VPW (GM Class 2)**, using an **AVT‑838, 841 or 842** interface on a serial port, USB, or the network (an AVT with an Ethernet port), or an **ELM327** type adapter (Bluetooth, USB or Wi‑Fi) that supports VPW. Written for the 1996‑2005 GM V6s (3100 / 3400 / 3800), it works with any Class 2 PCM.

It is a rewrite of the 2008 UVSCAN (Delphi 2007) for **Delphi 13 FireMonkey (FMX)**, with no third‑party components. It runs on Windows (Win32) and builds for **Android** (64‑bit); the last VCL version is git tag `vcl-final`.

## Download

### [Windows setup and Android APK: latest release](https://github.com/jdredd87/UVSCAN/releases/latest)

On Windows, UVScan checks for a newer release itself and offers to install it, then starts again. The APK installs without the Play Store: see [installing on Android](docs/user-guide.md#installing-on-android).

![Live data](docs/images/live-data.png)

## What it does

- **Live data** — streams up to 48 bytes of PIDs from the PCM (about 10 updates a second for small selections), with min / max, calculated PIDs and AVT analog inputs. Rows go in the order you put them (also while scanning), readings are rounded to steady, readable decimals, the grid zooms from 75 % to 250 %, and the PID list folds by group and shows the update rate to expect.
- **Alerts** — per PID colours and green / yellow / red style alert levels that recolour the row, flash and sound an alarm (knock retard, coolant temperature, voltage, …).
- **Dashboard** — dial, bar and big‑number gauges using the same alert levels; several dashboards (one for each built‑in scan list), **full screen** as a virtual dash, one gauge filling the screen, and quick buttons on a tapped gauge to move or edit it.
- **Quick start** — one tap (or a desktop shortcut) to pick a scan list and dashboard, connect, scan, log and go full screen, retrying until the car answers.
- **Test display** — made‑up values sweep every PID through its range so colours, alerts and gauges can be tried without a car.
- **CSV logging** — F8 start / stop (also on the *Live* and *Gauges* bars), F9 pause, F12 to mark a moment in the log, the rows written counted in the status strip. Log names from a pattern (`Camaro_{date}_{n}` counts up per day), or asked for as a log starts.
- **Manage logs** — every log with its date, length and size: open, share (a phone's share sheet: Gmail, Drive...), rename, delete, or clear out the ones older than a week / month / year at once.
- **Send logs while logging** — for a crew away from the car: every few minutes (at most so many per log) the log so far, or only its new rows, zipped or not, and the whole log when it stops (or only then), by email (Gmail and others over TLS), or on Windows to a folder (a cloud drive's, a network share, a USB drive); tried again a set number of times, then that way stops with a notice while the log goes on. Turned on per drive.
- **Live view on the network** — the grid, the live chart, the dashboard and the status in a web browser on any phone, tablet or laptop on the same Wi-Fi, about four times a second, with nothing to install. The chart is what UVScan's live chart shows (its PIDs, scales, level bands, paused or live), and each device can pick its own PIDs for the grid and chart; read only.
- **Hotkeys** — connect, scan, log, pause, mark, full screen, live chart and the log viewer on keys you choose (F keys, media keys, Ctrl / Alt + letter), optionally working while another program has the focus.
- **Log viewer** — logs as a chart (lanes, or overlaid with each channel on its own scale) and a grid on one cursor, with real‑time playback at 0.25×‑20×, zoom and pan (also with − / + / All buttons), marks to jump between, alert colours on the line and in the grid, saved views (e.g. *MPH vs RPM vs IAT*), *Save selection* to trim a long log to the minute you need, and on a phone *Share* to send a log by email, to Google Drive, in a message or save a copy anywhere.
- **Vehicle & codes** — VIN, PCM OS ID, AVT firmware; trouble codes from every module, clear codes.
- **Real‑time controls** — GM device control (mode $AE): lamps, cooling fan, EVAP vent and fuel trim reset found and checked on a bench PCM, plus your own commands (on / off, hold to run, value, one‑shot).
- **PID tools** — PID editor with live formula check, import of old `PIDS.csv`, named scan lists, PID support test, and a search of the PCM for every PID it answers.
- **Sensors** — a wideband (Innovate LC‑1 / LC‑2 / LM‑2 / MTX‑L over MTS, AEM X‑Series, PLX iMFD modules, Zeitronix ZT‑2 / ZT‑3, Tech Edge), an EGT box or anything that sends numbers on a serial, Bluetooth or network port, read beside the car: its readings are PIDs, so they log, chart, show on gauges and set off alerts with the PCM's. Add one from a template or build your own on one page — test it live, add PIDs with formulas and calculated ones, and share it all as a file; [examples](examples/sensors/) include Arduino sketches to build your own.
- **Network AVT** — an AVT with an Ethernet port (or behind a serial‑to‑network adapter) over TCP/IP, from Windows or a phone.
- **ELM327 adapters** — Bluetooth (a phone or a PC), USB or Wi‑Fi, with the same DPID streaming at about 10 updates a second; only the AVT's analog inputs are missing. Tried with the vLinker FD over Bluetooth and a cheap Wi‑Fi clone, on a PC and on a phone.
- **Installer and updates** — a Windows setup program and an Android APK on the [releases page](https://github.com/jdredd87/UVSCAN/releases/latest); UVScan checks for a newer release once a day and offers to install it (*More → About*).
- **Simulator** — choose port *Simulator* to use everything without hardware, as an AVT or as an ELM327.

| | |
|---|---|
| ![Dashboard](docs/images/dashboard.png) | ![Display and alerts](docs/images/display-alerts.png) |
| ![Real-time controls](docs/images/controls.png) | ![PID editor](docs/images/pid-editor.png) |
| ![Log viewer, overlay](docs/images/log-viewer-overlay.png) | ![Log viewer, lanes](docs/images/log-viewer-lanes.png) |

Over a Wi‑Fi ELM327, on Windows and on a phone (a PCM on the bench, engine off):

<p>
<img src="docs/images/win-connect-wifi.png" width="560" alt="Connected to a Wi-Fi ELM327">
<img src="docs/images/phone-live-wifi.png" width="180" alt="Scanning and logging over Wi-Fi on a phone">
</p>

On a phone, upright and sideways, and on a tablet:

<p>
<img src="docs/images/phone-live.png" width="180" alt="Live data on a phone">
<img src="docs/images/phone-dashboard.png" width="180" alt="Dashboard on a phone">
<img src="docs/images/phone-log-viewer.png" width="180" alt="Log viewer on a phone">
<img src="docs/images/phone-land-dashboard.png" width="370" alt="Dashboard, phone sideways">
</p>

Short clips of it at work, on both platforms, are on the **[wiki](https://github.com/jdredd87/UVSCAN/wiki/Demos)**.

## Documentation

- **[User guide](docs/user-guide.md)** — every tab, dialog and setting, with screenshots and clips.
- **[Wiki](https://github.com/jdredd87/UVSCAN/wiki)** — demo clips, getting started on Windows and Android, phones and tablets.
- **[Data files](docs/data-files.md)** — the JSON files in `C:\ProgramData\UVScan` and the CSV log format.
- **[Protocol notes](docs/protocol.md)** — AVT framing, Class 2, DPID streaming and device control, as measured on a bench PCM.
- **[Development](docs/development.md)** — building, tests, simulator, the bench tool and the source layout.
- **[Testing with a network AVT](docs/network-avt-testing.md)** — a checklist for anyone with an AVT on Ethernet (not yet tried on a real one).

## Quick start

1. Install UVScan with the setup program from the [latest release](https://github.com/jdredd87/UVSCAN/releases/latest), or build `UVScan.exe` (below).
2. Connect the AVT to the PC and the vehicle, key on.
3. Pick the COM port (or **Network (TCP/IP)** and the AVT's address), **Connect**, tick PIDs on the left, **Start scan**.

Everything UVScan stores lives in `C:\ProgramData\UVScan` and is created from built‑in defaults on first run, so the exe needs nothing else. Installed for all users, the setup program gives Users modify rights on that folder (a folder created there by one user is read‑only for others).

Command line (as in the old UVSCAN): `UVScan.exe -port COM9 -connect -scan -log`; for a quick getaway, `UVScan.exe -list "Acceleration" -log -fullscreen -retry` or `-quick "Drag strip"` (see [Quick start](docs/user-guide.md#quick-start) — UVScan makes desktop shortcuts for these).

## Build

Delphi 13 (RAD Studio 37.0); Win32 Debug for now:

```
build.cmd
build.cmd android [install]
build.cmd android release
build.cmd installer
```

`build.cmd installer` builds the Win32 Release exe and its setup program (Inno Setup 6); `build.cmd android release`, the APK for a release, signed with the release key. `build.cmd` builds the app and the DUnitX tests, runs the tests, and builds the console tools (`tools\Win32\UVScanProbe.exe`, the bench tool, and `tools\Win32\UVScanSimServer.exe`, the simulator on the network). See [development](docs/development.md).

## Status

Tested against an AVT‑841 and a bench 2001 3.8L PCM (no engine). Still to check on a running vehicle: live values with the engine running, analog inputs, real trouble codes, clearing codes, VIN write, real‑time controls with real loads, and AVT extended‑length frames.
