unit UVScan.Bluetooth.Android;

{ Classic Bluetooth serial adapters on Android (the Serial Port Profile, an
  RFCOMM socket), as an ISerialPort: an ELM327 type adapter. The adapter is
  paired in Android's Bluetooth settings first; ListBluetoothPorts names the
  paired devices.

  Port names look like 'BT vLinker FD [56:27:07:3C:EE:C7]': the address in
  brackets is what Open goes by, the name is for people.

  Android 12 and later ask for the "Nearby devices" permission
  (BLUETOOTH_CONNECT) at run time: the first Open asks, and the user
  connects again once allowed, as with USB permission.

  Open/Write run on whichever thread calls them; receiving has a thread of
  its own blocked in the socket's InputStream.read, and Read takes from what
  it has collected (as the USB reader does). Close closes the socket, which
  ends the blocked read. }

interface

{$IFDEF ANDROID}

uses
  System.SysUtils, UVScan.Serial;

const
  BluetoothPortPrefix = 'BT ';

{ The paired Bluetooth devices, as port names. Empty when Bluetooth is off,
  missing or not allowed yet. }
function ListBluetoothPorts: TArray<string>;
{ True for a name from ListBluetoothPorts. }
function IsBluetoothPort(const Name: string): Boolean;
{ Port for a name from ListBluetoothPorts (not opened yet). }
function CreateBluetoothPort(const PortName: string): ISerialPort;
{ Why ListBluetoothPorts is empty, or '' when it need not be. }
function BluetoothDiagnostics: string;

{$ENDIF}

implementation

{$IFDEF ANDROID}

uses
  System.Classes, System.Math, System.SyncObjs,
  Androidapi.JNI, Androidapi.JNIBridge, Androidapi.JNI.JavaTypes, Androidapi.JNI.GraphicsContentViewText,
  Androidapi.JNI.App, Androidapi.JNI.Os, Androidapi.JNI.Bluetooth, Androidapi.Helpers;

const
  SppUuid = '00001101-0000-1000-8000-00805F9B34FB'; // Serial Port Profile
  PermissionConnect = 'android.permission.BLUETOOTH_CONNECT';
  ReadChunk = 1024;

type
  TBluetoothSerialPort = class;

  { Blocks in InputStream.read and hands what arrives to the port. }
  TBtReader = class(TThread)
  private
    FPort: TBluetoothSerialPort;
    FInput: JInputStream;
  protected
    procedure Execute; override;
  public
    constructor Create(Port: TBluetoothSerialPort; Input: JInputStream);
  end;

  TBluetoothSerialPort = class(TInterfacedObject, ISerialPort)
  private
    FPortName: string;
    FAddress: string;
    FSocket: JBluetoothSocket;
    FOutput: JOutputStream;
    FJavaOut: TJavaArray<Byte>;
    FReader: TBtReader;
    FRxLock: TCriticalSection;
    FRxReady: TEvent;
    FPending: TBytes;
    FPendingPos: Integer;
    FLost: Boolean;
    procedure CheckOpen;
    procedure Received(const Data: TBytes);
    procedure DropReceived;
  public
    constructor Create(const PortName: string);
    destructor Destroy; override;
    procedure Open;
    procedure Close;
    function IsOpen: Boolean;
    function Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
    procedure Write(const Data: TBytes);
    procedure Purge;
    function Description: string;
  end;

{ Helpers }

function NeedsConnectPermission: Boolean;
begin
  Result := (TJBuild_VERSION.JavaClass.SDK_INT >= 31) and
    (TAndroidHelper.Context.checkSelfPermission(StringToJString(PermissionConnect)) <>
     TJPackageManager.JavaClass.PERMISSION_GRANTED);
end;

procedure AskConnectPermission;
var
  Perms: TJavaObjectArray<JString>;
begin
  Perms := TJavaObjectArray<JString>.Create(1);
  try
    Perms.Items[0] := StringToJString(PermissionConnect);
    TAndroidHelper.Activity.requestPermissions(Perms, 0);
  finally
    Perms.Free;
  end;
end;

function Adapter: JBluetoothAdapter;
begin
  Result := TJBluetoothAdapter.JavaClass.getDefaultAdapter;
end;

function PairedDevices: TArray<JBluetoothDevice>;
var
  A: JBluetoothAdapter;
  Bonded: JSet;
  It: JIterator;
begin
  Result := nil;
  A := Adapter;
  if (A = nil) or not A.isEnabled or NeedsConnectPermission then
    Exit;
  Bonded := A.getBondedDevices;
  if Bonded = nil then
    Exit;
  It := Bonded.iterator;
  while It.hasNext do
    Result := Result + [TJBluetoothDevice.Wrap(It.next)];
end;

