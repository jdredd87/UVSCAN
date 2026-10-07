# UVScan

Data logger / scan tool for GM vehicles on **J1850 VPW (GM Class 2)**, using an **AVT‑841** (or 838/842) interface on a serial port.
Rewrite of the 2008 UVSCAN (Delphi 2007, kept in [`legacy/`](legacy) for reference) for **Delphi 13 VCL**, with no third‑party components.

## What it does

- Connects to the AVT, reads AVT firmware, VIN and PCM OS ID
- Streams PIDs from the PCM using dynamic PIDs (DPIDs), shows live values with min/max
- Calculated PIDs (`%MCI%` formulas, `RUNTIME`, `LOGTIME`) and AVT analog inputs
- Per‑PID look and **alert levels** (colours, flashing, sounds) in the live grid, and a **Dashboard** of dial / bar / big‑number gauges that use the same levels
- **Test display**: made‑up values sweep every PID through its range to try out colours, alerts and gauges without a car
- CSV logging (F8 start/stop, F9 pause)
- PID support test, trouble code read/clear, fuel trim reset, check engine light on/off, VIN write, raw frame send
- Built‑in **simulator** (choose port `Simulator`) that mimics the PCM behaviour measured on the bench

## Build

Open `UVScan.dproj` in Delphi 13 (Win32 or Win64), or from a command prompt:

```
build.cmd [Debug|Release] [Win32|Win64]
```

This builds the app and the DUnitX tests (`tests/UVScanTests.dproj`), runs the tests, and builds the bench probe (`tools\Win32\UVScanProbe.exe`).
## Data location

Everything the app reads or writes (apart from CSV logs) lives in **`C:\ProgramData\UVScan\`**:

| File | Purpose |
|---|---|
| `pids.json` | PID definitions (`TPidCatalog` / `TPidDef`) |
| `lists.json` | Named scan lists (`TPidLists`): `{ "name": "Misfires", "pids": [1, 20, 21] }` |
| `display.json` | How PIDs look, their alert levels and the dashboard gauges (`TDisplaySettings`) |
| `settings.json` | Port/baud, selected PIDs, stream speed, log folder, window layout (`TAppSettings`, written on exit) |
| `dtcs.json` | Trouble code descriptions (`TDtcCatalog`): `{ "code": "P0300", "description": "…" }` |

The repo's `data\` folder holds the factory defaults (`pids.json`, `dtcs.json`, `lists.json`). They are compiled into `UVScan.exe` (`UVScan.Defaults.rc`), and any data file missing from ProgramData is created from them at startup, so a fresh install needs nothing but the exe. The only CSV files UVScan writes are scan logs; the only CSV it reads is an old UVSCAN `PIDS.csv`, when you import one. CSV logs default to `Documents\UVScan Logs` (changeable on the Tools tab).

JSON files are UTF‑8, indented, carry a `"version"`, and are saved via a temp file + rename. Missing fields fall back to defaults; problems in `pids.json` are listed in the Messages tab instead of stopping the app; an unreadable `settings.json` is renamed to `settings.json.bad` and defaults are used.

`pids.json` entry (see the header of `src/UVScan.Pids.pas` for every field):

```json
{ "id": 1, "name": "ENGINE SPEED", "shortName": "RPM",
  "kind": "vehicle", "category": "engine", "pid": "000C", "bytes": 2,
  "formula": "((N1 << 8) + N2) * 0.25", "units": "RPM", "mci": "RPM" }
