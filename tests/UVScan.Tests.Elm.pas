unit UVScan.Tests.Elm;

{ The ELM327 path: the ELM text protocol, the simulated ELM327, and the
  engine end to end through TElmAdapter. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Diagnostics, System.Generics.Collections,
  DUnitX.TestFramework,
  UVScan.Serial, UVScan.Pids, UVScan.Engine, UVScan.Adapter, UVScan.Elm, UVScan.Simulator,
  UVScan.Simulator.Elm, UVScan.Class2, UVScan.Hex;

type
  [TestFixture]
  TElmTests = class
  private
    FCatalog: TPidCatalog;
    FEngine: TScanEngine;
    FEvents: TList<TEngineEvent>;
    FState: TEngineState;
    FSim: TSimulatedElm;
    function WaitUntil(const Cond: TFunc<Boolean>; TimeoutMs: Integer = 5000): Boolean;
    function FindEvent(Kind: TEngineEventKind; out Ev: TEngineEvent): Boolean;
    function HasEvent(Kind: TEngineEventKind): Boolean;
    function Events(Kind: TEngineEventKind): TArray<TEngineEvent>;
    procedure Connect;
    function ValueOf(const S: TLiveSnapshot; PidId: Integer): Double;
    function Ask(const Port: ISerialPort; const Cmd: string): string;
    function Stop(const Port: ISerialPort): string;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure ParsesElmLines;
    [Test] procedure ComputesJ1850Crc;
    [Test] procedure BluetoothNamesAreNoNetworkAddresses;
    [Test] procedure SimulatedElmBehavesLikeOne;
    [Test] procedure ConnectsAndReadsVehicleInfo;
    [Test] procedure ScansAtFullRate;
    [Test] procedure ScansManyPidsInBothSlots;
    [Test] procedure ResumesAfterPcmReset;
    [Test] procedure TestsPidsAnsweredToF0;
    [Test] procedure ReadsAndClearsDtcs;
    [Test] procedure SendsLongDeviceControl;
    [Test] procedure AnalogInputsNeedAnAvt;
    [Test] procedure ReportsSilentPort;
  end;

implementation

const
  IdRpm = 1;
  IdIpw = 2;
  IdEct = 3;
  IdBoost = 87;
  IdAd1 = 21;

procedure TElmTests.Setup;
begin
  FCatalog := TPidCatalog.Create;
  FCatalog.LoadFromJsonText(
    '{"pids":[' +
    '{"id":1,"name":"ENGINE SPEED","shortName":"RPM","kind":"vehicle","pid":"000C","bytes":2,"formula":"((N1 << 8) +N2) *0.25","units":"RPM","mci":"RPM"},' +
    '{"id":2,"name":"Injector PW","kind":"vehicle","pid":"1193","bytes":2,"formula":"(((N1<<8)+N2)/65.535)","units":"ms","format":"%f","mci":"IPW"},' +
    '{"id":3,"name":"ECT","shortName":"ECT","kind":"vehicle","pid":"0005","bytes":1,"formula":"N0-40","units":"C","mci":"ECT"},' +
    '{"id":4,"name":"VSS","kind":"vehicle","pid":"000D","bytes":1,"formula":"N0","units":"km/h","mci":"VSS"},' +
    '{"id":5,"name":"TPS","kind":"vehicle","pid":"0011","bytes":1,"formula":"N0/2.55","units":"%","mci":"TPS"},' +
    '{"id":6,"name":"MAP","kind":"vehicle","pid":"000B","bytes":1,"formula":"N0","units":"kPa","mci":"MAP"},' +
    '{"id":7,"name":"IAT","kind":"vehicle","pid":"000F","bytes":1,"formula":"N0-40","units":"C","mci":"IAT"},' +
    '{"id":87,"name":"Boost Solenoid PWM","shortName":"Boost PWM","kind":"vehicle","pid":"1108","bytes":1,"formula":"N0","units":"%","mci":"BOOST"},' +
    '{"id":21,"name":"AD1","kind":"analog","category":"analog","analogChannel":1,"formula":"N0 * 0.0196","mci":"AD1"}]}');
  Assert.AreEqual(0, FCatalog.Warnings.Count, FCatalog.Warnings.Text);
  FEvents := TList<TEngineEvent>.Create;
  FEngine := TScanEngine.Create(FCatalog,
    procedure(const Ev: TEngineEvent)
    begin
      FEvents.Add(Ev);
      if Ev.Kind = eeState then
        FState := Ev.State;
    end);
end;

procedure TElmTests.TearDown;
begin
  FEngine.Free;
  CheckSynchronize(0);
  FEvents.Free;
  FCatalog.Free;
end;

function TElmTests.WaitUntil(const Cond: TFunc<Boolean>; TimeoutMs: Integer): Boolean;
var
  Clock: TStopwatch;
begin
  Clock := TStopwatch.StartNew;
  repeat
    CheckSynchronize(10);
    if Cond() then
      Exit(True);
  until Clock.ElapsedMilliseconds > TimeoutMs;
  Result := False;
end;

function TElmTests.FindEvent(Kind: TEngineEventKind; out Ev: TEngineEvent): Boolean;
var
  E: TEngineEvent;
begin
  for E in FEvents do
    if E.Kind = Kind then
    begin
      Ev := E;
      Exit(True);
    end;
  Result := False;
end;

function TElmTests.HasEvent(Kind: TEngineEventKind): Boolean;
var
  Ev: TEngineEvent;
begin
  Result := FindEvent(Kind, Ev);
end;

function TElmTests.Events(Kind: TEngineEventKind): TArray<TEngineEvent>;
var
  E: TEngineEvent;
begin
  Result := nil;
  for E in FEvents do
    if E.Kind = Kind then
      Result := Result + [E];
end;

procedure TElmTests.Connect;
var
  Cmd: TEngineCommand;
begin
  Cmd := Command(ecConnect);
  Cmd.Adapter := akElm327;
  Cmd.Factory :=
    function: ISerialPort
    begin
      FSim := TSimulatedElm.Create;
      Result := FSim;
    end;
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eeVehicleInfo) or HasEvent(eeError) end,
    10000), 'no vehicle info');
  Assert.IsFalse(HasEvent(eeError), 'error connecting');
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FState = esConnected end), 'not connected');
end;

