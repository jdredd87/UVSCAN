@echo off
rem Builds UVScan and the unit tests with the Delphi 13 command-line tools, then runs the tests.
rem Usage: build [Debug|Release] [Win32|Win64]
setlocal
set UV_CONFIG=%~1
if "%UV_CONFIG%"=="" set UV_CONFIG=Debug
set UV_PLATFORM=%~2
if "%UV_PLATFORM%"=="" set UV_PLATFORM=Win32
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" || exit /b 1
msbuild "%~dp0UVScan.dproj" /t:Build /p:Config=%UV_CONFIG% /p:Platform=%UV_PLATFORM% /nologo /v:minimal || exit /b 1
msbuild "%~dp0tests\UVScanTests.dproj" /t:Build /p:Config=%UV_CONFIG% /p:Platform=%UV_PLATFORM% /nologo /v:minimal || exit /b 1
"%~dp0tests\%UV_PLATFORM%\%UV_CONFIG%\UVScanTests.exe" --exitbehavior:Continue || exit /b 1
