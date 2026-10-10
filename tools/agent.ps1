<#
  Drives UVScanAgent (tools\UVScanAgent.dpr) on another Windows PC on the
  home network, a laptop at the car say, which has no Delphi: send it this
  build, run it, click and type in it, take screenshots, fetch the results.

  agent kit                      makes the laptop's kit (UVScanAgent.exe, a new token) in ..\..\UVScanAgent-kit
  agent find                     looks for the agent on this PC's networks and remembers it
  agent pair <host[:port]> [token]
  agent info | windows | quit
  agent deploy [folder]          sends this build (UVScan, UVScanProbe, UVScanSimServer) to UVScan\ (or folder)
  agent put <local> [remote]     agent get <remote> [local]     agent ls [remote]     agent rm <remote>
  agent run "<command line>" [timeout s] [dir]       hidden, waits, prints the output, exits with its code
  agent ps "<PowerShell commands>" [timeout s]       the same through PowerShell
  agent start "<command line>" [dir]                 on the laptop's desktop; prints the process id
  agent kill <name|pid>
  agent shot [file.png] [title]  the screen, or the window whose title contains title
  agent click <x> <y> [title] [left|right|double]    agent wheel <x> <y> <notches> [title]
  agent key <vk> [csaw] [title]   agent text "<text>" [title]     agent size <w> <h> [title]

  Remote paths are from the agent's folder unless absolute; %VARIABLES% work
  (%ProgramData%\UVScan). With a title, x and y are that window's client
  pixels. The laptop's address and token are kept in
  %LOCALAPPDATA%\UVScanAgent\target.txt.
