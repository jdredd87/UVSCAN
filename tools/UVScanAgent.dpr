program UVScanAgent;

{ Lets the development PC try UVScan on another Windows PC that has no
  Delphi (a laptop at the car, say): run this there, and tools\agent.ps1 on
  the development PC sends it builds, runs them, clicks and types in them,
  takes screenshots and fetches the results, over the home network.

  UVScanAgent [port] [address]

  port     default 8765
  address  default 0.0.0.0 (every network this PC is on); 127.0.0.1 keeps
           it to this PC

  Every request but /ping needs the token in agent-token.txt beside this
  program (made on the first run when missing), because the agent runs
  whatever it is sent. Windows asks once whether to let it through the
  firewall. While it runs it keeps the PC awake and its screen on; closing
  the window or Ctrl+C stops it.

  GET  /ping                     'UVScanAgent <version> <computer>' (no token)
  GET  /info                     computer, user, Windows, screen, serial ports, addresses
  PUT  /file?path=P              writes the body to P
  GET  /file?path=P              P
  GET  /list?path=P              the folders and files in P
  POST /delete?path=P            deletes file or folder P
  POST /unzip?path=Z&to=D        extracts zip Z into folder D
  POST /zip?path=D&to=Z          zips folder D into Z
  POST /run?timeout=S&dir=D      runs the command line in the body, hidden, for up to S
                                 seconds (default 60); X-Exit-Code and its output
  POST /start?dir=D              starts the command line in the body on the desktop; its process id
  POST /kill?name=N | ?pid=P     ends processes
  GET  /windows                  the visible windows: handle, process id, class, title, position
  GET  /shot[?title=T]           the screen, or the window whose title contains T, as PNG
  POST /click?x=X&y=Y[&title=T][&button=left|right|double]
  POST /wheel?x=X&y=Y&n=N[&title=T]   N notches, negative = down
  POST /key?vk=V[&mods=csaw][&title=T] a virtual key, with Ctrl/Shift/Alt/Windows
  POST /text[?title=T]           types the body
  POST /size?w=W&h=H[&title=T]   moves the window to 40,20 and sizes it
  POST /quit                     stops the agent

  Paths are from the agent's folder unless absolute, and %VARIABLES% are
  expanded. Coordinates are window client pixels with a title, screen
  pixels without. }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, Winapi.Messages, Winapi.TlHelp32, Winapi.IpHlpApi, Winapi.IpTypes,
  System.SysUtils, System.Types, System.Classes, System.StrUtils, System.Math, System.IOUtils, System.Zip,
  System.NetEncoding, System.Win.Registry, System.SyncObjs, System.Generics.Collections,
  System.Net.Socket, Vcl.Graphics, Vcl.Imaging.pngimage,
  UVScan.Hex in '..\src\UVScan.Hex.pas',
  UVScan.Serial in '..\src\UVScan.Serial.pas';

const
  AgentVersion = '1';
  DefaultPort = 8765;
  MaxBody = 512 * 1024 * 1024;
  CAPTUREBLT = $40000000;
  PW_RENDERFULLCONTENT = 2;

type
  TRequest = record
    Method, Path, Token: string;
    Query: TDictionary<string, string>;
    Body: TBytes;
    function Q(const Name: string; const Default: string = ''): string;
  end;

  TResponse = record
    Status: Integer;
    ContentType: string;
    Body: TBytes;
    ExitCode: string; // X-Exit-Code, for /run
    procedure Text(const S: string; Code: Integer = 200);
  end;

  EBadRequest = class(Exception);

function PrintWindow(H: HWND; DC: HDC; Flags: UINT): BOOL; stdcall; external user32;
function SetDpiContext(Context: THandle): BOOL; stdcall; external user32 name 'SetProcessDpiAwarenessContext' delayed;

{ Real pixels on every screen, even after the display scaling changes while
  the agent runs (system-DPI awareness then sees a stretched, smaller
  desktop). Windows 10 1703 on; older ones get system awareness. }
procedure UseRealPixels;
const
  PerMonitorAwareV2 = THandle(-4);
begin
  try
    if SetDpiContext(PerMonitorAwareV2) then
      Exit;
  except
    // no such function (an older Windows)
  end;
  SetProcessDPIAware;
end;

var
  BaseDir, Token: string;
  Stopping: Boolean;
  LogLock, ShotLock: TCriticalSection;

function TRequest.Q(const Name, Default: string): string;
begin
  if not Query.TryGetValue(Name, Result) then
    Result := Default;
end;