function TElmTests.ValueOf(const S: TLiveSnapshot; PidId: Integer): Double;
var
  I: Integer;
begin
  for I := 0 to High(S.PidIds) do
    if S.PidIds[I] = PidId then
      Exit(S.Values[I]);
  Result := NaN;
end;

{ Sends Cmd + CR to the port and returns what comes up to the prompt. }
function TElmTests.Ask(const Port: ISerialPort; const Cmd: string): string;
var
  Buf: array[0..255] of Byte;
  N, I: Integer;
  Clock: TStopwatch;
begin
  Result := '';
  Port.Write(TEncoding.ASCII.GetBytes(Cmd + #13));
  Clock := TStopwatch.StartNew;
  while not Result.Contains('>') and (Clock.ElapsedMilliseconds < 2000) do
  begin
    N := Port.Read(Buf, SizeOf(Buf), 50);
    for I := 0 to N - 1 do
      Result := Result + Char(Buf[I]);
  end;
end;

{ A lone space (no CR: at the prompt a CR repeats the last command) stops
  a listening ELM; returns what comes up to the prompt. }
function TElmTests.Stop(const Port: ISerialPort): string;
var
  Buf: array[0..255] of Byte;
  N, I: Integer;
  Clock: TStopwatch;
begin
  Result := '';
  Port.Write(TBytes.Create(Ord(' ')));
  Clock := TStopwatch.StartNew;
  while not Result.Contains('>') and (Clock.ElapsedMilliseconds < 2000) do
  begin
    N := Port.Read(Buf, SizeOf(Buf), 50);
    for I := 0 to N - 1 do
      Result := Result + Char(Buf[I]);
  end;
end;

procedure TElmTests.ParsesElmLines;
var
  F: TElmFrame;
begin
  Assert.IsTrue(ParseElmFrame('6CF1106AFE0000000100080B', True, F));
  Assert.AreEqual('6C F1 10 6A FE 00 00 00 01 00 08', BytesToHex(F), 'CRC dropped');
  Assert.IsTrue(ParseElmFrame('48 6B 10 41 00 BE 3F A8 13 C5', True, F), 'with spaces');
  Assert.AreEqual(9, Integer(Length(F)));
  Assert.IsTrue(ParseElmFrame('41 0C 1A F8', False, F), 'headers off: no CRC');
  Assert.AreEqual(4, Integer(Length(F)));
  Assert.IsFalse(ParseElmFrame('NO DATA', True, F));
  Assert.IsFalse(ParseElmFrame('SEARCHING...', True, F));
  Assert.IsFalse(ParseElmFrame('6CF110A', True, F), 'odd length');
  Assert.IsTrue(IsElmMessage('NO DATA'));
  Assert.IsTrue(IsElmMessage('BUFFER FULL'));
  Assert.IsTrue(IsElmMessage('<DATA ERROR'));
  Assert.IsTrue(IsElmMessage('?'));
  Assert.IsFalse(IsElmMessage('6CF1106AFE'));
end;

procedure TElmTests.ComputesJ1850Crc;
begin
  // The usual example: the generic "01 00" request.
  Assert.AreEqual($17, Integer(J1850Crc(BytesOf([$68, $6A, $F1, $01, $00]))));
  // A frame the bench PCM sent through a vLinker FD, CRC and all.
  Assert.AreEqual($0B, Integer(J1850Crc(HexToBytes('6C F1 10 6A FE 00 00 00 01 00 08'))));
end;

procedure TElmTests.BluetoothNamesAreNoNetworkAddresses;
begin
  Assert.IsTrue(IsBluetoothPortName('BT vLinker FD [DC:0D:30:CF:84:97]'));
  Assert.IsFalse(IsTcpAddress('BT vLinker FD [DC:0D:30:CF:84:97]'), 'the address has colons');
  Assert.IsFalse(IsBluetoothPortName('COM4'));
  Assert.IsFalse(IsBluetoothPortName('BT thing'));
  Assert.IsTrue(IsTcpAddress('192.168.0.10:35000'));
end;

procedure TElmTests.SimulatedElmBehavesLikeOne;
var
  Port: ISerialPort;
  S: string;
  Buf: array[0..1023] of Byte;
  N, I: Integer;
  Clock: TStopwatch;
begin
  Port := TSimulatedElm.Create;
  Port.Open;
  S := Ask(Port, 'ATZ');
  Assert.Contains(S, 'ELM327', 'reset');
  Assert.Contains(Ask(Port, 'ATE0'), 'OK');
  Assert.AreEqual('OK'#13#13'>', Ask(Port, 'ATS0'), 'no echo');
  Ask(Port, 'ATH1');
  Ask(Port, 'ATSH6C10F1');
  // A request: the reply with its CRC, then the prompt when the bus is quiet.
  S := Ask(Port, '3C01');
  Assert.Contains(S, '6CF1107C0100', 'VIN block 1');
  Assert.Contains(S, '>', 'prompt');
  // Tester present gets no answer: NO DATA when the timeout is up.
  Assert.Contains(Ask(Port, '3F'), 'NO DATA');
  // More than 7 data bytes only with ATAL.
  Assert.Contains(Ask(Port, 'AE01000000000000'), '?');
  Ask(Port, 'ATAL');
  Assert.DoesNotContain(Ask(Port, 'AE01000000000000'), '?');
  // ATMA shows the bus until a character comes; that one is dropped.
  Ask(Port, '2C FE 4A 00 0C FF FF');
  // The stream keeps the request listening: a space stops that first.
  S := Ask(Port, '2A 14 FE 00 00 00');
  Assert.DoesNotContain(S, '>', 'still listening while the frames come');
  Assert.Contains(Stop(Port), 'STOPPED');
  Port.Write(TEncoding.ASCII.GetBytes('ATMA'#13));
  S := '';
  Clock := TStopwatch.StartNew;
  while Clock.ElapsedMilliseconds < 700 do
  begin
    N := Port.Read(Buf, SizeOf(Buf), 50);
    for I := 0 to N - 1 do
      S := S + Char(Buf[I]);
  end;
  Assert.IsTrue(S.CountChar(#13) >= 3, 'stream frames shown: ' + S);
  Assert.DoesNotContain(S, '>', 'still monitoring');
  Assert.Contains(Stop(Port), 'STOPPED');
end;

procedure TElmTests.ConnectsAndReadsVehicleInfo;
var
  Ev: TEngineEvent;
begin
  Connect;
  Assert.IsTrue(FindEvent(eeVehicleInfo, Ev));
  Assert.AreEqual('ELM327 v1.5', Ev.Vehicle.Firmware);
  Assert.AreEqual(SimulatedVin, Ev.Vehicle.Vin);
  Assert.AreEqual(IntToStr(SimulatedOsid), Ev.Vehicle.Osid);
end;

{ Up to 4 DPIDs: both PCM slots, about 10 rows a second, as with the AVT;
  the tester present every 2 s and the ELM's quiet-bus timeouts must not
  cost more than a little of that. }
procedure TElmTests.ScansAtFullRate;
var
  Cmd: TEngineCommand;
  S: TLiveSnapshot;
  Start: Int64;
  Clock: TStopwatch;
  Rate: Double;
begin
  Connect;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := [IdRpm, IdEct];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FEngine.GetSnapshot.Cycles >= 3 end), 'no scan cycles');
  Start := FEngine.GetSnapshot.Cycles;
  Clock := TStopwatch.StartNew;
  WaitUntil(function: Boolean begin Result := Clock.ElapsedMilliseconds >= 5000 end, 6000);
  S := FEngine.GetSnapshot;
  Rate := (S.Cycles - Start) / Clock.Elapsed.TotalSeconds;
  Assert.IsTrue(Rate > 8, Format('%.1f rows/s', [Rate]));
  Assert.IsTrue(InRange(ValueOf(S, IdRpm), 600, 6000), 'rpm');
  Assert.IsTrue(InRange(ValueOf(S, IdEct), 80, 96), 'ect');
  Assert.AreEqual(Ord(esScanning), Ord(FState));
  FEngine.Post(Command(ecStopScan));
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FState = esConnected end), 'did not stop');
  Assert.IsFalse(HasEvent(eeError));
end;

{ More PIDs than one DPID holds: every DPID still comes, so rows do. }
procedure TElmTests.ScansManyPidsInBothSlots;
var
  Cmd: TEngineCommand;
  S: TLiveSnapshot;
  Id: Integer;
begin
  Connect;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := [IdRpm, IdIpw, IdEct, 4, 5, 6, 7];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FEngine.GetSnapshot.Cycles >= 10 end, 8000),
    'no scan cycles');
  S := FEngine.GetSnapshot;
  for Id in Cmd.PidIds do
    Assert.IsFalse(IsNan(ValueOf(S, Id)), 'no value for PID ' + IntToStr(Id));
  Assert.IsFalse(HasEvent(eeError));
end;

procedure TElmTests.ResumesAfterPcmReset;
var
  Cmd: TEngineCommand;
  Before: Int64;
begin
  Connect;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := [IdRpm, IdIpw, IdEct];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FEngine.GetSnapshot.Cycles >= 5 end), 'no scan cycles');
  FSim.Pcm.ResetPcm;
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eeWarning) end, 8000), 'no warning');
  Before := FEngine.GetSnapshot.Cycles;
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eeStreamBack) end, 8000), 'stream not back');
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FEngine.GetSnapshot.Cycles >= Before + 5 end),
    'no cycles after the reset');
  Assert.IsFalse(HasEvent(eeError));
