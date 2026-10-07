unit UVScan.Defaults;

{ Factory default data compiled into the exe (UVScan.Defaults.rc embeds the
  repo's data\pids.json, dtcs.json, lists.json and display.json). Used to restore the PID
  definitions and to create any data file that is missing at startup, so a
  fresh install needs nothing but the exe. }

interface

uses
  System.SysUtils;

function DefaultPidsJson: string;
function DefaultDtcsJson: string;
function DefaultListsJson: string;
{ Examples for display.json. PIDs are named by "pidCode" because ids differ
  between catalogs; ResolveSeedJson (UVScan.Display) turns them into ids. }
function DefaultDisplayJson: string;
function DefaultControlsJson: string;
function DefaultLogViewsJson: string;

{ Writes the default for each data file that does not exist yet. Returns the
  files that were created. }
function CreateMissingDataFiles: TArray<string>;

implementation

uses
  Winapi.Windows, System.Classes, System.JSON, UVScan.Paths, UVScan.JsonFile;

function ResourceText(const Name: string): string;
var
  Stream: TResourceStream;
  Bytes: TBytes;
begin
  Stream := TResourceStream.Create(HInstance, Name, RT_RCDATA);
  try
    SetLength(Bytes, Stream.Size);
    if Length(Bytes) > 0 then
      Stream.ReadBuffer(Bytes[0], Length(Bytes));
  finally
    Stream.Free;
  end;
  Result := TEncoding.UTF8.GetString(Bytes);
  if (Result <> '') and (Result[1] = #$FEFF) then
    Delete(Result, 1, 1);
end;

function DefaultPidsJson: string;
begin
  Result := ResourceText('DEFAULT_PIDS');
end;

function DefaultDtcsJson: string;
begin
  Result := ResourceText('DEFAULT_DTCS');
end;

function DefaultListsJson: string;
begin
  Result := ResourceText('DEFAULT_LISTS');
end;

function DefaultDisplayJson: string;
begin
  Result := ResourceText('DEFAULT_DISPLAY');
end;

function DefaultControlsJson: string;
begin
  Result := ResourceText('DEFAULT_CONTROLS');
end;

function DefaultLogViewsJson: string;
begin
  Result := ResourceText('DEFAULT_LOGVIEWS');
end;

function CreateMissingDataFiles: TArray<string>;

  procedure Ensure(const FileName, Json, Source: string);
  var
    Root: TJSONObject;
  begin
    if FileExists(FileName) then
      Exit;
    Root := ParseJsonObject(Json, Source);
    try
      WriteJsonFile(FileName, Root);
    finally
      Root.Free;
    end;
    Result := Result + [FileName];
  end;

begin
  Result := nil;
  Ensure(PidsFile, DefaultPidsJson, 'default pids.json');
  Ensure(DtcsFile, DefaultDtcsJson, 'default dtcs.json');
  Ensure(ListsFile, DefaultListsJson, 'default lists.json');
  Ensure(ControlsFile, DefaultControlsJson, 'default controls.json');
  Ensure(LogViewsFile, DefaultLogViewsJson, 'default logviews.json');
end;

end.
