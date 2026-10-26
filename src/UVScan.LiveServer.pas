unit UVScan.LiveServer;

(* The live view on the network: a small web server in UVScan, so anyone on
  the same Wi-Fi or network (the crew's phones, a laptop in the pits) opens
  an address in a browser and watches the scan: the grid, the dashboard and
  the status. Read only: nothing a browser sends changes the scan.

    GET /           the page (LiveViewPage), which asks for the data
    GET /live.json  what UVScan last published (Publish), about 4 times a second

  UVScan (the main thread) builds the JSON; the server only hands out the
  latest copy. Each request is answered on a thread of its own, and the
  connection closes after it (no keep-alive). *)

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections, System.Net.Socket;

type
  ELiveServerError = class(Exception);

  { The live chart's samples for the browsers (the last 15 minutes of the
    scan, as the app's live chart keeps them). A browser asks for the last
    so many seconds first, then for what came after the newest it has; a new
    scan is a new session, and a browser with an old one gets all again.
    Any thread. }
  TLiveChart = class
  private type
    TMark = record
      Time: Double;
      Number: Integer;
    end;
  private
    FLock: TCriticalSection;
    FSession: Integer;
    FNames, FUnits: TArray<string>;
    FSwitches: TArray<Boolean>;
    FTimes: TList<Double>;
    FValues: TList<TArray<Double>>;
    FMarks: TList<TMark>;
  public
    constructor Create;
    destructor Destroy; override;
    { A new scan: its channels (named like a log's columns). }
    procedure Start(const Names, Units: TArray<string>; const Switches: TArray<Boolean>);
    { A sample: T seconds into the scan, a value per channel (NaN: none). }
    procedure Add(const T: Double; const Values: TArray<Double>);
    procedure AddMark(const T: Double; Number: Integer);
    (* The answer to a browser: all of the last Back seconds when Session is
      not this one's (or Since is NaN), else the samples after Since.
        { "session": 2, "full": true, "names": [...], "units": [...], "switch": [...],
          "t": [12.3, 12.4], "v": [[812, 14.1], [815, 14.1]], "marks": [[12.35, 1]] }
      "names", "units" and "switch" only when full; null for no data. *)
    function Json(Session: Integer; const Since, Back: Double): string;
    property Session: Integer read FSession;
  end;

  TLiveServer = class
  private
    FListener: System.Net.Socket.TSocket;
    FPort: Word;
    FStop: Boolean;
    FAcceptThread: TThread;
    FLock: TCriticalSection;
    FJson: TBytes;
    FViewers: TDictionary<string, UInt64>; // address -> when it last asked for the data (tick)
    FBusy: Integer;                        // requests being answered
    FChart: TLiveChart;
    procedure Answer(Client: System.Net.Socket.TSocket);
    procedure Respond(Client: System.Net.Socket.TSocket; const Head, Who: string);
  public
    { Listens on every network of this device, on the first free port of
      Port..Port + Tries - 1 (Port 0: one the system picks). Raises
      ELiveServerError when none is free. }
    constructor Create(Port: Word; Tries: Integer = 10);
    destructor Destroy; override;
    { The data the page shows (any thread). }
    procedure Publish(const Json: string);
    { The addresses that asked for the data in the last 10 seconds. }
    function Viewers: TArray<string>;
    property Port: Word read FPort;
    { The chart's samples (GET /chart.json). }
    property Chart: TLiveChart read FChart;
  end;

{ This device's address on its network (the one its traffic goes out by),
  e.g. '192.168.1.23'; '' when it has none. Sends nothing. }
function LocalNetworkAddress: string;

{ 'GET /live.json?x=1 HTTP/1.1' -> 'GET', '/live.json' (and 'x=1'). False if it is not a request line. }
function ParseRequestLine(const Line: string; out Method, Path: string): Boolean; overload;
function ParseRequestLine(const Line: string; out Method, Path, Query: string): Boolean; overload;
{ 'since=12.5&session=2', 'since' -> '12.5'; '' when it is not there. }
function QueryParam(const Query, Name: string): string;

{ The page: HTML, its style and its script in one. }
function LiveViewPage: string;

implementation

uses
  {$IFDEF MSWINDOWS}Winapi.Winsock2,{$ENDIF}
  {$IFDEF POSIX}Posix.SysSocket, Posix.NetinetIn, Posix.ArpaInet, Posix.Unistd,{$ENDIF}
  System.Math, System.StrUtils, System.Generics.Defaults, UVScan.Serial;

const
  MaxBusy = 24;          // more requests at once than that: closed unanswered
  RequestTimeoutMs = 3000;
  ViewerMs = 10000;

function ParseRequestLine(const Line: string; out Method, Path: string): Boolean;
var
  Query: string;
begin
  Result := ParseRequestLine(Line, Method, Path, Query);
end;

function ParseRequestLine(const Line: string; out Method, Path, Query: string): Boolean;
var
  Parts: TArray<string>;
  Q: Integer;
begin
  Method := '';
  Path := '';
  Query := '';
  Parts := Line.Trim.Split([' ']);
  Result := (Length(Parts) = 3) and StartsStr('HTTP/', Parts[2]) and StartsStr('/', Parts[1]);
  if not Result then
    Exit;
  Method := UpperCase(Parts[0]);
  Path := Parts[1];
  Q := Path.IndexOf('#');
  if Q >= 0 then
    Path := Copy(Path, 1, Q);
  Q := Path.IndexOf('?');
  if Q >= 0 then
  begin
    Query := Copy(Path, Q + 2, MaxInt);
    Path := Copy(Path, 1, Q);
  end;
end;

function QueryParam(const Query, Name: string): string;
var
  Pair: string;
  Eq: Integer;
begin
  for Pair in Query.Split(['&']) do
  begin
    Eq := Pair.IndexOf('=');
    if (Eq > 0) and SameText(Copy(Pair, 1, Eq), Name) then
      Exit(Copy(Pair, Eq + 2, MaxInt));
  end;
  Result := '';
end;

{ TLiveChart }

const
  ChartKeepSeconds = 15 * 60;

var
  JsonFormat: TFormatSettings;

function JsonNum(const V: Double; Decimals: Integer = -1): string;
begin
  if IsNan(V) or IsInfinite(V) then
    Result := 'null'
  else if Decimals >= 0 then
    Result := FloatToStrF(V, ffFixed, 15, Decimals, JsonFormat)
  else
    Result := FloatToStrF(V, ffGeneral, 7, 0, JsonFormat);
end;

function JsonText(const S: string): string;
var
  C: Char;
  B: TStringBuilder;
begin
  B := TStringBuilder.Create(Length(S) + 2);
  try
    B.Append('"');
    for C in S do
      case C of
        '"': B.Append('\"');
        '\': B.Append('\\');
        #0..#31: B.Append('\u' + IntToHex(Ord(C), 4));
      else
        B.Append(C);
      end;
    B.Append('"');
    Result := B.ToString;
  finally
    B.Free;
  end;
end;

constructor TLiveChart.Create;
begin
  inherited;
  FLock := TCriticalSection.Create;
  FTimes := TList<Double>.Create;
  FValues := TList<TArray<Double>>.Create;
  FMarks := TList<TMark>.Create;
end;

destructor TLiveChart.Destroy;
begin
  FMarks.Free;
  FValues.Free;
  FTimes.Free;
  FLock.Free;
  inherited;
end;

procedure TLiveChart.Start(const Names, Units: TArray<string>; const Switches: TArray<Boolean>);
begin
  FLock.Enter;
  try
    Inc(FSession);
    FNames := Copy(Names);
    FUnits := Copy(Units);
    FSwitches := Copy(Switches);
    FTimes.Clear;
    FValues.Clear;
    FMarks.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TLiveChart.Add(const T: Double; const Values: TArray<Double>);
var
  Drop: Integer;
begin
  FLock.Enter;
  try
    if (FTimes.Count > 0) and (T < FTimes.Last) then
      Exit;
    FTimes.Add(T);
    FValues.Add(Copy(Values));
    // the oldest go in chunks, not one by one
    Drop := 0;
    while (Drop < FTimes.Count) and (FTimes[Drop] < T - ChartKeepSeconds) do
      Inc(Drop);
    if Drop >= 64 then
    begin
      FTimes.DeleteRange(0, Drop);
      FValues.DeleteRange(0, Drop);
      while (FMarks.Count > 0) and (FMarks[0].Time < FTimes[0]) do
        FMarks.Delete(0);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLiveChart.AddMark(const T: Double; Number: Integer);
var
  M: TMark;
begin
  M.Time := T;
  M.Number := Number;
  FLock.Enter;
  try
    FMarks.Add(M);
  finally
    FLock.Leave;
  end;
end;

function TLiveChart.Json(Session: Integer; const Since, Back: Double): string;
var
  B: TStringBuilder;
  Full: Boolean;
  From, I, C: Integer;
  Row: TArray<Double>;
  M: TMark;

  procedure Texts(const Key: string; const A: TArray<string>);
  var
    K: Integer;
  begin
    B.Append(',"' + Key + '":[');
    for K := 0 to High(A) do
      B.Append(IfThen(K > 0, ',', '') + JsonText(A[K]));
    B.Append(']');
  end;

begin
  B := TStringBuilder.Create;
  FLock.Enter;
  try
    Full := (Session <> FSession) or IsNan(Since);
    From := FTimes.Count;
    if Full then
    begin
      if FTimes.Count > 0 then
        while (From > 0) and (FTimes[From - 1] >= FTimes.Last - EnsureRange(Back, 1, ChartKeepSeconds)) do
          Dec(From);
    end
    else
      while (From > 0) and (FTimes[From - 1] > Since) do
        Dec(From);
    B.Append('{"session":' + IntToStr(FSession) + ',"full":' + IfThen(Full, 'true', 'false'));
    if Full then
    begin
      Texts('names', FNames);
      Texts('units', FUnits);
      B.Append(',"switch":[');
      for I := 0 to High(FSwitches) do
        B.Append(IfThen(I > 0, ',', '') + IfThen(FSwitches[I], 'true', 'false'));
      B.Append(']');
    end;
    B.Append(',"t":[');
    for I := From to FTimes.Count - 1 do
      B.Append(IfThen(I > From, ',', '') + JsonNum(FTimes[I], 3));
    B.Append('],"v":[');
    for I := From to FTimes.Count - 1 do
    begin
      Row := FValues[I];
      B.Append(IfThen(I > From, ',[', '['));
      for C := 0 to High(FNames) do
      begin
        if C > 0 then
          B.Append(',');
        if C <= High(Row) then
          B.Append(JsonNum(Row[C]))
        else
          B.Append('null');
      end;
      B.Append(']');
    end;
    B.Append('],"marks":[');
    I := 0;
    for M in FMarks do
    begin
      B.Append(IfThen(I > 0, ',', '') + '[' + JsonNum(M.Time, 3) + ',' + IntToStr(M.Number) + ']');
      Inc(I);
    end;
    B.Append(']}');
    Result := B.ToString;
  finally
    FLock.Leave;
    B.Free;
  end;
end;

function LocalNetworkAddress: string;
{$IFDEF MSWINDOWS}
var
  Data: TWSAData;
  S: Winapi.Winsock2.TSocket;
  A: TSockAddrIn;
  L: Integer;
begin
  Result := '';
  if WSAStartup($0202, Data) <> 0 then
    Exit;
  try
    S := Winapi.Winsock2.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if S = INVALID_SOCKET then
      Exit;
    try
      FillChar(A, SizeOf(A), 0);
      A.sin_family := AF_INET;
      A.sin_port := htons(53);
      A.sin_addr.S_addr := inet_addr('8.8.8.8');
      // a UDP "connection" only picks the way out: nothing is sent
      if Winapi.Winsock2.connect(S, TSockAddr(A), SizeOf(A)) = 0 then
      begin
        L := SizeOf(A);
        if Winapi.Winsock2.getsockname(S, TSockAddr(A), L) = 0 then
          Result := string(AnsiString(inet_ntoa(A.sin_addr)));
      end;
    finally
      closesocket(S);
    end;
  finally
    WSACleanup;
  end;
  if (Result = '0.0.0.0') or StartsStr('127.', Result) then
    Result := '';
end;
{$ELSE}
var
  S: Integer;
  A: sockaddr_in;
  L: socklen_t;
begin
  Result := '';
  S := Posix.SysSocket.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if S < 0 then
    Exit;
  try
    FillChar(A, SizeOf(A), 0);
    A.sin_family := AF_INET;
    A.sin_port := htons(53);
    A.sin_addr.s_addr := inet_addr('8.8.8.8');
    // a UDP "connection" only picks the way out: nothing is sent
    if Posix.SysSocket.connect(S, sockaddr(A), SizeOf(A)) = 0 then
    begin
      L := SizeOf(A);
      if Posix.SysSocket.getsockname(S, sockaddr(A), L) = 0 then
        Result := string(UTF8String(inet_ntoa(A.sin_addr)));
    end;
  finally
    __close(S);
  end;
  if (Result = '0.0.0.0') or StartsStr('127.', Result) then
    Result := '';
end;
{$ENDIF}

procedure SendAll(S: System.Net.Socket.TSocket; const Data: TBytes);
var
  Done, N: Integer;
begin
  Done := 0;
  while Done < Length(Data) do
  begin
    N := SocketSend(S, Data[Done], Length(Data) - Done);
    if N <= 0 then
      Exit;
    Inc(Done, N);
  end;
end;

{ TLiveServer }

constructor TLiveServer.Create(Port: Word; Tries: Integer);
var
  I: Integer;
  S: System.Net.Socket.TSocket;
  Problem: string;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FViewers := TDictionary<string, UInt64>.Create;
  FChart := TLiveChart.Create;
  Publish('{}');
  if Port = 0 then
    Tries := 1;
  for I := 0 to Max(1, Tries) - 1 do
  begin
    if Port + I > 65535 then
      Break;
    S := System.Net.Socket.TSocket.Create(TSocketType.TCP);
    try
      S.Listen('0.0.0.0', '', Port + I);
      FListener := S;
      Break;
    except
      on E: Exception do
      begin
        Problem := E.Message;
        try
          S.Free;
        except
          // never opened
        end;
      end;
    end;
  end;
  if FListener = nil then
    raise ELiveServerError.CreateFmt('no free port from %d to %d (%s)', [Port, Port + Max(1, Tries) - 1, Problem]);
  FPort := FListener.LocalPort;
  FAcceptThread := TThread.CreateAnonymousThread(
    procedure
    var
      Client: System.Net.Socket.TSocket;
    begin
      while not FStop do
      begin
        try
          Client := FListener.Accept(200);
        except
          Client := nil;
          if not FStop then
            Sleep(200);
        end;
        if Client <> nil then
          Answer(Client);
      end;
    end);
  FAcceptThread.FreeOnTerminate := False;
  FAcceptThread.Start;
end;

destructor TLiveServer.Destroy;
var
  Deadline: UInt64;
begin
  FStop := True;
  if FAcceptThread <> nil then
  begin
    FAcceptThread.WaitFor;
    FAcceptThread.Free;
  end;
  // the requests still being answered stop within their time
  Deadline := TThread.GetTickCount64 + RequestTimeoutMs + 2000;
  while (TInterlocked.CompareExchange(FBusy, 0, 0) > 0) and (TThread.GetTickCount64 < Deadline) do
    Sleep(10);
  FreeSocket(FListener);
  FViewers.Free;
  FChart.Free;
  FLock.Free;
  inherited;
end;

procedure TLiveServer.Publish(const Json: string);
var
  B: TBytes;
begin
  B := TEncoding.UTF8.GetBytes(Json);
  FLock.Enter;
  try
    FJson := B;
  finally
    FLock.Leave;
  end;
end;

function TLiveServer.Viewers: TArray<string>;
var
  Now: UInt64;
  P: TPair<string, UInt64>;
  Gone: TArray<string>;
begin
  Result := nil;
  Gone := nil;
  Now := TThread.GetTickCount64;
  FLock.Enter;
  try
    for P in FViewers do
      if Now - P.Value <= ViewerMs then
        Result := Result + [P.Key]
      else
        Gone := Gone + [P.Key];
    for var S in Gone do
      FViewers.Remove(S);
  finally
    FLock.Leave;
  end;
  TArray.Sort<string>(Result);
end;

{ A connection: its request's head is read (a GET has nothing after it), it
  is answered and closed, on a thread of its own. }
procedure TLiveServer.Answer(Client: System.Net.Socket.TSocket);
begin
  if TInterlocked.Increment(FBusy) > MaxBusy then
  begin
    TInterlocked.Decrement(FBusy);
    FreeSocket(Client);
    Exit;
  end;
  TThread.CreateAnonymousThread(
    procedure
    var
      Buf: array[0..2047] of Byte;
      Got: TBytes;
      N, L: Integer;
      Deadline: UInt64;
      Head, Who: string;
    begin
      try
        try
          Who := Client.RemoteAddress;
          Head := '';
          Deadline := TThread.GetTickCount64 + RequestTimeoutMs;
          while not FStop and (TThread.GetTickCount64 < Deadline) and (Length(Got) < 8192) do
            if SocketReadable(Client, 100) then
            begin
              N := SocketReceive(Client, Buf, SizeOf(Buf));
              if N <= 0 then
                Break; // the browser closed
              L := Length(Got);
              SetLength(Got, L + N);
              Move(Buf[0], Got[L], N);
              Head := TEncoding.ANSI.GetString(Got);
              if Pos(#13#10#13#10, Head) > 0 then
                Break;
            end;
          if (Head <> '') and not FStop then
            Respond(Client, Head, Who);
        except
          // the browser went away
        end;
      finally
        FreeSocket(Client);
        TInterlocked.Decrement(FBusy);
      end;
    end).Start;
end;

procedure TLiveServer.Respond(Client: System.Net.Socket.TSocket; const Head, Who: string);
var
  Line, Method, Path, Query, Status, ContentType, Text: string;
  Body: TBytes;
  P: Integer;
begin
  P := Pos(#13#10, Head);
  if P > 0 then
    Line := Copy(Head, 1, P - 1)
  else
    Line := Head;
  ContentType := 'text/plain; charset=utf-8';
  Body := nil;
  if not ParseRequestLine(Line, Method, Path, Query) then
    Status := '400 Bad Request'
  else if (Method <> 'GET') and (Method <> 'HEAD') then
    Status := '405 Method Not Allowed'
  else if (Path = '/') or SameText(Path, '/index.html') then
  begin
    Status := '200 OK';
    ContentType := 'text/html; charset=utf-8';
    Body := TEncoding.UTF8.GetBytes(LiveViewPage);
  end
  else if SameText(Path, '/live.json') then
  begin
    Status := '200 OK';
    ContentType := 'application/json; charset=utf-8';
    FLock.Enter;
    try
      Body := Copy(FJson);
      FViewers.AddOrSetValue(Who, TThread.GetTickCount64);
    finally
      FLock.Leave;
    end;
  end
  else if SameText(Path, '/chart.json') then
  begin
    Status := '200 OK';
    ContentType := 'application/json; charset=utf-8';
    Body := TEncoding.UTF8.GetBytes(FChart.Json(StrToIntDef(QueryParam(Query, 'session'), -1),
      StrToFloatDef(QueryParam(Query, 'since'), NaN, JsonFormat),
      StrToFloatDef(QueryParam(Query, 'back'), 60, JsonFormat)));
    FLock.Enter;
    try
      FViewers.AddOrSetValue(Who, TThread.GetTickCount64);
    finally
      FLock.Leave;
    end;
  end
  else if SameText(Path, '/favicon.ico') then
    Status := '204 No Content'
  else
    Status := '404 Not Found';
  if (Body = nil) and not StartsStr('2', Status) then
    Body := TEncoding.UTF8.GetBytes(Status);
  Text := 'HTTP/1.1 ' + Status + #13#10 +
    'Content-Type: ' + ContentType + #13#10 +
    'Content-Length: ' + IntToStr(Length(Body)) + #13#10 +
    'Cache-Control: no-store' + #13#10 +
    'Connection: close' + #13#10 + #13#10;
  if Method = 'HEAD' then
    Body := nil;
  SendAll(Client, TEncoding.ASCII.GetBytes(Text) + Body);
end;

function LiveViewPage: string;
begin
  Result := '''
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="dark">
    <title>UVScan live</title>
    <style>
    :root { --bg: #12161b; --panel: #1a2028; --alt: #1d242d; --line: #2b333d; --text: #ebeef2; --sub: #9aa5b1; --accent: #46aaff; }
    * { box-sizing: border-box; }
    [hidden] { display: none !important; }
    html, body { margin: 0; background: var(--bg); color: var(--text); font: 15px/1.35 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
    header { position: sticky; top: 0; z-index: 2; background: var(--panel); border-bottom: 1px solid var(--line); padding: 10px 16px 0; }
    .top { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
    .brand { font-weight: 700; font-size: 17px; }
    .pill { padding: 2px 10px; border-radius: 999px; font-size: 13px; font-weight: 600; background: #3a424d; }
    .pill.Scanning { background: #1f7a3a; }
    .pill.Connected { background: #245c94; }
    .pill.Busy, .pill.Test { background: #8a6a12; }
    #rec { color: #ff6b5e; font-weight: 700; font-size: 13px; }
    #status { color: var(--sub); font-size: 13px; margin: 4px 0 6px; overflow-wrap: anywhere; min-height: 1em; }
    nav { display: flex; gap: 4px; }
    nav button { background: none; border: 0; border-bottom: 3px solid transparent; color: var(--sub); font: inherit; font-weight: 600; padding: 8px 14px; cursor: pointer; }
    nav button.on { color: var(--text); border-bottom-color: var(--accent); }
    #lost { background: #7a2a22; color: #fff; padding: 8px 16px; font-size: 14px; }
    main { padding: 12px 16px 24px; }
    section { min-height: 60vh; }
    table { width: 100%; border-collapse: collapse; }
    th { text-align: left; color: var(--sub); font-size: 12px; font-weight: 600; padding: 4px 8px; border-bottom: 1px solid var(--line); }
    td { padding: 6px 8px; border-bottom: 1px solid var(--line); vertical-align: middle; }
    tbody tr:nth-child(even) { background: var(--alt); }
    td.v { font-weight: 700; font-size: 18px; white-space: nowrap; font-variant-numeric: tabular-nums; }
    td.v small { font-weight: 400; font-size: 12px; opacity: .75; margin-left: 4px; }
    td.m { white-space: nowrap; color: var(--sub); font-variant-numeric: tabular-nums; }
    th.r, td.v, td.m { text-align: right; }
    .nomm .mm { display: none; }
    .idle td.v { opacity: .6; }
    .empty { color: var(--sub); text-align: center; padding: 40px 0; }
    h2 { font-size: 14px; color: var(--sub); font-weight: 600; margin: 0 0 10px; }
    #gauges { display: flex; flex-wrap: wrap; gap: 12px; align-items: flex-start; }
    #gauges > div { max-width: 100%; min-width: 0; }
    #gauges svg { display: block; max-width: 100%; height: auto; }
    @media (max-width: 600px) { #gauges { justify-content: center; } }
    .chip { display: flex; gap: 8px; align-items: baseline; padding: 8px 14px; border-radius: 10px; max-width: 100%; }
    .chip b { font-size: 18px; font-variant-numeric: tabular-nums; }
    .chip span { font-size: 13px; opacity: .75; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .cbar { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; margin-bottom: 10px; }
    .cbar select, .cbar button { background: #262e38; color: var(--text); border: 1px solid var(--line); border-radius: 8px; padding: 6px 12px; font: inherit; font-size: 14px; cursor: pointer; }
    #cpaused { color: var(--sub); font-size: 13px; }
    #chips { margin-bottom: 10px; }
    #cnote { margin: 0 0 6px; color: var(--sub); font-size: 13px; }
    #chipList { display: flex; flex-wrap: wrap; gap: 6px; }
    #chips button { background: none; border: 1px solid var(--line); border-radius: 999px; padding: 4px 10px; font: inherit; font-size: 13px; color: var(--sub); cursor: pointer; }
    #chips button.on { border-color: currentColor; }
    #cv { display: block; width: 100%; border-radius: 6px; touch-action: pan-y; cursor: crosshair; }
    </style>
    </head>
    <body>
    <header>
      <div class="top"><span class="brand">UVScan</span><span id="state" class="pill">...</span><span id="rec"></span></div>
      <div id="status"></div>
      <nav><button data-tab="grid">Grid</button><button data-tab="chart">Chart</button><button data-tab="dash">Dashboard</button></nav>
    </header>
    <div id="lost" hidden>No answer from UVScan. Is it still open, and is this device on the same network? Trying again...</div>
    <main>
      <section id="grid">
        <table id="gridTable" hidden>
          <thead><tr><th>PID</th><th class="r">Value</th><th class="r mm">Min</th><th class="r mm">Max</th></tr></thead>
          <tbody id="rows"></tbody>
        </table>
        <p id="gridEmpty" class="empty">Waiting for a scan. The grid fills when UVScan scans.</p>
      </section>
      <section id="chart" hidden>
        <div class="cbar">
          <select id="span" title="How much it shows">
            <option value="15">15 s</option><option value="30">30 s</option><option value="60">1 min</option>
            <option value="120">2 min</option><option value="300">5 min</option><option value="600">10 min</option>
            <option value="900">15 min</option>
          </select>
          <button id="clive">Pause</button>
          <button id="cpick">PIDs</button>
          <button id="csame" hidden>Same as UVScan</button>
          <span id="cpaused"></span>
        </div>
        <div id="chips" hidden><p id="cnote"></p><div id="chipList"></div></div>
        <canvas id="cv" hidden></canvas>
        <p id="chartEmpty" class="empty">Waiting for a scan. The chart fills when UVScan scans.</p>
      </section>
      <section id="dash" hidden>
        <h2 id="dashName"></h2>
        <div id="gauges"></div>
        <p id="dashEmpty" class="empty" hidden>This dashboard has no gauges.</p>
      </section>
    </main>
    <script>
    "use strict";
    const $ = id => document.getElementById(id);
    const SIZES = { small: 190, medium: 250, large: 330 };
    const TICKS = { dial: { small: 5, medium: 7, large: 8 }, bar: { small: 4, medium: 5, large: 6 } };
    const CARD = "#1e242c", TEXT = "#ebeef2", TRACK = "#404450", ACCENT = "#46aaff", NEEDLE = "#ff5a3c";
    let last = null, flashOn = true, fails = 0, tab = "grid", rowKey = null, gaugeEls = [];

    function setText(el, s) { s = s == null ? "" : String(s); if (el.textContent !== s) el.textContent = s; }
    function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;"); }
    const f = n => n.toFixed(2);
    const clamp = (v, a, b) => Math.min(b, Math.max(a, v));

    function rgb(h) { const n = parseInt(h.slice(1), 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; }
    function hex(c) { return "#" + c.map(x => Math.round(x).toString(16).padStart(2, "0")).join(""); }
    function blend(a, b, t) { const x = rgb(a), y = rgb(b); return hex(x.map((v, i) => v + (y[i] - v) * t)); }
    function contrast(h) { const [r, g, b] = rgb(h); return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.55 ? "#141414" : "#ffffff"; }

    function niceStep(range, target) {
      if (!(range > 0) || target < 1) return 1;
      const raw = range / target, mag = Math.pow(10, Math.floor(Math.log10(raw))), n = raw / mag;
      return (n < 1.5 ? 1 : n < 3 ? 2 : n < 7 ? 5 : 10) * mag;
    }
    function trimNum(s) { return s.includes(".") ? s.replace(/0+$/, "").replace(/\.$/, "") : s; }
    function tickLabel(v, step) {
      if (Math.abs(v) >= 10000) return trimNum((v / 1000).toFixed(1)) + "k";
      if (step >= 1) return String(Math.round(v));
      return trimNum(v.toFixed(2));
    }
    function pt(cx, cy, r, deg) { const a = deg * Math.PI / 180; return [cx + Math.cos(a) * r, cy + Math.sin(a) * r]; }
    function arc(cx, cy, r, start, sweep) {
      if (!(sweep > 0.01)) return "";
      sweep = Math.min(sweep, 359.9);
      const [x0, y0] = pt(cx, cy, r, start), [x1, y1] = pt(cx, cy, r, start + sweep);
      return `M${f(x0)} ${f(y0)}A${f(r)} ${f(r)} 0 ${sweep > 180 ? 1 : 0} 1 ${f(x1)} ${f(y1)}`;
    }
    function zoneAt(zones, v) {
      let c = null;
      if (v == null) return c;
      for (const z of zones) if (v >= z.from && v <= z.to) c = z.color;
      return c;
    }
    function txt(cls, x, y, size, anchor, bold) {
      return `<text class="${cls}" x="${f(x)}" y="${f(y)}" font-size="${f(size)}" text-anchor="${anchor}" dominant-baseline="central"${bold ? " font-weight=\"700\"" : ""}></text>`;
    }
    // A text no wider than w: squeezed when it would be.
    function fit(el, s, w) {
      setText(el, s);
      el.removeAttribute("textLength");
      el.removeAttribute("lengthAdjust");
      try {
        if (el.getComputedTextLength() > w) { el.setAttribute("textLength", f(w)); el.setAttribute("lengthAdjust", "spacingAndGlyphs"); }
      } catch (e) { }
    }

    // The colours of a gauge now, as UVScan paints it: its level's colours
    // (blinking if the level flashes), or the dark card.
    function palette(g) {
      const lit = g.level >= 0 && (!g.flash || flashOn);
      const card = lit && g.bg ? g.bg : CARD;
      const text = lit && g.fg ? g.fg : lit && g.bg ? contrast(card) : TEXT;
      const own = lit && g.bg;
      let fill = zoneAt(g.zones, g.value);
      if (own) fill = text; else if (!fill) fill = g.normal || ACCENT;
      return { card, text, sub: blend(text, card, 0.35), track: own ? blend(card, text, 0.25) : TRACK, needle: own ? text : NEEDLE, fill };
    }

    function buildGauge(g) {
      const box = document.createElement("div");
      if (g.chip) {
        box.className = "chip";
        box.innerHTML = "<span></span><b></b><span></span>";
        return { el: box, update(g) {
          const p = palette(g);
          box.style.background = p.card; box.style.color = p.text;
          setText(box.children[0], g.name); setText(box.children[1], g.text); setText(box.children[2], g.units);
        } };
      }
      const B = SIZES[g.size] || 250, style = g.style;
      let W, H, s = "", geo = {};
      const span = g.max - g.min, frac = v => clamp((v - g.min) / span, 0, 1);
      if (style === "dial") {
        W = 100; H = 100;
        const pad = W * 0.06, titleH = H * 0.12;
        const D = Math.min(W - 2 * pad, H - pad * 0.5 - titleH - pad * 0.4);
        const cx = W / 2, cy = pad * 0.5 + titleH + D / 2, thick = D * 0.075, zw = D * 0.03;
        const R = D / 2 - zw - D * 0.02 - thick / 2, zr = R + thick / 2 + D * 0.012 + zw / 2;
        s += txt("title", W / 2, pad * 0.5 + titleH / 2, H * 0.062, "middle", true);
        s += `<path class="track" d="${arc(cx, cy, R, 135, 270)}" stroke-width="${f(thick)}" stroke-linecap="round" fill="none"/>`;
        for (const z of g.zones) {
          const f1 = frac(z.from), f2 = frac(z.to);
          s += `<path d="${arc(cx, cy, zr, 135 + 270 * f1, 270 * (f2 - f1))}" stroke="${z.color}" stroke-width="${f(zw)}" fill="none"/>`;
        }
        s += `<path class="fill" stroke-width="${f(thick)}" stroke-linecap="round" fill="none"/>`;
        const step = niceStep(span, TICKS.dial[g.size] || 7), lr = R - thick / 2 - D * 0.115;
        for (let t = Math.ceil(g.min / step - 1e-9) * step; t <= g.max + step * 1e-6; t += step) {
          const a = 135 + 270 * frac(t);
          const [x0, y0] = pt(cx, cy, R - thick / 2 - D * 0.02, a), [x1, y1] = pt(cx, cy, R - thick / 2 - D * 0.055, a), [lx, ly] = pt(cx, cy, lr, a);
          s += `<line class="tick" x1="${f(x0)}" y1="${f(y0)}" x2="${f(x1)}" y2="${f(y1)}" stroke-width="${f(D * 0.008)}"/>`;
          s += `<text class="sub" x="${f(lx)}" y="${f(ly)}" font-size="${f(D * 0.048)}" text-anchor="middle" dominant-baseline="central">${tickLabel(t, step)}</text>`;
        }
        s += `<line class="needle" stroke-width="${f(D * 0.022)}" stroke-linecap="round"/>`;
        s += `<circle class="hub" cx="${f(cx)}" cy="${f(cy)}" r="${f(D * 0.045)}"/><circle class="hub2" cx="${f(cx)}" cy="${f(cy)}" r="${f(D * 0.018)}"/>`;
        s += txt("val", cx, cy + R * 0.73, D * 0.14, "middle", true);
        s += txt("unit", cx, cy + R * 1.05, D * 0.05, "middle", false);
        geo = { titleW: W - 2 * pad, valW: R * 1.2, unitW: R * 1.8,
          fill: v => arc(cx, cy, R, 135, Math.max(0.5, 270 * frac(v))),
          needle: v => { const a = (135 + 270 * frac(v)) * Math.PI / 180, c = Math.cos(a), n = Math.sin(a);
            return [cx - c * R * 0.12, cy - n * R * 0.12, cx + c * R * 0.82, cy + n * R * 0.82]; } };
      } else if (style === "bar") {
        W = 200; H = 50;
        const pad = H * 0.12, bx = pad, bw = W - 2 * pad, by = H * 0.56, bh = H * 0.13;
        s += txt("title", pad, pad * 0.45 + H * 0.11, H * 0.13, "start", true);
        s += txt("unit", pad, pad * 0.45 + H * 0.29, H * 0.1, "start", false);
        s += txt("val", W - pad, pad * 0.2 + H * 0.225, H * 0.3, "end", true);
        s += `<rect class="track" x="${f(bx)}" y="${f(by)}" width="${f(bw)}" height="${f(bh)}" rx="${f(bh / 2)}"/>`;
        s += `<rect class="fill" x="${f(bx)}" y="${f(by)}" height="${f(bh)}" rx="${f(bh / 2)}"/>`;
        for (const z of g.zones) {
          const f1 = frac(z.from), f2 = frac(z.to);
          s += `<rect x="${f(bx + bw * f1)}" y="${f(by + bh + H * 0.035)}" width="${f(bw * (f2 - f1))}" height="${f(H * 0.045)}" rx="1" fill="${z.color}"/>`;
        }
        const step = niceStep(span, TICKS.bar[g.size] || 5);
        for (let t = Math.ceil(g.min / step - 1e-9) * step; t <= g.max + step * 1e-6; t += step)
          s += `<text class="sub" x="${f(bx + bw * frac(t))}" y="${f(H * 0.86)}" font-size="${f(H * 0.095)}" text-anchor="middle" dominant-baseline="central">${tickLabel(t, step)}</text>`;
        geo = { titleW: W * 0.55, valW: W * 0.55 - pad, unitW: W * 0.5, bar: v => Math.max(bh, bw * frac(v)) };
      } else {
        W = 100; H = 62;
        const pad = W * 0.06;
        s += txt("title", W / 2, H * 0.15, H * 0.1, "middle", true);
        s += txt("val", W / 2, H * 0.48, H * 0.42, "middle", true);
        s += txt("unit", W / 2, H * 0.83, H * 0.1, "middle", false);
        geo = { titleW: W - 2 * pad, valW: W - 2 * pad, unitW: W - 2 * pad };
      }
      const pw = style === "bar" ? 2 * B : B, ph = style === "dial" ? B : style === "bar" ? Math.round(B * 0.5) : Math.round(B * 0.62);
      box.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${pw}" height="${ph}">` +
        `<rect class="card" x="0.5" y="0.5" width="${W - 1}" height="${H - 1}" rx="${f(Math.min(W, H) * 0.07)}"/>${s}</svg>`;
      const q = sel => box.querySelector(sel), qa = sel => box.querySelectorAll(sel);
      const el = { card: q(".card"), title: q(".title"), val: q(".val"), unit: q(".unit"), fill: q(".fill"), needle: q(".needle"),
        track: q(".track"), hub: q(".hub"), hub2: q(".hub2"), subs: qa(".sub"), ticks: qa(".tick") };
      return { el: box, update(g) {
        const p = palette(g), has = g.value != null;
        el.card.setAttribute("fill", p.card);
        el.title.setAttribute("fill", p.sub);
        el.val.setAttribute("fill", p.text);
        el.unit.setAttribute("fill", p.sub);
        for (const t of el.subs) t.setAttribute("fill", p.sub);
        for (const t of el.ticks) t.setAttribute("stroke", p.sub);
        fit(el.title, g.name, geo.titleW);
        fit(el.val, g.text || "-", geo.valW);
        fit(el.unit, ((g.units || "") + "   " + (g.note || "")).trim(), geo.unitW);
        if (style === "dial") {
          el.track.setAttribute("stroke", p.track);
          el.fill.setAttribute("stroke", p.fill);
          el.fill.setAttribute("d", has ? geo.fill(g.value) : "");
          el.needle.style.display = has ? "" : "none";
          if (has) { const [a, b, c, d] = geo.needle(g.value);
            el.needle.setAttribute("x1", f(a)); el.needle.setAttribute("y1", f(b)); el.needle.setAttribute("x2", f(c)); el.needle.setAttribute("y2", f(d)); }
          el.needle.setAttribute("stroke", p.needle);
          el.hub.setAttribute("fill", p.needle);
          el.hub2.setAttribute("fill", p.card);
        } else if (style === "bar") {
          el.track.setAttribute("fill", p.track);
          el.fill.setAttribute("fill", p.fill);
          el.fill.setAttribute("width", has ? f(geo.bar(g.value)) : "0");
        }
      } };
    }

    function renderGrid(d) {
      const rows = d.rows || [], tb = $("rows"), key = rows.map(r => r.name).join("\n");
      if (key !== rowKey) {
        rowKey = key;
        tb.textContent = "";
        for (let i = 0; i < rows.length; i++) {
          const tr = tb.insertRow();
          tr.innerHTML = "<td></td><td class=\"v\"><span></span><small></small></td><td class=\"m mm\"></td><td class=\"m mm\"></td>";
        }
      }
      $("gridTable").hidden = !rows.length;
      $("gridTable").classList.toggle("nomm", !d.minMax);
      $("gridTable").classList.toggle("idle", !d.scanning);
      $("gridEmpty").hidden = rows.length > 0;
      rows.forEach((r, i) => {
        const tr = tb.rows[i], c = tr.cells, off = r.flash && !flashOn;
        setText(c[0], r.name);
        setText(c[1].firstChild, r.value);
        setText(c[1].lastChild, r.units);
        setText(c[2], r.min);
        setText(c[3], r.max);
        // a row colour without a text colour: text that reads on it (the page is dark)
        const bg = off ? r.nbg : r.bg, fg = (off ? r.nfg : r.fg) || (bg ? contrast(bg) : null);
        tr.style.background = bg || "";
        tr.style.color = fg || "";
        c[1].style.fontSize = r.size ? (r.size * 4 / 3) + "px" : "";
        c[2].style.color = c[3].style.color = fg ? "inherit" : "";
      });
    }

    function renderDash(d) {
      const dash = d.dash || {}, gs = dash.gauges || [], box = $("gauges");
      setText($("dashName"), dash.name || "");
      $("dash").style.background = dash.back || "";
      while (gaugeEls.length > gs.length) gaugeEls.pop().el.remove();
      gs.forEach((g, i) => {
        const key = JSON.stringify([g.name, g.units, g.style, g.size, g.min, g.max, g.zones, g.chip]);
        let ge = gaugeEls[i];
        if (!ge || ge.key !== key) {
          const fresh = buildGauge(g);
          fresh.key = key;
          if (ge) box.replaceChild(fresh.el, ge.el); else box.appendChild(fresh.el);
          gaugeEls[i] = ge = fresh;
        }
        ge.update(g);
      });
      $("dashEmpty").hidden = gs.length > 0;
    }

    function render() {
      const d = last;
      const st = $("state");
      setText(st, d.state || "");
      st.className = "pill " + String(d.state || "").split(" ")[0];
      setText($("rec"), d.logging ? (d.paused ? "\u25cf REC paused" : "\u25cf REC") : "");
      setText($("status"), (d.status || []).join("  \u00b7  "));
      document.title = "UVScan live - " + (d.state || "");
      if (tab === "grid") renderGrid(d); else if (tab === "dash") renderDash(d);
    }

    // The chart: the scan's samples (chart.json: the last so many seconds
    // first, then what came after), a lane per PID, each on its own scale.
    const COLORS = ["#46aaff", "#ff8a3d", "#3ddc84", "#f0c419", "#c77dff", "#ff5d73", "#2ec4b6", "#a3a3ff", "#ffb4a2", "#9be564"];
    // What it charts is what UVScan's chart shows (its PIDs, their order,
    // colours, scales and alert levels, the mode, the span), unless this
    // device picks its own PIDs (ch.mine) or span (ch.ownSpan), kept here.
    const ch = { session: -1, loaded: 0, names: [], units: [], sw: [], t: [], v: [], marks: [], span: 60,
      paused: false, t1: 0, pspan: 60, cursor: null, view: null, need: 0, mine: null, ownSpan: 0, picking: false, chipKey: "" };
    try {
      const sv = JSON.parse(localStorage.getItem("uvscanChart") || "{}");
      if ([15, 30, 60, 120, 300, 600, 900].includes(sv.ownSpan)) ch.span = ch.ownSpan = sv.ownSpan;
      if (Array.isArray(sv.mine)) ch.mine = sv.mine;
    } catch (e) { }
    function saveChart() {
      try { localStorage.setItem("uvscanChart", JSON.stringify({ ownSpan: ch.ownSpan, mine: ch.mine })); } catch (e) { }
    }
    // every channel, in UVScan's lane order: {c, name, color, width, lo, hi,
    // levels, bands, on}
    function looks() {
      const lk = last && last.chart && Array.isArray(last.chart.ch) ? last.chart.ch : [];
      const by = new Map(lk.map(s => [s.name, s]));
      const order = lk.map(s => s.name).filter(n => ch.names.includes(n)).concat(ch.names.filter(n => !by.has(n)));
      return order.map(n => {
        const c = ch.names.indexOf(n), s = by.get(n) || {};
        return { c, name: n, color: s.color || COLORS[c % COLORS.length], width: s.width || 2, lo: s.lo, hi: s.hi,
          levels: s.levels || null, bands: s.bands || [],
          on: ch.mine ? ch.mine.includes(n) : lk.length ? !!s.on : c < 8 };
      });
    }
    function chartMode() { return (last && last.chart && last.chart.mode) || "lanes"; }

    async function pollChart(signal) {
      const since = ch.t.length ? ch.t[ch.t.length - 1] : -1;
      const back = Math.min(900, Math.max(ch.span, 60, ch.need));
      const url = ch.session < 0 ? `chart.json?back=${back}` : `chart.json?session=${ch.session}&since=${since}`;
      const r = await fetch(url, { cache: "no-store", signal });
      if (!r.ok) throw new Error(r.status);
      const d = await r.json();
      if (d.full) {
        ch.session = d.session; ch.loaded = back;
        ch.names = d.names; ch.units = d.units; ch.sw = d.switch;
        ch.t = []; ch.v = d.names.map(() => []);
        ch.paused = false; ch.cursor = null; ch.chipKey = "";
      }
      const lastT = ch.t.length ? ch.t[ch.t.length - 1] : -Infinity;
      d.t.forEach((t, i) => {
        if (t <= lastT) return; // had it
        ch.t.push(t);
        d.v[i].forEach((x, c) => { if (c < ch.v.length) ch.v[c].push(x); });
      });
      // the last 15 minutes are kept
      let drop = 0;
      while (drop < ch.t.length && ch.t[drop] < ch.t[ch.t.length - 1] - 900) drop++;
      if (drop > 200) { ch.t.splice(0, drop); for (const a of ch.v) a.splice(0, drop); }
      ch.marks = d.marks || [];
      drawChart();
    }

    // The PIDs picker: made again only when what it shows changes (UVScan's
    // ticks, colours or order, or this device's pick).
    function paintChips(all) {
      $("csame").hidden = !ch.mine && !ch.ownSpan;
      setText($("cnote"), ch.mine ? "This device's own pick. Same as UVScan shows what UVScan's chart shows again."
        : "As UVScan's chart shows them; ticking PIDs there changes it here. Tap one to pick your own.");
      const key = JSON.stringify(all.map(s => [s.name, s.color, s.on]));
      if (key === ch.chipKey) return;
      ch.chipKey = key;
      const box = $("chipList");
      box.textContent = "";
      for (const s of all) {
        const b = document.createElement("button");
        b.textContent = s.name;
        if (s.on) { b.className = "on"; b.style.color = s.color; }
        b.onclick = () => {
          if (!ch.mine) ch.mine = looks().filter(x => x.on).map(x => x.name);
          ch.mine = ch.mine.includes(s.name) ? ch.mine.filter(x => x !== s.name) : ch.mine.concat([s.name]);
          saveChart(); drawChart();
        };
        box.appendChild(b);
      }
    }

    function indexAt(t) { // the first sample at or after t
      let lo = 0, hi = ch.t.length;
      while (lo < hi) { const m = (lo + hi) >> 1; if (ch.t[m] < t) lo = m + 1; else hi = m; }
      return lo;
    }

    // Drawn as UVScan's chart draws it (TLogChart.Paint): its colours, its
    // axes on the left, the cursor with each value beside it, its numbers.
    const BACK = "#161a1e", PLOT = "#1b1f26", GRID = "#2c323a", DIM = "#828c96", CURSOR = "#ffffff",
      SEL = "#46aaff", MARK = "#ffb020", FONT = "Segoe UI, system-ui, sans-serif";
    function chartStep(range, target) { // NiceStep
      if (!(range > 0) || target < 1) return 1;
      const raw = range / target, mag = Math.pow(10, Math.floor(Math.log10(raw))), f = raw / mag;
      return (f < 1.5 ? 1 : f < 2.25 ? 2 : f < 3.5 ? 2.5 : f < 7.5 ? 5 : 10) * mag;
    }
    function fmtAxis(v, step) { // FormatAxis
      if (Math.abs(v) >= 10000) return trimNum((v / 1000).toFixed(1)) + "k";
      return step >= 1 ? v.toFixed(0) : step >= 0.1 ? v.toFixed(1) : trimNum(v.toFixed(2));
    }
    function fmtShort(x, c) { // FormatValueShort (a switch: ON / OFF)
      if (x == null) return "--";
      if (ch.sw[c]) return x >= 0.5 ? "ON" : "OFF";
      const a = Math.abs(x);
      return a >= 1000 ? x.toFixed(0) : a >= 100 ? trimNum(x.toFixed(1)) : trimNum(x.toFixed(2));
    }
    function fmtLogTime(t) { // FormatLogTime
      const s = Math.max(0, t), m = Math.floor(s / 60), r = s - m * 60;
      return m + ":" + (r < 9.95 ? "0" : "") + r.toFixed(1);
    }
    function caption(s) { const u = ch.units[s.c]; return u ? s.name + " (" + u + ")" : s.name; }

    // a channel's scale: UVScan's (fixed, else what the scan kept spans)
    function rangeOf(s, i0, i1) {
      if (s.lo != null && s.hi != null && s.hi > s.lo) return [s.lo, s.hi];
      if (ch.sw[s.c]) return [-0.15, 1.15];
      const vals = ch.v[s.c];
      let lo = Infinity, hi = -Infinity;
      for (let i = i0; i < i1; i++) { const x = vals[i]; if (x != null) { if (x < lo) lo = x; if (x > hi) hi = x; } }
      if (!isFinite(lo)) return [0, 1];
      if (hi - lo < 1e-9) { lo -= 1; hi += 1; }
      const pad = (hi - lo) * 0.06;
      return [lo - pad, hi + pad];
    }
    // An alert level's test, as UVScan's (the first level that matches wins).
    const OPS = {
      ge: (a, b) => a >= b, gt: (a, b) => a > b, le: (a, b) => a <= b, lt: (a, b) => a < b,
      eq: (a, b) => Math.abs(a - b) <= Math.max(1e-12, Math.min(Math.abs(a), Math.abs(b)) * 1e-12),
      ne: (a, b) => !OPS.eq(a, b) };
    function levelOf(lv, x) {
      for (let i = 0; i < lv.length; i++) if (lv[i].v != null && (OPS[lv[i].op] || OPS.ne)(x, lv[i].v)) return i;
      return -1;
    }
    // the alert levels shaded behind the line (Level bands)
    function plotBands(g, s, lo, hi, top, bot, x0, x1) {
      const Y = x => bot - (x - lo) / (hi - lo) * (bot - top);
      g.save();
      g.globalAlpha = 28 / 255;
      for (const z of s.bands) {
        if (z.from == null || z.to == null) continue;
        const y1 = Math.max(top, Y(z.to)), y2 = Math.min(bot, Y(z.from));
        if (y2 > y1) { g.fillStyle = z.color; g.fillRect(x0, y1, x1 - x0, y2 - y1); }
      }
      g.restore();
    }
    // the line: several samples to a pixel are drawn as their lowest and
    // highest; where an alert level matches (level colours on), in its colour
    // and thicker
    function plotLine(g, s, lo, hi, top, bot, X, i0, i1, x0, x1) {
      const vals = ch.v[s.c], Y = x => bot - (x - lo) / (hi - lo) * (bot - top), lv = s.levels;
      g.save();
      g.beginPath(); g.rect(x0, top - 2, x1 - x0, bot - top + 4); g.clip();
      g.lineJoin = "round"; g.lineCap = "round";
      let pts = [], run = -2;
      const flush = () => {
        if (pts.length >= 2) {
          const L = run >= 0 ? lv[run] : null;
          g.strokeStyle = L && L.color ? L.color : s.color;
          g.lineWidth = L ? s.width + 1.5 : s.width;
          g.beginPath();
          g.moveTo(pts[0][0], pts[0][1]);
          for (let k = 1; k < pts.length; k++) g.lineTo(pts[k][0], pts[k][1]);
          g.stroke();
        }
        pts = pts.length ? [pts[pts.length - 1]] : []; // the next run starts where this one ended
      };
      const add = (px, x) => {
        const L = lv ? levelOf(lv, x) : -1;
        if (pts.length && L !== run) flush();
        run = L;
        pts.push([px, Y(x)]);
      };
      const per = Math.max(1, Math.floor((i1 - i0) / ((x1 - x0) * 2)));
      for (let i = i0; i < i1; i += per) {
        let mn = null, mx = null;
        for (let j = i; j < Math.min(i + per, i1); j++) { const x = vals[j]; if (x == null) continue; if (mn == null || x < mn) mn = x; if (mx == null || x > mx) mx = x; }
        if (mn == null) { flush(); pts = []; continue; } // no data: a break
        const px = X(ch.t[i]);
        add(px, mn);
        if (mx !== mn) add(px, mx);
      }
      flush();
      g.restore();
    }

    function drawChart() {
      if (tab !== "chart") return;
      const all = looks(), sel = all.filter(s => s.on && s.c >= 0), mode = chartMode(), N = sel.length;
      paintChips(all);
      const cv = $("cv"), n = ch.t.length;
      // What it shows: this device paused where it was left; else UVScan
      // paused where it was left there; else the newest (until there is a
      // full span, growing from the left edge, as in UVScan).
      const lk = (last && last.chart) || {}, appPaused = !ch.paused && !!lk.paused && lk.t1 > lk.t0;
      setText($("clive"), ch.paused ? "Live" : "Pause");
      setText($("cpaused"), ch.paused && ch.cursor != null ? "Paused at " + fmtLogTime(ch.cursor)
        : appPaused ? "Paused in UVScan at " + fmtLogTime(lk.cursor) : "");
      $("chartEmpty").hidden = n > 0;
      cv.hidden = n === 0;
      if (!n) return;
      const w = cv.clientWidth, narrow = w < 600;
      const axisW = mode === "overlay" ? Math.max(1, Math.min(N, 6)) * 46 : narrow ? 46 : 58;
      const plotH = mode === "lanes" ? Math.max(1, N) * (narrow ? 86 : 108) : narrow ? 300 : 420;
      const L = Math.round(axisW + 6), T = 8, R = Math.round(w - 10), B = T + plotH, h = B + 26, PW = R - L;
      ch.plotX = { L, R };
      const dpr = window.devicePixelRatio || 1;
      if (cv.width !== Math.round(w * dpr) || cv.height !== Math.round(h * dpr)) {
        cv.width = Math.round(w * dpr); cv.height = Math.round(h * dpr); cv.style.height = h + "px";
      }
      const g = cv.getContext("2d");
      g.setTransform(dpr, 0, 0, dpr, 0, 0);
      const span = ch.paused ? ch.pspan : appPaused ? lk.t1 - lk.t0 : ch.span;
      const t1 = ch.paused ? ch.t1 : appPaused ? lk.t1 : Math.max(ch.t[n - 1], ch.t[0] + span);
      const t0 = t1 - span, X = t => L + (t - t0) / span * PW;
      ch.view = { t0, t1 };
      const i0 = Math.max(0, indexAt(t0) - 1), i1 = Math.min(n, indexAt(t1) + 1);
      // the cursor: where it was paused, else the newest sample
      const cursor = ch.paused ? ch.cursor : appPaused ? lk.cursor : ch.t[n - 1];
      let ci = Math.min(n - 1, indexAt(cursor)); // the sample whose values it shows
      if (ci > 0 && cursor - ch.t[ci - 1] < ch.t[ci] - cursor) ci--;
      const cx = X(cursor);

      const txt = (s, x, y, size, color, align, bold, maxW) => { // y: the middle; too wide for maxW: cut, with ...
        g.font = (bold ? "600 " : "") + size + "px " + FONT;
        if (maxW && g.measureText(s).width > maxW) {
          let k = s.length;
          while (k > 1 && g.measureText(s.slice(0, k) + "...").width > maxW) k--;
          s = s.slice(0, k) + "...";
        }
        g.fillStyle = color; g.textAlign = align; g.textBaseline = "middle";
        g.fillText(s, x, y);
      };
      const tw = (s, size, bold) => { g.font = (bold ? "600 " : "") + size + "px " + FONT; return g.measureText(s).width; };
      const hline = y => { g.strokeStyle = GRID; g.lineWidth = 1; g.beginPath(); g.moveTo(L, Math.round(y) + 0.5); g.lineTo(R, Math.round(y) + 0.5); g.stroke(); };
      const vline = (x, color, width, alpha) => {
        g.save(); g.globalAlpha = alpha; g.strokeStyle = color; g.lineWidth = width;
        g.beginPath(); g.moveTo(Math.round(x) + 0.5, T); g.lineTo(Math.round(x) + 0.5, B); g.stroke(); g.restore();
      };
      const fill = (x, y, ww, hh, color, alpha) => { g.save(); g.globalAlpha = alpha; g.fillStyle = color; g.fillRect(x, y, ww, hh); g.restore(); };
      const timeX = x => Math.min(Math.max(x, L + 40), w - 41); // a time label's middle: inside at both edges
      const Y = (v, lo, hi, top, ht) => top + ht - (v - lo) / (hi - lo) * ht;

      g.fillStyle = BACK; g.fillRect(0, 0, w, h);
      g.fillStyle = PLOT; g.fillRect(L, T, PW, plotH);
      // time grid and labels (not under the cursor's time)
      const step = chartStep(span, Math.max(2, Math.trunc(PW / 90)));
      for (let t = Math.ceil(t0 / step) * step; t <= t1 + 1e-9; t += step) {
        const x = X(t);
        vline(x, GRID, 1, 1);
        if (Math.abs(timeX(x) - timeX(cx)) > 70) txt(fmtLogTime(t), timeX(x), B + 13, 11, DIM, "center");
      }

      if (!N) txt("Tick channels in UVScan's chart to chart them", L + PW / 2, T + plotH / 2, 15, DIM, "center");
      else if (mode === "lanes") {
        const lh = plotH / N;
        sel.forEach((s, k) => {
          const top = T + k * lh, [lo, hi] = rangeOf(s, i0, i1);
          if (k > 0) hline(top);
          plotBands(g, s, lo, hi, top + 3, top + lh - 3, L, R);
          plotLine(g, s, lo, hi, top + 3, top + lh - 3, X, i0, i1, L, R);
          // the name on the side away from the cursor, the scale on the left
          const name = caption(s), nw = Math.min(PW / 2 - 8, tw(name, 12, true) + 8);
          if (cx > L + PW / 2) { fill(L + 2, top + 2, nw, 16, PLOT, 170 / 255); txt(name, L + 6, top + 10, 12, s.color, "left", true, PW / 2 - 8); }
          else { fill(R - 8 - nw, top + 2, nw, 16, PLOT, 170 / 255); txt(name, R - 8, top + 10, 12, s.color, "right", true, PW / 2 - 8); }
          txt(fmtAxis(hi, (hi - lo) / 4), axisW, top + 8, 10.5, s.color, "right", false, axisW);
          if (lh >= 34) txt(fmtAxis(lo, (hi - lo) / 4), axisW, top + lh - 8, 10.5, s.color, "right", false, axisW);
          // its value beside the cursor, inside its own lane
          const v = ch.v[s.c][ci];
          if (v != null) {
            let y = Y(Math.min(hi, Math.max(lo, v)), lo, hi, top + 3, lh - 6);
            if (lh >= 24) y = Math.min(top + lh - 10, Math.max(top + 10, y));
            const bh = Math.min(18, Math.max(11, lh - 2)), fs = bh * 12 / 18, text = fmtShort(v, s.c) + " " + (ch.units[s.c] || "");
            const bw = tw(text, fs, true) + 10;
            const bx = cx + bw + 6 > R ? cx - bw - 6 : cx + 6, by = Math.min(B - bh, Math.max(T, y - bh / 2));
            fill(bx, by, bw, bh, BACK, 225 / 255);
            fill(bx, by, 3, bh, s.color, 1);
            txt(text, bx + 5, by + bh / 2, fs, s.color, "left", true);
          }
        });
      } else {
        const rs = sel.map(s => rangeOf(s, i0, i1));
        if (mode === "overlay") {
          sel.forEach((s, k) => plotBands(g, s, rs[k][0], rs[k][1], T, B, L, R));
          sel.forEach((s, k) => {
            const [lo, hi] = rs[k];
            plotLine(g, s, lo, hi, T, B, X, i0, i1, L, R);
            if (k < 6) { // one narrow axis each, side by side
              const x = k * 46 + 44;
              txt(s.name, x, T + 7, 10, s.color, "right", true, 44);
              txt(fmtAxis(hi, (hi - lo) / 4), x, T + 21, 10.5, s.color, "right");
              txt(fmtAxis((hi + lo) / 2, (hi - lo) / 4), x, T + plotH / 2, 10.5, s.color, "right");
              txt(fmtAxis(lo, (hi - lo) / 4), x, B - 7, 10.5, s.color, "right");
            }
          });
        } else { // one scale, at the left
          const lo = Math.min(...rs.map(r => r[0])), hi = Math.max(...rs.map(r => r[1]));
          const st = chartStep(hi - lo, Math.max(2, Math.trunc(plotH / 40)));
          for (let v = Math.ceil(lo / st) * st; v <= hi; v += st) {
            const y = Y(v, lo, hi, T, plotH);
            hline(y);
            txt(fmtAxis(v, st), axisW, y, 10.5, DIM, "right");
          }
          sel.forEach(s => plotLine(g, s, lo, hi, T, B, X, i0, i1, L, R));
        }
      }

      // marks: a line, and the number in a flag at the top
      for (const [t, num] of ch.marks) {
        const x = X(t);
        if (x < L || x > R) continue;
        vline(x, MARK, 1.5, 190 / 255);
        const fw = tw(String(num), 11, true) + 8;
        fill(x, T, fw, 16, MARK, 1);
        txt(String(num), x + fw / 2, T + 8, 11, BACK, "center", true);
      }
      // a range selected in UVScan
      if (lk.sel0 != null && lk.sel1 > lk.sel0) {
        const x0 = Math.max(L, X(lk.sel0)), x1 = Math.min(R, X(lk.sel1));
        if (x1 > x0) {
          fill(x0, T, x1 - x0, plotH, SEL, 38 / 255);
          vline(x0, SEL, 1, 160 / 255); vline(x1, SEL, 1, 160 / 255);
        }
      }
      // the cursor, its time, and (overlaid) one box with every value at it
      if (cx >= L && cx <= R) {
        vline(cx, CURSOR, 1.2, 200 / 255);
        txt(fmtLogTime(cursor), timeX(cx), B + 13, 11, CURSOR, "center", true);
        if (mode !== "lanes" && N) {
          const rows = sel.map(s => {
            const v = ch.v[s.c][ci], lvl = s.levels && v != null ? levelOf(s.levels, v) : -1;
            return { text: s.name + ":  " + fmtShort(v, s.c) + " " + (ch.units[s.c] || ""),
              color: lvl >= 0 && s.levels[lvl].color ? s.levels[lvl].color : s.color };
          });
          const pw = Math.max(...rows.map(r => tw(r.text, 12, true))) + 16;
          const bx = cx + pw + 10 > R ? cx - pw - 8 : cx + 8, by = T + (ch.marks.length ? 20 : 6);
          fill(bx, by, pw, rows.length * 17 + 8, BACK, 230 / 255);
          rows.forEach((r, k) => {
            fill(bx + 4, by + 8 + k * 17, 6, 9, r.color, 1);
            txt(r.text, bx + 13, by + 4 + k * 17 + 8.5, 12, r.color, "left", true);
          });
        }
      }
      g.textAlign = "left";
    }

    function chartAt(ev) {
      if (!ch.t.length) return;
      const cv = $("cv"), rc = cv.getBoundingClientRect(), px = ch.plotX || { L: 0, R: rc.width };
      pauseHere();
      const f = Math.min(1, Math.max(0, (ev.clientX - rc.left - px.L) / (px.R - px.L)));
      ch.cursor = ch.t1 - ch.pspan + f * ch.pspan;
      drawChart();
    }
    $("cv").addEventListener("pointerdown", ev => { chartAt(ev); try { $("cv").setPointerCapture(ev.pointerId); } catch (e) { } });
    $("cv").addEventListener("pointermove", ev => { if (ev.buttons) chartAt(ev); });
    // this device's own pause, at what it shows now (Live: back to UVScan's)
    function pauseHere() {
      if (ch.paused || !ch.view) return;
      const lk = (last && last.chart) || {};
      ch.paused = true; ch.t1 = ch.view.t1; ch.pspan = ch.view.t1 - ch.view.t0;
      ch.cursor = lk.paused ? lk.cursor : ch.t[ch.t.length - 1];
    }
    $("clive").onclick = () => {
      if (ch.paused) { ch.paused = false; ch.cursor = null; }
      else if (ch.t.length) pauseHere();
      drawChart();
    };
    $("cpick").onclick = () => { ch.picking = !ch.picking; $("chips").hidden = !ch.picking; };
    $("csame").onclick = () => { ch.mine = null; ch.ownSpan = 0; saveChart(); syncSpan(); drawChart(); };
    function setSpan(sp) {
      ch.span = sp;
      $("span").value = String(sp);
      if (ch.span > ch.loaded) ch.session = -1; // more than it has: all again
    }
    // UVScan's span (the nearest this has), unless this device picked one
    function syncSpan() {
      const lk = last && last.chart;
      if (lk && lk.paused && ch.t.length) {
        const need = Math.min(900, Math.ceil(ch.t[ch.t.length - 1] - lk.t0) + 5);
        if (lk.t0 < ch.t[0] - 0.5 && need > ch.loaded) { ch.need = need; ch.session = -1; }
      } else ch.need = 0;
      const want = ch.ownSpan || (last && last.chart && last.chart.span);
      if (!want) return;
      const opts = [...$("span").options].map(o => +o.value);
      const sp = opts.reduce((a, b) => Math.abs(b - want) < Math.abs(a - want) ? b : a);
      if (sp !== ch.span) setSpan(sp);
    }
    $("span").value = String(ch.span);
    $("span").onchange = () => {
      ch.ownSpan = +$("span").value;
      setSpan(ch.ownSpan);
      if (ch.paused) ch.pspan = ch.span;
      saveChart();
      drawChart();
    };
    window.addEventListener("resize", drawChart);

    function showTab(t) {
      tab = ["grid", "chart", "dash"].includes(t) ? t : "grid";
      $("grid").hidden = tab !== "grid";
      $("chart").hidden = tab !== "chart";
      $("dash").hidden = tab !== "dash";
      for (const b of document.querySelectorAll("nav button")) b.classList.toggle("on", b.dataset.tab === tab);
      try { localStorage.setItem("uvscanTab", tab); } catch (e) { }
      try { history.replaceState(null, "", "#" + tab); } catch (e) { }
      if (last) render();
      drawChart();
    }

    async function poll() {
      const ctl = new AbortController(), timer = setTimeout(() => ctl.abort(), 3000);
      try {
        const r = await fetch("live.json", { cache: "no-store", signal: ctl.signal });
        if (!r.ok) throw new Error(r.status);
        last = await r.json();
        fails = 0;
        $("lost").hidden = true;
        render();
        syncSpan();
        if (tab === "chart") await pollChart(ctl.signal);
      } catch (e) {
        if (++fails >= 3) $("lost").hidden = false;
      } finally {
        clearTimeout(timer);
        setTimeout(poll, fails ? 1000 : 250);
      }
    }

    for (const b of document.querySelectorAll("nav button")) b.onclick = () => showTab(b.dataset.tab);
    // the tab: the link's (#grid, #chart, #dash), else the one last shown
    try { tab = localStorage.getItem("uvscanTab") || "grid"; } catch (e) { }
    if (["#grid", "#chart", "#dash"].includes(location.hash)) tab = location.hash.slice(1);
    showTab(tab);
    setInterval(() => { flashOn = !flashOn; if (last) render(); }, 400);
    poll();
    </script>
    </body>
    </html>
    ''';
end;

initialization
  JsonFormat := TFormatSettings.Invariant;

end.
