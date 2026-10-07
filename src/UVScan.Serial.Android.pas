unit UVScan.Serial.Android;

{ USB serial adapters on Android (USB host / OTG), as an ISerialPort.

  Android has no COM ports: a USB serial chip is driven directly through
  android.hardware.usb (control transfers to set it up, bulk transfers for
  the data). Supported chips, following the protocol details of the
  open-source usb-serial-for-android library:
    - FTDI (VID 0403): FT232R/BM, FT2232, FT4232, FT232H, FT-X
    - Silicon Labs CP210x (VID 10C4)
    - WCH CH340 / CH341 (VID 1A86) - no hardware flow control
    - any CDC-ACM device (USB class 2 + data class 10)
  Port names look like 'USB FTDI 0403:6001'.

  The first Open of a device asks Android for permission; the user answers
  in a system dialog and connects again. (A device_filter.xml in the app's
  manifest lets Android offer UVScan when the adapter is plugged in, which
  grants the permission up front.)

  Everything here runs on whichever thread calls it (the scan engine for
  Open/Read/Write); the JNI bridge attaches that thread to the Java VM. }

interface

{$IFDEF ANDROID}

uses
  System.SysUtils, UVScan.Serial;

{ Names of the attached USB serial adapters UVScan can drive. }
function ListUsbSerialPorts: TArray<string>;
{ Port for a name from ListUsbSerialPorts (not opened yet). }
function CreateUsbSerialPort(const PortName: string; BaudRate: Cardinal; FlowControl: TFlowControl): ISerialPort;
{ Every attached USB device with its ids and whether UVScan can drive it,
  for the Messages tab when an adapter does not show up. }
function DescribeUsbDevices: TArray<string>;

{$ENDIF}

implementation

{$IFDEF ANDROID}

uses
  System.Classes, System.Math, System.StrUtils,
  Androidapi.JNI, Androidapi.JNIBridge, Androidapi.JNI.JavaTypes, Androidapi.JNI.GraphicsContentViewText,
  Androidapi.JNI.App, Androidapi.JNI.Os, Androidapi.Helpers;

{ android.hardware.usb imports (not in the RTL) }

