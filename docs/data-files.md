# Data files

Everything UVScan reads or writes, apart from CSV logs, lives in **`C:\ProgramData\UVScan\`**. All files are UTF‑8 JSON objects with a `"version"`, written indented and saved through a temporary file + rename, so a crash never leaves half a file. Missing fields fall back to defaults, and problems are listed in the *Messages* tab instead of stopping the app.

| File | Contents | Edited with |
|---|---|---|
| [`pids.json`](#pidsjson) | PID definitions | PID editor (*Edit PIDs…*) |
| [`lists.json`](#listsjson) | Named scan lists | Scan list row (*Save as… / Delete*) |
| [`display.json`](#displayjson) | PID looks, alert levels, dashboard gauges | *Display & alerts…*, Dashboard |
| [`controls.json`](#controlsjson) | Real‑time controls | Real‑time controls tab |
| [`logviews.json`](#logviewsjson) | Saved log viewer set‑ups | Log viewer (*Save view…*) |
| [`sensors.json`](#sensorsjson) | Sensors read beside the car (widebands…) | *Sensors…* |
| [`dtcs.json`](#dtcsjson) | Trouble code descriptions | (text editor) |
| [`settings.json`](#settingsjson) | Port, selection, window, options | written on exit |

The repo's `data\` folder holds the factory defaults for `pids.json`, `dtcs.json`, `lists.json`, `display.json`, `controls.json` and `logviews.json`. They are compiled into `UVScan.exe` (`UVScan.Defaults.rc`), so a missing file is simply recreated at startup and a fresh install needs nothing but the exe.

**After an update** UVScan brings your files up to date with its built-in data at startup, without undoing your own changes: new built-in PIDs, scan lists, chart views, dashboards and real-time controls are added (but never one you deleted), a corrected built-in PID replaces your copy only if you never changed it, and new or corrected trouble code descriptions go into `dtcs.json`. *Messages* lists what changed.

The only CSV files UVScan writes are scan logs; the only CSV it reads is an old UVSCAN `PIDS.csv`, when you import one in the PID editor.

## pids.json

```json
{ "version": 1,
  "pids": [
    { "id": 1, "name": "ENGINE SPEED", "shortName": "RPM",
      "kind": "vehicle", "category": "engine", "pid": "000C", "bytes": 2,
      "formula": "((N1 << 8) + N2) * 0.25", "units": "RPM", "mci": "RPM" },
    { "id": 39, "name": "Inj Duty Cycle", "kind": "calculated", "category": "calculated",
      "formula": "(%IPW% / (1 / ((%RPM% / 60) / 2) * 1000)) * 100", "units": "%",
      "format": "%f", "mci": "InjDutyCycle" },
    { "id": 17, "name": "AD2", "kind": "analog", "category": "analog",
      "analogChannel": 2, "formula": "N0 * 0.0196", "units": "Volts", "mci": "AD2" } ] }
```

| Field | Meaning |
|---|---|
| `id` | Unique number; scan lists, display settings and settings refer to PIDs by it. |
| `name`, `shortName`, `description` | Shown in the list, grid and log header. |
| `kind` | `vehicle` (read from the PCM: needs `pid` + `bytes`), `calculated` (formula over other PIDs), `analog` (AVT input: needs `analogChannel` 1–3) or `sensor` (a field of a sensor in [`sensors.json`](#sensorsjson): needs `sensor` + `field`; `N0` in the formula is its value). |
| `category` | `engine`, `transmission`, `indicators`, `body`, `accessories`, `calculated`, `analog`, `sensors` or `other` (the list groups). |
| `pid`, `bytes` | Mode $22 PID number (hex) and answer size, 1–4. |
| `formula` | `N0`/`N1` = data byte 1, `N2`–`N4` = bytes 2–4; `%MCI%` = another PID's value; `RUNTIME`, `LOGTIME`; `+ - * / << >> & \|`, comparisons, `? :`. |
| `units`, `format` | Units text; `format` is a legacy printf‑style result format (`%f`, `%d`, …). |
| `mci` | Unique name other formulas use as `%NAME%`. |
| `enabled` | `false` keeps the entry but hides it from the PID list. |

The file also has `"builtIns": { "1": "<hash>", … }`: the built-in PIDs it has been given (by their id in the factory file) and how each one was then. At startup UVScan adds a built-in PID not named there (unless you have one that matches), and gives a corrected one to your copy only while that copy is still exactly as it was given; a PID you changed or deleted stays as you left it. A file without `builtIns` gets them filled in from the current defaults, and nothing else changes. A `pids.json` with an entry UVScan cannot read is not touched (fix it in the PID editor). *Default PIDs* in the PID editor adds every built-in PID you do not have, deleted ones included.

## lists.json

```json
{ "version": 1, "builtIns": ["Misfires", "Transmission"],
  "lists": [ { "name": "Misfires", "pids": [20, 21, 22, 23, 24, 25] } ] }
