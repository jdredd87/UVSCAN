unit UVScan.Serial;

{ The serial port the scan engine talks through, and the Windows
  implementation of it. Synchronous (non-overlapped) I/O: the port is owned
  and used by exactly one thread (the scan engine), so no locking.

  On Android the ports are USB serial adapters plugged in through USB OTG
  (FTDI, CP210x, CH34x, CDC-ACM; see UVScan.Serial.Android). Other platforms
  have none: CreateSerialPort raises there and ListSerialPorts is empty, so
  only the Simulator connects. Another transport (Bluetooth, TCP) only has
  to implement ISerialPort.

  An AVT on the network (an AVT with a serial-to-Ethernet port, as the old
  UVSCAN drove) is TTcpSerialPort: the same bytes over a raw TCP
  connection, on every platform. }

interface

uses
  {$IFDEF MSWINDOWS}Winapi.Windows,{$ENDIF} System.SysUtils, System.Classes, System.Net.Socket;

type
  ESerialError = class(Exception);

  TFlowControl = (fcNone, fcRtsCts);

  ISerialPort = interface
    ['{6D1B4C0E-6C7A-4D5E-9F0B-1E2A3C4D5E61}']
    procedure Open;
    procedure Close;
    function IsOpen: Boolean;
    { Waits up to TimeoutMs for at least one byte; returns bytes read (0 on timeout). }
    function Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
    procedure Write(const Data: TBytes);
    procedure Purge;
    function Description: string;
  end;

{$IFDEF MSWINDOWS}
  TWin32SerialPort = class(TInterfacedObject, ISerialPort)
  private
    FPortName: string;
    FBaudRate: Cardinal;
    FFlowControl: TFlowControl;
    FHandle: THandle;
    FReadTimeout: Cardinal;
    procedure CheckOpen;
    procedure RaiseLastError(const Action: string);
    procedure SetReadTimeout(TimeoutMs: Cardinal);
  public
    constructor Create(const PortName: string; BaudRate: Cardinal; FlowControl: TFlowControl);
    destructor Destroy; override;
    procedure Open;
    procedure Close;
    function IsOpen: Boolean;
    function Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
    procedure Write(const Data: TBytes);
    procedure Purge;
    function Description: string;
  end;
{$ENDIF}

const
  DefaultTcpPort = 10001; // the old UVSCAN's default: a serial server's raw TCP port

type
  { An AVT reached over the network: a raw TCP stream to Host:Port carrying
    the AVT's bytes, as its serial port would. Open gives up after a few
    seconds (an interface that is off or on another network). }
  TTcpSerialPort = class(TInterfacedObject, ISerialPort)
  private
    FHost: string;
    FPort: Word;
    FSocket: System.Net.Socket.TSocket;
    procedure CheckOpen;
    procedure Lost(const Why: string);
  public
    constructor Create(const Host: string; Port: Word);
    destructor Destroy; override;
    procedure Open;
    procedure Close;
    function IsOpen: Boolean;
    function Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
    procedure Write(const Data: TBytes);
    procedure Purge;
    function Description: string;
  end;

{ 'host:port', 'host' (port DefaultTcpPort) or either after 'tcp:' / 'tcp://'.
  False when it is not one (no host, a bad port). IPv4 or a host name. }
function ParseTcpAddress(const Address: string; out Host: string; out Port: Word): Boolean;

{ True when S has data to read (or the other end has closed) within
  TimeoutMs (TSocket.WaitForData is not public). }
function SocketReadable(S: System.Net.Socket.TSocket; TimeoutMs: Cardinal): Boolean;
{ Closes S and frees it (S becomes nil). Without the graceful shutdown that
  TSocket's own Close and destructor do, which raises when the other end has
  already gone, or on a listening socket. }
procedure FreeSocket(var S: System.Net.Socket.TSocket);
{ Sends Count bytes of Buf on S; returns how many went (raises on an error).
  On Android a connection the other end has closed is an error here, not a
  signal that ends the app. (TSocket.Send with integer flags fails.) }
function SocketSend(S: System.Net.Socket.TSocket; const Buf; Count: Integer): Integer;
{ Up to Count bytes from S into Buf; 0 when the other end has closed. }
function SocketReceive(S: System.Net.Socket.TSocket; var Buf; Count: Integer): Integer;

{ True when Name is a network address rather than a serial port name: it
  starts with 'tcp:', or has a dot or a colon (192.168.2.99, myavt:5000). }
