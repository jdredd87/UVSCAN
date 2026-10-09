# Development

## Building

Delphi 13 (RAD Studio 37.0), FireMonkey (FMX): Win32 and Android64 (Win32 Debug is the only Windows build for now). No third‑party components: the serial port, AVT protocol, formula evaluator, JSON handling, grid, gauges and chart are all in `src\`. The last VCL version is git tag `vcl-final`.

Open `UVScan.dproj` in the IDE, or from a command prompt:

```
build.cmd
```

That builds the app (`Win32\Debug\UVScan.exe`), builds and runs the DUnitX tests (`tests\UVScanTests.dproj`), and builds the bench tool (`tools\Win32\UVScanProbe.exe`). It stops at the first failure.

### Android

```
build.cmd android [install]
```

builds `Android64\Debug\UVScan\bin\UVScan.apk` and, with `install`, puts it on the phone attached over adb. The Android SDK profile is passed explicitly (`UV_ANDROID_SDK`, default `AndroidAPI36.1_64bit.sdk`) because the IDE default can still name an SDK folder from an older Delphi update. The Android project files:

- `AndroidManifest.template.xml`: Delphi 13's template plus the USB host feature and the "USB device attached" filter.
- `deploy\android\device_filter.xml`: the USB adapters UVScan can drive (deployed to `res\xml`).
- `UVScan.deployproj`: what goes into the APK.

On Android the data folder is the app's private documents folder, and logs go to `Android/data/com.jdredd87.uvscan/files/Logs` (reachable over USB). The serial port is USB host (`UVScan.Serial.Android`): FTDI (the AVT‑841's own USB port, if it is FTDI), CP210x, CH340/CH341, CDC‑ACM and the Keyspan USA‑19HS (the bench's COM9 adapter; its firmware is in ROM, and the other Keyspan models, which need firmware loaded, are not supported). Android asks for permission the first time; connect again after allowing it.

For development, connect the IDE to the phone over Wi‑Fi (Developer options > Wireless debugging, `adb pair` once, then `adb connect <ip:port>`) so the phone's USB port is free for the adapter. `tools\phone-mirror.cmd` shows the phone's screen in a window on the PC that the mouse and keyboard work (scrcpy, `winget install --id Genymobile.scrcpy`); it makes scrcpy use Delphi's adb so the two do not restart each other's adb server.

### Writing UI code

- Forms are `.fmx`. The custom controls (`TDataGrid`, `TGaugeView`, `TLogChart`) are not registered components: each form creates them in `FormCreate` inside a `TLayout` placeholder, so the forms open in the designer without a package.
- Android back: forms handle `vkHardwareBack` in `OnKeyUp` (set `Key := 0` when used; `MakePage` does it for editor pages). Android 16 no longer sends apps built for it the back key, so `HookBackGesture` (called once by the main form) registers an `OnBackInvokedCallback` (declared in `UVScan.UI.Common`, Delphi's units lack it) that feeds the gesture to the active form as `vkHardwareBack`, as FMX does on older Android. Forms shown as pages (`ShowDialog`, the log viewer) apply `KeepInSafeArea` again once on screen: asked before, they get no insets.
- Nothing may block on Android: use `UVScan.UI.Common` (`ShowInfo`, `Confirm`, `AskText`, `ShowDialog`) and pass a callback. On Windows these are still modal and the callback runs before the call returns.
- Colours are `TAlphaColor`; `NoColor` (0) means "the default".
- One layout on both platforms: top bar, pages in `tcMain` / `tcMore`, status strip and tab bar (built in `BuildChrome`). `ArrangeLayout` docks the PID list and shows the page tool bars on any window at least `WideLayoutWidth` wide (tablets included), and on a short, wide one (a phone held sideways, below `RailHeight`) moves the tab bar down the left side (`FRail`). Layouts choose by `InnerWidth` / `InnerHeight` (the room inside the safe area: sideways, the camera and system buttons are at the sides), never `ClientWidth`; the safe area change on a turn calls the form's `OnResize` again. Switch pages with `ShowPage`, not `ActiveTab`.
- Fit by width, not by platform: layouts switch on the window's or the control's width (`ClientWidth < NarrowWidth`, `LiveGridCompact`, `ApplyPageGridColumns`), so a narrow Windows window looks like a phone and a tablet like a desktop. Size things from the active style's text (`FitTextWidth`, `WrappedTextHeight`, `FlowControls`, `ArrangeCaptionRows` in `UVScan.UI.Common`) — Win10Modern's text and fields are bigger than the design's. Editors use `MakePage` for the top bar.
- `TDataGrid` columns can wrap (`SetColumnWrap`, with `AutoHeights`), shrink their text to fit (`SetColumnShrink`) or stretch; the grid scrolls sideways when the columns are wider than it. Paint with a single clip rectangle: a second `IntersectClipRect` is not undone by `RestoreState` and hides every control painted after it.
- Themes: `UVScan.UI.Theme` applies Delphi's styles (compiled in from `res\styles` by `UVScan.StylesWin.rc` / `UVScan.StylesAndroid.rc`) and keeps a `Palette` for UVScan's own painted controls, which repaint on `TThemeChangedMessage`. Use palette colours, not literals, for anything drawn or tinted.
- Menus: FMX `TPopupMenu` does not show on Android; use `ShowActionMenu` / `ShowMenuAsActions` from `UVScan.UI.Common` (the page **⋮** menu uses them on both platforms).
- `IsMobile` switches the few things that really differ on a phone or tablet: full-screen dialogs, no file dialogs, padding for the status and navigation bars, touch wording ("tap"), taller rows.

The factory data in `data\` is compiled into the exe through `UVScan.Defaults.rc` (`UVScan.Defaults.res` is generated and not in git).

## Tests

`tests\` holds DUnitX tests for the protocol pieces (AVT framing, Class 2 messages, DPID planning, the formula evaluator), the JSON files, the legacy CSV import, display levels and alerts, real‑time controls (including how active device controls are merged), log reading and saved views, and end‑to‑end engine runs against the simulator (connect, scan, log, PID test, discovery, stop/restart). They run on both platforms and report memory leaks.

## Simulator

`UVScan.Simulator.pas` is an `ISerialPort` that behaves like an AVT‑841 with a PCM behind it, built from what the bench PCM actually did: AVT init answers, `01 60` transmit confirmations, DPID definition replies, the two stream slots and their rates, `2A 00` pausing, NRC codes for bad requests, mode $22 PIDs, trouble codes in several modules, VIN blocks, and mode $AE device control (CPIDs $01‑$04 with exactly 6 bytes, NRC $12 / $31 otherwise). Choose port **Simulator** in the app; the tests use it too. When the bench shows new behaviour, add it here.

## Bench tool

`tools\UVScanProbe.dpr` is a console program for real hardware. Close UVScan first (only one program can open the COM port).

```
UVScanProbe COM9 raw [baud] [rtscts|none]   AVT init frames, raw bytes
UVScanProbe COM9 run 5 1,3,12 [-notest] [-nodtc] [-speed 4]
                                            connect, PID test, 5 s scan, DTC read (read-only)
