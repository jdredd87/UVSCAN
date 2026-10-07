# Protocol notes

What UVScan sends and why, as measured with an **AVT‑841** on a bench **2001 3.8L PCM** (OS ID 9389759, no engine). Bytes are hex. `6C` is the Class 2 priority/type byte, `10` the PCM, `F1` the scan tool (`F0` for PID tests and searches), `FE` all nodes.

## AVT‑841 framing

- Each frame starts with a header byte: high nibble = kind, low nibble = length. `$11` would mean an extended length byte follows (assumed, not yet seen).
- Init: `E1 33` → `91 07`; `B0` → `92 04 13` (firmware 4.13 shown as `04 13`).
- Every bus message UVScan sends is confirmed by the AVT with `01 60`.
- Received bus messages arrive as `0N 00 <message>` (status byte `00`).
- A single duplicated header byte was seen once; the parser resynchronises.
- Serial: 115200 baud, 8N1, RTS/CTS.

## Reading a PID (mode $22)

`6C 10 F0 22 hi lo 01` → `6C F0 10 62 hi lo data…`, or `7F 22 … ` when the PCM does not have it. Used by *Test PIDs* and *Search PCM for supported PIDs*. The bench PCM answers 17 SAE PIDs ($00xx) and 294 GM PIDs ($1xxx).

## Streaming (DPIDs, modes $2C / $2A)

1. Ticked vehicle PIDs are packed into DPIDs: each carries 6 data bytes (positions 1–6), numbered from `$FE` down, at most 8 DPIDs (48 bytes). PIDs are placed largest first and never split across DPIDs.
2. Each slot is defined with `6C 10 F1 2C <dpid> <40 | pos<<3 | size> <pid hi> <pid lo> FF FF`. The PCM confirms each with `6C F1 10 6C <dpid> <cfg>` (or `7F 2C …` to refuse) and UVScan waits for that before sending the next.
3. Streaming is requested with `6C 10 F1 2A <slot|speed> d1 d2 d3 d4`, always with exactly 4 DPID entries (unused = `00`); anything else gets `7F 2A … 12` and no data. `7F 2A … 23` means *accepted, data follows*.
4. The PCM has **two schedule slots** (`$1x`, `$2x`) of up to 4 DPIDs each; a request replaces its slot's list. The low nibble is the speed: `4` fast, `3` medium, `2` slow. At speed 4 each slot sends each of its DPIDs about 5 times a second.
   - ≤ 4 DPIDs (≤ 24 bytes): the same list goes in both slots → **about 10 updates/s**.
   - 5–8 DPIDs: the first four in slot 1, the rest in slot 2 → **about 5 updates/s**.
5. `2A 00` only **pauses**; the next request resumes the other slot's old list. So UVScan sends `2A 00` and clears both slots (`2A 14 00 00 00 00`, `2A 24 00 00 00 00`) before every scan and when stopping.
6. Data arrives as `6C F1 10 6A <dpid> d1..d6`. A cycle completes when every planned DPID has arrived; then calculated PIDs are worked out and a log row is written.
7. Tester present (`6C FE F1 3F`) every 2 s keeps the stream alive.

### Legacy PID‑send bugs this fixes

- **Stale DPIDs came back to life.** The 2008 code never cleared the PCM's schedule slots, and `2A 00` only pauses. After a scan with more than 4 DPIDs, any later scan resumed the old slot‑2 DPIDs, so the PCM streamed data nobody asked for.
- When the last DPID was exactly full, it requested the **next, never‑defined DPID**, and calculated PIDs / log rows (triggered by that DPID) silently stopped.
- The 48‑byte limit check used an uninitialised variable, so more than 8 DPIDs could be defined; the extras were never requested or decoded.
- Definitions were sent on fixed delays without waiting for the PCM's confirmation, and a refused PID restarted the whole definition loop mid‑stream.
- Small scans ran at 5 Hz where 10 Hz is possible.

## Trouble codes

Modules are found with a broadcast (`6C FE F1 20`, every module answers `60`), then each is asked for its codes with mode `$19` (`19 08 FF 00`, list ends with `00 00 FF`). Clearing sends `20`, `10 00` and `14` to the PCM.

