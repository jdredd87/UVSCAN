unit UVScan.Version;

{ Which UVScan this is. AppVersion is set by hand (major.minor.patch; the
  version info in UVScan.dproj says the same); the build number, commit and
  date come from git through tools\stamp.ps1, which UVScan.dproj runs before
  each build. }

interface

const
  AppVersion = '2.0.5';
  AppRepo = 'https://github.com/jdredd87/UVSCAN';

{$I UVScan.BuildStamp.inc}

{ "2.0.0 (build 98)" }
function VersionText: string;
{ "2.0.0, build 98 (0c3c986), 2026-10-12" }
function FullVersionText: string;
{ "Windows 32-bit", "Android 64-bit" }
function PlatformText: string;

implementation

uses
  System.SysUtils;

function VersionText: string;
begin
  Result := Format('%s (build %d)', [AppVersion, BuildNumber]);
end;

function FullVersionText: string;
begin
  Result := Format('%s, build %d (%s), %s', [AppVersion, BuildNumber, BuildCommit, BuildDate]);
end;

function PlatformText: string;
begin
  {$IF Defined(ANDROID)}
  Result := 'Android';
  {$ELSEIF Defined(MSWINDOWS)}
  Result := 'Windows';
  {$ELSE}
  Result := TOSVersion.Name;
  {$ENDIF}
  {$IFDEF CPU64BITS}
  Result := Result + ' 64-bit';
  {$ELSE}
  Result := Result + ' 32-bit';
  {$ENDIF}
end;

end.