procedure TResponse.Text(const S: string; Code: Integer);
begin
  Status := Code;
  ContentType := 'text/plain; charset=utf-8';
  Body := TEncoding.UTF8.GetBytes(S);
end;

procedure Log(const S: string);
begin
  LogLock.Enter;
  try
    Writeln(FormatDateTime('hh:nn:ss  ', Now) + S);
  finally
    LogLock.Leave;
  end;
end;

function FullPath(const P: string): string;
var
  Buf: array[0..32767] of Char;
begin
  if P = '' then
    raise EBadRequest.Create('path missing');
  SetString(Result, Buf, ExpandEnvironmentStrings(PChar(P), Buf, Length(Buf)) - 1);
  if not TPath.IsPathRooted(Result) then
    Result := TPath.Combine(BaseDir, Result);
end;

function ComputerName: string;
var
  Buf: array[0..MAX_COMPUTERNAME_LENGTH] of Char;
  N: DWORD;
begin
  N := Length(Buf);
  if GetComputerName(Buf, N) then
    SetString(Result, Buf, N)
  else
    Result := '?';
end;

function LocalAddresses: string;
var
  Size: ULONG;
  Buf: TBytes;
  A: PIP_ADAPTER_INFO;
  S: PIP_ADDR_STRING;
  Ip: string;
begin
  Result := '';
  Size := 0;
  GetAdaptersInfo(nil, Size);
  if Size = 0 then
    Exit;
  SetLength(Buf, Size);
  A := PIP_ADAPTER_INFO(@Buf[0]);
  if GetAdaptersInfo(A, Size) <> ERROR_SUCCESS then
    Exit;
  while A <> nil do
  begin
    S := @A.IpAddressList;
    while S <> nil do
    begin
      Ip := string(PAnsiChar(@S.IpAddress.S[0]));
      if (Ip <> '') and (Ip <> '0.0.0.0') then
        Result := Result + IfThen(Result <> '', ', ') + Ip;
      S := S.Next;
    end;
    A := A.Next;
  end;
end;

{ The serial ports Windows knows, with the driver's device name (which
  hints at the chip: Silabser = CP210x, VCP = FTDI, ProlificSerial = PL2303). }
function SerialPorts: string;
var
  R: TRegistry;
  Names: TStringList;
  N: string;
begin
  Result := '';
  R := TRegistry.Create(KEY_READ);
  Names := TStringList.Create;
  try
    R.RootKey := HKEY_LOCAL_MACHINE;
    if R.OpenKeyReadOnly('HARDWARE\DEVICEMAP\SERIALCOMM') then
    begin
      R.GetValueNames(Names);
      for N in Names do
        Result := Result + Format('  %s  %s'#13#10, [R.ReadString(N), N]);
    end;
  finally
    Names.Free;
    R.Free;
  end;
  if Result = '' then
    Result := '  (none)'#13#10;
end;

function WindowsVersion: string;
var
  R: TRegistry;
begin
  Result := TOSVersion.ToString;
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_LOCAL_MACHINE;
    if R.OpenKeyReadOnly('SOFTWARE\Microsoft\Windows NT\CurrentVersion') and R.ValueExists('DisplayVersion') then
      Result := Result + ' ' + R.ReadString('DisplayVersion');
  finally
    R.Free;
  end;
end;

function Info: string;
var
  DC: HDC;
  Dpi: Integer;
  UserBuf: array[0..256] of Char;
  N: DWORD;
begin
  DC := GetDC(0);
  Dpi := GetDeviceCaps(DC, LOGPIXELSX);
  ReleaseDC(0, DC);
  N := Length(UserBuf);
  if not GetUserName(UserBuf, N) then
    N := 1;
  Result := Format(
    'Agent      UVScanAgent %s in %s'#13#10 +
    'Computer   %s, user %s'#13#10 +
    'Windows    %s'#13#10 +
    'Screen     %d x %d at %d dpi (%d%%), whole desktop %d x %d'#13#10 +
    'Addresses  %s'#13#10 +
    'Serial ports'#13#10'%s',
    [AgentVersion, BaseDir, ComputerName, string(PChar(@UserBuf[0])), WindowsVersion,
     GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN), Dpi, MulDiv(Dpi, 100, 96),
     GetSystemMetrics(SM_CXVIRTUALSCREEN), GetSystemMetrics(SM_CYVIRTUALSCREEN),
     LocalAddresses, SerialPorts]);
end;

function ListFolder(const Dir: string): string;
var
  S: string;
