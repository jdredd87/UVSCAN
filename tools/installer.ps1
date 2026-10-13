<#
  Builds the Windows setup program from installer\UVScan.iss with Inno Setup 6
  (ISCC), for the UVScan.exe in Win32\Release. "build installer" compiles that
  exe first, then runs this. The version comes from src\UVScan.Version.pas
  (AppVersion) and the build stamp (src\UVScan.BuildStamp.inc).
  Output: installer\Output\UVScan-<version>-build<n>-setup.exe
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
  Write-Host 'Inno Setup 6 is not installed: winget install JRSoftware.InnoSetup --scope user'
  exit 1
}
$exe = Join-Path $root 'Win32\Release\UVScan.exe'
if (-not (Test-Path $exe)) { Write-Host "Not built: $exe"; exit 1 }
$ver = Get-Content (Join-Path $root 'src\UVScan.Version.pas') -Raw
$stamp = Get-Content (Join-Path $root 'src\UVScan.BuildStamp.inc') -Raw
$version = [regex]::Match($ver, "AppVersion\s*=\s*'([^']+)'").Groups[1].Value
$build = [regex]::Match($stamp, 'BuildNumber\s*=\s*(\d+)').Groups[1].Value
$commit = [regex]::Match($stamp, "BuildCommit\s*=\s*'([^']*)'").Groups[1].Value
if (-not $version -or -not $build) { Write-Host 'Version or build number not found'; exit 1 }
& $iscc /Q "/DAppVersion=$version" "/DBuildNumber=$build" "/DBuildCommit=$commit" `
  (Join-Path $root 'installer\UVScan.iss')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Setup: $(Join-Path $root "installer\Output\UVScan-$version-build$build-setup.exe")"
