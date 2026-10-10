@echo off
rem Installs UVScanAgent (from this folder) in C:\UVScanAgent, lets it through Windows
rem Firewall from this PC's own network only, and starts it. Run as administrator.
rem The kit names it install.cmd.
rem   install            as above
rem   install console    then hands this remote desktop session to the PC's own screen, so
rem                      the agent can still see and click in it after the remote desktop ends
rem   install signin     also starts it whenever you sign in
rem   install remove     stops it and removes all of the above
setlocal
net session >nul 2>&1 || (echo Run this as administrator: right-click it, Run as administrator.& pause & exit /b 1)
set DEST=C:\UVScanAgent
set STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\UVScanAgent.cmd
taskkill /im UVScanAgent.exe /f >nul 2>&1
netsh advfirewall firewall delete rule name=UVScanAgent >nul 2>&1
if /i "%~1"=="remove" (
  del "%STARTUP%" >nul 2>&1
  rmdir /s /q "%DEST%"
  echo UVScanAgent removed.
  exit /b 0
)
if not exist "%DEST%" mkdir "%DEST%"
copy /y "%~dp0UVScanAgent.exe" "%DEST%\" >nul || exit /b 1
copy /y "%~dp0agent-token.txt" "%DEST%\" >nul || exit /b 1
copy /y "%~dp0README.txt" "%DEST%\" >nul 2>&1
copy /y "%~f0" "%DEST%\install.cmd" >nul 2>&1
netsh advfirewall firewall add rule name=UVScanAgent dir=in action=allow program="%DEST%\UVScanAgent.exe" protocol=tcp localport=8765 remoteip=localsubnet profile=any >nul || exit /b 1
if /i "%~1"=="signin" > "%STARTUP%" echo @start "" /min "%DEST%\UVScanAgent.exe"
rem started through Explorer, so it runs as the signed-in user, not as administrator
explorer.exe "%DEST%\UVScanAgent.exe"
echo UVScanAgent installed in %DEST% and started.
if /i not "%~1"=="console" exit /b 0
timeout /t 3 /nobreak >nul
for /f "tokens=3" %%i in ('query session ^| findstr /b ">"') do tscon %%i /dest:console
