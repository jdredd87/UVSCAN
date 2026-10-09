# Testing with a network AVT

UVScan can reach an AVT over the network instead of a serial cable: an AVT with an Ethernet port (838 / 842), or an AVT‑841 behind a serial‑to‑Ethernet adapter. The old UVSCAN did this, and the new one sends the same bytes the same way, as a plain TCP connection. It has been tested against UVScan's simulator served on the network, from Windows, an Android emulator and a Samsung phone, but **not yet against a real network AVT**. If you have one, this page is everything needed to try it and send back what happened. It takes about 15 minutes.

UVScan only reads from the vehicle during these steps. It doesn't clear codes, write anything, or run any controls.

## What you need

- **The AVT on your network**, and its **IP address and port**. UVScan's default port is **10001**, the one the old UVSCAN used. If it's set differently, the AVT's network module setup page or tool shows it.
- **A Windows PC** on the same network (and, if you can, an **Android phone** on the same Wi‑Fi).
- **A GM vehicle with Class 2 (J1850 VPW)**, roughly 1996–2008, key on or engine running. Step 1 is useful even without one.
- **UVScan**: `UVScan.exe` and `UVScanProbe.exe` (Windows) and `UVScan.apk` (Android), from whoever sent you this page. Run `UVScan.exe` once first; it creates its data files in `C:\ProgramData\UVScan`.

Close UVScan before running `UVScanProbe`, and the other way round: an AVT on the network usually takes one connection at a time.

## 1. Does the AVT answer? (no vehicle needed)

In a command prompt, in the folder with `UVScanProbe.exe`, with your AVT's address:

```
UVScanProbe 192.168.2.99:10001 raw > probe-raw.txt
```

It sends the AVT's start‑up commands and records every byte that comes back for a few seconds. Lines starting `RX` mean the AVT answered.

## 2. A short read‑only session (vehicle, key on)

```
UVScanProbe 192.168.2.99:10001 run 30 1,3,7,8,11,12 > probe-run.txt
```

This connects, reads the AVT firmware, VIN and PCM OS ID, tests six PIDs (engine speed, coolant temperature, MAP, vehicle speed, throttle and ignition voltage), scans them for 30 seconds, and reads the trouble codes.

## 3. In UVScan (Windows, then Android if you can)

1. **Tools → Show raw traffic in Messages**: tick it.
2. On **Connect**, pick **Network (TCP/IP)**, type the address (e.g. `192.168.2.99:10001`) and press **Connect**. Under *Vehicle* you should see the AVT firmware, the VIN and the OS ID.
3. Tick a few PIDs on the **PIDs** page and press **Start scan**. Let it run for a minute. Note the *updates/s* in the status strip at the bottom.
4. While it scans, **unplug the AVT's network cable** (or turn the AVT off) and note what UVScan says, and after how long.
5. Plug it back in, wait a few seconds, and press **Connect** again. Does it connect?
6. On **Messages**, press **Copy** (on a phone: **⋮ → Copy all**) and paste the text into a file or an email.

## What to send back

- `probe-raw.txt` and `probe-run.txt`.
- The Messages text from step 3.6 (one per device if you tried Windows and Android).
- The AVT model and firmware, its network module if you know it, and the port it uses.
- The vehicle (year, model, engine).
- The *updates/s* from step 3.3, what happened in steps 3.4 and 3.5, and anything that looked wrong.

## If it doesn't connect

| UVScan says | Meaning |
|---|---|
| *Could not connect to … Connection refused* | Nothing is listening on that port at that address. Check the port number. |
| *No answer from … within 5 seconds* | Nothing at that address on this network, or a firewall in between. Check the IP address, and that the PC or phone is on the same network. |
| *… accepted the connection but no AVT answered* | Something is listening there, but it doesn't reply like an AVT: the AVT is off behind its network module, the module's serial settings don't match the AVT, or it's another device. That's still worth sending back, with `probe-raw.txt`. |