#>
param([Parameter(Position = 0)][string]$Cmd = 'help',
      [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest)
$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot -Parent
$Cfg = Join-Path $env:LOCALAPPDATA 'UVScanAgent\target.txt'
$DefaultPort = 8765
function Arg([int]$I, [string]$Default = '') { if ($Rest -and $Rest.Count -gt $I -and $Rest[$I] -ne '') { $Rest[$I] } else { $Default } }

function Target {
  # UVSCAN_AGENT=host:port|token picks another agent for this shell
  if ($env:UVSCAN_AGENT) { $p = $env:UVSCAN_AGENT -split '\|'; return [pscustomobject]@{ Host = $p[0]; Token = $p[1] } }
  if (-not (Test-Path $Cfg)) { throw "No laptop yet: run 'agent find' or 'agent pair <host[:port]> <token>'." }
  $l = @(Get-Content $Cfg)
  if ($l.Count -lt 2 -or $l[0] -eq '') { throw "No laptop address yet: run 'agent find' or 'agent pair <host[:port]>'." }
  [pscustomobject]@{ Host = $l[0]; Token = $l[1] }
}
function SaveTarget([string]$HostPort, [string]$Token) {
  New-Item -ItemType Directory -Force (Split-Path $Cfg) | Out-Null
  [IO.File]::WriteAllText($Cfg, "$HostPort`n$Token`n")
}
function SavedToken { if (Test-Path $Cfg) { $l = @(Get-Content $Cfg); if ($l.Count -ge 2) { return $l[1] } }; '' }

function Call([string]$Method, [string]$Path, [hashtable]$Query = @{}, [byte[]]$Body = $null, [int]$TimeoutSec = 60, [string]$HostPort = '') {
  $tok = ''
  if ($HostPort -eq '') { $t = Target; $HostPort = $t.Host; $tok = $t.Token }
  $qs = ($Query.GetEnumerator() | Where-Object { $_.Value -ne $null -and "$($_.Value)" -ne '' } |
    ForEach-Object { [Uri]::EscapeDataString($_.Key) + '=' + [Uri]::EscapeDataString([string]$_.Value) }) -join '&'
  $url = "http://$HostPort$Path"; if ($qs) { $url += "?$qs" }
  $req = [Net.HttpWebRequest]::Create($url)
  $req.Method = $Method; $req.KeepAlive = $false
  $req.Timeout = ($TimeoutSec + 30) * 1000; $req.ReadWriteTimeout = ($TimeoutSec + 30) * 1000
  if ($tok) { $req.Headers.Add('X-Token', $tok) }
  if ($Body -ne $null) {
    $req.ContentLength = $Body.Length; $s = $req.GetRequestStream(); $s.Write($Body, 0, $Body.Length); $s.Close()
  } elseif ($Method -ne 'GET') { $req.ContentLength = 0 }
  try { $resp = $req.GetResponse() }
  catch [Net.WebException] {
    $resp = $_.Exception.Response
    if (-not $resp) { throw "Could not reach the agent at ${HostPort}: $($_.Exception.Message)" }
  }
  $ms = New-Object IO.MemoryStream; $resp.GetResponseStream().CopyTo($ms); $resp.Close()
  $r = [pscustomobject]@{ Status = [int]$resp.StatusCode; Body = $ms.ToArray(); Exit = $resp.Headers['X-Exit-Code'] }
  if ($r.Status -ne 200) { throw "Agent: $($r.Status) $([Text.Encoding]::UTF8.GetString($r.Body))" }
  $r
}
function Utf8([byte[]]$B) { [Text.Encoding]::UTF8.GetString($B) }
function Say($R) { (Utf8 $R.Body).TrimEnd() -split "\r?\n" }
function Bytes([string]$S) { [Text.Encoding]::UTF8.GetBytes($S) }

function Run([string]$CmdLine, [int]$Timeout, [string]$Dir) {
  $r = Call POST '/run' @{ timeout = $Timeout; dir = $Dir } (Bytes $CmdLine) $Timeout
  # console programs write in the OEM code page
  $oem = [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
  $out = $oem.GetString($r.Body)
  if ($out) { Write-Output $out.TrimEnd() }
  if ($r.Exit -eq 'timeout') { Write-Output "[timed out after $Timeout s]"; exit 124 }
  if ($r.Exit -ne '0') { Write-Output "[exit $($r.Exit)]" }
  exit [int]$r.Exit
}

function Find([int]$Port) {
  $nets = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.PrefixLength -ge 16 -and $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' }
  $tries = @()
  foreach ($n in $nets) {
    $p = $n.IPAddress.Split('.')
    foreach ($i in 1..254) {
      $ip = "$($p[0]).$($p[1]).$($p[2]).$i"
      if ($ip -eq $n.IPAddress) { continue }
      $c = New-Object Net.Sockets.TcpClient
      $tries += [pscustomobject]@{ Ip = $ip; Client = $c; Task = $c.ConnectAsync($ip, $Port) }
    }
  }
  Start-Sleep -Milliseconds 1500
  $found = @()
  foreach ($t in $tries) {
    if ($t.Task.Status -eq 'RanToCompletion' -and $t.Client.Connected) { $found += $t.Ip }
    $t.Client.Close()
  }
  $agents = @()
  foreach ($ip in $found) {
    try { $r = Call GET '/ping' @{} $null 5 "${ip}:$Port"; $s = Utf8 $r.Body; if ($s -like 'UVScanAgent *') { $agents += "${ip}:$Port  $s" } } catch { }
  }
  $agents
}

switch ($Cmd) {
  'kit' {
    $exe = Join-Path $Repo 'tools\Win32\UVScanAgent.exe'
    if (-not (Test-Path $exe)) { throw "Build it first: build.cmd (or dcc32 tools\UVScanAgent.dpr)." }
    $kit = Join-Path (Split-Path $Repo -Parent) 'UVScanAgent-kit'
    $tok = SavedToken
    if ($tok -eq '') { $tok = ([guid]::NewGuid().ToString('N')); SaveTarget '' $tok }
    if (Test-Path $kit) { Remove-Item -Recurse -Force $kit }
    New-Item -ItemType Directory -Force "$kit\UVScanAgent" | Out-Null
    Copy-Item $exe "$kit\UVScanAgent\"
    Copy-Item (Join-Path $PSScriptRoot 'UVScanAgent-install.cmd') "$kit\UVScanAgent\install.cmd"
    [IO.File]::WriteAllText("$kit\UVScanAgent\agent-token.txt", $tok)
    [IO.File]::WriteAllText("$kit\UVScanAgent\README.txt", (@(
      'UVScanAgent lets the UVScan development PC try new UVScan builds on this PC over the home network.',
      '',
      'Easiest: right-click install.cmd, Run as administrator. It copies the agent to C:\UVScanAgent, lets it through',
      'Windows Firewall from your home network only, starts it whenever you sign in, and starts it now.',
      '("install remove", as administrator, takes all of that away again.)',
      '',
      'Or by hand: unzip anywhere, double-click UVScanAgent.exe (if Windows says it protected your PC: More info,',
      'Run anyway), and when Windows Firewall asks, tick Private networks and press Allow.',
      '',
      'Leave its window open (it may be minimized). It shows everything the development PC asks it to do.',
      'While it runs it keeps this PC awake with the screen on. Close the window to stop it.',
      'Do not lock the PC (Windows+L) while testing: nothing can click in UVScan on a locked screen.',
      'Only a computer with the token in agent-token.txt can use it. Keep that file to yourself.'
    ) -join "`r`n") + "`r`n")
    $zip = "$kit\UVScanAgent.zip"
    Compress-Archive -Path "$kit\UVScanAgent" -DestinationPath $zip
    "Kit: $zip ($([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB)"
  }
  'find' {
    $port = [int](Arg 0 $DefaultPort)
    $a = @(Find $port)
    if ($a.Count -eq 0) { "No agent answered on port $port. Is UVScanAgent.exe running on the laptop, and allowed through its firewall?"; exit 1 }
    $a
    $tok = SavedToken
    if ($a.Count -eq 1) { SaveTarget ($a[0] -split '  ')[0] $tok; "Using $(($a[0] -split '  ')[0])." }
  }
  'pair' { $h = Arg 0; if ($h -notmatch ':') { $h = "${h}:$DefaultPort" }; $t = Arg 1 (SavedToken); SaveTarget $h $t; Say (Call GET '/info') }
  'info' { Say (Call GET '/info') }
  'windows' { Say (Call GET '/windows') }
  'quit' { Say (Call POST '/quit') }
  'ls' { Say (Call GET '/list' @{ path = (Arg 0 '.') }) }
  'rm' { Say (Call POST '/delete' @{ path = (Arg 0) }) }
  'put' {
    $local = (Resolve-Path (Arg 0)).Path
    Say (Call PUT '/file' @{ path = (Arg 1 (Split-Path $local -Leaf)) } ([IO.File]::ReadAllBytes($local)) 300)
  }
  'get' {
    $remote = Arg 0; $local = Arg 1 (Split-Path $remote -Leaf)
    $r = Call GET '/file' @{ path = $remote } $null 300
    $local = [IO.Path]::GetFullPath((Join-Path (Get-Location) $local))
    [IO.File]::WriteAllBytes($local, $r.Body); "$local, $($r.Body.Length) bytes"
  }
  'run' { Run (Arg 0) ([int](Arg 1 60)) (Arg 2) }
  'ps' {
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('$ProgressPreference = ''SilentlyContinue''; ' + (Arg 0)))
    Run "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $enc" ([int](Arg 1 60)) ''
  }
  'start' { "pid $(Say (Call POST '/start' @{ dir = (Arg 1) } (Bytes (Arg 0))))" }
  'kill' {
    $a = Arg 0
    if ($a -match '^\d+$') { Say (Call POST '/kill' @{ pid = $a }) } else { Say (Call POST '/kill' @{ name = $a }) }
  }
  'shot' {
    $local = [IO.Path]::GetFullPath((Join-Path (Get-Location) (Arg 0 'laptop.png')))
    $r = Call GET '/shot' @{ title = (Arg 1) }
    [IO.File]::WriteAllBytes($local, $r.Body); "$local, $($r.Body.Length) bytes"
  }
  'click' { Say (Call POST '/click' @{ x = (Arg 0); y = (Arg 1); title = (Arg 2); button = (Arg 3) }) }
  'wheel' { Say (Call POST '/wheel' @{ x = (Arg 0); y = (Arg 1); n = (Arg 2); title = (Arg 3) }) }
  'key' { Say (Call POST '/key' @{ vk = (Arg 0); mods = (Arg 1); title = (Arg 2) }) }
  'text' { Say (Call POST '/text' @{ title = (Arg 1) } (Bytes (Arg 0))) }
  'size' { Say (Call POST '/size' @{ w = (Arg 0); h = (Arg 1); title = (Arg 2) }) }
  'deploy' {
    $dest = Arg 0 'UVScan'
    $files = @("$Repo\Win32\Debug\UVScan.exe", "$Repo\tools\Win32\UVScanProbe.exe", "$Repo\tools\Win32\UVScanSimServer.exe")
    foreach ($f in $files) { if (-not (Test-Path $f)) { throw "Missing $f. Run build.cmd first." } }
    $zip = Join-Path $env:TEMP 'uvscan-deploy.zip'
    if (Test-Path $zip) { Remove-Item $zip }
    Compress-Archive -Path $files -DestinationPath $zip
    foreach ($p in 'UVScan', 'UVScanProbe', 'UVScanSimServer') { Call POST '/kill' @{ name = $p } | Out-Null }
    Say (Call PUT '/file' @{ path = 'uvscan-deploy.zip' } ([IO.File]::ReadAllBytes($zip)) 300)
    Remove-Item $zip
    Say (Call POST '/unzip' @{ path = 'uvscan-deploy.zip'; to = $dest } $null 120)
    Call POST '/delete' @{ path = 'uvscan-deploy.zip' } | Out-Null
    Say (Call GET '/list' @{ path = $dest })
  }
  default { Get-Content $PSCommandPath | Select-Object -Skip 1 -First 24 }
}