function PortNameOf(D: JBluetoothDevice): string;
var
  Name: string;
begin
  Name := JStringToString(D.getName).Trim;
  if Name = '' then
    Name := 'Bluetooth device';
  Result := Format('%s%s [%s]', [BluetoothPortPrefix, Name, JStringToString(D.getAddress)]);
end;

function AddressOf(const PortName: string): string;
var
  L, R: Integer;
begin
  L := PortName.LastIndexOf('[');
  R := PortName.LastIndexOf(']');
  if (L < 0) or (R < L) then
    Exit('');
  Result := PortName.Substring(L + 1, R - L - 1).Trim.ToUpper;
end;

function ListBluetoothPorts: TArray<string>;
var
  D: JBluetoothDevice;
begin
  Result := nil;
  try
    for D in PairedDevices do
      Result := Result + [PortNameOf(D)];
  except
    Result := nil;
  end;
end;

function IsBluetoothPort(const Name: string): Boolean;
begin
  Result := Name.StartsWith(BluetoothPortPrefix) and (AddressOf(Name) <> '');
end;

function CreateBluetoothPort(const PortName: string): ISerialPort;
begin
  Result := TBluetoothSerialPort.Create(PortName);
end;

function BluetoothDiagnostics: string;
var
  A: JBluetoothAdapter;
begin
  try
    A := Adapter;
    if A = nil then
      Exit('This device has no Bluetooth');
    if NeedsConnectPermission then
      Exit('Bluetooth permission (Nearby devices) not allowed yet');
    if not A.isEnabled then
      Exit('Bluetooth is off');
    if Length(PairedDevices) = 0 then
      Exit('No paired Bluetooth devices - pair the adapter in Android''s Bluetooth settings');
    Result := '';
  except
    on E: Exception do
      Result := 'Bluetooth not available: ' + E.Message;
  end;
end;

{ TBluetoothSerialPort }

constructor TBluetoothSerialPort.Create(const PortName: string);
begin
  inherited Create;
  FPortName := PortName;
  FAddress := AddressOf(PortName);
  FRxLock := TCriticalSection.Create;
  FRxReady := TEvent.Create(nil, True, False, '');
end;

destructor TBluetoothSerialPort.Destroy;
begin
  Close;
  FRxReady.Free;
  FRxLock.Free;
  inherited;
end;

function TBluetoothSerialPort.Description: string;
begin
  Result := FPortName;
end;

function TBluetoothSerialPort.IsOpen: Boolean;
begin
  Result := FSocket <> nil;
end;

procedure TBluetoothSerialPort.CheckOpen;
begin
  if not IsOpen then
    raise ESerialError.CreateFmt('%s is not open', [FPortName]);
  if FLost then
    raise ESerialError.CreateFmt('%s: the Bluetooth connection was lost', [FPortName]);
end;

procedure TBluetoothSerialPort.Open;
var
  A: JBluetoothAdapter;
  Device: JBluetoothDevice;
  D: JBluetoothDevice;
  Uuid: JUUID;
begin
  if IsOpen then
    Exit;
  if FAddress = '' then
    raise ESerialError.CreateFmt('%s is not a Bluetooth device', [FPortName]);
  try
    A := Adapter;
    if A = nil then
      raise ESerialError.Create('This device has no Bluetooth');
    if NeedsConnectPermission then
    begin
      AskConnectPermission;
      raise ESerialError.Create('Bluetooth permission needed - allow UVScan to connect to nearby devices, then connect again');
    end;
    if not A.isEnabled then
      raise ESerialError.Create('Bluetooth is off - turn it on, then connect again');
    Device := nil;
    for D in PairedDevices do
      if SameText(JStringToString(D.getAddress), FAddress) then
        Device := D;
    if Device = nil then
      raise ESerialError.CreateFmt('%s is not paired any more', [FPortName]);
    // Discovery slows a connection down a lot.
    A.cancelDiscovery;
    Uuid := TJUUID.JavaClass.fromString(StringToJString(SppUuid));
    FLost := False;
    try
      FSocket := Device.createRfcommSocketToServiceRecord(Uuid);
      FSocket.connect;
    except
      // Some adapters only take an unauthenticated (insecure) connection.
      FSocket := nil;
      FSocket := Device.createInsecureRfcommSocketToServiceRecord(Uuid);
      FSocket.connect;
    end;
    try
      FOutput := FSocket.getOutputStream;
      FJavaOut := TJavaArray<Byte>.Create(ReadChunk);
      DropReceived;
      FReader := TBtReader.Create(Self, FSocket.getInputStream);
    except
      Close;
      raise;
    end;
  except
    on E: ESerialError do
    begin
      FSocket := nil;
      raise;
    end;
    on E: Exception do
    begin
      FSocket := nil;
      raise ESerialError.CreateFmt('%s: could not connect (is it on and in range?): %s', [FPortName, E.Message]);
    end;
  end;
