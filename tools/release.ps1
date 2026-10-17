<#
  Publishes a UVScan release on GitHub: the tag v<version> with the Windows
  setup program. UVScan's update check (More > About) offers the newest one.

  1. Change AppVersion in src\UVScan.Version.pas and the version info in
     UVScan.dproj to match (Windows file version, Android versionName),
     commit and push.
  2. powershell -File tools\release.ps1 [-Notes notes.md] [-DryRun]

  It checks that everything is committed and pushed, the versions agree and
  the tag is new; builds and tests (build.cmd), builds the setup program
  (build.cmd installer), tags, pushes the tag and makes the release (gh).
  Without -Notes the release says how to install it and lists the commits
  since the last release; in -Notes, {VERSION} and {BUILD} are filled in (for
  the setup program's name). Start the notes with a "### What's new" section:
  that is what the update question shows. -DryRun stops before the tag.
#>
param([string]$Notes = '', [switch]$DryRun)
$ErrorActionPreference = 'Continue' # git and gh write to stderr; their exit codes are checked
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[Environment]::CurrentDirectory = $root # for git, gh and cmd too
function Fail($msg) { Write-Host "release: $msg"; exit 1 }

$ver = [regex]::Match((Get-Content src\UVScan.Version.pas -Raw), "AppVersion\s*=\s*'([^']+)'").Groups[1].Value
if ($ver -notmatch '^\d+\.\d+\.\d+$') { Fail "AppVersion '$ver' is not major.minor.patch" }
$tag = "v$ver"
$dproj = Get-Content UVScan.dproj -Raw
if ($dproj -notmatch [regex]::Escape("FileVersion=$ver.0;")) { Fail "UVScan.dproj: the Windows file version is not $ver.0" }
if ($dproj -notmatch [regex]::Escape("versionName=$ver;")) { Fail "UVScan.dproj: the Android versionName is not $ver" }

if (git status --porcelain --untracked-files=no) { Fail 'commit (or undo) the changes first' }
git fetch -q origin
if ((git rev-parse HEAD) -ne (git rev-parse '@{u}')) { Fail 'push first (or pull): this is not what GitHub has' }
if (git tag -l $tag) { Fail "$tag exists already: change AppVersion" }
gh release view $tag *> $null
if ($LASTEXITCODE -eq 0) { Fail "the release $tag exists already" }

& (Join-Path $root 'build.cmd')
if ($LASTEXITCODE -ne 0) { Fail 'build or tests failed' }
& (Join-Path $root 'build.cmd') installer
if ($LASTEXITCODE -ne 0) { Fail 'the setup program did not build' }
$stamp = Get-Content src\UVScan.BuildStamp.inc -Raw
$build = [regex]::Match($stamp, 'BuildNumber\s*=\s*(\d+)').Groups[1].Value
if ($stamp -match "BuildCommit\s*=\s*'[^']*\+'") { Fail 'built with uncommitted changes (did the build change a file?)' }
$setup = "installer\Output\UVScan-$ver-build$build-setup.exe"
if (-not (Test-Path $setup)) { Fail "no $setup" }

if ($Notes) {
  # {VERSION} and {BUILD} in the notes become this release's
  $text = (Get-Content $Notes -Raw).Replace('{VERSION}', $ver).Replace('{BUILD}', $build)
} else {
  $text = "UVScan $ver (build $build).`n`n" +
    "**Windows:** download ``UVScan-$ver-build$build-setup.exe`` below and run it. " +
    "Already have UVScan? It offers the update itself (*More > About*), and your PIDs, lists, settings and logs stay.`n"
  $prev = git describe --tags --abbrev=0 --match 'v[0-9]*' 2>$null
  if ($LASTEXITCODE -eq 0 -and $prev) {
    $log = git log --pretty='- %s' "$prev..HEAD"
    $text += "`n### Changes since $prev`n`n" + ($log -join "`n") + "`n"
  }
}
$notesFile = Join-Path $env:TEMP "uvscan-release-$ver.md"
[IO.File]::WriteAllText($notesFile, $text)
Write-Host "--- $tag, $setup`n$text---"
if ($DryRun) { Write-Host 'Dry run: no tag, no release.'; exit 0 }

git tag -a $tag -m "UVScan $ver"
git push -q origin $tag
if ($LASTEXITCODE -ne 0) { Fail 'could not push the tag' }
gh release create $tag $setup --verify-tag --title "UVScan $ver" --notes-file $notesFile
if ($LASTEXITCODE -ne 0) { Fail 'gh could not make the release (the tag is pushed; run gh release create again)' }
Write-Host "Released $tag"