end;

{ The PID test asks from F0, so the answers are addressed to F0. }
procedure TElmTests.TestsPidsAnsweredToF0;
var
  Cmd: TEngineCommand;
  Ev: TEngineEvent;
  Supported: Integer;
begin
  Connect;
  Cmd := Command(ecTestPids);
  Cmd.PidIds := [IdRpm, IdIpw, IdEct, IdBoost];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := Length(Events(eePidTest)) = 4 end),
    'expected 4 PID test results');
  Supported := 0;
  for Ev in Events(eePidTest) do
    if Ev.Supported then
      Inc(Supported)
    else
      Assert.AreEqual(IdBoost, Ev.PidId);
  Assert.AreEqual(3, Supported);
  // And the stream still works after it (back to the ELM's own address).
  FEvents.Clear;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := [IdRpm];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FEngine.GetSnapshot.Cycles >= 5 end), 'no scan cycles');
end;

procedure TElmTests.ReadsAndClearsDtcs;
var
  Ev: TEngineEvent;
begin
  Connect;
  FEngine.Post(Command(ecReadDtcs));
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eeDtcs) end), 'no DTC result');
  Assert.IsTrue(FindEvent(eeDtcs, Ev));
  Assert.AreEqual(2, Integer(Length(Ev.Dtcs)));
  Assert.AreEqual('P0300', Ev.Dtcs[0].Code);
  Assert.AreEqual('P0171', Ev.Dtcs[1].Code);
  FEngine.Post(Command(ecClearDtcs));
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FState = esConnected end));
  FEvents.Clear;
  FEngine.Post(Command(ecReadDtcs));
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eeDtcs) end), 'no DTC result after clearing');
  Assert.IsTrue(FindEvent(eeDtcs, Ev));
  Assert.AreEqual(0, Integer(Length(Ev.Dtcs)));