type
  JUsbEndpoint = interface;
  JUsbInterface = interface;
  JUsbDevice = interface;
  JUsbDeviceConnection = interface;
  JUsbManager = interface;

  JUsbEndpointClass = interface(JObjectClass)
    ['{ED22A523-A782-47C9-A0F7-F4CC6C857221}']
  end;

  [JavaSignature('android/hardware/usb/UsbEndpoint')]
  JUsbEndpoint = interface(JObject)
    ['{26AB0F06-49C8-422A-B99C-9B7958D3FAD2}']
    function getAddress: Integer; cdecl;
    function getDirection: Integer; cdecl;
    function getType: Integer; cdecl;
    function getMaxPacketSize: Integer; cdecl;
  end;
  TJUsbEndpoint = class(TJavaGenericImport<JUsbEndpointClass, JUsbEndpoint>) end;

  JUsbInterfaceClass = interface(JObjectClass)
    ['{FC49C931-2592-462F-BE4A-02FA4B38A09A}']
  end;

  [JavaSignature('android/hardware/usb/UsbInterface')]
  JUsbInterface = interface(JObject)
    ['{09950EAB-33EB-4282-B338-8A20E506C29F}']
    function getId: Integer; cdecl;
    function getInterfaceClass: Integer; cdecl;
    function getInterfaceSubclass: Integer; cdecl;
    function getEndpointCount: Integer; cdecl;
    function getEndpoint(index: Integer): JUsbEndpoint; cdecl;
  end;
  TJUsbInterface = class(TJavaGenericImport<JUsbInterfaceClass, JUsbInterface>) end;

  JUsbDeviceClass = interface(JObjectClass)
    ['{CC8CA332-E1B1-47D4-9DA4-A9D48015A7B7}']
  end;

  [JavaSignature('android/hardware/usb/UsbDevice')]
  JUsbDevice = interface(JObject)
    ['{0E5C61CE-76A8-4549-84FB-7F6D63714AE8}']
    function getDeviceName: JString; cdecl;
    function getVendorId: Integer; cdecl;
    function getProductId: Integer; cdecl;
    function getDeviceClass: Integer; cdecl;
    function getInterfaceCount: Integer; cdecl;
    function getInterface(index: Integer): JUsbInterface; cdecl;
  end;
  TJUsbDevice = class(TJavaGenericImport<JUsbDeviceClass, JUsbDevice>) end;

  JUsbDeviceConnectionClass = interface(JObjectClass)
    ['{435D1FE8-A62A-4CAF-A5CE-234EDB3BDC75}']
  end;

  [JavaSignature('android/hardware/usb/UsbDeviceConnection')]
  JUsbDeviceConnection = interface(JObject)
    ['{1AAF688C-EBA0-4008-B6B1-AC4B892A566C}']
    function claimInterface(intf: JUsbInterface; force: Boolean): Boolean; cdecl;
    function releaseInterface(intf: JUsbInterface): Boolean; cdecl;
    procedure close; cdecl;
    function controlTransfer(requestType, request, value, index: Integer; buffer: TJavaArray<Byte>;
      length, timeout: Integer): Integer; cdecl;
    function bulkTransfer(endpoint: JUsbEndpoint; buffer: TJavaArray<Byte>; offset, length,
      timeout: Integer): Integer; cdecl;
  end;
  TJUsbDeviceConnection = class(TJavaGenericImport<JUsbDeviceConnectionClass, JUsbDeviceConnection>) end;

  JUsbManagerClass = interface(JObjectClass)
    ['{6F90CF32-E24E-471F-ACAC-F7CBBCC30751}']
  end;

  [JavaSignature('android/hardware/usb/UsbManager')]
  JUsbManager = interface(JObject)
    ['{E9FA1448-95F3-4E91-AD48-955F24007F2F}']
    function getDeviceList: JHashMap; cdecl;
    function hasPermission(device: JUsbDevice): Boolean; cdecl;
    procedure requestPermission(device: JUsbDevice; pi: JPendingIntent); cdecl;
    function openDevice(device: JUsbDevice): JUsbDeviceConnection; cdecl;
  end;
  TJUsbManager = class(TJavaGenericImport<JUsbManagerClass, JUsbManager>) end;

const
  // android.hardware.usb.UsbConstants
  USB_DIR_IN = $80;
  USB_ENDPOINT_XFER_BULK = 2;
  USB_CLASS_COMM = 2;
  USB_CLASS_CDC_DATA = $0A;

  ActionUsbPermission = 'com.uvscan.USB_PERMISSION';
  ControlTimeoutMs = 1000;
  WriteTimeoutMs = 1000;
  JavaBufferSize = 16384;

type
  TUsbDriver = (udNone, udFtdi, udCp210x, udCh34x, udCdcAcm);

const
  DriverNames: array[TUsbDriver] of string = ('', 'FTDI', 'CP210x', 'CH34x', 'CDC');

type
  TAndroidUsbSerialPort = class(TInterfacedObject, ISerialPort)
  private
    FPortName: string;
    FBaudRate: Cardinal;
    FFlowControl: TFlowControl;
    FDriver: TUsbDriver;
    FDevice: JUsbDevice;
    FConn: JUsbDeviceConnection;
    FControlIntf, FDataIntf: JUsbInterface;
    FEpIn, FEpOut: JUsbEndpoint;
    FInPacket: Integer;         // max packet size of the IN endpoint
    FPortIndex: Integer;        // FTDI: interface number + 1
    FMultiPort: Boolean;        // FTDI chip with more than one port
    FJavaIn, FJavaOut: TJavaArray<Byte>;
    FPending: TBytes;           // received but not yet handed to Read
    FPendingPos: Integer;
    procedure CheckOpen;
    procedure Control(RequestType, Request, Value, Index: Integer; const Data: TBytes = nil);
    function ControlIn(Request, Value, Index, Len: Integer): Integer;
    procedure FindBulkEndpoints(Intf: JUsbInterface);
    procedure SetupFtdi;
    procedure SetupCp210x;
    procedure SetupCh34x;
    procedure SetupCdcAcm;
    function BulkRead(TimeoutMs: Integer): Integer;
    procedure ReleaseAll;
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

{ Helpers }

