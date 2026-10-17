# Development

## Building

Delphi 13 (RAD Studio 37.0), FireMonkey (FMX): Win32 and Android64 (Win32 Debug for development; the setup program uses Win32 Release). No third‑party components: the serial port, AVT protocol, formula evaluator, JSON handling, grid, gauges and chart are all in `src\`. The last VCL version is git tag `vcl-final`.

Open `UVScan.dproj` in the IDE, or from a command prompt:

```
build.cmd
```

That builds the app (`Win32\Debug\UVScan.exe`), builds and runs the DUnitX tests (`tests\UVScanTests.dproj`), and builds the console tools (`tools\Win32\UVScanProbe.exe`, the bench tool, `tools\Win32\UVScanSimServer.exe`, the simulator on the network, and `tools\Win32\UVScanAgent.exe`, for [testing on another PC](#testing-on-another-pc)). It stops at the first failure.

### Android

```
build.cmd android [install]
```

builds `Android64\Debug\UVScan\bin\UVScan.apk` and, with `install`, puts it on the phone attached over adb. The Android SDK profile is passed explicitly (`UV_ANDROID_SDK`, default `AndroidAPI36.1_64bit.sdk`) because the IDE default can still name an SDK folder from an older Delphi update. The Android project files:

- `AndroidManifest.template.xml`: Delphi 13's template plus the USB host feature and the "USB device attached" filter.
- `deploy\android\device_filter.xml`: the USB adapters UVScan can drive (deployed to `res\xml`).
- `UVScan.deployproj`: what goes into the APK.

On Android the data folder is the app's private documents folder, and logs go to `Android/data/com.jdredd87.uvscan/files/Logs` (reachable over USB). The serial port is USB host (`UVScan.Serial.Android`): FTDI (the AVT‑841's own USB port, if it is FTDI), CP210x, CH340/CH341, CDC‑ACM and the Keyspan USA‑19HS (the bench's COM9 adapter; its firmware is in ROM, and the other Keyspan models, which need firmware loaded, are not supported). Android asks for permission the first time; connect again after allowing it.

Receiving has a thread of its own (`TUsbReader`) that always keeps one `UsbRequest` queued on the IN endpoint and waits in `requestWait`; `Read` takes from what it collected. Reading with `bulkTransfer` and a timeout lost data: when the timeout ran out as a packet arrived, the packet was thrown away, and the scan engine reads with timeouts of 20 ms (on the S9+ with the Keyspan, 9.3 instead of 10 rows/s). The Keyspan runs in DMA mode above 57600 baud, as in the Linux driver; in its "by hand" mode at 115200 nearly every byte came in a USB packet of its own. With the forwarding length and timeout of 1 that UVScan sets, short replies are not held back in DMA mode.

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

The factory data in `data\` is compiled into the exe through `UVScan.Defaults.rc` (`UVScan.Defaults.res` is generated and not in git). At startup `AddNewBuiltIns` (`UVScan.Defaults`) brings an existing install's files up to date with it (see [data files](data-files.md#data-files)), so when changing `data\`:

- `pids.json`: give a new PID a new `id` and never reuse the id of one taken out; installs know the built-ins by id. Fixing a built-in PID in place is fine: installs whose copy is unchanged get the fix.
- `controls.json`: raise `"defaults"` when adding built-in controls, or installs will not get them.
- `lists.json`, `logviews.json`, `display.json`: a new built-in needs a new name; changing an existing one does not reach installs that have it.
- `dtcs.json`: any change reaches every install.

### Version

`AppVersion` in `src\UVScan.Version.pas` is the version, changed by hand (major.minor.patch; the rewrite started at 2.0.0, after the VCL UVSCAN's 10.18.08b). Change the version info in `UVScan.dproj` to match (*Project → Options → Version Info*: Windows file version, Android `versionName`). Before each build (IDE or `build.cmd`, either platform) the project runs `tools\stamp.ps1`, which writes `src\UVScan.BuildStamp.inc` (not in git): the build number (the commit count), the commit (with `+` when built with uncommitted changes) and the date. UVScan shows them in the title bar, *More → About* and the first line of *Messages*.

### Installer

```
build.cmd installer
```

builds `Win32\Release\UVScan.exe` and the setup program `installer\Output\UVScan-<version>-build<n>-setup.exe` from `installer\UVScan.iss` with [Inno Setup 6](https://jrsoftware.org/isinfo.php) (`winget install JRSoftware.InnoSetup --scope user`; a build tool only, nothing of it is in UVScan). `tools\installer.ps1` passes the version and build number. The setup installs just `UVScan.exe`, for the current user (no admin, `%LOCALAPPDATA%\Programs\UVScan`) or, chosen in its first dialog, for all users (Program Files; it then gives Users modify rights on `C:\ProgramData\UVScan`). Start menu shortcut, desktop icon (ticked by default), uninstall from *Settings → Apps*, which keeps the data and the logs. Silent: `/VERYSILENT /CURRENTUSER` (or `/ALLUSERS`), `/DIR="..."`. UVScan's update runs it with `/SILENT /SUPPRESSMSGBOXES /NORESTART`: a progress window only, the earlier choices (for whom, where, the desktop icon) kept, and UVScan started again afterwards (as the user, also when the setup ran as admin); an all-users install still asks for admin permission. Because UVScan is still closing when the setup starts, a silent setup first waits (up to 10 s) for the mutex UVScan holds while it runs (`UVScanRunning`); otherwise it would find UVScan running and, unable to ask, give up. Copies before 2.0.2 start it without switches, so their update is the full wizard. It is not signed, so SmartScreen warns the first time (*More info → Run anyway*).

### Releases

A release is a GitHub release tagged `v<AppVersion>` with the setup program attached; UVScan's update check (`src\UVScan.Update.pas`) reads `releases/latest` from the GitHub API, compares its tag with `AppVersion` and, on Windows, downloads the asset ending in `-setup.exe` (a phone opens the release page; an `.apk` asset is recognised for later). Drafts and pre-releases are not offered. To release:

1. Raise `AppVersion` in `src\UVScan.Version.pas` and the version info in `UVScan.dproj` (Windows file version, Android `versionName`) to match; commit and push.
2. `powershell -File tools\release.ps1` (`-Notes notes.md` for your own text, `-DryRun` to stop before tagging).

It checks that everything is committed and pushed, the two versions agree and the tag is new; runs `build.cmd` (build and tests) and `build.cmd installer`; then tags, pushes the tag and makes the release with `gh`. Its default notes say how to install and list the commits since the previous release. UVScan shows, in the question whether to install, only the section of the notes under the first heading that says *new* or *change* (*### What’s new*, *### Changes since v2.0.0*), as plain text; write one in your own notes. Builds between releases keep the version and differ in the build number, so the update check only offers a release with a higher version.

## Tests

`tests\` holds DUnitX tests for the protocol pieces (AVT framing, Class 2 messages, DPID planning, the formula evaluator), the JSON files, the legacy CSV import, display levels and alerts, real‑time controls (including how active device controls are merged), log reading and saved views, and end‑to‑end engine runs against the simulator (connect, scan, log, PID test, discovery, stop/restart). They run on both platforms and report memory leaks.

## Adapters

The engine (`UVScan.Engine`) speaks Class 2 messages; `UVScan.Adapter` turns them into what the hardware wants. `TAvtAdapter` is the AVT's binary framing (`UVScan.Avt`). `TElmAdapter` drives an ELM327 through `TElmLink` (`UVScan.Elm`: commands, the prompt, reply lines) and hands the engine the same frames an AVT would (status byte 00, then the message), so matching replies, DPID data and logs are the same for both. Standard ELM327 commands only: `ATZ ATE0 ATL0 ATS0 ATH1 ATAL ATSP2`, `ATSH` when the header changes, `ATSR`/`ATAR` for replies to F0 (the PID test asks from F0), `ATMA`.

How the ELM keeps a DPID stream coming (worked out with `tools\ElmProbe`, see below): a request makes it listen until the bus is quiet for its timeout, and the PCM's bursts have gaps, so while streaming the adapter answers its prompt with `ATMA`. Every request (the tester present every 2 s) has to stop that first: a space (at the prompt a space is ignored, where a CR would repeat the last command), then the request, whose own listening carries the stream on. Frames that arrive between the space and "STOPPED" are kept (over a phone's Bluetooth that is two or three frames).

On Android a paired Bluetooth adapter is a port of its own (`UVScan.Bluetooth.Android`, an RFCOMM socket with a reader thread), listed by `ListSerialPorts` as `BT <name> [<address>]`. `IsBluetoothPortName` keeps those names from being taken for network addresses (they have colons).

Measured with the vLinker FD on the bench PCM, 10 PIDs in 3 DPIDs: UVScan on the laptop (COM4) 9.7 rows/s; on the S9+ 9.4 rows/s: a phone's Bluetooth now and then holds data back ~0.15 s (late, not lost), and stopping the ELM for the tester present takes longer there (~0.3 s). `UVScanProbe COM4 run 30 1,3,12 -elm [-trace] -notest -nodtc` runs the engine against an ELM; `-trace` keeps the raw traffic on while streaming.

## Simulator

`UVScan.Simulator.Elm.pas` puts a simulated ELM327 v1.5 in front of the same PCM: ELM text, echo / spaces / headers as after ATZ, listening until the bus is quiet ("NO DATA" when nothing came), ATMA, "STOPPED" on any character while listening, replies only for the receive address, CRC bytes, at most 7 data bytes without ATAL. Port **Simulator** with **ELM327** chosen uses it; so do the tests in `UVScan.Tests.Elm`.

`UVScan.Simulator.pas` is an `ISerialPort` that behaves like an AVT‑841 with a PCM behind it, built from what the bench PCM actually did: AVT init answers, `01 60` transmit confirmations, DPID definition replies, the two stream slots and their rates, `2A 00` pausing, NRC codes for bad requests, mode $22 PIDs, trouble codes in several modules, VIN blocks, and mode $AE device control (CPIDs $01‑$04 with exactly 6 bytes, NRC $12 / $31 otherwise). Choose port **Simulator** in the app; the tests use it too. When the bench shows new behaviour, add it here.

### Network AVT

An AVT with an Ethernet port (as the old UVSCAN supported through AsyncPro's Winsock port) carries the same bytes over a raw TCP connection. `TTcpSerialPort` in `UVScan.Serial` is that `ISerialPort`, on `System.Net.Socket` (Windows and Android alike): it connects on a thread of its own and gives up after 5 s, turns Nagle off (the AVT's exchanges are a few bytes each), and on Android sends with `MSG_NOSIGNAL` so a dropped connection is an error, not a signal that ends the app. Port **Network (TCP/IP)** in the app, `host:port` on the command line and in the bench tool.

`TSimulatorServer` (in `UVScan.Simulator`) serves the simulator on the network, a simulator per connection: the tests connect to it on `127.0.0.1`, and `tools\Win32\UVScanSimServer.exe [port] [address]` runs it for trying the network connection from the app:

```
UVScanSimServer 10001 127.0.0.1   this PC only (no firewall question)
UVScanSimServer                   port 10001 on every network (Windows asks once about the firewall)
```

From an Android emulator the PC is `10.0.2.2`; a phone on USB can use `adb reverse tcp:10001 tcp:10001` and `127.0.0.1:10001`; a phone on the Wi‑Fi uses the PC's address.

## Bench tool

`tools\UVScanProbe.dpr` is a console program for real hardware. Close UVScan first (only one program can open the COM port). Instead of `COM9` it takes an AVT on the network as `host:port`.

```
UVScanProbe COM9 raw [baud] [rtscts|none]   AVT init frames, raw bytes
UVScanProbe COM9 run 5 1,3,12 [-notest] [-nodtc] [-speed 4] [-log f.csv] [-search 0000-00FF,1000-1FFF]
                                            connect, PID test, (PID search,) 5 s scan (logged), DTC read (read-only)
