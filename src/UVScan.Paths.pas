unit UVScan.Paths;

{ Where UVScan keeps its data: C:\ProgramData\UVScan (pids.csv, dtcs.csv,
  settings.ini). The program itself can live anywhere (e.g. Program Files);
  the installer seeds this folder from the repo's data\ directory. }

interface

function DataDir: string;
function PidsFile: string;
function DtcsFile: string;
function SettingsFile: string;

implementation

uses
  Winapi.Windows, Winapi.ShlObj, System.SysUtils, System.IOUtils;

function DataDir: string;
var
  Buf: array[0..MAX_PATH] of Char;
begin
  if SHGetFolderPath(0, CSIDL_COMMON_APPDATA, 0, SHGFP_TYPE_CURRENT, Buf) = S_OK then
    Result := TPath.Combine(Buf, 'UVScan')
  else
    Result := 'C:\ProgramData\UVScan';
end;

function PidsFile: string;
begin
  Result := TPath.Combine(DataDir, 'pids.csv');
end;

function DtcsFile: string;
begin
  Result := TPath.Combine(DataDir, 'dtcs.csv');
end;

function SettingsFile: string;
begin
  Result := TPath.Combine(DataDir, 'settings.ini');
end;

end.