begin
  if not TDirectory.Exists(Dir) then
    raise EBadRequest.Create('no folder ' + Dir);
  Result := '';
  for S in TDirectory.GetDirectories(Dir) do
    Result := Result + Format('%-19s %12s  %s\'#13#10,
      [FormatDateTime('yyyy-mm-dd hh:nn:ss', TDirectory.GetLastWriteTime(S)), '', ExtractFileName(S)]);
  for S in TDirectory.GetFiles(Dir) do
    Result := Result + Format('%-19s %12d  %s'#13#10,
      [FormatDateTime('yyyy-mm-dd hh:nn:ss', TFile.GetLastWriteTime(S)), TFile.GetSize(S), ExtractFileName(S)]);
end;

{ Processes }

function OpenNul: THandle;
var
  SA: TSecurityAttributes;
begin
  SA.nLength := SizeOf(SA);
  SA.lpSecurityDescriptor := nil;
  SA.bInheritHandle := True;
  Result := CreateFile('NUL', GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, @SA, OPEN_EXISTING, 0, 0);
end;

function WorkDir(const Dir: string): string;
begin
  if Dir = '' then
    Result := BaseDir
  else
    Result := FullPath(Dir);
end;

{ Runs CmdLine hidden with its output captured, for up to TimeoutSec; on
  the timeout it and everything it started are ended. }
procedure RunCaptured(const CmdLine, Dir: string; TimeoutSec: Integer; var Res: TResponse);
var
  SA: TSecurityAttributes;
  ReadPipe, WritePipe, Nul, Job: THandle;
  SI: TStartupInfo;
  PI: TProcessInformation;
  Cmd: string;
  Output: TBytesStream;
  Buf: array[0..65535] of Byte;
  Avail, Got, Code: DWORD;
  Deadline: UInt64;
  TimedOut, Exited: Boolean;

  procedure Drain;
  begin
    while PeekNamedPipe(ReadPipe, nil, 0, nil, @Avail, nil) and (Avail > 0) do
      if ReadFile(ReadPipe, Buf, SizeOf(Buf), Got, nil) and (Got > 0) then
        Output.WriteBuffer(Buf, Got)
      else
        Break;
  end;

