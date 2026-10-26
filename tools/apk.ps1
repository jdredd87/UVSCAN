<#
  Makes the APK people install themselves (from a release, not a store) out of
  the app bundle "build android release" builds: bundletool's universal APK,
  signed with the release key (UV_KEYSTORE, its password in UV_KEYSTORE_PASS,
  alias uvscan). The version comes from src\UVScan.Version.pas and the build
  stamp, as the setup program's does.
  Output: installer\Output\UVScan-<version>-build<n>.apk
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$aab = Join-Path $root 'Android64\Debug\UVScan\bin\UVScan.aab'
if (-not (Test-Path $aab)) { Write-Host "Not built: $aab"; exit 1 }
$java = Join-Path $env:JAVA_HOME 'bin\java.exe'
if (-not $env:JAVA_HOME -or -not (Test-Path $java)) { $java = 'java' }
$bds = if ($env:BDS) { $env:BDS } else { "${env:ProgramFiles(x86)}\Embarcadero\Studio\37.0" }
$bundletool = Get-ChildItem "$bds\bin\Android\bundletool-*.jar" | Select-Object -Last 1
$ver = Get-Content (Join-Path $root 'src\UVScan.Version.pas') -Raw
$stamp = Get-Content (Join-Path $root 'src\UVScan.BuildStamp.inc') -Raw
$version = [regex]::Match($ver, "AppVersion\s*=\s*'([^']+)'").Groups[1].Value
$build = [regex]::Match($stamp, 'BuildNumber\s*=\s*(\d+)').Groups[1].Value
if (-not $version -or -not $build) { Write-Host 'Version or build number not found'; exit 1 }
$out = Join-Path $root 'installer\Output'
New-Item -ItemType Directory -Force $out | Out-Null
$apks = Join-Path $env:TEMP 'UVScan-universal.apks'
# bundletool reads the password from a file (not the command line, where others could see it)
$pass = Join-Path $env:TEMP "uvscan-ks-$PID.txt"
[IO.File]::WriteAllText($pass, $env:UV_KEYSTORE_PASS)
try {
  & $java -jar $bundletool.FullName build-apks "--bundle=$aab" "--output=$apks" --overwrite --mode=universal `
    "--ks=$env:UV_KEYSTORE" "--ks-pass=file:$pass" '--ks-key-alias=uvscan' "--key-pass=file:$pass"
} finally { Remove-Item $pass }
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($apks)
try {
  $apk = Join-Path $out "UVScan-$version-build$build.apk"
  [IO.Compression.ZipFileExtensions]::ExtractToFile($zip.GetEntry('universal.apk'), $apk, $true)
} finally { $zip.Dispose() }
Remove-Item $apks
Write-Host "APK: $apk"