function UsbManager: JUsbManager;
var
  Obj: JObject;
begin
  Obj := TAndroidHelper.Context.getSystemService(TJContext.JavaClass.USB_SERVICE);
  if Obj = nil then
    raise ESerialError.Create('This device has no USB host support');
  Result := TJUsbManager.Wrap(Obj);
end;

function AttachedDevices: TArray<JUsbDevice>;
var
  Map: JHashMap;
  It: JIterator;
begin
  Result := nil;
  Map := UsbManager.getDeviceList;
  if Map = nil then
    Exit;
  It := Map.values.iterator;
  while It.hasNext do
    Result := Result + [TJUsbDevice.Wrap(It.next)];
end;

function IsCdcAcm(Device: JUsbDevice): Boolean;
var
  I: Integer;
  HasComm, HasData: Boolean;
begin
  HasComm := Device.getDeviceClass = USB_CLASS_COMM;
  HasData := False;
  for I := 0 to Device.getInterfaceCount - 1 do
    case Device.getInterface(I).getInterfaceClass of
      USB_CLASS_COMM: HasComm := True;
      USB_CLASS_CDC_DATA: HasData := True;
    end;
  Result := HasComm and HasData;
end;

function DriverFor(Device: JUsbDevice): TUsbDriver;
var
  Vid, Pid: Integer;
begin
  Vid := Device.getVendorId;
  Pid := Device.getProductId;
  case Vid of
    $0403:
      Result := udFtdi; // FT232R/BM 6001, FT2232 6010, FT4232 6011, FT232H 6014, FT-X 6015, custom PIDs
    $10C4:
      if (Pid = $EA60) or (Pid = $EA61) or (Pid = $EA70) or (Pid = $EA71) or (Pid = $EA80) then
        Result := udCp210x
      else
        Result := udNone;
    $1A86:
      if (Pid = $7523) or (Pid = $5523) or (Pid = $7522) then
        Result := udCh34x
      else
        Result := udNone;
  else
    Result := udNone;
  end;
  if (Result = udNone) and IsCdcAcm(Device) then
    Result := udCdcAcm;
end;

function BaseName(Device: JUsbDevice; Driver: TUsbDriver): string;
begin
  Result := Format('USB %s %.4x:%.4x', [DriverNames[Driver], Device.getVendorId, Device.getProductId]);
end;