UVScanProbe COM9 rawscan | rates | multi    stream experiments (DPID slots and rates)
UVScanProbe COM9 sweep 0000-00FF,1000-1FFF  list every PID the PCM answers (mode $22, read-only)
UVScanProbe COM9 cpids 00 FF                device control survey: each CPID with all-zero data
UVScanProbe COM9 cpidlen 01,02              which control lengths each CPID accepts
UVScanProbe COM9 cpidmap pids.txt 01,02     set control bits one by one, read every PID, show changes
UVScanProbe COM9 cpidconfirm 01 1104,110C 3 repeat single-bit tests, keep effects that follow every time
```

`cpids`, `cpidlen`, `cpidmap` and `cpidconfirm` **send device control commands**; `cpidmap` on CPID $02 resets learned values. They end with mode $20 (return to normal). See [protocol notes](protocol.md#device-control-mode-ae).

## Sample log

`python tools\make_sample_log.py [file.csv]` writes a made-up 25-minute drive (10 rows a second, 20 channels: cold start, city, on-ramp and passing pulls with knock retard, highway with the converter clutch locked, a hot idle with the fan and A/C cycling) as a UVScan log, by default `UVScan_sample_drive.csv` in *Documents\UVScan Logs*, for trying the log viewer and playback with more than the built-in demo.

## Source layout

| Path | Purpose |
|---|---|
| `src/UVScan.Serial.pas` | Win32 serial port (no AsyncPro), COM port list |
| `src/UVScan.Avt.pas` | AVT frame encoding / parsing (header = kind nibble + length nibble) |
| `src/UVScan.Class2.pas` | GM Class 2 message builders and parsers, DTC formatting, NRC texts |
| `src/UVScan.Dpid.pas` | Packs PIDs into DPIDs ($FE down, 6 data bytes each) and builds stream requests |
| `src/UVScan.Formula.pas` | PID formula evaluator (replaces ArtFormula) |
| `src/UVScan.Engine.pas` | Background thread that owns the port: connect, scan, log, codes, PID search, real‑time controls |
| `src/UVScan.Simulator.pas` | Simulated AVT + PCM |
| `src/UVScan.Pids.pas` | `TPidCatalog` (pids.json): load / save, validation, value formatting |
| `src/UVScan.PidLists.pas` | `TPidLists` (lists.json) |
| `src/UVScan.Display.pas` | `TDisplaySettings` (display.json): looks, alert levels, gauge zones |
| `src/UVScan.Alerts.pas` | Alert sounds (built‑in tones) and when to play them |
| `src/UVScan.Gauge.pas` | `TGaugeView`: dial / bar / number gauge drawn with GDI+ |
| `src/UVScan.Controls.pas` | `TControlList` (controls.json): command templates, value scaling |
| `src/UVScan.LogData.pas` | `TLogData`: reads UVScan CSV logs; the made‑up demo drive; the live chart's rolling buffer (`StartLive`, `Append`) |
| `src/UVScan.LogViews.pas` | `TLogViewList` (logviews.json): saved log viewer set‑ups |
| `src/UVScan.LogChart.pas` | `TLogChart`: lanes / overlay / shared chart with cursor, zoom and pan; `Follow` keeps the newest `LiveSpan` seconds in view |
| `src/UVScan.Dtc.pas` | `TDtcCatalog` (dtcs.json) |
| `src/UVScan.Settings.pas` | `TAppSettings` (settings.json) |
| `src/UVScan.LegacyImport.pas` | Old `PIDS.csv` import and catalog merge |
| `src/UVScan.Defaults.pas` | Factory defaults built into the exe; creates missing data files |
| `src/UVScan.Paths.pas` | Data folder (`C:\ProgramData\UVScan`) |
| `src/UVScan.JsonFile.pas` | JSON helpers (atomic save) |
| `src/UVScan.Hex.pas` | Hex / byte helpers |
| `src/UVScan.MainForm.*` | Main window |
| `src/UVScan.PidEditor.*` | PID editor |
| `src/UVScan.PidDiscovery.*` | PID search dialog |
| `src/UVScan.DisplayEditor.*` | Display & alerts dialog |
| `src/UVScan.GaugeEditor.*` | Gauge dialog |
| `src/UVScan.ControlEditor.*` | Real‑time control dialog |
| `src/UVScan.LogViewer.*` | Log viewer window, also the live chart (`ShowLive`; the main form owns the live `TLogData` and calls `LiveChanged`) |
| `data/` | Factory defaults, compiled into the exe |
| `tests/` | DUnitX tests |
| `tools/UVScanProbe.dpr` | Console bench tool |
| `tools/make_sample_log.py` | Writes the sample log (see above) |
| `docs/` | This documentation and its screenshots |
| `legacy/` | The original 2008 source, for reference only; not used by the new app |

## Threading

One `TThread` (`TScanEngine`) owns the port. The UI posts commands to a `TThreadedQueue`; the engine handles them strictly one after another (request, wait for the matching reply or a timeout, next request), sends tester‑present from the same loop so it never lands in the middle of an exchange, and reports back through `TThread.Queue` events. Live values are copied into a lock‑protected snapshot that a 100 ms UI timer reads; on a phone, `ecBackground` / `ecForeground` (from the app's EnteredBackground / BecameActive events) make the engine stop the log, the scan and the connection once the app has been away longer than the setting, timed in the engine thread and checked against the wall clock on return (a frozen app's clocks may lag); every completed cycle is also queued with its time (`TakeSamples`, at most 1000 waiting) so the live chart gets each one even when the timer runs late; the grid repaints only cells whose text changed, and messages are added to the Messages tab in batches.
