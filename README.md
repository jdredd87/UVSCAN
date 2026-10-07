# UVScan

Data logger / scan tool for GM vehicles on **J1850 VPW (GM Class 2)**, using an **AVT‑841** (or 838/842) interface on a serial port.
Rewrite of the 2008 UVSCAN (Delphi 2007, kept in [`legacy/`](legacy) for reference) for **Delphi 13 VCL**, with no third‑party components.

## What it does

- Connects to the AVT, reads AVT firmware, VIN and PCM OS ID
- Streams PIDs from the PCM using dynamic PIDs (DPIDs), shows live values with min/max
- Calculated PIDs (`%MCI%` formulas, `RUNTIME`, `LOGTIME`) and AVT analog inputs
- CSV logging (F8 start/stop, F9 pause)
- PID support test, trouble code read/clear, fuel trim reset, check engine light on/off, VIN write, raw frame send
- Built‑in **simulator** (choose port `Simulator`) so everything can be exercised without hardware

## Build

Open `UVScan.dproj` in Delphi 13 (Win32 or Win64), or from a command prompt:

```
build.cmd [Debug|Release] [Win32|Win64]
```

This builds the app and the DUnitX tests (`tests/UVScanTests.dproj`) and runs the tests.
The app looks for `pids.csv` / `dtcs.csv` next to the exe, then in a `data` folder up the directory tree (so running from `Win32\Debug` finds `data\`).
Settings are stored in `%APPDATA%\UVScan\settings.ini`.

Command line (same idea as legacy UVSCAN): `UVScan.exe -port COM6 -connect -scan -log`

## Layout

| Path | Purpose |
|---|---|
| `src/UVScan.Serial.pas` | Win32 serial port (no AsyncPro), COM port enumeration |
| `src/UVScan.Avt.pas` | AVT frame encoding/parsing (header = kind nibble + length nibble) |
| `src/UVScan.Class2.pas` | GM Class 2 message builders/parsers, DTC formatting |
| `src/UVScan.Dpid.pas` | Packs PIDs into DPIDs ($FE down, 6 data bytes each) |
| `src/UVScan.Formula.pas` | PID formula evaluator (replaces ArtFormula) |
| `src/UVScan.Pids.pas` | `pids.csv` loader and value formatting |
| `src/UVScan.Engine.pas` | Background thread that owns the port and runs everything |
| `src/UVScan.Simulator.pas` | Simulated AVT + PCM |
| `src/UVScan.MainForm.*` | UI |
| `data/` | `pids.csv` (UTF‑8), `dtcs.csv` |
| `tests/` | DUnitX tests, incl. end‑to‑end engine tests against the simulator |
| `legacy/` | Original source, dead code stripped; `uvscan.doc` documents the CSV formats |

## How scanning works

1. Selected vehicle PIDs are packed into DPIDs: each DPID carries 6 data bytes (positions 1–6), starting at `$FE` and counting down, max 8 DPIDs (48 bytes). PIDs are placed largest first and never split.
2. Each slot is defined with `6C 10 F1 2C <dpid> <01 pos size> <pid hi> <pid lo> FF FF`, and the engine **waits for the PCM's reply** (`6C` accepted / `7F 2C` rejected) before sending the next one.
3. Streaming starts with `6C 10 F1 2A <rate> <dpids…>` (4 DPIDs per request, rates `$14`, `$24` as in legacy).
4. The PCM sends `6C F1 10 6A <dpid> d1..d6`; a cycle completes when every planned DPID has arrived, then calculated PIDs are computed and a log row is written.
5. Tester present (`6C FE F1 3F`) is sent every 2 s from the same thread, so it can never interleave with another exchange.
6. Stop sends `6C 10 F1 2A 00` before anything else is redefined.

### Legacy PID‑send bugs this fixes

- When the last DPID was exactly full, legacy requested the **next, never‑defined DPID** in the `$2A` message, and calculated PIDs/log rows (triggered by that DPID) silently stopped.
- The 48‑byte limit check used an uninitialised variable, so more than 8 DPIDs could be defined; the extras were never requested or decoded.
- Definitions were sent on fixed delays without waiting for replies, never stopped the previous stream, and a rejected PID restarted the whole definition loop mid‑stream.

## Bench test checklist (AVT‑841 + PCM)

Things the simulator cannot prove. Turn on **Tools → Show raw traffic** and save the Messages tab:

- [ ] Connect: reply to `E1 33` (expect `C1 00`) and `B0` (expect `92 xx yy`)
- [ ] VIN (`3C 01/02/03`) and OS ID (`3C 0A`) read correctly
- [ ] Does the PCM answer each `$2C` with a positive `6C`? (Engine continues on timeout but logs a warning.)
- [ ] Streaming works with **Pad DPID requests** on (legacy) — and try off
- [ ] Does `2A 00` stop the stream?
- [ ] Rejected PID shows as "rejected", the rest keep updating
- [ ] Update rate with 1, 2, 5 and 8 DPIDs
- [ ] Analog inputs (`52 59 01` → `64 58 a1 a2 a3`)
- [ ] DTC read: module discovery (`20` broadcast) and code list; clear codes
- [ ] Any AVT frame with header `$11` (extended length) — the parser assumes it, unconfirmed