function IsTcpAddress(const Name: string): Boolean;

{ The port Name stands for: a network address (TTcpSerialPort) or a serial
  port (CreateSerialPort). Not opened yet. }
function CreatePort(const Name: string; BaudRate: Cardinal; FlowControl: TFlowControl): ISerialPort;

{ The serial port called PortName (e.g. 'COM9'); raises ESerialError where
  this platform has none. Not opened yet. }
function CreateSerialPort(const PortName: string; BaudRate: Cardinal; FlowControl: TFlowControl): ISerialPort;

{ COM port names present on this machine, e.g. ['COM1', 'COM6'], in numeric order. }
function ListSerialPorts: TArray<string>;

{ True where CreateSerialPort can work. }
function SerialPortsSupported: Boolean;

{ Lines describing the attached hardware when a port does not show up
  (Android: every USB device with its ids); empty where there is nothing to add. }
function SerialPortDiagnostics: TArray<string>;

implementation

uses
  {$IFDEF MSWINDOWS}System.Win.Registry, Winapi.Winsock2,{$ENDIF}
  {$IFDEF POSIX}Posix.SysSocket, Posix.NetinetIn, Posix.NetinetTCP,{$ENDIF}
  {$IFDEF ANDROID}UVScan.Serial.Android,{$ENDIF}
  System.Generics.Collections, System.Generics.Defaults, System.StrUtils, System.SyncObjs;

{ TTcpSerialPort }

const
  TcpConnectTimeoutMs = 5000;

type
  { A connection being made, on a thread of its own (a connect to an address
    nobody answers can take a minute or more, and cannot be cut short on
    every platform). The port takes the socket if it connects in time;
    otherwise it is left to the thread, and freed with this once both are
    done with it. }
  TTcpConnect = class(TInterfacedObject)
  public
    Socket: System.Net.Socket.TSocket;
    Error: string;
    Done: TEvent;
    constructor Create;
    destructor Destroy; override;
  end;

constructor TTcpConnect.Create;
begin
  inherited;
  Done := TEvent.Create(nil, True, False, '');
  Socket := System.Net.Socket.TSocket.Create(TSocketType.TCP);
end;

destructor TTcpConnect.Destroy;
begin
  FreeSocket(Socket); // nil once the port has it
  Done.Free;
  inherited;
end;

function ParseTcpAddress(const Address: string; out Host: string; out Port: Word): Boolean;
var
  S: string;
  I, P: Integer;
begin
  S := Trim(Address);
  if StartsText('tcp://', S) then
    Delete(S, 1, 6)
  else if StartsText('tcp:', S) then
    Delete(S, 1, 4);
  Port := DefaultTcpPort;
  I := LastDelimiter(':', S);
  if I > 0 then
  begin
    if not TryStrToInt(Trim(Copy(S, I + 1, MaxInt)), P) or (P < 1) or (P > 65535) then
      Exit(False);
    Port := P;
    S := Copy(S, 1, I - 1);
  end;
  Host := Trim(S);
  Result := (Host <> '') and (Host.IndexOfAny([' ', ':', '/']) < 0);
end;

function SocketReadable(S: System.Net.Socket.TSocket; TimeoutMs: Cardinal): Boolean;
var
  R: System.Net.Socket.TFDSet;
begin
  R := System.Net.Socket.TFDSet.Create(S);
  Result := System.Net.Socket.TSocket.Select(@R, nil, nil, Int64(TimeoutMs) * 1000) = TWaitResult.wrSignaled;
end;

procedure FreeSocket(var S: System.Net.Socket.TSocket);
begin
  if S = nil then
    Exit;
  try
    if TSocketState.Connected in S.State then
      S.Close(True);
  except
    // the handle is gone already
  end;
  FreeAndNil(S);
end;

function SocketSend(S: System.Net.Socket.TSocket; const Buf; Count: Integer): Integer;
begin
  {$IFDEF POSIX}
  {$WARN SYMBOL_PLATFORM OFF} // Linux and Android have it, which is where this runs
  Result := Posix.SysSocket.send(S.Handle, Buf, Count, MSG_NOSIGNAL);
  {$WARN SYMBOL_PLATFORM ON}
  if Result < 0 then
    raise ESerialError.CreateFmt('send failed (error %d)', [GetLastError]);
  {$ELSE}
  Result := S.Send(Buf, Count, []);
  {$ENDIF}
end;