## VIN and OS ID

Read with mode `$3C` blocks; the VIN is written with mode `$3B` blocks (`3B 01` + 6 bytes, `3B 02`, `3B 03`), after which the key must be off for 15 s.

## Device control (mode $AE)

Real‑time controls use mode **$AE**: `6C 10 F1 AE <CPID> b1 b2 b3 b4 b5 b6`. The PCM answers `6C F1 10 EE <CPID> E1` when it accepts the request, or `7F AE <CPID> … <code>` when it does not. GM modules drop device control a few seconds after tester‑present stops, and mode `$20` (return to normal, answered with `60`) ends it at once — UVScan keeps tester‑present going while a control is active and sends the releases plus `$20` on *Release all*, disconnect and exit.

### What the bench PCM (2001 3.8L, OS 9389759) does

Found with the bench tool (`UVScanProbe cpids / cpidlen / cpidmap / cpidconfirm`, see [development](development.md#bench-tool)):

- **CPIDs `$01`–`$04` exist**; every other CPID answers `7F AE … 31` (request out of range).
- Each takes **exactly 6 control bytes**; any other length answers `7F AE … 12`.
- **CPID `$01` is the discrete outputs**, as three *mask / value* byte pairs: `AE 01 m1 v1 m2 v2 m3 v3`. A bit set in a mask byte takes control of that output; the same bit in the following value byte switches it on (1) or off (0). All‑zero data hands everything back to the PCM.

  | Bytes after `AE 01` | Output | Status PID / bit | Checked |
  |---|---|---|---|
  | `80 80` / `80 00` | Check engine lamp (MIL) on / off | `$1104` bit 0 | off ✔ (lamp was already on) |
  | `20 20` | Change oil lamp on | `$1104` bit 4 | on ✔ |
  | `10 xx` | Low oil lamp | `$1104` bit 2 | off ✔ |
  | `08 xx` | Generator (battery) lamp | `$1104` bit 3 | off ✔ |
  | `04 xx` | Engine hot lamp | `$1104` bit 1 | off ✔ |
  | `00 00 80 80` | Cooling fan 1 on | `$1103` bit 6 | on ✔ |
  | `00 00 08 08` | EVAP vent solenoid on | `$1107` bit 2 | on ✔ |
  | `00 00 00 00 40 00` | Fuel pump speed (high) off | `$1104` bit 7 | off ✔ |
  | `00 00 00 00 10 00` | Cruise inhibit command off | `$1102` bit 6 | off ✔ |

  "Checked" means: with the control set the status PID changed, with it released the PID went back, three times in a row. Other bits were accepted but showed no clear effect without real loads connected.

- Because one CPID carries several outputs, the PCM only knows the last packet sent. UVScan therefore **merges** active controls of the same module and CPID: turning the fan on while the MIL is forced on sends `AE 01 80 80 80 80 00 00`, and switching the MIL off then sends `AE 01 00 00 80 80 00 00`.
- **CPID `$02` is resets.** Its bits change learned values that stay changed after mode `$20` (on the bench: `$119F` engine oil life, `$121E`, and with `$40` — the original UVSCAN's fuel trim reset — `$1929`). Which bit resets what could not be pinned down on a bench PCM with no engine; only the fuel trim reset from the old program is built in.
- **CPIDs `$03` and `$04`** are accepted and change a group of transmission‑ and idle‑related PIDs (`$1996`, `$1997` 1‑2 shift error, `$19A0`, `$1A1B`) that also stay changed. They look like value / learn controls and are not built in.

The probe runs reset some learned values on the bench PCM. Use the reset CPIDs on a vehicle only when you mean to.

## Not yet checked on a running vehicle

- [ ] Values with the engine running (the bench PCM only shows defaults)
- [ ] Analog inputs (`52 59 01` → `64 58 a1 a2 a3`)
- [ ] Trouble codes from a vehicle with real faults; clearing codes; VIN write
- [ ] Real‑time controls with the outputs connected to real loads
- [ ] AVT frames with header `$11` (extended length)