```

`builtIns` names the built-in lists this file has been given. At startup UVScan adds any built-in list not named there (matching its PIDs to your `pids.json` by kind, PID code and name) and adds its name, so a new version brings its new lists and one you deleted stays deleted.

The order of `pids` is the order of the live data rows when the list is scanned; moving a row (or **Save as…**) writes it.

## display.json

Gauges are kept per dashboard: `"dashboard"` is the one shown, `"dashboards"` lists them (`{ "name": "Knock check", "gauges": [ ... ] }`, optionally with `"backColor": "#000000"`, `"backImage": "dashboard-….jpg"` (a file in the `images` folder beside the JSON files) and `"fit": true`; a gauge may have `"minimized": true`) and `"builtIns"` works as in `lists.json`. A file with a single `"gauges"` list (from before there were several) is read as the dashboard *Main*.

```json
{ "version": 1,
  "pids": [
    { "pid": 232, "fontSize": 16, "rowColor": "#C8F0C8",
      "levels": [
        { "name": "Alarm", "when": ">=", "value": 4, "rowColor": "#FF5050", "textColor": "#FFFFFF",
          "flash": true, "sound": "alarm", "repeat": false },
        { "name": "Warning", "when": ">=", "value": 1, "rowColor": "#FFE680" } ] } ],
  "gauges": [
    { "pid": 232, "style": "dial", "size": "medium", "min": 0, "max": 20 } ] }
```

| Field | Values |
|---|---|
| `pid` | PID `id` from `pids.json`. |
| `fontSize`, `textColor`, `rowColor` | Normal look; colours are `#RRGGBB`, missing = default. |
| `levels[].when` | `>=`, `>`, `<=`, `<`, `=`, `<>` |
| `levels[].sound` | `none`, `beep`, `alert` (Windows alert sound), `alarm`, `file` (+ `soundFile`). |
| `levels[].repeat` | Play again every 3 s while the level lasts. |
| `gauges[].style` / `size` | `dial`, `bar`, `number` / `small`, `medium`, `large`. |

Levels are checked in order; the first that matches wins. The factory file names PIDs by `"pidCode"` (e.g. `"11A6"`, with an optional `"units"`) because ids differ between catalogs; on first run those are turned into ids from your `pids.json`, and entries for PIDs you do not have are dropped.

## controls.json

```json
{ "version": 1,
  "controls": [
    { "name": "Check engine light", "group": "Outputs", "kind": "toggle", "module": "10",
      "on": "AE 01 80 80 00 00 00 00", "off": "AE 01 00 00 00 00 00 00", "builtIn": true },
    { "name": "Reset long-term fuel trims", "group": "Resets", "kind": "action", "module": "10",
      "send": "AE 02 40 00 00 00 00 00", "confirm": "Reset the long-term fuel trims?" },
    { "name": "Idle speed", "kind": "value", "module": "10",
      "on": "AE 03 01 {V} 00 00 00 00", "off": "AE 03 00 00 00 00 00 00",
      "min": 500, "max": 1600, "step": 25, "scale": 12.5, "offset": 0, "units": "rpm" } ] }
```

(The idle speed entry only shows the format; it is not a known command.)

| Field | Meaning |
|---|---|
| `kind` | `action` (one command, stored as `send`), `toggle` (on / off), `hold` (on while the button is held), `value` (on with a value, off releases). |
| `module` | Target address in hex: `10` PCM, `18` TCM, `28` ABS, `40` BCM, `60` instrument cluster, … |
| `on` / `send`, `off` | Hex bytes starting with the mode byte. The header (`6C <module> F1`) is added when sending. A Class 2 request is the mode byte plus at most 7 data bytes. |
| `{V}`, `{V16}` | In a value control: one byte / two bytes (high first) with `raw = round((value − offset) / scale)`. |
| `min`, `max`, `step`, `units` | Slider range for value controls. |
| `confirm` | Question asked before sending (actions) or switching on. |
| `notes` | Shown under the buttons. |
| `builtIn` | Came with UVScan; *Restore built‑ins* adds deleted ones back. |

The top‑level `"defaults"` number records which set of built‑ins the file has seen; when a newer UVScan ships more, the new ones are added once.

## logviews.json

```json
{ "version": 1, "lastView": "Knock check", "liveSpan": 60,
  "views": [
    { "name": "Knock check", "mode": "lanes", "useDisplayLevels": true,
      "channels": [
        { "name": "RPM", "color": "#2D7FF9", "width": 2 },
        { "name": "KR", "color": "#51C235", "width": 2, "min": 0, "max": 10, "levelColors": true,
          "levels": [ { "name": "Alarm", "when": ">=", "value": 4, "rowColor": "#FF5050" } ] } ] } ] }
```

