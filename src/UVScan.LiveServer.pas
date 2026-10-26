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
  end;

{ This device's address on its network (the one its traffic goes out by),
  e.g. '192.168.1.23'; '' when it has none. Sends nothing. }
function LocalNetworkAddress: string;

{ 'GET /live.json?x=1 HTTP/1.1' -> 'GET', '/live.json'. False if it is not a request line. }
function ParseRequestLine(const Line: string; out Method, Path: string): Boolean;

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
  Parts: TArray<string>;
  Q: Integer;
begin
  Method := '';
  Path := '';
  Parts := Line.Trim.Split([' ']);
  Result := (Length(Parts) = 3) and StartsStr('HTTP/', Parts[2]) and StartsStr('/', Parts[1]);
  if not Result then
    Exit;
  Method := UpperCase(Parts[0]);
  Path := Parts[1];
  Q := Path.IndexOfAny(['?', '#']);
  if Q >= 0 then
    Path := Copy(Path, 1, Q);
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
  Line, Method, Path, Status, ContentType, Text: string;
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
  if not ParseRequestLine(Line, Method, Path) then
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
    </style>
    </head>
    <body>
    <header>
      <div class="top"><span class="brand">UVScan</span><span id="state" class="pill">...</span><span id="rec"></span></div>
      <div id="status"></div>
      <nav><button data-tab="grid">Grid</button><button data-tab="dash">Dashboard</button></nav>
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
      if (tab === "grid") renderGrid(d); else renderDash(d);
    }

    function showTab(t) {
      tab = t === "dash" ? "dash" : "grid";
      $("grid").hidden = tab !== "grid";
      $("dash").hidden = tab !== "dash";
      for (const b of document.querySelectorAll("nav button")) b.classList.toggle("on", b.dataset.tab === tab);
      try { localStorage.setItem("uvscanTab", tab); } catch (e) { }
      try { history.replaceState(null, "", tab === "dash" ? "#dash" : "#grid"); } catch (e) { }
      if (last) render();
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
      } catch (e) {
        if (++fails >= 3) $("lost").hidden = false;
      } finally {
        clearTimeout(timer);
        setTimeout(poll, fails ? 1000 : 250);
      }
    }

    for (const b of document.querySelectorAll("nav button")) b.onclick = () => showTab(b.dataset.tab);
    // the tab: the link's (#dash, #grid), else the one last shown
    try { tab = localStorage.getItem("uvscanTab") || "grid"; } catch (e) { }
    if (location.hash === "#dash" || location.hash === "#grid") tab = location.hash.slice(1);
    showTab(tab);
    setInterval(() => { flashOn = !flashOn; if (last) render(); }, 400);
    poll();
    </script>
    </body>
    </html>
    ''';
end;

end.