end;

procedure TBluetoothSerialPort.Close;
begin
  if FSocket <> nil then
    try
      FSocket.close; // ends the reader's blocked read
    except
      // already gone
    end;
  if FReader <> nil then
  begin
    FReader.Terminate;
    FReader.WaitFor;
    FreeAndNil(FReader);
  end;
  FSocket := nil;
  FOutput := nil;
  FreeAndNil(FJavaOut);
  DropReceived;
end;

procedure TBluetoothSerialPort.Received(const Data: TBytes);
begin
  if Length(Data) = 0 then
    Exit;
  FRxLock.Enter;
  try
    if FPendingPos >= Length(FPending) then
      FPending := Data
    else
      FPending := Copy(FPending, FPendingPos, MaxInt) + Data;
    FPendingPos := 0;
    FRxReady.SetEvent;
  finally
    FRxLock.Leave;
  end;
end;

procedure TBluetoothSerialPort.DropReceived;
begin
  FRxLock.Enter;
  try
    FPending := nil;
    FPendingPos := 0;
    FRxReady.ResetEvent;
  finally
    FRxLock.Leave;
  end;
end;

function TBluetoothSerialPort.Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
var
  Deadline, Now_: UInt64;
begin
  if not IsOpen then
    raise ESerialError.CreateFmt('%s is not open', [FPortName]);
  Result := 0;
  if Count <= 0 then
    Exit;
  Deadline := TThread.GetTickCount64 + TimeoutMs;
  repeat
    FRxLock.Enter;
    try
      if FPendingPos < Length(FPending) then
      begin
        Result := Min(Count, Length(FPending) - FPendingPos);
        Move(FPending[FPendingPos], Buffer, Result);
        Inc(FPendingPos, Result);
        if FPendingPos >= Length(FPending) then
        begin
          FPending := nil;
          FPendingPos := 0;
          FRxReady.ResetEvent;
        end;
        Exit;
      end;
    finally
      FRxLock.Leave;
    end;
    if FLost then
      raise ESerialError.CreateFmt('%s: the Bluetooth connection was lost', [FPortName]);
    Now_ := TThread.GetTickCount64;
    if Now_ >= Deadline then
      Exit;
    FRxReady.WaitFor(Cardinal(Deadline - Now_));
  until False;
end;

procedure TBluetoothSerialPort.Write(const Data: TBytes);
var
  Pos, Chunk: Integer;
  Env: PJNIEnv;
begin
  CheckOpen;
  Pos := 0;
  Env := TJNIResolver.GetJNIEnv;
  try
    while Pos < Length(Data) do
    begin
      Chunk := Min(ReadChunk, Length(Data) - Pos);
      Env^.SetByteArrayRegion(Env, FJavaOut.ToPointer, 0, Chunk, PJNIByte(@Data[Pos]));
      FOutput.write(FJavaOut, 0, Chunk);
      Inc(Pos, Chunk);
    end;
    FOutput.flush;
  except
    on E: Exception do
    begin
      FLost := True;
      raise ESerialError.CreateFmt('%s write failed (out of range or off?): %s', [FPortName, E.Message]);
    end;
  end;
end;

procedure TBluetoothSerialPort.Purge;
begin
  // Nothing to flush on the adapter's side: drop what has arrived, after
  // letting anything on its way in land first.
  DropReceived;
  if IsOpen then
  begin
    Sleep(20);
    DropReceived;
  end;
end;

{ TBtReader }

constructor TBtReader.Create(Port: TBluetoothSerialPort; Input: JInputStream);
begin
  FPort := Port;
  FInput := Input;
  inherited Create(False);
end;

procedure TBtReader.Execute;
var
  Arr: TJavaArray<Byte>;
  N: Integer;
  Raw: TBytes;
  Env: PJNIEnv;
begin
  Arr := TJavaArray<Byte>.Create(ReadChunk);
  try
    Env := TJNIResolver.GetJNIEnv;
    try
      while not Terminated do
      begin
        N := FInput.read(Arr, 0, ReadChunk);
        if N < 0 then
          Break; // closed by the adapter
        if N > 0 then
        begin
          SetLength(Raw, N);
          Env^.GetByteArrayRegion(Env, Arr.ToPointer, 0, N, PJNIByte(@Raw[0]));
          FPort.Received(Raw);
        end;
      end;
    except
      // the socket was closed (Close, or the adapter went away)
    end;
    if not Terminated then
      FPort.FLost := True;
  finally
    FInput := nil;
    Arr.Free;
  end;
end;

{$ENDIF}

end.
