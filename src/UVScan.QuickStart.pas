unit UVScan.QuickStart;

{ Quick starts: named ways of getting UVScan going in a hurry (at the drag
  strip there are seconds, not minutes): a scan list, a dashboard, and which
  of connect / scan / log / full screen / live chart to do at once. They are
  kept in settings.json ("quickStarts"), run from the app's Quick start menu,
  and on Windows from the command line - a desktop shortcut made by UVScan
  has the switches for one:

    UVScan.exe -list "Acceleration" -connect -scan -log -fullscreen -retry
    UVScan.exe -quick "Drag strip"

  -port <name>        COM port, or host:port of an adapter on the network
  -adapter <kind>     avt or elm327 (otherwise the one chosen last)
  -list <name>        tick the PIDs of this scan list
  -dashboard <name>   show this dashboard (otherwise the scan list's, if any)
  -connect            connect at start
  -scan               start scanning (connects first)
  -log                start a log too (scans first)
  -fullscreen         the dashboard on the whole screen
  -chart              open the live chart once the scan runs
  -retry              keep trying to connect until the adapter and car answer
  -quick <name>       one of the quick starts kept in settings.json }

interface

uses
  System.SysUtils, System.JSON;

type
  TQuickStart = record
    Name: string;
    Port: string;         // '' = the port chosen last
    Adapter: string;      // 'avt' or 'elm327', '' = the one chosen last
    List: string;         // scan list to tick, '' = keep the ticked PIDs
    Dashboard: string;    // dashboard to show, '' = the scan list's (if it has one)
    Connect: Boolean;
    Scan: Boolean;        // implies Connect
    Log: Boolean;         // implies Scan
    FullScreen: Boolean;
    Chart: Boolean;
    Retry: Boolean;       // connect again every few seconds until it works
    { Scan and Log switch on what they need. }
    procedure Normalize;
    { Anything to do at all. }
    function Any: Boolean;
    function ToJson: TJSONObject;
    class function FromJson(O: TJSONObject): TQuickStart; static;
    { The command line that starts it (without -quick, so a shortcut keeps
      working if the quick start is renamed or deleted). }
    function Arguments: string;
    { One line for a menu: "Acceleration - connect, scan, log, full screen". }
    function Describe: string;
  end;

  TQuickStarts = TArray<TQuickStart>;

{ The quick start a command line asks for. Args are the parameters without
  the program (ParamStr(1)..). -quick picks one of Known by name (case does
  not matter); other switches given as well add to it. False with Problem
  set for an unknown quick start or a switch without its value. }
function ParseQuickStartArgs(const Args: TArray<string>; const Known: TQuickStarts; out Q: TQuickStart;
  out Problem: string): Boolean;
{ ParseQuickStartArgs on this program's command line. }
function QuickStartFromCommandLine(const Known: TQuickStarts; out Q: TQuickStart; out Problem: string): Boolean;

function QuickStartsToJson(const Items: TQuickStarts): TJSONArray;
function QuickStartsFromJson(A: TJSONArray): TQuickStarts;
function IndexOfQuickStart(const Items: TQuickStarts; const Name: string): Integer;
{ What a new settings file starts with. }
function DefaultQuickStarts: TQuickStarts;

implementation

uses
  System.StrUtils, UVScan.JsonFile;

{ TQuickStart }

procedure TQuickStart.Normalize;
begin
  if Log then
    Scan := True;
  if Scan then
    Connect := True;
  if not Connect then
    Retry := False;
end;

function TQuickStart.Any: Boolean;
begin
  Result := (Port <> '') or (Adapter <> '') or (List <> '') or (Dashboard <> '') or Connect or Scan or Log or FullScreen or Chart;
end;

function TQuickStart.ToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', Name);
  if Port <> '' then
    Result.AddPair('port', Port);
  if Adapter <> '' then
    Result.AddPair('adapter', Adapter);
  if List <> '' then
    Result.AddPair('list', List);
  if Dashboard <> '' then
    Result.AddPair('dashboard', Dashboard);
  Result.AddPair('connect', TJSONBool.Create(Connect));
  Result.AddPair('scan', TJSONBool.Create(Scan));
  Result.AddPair('log', TJSONBool.Create(Log));
  Result.AddPair('fullScreen', TJSONBool.Create(FullScreen));
  Result.AddPair('chart', TJSONBool.Create(Chart));
  Result.AddPair('retry', TJSONBool.Create(Retry));
end;

class function TQuickStart.FromJson(O: TJSONObject): TQuickStart;
begin
  Result := Default(TQuickStart);
  Result.Name := Trim(JStr(O, 'name'));
  Result.Port := Trim(JStr(O, 'port'));
  Result.Adapter := LowerCase(Trim(JStr(O, 'adapter')));
  Result.List := Trim(JStr(O, 'list'));
  Result.Dashboard := Trim(JStr(O, 'dashboard'));
  Result.Connect := JBool(O, 'connect');
  Result.Scan := JBool(O, 'scan');
  Result.Log := JBool(O, 'log');
  Result.FullScreen := JBool(O, 'fullScreen');
  Result.Chart := JBool(O, 'chart');
  Result.Retry := JBool(O, 'retry');
  Result.Normalize;
end;

function Quoted(const S: string): string;
begin
  // Windows command lines: a name with spaces in quotes (no quotes inside names)
  Result := '"' + StringReplace(S, '"', '', [rfReplaceAll]) + '"';
end;

function TQuickStart.Arguments: string;
var
  Parts: TArray<string>;
begin
  Parts := nil;
  if Port <> '' then
    Parts := Parts + ['-port ' + Quoted(Port)];
  if Adapter <> '' then
    Parts := Parts + ['-adapter ' + Adapter];
  if List <> '' then
    Parts := Parts + ['-list ' + Quoted(List)];
  if Dashboard <> '' then
    Parts := Parts + ['-dashboard ' + Quoted(Dashboard)];
  if Log then
    Parts := Parts + ['-log']
  else if Scan then
    Parts := Parts + ['-scan']
  else if Connect then
    Parts := Parts + ['-connect'];
  if FullScreen then
    Parts := Parts + ['-fullscreen'];
  if Chart then
    Parts := Parts + ['-chart'];
  if Retry then
    Parts := Parts + ['-retry'];
  Result := string.Join(' ', Parts);
end;

function TQuickStart.Describe: string;
var
  Steps: TArray<string>;
begin
  Steps := nil;
  if List <> '' then
    Steps := Steps + [List];
  if Dashboard <> '' then
    Steps := Steps + ['dashboard ' + Dashboard];
  if Log then
    Steps := Steps + ['connect, scan, log']
  else if Scan then
    Steps := Steps + ['connect, scan']
  else if Connect then
    Steps := Steps + ['connect'];
  if FullScreen then
    Steps := Steps + ['full screen'];
  if Chart then
    Steps := Steps + ['live chart'];
  if Retry then
    Steps := Steps + ['keeps trying'];
  Result := string.Join(' - ', Steps);
end;

{ Command line }

function ParseQuickStartArgs(const Args: TArray<string>; const Known: TQuickStarts; out Q: TQuickStart;
  out Problem: string): Boolean;
var
  I, K: Integer;
  S: string;

  function Value(out V: string): Boolean;
  begin
    Result := (I < High(Args)) and not Args[I + 1].StartsWith('-') and not Args[I + 1].StartsWith('/');
    if Result then
    begin
      Inc(I);
      V := Trim(Args[I]);
    end
    else
      Problem := Format('%s needs a value', [Args[I]]);
  end;

begin
  Q := Default(TQuickStart);
  Problem := '';
  I := 0;
  while I <= High(Args) do
  begin
    S := LowerCase(Args[I]);
    if S.StartsWith('/') or S.StartsWith('-') then
    begin
      S := S.TrimLeft(['-', '/']);
      if S = 'quick' then
      begin
        if not Value(S) then
          Exit(False);
        K := IndexOfQuickStart(Known, S);
        if K < 0 then
        begin
          Problem := Format('There is no quick start "%s"', [S]);
          Exit(False);
        end;
        // Its settings; switches before or after it add to them.
        Q.Port := IfThen(Q.Port <> '', Q.Port, Known[K].Port);
        Q.Adapter := IfThen(Q.Adapter <> '', Q.Adapter, Known[K].Adapter);
        Q.List := IfThen(Q.List <> '', Q.List, Known[K].List);
        Q.Dashboard := IfThen(Q.Dashboard <> '', Q.Dashboard, Known[K].Dashboard);
        Q.Name := Known[K].Name;
        Q.Connect := Q.Connect or Known[K].Connect;
        Q.Scan := Q.Scan or Known[K].Scan;
        Q.Log := Q.Log or Known[K].Log;
        Q.FullScreen := Q.FullScreen or Known[K].FullScreen;
        Q.Chart := Q.Chart or Known[K].Chart;
        Q.Retry := Q.Retry or Known[K].Retry;
      end
      else if S = 'port' then
      begin
        if not Value(Q.Port) then
          Exit(False);
      end
      else if S = 'adapter' then
      begin
        if not Value(Q.Adapter) then
          Exit(False);
        Q.Adapter := LowerCase(Q.Adapter);
        if (Q.Adapter <> 'avt') and (Q.Adapter <> 'elm327') then
        begin
          Problem := Format('-adapter is avt or elm327, not "%s"', [Q.Adapter]);
          Exit(False);
        end;
      end
      else if S = 'list' then
      begin
        if not Value(Q.List) then
          Exit(False);
      end
      else if S = 'dashboard' then
      begin
        if not Value(Q.Dashboard) then
          Exit(False);
      end
      else if S = 'connect' then
        Q.Connect := True
      else if S = 'scan' then
        Q.Scan := True
      else if S = 'log' then
        Q.Log := True
      else if (S = 'fullscreen') or (S = 'full') then
        Q.FullScreen := True
      else if S = 'chart' then
        Q.Chart := True
      else if S = 'retry' then
        Q.Retry := True;
      // anything else is not ours (FMX and Windows have switches of their own)
    end;
    Inc(I);
  end;
  Q.Normalize;
  Result := True;
end;

function QuickStartFromCommandLine(const Known: TQuickStarts; out Q: TQuickStart; out Problem: string): Boolean;
var
  Args: TArray<string>;
  I: Integer;
begin
  Args := nil;
  for I := 1 to ParamCount do
    Args := Args + [ParamStr(I)];
  Result := ParseQuickStartArgs(Args, Known, Q, Problem);
end;

{ Lists }

function QuickStartsToJson(const Items: TQuickStarts): TJSONArray;
var
  Q: TQuickStart;
begin
  Result := TJSONArray.Create;
  for Q in Items do
    Result.AddElement(Q.ToJson);
end;

function QuickStartsFromJson(A: TJSONArray): TQuickStarts;
var
  I: Integer;
  Q: TQuickStart;
begin
  Result := nil;
  if A = nil then
    Exit;
  for I := 0 to A.Count - 1 do
    if A.Items[I] is TJSONObject then
    begin
      Q := TQuickStart.FromJson(TJSONObject(A.Items[I]));
      if (Q.Name <> '') and (IndexOfQuickStart(Result, Q.Name) < 0) then
        Result := Result + [Q];
    end;
end;

function IndexOfQuickStart(const Items: TQuickStarts; const Name: string): Integer;
begin
  for Result := 0 to High(Items) do
    if SameText(Items[Result].Name, Trim(Name)) then
      Exit;
  Result := -1;
end;

function DefaultQuickStarts: TQuickStarts;
var
  Q: TQuickStart;
begin
  // At the strip: the pull's PIDs on their dashboard, logging, nothing to touch.
  Q := Default(TQuickStart);
  Q.Name := 'Drag strip';
  Q.List := 'Acceleration';
  Q.Log := True;
  Q.FullScreen := True;
  Q.Retry := True;
  Q.Normalize;
  Result := [Q];
end;

end.
