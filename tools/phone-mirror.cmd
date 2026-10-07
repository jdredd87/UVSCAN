@echo off
rem Shows the phone's screen in a window on the PC, mouse and keyboard work it
rem (scrcpy over Wi-Fi debugging, so the phone's USB port stays free for the
rem adapter). Wireless debugging must be on and the PC paired once.
rem
rem scrcpy is told to use Delphi's adb: two different adb versions keep
rem restarting each other's server, which would cut the IDE off the phone.
setlocal
set ADB=C:\Users\Public\Documents\Embarcadero\Studio\37.0\CatalogRepository\AndroidSDK-37.0.59082.6021\platform-tools\adb.exe

set SCRCPY=
for /f "delims=" %%s in ('where scrcpy 2^>nul') do if not defined SCRCPY set SCRCPY=%%s
if not defined SCRCPY for /f "delims=" %%s in ('dir /s /b "%LOCALAPPDATA%\Microsoft\WinGet\Packages\scrcpy.exe" 2^>nul') do if not defined SCRCPY set SCRCPY=%%s
if not defined SCRCPY (
  echo scrcpy not found. Install it with:  winget install --id Genymobile.scrcpy
  pause
  exit /b 1
)

rem The phone's address: already connected, else announced on the network.
set DEV=
for /f "tokens=1,2" %%a in ('"%ADB%" devices') do if "%%b"=="device" echo %%a | findstr /r "^[0-9][0-9]*\." >nul && if not defined DEV set DEV=%%a
if not defined DEV for /f "tokens=3" %%a in ('"%ADB%" mdns services ^| findstr _adb-tls-connect') do if not defined DEV set DEV=%%a
if not defined DEV (
  echo Phone not found. Turn on Settings ^> Developer options ^> Wireless debugging
  echo on the same Wi-Fi as this PC, then run this again.
  pause
  exit /b 1
)
"%ADB%" connect %DEV% >nul

start "" "%SCRCPY%" -s %DEV% --window-title "Phone - UVScan" --stay-awake --max-size 1600