{ Supported devices with their port names; identical adapters get #2, #3. }
procedure EnumeratePorts(out Names: TArray<string>; out Devices: TArray<JUsbDevice>);
var
  D: JUsbDevice;
  Drv: TUsbDriver;
  Name, Base: string;
  N, I: Integer;
  Taken: Boolean;
begin
  Names := nil;
  Devices := nil;
  for D in AttachedDevices do
  begin
    Drv := DriverFor(D);
    if Drv = udNone then
      Continue;
    Base := BaseName(D, Drv);
    Name := Base;
    N := 1;
    repeat
      Taken := False;
      for I := 0 to High(Names) do
        Taken := Taken or SameText(Names[I], Name);
      if Taken then
      begin
        Inc(N);
        Name := Format('%s #%d', [Base, N]);
      end;
    until not Taken;
    Names := Names + [Name];
    Devices := Devices + [D];
  end;
end;

function ListUsbSerialPorts: TArray<string>;
var
  Devices: TArray<JUsbDevice>;
begin
  try
    EnumeratePorts(Result, Devices);
  except
    Result := nil; // no USB host on this device
  end;
end;

function DescribeUsbDevices: TArray<string>;
var
  D: JUsbDevice;
  Drv: TUsbDriver;
  S: string;
  Mgr: JUsbManager;
begin
  Result := nil;
  try
    Mgr := UsbManager;
    for D in AttachedDevices do
    begin
      Drv := DriverFor(D);
      S := Format('%s  %.4x:%.4x  class %d, %d interface(s)', [JStringToString(D.getDeviceName), D.getVendorId,
        D.getProductId, D.getDeviceClass, D.getInterfaceCount]);
      if Drv = udNone then
        S := S + '  - not a supported serial adapter'
      else
        S := S + '  - ' + DriverNames[Drv] + IfThen(Mgr.hasPermission(D), '', ' (permission not granted yet)');
      Result := Result + [S];
    end;
    if Result = nil then
      Result := ['No USB devices attached (an OTG adapter is needed between the phone and the cable)'];
  except
    on E: Exception do
      Result := ['USB host not available: ' + E.Message];
  end;
end;

function CreateUsbSerialPort(const PortName: string; BaudRate: Cardinal; FlowControl: TFlowControl): ISerialPort;
begin
  Result := TAndroidUsbSerialPort.Create(PortName, BaudRate, FlowControl);
end;

procedure RequestPermission(Device: JUsbDevice);
var
  Intent: JIntent;
  Flags: Integer;
  PI: JPendingIntent;
begin
  Intent := TJIntent.JavaClass.init(StringToJString(ActionUsbPermission));
  Intent.setPackage(TAndroidHelper.Context.getPackageName);
  Flags := 0;
  if TJBuild_VERSION.JavaClass.SDK_INT >= 23 then
    Flags := $04000000; // PendingIntent.FLAG_IMMUTABLE (required from Android 12)
  PI := TJPendingIntent.JavaClass.getBroadcast(TAndroidHelper.Context, 0, Intent, Flags);
  UsbManager.requestPermission(Device, PI);
end;

{ TAndroidUsbSerialPort }

constructor TAndroidUsbSerialPort.Create(const PortName: string; BaudRate: Cardinal; FlowControl: TFlowControl);
begin
  inherited Create;
  FPortName := PortName;
  FBaudRate := BaudRate;
  FFlowControl := FlowControl;
end;

destructor TAndroidUsbSerialPort.Destroy;
begin
  Close;
  inherited;
end;

function TAndroidUsbSerialPort.Description: string;
begin
  Result := Format('%s @ %d', [FPortName, FBaudRate]);
end;

function TAndroidUsbSerialPort.IsOpen: Boolean;
begin
  Result := FConn <> nil;
end;

procedure TAndroidUsbSerialPort.CheckOpen;
begin
  if not IsOpen then
    raise ESerialError.CreateFmt('%s is not open', [FPortName]);
end;

procedure TAndroidUsbSerialPort.Control(RequestType, Request, Value, Index: Integer; const Data: TBytes);
var
  Arr: TJavaArray<Byte>;
  Env: PJNIEnv;
  R: Integer;
begin
  Arr := nil;
  try
    if Length(Data) > 0 then
    begin
      Arr := TJavaArray<Byte>.Create(Length(Data));
      Env := TJNIResolver.GetJNIEnv;
      Env^.SetByteArrayRegion(Env, Arr.ToPointer, 0, Length(Data), PJNIByte(@Data[0]));
    end;
    R := FConn.controlTransfer(RequestType, Request, Value, Index, Arr, Length(Data), ControlTimeoutMs);
  finally
    Arr.Free;
  end;
  if R < 0 then
    raise ESerialError.CreateFmt('%s: USB control request $%.2x failed', [FPortName, Request]);
end;

{ Vendor IN request (CH34x status reads); the answer itself is not needed. }
function TAndroidUsbSerialPort.ControlIn(Request, Value, Index, Len: Integer): Integer;
var
  Arr: TJavaArray<Byte>;
begin
  Arr := TJavaArray<Byte>.Create(Len);
  try
    Result := FConn.controlTransfer($C0, Request, Value, Index, Arr, Len, ControlTimeoutMs);
  finally
    Arr.Free;
  end;
  if Result < 0 then
    raise ESerialError.CreateFmt('%s: USB status request $%.2x failed', [FPortName, Request]);
end;

procedure TAndroidUsbSerialPort.FindBulkEndpoints(Intf: JUsbInterface);
var
  I: Integer;
  Ep: JUsbEndpoint;
begin
  for I := 0 to Intf.getEndpointCount - 1 do
  begin
    Ep := Intf.getEndpoint(I);
    if Ep.getType <> USB_ENDPOINT_XFER_BULK then
      Continue;
    if Ep.getDirection = USB_DIR_IN then
    begin
      if FEpIn = nil then
        FEpIn := Ep;
    end
    else if FEpOut = nil then
      FEpOut := Ep;
  end;
end;

procedure TAndroidUsbSerialPort.Open;
var
  Names: TArray<string>;
  Devices: TArray<JUsbDevice>;
  I: Integer;
  Mgr: JUsbManager;
begin
  if IsOpen then
    Exit;
  try
    EnumeratePorts(Names, Devices);
    FDevice := nil;
    for I := 0 to High(Names) do
      if SameText(Names[I], FPortName) then
        FDevice := Devices[I];
    // Plugged into another socket or hub since: the same kind of adapter will do.
    if (FDevice = nil) and (Length(Names) > 0) then
      for I := 0 to High(Names) do
        if (FDevice = nil) and FPortName.StartsWith(Names[I].Split([' #'])[0]) then
          FDevice := Devices[I];
    if FDevice = nil then
      raise ESerialError.CreateFmt('%s is not plugged in', [FPortName]);
    FDriver := DriverFor(FDevice);
    Mgr := UsbManager;
    if not Mgr.hasPermission(FDevice) then
    begin
      RequestPermission(FDevice);
      raise ESerialError.Create('USB permission needed - allow UVScan to use the device, then connect again');
    end;
    FConn := Mgr.openDevice(FDevice);
    if FConn = nil then
      raise ESerialError.CreateFmt('%s could not be opened', [FPortName]);
    try
      case FDriver of
        udFtdi: SetupFtdi;
        udCp210x: SetupCp210x;
        udCh34x: SetupCh34x;
        udCdcAcm: SetupCdcAcm;
      end;
      if (FEpIn = nil) or (FEpOut = nil) then
        raise ESerialError.CreateFmt('%s: no bulk data endpoints found', [FPortName]);
      FInPacket := Max(8, FEpIn.getMaxPacketSize);
      FJavaIn := TJavaArray<Byte>.Create(JavaBufferSize);
      FJavaOut := TJavaArray<Byte>.Create(JavaBufferSize);
      FPending := nil;
      FPendingPos := 0;
      Purge;
    except
      Close;
      raise;
    end;
  except
    on E: ESerialError do
      raise;
    on E: Exception do
      raise ESerialError.CreateFmt('%s: %s', [FPortName, E.Message]);
  end;
end;

{ FTDI: vendor requests to the device, index = port number (A = 1). }
procedure TAndroidUsbSerialPort.SetupFtdi;
const
  ReqOut = $40;
  RESET_REQUEST = 0;
  MODEM_CONTROL_REQUEST = 1;
  SET_FLOW_CONTROL_REQUEST = 2;
  SET_BAUD_RATE_REQUEST = 3;
  SET_DATA_REQUEST = 4;
  SET_LATENCY_TIMER_REQUEST = 9;
  RESET_ALL = 0;
  SIO_RTS_CTS_HS = $0100;     // high byte of the index
  DTR_ON = $0101;
  RTS_ON = $0202;
  DATA_8N1 = $0008;           // 8 data bits, no parity, 1 stop bit
  LatencyMs = 4;              // send what arrived after this long (default 16)
var
  Divisor, Sub, Value, Index, Baud: Integer;
begin
  FControlIntf := FDevice.getInterface(0);
  if not FConn.claimInterface(FControlIntf, True) then
    raise ESerialError.CreateFmt('%s: could not claim the USB interface', [FPortName]);
  FDataIntf := FControlIntf;
  FPortIndex := FControlIntf.getId + 1;
  FMultiPort := FDevice.getInterfaceCount > 1;
  FindBulkEndpoints(FControlIntf);

  Control(ReqOut, RESET_REQUEST, RESET_ALL, FPortIndex);

  // Baud rate: 3 MHz / (divisor + n/8). 115200 -> divisor 26, value $001A.
  Baud := FBaudRate;
  if Baud >= 2500000 then
  begin
    Divisor := 0;
    Sub := 0;
  end
  else if Baud >= 1750000 then
  begin
    Divisor := 1;
    Sub := 0;
  end
  else
  begin
    Divisor := (24000000 shl 1) div Baud;
    Divisor := (Divisor + 1) shr 1; // round
    Sub := Divisor and 7;
    Divisor := Divisor shr 3;
    if Divisor > $3FFF then
      raise ESerialError.CreateFmt('%s: baud rate %d is too low', [FPortName, Baud]);
  end;
  Value := Divisor;
  Index := 0;
  case Sub of
    4: Value := Value or $4000;                       // 0.5
    2: Value := Value or $8000;                       // 0.25
    1: Value := Value or $C000;                       // 0.125
    3: Index := 1;                                    // 0.375
    5: begin Value := Value or $4000; Index := 1; end; // 0.625
    6: begin Value := Value or $8000; Index := 1; end; // 0.75
    7: begin Value := Value or $C000; Index := 1; end; // 0.875
  end;
  if FMultiPort then
    Index := (Index shl 8) or FPortIndex;
  Control(ReqOut, SET_BAUD_RATE_REQUEST, Value, Index);

  Control(ReqOut, SET_DATA_REQUEST, DATA_8N1, FPortIndex);
  if FFlowControl = fcRtsCts then
    Control(ReqOut, SET_FLOW_CONTROL_REQUEST, 0, SIO_RTS_CTS_HS or FPortIndex)
  else
    Control(ReqOut, SET_FLOW_CONTROL_REQUEST, 0, FPortIndex);
  Control(ReqOut, MODEM_CONTROL_REQUEST, DTR_ON, FPortIndex);
  Control(ReqOut, MODEM_CONTROL_REQUEST, RTS_ON, FPortIndex);
  Control(ReqOut, SET_LATENCY_TIMER_REQUEST, LatencyMs, FPortIndex);
end;

{ Silicon Labs CP210x: vendor requests to the interface. }
procedure TAndroidUsbSerialPort.SetupCp210x;
const
  ReqOut = $41;
  IFC_ENABLE = $00;
  SET_LINE_CTL = $03;
  SET_MHS = $07;
  SET_BAUDRATE = $1E;
  SET_FLOW = $13;
  UART_ENABLE = $0001;
  LINE_8N1 = $0800;           // data bits << 8 | parity << 4 | stop bits
  DTR_RTS_ON = $0303;         // write DTR + RTS, both high
var
  Intf: Integer;
  Flow: TBytes;
  Handshake, Replace: Cardinal;
begin
  FControlIntf := FDevice.getInterface(0);
  if not FConn.claimInterface(FControlIntf, True) then
    raise ESerialError.CreateFmt('%s: could not claim the USB interface', [FPortName]);
  FDataIntf := FControlIntf;
  FindBulkEndpoints(FControlIntf);
  Intf := FControlIntf.getId;
  Control(ReqOut, IFC_ENABLE, UART_ENABLE, Intf);
  Control(ReqOut, SET_BAUDRATE, 0, Intf, [Byte(FBaudRate), Byte(FBaudRate shr 8), Byte(FBaudRate shr 16),
    Byte(FBaudRate shr 24)]);
  Control(ReqOut, SET_LINE_CTL, LINE_8N1, Intf);
  // Flow control block: ulControlHandshake, ulFlowReplace, ulXonLimit, ulXoffLimit (little endian).
  Handshake := $01;           // DTR held active
  if FFlowControl = fcRtsCts then
  begin
    Handshake := Handshake or $08; // CTS handshake
    Replace := $80;                // RTS handshake
  end
  else
    Replace := $40;                // RTS held active
  SetLength(Flow, 16);
  FillChar(Flow[0], 16, 0);
  Move(Handshake, Flow[0], 4);
  Move(Replace, Flow[4], 4);
  Control(ReqOut, SET_FLOW, 0, Intf, Flow);
  if FFlowControl <> fcRtsCts then
    Control(ReqOut, SET_MHS, DTR_RTS_ON, Intf);
end;

{ WCH CH340 / CH341: vendor requests, register writes. }
procedure TAndroidUsbSerialPort.SetupCh34x;
const
  ReqOut = $40;
  LCR_8N1 = $C3;              // enable RX + TX, 8 data bits
  SCL_DTR = $20;
  SCL_RTS = $40;

  procedure SetBaud;
  var
    Factor, Divisor: Int64;
  begin
    if FBaudRate = 921600 then
    begin
      Divisor := 7;
      Factor := $F300;
    end
    else
    begin
      Factor := 1532620800 div FBaudRate;
      Divisor := 3;
      while (Factor > $FFF0) and (Divisor > 0) do
      begin
        Factor := Factor shr 3;
        Dec(Divisor);
      end;
      if Factor > $FFF0 then
        raise ESerialError.CreateFmt('%s: baud rate %d not supported', [FPortName, FBaudRate]);
      Factor := $10000 - Factor;
    end;
    Divisor := Divisor or $0080;
    Control(ReqOut, $9A, $1312, Integer((Factor and $FF00) or Divisor));
    Control(ReqOut, $9A, $0F2C, Integer(Factor and $FF));
  end;

var
  I: Integer;
begin
  FControlIntf := FDevice.getInterface(0);
  if not FConn.claimInterface(FControlIntf, True) then
    raise ESerialError.CreateFmt('%s: could not claim the USB interface', [FPortName]);
  FDataIntf := FControlIntf;
  for I := 0 to FDevice.getInterfaceCount - 1 do
    if FEpIn = nil then
      FindBulkEndpoints(FDevice.getInterface(I));
  // Same sequence as the Linux and usb-serial-for-android drivers.
  ControlIn($5F, 0, 0, 2);
  Control(ReqOut, $A1, 0, 0);
  SetBaud;
  ControlIn($95, $2518, 0, 2);
  Control(ReqOut, $9A, $2518, LCR_8N1);
  ControlIn($95, $0706, 0, 2);
  Control(ReqOut, $A1, $501F, $D90A);
  SetBaud;
  Control(ReqOut, $A4, (not (SCL_DTR or SCL_RTS)) and $FF, 0); // modem lines are active low
  ControlIn($95, $0706, 0, 2);
end;

{ CDC-ACM: class requests to the communication interface. }
procedure TAndroidUsbSerialPort.SetupCdcAcm;
const
  ReqOut = $21;
  SET_LINE_CODING = $20;
  SET_CONTROL_LINE_STATE = $22;
var
  I, CommId: Integer;
  Intf: JUsbInterface;
begin
  FControlIntf := nil;
  FDataIntf := nil;
  for I := 0 to FDevice.getInterfaceCount - 1 do
  begin
    Intf := FDevice.getInterface(I);
    if (Intf.getInterfaceClass = USB_CLASS_COMM) and (FControlIntf = nil) then
      FControlIntf := Intf
    else if (Intf.getInterfaceClass = USB_CLASS_CDC_DATA) and (FDataIntf = nil) then
      FDataIntf := Intf;
  end;
  if FDataIntf = nil then
    raise ESerialError.CreateFmt('%s: no CDC data interface', [FPortName]);
  if FControlIntf = nil then
    FControlIntf := FDataIntf;
  if not FConn.claimInterface(FControlIntf, True) or
    ((FDataIntf <> FControlIntf) and not FConn.claimInterface(FDataIntf, True)) then
    raise ESerialError.CreateFmt('%s: could not claim the USB interfaces', [FPortName]);
  FindBulkEndpoints(FDataIntf);
  CommId := FControlIntf.getId;
  Control(ReqOut, SET_LINE_CODING, 0, CommId, [Byte(FBaudRate), Byte(FBaudRate shr 8), Byte(FBaudRate shr 16),
    Byte(FBaudRate shr 24), 0 {1 stop bit}, 0 {no parity}, 8 {data bits}]);
  Control(ReqOut, SET_CONTROL_LINE_STATE, $0003 {DTR + RTS}, CommId);
end;

procedure TAndroidUsbSerialPort.ReleaseAll;
begin
  if FConn <> nil then
  begin
    try
      if FDataIntf <> nil then
        FConn.releaseInterface(FDataIntf);
      if (FControlIntf <> nil) and (FControlIntf <> FDataIntf) then
        FConn.releaseInterface(FControlIntf);
      FConn.close;
    except
      // unplugged: nothing left to release
    end;
  end;
  FConn := nil;
  FControlIntf := nil;
  FDataIntf := nil;
  FEpIn := nil;
  FEpOut := nil;
end;

procedure TAndroidUsbSerialPort.Close;
begin
  ReleaseAll;
  FreeAndNil(FJavaIn);
  FreeAndNil(FJavaOut);
  FPending := nil;
  FPendingPos := 0;
end;

{ One bulk IN transfer into FPending. Returns the number of data bytes
  (FTDI modem status bytes removed); 0 on timeout or status-only packets. }
function TAndroidUsbSerialPort.BulkRead(TimeoutMs: Integer): Integer;
var
  N, Pos, Chunk: Integer;
  Raw: TBytes;
  Env: PJNIEnv;
  Data: TBytes;
begin
  Result := 0;
  N := FConn.bulkTransfer(FEpIn, FJavaIn, 0, JavaBufferSize, Max(1, TimeoutMs)); // 0 would wait forever
  if N <= 0 then
    Exit; // -1 = timeout (or an unplugged device; the next write reports that)
  SetLength(Raw, N);
  Env := TJNIResolver.GetJNIEnv;
  Env^.GetByteArrayRegion(Env, FJavaIn.ToPointer, 0, N, PJNIByte(@Raw[0]));
  if FDriver = udFtdi then
  begin
    // Every packet starts with two modem status bytes.
    SetLength(Data, N);
    Result := 0;
    Pos := 0;
    while Pos < N do
    begin
      Chunk := Min(FInPacket, N - Pos);
      if Chunk > 2 then
      begin
        Move(Raw[Pos + 2], Data[Result], Chunk - 2);
        Inc(Result, Chunk - 2);
      end;
      Inc(Pos, Chunk);
    end;
    SetLength(Data, Result);
  end
  else
  begin
    Data := Raw;
    Result := N;
  end;
  if Result > 0 then
  begin
    if FPendingPos >= Length(FPending) then
    begin
      FPending := Data;
      FPendingPos := 0;
    end
    else
      FPending := Copy(FPending, FPendingPos, MaxInt) + Data;
    FPendingPos := 0;
  end;
end;

function TAndroidUsbSerialPort.Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
var
  Deadline, Now_: UInt64;
  Avail: Integer;
begin
  CheckOpen;
  Result := 0;
  if Count <= 0 then
    Exit;
  Deadline := TThread.GetTickCount64 + TimeoutMs;
  while Length(FPending) - FPendingPos <= 0 do
  begin
    // FTDI sends a status-only packet every latency period, so loop until
    // data arrives or the time is up.
    Now_ := TThread.GetTickCount64;
    if BulkRead(Integer(Max(1, Int64(Deadline) - Int64(Now_)))) > 0 then
      Break;
    if TThread.GetTickCount64 >= Deadline then
      Exit;
  end;
  Avail := Length(FPending) - FPendingPos;
  Result := Min(Count, Avail);
  Move(FPending[FPendingPos], Buffer, Result);
  Inc(FPendingPos, Result);
  if FPendingPos >= Length(FPending) then
  begin
    FPending := nil;
    FPendingPos := 0;
  end;
end;

procedure TAndroidUsbSerialPort.Write(const Data: TBytes);
var
  Pos, Chunk, N: Integer;
  Env: PJNIEnv;
begin
  CheckOpen;
  Pos := 0;
  Env := TJNIResolver.GetJNIEnv;
  while Pos < Length(Data) do
  begin
    Chunk := Min(JavaBufferSize, Length(Data) - Pos);
    Env^.SetByteArrayRegion(Env, FJavaOut.ToPointer, 0, Chunk, PJNIByte(@Data[Pos]));
    N := FConn.bulkTransfer(FEpOut, FJavaOut, 0, Chunk, WriteTimeoutMs);
    if N <= 0 then
      raise ESerialError.CreateFmt('%s write failed (unplugged?)', [FPortName]);
    Inc(Pos, N);
  end;
end;

procedure TAndroidUsbSerialPort.Purge;
var
  I: Integer;
begin
  FPending := nil;
  FPendingPos := 0;
  if not IsOpen then
    Exit;
  case FDriver of
    udFtdi:
      begin
        Control($40, 0, 1, FPortIndex); // purge RX
        Control($40, 0, 2, FPortIndex); // purge TX
      end;
    udCp210x:
      Control($41, $12, $000F, FControlIntf.getId); // flush read + write
  end;
  // Drop anything already on its way to us.
  for I := 1 to 8 do
    if BulkRead(5) = 0 then
      Break;
  FPending := nil;
  FPendingPos := 0;
end;

{$ENDIF}

end.
