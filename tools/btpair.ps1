# Pairs a classic Bluetooth device with a PIN and enables its serial port service.
# Usage: btpair.ps1 [-Name vLinker] [-Pin 1234] [-List]
param([string]$Name = 'vLinker', [string]$Pin = '1234', [switch]$List, [int]$Inquiry = 6)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Bt {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct SYSTEMTIME { public ushort y, mo, dow, d, h, mi, s, ms; }
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct DEVICE_INFO {
    public int dwSize; public ulong Address; public uint ulClassofDevice;
    public int fConnected; public int fRemembered; public int fAuthenticated;
    public SYSTEMTIME stLastSeen; public SYSTEMTIME stLastUsed;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 248)] public string szName;
  }
  [StructLayout(LayoutKind.Sequential)]
  public struct SEARCH_PARAMS {
    public int dwSize; public int fReturnAuthenticated; public int fReturnRemembered; public int fReturnUnknown;
    public int fReturnConnected; public int fIssueInquiry; public byte cTimeoutMultiplier; public IntPtr hRadio;
  }
  [StructLayout(LayoutKind.Sequential)]
  public struct RADIO_PARAMS { public int dwSize; }
  [DllImport("BluetoothApis.dll", SetLastError = true)]
  public static extern IntPtr BluetoothFindFirstRadio(ref RADIO_PARAMS p, out IntPtr hRadio);
  [DllImport("BluetoothApis.dll", SetLastError = true)]
  public static extern IntPtr BluetoothFindFirstDevice(ref SEARCH_PARAMS p, ref DEVICE_INFO info);
  [DllImport("BluetoothApis.dll", SetLastError = true)]
  public static extern bool BluetoothFindNextDevice(IntPtr hFind, ref DEVICE_INFO info);
  [DllImport("BluetoothApis.dll", SetLastError = true)]
  public static extern bool BluetoothFindDeviceClose(IntPtr hFind);
  [DllImport("bthprops.cpl", SetLastError = true, CharSet = CharSet.Unicode)]
  public static extern uint BluetoothAuthenticateDevice(IntPtr hwnd, IntPtr hRadio, ref DEVICE_INFO info, string passkey, uint len);
  [DllImport("BluetoothApis.dll", SetLastError = true)]
  public static extern uint BluetoothSetServiceState(IntPtr hRadio, ref DEVICE_INFO info, ref Guid service, uint flags);
  [DllImport("BluetoothApis.dll", SetLastError = true)]
  public static extern uint BluetoothRemoveDevice(ref ulong address);
}
'@
$rp = New-Object Bt+RADIO_PARAMS; $rp.dwSize = 4
$radio = [IntPtr]::Zero
$hr = [Bt]::BluetoothFindFirstRadio([ref]$rp, [ref]$radio)
if ($hr -eq [IntPtr]::Zero) { throw "No Bluetooth radio (error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))" }
$sp = New-Object Bt+SEARCH_PARAMS
$sp.dwSize = [Runtime.InteropServices.Marshal]::SizeOf($sp)
$sp.fReturnAuthenticated = 1; $sp.fReturnRemembered = 1; $sp.fReturnUnknown = 1; $sp.fReturnConnected = 1
$sp.fIssueInquiry = 1; $sp.cTimeoutMultiplier = $Inquiry; $sp.hRadio = $radio
$di = New-Object Bt+DEVICE_INFO
$di.dwSize = [Runtime.InteropServices.Marshal]::SizeOf($di)
$found = $null
$h = [Bt]::BluetoothFindFirstDevice([ref]$sp, [ref]$di)
if ($h -ne [IntPtr]::Zero) {
  do {
    "{0:X12}  {1,-28} paired={2} remembered={3} connected={4}" -f $di.Address, $di.szName, $di.fAuthenticated, $di.fRemembered, $di.fConnected
    if (-not $found -and $di.szName -like "*$Name*") { $found = $di }
    $di = New-Object Bt+DEVICE_INFO; $di.dwSize = [Runtime.InteropServices.Marshal]::SizeOf($di)
  } while ([Bt]::BluetoothFindNextDevice($h, [ref]$di))
  [Bt]::BluetoothFindDeviceClose($h) | Out-Null
}
if ($List) { return }
if (-not $found) { throw "No device named like '$Name' found (is it on, in range, and not connected to the phone?)" }
"Using {0:X12} {1}" -f $found.Address, $found.szName
if ($found.fAuthenticated -eq 0) {
  $r = [Bt]::BluetoothAuthenticateDevice([IntPtr]::Zero, $radio, [ref]$found, $Pin, [uint32]$Pin.Length)
  "Pair with PIN ${Pin}: result $r (0 = OK)"
} else { "Already paired" }
$spp = [Guid]'00001101-0000-1000-8000-00805F9B34FB'
$r = [Bt]::BluetoothSetServiceState($radio, [ref]$found, [ref]$spp, 1)
"Serial port service: result $r (0 = OK)"
Start-Sleep 3
$mac = '{0:X12}' -f $found.Address
Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'COM\d+' -and $_.PNPDeviceID -match $mac } | ForEach-Object { "Port: $($_.Name)" }