function SocketReceive(S: System.Net.Socket.TSocket; var Buf; Count: Integer): Integer;
begin
  Result := S.Receive(Buf, Count, []);
end;

function IsTcpAddress(const Name: string): Boolean;
begin
  Result := StartsText('tcp:', Trim(Name)) or (Name.IndexOfAny(['.', ':']) >= 0);
end;

function CreatePort(const Name: string; BaudRate: Cardinal; FlowControl: TFlowControl): ISerialPort;
var
  Host: string;
  Port: Word;
begin
  if not IsTcpAddress(Name) then
    Exit(CreateSerialPort(Name, BaudRate, FlowControl));
  if not ParseTcpAddress(Name, Host, Port) then
    raise ESerialError.CreateFmt('"%s" is not a network address (host:port, e.g. 192.168.2.99:%d)',
      [Name, DefaultTcpPort]);
  Result := TTcpSerialPort.Create(Host, Port);
end;

constructor TTcpSerialPort.Create(const Host: string; Port: Word);
begin
  inherited Create;
  FHost := Host;
  FPort := Port;
end;

destructor TTcpSerialPort.Destroy;
begin
  Close;
  inherited;
end;

function TTcpSerialPort.Description: string;
begin
  Result := Format('%s:%d', [FHost, FPort]);
end;

function TTcpSerialPort.IsOpen: Boolean;
begin
  Result := FSocket <> nil;
end;

procedure TTcpSerialPort.CheckOpen;
begin
  if FSocket = nil then
    raise ESerialError.Create('The network connection is not open');
end;

procedure TTcpSerialPort.Lost(const Why: string);
begin
  Close;
  raise ESerialError.CreateFmt('Network connection to %s lost: %s', [Description, Why]);
end;

procedure TTcpSerialPort.Open;
var
  Job: TTcpConnect;
  Keep: IInterface;
  Host: string;
  Port: Word;
  Opt: Integer;
begin
  if IsOpen then
    Exit;
  Job := TTcpConnect.Create;
  Keep := Job; // the thread holds it too
  Host := FHost;
  Port := FPort;
  TThread.CreateAnonymousThread(
    procedure
    var
      Mine: IInterface;
    begin
      Mine := Keep;
      try
        Job.Socket.Connect(Host, '', '', Port);
      except
        on E: Exception do
          Job.Error := E.Message;
      end;
      Job.Done.SetEvent;
    end).Start;
  if Job.Done.WaitFor(TcpConnectTimeoutMs) <> TWaitResult.wrSignaled then
    raise ESerialError.CreateFmt('No answer from %s within %d seconds. Is the interface on, and on this network?',
      [Description, TcpConnectTimeoutMs div 1000]);
  if Job.Error <> '' then
    raise ESerialError.CreateFmt('Could not connect to %s: %s', [Description, Job.Error]);
  FSocket := Job.Socket;
  Job.Socket := nil;
  // The AVT's requests and answers are a few bytes each: send each one at
  // once rather than waiting to fill a packet (Nagle), which would add up to
  // a couple of hundred ms to every exchange.
  Opt := 1;
  {$IFDEF MSWINDOWS}
  Winapi.Winsock2.setsockopt(FSocket.Handle, IPPROTO_TCP, TCP_NODELAY, PAnsiChar(@Opt), SizeOf(Opt));
  {$ELSE}
  Posix.SysSocket.setsockopt(FSocket.Handle, IPPROTO_TCP, TCP_NODELAY, Opt, SizeOf(Opt));
  {$ENDIF}
end;

procedure TTcpSerialPort.Close;
begin
  FreeSocket(FSocket);
end;

function TTcpSerialPort.Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
begin
  CheckOpen;
  Result := 0;
  if Count <= 0 then
    Exit;
  try
    if not SocketReadable(FSocket, TimeoutMs) then
      Exit;
    Result := SocketReceive(FSocket, Buffer, Count);
  except
    on E: Exception do
      Lost(E.Message);
  end;
  if Result <= 0 then // readable with nothing to read: the other end has closed
    Lost('the interface closed it');
end;

procedure TTcpSerialPort.Write(const Data: TBytes);
var
  Sent, N: Integer;
begin
  CheckOpen;
  Sent := 0;
  while Sent < Length(Data) do
  begin
    N := 0;
    try
      N := SocketSend(FSocket, Data[Sent], Length(Data) - Sent);
    except
      on E: Exception do
        Lost(E.Message);
    end;
    if N <= 0 then
      Lost('could not send');
    Inc(Sent, N);
  end;
