# Data files

Everything UVScan reads or writes, apart from CSV logs, lives in **`C:\ProgramData\UVScan\`**. All files are UTF‑8 JSON objects with a `"version"`, written indented and saved through a temporary file + rename, so a crash never leaves half a file. Missing fields fall back to defaults, and problems are listed in the *Messages* tab instead of stopping the app.

| File | Contents | Edited with |
|---|---|---|
| [`pids.json`](#pidsjson) | PID definitions | PID editor (*Edit PIDs…*) |
| [`lists.json`](#listsjson) | Named scan lists | Scan list row (*Save as… / Delete*) |
| [`display.json`](#displayjson) | PID looks, alert levels, dashboard gauges | *Display & alerts…*, Dashboard |
| [`controls.json`](#controlsjson) | Real‑time controls | Real‑time controls tab |
| [`logviews.json`](#logviewsjson) | Saved log viewer set‑ups | Log viewer (*Save view…*) |
| [`dtcs.json`](#dtcsjson) | Trouble code descriptions | (text editor) |
| [`settings.json`](#settingsjson) | Port, selection, window, options | written on exit |

The repo's `data\` folder holds the factory defaults for `pids.json`, `dtcs.json`, `lists.json`, `display.json`, `controls.json` and `logviews.json`. They are compiled into `UVScan.exe` (`UVScan.Defaults.rc`), so a missing file is simply recreated at startup and a fresh install needs nothing but the exe.

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
| `kind` | `vehicle` (read from the PCM: needs `pid` + `bytes`), `calculated` (formula over other PIDs) or `analog` (AVT input: needs `analogChannel` 1–3). |
| `category` | `engine`, `transmission`, `indicators`, `body`, `accessories`, `calculated`, `analog` or `other` (the list groups). |
| `pid`, `bytes` | Mode $22 PID number (hex) and answer size, 1–4. |
| `formula` | `N0`/`N1` = data byte 1, `N2`–`N4` = bytes 2–4; `%MCI%` = another PID's value; `RUNTIME`, `LOGTIME`; `+ - * / << >> & \|`, comparisons, `? :`. |
| `units`, `format` | Units text; `format` is a legacy printf‑style result format (`%f`, `%d`, …). |
| `mci` | Unique name other formulas use as `%NAME%`. |
| `enabled` | `false` keeps the entry but hides it from the PID list. |

## lists.json

```json
{ "version": 1, "builtIns": ["Misfires", "Transmission"],
  "lists": [ { "name": "Misfires", "pids": [20, 21, 22, 23, 24, 25] } ] }
```

`builtIns` names the built-in lists this file has been given. At startup UVScan adds any built-in list not named there (matching its PIDs to your `pids.json` by kind, PID code and name) and adds its name, so a new version brings its new lists and one you deleted stays deleted.

## display.json

Gauges are kept per dashboard: `"dashboard"` is the one shown, `"dashboards"` lists them (`{ "name": "Knock check", "gauges": [ ... ] }`) and `"builtIns"` works as in `lists.json`. A file with a single `"gauges"` list (from before there were several) is read as the dashboard *Main*.

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

## dtcs.json

```json
{ "version": 1, "dtcs": [ { "code": "P0300", "description": "Random/Multiple Cylinder Misfire Detected" } ] }
```

## settings.json

Port and baud (and `connection.tcpAddress`, the `host:port` of an AVT on the network), the ticked PIDs and active scan list, stream speed, log folder, how long a phone may be away from UVScan before it stops (`logging.backgroundStop`, seconds), raw traffic option, alert sounds, live grid zoom and min / max columns, window position and PID panel width. Written when UVScan closes. An unreadable file is renamed to `settings.json.bad` and defaults are used.

## CSV logs

`UVScan_<yyyy-mm-dd_hhnnss>.csv` in the log folder: a header row `Time (s),<PID name> (<units>),…` and one row per update while logging (paused rows are skipped).
