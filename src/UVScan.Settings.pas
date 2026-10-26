unit UVScan.Settings;

(* Application settings, stored as settings.json:

  { "version": 1,
    "connection": { "port": "COM9", "baud": 115200, "tcpAddress": "192.168.2.99:10001" },
    "scan":       { "selectedPids": [1, 3, 12], "activeList": "Misfires", "streamSpeed": "fast" },
    "logging":    { "folder": "C:\\Users\\me\\Documents\\UVScan Logs" },
    "advanced":   { "trace": false, "alertSounds": true },
    "liveGrid":   { "zoom": 100, "showMinMax": true },
    "appearance": { "theme": "system", "keepScreenOn": true },
    "updates":    { "check": true, "lastCheck": "2026-10-12T09:30:00.000Z" },
    "hotkeys":    { "connect": "F5", "scan": "F6", "mark": "F12", "liveChart": "Ctrl+G", "global": false },
    "logSend":    { "everyMinutes": 5, ... }   (sending the log while it is written: UVScan.LogSend)
    "liveView":   { "on": false, "port": 8080 }   (the live data in a browser: UVScan.LiveServer)
    "window":     { "left": 100, "top": 80, "width": 1180, "height": 720,
                    "maximized": false, "pidPanelWidth": 400 } }

  Missing values fall back to defaults, so hand-edited or older files load. *)

interface

uses
  System.SysUtils, System.JSON, UVScan.QuickStart, UVScan.Hotkeys, UVScan.LogSend;

type
  TStreamSpeed = (ssFast, ssMedium, ssSlow);

  TWindowSettings = record
    Left, Top, Width, Height: Integer;
    Maximized: Boolean;
    PidPanelWidth: Integer;
    PidsHidden: Boolean; // wide window: the PID list on its own page, not beside the others
    Saved: Boolean;   // False until a window position has been stored
  end;

  TAppSettings = class
  public
    Port: string;
    Baud: Integer;
    Adapter: string;        // what is on the port: 'avt' (AVT-841) or 'elm327'
    TcpAddress: string;     // host:port of an adapter on the network (port 'Network (TCP/IP)')
    SelectedPids: TArray<Integer>;
    ActiveList: string;     // name of the scan list last chosen, '' if none
    FoldedGroups: TArray<string>; // PID list groups shown folded (their names: 'Engine', ...)
    StreamSpeed: TStreamSpeed;
    LogFolder: string;
    AlwaysLog: Boolean;     // every scan writes a log, no Start log needed
    OneLog: Boolean;        // a log started again carries on the same file until UVScan closes
    AskKeep: Boolean;       // stopping the scan (or the log) asks whether to keep the log
    KeepByDefault: Boolean; // that question's default answer is Yes
    LogNamePattern: string; // a new log's name: {date}, {time}, {n}, {vin} (UVScan.LogFiles)
    AskLogName: Boolean;    // starting a log asks for its name (the pattern's filled in)
    BackgroundStop: Integer; // phone: seconds in the background before the log, scan and connection stop
    PendingNotice: string;   // shown at the next start (Android may end the app before the user is back)
    Trace: Boolean;
    AlertSounds: Boolean;   // play the sounds of the PID alert levels
    LiveZoom: Integer;      // live data grid zoom, percent
    LiveOrder: TArray<Integer>; // live data rows, top first, when no scan list is chosen
    ShowMinMax: Boolean;    // live data grid min / max columns
    Theme: string;          // 'system', 'light' or 'dark'
    KeepScreenOn: Boolean;  // no sleep / screen saver while UVScan is open
    RoundReadings: Boolean; // gauges and live data: tidy decimals per PID (logs keep every digit)
    LockRotation: Boolean;  // phone / tablet: the screen keeps the way it faces (bumps in a car)
    ScanView: string;       // the Live page when a scan starts: 'keep' (as it was), 'grid' or 'chart'
    QuickStarts: TQuickStarts; // named ways to start in a hurry (Quick start menu, shortcuts)
    CheckUpdates: Boolean;  // ask GitHub for a newer UVScan when it starts (once a day)
    UpdateChecked: TDateTime; // when it last asked, 0: never
    Hotkeys: THotkeys;      // keys for the main actions (none: Key 0)
    GlobalHotkeys: Boolean; // Windows: they work when another program is in front too
    Window: TWindowSettings;
    LogSend: TLogSendSettings; // sending the log while it is written (where to, how often)
    LiveView: Boolean;      // the live data in a web browser on this network (UVScan.LiveServer)
    LiveViewPort: Integer;  // its port (the next free one if taken)
    constructor Create;
    destructor Destroy; override;
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

