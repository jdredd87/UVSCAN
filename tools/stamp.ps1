<#
  Writes src\UVScan.BuildStamp.inc (not in git) for UVScan.Version: the build
  number (commits so far), the commit and the date. UVScan.dproj runs it
  before each build (IDE or build.cmd, Windows or Android). A "+" after the
  commit: built with changes not committed yet. Without git: build 0.
  The file is only rewritten when it changes, so nothing recompiles for nothing.
#>
$ErrorActionPreference = 'SilentlyContinue'
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root 'src\UVScan.BuildStamp.inc'
$count = '0'
$commit = 'unknown'
if (Get-Command git) {
  $n = git -C $root rev-list --count HEAD 2>$null
  $h = git -C $root rev-parse --short HEAD 2>$null
  if ($LASTEXITCODE -eq 0 -and $n -and $h) {
    $count = "$n".Trim()
    $commit = "$h".Trim()
    if (git -C $root status --porcelain --untracked-files=no 2>$null) { $commit += '+' }
  }
}
$date = Get-Date -Format 'yyyy-MM-dd'
$text = "// Written by tools\stamp.ps1 before each build - not in git.`r`n" +
  "const`r`n  BuildNumber = $count;`r`n  BuildCommit = '$commit';`r`n  BuildDate = '$date';`r`n"
$old = ''
if (Test-Path $out) { $old = [IO.File]::ReadAllText($out) }
if ($old -ne $text) { [IO.File]::WriteAllText($out, $text) }
exit 0