begin
  SA.nLength := SizeOf(SA);
  SA.lpSecurityDescriptor := nil;
  SA.bInheritHandle := True;
  if not CreatePipe(ReadPipe, WritePipe, @SA, 0) then
    RaiseLastOSError;
  SetHandleInformation(ReadPipe, HANDLE_FLAG_INHERIT, 0);
  Nul := OpenNul;
  Output := TBytesStream.Create;
  Job := CreateJobObject(nil, nil);
  try
    FillChar(SI, SizeOf(SI), 0);
    SI.cb := SizeOf(SI);
    SI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    SI.wShowWindow := SW_HIDE;
    SI.hStdInput := Nul;
    SI.hStdOutput := WritePipe;
    SI.hStdError := WritePipe;
    Cmd := CmdLine;
    UniqueString(Cmd);
    if not CreateProcess(nil, PChar(Cmd), nil, nil, True, CREATE_NO_WINDOW or CREATE_SUSPENDED, nil,
      PChar(WorkDir(Dir)), SI, PI) then
      raise EBadRequest.Create('could not start: ' + SysErrorMessage(GetLastError));
    CloseHandle(WritePipe);
    WritePipe := 0;
    AssignProcessToJobObject(Job, PI.hProcess);
    ResumeThread(PI.hThread);
    CloseHandle(PI.hThread);
    try
      Deadline := GetTickCount64 + UInt64(TimeoutSec) * 1000;
      TimedOut := False;
      repeat
        Drain;
        Exited := WaitForSingleObject(PI.hProcess, 50) = WAIT_OBJECT_0;
        if not Exited and (GetTickCount64 > Deadline) then
        begin
          TerminateJobObject(Job, 1);
          WaitForSingleObject(PI.hProcess, 5000);
          TimedOut := True;
          Exited := True;
        end;
      until Exited;
      Sleep(50);
      Drain;
      GetExitCodeProcess(PI.hProcess, Code);
    finally
      CloseHandle(PI.hProcess);
    end;
    Res.Status := 200;
    Res.ContentType := 'application/octet-stream';
    if TimedOut then
    begin
      Res.ExitCode := 'timeout';
      Res.Body := Copy(Output.Bytes, 0, Output.Size);
      Res.Body := Res.Body + TEncoding.UTF8.GetBytes(Format(#13#10'[ended after %d s]'#13#10, [TimeoutSec]));
    end
    else
    begin
      Res.ExitCode := IntToStr(Integer(Code));
      Res.Body := Copy(Output.Bytes, 0, Output.Size);
    end;
  finally
    CloseHandle(Job);
    Output.Free;
    CloseHandle(Nul);
    if WritePipe <> 0 then
      CloseHandle(WritePipe);
    CloseHandle(ReadPipe);
  end;
end;

function StartOnDesktop(const CmdLine, Dir: string): Cardinal;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  Cmd: string;
begin
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  Cmd := CmdLine;
  UniqueString(Cmd);
  if not CreateProcess(nil, PChar(Cmd), nil, nil, False, CREATE_NEW_CONSOLE, nil, PChar(WorkDir(Dir)), SI, PI) then
    raise EBadRequest.Create('could not start: ' + SysErrorMessage(GetLastError));
  CloseHandle(PI.hThread);
  CloseHandle(PI.hProcess);
  Result := PI.dwProcessId;
end;

function KillProcesses(const Name: string; Pid: Cardinal): string;
var
  Snap, H: THandle;
  E: TProcessEntry32;
  Want: string;
begin
  Result := '';
  Want := LowerCase(Name);
  if (Want <> '') and not Want.EndsWith('.exe') then
    Want := Want + '.exe';
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  try
    E.dwSize := SizeOf(E);
    if Process32First(Snap, E) then
      repeat
        if (E.th32ProcessID <> GetCurrentProcessId) and
          (((Pid <> 0) and (E.th32ProcessID = Pid)) or ((Want <> '') and (LowerCase(E.szExeFile) = Want))) then
        begin
          H := OpenProcess(PROCESS_TERMINATE or SYNCHRONIZE, False, E.th32ProcessID);
          if (H <> 0) and TerminateProcess(H, 1) then
          begin
            WaitForSingleObject(H, 3000);
            Result := Result + Format('ended %s (%d)'#13#10, [string(E.szExeFile), E.th32ProcessID]);
          end
          else
            Result := Result + Format('could not end %s (%d): %s'#13#10,
              [string(E.szExeFile), E.th32ProcessID, SysErrorMessage(GetLastError)]);
          if H <> 0 then
            CloseHandle(H);
        end;
      until not Process32Next(Snap, E);
  finally
    CloseHandle(Snap);
  end;
  if Result = '' then
    Result := 'none running'#13#10;
end;

{ Windows and input }

type
  TWin = record
    Handle: HWND;
    Pid: DWORD;
    Cls, Title: string;
    Rect: TRect;
  end;

function EnumProc(H: HWND; L: LPARAM): BOOL; stdcall;
var
  W: TWin;
  Buf: array[0..511] of Char;
begin
  Result := True;
  if not IsWindowVisible(H) then
    Exit;
  W.Handle := H;
  GetWindowThreadProcessId(H, W.Pid);
  SetString(W.Cls, Buf, GetClassName(H, Buf, Length(Buf)));
  SetString(W.Title, Buf, GetWindowText(H, Buf, Length(Buf)));
  // FMX's hidden application window
  if (W.Title = '') or (W.Cls = 'FMTApplication') or (W.Cls = 'TFMAppClass') then
    Exit;
  GetWindowRect(H, W.Rect);
  TList<TWin>(L).Add(W);
end;

function VisibleWindows: TArray<TWin>;
var
  List: TList<TWin>;
begin
  List := TList<TWin>.Create;
  try
    EnumWindows(@EnumProc, LPARAM(List));
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

{ The first visible window whose title contains Title (no title: none). }
function FindWin(const Title: string): HWND;
var
  W: TWin;
begin
  Result := 0;
  if Title = '' then
    Exit;
  for W in VisibleWindows do
    if ContainsText(W.Title, Title) then
      Exit(W.Handle);
  raise EBadRequest.Create('no window titled ' + Title);
end;

function WindowList: string;
var
  W: TWin;
begin
  Result := '';
  for W in VisibleWindows do
    Result := Result + Format('%d'#9'%d'#9'%s'#9'%s'#9'%d,%d %dx%d'#13#10,
      [W.Handle, W.Pid, W.Cls, W.Title, W.Rect.Left, W.Rect.Top, W.Rect.Width, W.Rect.Height]);
end;

procedure Activate(H: HWND);
var
  Fg, Mine: DWORD;
begin
  if H = 0 then
    Exit;
  if IsIconic(H) then
    ShowWindow(H, SW_RESTORE);
  if GetForegroundWindow = H then
    Exit;
  // Windows only lets the program in front pass the focus on, so this
  // thread shares its input state for a moment.
  Fg := GetWindowThreadProcessId(GetForegroundWindow, nil);
  Mine := GetCurrentThreadId;
  AttachThreadInput(Mine, Fg, True);
  try
    SetForegroundWindow(H);
    BringWindowToTop(H);
  finally
    AttachThreadInput(Mine, Fg, False);
  end;
  Sleep(150);
end;

{ X, Y in H's client area (or the screen without H) to the screen. }
function ToScreen(H: HWND; X, Y: Integer): TPoint;
begin
  Result := Point(X, Y);
  if H <> 0 then
    ClientToScreen(H, Result);
end;

procedure Click(H: HWND; X, Y: Integer; const Button: string);
var
  P: TPoint;
  Down, Up: DWORD;
  I, Times: Integer;
begin
  Activate(H);
  P := ToScreen(H, X, Y);
  SetCursorPos(P.X, P.Y);
  Sleep(80);
  Down := MOUSEEVENTF_LEFTDOWN;
  Up := MOUSEEVENTF_LEFTUP;
  Times := 1;
  if SameText(Button, 'right') then
  begin
    Down := MOUSEEVENTF_RIGHTDOWN;
    Up := MOUSEEVENTF_RIGHTUP;
  end
  else if SameText(Button, 'double') then
    Times := 2;
  for I := 1 to Times do
  begin
    mouse_event(Down, 0, 0, 0, 0);
    Sleep(40);
    mouse_event(Up, 0, 0, 0, 0);
    Sleep(60);
  end;
end;

procedure Wheel(H: HWND; X, Y, Notches: Integer);
var
  P: TPoint;
  I: Integer;
begin
  Activate(H);
  P := ToScreen(H, X, Y);
  SetCursorPos(P.X, P.Y);
  Sleep(80);
  for I := 1 to Abs(Notches) do
  begin
    mouse_event(MOUSEEVENTF_WHEEL, 0, 0, DWORD(IfThen(Notches < 0, -WHEEL_DELTA, WHEEL_DELTA)), 0);
    Sleep(60);
  end;
end;

procedure PressKey(H: HWND; Vk: Byte; const Mods: string);
const
  ModKeys: array[0..3] of Byte = (VK_CONTROL, VK_SHIFT, VK_MENU, VK_LWIN);
  ModChars = 'csaw';
var
  I: Integer;
begin
  Activate(H);
  for I := 0 to 3 do
    if Pos(ModChars[I + 1], LowerCase(Mods)) > 0 then
      keybd_event(ModKeys[I], 0, 0, 0);
  keybd_event(Vk, 0, 0, 0);
  Sleep(30);
  keybd_event(Vk, 0, KEYEVENTF_KEYUP, 0);
  for I := 3 downto 0 do
    if Pos(ModChars[I + 1], LowerCase(Mods)) > 0 then
      keybd_event(ModKeys[I], 0, KEYEVENTF_KEYUP, 0);
end;

procedure TypeText(H: HWND; const S: string);
var
  C: Char;
  In2: array[0..1] of TInput;
begin
  Activate(H);
  for C in S do
  begin
    FillChar(In2, SizeOf(In2), 0);
    In2[0].Itype := INPUT_KEYBOARD;
    In2[0].ki.wScan := Ord(C);
    In2[0].ki.dwFlags := KEYEVENTF_UNICODE;
    In2[1] := In2[0];
    In2[1].ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;
    SendInput(2, In2[0], SizeOf(TInput));
    Sleep(15);
  end;
end;

{ The screen, or window H as it draws itself (PrintWindow, so it needn't be
  in front), as PNG. }
function Screenshot(H: HWND): TBytes;
var
  Bmp: TBitmap;
  Png: TPngImage;
  R: TRect;
  DC: HDC;
  S: TBytesStream;
begin
  ShotLock.Enter;
  Bmp := TBitmap.Create;
  Png := TPngImage.Create;
  S := TBytesStream.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.Canvas.Lock;
    try
      if H <> 0 then
      begin
        GetWindowRect(H, R);
        Bmp.SetSize(R.Width, R.Height);
        PrintWindow(H, Bmp.Canvas.Handle, PW_RENDERFULLCONTENT); // FMX draws with Direct2D
      end
      else
      begin
        R := Rect(GetSystemMetrics(SM_XVIRTUALSCREEN), GetSystemMetrics(SM_YVIRTUALSCREEN), 0, 0);
        Bmp.SetSize(GetSystemMetrics(SM_CXVIRTUALSCREEN), GetSystemMetrics(SM_CYVIRTUALSCREEN));
        DC := GetDC(0);
        try
          BitBlt(Bmp.Canvas.Handle, 0, 0, Bmp.Width, Bmp.Height, DC, R.Left, R.Top, SRCCOPY or CAPTUREBLT);
        finally
          ReleaseDC(0, DC);
        end;
      end;
    finally
      Bmp.Canvas.Unlock;
    end;
    Png.Assign(Bmp);
    Png.SaveToStream(S);
    Result := Copy(S.Bytes, 0, S.Size);
  finally
    S.Free;
    Png.Free;
    Bmp.Free;
    ShotLock.Leave;
  end;
end;

{ HTTP }

procedure ParseQuery(const S: string; Q: TDictionary<string, string>);
var
  Part: string;
  I: Integer;
begin
  for Part in S.Split(['&']) do
  begin
    I := Pos('=', Part);
    if I > 0 then
      Q.AddOrSetValue(LowerCase(TNetEncoding.URL.Decode(Copy(Part, 1, I - 1))),
        TNetEncoding.URL.Decode(Copy(Part, I + 1, MaxInt)))
    else if Part <> '' then
      Q.AddOrSetValue(LowerCase(TNetEncoding.URL.Decode(Part)), '');
  end;
end;

function ReadRequest(Client: System.Net.Socket.TSocket; var Req: TRequest): Boolean;
var
  Head: TBytes;
  Buf: array[0..65535] of Byte;
  N, I, HeadEnd, Len, Have: Integer;
  Lines, Parts: TArray<string>;
  Line, Target: string;
begin
  Result := False;
  Head := nil;
  HeadEnd := -1;
  while HeadEnd < 0 do
  begin
    if not SocketReadable(Client, 30000) then
      Exit;
    N := SocketReceive(Client, Buf, SizeOf(Buf));
    if N <= 0 then
      Exit;
    Have := Length(Head);
    SetLength(Head, Have + N);
    Move(Buf[0], Head[Have], N);
    for I := 3 to High(Head) do
      if (Head[I - 3] = 13) and (Head[I - 2] = 10) and (Head[I - 1] = 13) and (Head[I] = 10) then
      begin
        HeadEnd := I + 1;
        Break;
      end;
    if (HeadEnd < 0) and (Length(Head) > 65536) then
      Exit;
  end;
  Lines := TEncoding.UTF8.GetString(Head, 0, HeadEnd).Split([#13#10]);
  Parts := Lines[0].Split([' ']);
  if Length(Parts) < 2 then
    Exit;
  Req.Method := UpperCase(Parts[0]);
  Target := Parts[1];
  I := Pos('?', Target);
  if I > 0 then
  begin
    ParseQuery(Copy(Target, I + 1, MaxInt), Req.Query);
    Target := Copy(Target, 1, I - 1);
  end;
  Req.Path := LowerCase(TNetEncoding.URL.Decode(Target));
  Len := 0;
  for Line in Lines do
  begin
    I := Pos(':', Line);
    if I = 0 then
      Continue;
    if SameText(Trim(Copy(Line, 1, I - 1)), 'Content-Length') then
      Len := StrToIntDef(Trim(Copy(Line, I + 1, MaxInt)), 0)
    else if SameText(Trim(Copy(Line, 1, I - 1)), 'X-Token') then
      Req.Token := Trim(Copy(Line, I + 1, MaxInt));
  end;
  if (Len < 0) or (Len > MaxBody) then
    Exit;
  SetLength(Req.Body, Len);
  Have := Min(Len, Length(Head) - HeadEnd);
  if Have > 0 then
    Move(Head[HeadEnd], Req.Body[0], Have);
  while Have < Len do
  begin
    if not SocketReadable(Client, 30000) then
      Exit;
    N := SocketReceive(Client, Req.Body[Have], Len - Have);
    if N <= 0 then
      Exit;
    Inc(Have, N);
  end;
  Result := True;
end;

procedure SendAll(Client: System.Net.Socket.TSocket; const Data: TBytes);
var
  Sent, N: Integer;
begin
  Sent := 0;
  while Sent < Length(Data) do
  begin
    N := SocketSend(Client, Data[Sent], Min(65536, Length(Data) - Sent));
    if N <= 0 then
      Exit;
    Inc(Sent, N);
  end;
end;

procedure SendResponse(Client: System.Net.Socket.TSocket; const Res: TResponse);
const
  Reasons: array[0..4] of string = ('OK', 'Bad Request', 'Forbidden', 'Not Found', 'Internal Server Error');
var
  Reason, Head: string;
begin
  case Res.Status of
    200: Reason := Reasons[0];
    400: Reason := Reasons[1];
    403: Reason := Reasons[2];
    404: Reason := Reasons[3];
  else
    Reason := Reasons[4];
  end;
  Head := Format('HTTP/1.1 %d %s'#13#10'Content-Type: %s'#13#10'Content-Length: %d'#13#10'Connection: close'#13#10,
    [Res.Status, Reason, Res.ContentType, Length(Res.Body)]);
  if Res.ExitCode <> '' then
    Head := Head + 'X-Exit-Code: ' + Res.ExitCode + #13#10;
  SendAll(Client, TEncoding.ASCII.GetBytes(Head + #13#10));
  SendAll(Client, Res.Body);
end;

function BodyText(const Req: TRequest): string;
begin
  Result := TEncoding.UTF8.GetString(Req.Body);
end;

procedure HandleRequest(const Req: TRequest; var Res: TResponse);
var
  P, D: string;
begin
  if Req.Path = '/ping' then
  begin
    Res.Text(Format('UVScanAgent %s %s', [AgentVersion, ComputerName]));
    Exit;
  end;
  if Req.Token <> Token then
  begin
    Res.Text('wrong or missing token', 403);
    Exit;
  end;
  if Req.Path = '/info' then
    Res.Text(Info)
  else if (Req.Path = '/file') and (Req.Method = 'PUT') then
  begin
    P := FullPath(Req.Q('path'));
    ForceDirectories(ExtractFileDir(P));
    TFile.WriteAllBytes(P, Req.Body);
    Res.Text(Format('wrote %s, %d bytes', [P, Length(Req.Body)]));
  end
  else if Req.Path = '/file' then
  begin
    P := FullPath(Req.Q('path'));
    if not TFile.Exists(P) then
      Res.Text('no file ' + P, 404)
    else
    begin
      Res.Status := 200;
      Res.ContentType := 'application/octet-stream';
      // shared reads, for a log UVScan is still writing
      with TFileStream.Create(P, fmOpenRead or fmShareDenyNone) do
      try
        SetLength(Res.Body, Size);
        if Size > 0 then
          ReadBuffer(Res.Body[0], Size);
      finally
        Free;
      end;
    end;
  end
  else if Req.Path = '/list' then
    Res.Text(ListFolder(FullPath(Req.Q('path', '.'))))
  else if Req.Path = '/delete' then
  begin
    P := FullPath(Req.Q('path'));
    if TDirectory.Exists(P) then
      TDirectory.Delete(P, True)
    else if TFile.Exists(P) then
      TFile.Delete(P)
    else
      raise EBadRequest.Create('no file or folder ' + P);
    Res.Text('deleted ' + P);
  end
  else if Req.Path = '/unzip' then
  begin
    P := FullPath(Req.Q('path'));
    D := FullPath(Req.Q('to', '.'));
    ForceDirectories(D);
    TZipFile.ExtractZipFile(P, D);
    Res.Text(Format('extracted %s into %s', [P, D]));
  end
  else if Req.Path = '/zip' then
  begin
    P := FullPath(Req.Q('path'));
    D := FullPath(Req.Q('to'));
    TZipFile.ZipDirectoryContents(D, P);
    Res.Text(Format('zipped %s into %s', [P, D]));
  end
  else if Req.Path = '/run' then
    RunCaptured(BodyText(Req), Req.Q('dir'), StrToIntDef(Req.Q('timeout'), 60), Res)
  else if Req.Path = '/start' then
    Res.Text(IntToStr(StartOnDesktop(BodyText(Req), Req.Q('dir'))))
  else if Req.Path = '/kill' then
    Res.Text(KillProcesses(Req.Q('name'), StrToIntDef(Req.Q('pid'), 0)))
  else if Req.Path = '/windows' then
    Res.Text(WindowList)
  else if Req.Path = '/shot' then
  begin
    Res.Status := 200;
    Res.ContentType := 'image/png';
    Res.Body := Screenshot(FindWin(Req.Q('title')));
  end
  else if Req.Path = '/click' then
  begin
    Click(FindWin(Req.Q('title')), StrToInt(Req.Q('x')), StrToInt(Req.Q('y')), Req.Q('button', 'left'));
    Res.Text('ok');
  end
  else if Req.Path = '/wheel' then
  begin
    Wheel(FindWin(Req.Q('title')), StrToInt(Req.Q('x')), StrToInt(Req.Q('y')), StrToInt(Req.Q('n')));
    Res.Text('ok');
  end
  else if Req.Path = '/key' then
  begin
    PressKey(FindWin(Req.Q('title')), StrToInt(Req.Q('vk')), Req.Q('mods'));
    Res.Text('ok');
  end
  else if Req.Path = '/text' then
  begin
    TypeText(FindWin(Req.Q('title')), BodyText(Req));
    Res.Text('ok');
  end
  else if Req.Path = '/size' then
  begin
    MoveWindow(FindWin(Req.Q('title', 'UVScan')), 40, 20, StrToInt(Req.Q('w')), StrToInt(Req.Q('h')), True);
    Res.Text('ok');
  end
  else if Req.Path = '/quit' then
  begin
    Stopping := True;
    Res.Text('stopping');
  end
  else
    Res.Text('unknown request ' + Req.Method + ' ' + Req.Path, 404);
end;

function Describe(const Req: TRequest): string;
var
  Pair: TPair<string, string>;
begin
  Result := Req.Method + ' ' + Req.Path;
  for Pair in Req.Query do
    Result := Result + ' ' + Pair.Key + '=' + Pair.Value;
  if (Req.Path = '/run') or (Req.Path = '/start') or (Req.Path = '/text') then
    Result := Result + '  ' + LeftStr(BodyText(Req), 120)
  else if Length(Req.Body) > 0 then
    Result := Result + Format('  (%d bytes)', [Length(Req.Body)]);
end;

procedure Serve(Client: System.Net.Socket.TSocket);
var
  Req: TRequest;
  Res: TResponse;
  Who: string;
begin
  Req.Query := TDictionary<string, string>.Create;
  try
    try
      Who := Client.RemoteAddress;
      if not ReadRequest(Client, Req) then
        Exit;
      if Req.Path <> '/ping' then
        Log(Who + '  ' + Describe(Req));
      Res.Status := 500;
      Res.ExitCode := '';
      try
        HandleRequest(Req, Res);
      except
        on E: EBadRequest do
          Res.Text(E.Message, 400);
        on E: Exception do
          Res.Text(E.ClassName + ': ' + E.Message, 500);
      end;
      if Res.Status <> 200 then
        Log(Format('  -> %d %s', [Res.Status, TEncoding.UTF8.GetString(Res.Body)]));
      SendResponse(Client, Res);
    except
      // the other end went away
    end;
  finally
    Req.Query.Free;
    FreeSocket(Client);
  end;
end;

procedure ServeInThread(Client: System.Net.Socket.TSocket);
begin
  TThread.CreateAnonymousThread(
    procedure
    begin
      Serve(Client);
    end).Start;
end;

function LoadToken: string;
var
  F: string;
  G: TGUID;
begin
  F := TPath.Combine(BaseDir, 'agent-token.txt');
  if TFile.Exists(F) then
    Result := Trim(TFile.ReadAllText(F))
  else
    Result := '';
  if Length(Result) < 16 then
  begin
    CreateGUID(G);
    Result := LowerCase(GUIDToString(G).Replace('{', '').Replace('}', '').Replace('-', ''));
    TFile.WriteAllText(F, Result);
  end;
end;

var
  Port: Integer;
  Address: string;
  Listener, Client: System.Net.Socket.TSocket;

begin
  UseRealPixels;
  LogLock := TCriticalSection.Create;
  ShotLock := TCriticalSection.Create;
  try
    BaseDir := ExtractFilePath(ParamStr(0));
    SetCurrentDir(BaseDir);
    Token := LoadToken;
    Port := StrToIntDef(ParamStr(1), DefaultPort);
    Address := ParamStr(2);
    if Address = '' then
      Address := '0.0.0.0';
    Listener := System.Net.Socket.TSocket.Create(TSocketType.TCP);
    Listener.Listen(Address, '', Port);
    // the PC stays awake, and its screen on, while the agent runs
    SetThreadExecutionState(ES_CONTINUOUS or ES_SYSTEM_REQUIRED or ES_DISPLAY_REQUIRED);
    Writeln(Format('UVScan agent %s on %s, port %d. Addresses: %s', [AgentVersion, ComputerName, Port, LocalAddresses]));
    Writeln('Token: ' + Token);
    Writeln('Leave this window open while testing; it keeps this PC awake. Close it to stop.');
    Writeln;
    while not Stopping do
    begin
      try
        Client := Listener.Accept(200);
      except
        Client := nil;
        Sleep(200);
      end;
      if Client <> nil then
        ServeInThread(Client);
    end;
    Log('Stopped.');
    Sleep(300); // the /quit answer goes out
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      Writeln('Enter closes this window.');
      Readln;
      ExitCode := 1;
    end;
  end;
end.