```

`kind` is `vehicle` (needs `pid` + `bytes`), `calculated` (formula over other PIDs' `%MCI%` values) or `analog` (`analogChannel` 1–3). MCI names must be unique. `"enabled": false` keeps an entry in the file but hides it from the scan list.

### Editing PIDs

**Edit PIDs…** (under the PID list; not while scanning) opens the editor: add, duplicate, delete and edit every field, with a live formula check, a "try the formula" box (data bytes in hex for vehicle/analog PIDs, `NAME=value` pairs for calculated ones) and a problem count. Save runs the same validation as loading and refuses to write `pids.json` while there are problems; Cancel discards everything.

- **Import…** reads an old UVSCAN `PIDS.csv` and offers *Merge: add new PIDs only*, *Merge: add new and update existing* (matched by ID) or *Replace all*. Rows the old app ignored (`group` ≠ 1) come in disabled; the old `º` degree sign becomes `°`.
- **Defaults…** adds the factory PIDs you don't have yet (keeping your own changes), or puts the factory list back entirely.

Both only change the editor's working copy; nothing is written until **Save**.

### Finding PIDs a PCM supports

**Tools → Search PCM for supported PIDs…** (connected, not scanning) asks the PCM about every PID in the chosen ranges with read‑only mode `$22`: standard SAE `$0000–$00FF` (~10 s), GM enhanced `$1000–$1FFF` (~2 min) and any extra ranges. Each answer is listed with its size, raw value and what it is already defined as. Tick the new ones and **Add ticked PIDs**: they go into `pids.json` as raw `PID $xxxx` entries (category Other), and the PID editor opens filtered to them so you can name them and give them a formula — e.g. after logging them with the engine running to see what they follow.

The factory list includes PIDs from the old UVSCAN `Extra_Pids.csv` that a 2001 3.8L (3800 Series II) PCM answers, checked against the raw values it returned on the bench.

### Display, alerts and the dashboard

Right‑click a PID (in the list or the live grid) → **Display & alerts…** to set its normal look (value font size, text and row colour) and its **alert levels**. Levels are checked from the top and the first that matches wins, e.g. for knock retard: *Alarm* `>= 4` red, flashing, alarm tone; *Warning* `>= 1` amber; normal row pale green. Each level can change the row and text colour, flash, and play a sound (beep, Windows alert, alarm tone or your own `.wav`, optionally repeating every few seconds while the level lasts). A sound plays when a PID enters a level, at most once every 3 s per PID, and the alert is noted in Messages. **Presets…** sets up green / yellow / red for "high is bad" or "low is bad" from two thresholds. **Alert sounds** in the top bar mutes everything.

The **Dashboard** tab shows gauges: dial, bar or big number, small / medium / large, each with its own scale. They use the same levels: the scale carries the levels as coloured bands, and the card takes the level's colours (and flashes) while the value is in it. Add gauges with **Add gauge…** or right‑click a PID → **Add to dashboard…**; right‑click a gauge to edit, move or remove it (double‑click edits). **Tick these PIDs** ticks the dashboard's PIDs for scanning.

In the Live data footer, **Min / max** shows or hides those columns and **-** / **+** zoom the grid from 75 % to 250 % (fonts, rows and columns together; also Ctrl + mouse wheel, Ctrl + plus / minus, Ctrl + 0 for 100 %). Both are remembered.

**Test display** (Live data and Dashboard tabs, whenever not scanning) feeds the ticked and dashboard PIDs with made‑up values that rise and fall slowly through each PID's range (its gauge scale, widened to reach every threshold), so you can watch each level, flash and sound. Nothing is sent to the PCM and nothing is logged; a banner says the values are made up.

`display.json` (colours are `#RRGGBB`, `pid` is the id from `pids.json`):

```json
{ "version": 1,
  "pids": [ { "pid": 232, "rowColor": "#C8F0C8", "levels": [
      { "name": "Alarm", "when": ">=", "value": 4, "rowColor": "#FF5050", "textColor": "#FFFFFF",
        "flash": true, "sound": "alarm" },
      { "name": "Warning", "when": ">=", "value": 1, "rowColor": "#FFE680" } ] } ],
  "gauges": [ { "pid": 232, "style": "dial", "size": "medium", "min": 0, "max": 20 } ] }
```

On first run it is created from `data\display.json`, which names PIDs by PID code (`"pidCode": "11A6"`) so the examples (knock retard, coolant temperature, ignition voltage, and a few gauges) attach to whatever ids your `pids.json` uses.

### Scan lists

The **Scan list** row above the PID list holds named selections, e.g. *Misfires* or *Transmission*. Pick one to tick its PIDs, **Save as…** to store the current ticks under a name (or update the selected list), **Delete** to remove a list (the PIDs themselves are untouched). Lists only store PID ids, so a formula fixed in the editor is fixed in every list. Defaults: *Basic engine*, *Misfires*, *Transmission*.
The program itself can live anywhere (Program Files once there is an installer). Installer note: grant Users modify rights on `ProgramData\UVScan` — a folder created there by one user is read‑only for other users.

Command line (same idea as legacy UVSCAN): `UVScan.exe -port COM9 -connect -scan -log`

## Layout

| Path | Purpose |
|---|---|
| `src/UVScan.Serial.pas` | Win32 serial port (no AsyncPro), COM port enumeration |
| `src/UVScan.Avt.pas` | AVT frame encoding/parsing (header = kind nibble + length nibble) |
| `src/UVScan.Class2.pas` | GM Class 2 message builders/parsers, DTC formatting |
| `src/UVScan.Dpid.pas` | Packs PIDs into DPIDs ($FE down, 6 data bytes each) and builds stream requests |
| `src/UVScan.Formula.pas` | PID formula evaluator (replaces ArtFormula) |
| `src/UVScan.Pids.pas` | `TPidCatalog`: pids.json load/save, validation, value formatting |
| `src/UVScan.Dtc.pas` | `TDtcCatalog`: dtcs.json load/save |
| `src/UVScan.PidLists.pas` | `TPidLists`: named scan lists (lists.json) |
| `src/UVScan.LegacyImport.pas` | Old `PIDS.csv` import, catalog merge |
| `src/UVScan.Defaults.pas` | Factory defaults built into the exe; creates missing data files |
| `src/UVScan.Engine.pas` | Background thread that owns the port and runs everything |
| `src/UVScan.Simulator.pas` | Simulated AVT + PCM |
| `src/UVScan.MainForm.*` | Main window |
| `src/UVScan.PidEditor.*` | PID editor dialog |
| `src/UVScan.Display.pas` | `TDisplaySettings`: display.json, alert levels, gauge zones |
| `src/UVScan.Alerts.pas` | Alert sounds (built‑in tones) and when to play them |
| `src/UVScan.Gauge.pas` | `TGaugeView`: dial / bar / number gauge drawn with GDI+ |
| `src/UVScan.DisplayEditor.*` | Display & alerts dialog |
| `src/UVScan.GaugeEditor.*` | Add / edit gauge dialog |
| `src/UVScan.Paths.pas` | Data folder (`C:\ProgramData\UVScan`) |
| `src/UVScan.Settings.pas` | `TAppSettings` (settings.json) |
| `src/UVScan.JsonFile.pas` | JSON read/write helpers (atomic save) |
| `data/` | Factory defaults (`pids.json`, `dtcs.json`, `lists.json`, `display.json`), compiled into the exe |
| `tests/` | DUnitX tests, incl. end‑to‑end engine tests against the simulator |
| `tools/UVScanProbe.dpr` | Console bench tool for real hardware |
| `legacy/` | Original 2008 source for reference only (dead code stripped); not used by the new app |

