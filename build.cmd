@echo off
rem Builds UVScan and the unit tests with the Delphi 13 command-line tools, runs the tests,
rem and builds the console bench probe.
rem Usage: build [Debug|Release] [Win32|Win64]
rem        build android [install]   - Android64 debug APK (install: adb install on the attached phone)
setlocal
if /i "%~1"=="android" goto android
set UV_CONFIG=%~1
if "%UV_CONFIG%"=="" set UV_CONFIG=Debug
set UV_PLATFORM=%~2
if "%UV_PLATFORM%"=="" set UV_PLATFORM=Win32
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" || exit /b 1
msbuild "%~dp0UVScan.dproj" /t:Build /p:Config=%UV_CONFIG% /p:Platform=%UV_PLATFORM% /nologo /v:minimal || exit /b 1
msbuild "%~dp0tests\UVScanTests.dproj" /t:Build /p:Config=%UV_CONFIG% /p:Platform=%UV_PLATFORM% /nologo /v:minimal || exit /b 1
"%~dp0tests\%UV_PLATFORM%\%UV_CONFIG%\UVScanTests.exe" --exitbehavior:Continue || exit /b 1
if not exist "%~dp0tools\Win32" mkdir "%~dp0tools\Win32"
pushd "%~dp0tools"
"%BDS%\bin\dcc32.exe" -B -Q -$D+ "-NSSystem;Winapi;System.Win" -EWin32 -NUWin32 UVScanProbe.dpr
set UV_RESULT=%ERRORLEVEL%
popd
exit /b %UV_RESULT%

:android
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" || exit /b 1
rem The SDK profile is named explicitly: the IDE default may point at an SDK folder from an older update.
if "%UV_ANDROID_SDK%"=="" set UV_ANDROID_SDK=AndroidAPI36.1_64bit.sdk
msbuild "%~dp0UVScan.dproj" /t:Build;Deploy /p:Config=Debug /p:Platform=Android64 /p:PlatformSDK=%UV_ANDROID_SDK% /nologo /v:minimal || exit /b 1
echo APK: %~dp0Android64\Debug\UVScan\bin\UVScan.apk
if /i not "%~2"=="install" exit /b 0
"C:\Users\Public\Documents\Embarcadero\Studio\37.0\CatalogRepository\AndroidSDK-37.0.59082.6021\platform-tools\adb.exe" install -r "%~dp0Android64\Debug\UVScan\bin\UVScan.apk"
exit /b %ERRORLEVEL%