end;

{ A device control packet is 8 data bytes: more than an ELM sends unless
  ATAL is on. }
procedure TElmTests.SendsLongDeviceControl;
var
  Cmd: TEngineCommand;
  E: TEngineEvent;
begin
  Connect;
  FEvents.Clear;
  Cmd := Command(ecControl);
  Cmd.Text := 'MIL';
  Cmd.Data := HexToBytes('6C 10 F1 AE 01 80 80 00 00 00 00');
  Cmd.Release := HexToBytes('6C 10 F1 AE 01 00 00 00 00 00 00');
  Cmd.Flag := True;
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FindEvent(eeControl, E) end), 'no control result');
  Assert.IsTrue(E.Supported, E.Raw);
  Assert.IsTrue(E.Flag);
end;

procedure TElmTests.AnalogInputsNeedAnAvt;
var
  Cmd: TEngineCommand;
  Ev: TEngineEvent;
begin
  Connect;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := [IdAd1];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eeError) end), 'analog-only scan refused');
  Assert.IsTrue(FindEvent(eeError, Ev));
  Assert.Contains(Ev.Text, 'AVT');
  // With vehicle PIDs it scans them, and says the analog ones stay empty.
  FEvents.Clear;
  Cmd.PidIds := [IdRpm, IdAd1];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FEngine.GetSnapshot.Cycles >= 3 end), 'no scan cycles');
  Assert.IsTrue(HasEvent(eeWarning));
  Assert.IsTrue(IsNan(ValueOf(FEngine.GetSnapshot, IdAd1)));
end;

{ Something on the port that is no ELM: a clear message, not a hang. }
procedure TElmTests.ReportsSilentPort;
var
  Cmd: TEngineCommand;
  Ev: TEngineEvent;
begin
  Cmd := Command(ecConnect);
  Cmd.Adapter := akElm327;
  Cmd.Factory :=
    function: ISerialPort
    begin
      Result := TSimulatedAvt.Create; // an AVT says nothing to "ATZ"
    end;
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eeError) end, 15000), 'no error');
  Assert.IsTrue(FindEvent(eeError, Ev));
  Assert.Contains(Ev.Text, 'ELM327');
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FState = esDisconnected end), 'still connected');
end;

initialization
  TDUnitX.RegisterTestFixture(TElmTests);

end.