{ Documents\UVScan Logs; on Android the app's folder on shared storage
  (Android/data/<app>/files/Logs), reachable over USB without permissions. }
function DefaultLogFolder: string;

implementation

uses
  {$IFDEF MSWINDOWS}Winapi.Windows,{$ELSE}Posix.Stdio, Posix.Unistd,{$ENDIF} System.IOUtils, System.Generics.Collections, System.Math,
  System.DateUtils, System.StrUtils, UVScan.JsonFile, UVScan.Class2, UVScan.LogFiles;

function StreamSpeedNibble(Speed: TStreamSpeed): Byte;
begin
  case Speed of
    ssMedium: Result := StreamSpeedMedium;
    ssSlow: Result := StreamSpeedSlow;
  else
    Result := StreamSpeedFast;
  end;
end;

function DefaultLogFolder: string;
begin
  {$IFDEF ANDROID}
  Result := TPath.Combine(TPath.GetPublicPath, 'Logs');
  {$ELSE}
  Result := TPath.Combine(TPath.GetDocumentsPath, 'UVScan Logs');
  {$ENDIF}
end;

{ TAppSettings }

constructor TAppSettings.Create;
begin
  inherited;
  LogSend := TLogSendSettings.Create;
  ResetToDefaults;
end;

destructor TAppSettings.Destroy;
begin
  LogSend.Free;
  inherited;
end;

procedure TAppSettings.ResetToDefaults;
begin
  Port := '';
  Baud := 115200;
  Adapter := 'avt';
  TcpAddress := '';
  SelectedPids := nil;
  ActiveList := '';
  FoldedGroups := nil;
  StreamSpeed := ssFast;
  LogFolder := DefaultLogFolder;
  AlwaysLog := False;
  OneLog := False;
  AskKeep := False;
  KeepByDefault := True;
  LogNamePattern := DefaultLogNamePattern;
  AskLogName := False;
  BackgroundStop := 15;
  PendingNotice := '';
  Trace := False;
  AlertSounds := True;
  LiveZoom := 100;
  ShowMinMax := True;
  Theme := 'system';
  KeepScreenOn := True;
  RoundReadings := True;
  ScanView := 'keep';
  QuickStarts := DefaultQuickStarts;
  CheckUpdates := True;
  UpdateChecked := 0;
  Hotkeys := DefaultHotkeys;
  GlobalHotkeys := False;
  Window := Default(TWindowSettings);
  LogSend.ResetToDefaults;
  LiveView := False;
  LiveViewPort := 8080;
end;

