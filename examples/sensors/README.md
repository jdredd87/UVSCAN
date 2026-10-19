# Example sensor files

Sensor files for UVScan's **Sensors** page (see the user guide's [Sensors](../../docs/user-guide.md#sensors) section): a sensor and its PIDs, ready to import. They are also examples to copy when you set up a device of your own.

| File | What it is |
|---|---|
| [`arduino-text.uvsensor`](arduino-text.uvsensor) + [`arduino-text.ino`](arduino-text.ino) | An Arduino sending a line of text ten times a second: `egt=812 oilp=45.2 boost=7.3`. PIDs: EGT, oil pressure, boost. The simplest way to add any sensor of your own. |
| [`arduino-packet.uvsensor`](arduino-packet.uvsensor) + [`arduino-packet.ino`](arduino-packet.ino) | The same idea as binary packets (*Fixed packets*), the way many commercial boxes send: layout `start AA 55; length 8; egt 2-3; boost 4-5 signed; battery 6; count 7`, with the PIDs' formulas scaling the raw numbers. |
| [`plx-afr-egt-boost.uvsensor`](plx-afr-egt-boost.uvsensor) | A PLX chain of SM‑AFR, SM‑EGT and SM‑Boost on the iMFD serial / USB adapter: AFR, EGT in °F, boost in psi (PLX's own conversions). |
| [`innovate-two-widebands.uvsensor`](innovate-two-widebands.uvsensor) | Two Innovate LC‑1s in an MTS chain, or an LM‑2 with two sensors: an AFR for each bank, and a calculated PID with the difference between them. |

Single devices (Innovate LC‑1 / LC‑2 / LM‑2 / MTX‑L, AEM X‑Series, PLX, Zeitronix, Tech Edge, a demo wideband) are built in as templates: **Sensors… → Add…**.

## Importing one

- **Windows:** *Connect* page → **Sensors…** → **Import…**, and pick the file.
- **Phone:** get the file onto it (email it to yourself, Google Drive, Downloads…), then **Sensors…** → **Import…** opens Android's file picker.

Then choose the sensor's **Port**, try it with **Start test**, and **Save**. Its PIDs are in the PID list under *Sensors*; tick them like any others. A sensor or MCI name you already have gets a number (`EGT 2`, `%EGT2%`), and the file's own formulas follow.

## Making your own

The easiest way: set the sensor up on the Sensors page (or start from one of these), add PIDs for its fields from **Start test**, then **Export…** (Windows) or **Share…** (phone) writes a `.uvsensor` file. The port is left out; whoever imports it picks their own.

The files are plain JSON, so they can also be written by hand:

```json
{ "uvscanSensor": 1,
  "sensor": { "name": "...", "protocol": "text", "baud": 9600 },
  "pids": [ { "name": "...", "kind": "sensor", "field": "egt", "formula": "N0 * 9 / 5 + 32", "units": "°F" } ] }
```

- `protocol`: `mts` (Innovate), `text` (lines of text), `plx` (PLX iMFD) or `packet` (fixed packets, with a `layout`). The fields each one gives, and the layout's syntax, are in the [user guide](../../docs/user-guide.md#sensors) and [data files](../../docs/data-files.md#sensorsjson).
- A device that only answers when asked: `"send": "R\r", "sendEveryMs": 200` (what to send, and how often).
- PIDs: `field` is the sensor's value to show and `N0` in `formula` is that value (no formula: as it is). `mci` lets other formulas use it as `%NAME%`. PIDs of other kinds (a `calculated` one over the sensor's) can be in the file too.