UVScanProbe COM9 rawscan | rates | multi    stream experiments (DPID slots and rates)
UVScanProbe COM9 sweep 0000-00FF,1000-1FFF  list every PID the PCM answers (mode $22, read-only)
UVScanProbe COM9 cpids 00 FF                device control survey: each CPID with all-zero data
UVScanProbe COM9 cpidlen 01,02              which control lengths each CPID accepts
UVScanProbe COM9 cpidmap pids.txt 01,02     set control bits one by one, read every PID, show changes
UVScanProbe COM9 cpidconfirm 01 1104,110C 3 repeat single-bit tests, keep effects that follow every time
```

`cpids`, `cpidlen`, `cpidmap` and `cpidconfirm` **send device control commands**; `cpidmap` on CPID $02 resets learned values. They end with mode $20 (return to normal). See [protocol notes](protocol.md#device-control-mode-ae).

## ELM327 probe

`tools\ElmProbe\ElmProbe.dproj` is a small FMX app (Windows and Android) for trying ELM327 type adapters on Class 2 before UVScan supports them. It uses `src\UVScan.Elm.pas` (the ELM's text protocol over any `ISerialPort`) and `src\UVScan.Bluetooth.Android.pas` (a paired classic Bluetooth adapter as an `ISerialPort`), both meant for UVScan later. Pick the adapter (Android: a paired Bluetooth device; Windows: a COM port, which is what a paired Bluetooth adapter becomes, or a Wi-Fi address such as `192.168.0.10:35000`) and **Run tests**: adapter id and voltage, J1850 VPW, VIN and OSID, mode $22 reads and their speed, DTCs, DPID definitions, then four 20-second DPID streams (one slot or both, kept listening by ATMA or by the request, a tester present every 2 s). Every byte both ways is logged with times, on screen and in `ElmProbe\ElmProbe_<time>.txt` (Documents on Windows, the app's files folder on Android). It can be started straight into the tests:

```
ElmProbe.exe -port COM12 [-baud 38400] -run [-exit]
adb shell am start -n com.jdredd87.elmprobe/com.embarcadero.firemonkey.FMXNativeActivity --es port vLinker --ez run true
```

Build it as UVScan: `msbuild tools\ElmProbe\ElmProbe.dproj /t:Build;Deploy /p:Platform=Android64 /p:PlatformSDK=AndroidAPI36.1_64bit.sdk` (or `/p:Platform=Win32`).

What it found with a vLinker FD (an STN1151 chip, answers as "ELM327 v2.2") over Bluetooth on the S9+, against the bench PCM: Bluetooth connect 0.3-1.9 s; VIN and OSID read; mode $22 9 reads/s; DPID streams at the AVT's rates: each DPID 9.5 rows/s with both slots, 4.8 with one. The ELM stops listening when the bus is quiet for a moment (with one slot the PCM pauses ~150 ms between bursts), so it is kept listening by ATMA, by both slots, or by ATAT0 + ATST FF; and the PCM drops back to normal mode (`6C F1 10 60`) about 5 s after the last tester present, so a `3F` every 2 s (the ELM stopped for it, ~250 ms) keeps the stream going.

On Windows a paired classic Bluetooth adapter is a COM port ("Standard Serial over Bluetooth link"), which `TWin32SerialPort` drives unchanged. `tools\btpair.ps1 [-Name vLinker] [-Pin 1234] [-List]` pairs one without the Settings app (it also works through the agent: `agent put tools\btpair.ps1 btpair.ps1`, then `agent run "C:\Windows\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File C:\UVScanAgent\btpair.ps1"`) and prints the COM port. The vLinker FD on the laptop (COM4): the same results, streams at 9.8-9.9 rows/s per DPID with both slots, longest gap 109 ms.

## Testing on another PC

A laptop at the car (or wherever the AVT is) needs no Delphi: `tools\UVScanAgent.exe` runs there, and `tools\agent.ps1` on the development PC sends it builds, runs them, clicks and types in them, takes screenshots and fetches files, over the home network.

1. `powershell -File tools\agent.ps1 kit` makes `..\UVScanAgent-kit\UVScanAgent.zip` with the agent, a new token and `install.cmd`.
2. On the laptop, unzip it and run `install.cmd` as administrator: it copies the agent to `C:\UVScanAgent`, lets it through Windows Firewall from the local network only, and starts it (`install signin` also starts it at sign-in, `install remove` undoes it all). Or just run `UVScanAgent.exe` and allow it when the firewall asks.
3. `agent find` looks for it on this PC's networks and remembers it.

```
agent deploy                           this build (UVScan, UVScanProbe, UVScanSimServer) to C:\UVScanAgent\UVScan
agent info                             Windows, screen, serial ports (with the driver, which names the chip)
agent run "UVScan\UVScanProbe.exe COM3 run 20 1,3,7" 120    hidden; prints the output, exits with its code
agent ps "Get-ChildItem C:\ProgramData\UVScan"               the same through PowerShell
agent start UVScan\UVScan.exe          on the laptop's desktop
agent shot lap.png [title]             the screen, or one window
agent click 517 860 [title]            screen pixels, or the window's client pixels with a title
agent key 13 [csaw] [title]  |  agent text "..." [title]  |  agent windows  |  agent kill UVScan
agent get %ProgramData%\UVScan\settings.json  |  agent put file [remote]  |  agent ls [folder]
```

Every request but `/ping` needs the token from the kit (kept in `%LOCALAPPDATA%\UVScanAgent\target.txt` here), because the agent runs whatever it is sent. Its window logs each request. It keeps the laptop awake with the screen on while it runs; a locked screen stops clicks and screenshots. The protocol is plain HTTP, listed at the top of `tools/UVScanAgent.dpr`.

## Sample log

`python tools\make_sample_log.py [file.csv]` writes a made-up 25-minute drive (10 rows a second, 20 channels: cold start, city, on-ramp and passing pulls with knock retard, highway with the converter clutch locked, a hot idle with the fan and A/C cycling) as a UVScan log, by default `UVScan_sample_drive.csv` in *Documents\UVScan Logs*, for trying the log viewer and playback with more than the built-in demo.

## Source layout

| Path | Purpose |
|---|---|
| `src/UVScan.Serial.pas` | Win32 serial port (no AsyncPro), COM port list, the network AVT (TCP) |
| `src/UVScan.Avt.pas` | AVT frame encoding / parsing (header = kind nibble + length nibble) |
| `src/UVScan.Class2.pas` | GM Class 2 message builders and parsers, DTC formatting, NRC texts |
| `src/UVScan.Dpid.pas` | Packs PIDs into DPIDs ($FE down, 6 data bytes each) and builds stream requests |
| `src/UVScan.Formula.pas` | PID formula evaluator (replaces ArtFormula) |
| `src/UVScan.Engine.pas` | Background thread that owns the port: connect, scan, log, codes, PID search, real‑time controls |
| `src/UVScan.Simulator.pas` | Simulated AVT + PCM, and the simulator served on the network |
| `src/UVScan.Simulator.Elm.pas` | Simulated ELM327 in front of the simulated PCM |
| `src/UVScan.Adapter.pas` | The adapter layer: AVT and ELM327 |
| `src/UVScan.Elm.pas` | The ELM327 text protocol |
| `src/UVScan.Bluetooth.Android.pas` | Paired Bluetooth adapters on Android |
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
| `src/UVScan.Version.pas` | Version and build stamp (`tools\stamp.ps1`) |
| `installer/UVScan.iss`, `tools/installer.ps1` | The Windows setup program (`build.cmd installer`) |
| `src/UVScan.Update.pas`, `tools/release.ps1` | Update check, and making a release |
| `src/UVScan.JsonFile.pas` | JSON helpers (atomic save) |
| `src/UVScan.Hex.pas` | Hex / byte helpers |
| `src/UVScan.MainForm.*` | Main window |
| `src/UVScan.PidEditor.*` | PID editor |
| `src/UVScan.PidDiscovery.*` | PID search dialog |
| `src/UVScan.DisplayEditor.*` | Display & alerts dialog |
| `src/UVScan.GaugeEditor.*` | Gauge dialog |
| `src/UVScan.ControlEditor.*` | Real‑time control dialog |
| `src/UVScan.LogViewer.*` | Log viewer window; also the live chart, a second viewer whose contents (`FRoot`) sit in the Live page (`EmbedLive`; the main form owns the live `TLogData` and calls `LiveChanged`) |
| `data/` | Factory defaults, compiled into the exe |
| `tests/` | DUnitX tests |
| `tools/UVScanProbe.dpr` | Console bench tool |
| `tools/UVScanSimServer.dpr` | The simulator on the network, for the Network (TCP/IP) connection |
| `tools/UVScanAgent.dpr`, `tools/agent.ps1`, `tools/UVScanAgent-install.cmd` | Testing on another PC (see above) |
| `tools/ElmProbe/`, `tools/btpair.ps1` | ELM327 probe, Bluetooth pairing on Windows (see above) |
| `tools/make_sample_log.py` | Writes the sample log (see above) |
| `docs/` | This documentation and its screenshots |

## Threading

One `TThread` (`TScanEngine`) owns the port. The UI posts commands to a `TThreadedQueue`; the engine handles them strictly one after another (request, wait for the matching reply or a timeout, next request), sends tester‑present from the same loop so it never lands in the middle of an exchange, and reports back through `TThread.Queue` events. Live values are copied into a lock‑protected snapshot that a 100 ms UI timer reads; on a phone, `ecBackground` / `ecForeground` (from the app's EnteredBackground / BecameActive events) make the engine stop the log, the scan and the connection once the app has been away longer than the setting, timed in the engine thread and checked against the wall clock on return (a frozen app's clocks may lag); every completed cycle is also queued with its time (`TakeSamples`, at most 1000 waiting) so the live chart gets each one even when the timer runs late; the grid repaints only cells whose text changed, and messages are added to the Messages tab in batches.