function TAppSettings.ToJson: TJSONObject;
var
  Sec: TJSONObject;
  Ids, Names: TJSONArray;
  Id: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('version', TJSONNumber.Create(SettingsVersion));

  Sec := TJSONObject.Create;
  Sec.AddPair('port', Port);
  Sec.AddPair('baud', TJSONNumber.Create(Baud));
  Sec.AddPair('adapter', Adapter);
  Sec.AddPair('tcpAddress', TcpAddress);
  Result.AddPair('connection', Sec);

  Sec := TJSONObject.Create;
  Ids := TJSONArray.Create;
  for Id in SelectedPids do
    Ids.Add(Id);
  Sec.AddPair('selectedPids', Ids);
  Sec.AddPair('activeList', ActiveList);
  Names := TJSONArray.Create;
  for var G in FoldedGroups do
    Names.Add(G);
  Sec.AddPair('foldedGroups', Names);
  Sec.AddPair('streamSpeed', StreamSpeedKeys[StreamSpeed]);
  Result.AddPair('scan', Sec);

  Sec := TJSONObject.Create;
  Sec.AddPair('folder', LogFolder);
  Sec.AddPair('always', TJSONBool.Create(AlwaysLog));
  Sec.AddPair('oneLog', TJSONBool.Create(OneLog));
  Sec.AddPair('askKeep', TJSONBool.Create(AskKeep));
  Sec.AddPair('keepByDefault', TJSONBool.Create(KeepByDefault));
  Sec.AddPair('namePattern', LogNamePattern);
  Sec.AddPair('askName', TJSONBool.Create(AskLogName));
  Sec.AddPair('backgroundStop', TJSONNumber.Create(BackgroundStop));
  if PendingNotice <> '' then
    Sec.AddPair('pendingNotice', PendingNotice);
  Result.AddPair('logging', Sec);

  Sec := TJSONObject.Create;
  Sec.AddPair('trace', TJSONBool.Create(Trace));
  Sec.AddPair('alertSounds', TJSONBool.Create(AlertSounds));
  Result.AddPair('advanced', Sec);

  Sec := TJSONObject.Create;
  Sec.AddPair('zoom', TJSONNumber.Create(LiveZoom));
  Ids := TJSONArray.Create;
  for Id in LiveOrder do
    Ids.Add(Id);
  Sec.AddPair('order', Ids);
  Sec.AddPair('showMinMax', TJSONBool.Create(ShowMinMax));
  Result.AddPair('liveGrid', Sec);

  Sec := TJSONObject.Create;
  Sec.AddPair('theme', Theme);
  Sec.AddPair('keepScreenOn', TJSONBool.Create(KeepScreenOn));
  Sec.AddPair('roundReadings', TJSONBool.Create(RoundReadings));
  Sec.AddPair('lockRotation', TJSONBool.Create(LockRotation));
  Sec.AddPair('scanView', ScanView);
  Result.AddPair('appearance', Sec);

  Result.AddPair('quickStarts', QuickStartsToJson(QuickStarts));

  Sec := TJSONObject.Create;
  Sec.AddPair('check', TJSONBool.Create(CheckUpdates));
  if UpdateChecked > 0 then
    Sec.AddPair('lastCheck', DateToISO8601(UpdateChecked, False));
  Result.AddPair('updates', Sec);

  Sec := TJSONObject.Create;
  for var A := Low(THotkeyAction) to High(THotkeyAction) do
    Sec.AddPair(HotkeyIds[A], Hotkeys[A].Text);
  Sec.AddPair('global', TJSONBool.Create(GlobalHotkeys));
  Result.AddPair('hotkeys', Sec);
  Result.AddPair('logSend', LogSend.ToJson);

  Sec := TJSONObject.Create;
  Sec.AddPair('on', TJSONBool.Create(LiveView));
  Sec.AddPair('port', TJSONNumber.Create(LiveViewPort));
  Result.AddPair('liveView', Sec);

  if Window.Saved then
  begin
    Sec := TJSONObject.Create;
    Sec.AddPair('left', TJSONNumber.Create(Window.Left));
    Sec.AddPair('top', TJSONNumber.Create(Window.Top));
    Sec.AddPair('width', TJSONNumber.Create(Window.Width));
    Sec.AddPair('height', TJSONNumber.Create(Window.Height));
    Sec.AddPair('maximized', TJSONBool.Create(Window.Maximized));
    Sec.AddPair('pidPanelWidth', TJSONNumber.Create(Window.PidPanelWidth));
    Sec.AddPair('pidsHidden', TJSONBool.Create(Window.PidsHidden));
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
    Adapter := JStr(Sec, 'adapter', Adapter);
    TcpAddress := JStr(Sec, 'tcpAddress', TcpAddress);
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
    FoldedGroups := nil;
    Ids := JArr(Sec, 'foldedGroups');
    if Ids <> nil then
      for I := 0 to Ids.Count - 1 do
        if Ids.Items[I] is TJSONString then
          FoldedGroups := FoldedGroups + [Ids.Items[I].Value];
    for S := Low(TStreamSpeed) to High(TStreamSpeed) do
      if SameText(JStr(Sec, 'streamSpeed'), StreamSpeedKeys[S]) then
        StreamSpeed := S;
  end;

  Sec := JObj(Root, 'logging');
  if Sec <> nil then
  begin
    LogFolder := JStr(Sec, 'folder', LogFolder);
    AlwaysLog := JBool(Sec, 'always', AlwaysLog);
    OneLog := JBool(Sec, 'oneLog', OneLog);
    AskKeep := JBool(Sec, 'askKeep', AskKeep);
    KeepByDefault := JBool(Sec, 'keepByDefault', KeepByDefault);
    LogNamePattern := JStr(Sec, 'namePattern', LogNamePattern);
    if Trim(LogNamePattern) = '' then
      LogNamePattern := DefaultLogNamePattern;
    AskLogName := JBool(Sec, 'askName', AskLogName);
    BackgroundStop := EnsureRange(JInt(Sec, 'backgroundStop', BackgroundStop), 5, 600);
    PendingNotice := JStr(Sec, 'pendingNotice', '');
  end;

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
    LiveOrder := nil;
    Ids := JArr(Sec, 'order');
    if Ids <> nil then
      for I := 0 to Ids.Count - 1 do
        if Ids.Items[I] is TJSONNumber then
          LiveOrder := LiveOrder + [TJSONNumber(Ids.Items[I]).AsInt];
    ShowMinMax := JBool(Sec, 'showMinMax', ShowMinMax);
  end;

  Sec := JObj(Root, 'appearance');
  if Sec <> nil then
  begin
    Theme := LowerCase(JStr(Sec, 'theme', Theme));
    KeepScreenOn := JBool(Sec, 'keepScreenOn', KeepScreenOn);
    RoundReadings := JBool(Sec, 'roundReadings', RoundReadings);
    LockRotation := JBool(Sec, 'lockRotation', LockRotation);
    ScanView := LowerCase(JStr(Sec, 'scanView', ScanView));
    if not MatchText(ScanView, ['keep', 'grid', 'chart']) then
      ScanView := 'keep';
  end;

  // Missing (an older file): the defaults stay; there but empty: none.
  if Root.GetValue('quickStarts') is TJSONArray then
    QuickStarts := QuickStartsFromJson(TJSONArray(Root.GetValue('quickStarts')));

  Sec := JObj(Root, 'updates');
  if Sec <> nil then
  begin
    CheckUpdates := JBool(Sec, 'check', CheckUpdates);
    if not TryISO8601ToDate(JStr(Sec, 'lastCheck'), UpdateChecked, False) then
      UpdateChecked := 0;
  end;

  // A key missing (an older file): its default; there but empty: none.
  Sec := JObj(Root, 'hotkeys');
  if Sec <> nil then
  begin
    for var A := Low(THotkeyAction) to High(THotkeyAction) do
      if Sec.GetValue(HotkeyIds[A]) <> nil then
        Hotkeys[A] := THotkey.Parse(JStr(Sec, HotkeyIds[A]));
    GlobalHotkeys := JBool(Sec, 'global', GlobalHotkeys);
  end;

  LogSend.FromJson(JObj(Root, 'logSend'));

  Sec := JObj(Root, 'liveView');
  if Sec <> nil then
  begin
    LiveView := JBool(Sec, 'on', LiveView);
    LiveViewPort := EnsureRange(JInt(Sec, 'port', LiveViewPort), 1024, 65000);
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
    Window.PidsHidden := JBool(Sec, 'pidsHidden');
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
