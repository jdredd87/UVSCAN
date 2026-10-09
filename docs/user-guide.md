# UVScan user guide

UVScan reads live data, trouble codes and vehicle information from GM vehicles on the **Class 2 / J1850 VPW** bus through an **AVT‑841** (or 838 / 842) interface, logs it to CSV, shows it as a grid or as gauges with alerts, and can send real‑time control commands. It was written for the 1996‑2005 GM V6s (3100 / 3400 / 3800) but works with any Class 2 PCM.

- [The main window](#the-main-window)
- [Connecting](#connecting)
- [Choosing PIDs and scan lists](#choosing-pids-and-scan-lists)
- [Live data](#live-data)
- [Live chart](#live-chart)
- [Display and alerts](#display-and-alerts)
- [Dashboard](#dashboard)
- [Test display](#test-display)
- [Logging](#logging)
- [Log viewer](#log-viewer)
- [Vehicle and trouble codes](#vehicle-and-trouble-codes)
- [Real‑time controls](#real-time-controls)
- [Tools](#tools)
- [Editing PIDs](#editing-pids)
- [Finding PIDs a PCM supports](#finding-pids-a-pcm-supports)
- [Messages](#messages)
- [Keyboard and command line](#keyboard-and-command-line)
- [Where things are stored](#where-things-are-stored)
- [Troubleshooting](#troubleshooting)

All screenshots were taken with the built‑in **Simulator**, so the values are made up.

---

## The main window

![Main window while scanning](images/live-data.png)

Windows and Android share one layout:

| Area | What it is |
|---|---|
| Top bar | The page's title, one main button that follows the connection (**Connect** → **Start scan** → **Stop**), and **⋮** with the page's other actions. Pages under *More* get a back arrow. On Android the back button or gesture does what the arrow does: it leaves an editor or sub‑page (an editor's back arrow cancels; the PID editor asks first if there are unsaved changes), goes from a *More* page to the menu and from any page to *Live*; on *Live* it sends UVScan to the background like Home (a scan carries on for the time set in *Settings → Logging*). |
| Pages | **Connect** (adapter, scan, logging, vehicle info), **PIDs** (the PID list with the **Scan list** row, the byte count — the PCM streams at most 48 — and **Test PIDs / Clear selection / Edit PIDs…**), **Live** (live data grid), **Gauges** (dashboard) and **More**: *Real‑time controls*, *Trouble codes*, *Log viewer*, *Tools*, *Settings*, *Messages*. A coloured notice line appears at the top when something needs your attention (tap or click it to dismiss). |
| Status strip | A dot — grey idle, blue connected, green scanning, red logging, amber paused — then state, port, VIN, OS ID, update rate and logging. Tap it to go to *Connect*. |
| Tab bar | **Connect · PIDs · Live · Gauges · More** at the bottom (down the left side when the phone is held sideways). |

On a wide window (about 1000 pixels and up — a big Windows window, or a tablet held sideways) the PID list stays docked on the left beside the pages (drag the splitter to size it) and the *Live* and *Gauges* pages show their buttons in a bar; on a phone or a narrow window those buttons are in the **⋮** menu.

A phone works upright or sideways. Held sideways (a short, wide screen) the tab bar moves down the left side so the pages keep their height, the PID search sits beside the scan list, *Real‑time controls* shows the selected control beside the list, the gauge editor keeps its preview beside the fields, and the log viewer puts its log box in the top bar, playback on one row and the chart beside *Channels | Data*.

Everything fits the width it has: on a phone or a narrow window the grids drop or narrow their less important columns and wrap long names onto more lines, a number too long for its cell is drawn smaller rather than cut short, and a grid whose columns still do not fit scrolls sideways (drag it with a finger, or Shift + mouse wheel). The editors (gauges, *Display & alerts*, PIDs, real‑time controls, PID search) open as pages with the same top bar: the back arrow cancels, the button on the right saves.

**Themes** (*More → Settings → Theme*): **System default** follows the light / dark setting of Windows or the phone; or pick **Light** or **Dark**. They are Delphi's own styles (Win10Modern on Windows, the Android styles on a phone). **Keep the screen on while UVScan is open** (same page, on by default) stops the phone or PC from going to sleep or blanking the screen.

## Connecting

1. Plug the AVT into the PC and the vehicle (key on).
2. On the *Connect* page pick its COM port, or on Android its USB adapter (**Refresh** re‑reads the list), and the baud rate (115200 for the AVT‑841). Choose **Simulator** to try UVScan without hardware.
3. Press **Connect** (on the page or in the top bar). UVScan initialises the AVT, reads its firmware version, the VIN and the PCM operating system ID (shown in the status strip and under *Vehicle* on the *Connect* page).

Everything that talks to the AVT runs on a background thread, so the window stays responsive while the PCM is busy.

## Choosing PIDs and scan lists

Tick PIDs on the *PIDs* page, or in the list on the left of a wide window (type in **Search PIDs…** to filter). The footer shows how many are ticked and how many of the PCM's 48 streaming bytes they use; it turns red when there are too many.

- **Test PIDs** asks the PCM about each ticked PID (or all of them) and shows *yes / no* in the *Test* column.
- **Scan list** holds named selections such as *Misfires* or *Transmission*. Pick one to tick its PIDs, **Save as…** to store the current ticks under a name, **Delete** to remove a list. Lists only remember which PIDs, so fixing a PID's formula fixes it in every list.
- Right‑click a PID (long‑press on a phone) → **Display & alerts…** or **Add to dashboard…**.

## Live data

Press **Start scan**. Each ticked PID gets a row with its current value, units and the lowest / highest value seen (**Reset min / max** starts those again).

- **Min / max** in the footer (or **⋮ → Show min / max**) hides or shows those two columns.
- **‑ / +** zoom the grid from 75 % to 250 % — text, rows and columns together. Ctrl + mouse wheel over the grid, Ctrl + plus / minus and Ctrl + 0 (back to 100 %) do the same. Click the percentage to reset.
- Rows take the colours of their [alert levels](#display-and-alerts) and flash when a level says so.
- With up to 4 DPIDs (about 24 bytes of PIDs) the PCM sends about 10 updates a second, with more about 5 (see [protocol notes](protocol.md)).

![Live data zoomed, without min / max](images/live-zoom.png)

## Live chart

The chart button in the top bar of *Live* and *Gauges* (or **⋮ → Live chart**) shows the running scan as a line chart — the [log viewer](#log-viewer)'s chart, fed by the scan instead of a file. It also charts the [test display](#test-display), so you can try it without a car. On Windows it is a window of its own, so you can keep it beside the live grid; on a phone it is a page (back returns to *Live*).

![Live chart](images/live-chart.png)

- The newest values are on the right and the chart scrolls as they come in. The box after the buttons sets how much it shows: 15 s, 30 s, 1, 2, 5 or 10 minutes (remembered).
- Every update of the scan is charted (about 10 a second with up to 4 DPIDs), and the last 15 minutes are kept while you scan, so you can open the chart after something happened and still see it.
- **Pause:** click, drag or touch the chart (or press **Pause** / Space) to stop it scrolling and put the cursor there. The values on the left are then the ones at the cursor; the slider, **|<**, the mouse wheel, panning and selecting a stretch (for min / avg / max) all work as on a log. **Live** (or **>|**) goes back to now.
- Channels, colours, widths, scales, alert colours, level bands, chart modes and saved **views** are the same as in the log viewer. The channels are named like the columns of a log, so a view saved for logs works on the live chart and the other way round.
- **Image…** saves the chart as it is. **Demo**, **Open log…** or a recent log switch the window back to logs; **Live scan** (on a phone **Live**) returns to the scan.
- A new scan starts the chart again with its PIDs.

## Display and alerts

Right‑click a PID in the list or a row in the live grid → **Display & alerts…**.

![Display and alerts](images/display-alerts.png)

**Normal look** — the size of the value text and the row's text and background colour (for example a pale green row for knock retard, so it stands out).

**Alert levels** — checked from the top; the first one that matches the current value is used. Each level has:

| Setting | Meaning |
|---|---|
| Name | Shown in the grid preview, on the gauge and in Messages (*Alarm*, *Hot*, …). |
| When value is | *at or above, above, at or below, below, equal to, not equal to* a number. |
| Row colour / text colour | The colours while the level is active (*Default* keeps the normal look). |
| Flash | The row and the gauge blink while the level is active. |
| Sound | *Beep* or *Alarm tone* (built into UVScan, so they work even with Windows sounds off), the *Windows alert sound*, or any `.wav` file. **Test** plays it. |
| Repeat | Play the sound again every few seconds while the value stays in the level. |

A sound plays when a PID **enters** a level, at most once every 3 seconds per PID, so a value hovering on a threshold does not machine‑gun. Each alert is also written to Messages. **Play alert sounds** (*More → Settings*) mutes all of them.

**Presets…** builds green / yellow / red from two numbers: *high values are bad* (knock retard, temperatures) or *low values are bad* (voltage, oil pressure). The red level flashes and sounds the alarm tone.

Type a number in **Preview** to see how the row looks at that value.

Built‑in examples (created the first time UVScan runs, matched to your PIDs by PID code): knock retard (warning ≥ 1°, alarm ≥ 4°), coolant temperature (hot ≥ 104 °C, overheating ≥ 110 °C with a repeating alarm) and ignition voltage (overcharging ≥ 15.5 V, low ≤ 11.5 V, not charging ≤ 12.6 V).

## Dashboard

![Dashboard](images/dashboard.png)

Big gauges for the PIDs you care about most:

- **Dial** — 270° scale with needle and the value in the middle,
- **Bar** — a horizontal bar with the value on the right,
- **Big number** — just the value, large.

Each comes in small, medium or large and has its own scale. Gauges wrap to fit the window. On a phone small gauges sit two to a row (six dials fit on the screen), medium ones keep their size, large ones fill the width and bars take the width; held sideways, two rows of small gauges fit the screen.

They follow the **same alert levels** as the grid: the scale shows the levels as coloured bands, the value arc takes the colour of the band it is in (or the PID's normal colour), and while a level is active the whole card takes the level's colours, flashes and sounds.

- **Add gauge…** or right‑click a PID → **Add to dashboard…**
- Right‑click a gauge → **Edit gauge…**, **Display & alerts…**, **Move earlier / later**, **Remove from dashboard**. Double‑click edits.
- **Tick these PIDs** ticks the dashboard's PIDs in the PID list, ready to scan.

![Gauge editor](images/gauge-editor.png)

The gauge editor shows the gauge at the top; drag **Try a value** to see it at any value, including flashing levels. Tap the **PID** row to pick another PID (with a search box), choose **Dial / Bar / Number** and **Small / Medium / Large**, and set the scale — **Auto** suggests one from the PID's formula and widens it to show every alert level. **Edit alert levels…** opens *Display & alerts* for the PID: each level is a card (tap it to change its name, condition, colours, flashing and sound), **+ Add level** and **Presets…** add more.

## Test display

**Test display** (on the *Live* and *Gauges* pages or in their **⋮** menu, whenever you are not scanning) fills the grid and the gauges with made‑up values that slowly rise and fall through each PID's range — its gauge scale, widened so every alert threshold is crossed. Use it to check colours, flashing, sounds and gauge layouts without a car. A notice says the values are made up; nothing is sent to the PCM and nothing is logged. Press **Stop test** (or start a real scan) to end it.

## Logging

While scanning, **Start log (F8)** writes every update to a CSV file named `UVScan_<date>_<time>.csv` in the log folder (default *Documents\UVScan Logs*, change it in *More → Settings*). **Pause (F9)** stops writing rows without closing the file. The first column is the time since the log started, then one column per PID with its units in the header.

**On a phone, stay in UVScan while logging.** Android lets an app it is not showing run for only a short while before pausing it, which would cut the stream off part‑way. So when you switch to another app (or the screen turns off) UVScan waits; if you are not back within the time set in *Settings → Logging* (**Stop and disconnect when away for**, 15 seconds unless you change it), it closes the log, stops the scan, releases any held controls and disconnects. The rows recorded until then stay in the log. While you are away a notification says UVScan is still connected, scanning or logging and how long it will wait (tap it to go back); if the time runs out it changes to say what was stopped. When you come back the notification goes and a notice in UVScan says what was stopped (even if Android has closed UVScan meanwhile); connect and start again. Back sooner, and everything just carries on. Android 13 and later ask once, the first time you connect, whether UVScan may show notifications. Keep the screen on (*Settings → Appearance*) so it does not turn off by itself mid‑drive.

## Log viewer

**Open logs** on the *Connect* page or *More → Log viewer* (or **F7**) opens your logs as a chart and a grid that follow one cursor. The first time it opens the newest log in the log folder; **Open log…** picks any file and the list next to it holds the 40 most recent. **Demo drive (made up)** opens a generated 10‑minute drive (cold start, city, highway, a hard pull with knock retard) to try everything without a log.

![Log viewer, overlay](images/log-viewer-overlay.png)

**Channels** (left): tick the ones to chart. *Value* is the value at the cursor, coloured by its alert level; *Min* / *Avg* / *Max* are for the whole log (or the selected stretch, see below). Select a channel to change it:

| Setting | What it does |
|---|---|
| Colour, width | The line. |
| Scale automatically | Fits the whole log; untick it and type a min and max to fix the scale (e.g. 0‑10° for knock retard so small blips stay small). |
| Colour the line by alert level | Where an alert level matches, the line takes the level's colour and gets thicker. |
| Alert levels… | Levels for this channel in this view, with the same dialog as *Display & alerts*. Without its own levels a channel uses the *Display & alerts* levels of the PID with the same name and units (switch that off with **Alert levels from Display & alerts**). |

**Chart modes** (*Chart* list):

- **Lanes** — a strip per channel, each on its own scale: the clearest way to line up, say, RPM, TPS, MAP and knock retard.
- **Overlay (own scales)** — all lines in one area, each on its own scale with its own coloured axis: good for comparing shapes, e.g. **MPH vs RPM vs IAT**.
- **Overlay (one scale)** — everything on one scale, for channels in the same units.

![Log viewer, lanes](images/log-viewer-lanes.png)

**Moving around:** click or drag in the chart to move the cursor (the grid jumps to that row); the mouse wheel zooms around the mouse; drag with the right mouse button to pan; double‑click to see the whole log. With the chart focused, ←/→ step one sample (Shift: 10), Home / End jump to the ends. Clicking a grid row moves the cursor there too. **Level bands** shades each channel's alert levels behind its line.

**Selecting a stretch:** hold Shift and drag in the chart. The stretch is shaded with its length, and the *Min\* / Avg\* / Max\** columns on the left show the values over just that stretch (for ON / OFF channels the average is how much of the time it was on) — e.g. select a wide‑open pull to see peak knock retard and average MAP. Enter zooms to the selection, Esc clears it.

![Selecting a stretch](images/log-viewer-selection.png)

**Image…** saves the chart as a PNG (for forum posts or a tuner). You can also drop a log file onto the viewer to open it, and after you stop logging, **F7** opens the log you just recorded.

**On a phone or a narrow window** the viewer is a page: the recent logs and **Demo** at the top, the playback buttons, then the chart above **Channels | Data** (one at a time). The selected channel's colour, scale and alert levels are on a page of their own — **Colour, scale, alerts: …** under the list. **⋮** holds the view set‑ups (pick, **Save view…**, **Delete view**), the chart mode, **Save chart picture** (saved next to the logs), **Follow the cursor**, **Level bands** and **Levels from Display & alerts**. Select a stretch by long‑pressing the chart (or **Select range**) and dragging. The back key (or arrow) leaves the channel page, then the viewer.

**Playback:** **Play** (or Space) runs the cursor through the log in real time — or at 0.25× to 20× — with the chart following (**Follow cursor**), the grid scrolling along and the values on the left updating, like watching the drive again. **|<** and **>|** jump to the start and end; the slider scrubs.

**Views:** **Save view…** stores the ticked channels, colours, widths, scales, alert levels and chart mode under a name; pick it in **View** to apply it to any log (channels are matched by name; ones the view does not list are hidden). The last view used is remembered. Two come with UVScan: *MPH vs RPM vs IAT* and *Knock check*. Views live in `logviews.json`.

## Vehicle and trouble codes

![Trouble codes](images/trouble-codes.png)

- **Read vehicle info** (on the *Connect* page) — AVT firmware, VIN and PCM OS ID.
- **Read codes** (*More → Trouble codes*) — trouble codes from every module that answers (PCM, TCM, ABS, BCM, …) with descriptions from `dtcs.json`.
- **Clear codes** — asks first, then clears the PCM's codes (cycle the key and read again to confirm).

## Real‑time controls

![Real-time controls](images/controls.png)

Real‑time controls (also called output tests, device control or special functions) make a module switch an output, hold a value or reset something it has learned — for example turn on the check engine light or reset the learned fuel trims. On GM Class 2 these are **mode $AE device control** requests.

**Every control here sends a command that changes what the PCM does.** Use only ones you understand, ideally with the engine off. Anything still active is released by **Release all**, by **Disconnect** and when UVScan closes; GM modules also drop device control by themselves a few seconds after the scan tool goes quiet.

Each control is one of four types:

| Type | Buttons | What happens |
|---|---|---|
| Action (send once) | **Send** | One command, e.g. a reset. |
| On / off | **On**, **Off** | *On* starts the control and keeps it active (UVScan keeps the session alive) until *Off* or *Release all*. |
| Hold to run | **Hold to run** | On while you hold the button down, off as soon as you let go. |
| Value | slider, **Apply**, **Release** | Sends the chosen value, e.g. an idle speed; *Release* gives control back to the PCM. |

The *Last result* column shows the module's answer — *OK*, or *refused* with the reason (for example *conditions not correct (engine running?)* or *request out of range*). Active controls are highlighted.

Controls work while scanning, so you can watch the PIDs they affect at the same time.

### Built‑in controls

| Control | Type | Command |
|---|---|---|
| Check engine light on / off | on / off | `AE 01 80 80 …` / `AE 01 80 00 …` |
| Change oil, low oil, generator, engine hot light on | on / off | `AE 01 20 20 …`, `10 10`, `08 08`, `04 04` |
| Cooling fan 1 on | on / off (asks first) | `AE 01 00 00 80 80 00 00` |
| EVAP vent solenoid on | on / off | `AE 01 00 00 08 08 00 00` |
| Reset long‑term fuel trims | action (asks first) | `AE 02 40 00 00 00 00 00` |
| Release all (return to normal) | action | `20` |

They were found and checked on a bench PCM (2001 3.8L, OS 9389759) by switching each output and watching the PCM's own status PIDs follow — see [protocol notes](protocol.md#device-control-mode-ae). Other PCMs may use other bits; if one is refused or does nothing on your vehicle, it does not apply there. **Restore built‑ins** puts back any you deleted, and new built‑ins from a newer UVScan are added once by themselves.

Several controls can be on at once: outputs that share a GM control packet (all the lamps, the fan and the EVAP vent are in CPID $01) are combined, so switching one off leaves the others on.

### Adding your own

If you know the command for something (from a service manual, a forum, or by logging what another scan tool sends), press **Add…**:

![Control editor](images/control-editor.png)

| Field | Meaning |
|---|---|
| Name, Group | How it is listed. |
| Type | Action, on / off, hold to run or value (see above). |
| Module | The module's bus address, e.g. `10` PCM, `18` TCM, `40` BCM. |
| On command / Command | Hex bytes starting with the mode byte, e.g. `AE 01 80 80 00 00 00 00`. The message header (priority, module, tester address) is added for you. |
| Off command / Release | What turns it off again (required for on / off and hold to run). |
| Value control | Min, max and step of the slider, units, and how the value becomes a byte: `{V}` (one byte) or `{V16}` (two bytes, high first) in the command is replaced by `raw = (value − offset) / scale`. |
| Ask first | A question to confirm before sending (leave empty for none). |
| Notes | Shown under the buttons. |

**Will send** shows the exact bytes, and the dialog explains what is wrong until the control is complete. Controls are saved in `controls.json`.

## Tools

![Tools](images/tools.png)

- **Write VIN** — writes a new 17‑character VIN to the PCM (asks first; turn the key off for 15 s afterwards).
- **Advanced** — send a raw AVT frame (hex) and see the reply in Messages, and show the raw bus traffic in Messages (**Show raw traffic in Messages**).
- **Search PCM for supported PIDs…** — see [below](#finding-pids-a-pcm-supports).

The log folder and the stream speed (fast / medium / slow; applies from the next scan) are in *More → Settings*.

## Editing PIDs

**Edit PIDs…** (under the PID list; not while scanning) opens the PID editor.

![PID editor](images/pid-editor.png)

Every PID has a name, short name, category, kind and formula:

| Kind | Needs | Formula inputs |
|---|---|---|
| Vehicle | the PID number (`000C`, `11A6`, …) and its size in bytes | `N0`/`N1` = data byte 1, `N2` = byte 2, … |
| Calculated | — | other PIDs by their MCI name, e.g. `%RPM%`, plus `RUNTIME`, `LOGTIME` |
| Analog | AVT analog channel 1–3 | `N0` = the reading |

Formulas use `+ - * /`, `<< >>`, `& |`, comparisons and `? :` (e.g. `N0 > 127 ? N0 - 256 : N0`). The **Try the formula** box evaluates it with bytes or values you type. The problems panel lists everything that would stop the file loading; click one to jump to it. **Save** refuses to write while there are problems; the back arrow throws everything away. On a phone or a narrow window the editor is two pages: the list (tap a PID) and its details, with **All PIDs** (or the back key) to return to the list.

- **Import…** reads an old UVSCAN `PIDS.csv` and either adds only new PIDs, adds new and updates matching ones, or replaces the whole list.
- **Defaults…** adds the factory PIDs you are missing, or puts the factory list back completely.

## Finding PIDs a PCM supports

**Tools → Search PCM for supported PIDs…** (connected, not scanning) asks the PCM about every PID in the chosen ranges — standard SAE `$0000‑$00FF` (about 10 s), GM enhanced `$1000‑$1FFF` (about 2 minutes) and any extra ranges — using the read‑only mode `$22`.

![PID search](images/pid-search.png)

Each PID that answers is listed with its size, raw value and what it is already defined as. Tick the new ones and press **Add** (top right): they are added as `PID $xxxx` (category *Other*) and the PID editor opens filtered to them so you can name them and give them a formula — for example after logging them with the engine running to see what they follow.

## Messages

Everything UVScan does is written here with a timestamp: connection steps, PCM answers and refusals, alerts, real‑time control results and, with **Show raw traffic in Messages** on (*Tools*), every frame sent and received.

## Keyboard and command line

| Key | Action |
|---|---|
| F7 | Log viewer |
| F8 | Start / stop log |
| F9 | Pause / resume log |
| Ctrl + / Ctrl ‑ / Ctrl 0 | Zoom the live grid (Live data tab) |
| Ctrl + mouse wheel | Zoom the live grid |
| Space (log viewer) | Play / pause (live chart: pause / back to now) |
| ← → Home End (log viewer chart) | Step through the log |

```
UVScan.exe -port COM9 -connect -scan -log
```

`-port` picks the port, `-connect` connects at start, `-scan` starts scanning the saved selection, `-log` starts a log as well.

## Where things are stored

Everything UVScan reads or writes, apart from CSV logs, is in **`C:\ProgramData\UVScan`**: `pids.json`, `lists.json`, `display.json`, `controls.json`, `logviews.json`, `dtcs.json` and `settings.json`. Missing files are created from the defaults built into `UVScan.exe`. See [data files](data-files.md) for the formats.

## Troubleshooting

| Problem | Try |
|---|---|
| *Could not open COM…* | Another program (or another UVScan) has the port. Close it, check the port in Device Manager. |
| Connect works but no data | Key on? The status strip's update rate stays at 0 and a notice says *No data from the PCM*. Check the AVT's vehicle connection. |
| *Selected PIDs need N bytes; the limit is 48* | Untick some PIDs; the PCM cannot stream more than 48 bytes. |
| A PID shows *rejected* | The PCM refused it in a DPID. Use **Test PIDs**, or remove it. |
| A real‑time control is *refused* | The reason is in *Last result*. *Request out of range* means this PCM does not have that control; *conditions not correct* usually means the engine is running or the vehicle is moving. |
| No alert sounds | **Play alert sounds** in *More → Settings* must be ticked; check the level's sound with **Test**. |
