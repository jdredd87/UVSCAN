# UVScan

A data logger and scan tool for GM vehicles on **J1850 VPW (GM Class 2)**, using an **AVT‑841** (or 838 / 842) interface on a serial port. Written for the 1996‑2005 GM V6s (3100 / 3400 / 3800), it works with any Class 2 PCM.

It is a rewrite of the 2008 UVSCAN (Delphi 2007, kept in [`legacy/`](legacy) for reference) for **Delphi 13 FireMonkey (FMX)**, with no third‑party components. It runs on Windows (Win32) and builds for **Android** (64‑bit); the last VCL version is git tag `vcl-final`.

![Live data](docs/images/live-data.png)

## What it does

- **Live data** — streams up to 48 bytes of PIDs from the PCM (about 10 updates a second for small selections), with min / max, calculated PIDs and AVT analog inputs. The grid zooms from 75 % to 250 %.
- **Alerts** — per PID colours and green / yellow / red style alert levels that recolour the row, flash and sound an alarm (knock retard, coolant temperature, voltage, …).
- **Dashboard** — dial, bar and big‑number gauges using the same alert levels.
- **Test display** — made‑up values sweep every PID through its range so colours, alerts and gauges can be tried without a car.
- **CSV logging** — F8 start / stop, F9 pause.
- **Log viewer** — logs as a chart (lanes, or overlaid with each channel on its own scale) and a grid on one cursor, with real‑time playback at 0.25×‑20×, zoom and pan, alert colours on the line and in the grid, and saved views (e.g. *MPH vs RPM vs IAT*).
- **Vehicle & codes** — VIN, PCM OS ID, AVT firmware; trouble codes from every module, clear codes.
- **Real‑time controls** — GM device control (mode $AE): lamps, cooling fan, EVAP vent and fuel trim reset found and checked on a bench PCM, plus your own commands (on / off, hold to run, value, one‑shot).
- **PID tools** — PID editor with live formula check, import of old `PIDS.csv`, named scan lists, PID support test, and a search of the PCM for every PID it answers.
- **Simulator** — choose port *Simulator* to use everything without hardware.

| | |
|---|---|
| ![Dashboard](docs/images/dashboard.png) | ![Display and alerts](docs/images/display-alerts.png) |
| ![Real-time controls](docs/images/controls.png) | ![PID editor](docs/images/pid-editor.png) |
| ![Log viewer, overlay](docs/images/log-viewer-overlay.png) | ![Log viewer, lanes](docs/images/log-viewer-lanes.png) |

## Documentation

- **[User guide](docs/user-guide.md)** — every tab, dialog and setting, with screenshots.
- **[Data files](docs/data-files.md)** — the JSON files in `C:\ProgramData\UVScan` and the CSV log format.
- **[Protocol notes](docs/protocol.md)** — AVT framing, Class 2, DPID streaming and device control, as measured on a bench PCM.
- **[Development](docs/development.md)** — building, tests, simulator, the bench tool and the source layout.

## Quick start

1. Build `UVScan.exe` (below).
2. Connect the AVT to the PC and the vehicle, key on.
3. Pick the COM port, **Connect**, tick PIDs on the left, **Start scan**.

Everything UVScan stores lives in `C:\ProgramData\UVScan` and is created from built‑in defaults on first run, so the exe needs nothing else. Installer note: grant Users modify rights on that folder (a folder created there by one user is read‑only for others).

Command line (as in the old UVSCAN): `UVScan.exe -port COM9 -connect -scan -log`

## Build

Delphi 13 (RAD Studio 37.0); Win32 Debug for now:

```
build.cmd
build.cmd android [install]
```

Builds the app and the DUnitX tests, runs the tests, and builds the bench tool (`tools\Win32\UVScanProbe.exe`). See [development](docs/development.md).

## Status

Tested against an AVT‑841 and a bench 2001 3.8L PCM (no engine). Still to check on a running vehicle: live values with the engine running, analog inputs, real trouble codes, clearing codes, VIN write, real‑time controls with real loads, and AVT extended‑length frames.