## How scanning works

Verified on an AVT‑841 talking to a bench PCM (OS ID 9389759).

1. Selected vehicle PIDs are packed into DPIDs: each DPID carries 6 data bytes (positions 1–6), starting at `$FE` and counting down, max 8 DPIDs (48 bytes). PIDs are placed largest first and never split.
2. Each slot is defined with `6C 10 F1 2C <dpid> <01 pos size> <pid hi> <pid lo> FF FF`. The PCM confirms each with `6C F1 10 6C <dpid> <cfg>` (or `7F 2C` to reject), and the engine waits for that before sending the next.
3. Streaming uses `6C 10 F1 2A <slot|speed> d1 d2 d3 d4`, always with exactly 4 DPID entries (unused = `00`); anything else gets `7F 2A … 12` and no data. `7F 2A … 23` means *accepted*.
4. The PCM has **two schedule slots** (`$1x`, `$2x`) of up to 4 DPIDs each; a request replaces its slot's list. The low nibble is the speed (4 fast, 3 medium, 2 slow). Each slot sends each DPID about 5 times/s at speed 4.
   - ≤ 4 DPIDs (≤ 24 bytes): the same list goes in both slots → **~10 updates/s**.
   - 5–8 DPIDs: first four in slot 1, the rest in slot 2 → **~5 updates/s**.
5. `2A 00` only **pauses**; the next request resumes the other slot's old list. So the engine sends `2A 00` and clears both slots (`2A 14 00 00 00 00`, `2A 24 00 00 00 00`) before every scan and when stopping.
6. The PCM sends `6C F1 10 6A <dpid> d1..d6`; a cycle completes when every planned DPID has arrived, then calculated PIDs are computed and a log row is written.
7. Tester present (`6C FE F1 3F`) every 2 s from the engine thread keeps the stream alive.

AVT‑841 framing: header byte = kind nibble + length nibble. Init: `E1 33` → `91 07`, `B0` → `92 04 13` (firmware). Every bus message sent is confirmed by the AVT with `01 60`. Received bus messages are `0N 00 <message>` (status byte 00). A single duplicated header byte was seen once; the parser recovers from it.

### Legacy PID‑send bugs this fixes

- **Stale DPIDs came back to life.** Legacy never cleared the PCM's schedule slots, and `2A 00` only pauses. After a scan with more than 4 DPIDs, any later scan resumed the old slot‑2 DPIDs, so the PCM streamed data nobody asked for and the bus filled with stale frames.
- When the last DPID was exactly full, legacy requested the **next, never‑defined DPID**, and calculated PIDs/log rows (triggered by that DPID) silently stopped.
- The 48‑byte limit check used an uninitialised variable, so more than 8 DPIDs could be defined; the extras were never requested or decoded.
- Definitions were sent on fixed delays without waiting for the PCM's confirmation, and a rejected PID restarted the whole definition loop mid‑stream.
- Legacy's `$14`/`$24` split was right for 5–8 DPIDs, but small scans ran at 5 Hz where 10 Hz is possible.

## Bench tool

```
UVScanProbe COM9 raw                        AVT init frames, raw bytes
UVScanProbe COM9 run 5 1,3,12 [-notest] [-nodtc] [-speed 4]
                                            connect, PID test, 5 s scan, DTC read (read-only)
UVScanProbe COM9 rawscan | rates | multi    byte-level stream experiments
```

## Still to check on a running vehicle

- [ ] Values with the engine running (the bench PCM only shows defaults)
- [ ] Analog inputs (`52 59 01` → `64 58 a1 a2 a3`)
- [ ] DTC list with real codes; clear codes, fuel trim reset, check engine light, VIN write (not run on the bench)
- [ ] AVT frames with header `$11` (extended length) — the parser assumes them, unconfirmed
