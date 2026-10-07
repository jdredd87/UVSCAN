unit UVScan.Settings;

(* Application settings, stored as settings.json:

  { "version": 1,
    "connection": { "port": "COM9", "baud": 115200 },
    "scan":       { "selectedPids": [1, 3, 12], "streamSpeed": "fast" },
    "logging":    { "folder": "C:\\Users\\me\\Documents\\UVScan Logs" },
    "advanced":   { "trace": false },
    "window":     { "left": 100, "top": 80, "width": 1180, "height": 720,
                    "maximized": false, "pidPanelWidth": 400 } }

  Missing values fall back to defaults, so hand-edited or older files load. *)

interface

uses
  System.SysUtils, System.JSON;

type
  TStreamSpeed = (ssFast, ssMedium, ssSlow);

  TWindowSettings = record
    Left, Top, Width, Height: Integer;
    Maximized: Boolean;
    PidPanelWidth: Integer;
    Saved: Boolean;   // False until a window position has been stored
  end;

  TAppSettings = class
  public
    Port: string;
    Baud: Integer;
    SelectedPids: TArray<Integer>;
    StreamSpeed: TStreamSpeed;
    LogFolder: string;
    Trace: Boolean;
    Window: TWindowSettings;
    constructor Create;
    procedure ResetToDefaults;
    function ToJson: TJSONObject;
    procedure FromJson(Root: TJSONObject);
    { Missing file: defaults. Unreadable file: renamed to *.bad, defaults, and
      the reason is returned in Problem. }
    procedure LoadFromFile(const FileName: string; out Problem: string);
    procedure SaveToFile(const FileName: string);
    { One-time import of the INI file written by earlier builds. }
    procedure ImportIni(const FileName: string);
  end;

const
  SettingsVersion = 1;
  StreamSpeedKeys: array[TStreamSpeed] of string = ('fast', 'medium', 'slow');

{ Low nibble of the $2A rate byte (UVScan.Class2.StreamSpeed*). }
function StreamSpeedNibble(Speed: TStreamSpeed): Byte;

implementation

uses
  Winapi.Windows, System.IOUtils, System.IniFiles, System.Math, System.Generics.Collections,
  UVScan.JsonFile, UVScan.Class2;

function StreamSpeedNibble(Speed: TStreamSpeed): Byte;
begin
  case Speed of
    ssMedium: Result := StreamSpeedMedium;
    ssSlow: Result := StreamSpeedSlow;
  else
    Result := StreamSpeedFast;
  end;
end;

{ TAppSettings }

constructor TAppSettings.Create;
begin
  inherited;
  ResetToDefaults;
end;

procedure TAppSettings.ResetToDefaults;
begin
  Port := '';
  Baud := 115200;
  SelectedPids := nil;
  StreamSpeed := ssFast;
  LogFolder := TPath.Combine(TPath.GetDocumentsPath, 'UVScan Logs');
  Trace := False;
  Window := Default(TWindowSettings);
end;

function TAppSettings.ToJson: TJSONObject;
var
  Sec: TJSONObject;
  Ids: TJSONArray;
  Id: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('version', TJSONNumber.Create(SettingsVersion));

  Sec := TJSONObject.Create;
  Sec.AddPair('port', Port);
  Sec.AddPair('baud', TJSONNumber.Create(Baud));
  Result.AddPair('connection', Sec);

  Sec := TJSONObject.Create;
  Ids := TJSONArray.Create;
  for Id in SelectedPids do
    Ids.Add(Id);
  Sec.AddPair('selectedPids', Ids);
  Sec.AddPair('streamSpeed', StreamSpeedKeys[StreamSpeed]);
  Result.AddPair('scan', Sec);

  Sec := TJSONObject.Create;
  Sec.AddPair('folder', LogFolder);
  Result.AddPair('logging', Sec);

  Sec := TJSONObject.Create;
  Sec.AddPair('trace', TJSONBool.Create(Trace));
  Result.AddPair('advanced', Sec);

  if Window.Saved then
  begin
    Sec := TJSONObject.Create;
    Sec.AddPair('left', TJSONNumber.Create(Window.Left));
    Sec.AddPair('top', TJSONNumber.Create(Window.Top));
    Sec.AddPair('width', TJSONNumber.Create(Window.Width));
    Sec.AddPair('height', TJSONNumber.Create(Window.Height));
    Sec.AddPair('maximized', TJSONBool.Create(Window.Maximized));
    Sec.AddPair('pidPanelWidth', TJSONNumber.Create(Window.PidPanelWidth));
    Result.AddPair('window', Sec);
  end;
