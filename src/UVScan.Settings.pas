unit UVScan.Settings;

(* Application settings, stored as settings.json:

  { "version": 1,
    "connection": { "port": "COM9", "baud": 115200 },
    "scan":       { "selectedPids": [1, 3, 12], "activeList": "Misfires", "streamSpeed": "fast" },
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
    ActiveList: string;     // name of the scan list last chosen, '' if none
    StreamSpeed: TStreamSpeed;
    LogFolder: string;
    Trace: Boolean;
    AlertSounds: Boolean;   // play the sounds of the PID alert levels
    LiveZoom: Integer;      // live data grid zoom, percent
    ShowMinMax: Boolean;    // live data grid min / max columns
    Window: TWindowSettings;
    constructor Create;
    procedure ResetToDefaults;
    function ToJson: TJSONObject;
    procedure FromJson(Root: TJSONObject);
    { Missing file: defaults. Unreadable file: renamed to *.bad, defaults, and
      the reason is returned in Problem. }
    procedure LoadFromFile(const FileName: string; out Problem: string);
    procedure SaveToFile(const FileName: string);
  end;

const
  SettingsVersion = 1;
  StreamSpeedKeys: array[TStreamSpeed] of string = ('fast', 'medium', 'slow');

{ Low nibble of the $2A rate byte (UVScan.Class2.StreamSpeed*). }
function StreamSpeedNibble(Speed: TStreamSpeed): Byte;

implementation

uses
  Winapi.Windows, System.IOUtils, System.Generics.Collections, System.Math,
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
  ActiveList := '';
  StreamSpeed := ssFast;
  LogFolder := TPath.Combine(TPath.GetDocumentsPath, 'UVScan Logs');
  Trace := False;
  AlertSounds := True;
  LiveZoom := 100;
  ShowMinMax := True;
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
  Sec.AddPair('activeList', ActiveList);
  Sec.AddPair('streamSpeed', StreamSpeedKeys[StreamSpeed]);
  Result.AddPair('scan', Sec);

  Sec := TJSONObject.Create;
  Sec.AddPair('folder', LogFolder);
  Result.AddPair('logging', Sec);

  Sec := TJSONObject.Create;
  Sec.AddPair('trace', TJSONBool.Create(Trace));
  Sec.AddPair('alertSounds', TJSONBool.Create(AlertSounds));
  Result.AddPair('advanced', Sec);

  Sec := TJSONObject.Create;
  Sec.AddPair('zoom', TJSONNumber.Create(LiveZoom));
  Sec.AddPair('showMinMax', TJSONBool.Create(ShowMinMax));
  Result.AddPair('liveGrid', Sec);

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
    ActiveList := JStr(Sec, 'activeList');
    for S := Low(TStreamSpeed) to High(TStreamSpeed) do
      if SameText(JStr(Sec, 'streamSpeed'), StreamSpeedKeys[S]) then
        StreamSpeed := S;
  end;

  Sec := JObj(Root, 'logging');
  if Sec <> nil then
    LogFolder := JStr(Sec, 'folder', LogFolder);

  Sec := JObj(Root, 'advanced');
  if Sec <> nil then
  begin
    Trace := JBool(Sec, 'trace', Trace);
    AlertSounds := JBool(Sec, 'alertSounds', AlertSounds);
  end;

  Sec := JObj(Root, 'liveGrid');
  if Sec <> nil then
  begin
    LiveZoom := EnsureRange(JInt(Sec, 'zoom', LiveZoom), 50, 300);
    ShowMinMax := JBool(Sec, 'showMinMax', ShowMinMax);
  end;

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

end.