| Field | Meaning |
|---|---|
| `liveSpan` | Seconds the live chart shows (15‑600). |
| `mode` | `lanes`, `overlay` (own scales) or `shared` (one scale). |
| `useDisplayLevels` | Channels without their own `levels` use the *Display & alerts* levels of the PID with the same name and units. |
| `builtIns` | The built-in views this file has been given (as in `lists.json`). |
| `channels[].name` | Matched to log columns by name (`RPM` or `RPM (RPM)`); log columns not listed are hidden. In **Lanes** the channels are drawn in this order. |
| `visible`, `color`, `width` | The line (`width` 1‑4). |
| `min`, `max` | Fixed scale; leave both out for automatic. |
| `levelColors`, `levels` | Colour the line by level; levels as in `display.json`. |

## sensors.json

```json
{ "version": 1,
  "sensors": [
    { "name": "Wideband", "protocol": "mts", "port": "COM5", "baud": 19200,
      "description": "Innovate LC-1 on its serial out" },
    { "name": "EGT box", "protocol": "text", "port": "192.168.4.1:23", "baud": 9600,
      "send": "R\\r", "sendEveryMs": 250, "enabled": false } ] }
```

| Field | Meaning |
|---|---|
| `name` | Unique; sensor PIDs name their sensor by it. |
| `protocol` | `mts`: Innovate's MTS serial protocol 2 (LC‑1, LC‑2, LM‑1/2, MTX‑L and aux boxes chained to them); fields `lambdaN`, `afrN`, `statusN`, `warmupN` (while warming up), `auxN`. `text`: lines of text; each number is a field by its place (`1`, `2`, …), and one after `name=` or `name:` also by that name (lower case). |
| `port`, `baud` | A COM port, a phone's USB or Bluetooth port name, a network address (`host:port`), or `Simulator` (a made-up device of that protocol). |
| `send`, `sendEveryMs` | Text sent every so often to a device that answers when asked; `\r`, `\n`, `\t` and `\\` as in C. |
| `enabled` | `false`: its PIDs stay empty, the port is left alone. |

A sensor shared as a **`.uvsensor`** file is the sensor (without its port) and its PIDs (without their ids): `{ "uvscanSensor": 1, "sensor": { … }, "pids": [ { "name": …, "kind": "sensor", "field": … } ] }`. Importing it gives the sensor a free name, the PIDs new ids and free MCI names.

## dtcs.json

```json
{ "version": 1, "defaults": "<hash>", "dtcs": [ { "code": "P0300", "description": "Random/Multiple Cylinder Misfire Detected" } ] }
```

`defaults` identifies the built-in list the file was last brought up to date with. When a newer UVScan has a different one, its codes are added or their descriptions corrected; codes only your file has stay.

## settings.json

Port and baud (and `connection.tcpAddress`, the `host:port` of an adapter on the network, and `connection.adapter`, `avt` or `elm327`), the ticked PIDs and active scan list, stream speed, log folder, the logging options (`logging.always`: every scan logs; `logging.oneLog`: later logs carry on the same file until UVScan closes; `logging.askKeep`: stopping asks whether to keep the log, `logging.keepByDefault`: Yes is that question's default), how long a phone may be away from UVScan before it stops (`logging.backgroundStop`, seconds), raw traffic option, alert sounds, live grid zoom and min / max columns, the live rows' order for scans without a scan list (`liveGrid.order`, PID ids top first), theme, keep the screen on, rounded readings (`appearance.roundReadings`), rotation lock (`appearance.lockRotation`), what the Live page shows when a scan starts (`appearance.scanView`: `keep`, `grid` or `chart`), the hotkeys (`hotkeys.connect`, `scan`, `logViewer`, `log`, `pause`, `mark`, `fullScreen`, `liveChart`: text such as `F5` or `Ctrl+G`, empty for none, missing for the default; `hotkeys.global`: they work when UVScan is not in front), window position, PID panel width and whether it is on its own page (`window.pidsHidden`). Written when UVScan closes. An unreadable file is renamed to `settings.json.bad` and defaults are used.

`quickStarts` holds the [quick starts](user-guide.md#quick-start):

```json
"quickStarts": [
  { "name": "Drag strip", "list": "Acceleration", "connect": true, "scan": true, "log": true,
    "fullScreen": true, "chart": false, "retry": true } ]
```

Optional: `"port"` (else the port chosen last), `"adapter"` (`avt` or `elm327`, else the one chosen last) and `"dashboard"` (else the scan list's). A file without `quickStarts` gets *Drag strip*; an empty list stays empty.

## CSV logs

`UVScan_<yyyy-mm-dd_hhnnss>.csv` in the log folder: a header row `Time (s),<PID name> (<units>),…,Mark` and one row per update while logging (paused rows are skipped). The last column is empty, or a mark's number (1, 2, …) on the row after the Mark hotkey was pressed; logs from before 2.0.6 have no *Mark* column, and the log viewer reads both. With *One log until UVScan closes* a later log with the same header is appended to the file: its time goes on from the last row plus the time since the file was last written, so the stop shows as a gap (the chart breaks its lines where rows stop for more than ten usual steps, at least 2 s).