end;

procedure TAppSettings.FromJson(Root: TJSONObject);
var
  Sec: TJSONObject;
  Ids: TJSONArray;
  I: Integer;
  S: TStreamSpeed;
begin
  ResetToDefaults;

  Sec := JObj(Root, 'connection');
  if Sec <> nil then
  begin
    Port := JStr(Sec, 'port', Port);
    Baud := JInt(Sec, 'baud', Baud);
  end;

  Sec := JObj(Root, 'scan');
  if Sec <> nil then
  begin
    Ids := JArr(Sec, 'selectedPids');
    if Ids <> nil then
      for I := 0 to Ids.Count - 1 do
        if Ids.Items[I] is TJSONNumber then
          SelectedPids := SelectedPids + [TJSONNumber(Ids.Items[I]).AsInt];
    for S := Low(TStreamSpeed) to High(TStreamSpeed) do
      if SameText(JStr(Sec, 'streamSpeed'), StreamSpeedKeys[S]) then
        StreamSpeed := S;
  end;

  Sec := JObj(Root, 'logging');
  if Sec <> nil then
    LogFolder := JStr(Sec, 'folder', LogFolder);

  Sec := JObj(Root, 'advanced');
  if Sec <> nil then
    Trace := JBool(Sec, 'trace', Trace);

  Sec := JObj(Root, 'window');
  if Sec <> nil then
  begin
    Window.Left := JInt(Sec, 'left');
    Window.Top := JInt(Sec, 'top');
    Window.Width := JInt(Sec, 'width');
    Window.Height := JInt(Sec, 'height');
    Window.Maximized := JBool(Sec, 'maximized');
    Window.PidPanelWidth := JInt(Sec, 'pidPanelWidth');
    Window.Saved := (Window.Width > 0) and (Window.Height > 0);
  end;
end;

procedure TAppSettings.LoadFromFile(const FileName: string; out Problem: string);
var
  Root: TJSONObject;
begin
  Problem := '';
  ResetToDefaults;
  if not FileExists(FileName) then
    Exit;
  try
    Root := ReadJsonObject(FileName);
  except
    on E: Exception do
    begin
      // Keep the broken file for inspection; it would be overwritten on exit.
      System.SysUtils.DeleteFile(FileName + '.bad');
      System.SysUtils.RenameFile(FileName, FileName + '.bad');
      Problem := E.Message + ' - using defaults; the old file was kept as settings.json.bad';
      Exit;
    end;
  end;
  try
    FromJson(Root);
  finally
    Root.Free;
  end;
end;

procedure TAppSettings.SaveToFile(const FileName: string);
var
  Root: TJSONObject;
begin
  Root := ToJson;
  try
    WriteJsonFile(FileName, Root);
  finally
    Root.Free;
  end;
end;

procedure TAppSettings.ImportIni(const FileName: string);
var
  Ini: TMemIniFile;
  Id: string;
  N: Integer;
begin
  ResetToDefaults;
  Ini := TMemIniFile.Create(FileName);
  try
    Port := Ini.ReadString('Connection', 'Port', Port);
    Baud := StrToIntDef(Ini.ReadString('Connection', 'Baud', ''), Baud);
    LogFolder := Ini.ReadString('Logging', 'Folder', LogFolder);
    Trace := Ini.ReadBool('Advanced', 'Trace', Trace);
    StreamSpeed := TStreamSpeed(EnsureRange(Ini.ReadInteger('Advanced', 'StreamRate', 0), 0, Ord(High(TStreamSpeed))));
    for Id in Ini.ReadString('Scan', 'Selected', '').Split([',']) do
      if TryStrToInt(Id, N) then
        SelectedPids := SelectedPids + [N];
    if Ini.ValueExists('Window', 'Width') then
    begin
      Window.Left := Ini.ReadInteger('Window', 'Left', 0);
      Window.Top := Ini.ReadInteger('Window', 'Top', 0);
      Window.Width := Ini.ReadInteger('Window', 'Width', 0);
      Window.Height := Ini.ReadInteger('Window', 'Height', 0);
      Window.Maximized := Ini.ReadBool('Window', 'Maximized', False);
      Window.PidPanelWidth := Ini.ReadInteger('Window', 'PidPanel', 0);
      Window.Saved := (Window.Width > 0) and (Window.Height > 0);
    end;
  finally
    Ini.Free;
  end;
end;

end.