end;

procedure TTcpSerialPort.Purge;
var
  Scratch: array[0..1023] of Byte;
begin
  CheckOpen;
  try
    while SocketReadable(FSocket, 0) do
      if SocketReceive(FSocket, Scratch, SizeOf(Scratch)) <= 0 then
        Break; // closed: the next read says so
  except
    // the same
  end;
end;

{$IF DEFINED(MSWINDOWS)}

const
  WriteTimeoutMs = 1000;

{ TWin32SerialPort }

constructor TWin32SerialPort.Create(const PortName: string; BaudRate: Cardinal; FlowControl: TFlowControl);
begin
  inherited Create;
  FPortName := PortName;
  FBaudRate := BaudRate;
  FFlowControl := FlowControl;
  FHandle := INVALID_HANDLE_VALUE;
end;

destructor TWin32SerialPort.Destroy;
begin
  Close;
  inherited;
end;

function TWin32SerialPort.Description: string;
begin
  Result := Format('%s @ %d', [FPortName, FBaudRate]);
end;

procedure TWin32SerialPort.RaiseLastError(const Action: string);
var
  Code: DWORD;
begin
  Code := GetLastError;
  raise ESerialError.CreateFmt('%s %s failed: %s', [FPortName, Action, SysErrorMessage(Code)]);
end;

procedure TWin32SerialPort.CheckOpen;
begin
  if not IsOpen then
    raise ESerialError.CreateFmt('%s is not open', [FPortName]);
end;

function TWin32SerialPort.IsOpen: Boolean;
begin
  Result := FHandle <> INVALID_HANDLE_VALUE;
end;

procedure TWin32SerialPort.Open;
var
  DCB: TDCB;
  Timeouts: TCommTimeouts;
