unit UVScan.Paths;

{ Where UVScan keeps its data: C:\ProgramData\UVScan on Windows (pids.json,
  dtcs.json, lists.json, display.json, settings.json, ...). The program itself
  can live anywhere (e.g. Program Files). On Android it is the app's private
  documents folder. Missing files are created from the defaults compiled
  into the program (UVScan.Defaults). }

interface

function DataDir: string;
function PidsFile: string;
function DtcsFile: string;
function SettingsFile: string;
function ListsFile: string;
function DisplayFile: string;
function ControlsFile: string;
function LogViewsFile: string;

implementation

uses
  {$IFDEF MSWINDOWS}Winapi.Windows, Winapi.ShlObj,{$ENDIF} System.SysUtils, System.IOUtils;

function DataDir: string;
{$IFDEF MSWINDOWS}
var
  Buf: array[0..MAX_PATH] of Char;
begin
  if SHGetFolderPath(0, CSIDL_COMMON_APPDATA, 0, SHGFP_TYPE_CURRENT, Buf) = S_OK then
    Result := TPath.Combine(Buf, 'UVScan')
  else
    Result := 'C:\ProgramData\UVScan';
end;
{$ELSE}
begin
  Result := TPath.Combine(TPath.GetDocumentsPath, 'UVScan');
end;
{$ENDIF}


function PidsFile: string;
begin
  Result := TPath.Combine(DataDir, 'pids.json');
end;

function DtcsFile: string;
begin
  Result := TPath.Combine(DataDir, 'dtcs.json');
end;

function SettingsFile: string;
begin
  Result := TPath.Combine(DataDir, 'settings.json');
end;

function ListsFile: string;
begin
  Result := TPath.Combine(DataDir, 'lists.json');
end;

function DisplayFile: string;
begin
  Result := TPath.Combine(DataDir, 'display.json');
end;

function ControlsFile: string;
begin
  Result := TPath.Combine(DataDir, 'controls.json');
end;

function LogViewsFile: string;
begin
  Result := TPath.Combine(DataDir, 'logviews.json');
end;

end.
