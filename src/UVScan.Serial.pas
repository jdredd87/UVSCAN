unit UVScan.Serial;

{ Minimal Win32 serial port. Synchronous (non-overlapped) I/O: the port is
  owned and used by exactly one thread (the scan engine), so no locking. }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes;

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

{ COM port names present on this machine, e.g. ['COM1', 'COM6'], in numeric order. }
function ListSerialPorts: TArray<string>;

implementation

uses
  System.Win.Registry, System.Generics.Collections, System.Generics.Defaults;

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

end.