begin
  if IsOpen then
    Exit;
  FHandle := CreateFile(PChar('\\.\' + FPortName), GENERIC_READ or GENERIC_WRITE, 0, nil,
    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if FHandle = INVALID_HANDLE_VALUE then
    RaiseLastError('open');
  try
    if not SetupComm(FHandle, 8192, 4096) then
      RaiseLastError('SetupComm');

    FillChar(DCB, SizeOf(DCB), 0);
    DCB.DCBlength := SizeOf(DCB);
    if not GetCommState(FHandle, DCB) then
      RaiseLastError('GetCommState');
    DCB.BaudRate := FBaudRate;
    DCB.ByteSize := 8;
    DCB.Parity := NOPARITY;
    DCB.StopBits := ONESTOPBIT;
    // Flags bit layout: fBinary(0) fParity(1) fOutxCtsFlow(2) fOutxDsrFlow(3)
    // fDtrControl(4-5) fDsrSensitivity(6) fTXContinueOnXoff(7) fOutX(8) fInX(9)
    // fErrorChar(10) fNull(11) fRtsControl(12-13) fAbortOnError(14)
    DCB.Flags := $0001 or (DTR_CONTROL_ENABLE shl 4);
    if FFlowControl = fcRtsCts then
      DCB.Flags := DCB.Flags or $0004 or (RTS_CONTROL_HANDSHAKE shl 12)
    else
      DCB.Flags := DCB.Flags or (RTS_CONTROL_ENABLE shl 12);
    if not SetCommState(FHandle, DCB) then
      RaiseLastError('SetCommState');

    FillChar(Timeouts, SizeOf(Timeouts), 0);
    Timeouts.ReadIntervalTimeout := MAXDWORD;
    Timeouts.ReadTotalTimeoutMultiplier := MAXDWORD;
    Timeouts.ReadTotalTimeoutConstant := 50;
    Timeouts.WriteTotalTimeoutConstant := WriteTimeoutMs;
    if not SetCommTimeouts(FHandle, Timeouts) then
      RaiseLastError('SetCommTimeouts');
    FReadTimeout := 50;

    Purge;
  except
    Close;
    raise;
  end;
end;

procedure TWin32SerialPort.Close;
begin
  if IsOpen then
  begin
    CloseHandle(FHandle);
    FHandle := INVALID_HANDLE_VALUE;
  end;
end;

procedure TWin32SerialPort.SetReadTimeout(TimeoutMs: Cardinal);
var
  Timeouts: TCommTimeouts;
begin
  if TimeoutMs = FReadTimeout then
    Exit;
  if TimeoutMs = 0 then
    TimeoutMs := 1; // 0 would mean "wait forever" with this timeout mode
  FillChar(Timeouts, SizeOf(Timeouts), 0);
  // MAXDWORD/MAXDWORD/constant: return as soon as any byte arrives,
  // otherwise wait up to the constant.
  Timeouts.ReadIntervalTimeout := MAXDWORD;
  Timeouts.ReadTotalTimeoutMultiplier := MAXDWORD;
  Timeouts.ReadTotalTimeoutConstant := TimeoutMs;
  Timeouts.WriteTotalTimeoutConstant := WriteTimeoutMs;
  if not SetCommTimeouts(FHandle, Timeouts) then
    RaiseLastError('SetCommTimeouts');
  FReadTimeout := TimeoutMs;
end;

function TWin32SerialPort.Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
var
  BytesRead: DWORD;
begin
  CheckOpen;
  SetReadTimeout(TimeoutMs);
  if not ReadFile(FHandle, Buffer, Count, BytesRead, nil) then
    RaiseLastError('read');
  Result := BytesRead;
end;

procedure TWin32SerialPort.Write(const Data: TBytes);
var
  Written: DWORD;
begin
  CheckOpen;
  if Length(Data) = 0 then
    Exit;
  if not WriteFile(FHandle, Data[0], Length(Data), Written, nil) then
    RaiseLastError('write');
  if Integer(Written) <> Length(Data) then
    raise ESerialError.CreateFmt('%s write timed out (%d of %d bytes)', [FPortName, Written, Length(Data)]);
end;

procedure TWin32SerialPort.Purge;
begin
  if IsOpen then
    PurgeComm(FHandle, PURGE_RXCLEAR or PURGE_TXCLEAR or PURGE_RXABORT or PURGE_TXABORT);
end;

{ Port enumeration }

function PortNumber(const Name: string): Integer;
begin
  Result := StrToIntDef(Copy(Name, 4, MaxInt), MaxInt);
end;

function ListSerialPorts: TArray<string>;
var
  Reg: TRegistry;
  Names: TStringList;
  Ports: TList<string>;
  Name, Value: string;
begin
  Ports := TList<string>.Create;
  try
    Reg := TRegistry.Create(KEY_READ);
    Names := TStringList.Create;
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      if Reg.OpenKeyReadOnly('HARDWARE\DEVICEMAP\SERIALCOMM') then
      begin
        Reg.GetValueNames(Names);
        for Name in Names do
        begin
          Value := Reg.ReadString(Name);
          if (Value <> '') and not Ports.Contains(Value) then
            Ports.Add(Value);
        end;
      end;
    finally
      Names.Free;
      Reg.Free;
    end;
    Ports.Sort(TComparer<string>.Construct(
      function(const A, B: string): Integer
      begin
        Result := PortNumber(A) - PortNumber(B);
        if Result = 0 then
          Result := CompareText(A, B);
      end));
    Result := Ports.ToArray;
  finally
    Ports.Free;
  end;
end;

function CreateSerialPort(const PortName: string; BaudRate: Cardinal; FlowControl: TFlowControl): ISerialPort;
begin
  Result := TWin32SerialPort.Create(PortName, BaudRate, FlowControl);
end;

function SerialPortsSupported: Boolean;
begin
  Result := True;
end;

function SerialPortDiagnostics: TArray<string>;
begin
  Result := nil;
end;

{$ELSEIF DEFINED(ANDROID)}

function CreateSerialPort(const PortName: string; BaudRate: Cardinal; FlowControl: TFlowControl): ISerialPort;
begin
  Result := CreateUsbSerialPort(PortName, BaudRate, FlowControl);
end;

function ListSerialPorts: TArray<string>;
begin
  Result := ListUsbSerialPorts;
end;

function SerialPortsSupported: Boolean;
begin
  Result := True;
end;

function SerialPortDiagnostics: TArray<string>;
begin
  Result := DescribeUsbDevices;
end;

{$ELSE}

function CreateSerialPort(const PortName: string; BaudRate: Cardinal; FlowControl: TFlowControl): ISerialPort;
begin
  raise ESerialError.Create('Serial ports are not supported on this device yet; use the Simulator');
end;

function ListSerialPorts: TArray<string>;
begin
  Result := nil;
end;

function SerialPortsSupported: Boolean;
begin
  Result := False;
end;

function SerialPortDiagnostics: TArray<string>;
begin
  Result := nil;
end;

{$ENDIF}

end.
