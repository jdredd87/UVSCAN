unit UVScan.Tests.Engine;

{ End-to-end engine tests against the built-in AVT/PCM simulator. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Diagnostics, System.IOUtils,
  System.Generics.Collections, DUnitX.TestFramework,
  UVScan.Serial, UVScan.Pids, UVScan.Engine, UVScan.Simulator, UVScan.Class2, UVScan.Hex;

type
  [TestFixture]
  TEngineTests = class
  private
    FCatalog: TPidCatalog;
    FEngine: TScanEngine;
    FEvents: TList<TEngineEvent>;
    FState: TEngineState;
    FSim: TSimulatedAvt;
    function WaitUntil(const Cond: TFunc<Boolean>; TimeoutMs: Integer = 5000): Boolean;
    function HasEvent(Kind: TEngineEventKind): Boolean;
    function FindEvent(Kind: TEngineEventKind; out Ev: TEngineEvent): Boolean;
    procedure Connect;
    function ValueOf(const S: TLiveSnapshot; PidId: Integer): Double;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure ConnectsAndReadsVehicleInfo;
    [Test] procedure ConnectsWhenAvtHoldsHalfAFrame;
    [Test] procedure ScansAndDecodesValues;
    [Test] procedure UpdatesComeEvenly;
    [Test] procedure ReportsRejectedPidAndKeepsScanning;
    [Test] procedure LogsToCsv;
    [Test] procedure TestsPids;
    [Test] procedure ReadsDtcs;
    [Test] procedure RejectsScanWithNothingSelected;
    [Test] procedure SmallScanAfterLargeScanDoesNotReviveOldDpids;
    [Test] procedure DiscoversSupportedPids;
    [Test] procedure DeviceControlsShareAPacket;
    [Test] procedure DeviceControlRefusalIsReported;
    [Test] procedure StopsEverythingWhenAwayTooLong;
    [Test] procedure CarriesOnWhenBackInTime;
  end;

implementation

const
  IdRpm = 1;
  IdEct = 3;
  IdIpw = 2;
  IdBoost = 87;
  IdDuty = 25;
  IdRuntime = 30;

procedure TEngineTests.Setup;
begin
  FCatalog := TPidCatalog.Create;
  FCatalog.LoadFromJsonText(
    '{"pids":[' +
    '{"id":1,"name":"ENGINE SPEED","shortName":"RPM","kind":"vehicle","pid":"000C","bytes":2,"formula":"((N1 << 8) +N2) *0.25","units":"RPM","mci":"RPM"},' +
    '{"id":2,"name":"Injector PW","kind":"vehicle","pid":"1193","bytes":2,"formula":"(((N1<<8)+N2)/65.535)","units":"ms","format":"%f","mci":"IPW"},' +
    '{"id":3,"name":"ECT","shortName":"ECT","kind":"vehicle","pid":"0005","bytes":1,"formula":"N0-40","units":"C","mci":"ECT"},' +
    '{"id":87,"name":"Boost Solenoid PWM","shortName":"Boost PWM","kind":"vehicle","pid":"1108","bytes":1,"formula":"N0","units":"%","mci":"BOOST"},' +
    '{"id":25,"name":"Inj Duty Cycle","shortName":"Inj DC","kind":"calculated","formula":"(%IPW% / (1 / ((%RPM% / 60 ) / 2) * 1000)) * 100","units":"%","format":"%f","mci":"InjDutyCycle"},' +
    '{"id":30,"name":"RUNTIME","kind":"calculated","mci":"RUNTIME"}]}');
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

procedure TEngineTests.TearDown;
begin
  FEngine.Free;
  CheckSynchronize(0);
  FEvents.Free;
  FCatalog.Free;
end;

function TEngineTests.WaitUntil(const Cond: TFunc<Boolean>; TimeoutMs: Integer): Boolean;
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

function TEngineTests.FindEvent(Kind: TEngineEventKind; out Ev: TEngineEvent): Boolean;
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

function TEngineTests.HasEvent(Kind: TEngineEventKind): Boolean;
var
  Ev: TEngineEvent;
begin
  Result := FindEvent(Kind, Ev);
end;

procedure TEngineTests.Connect;
var
  Cmd: TEngineCommand;
begin
  Cmd := Command(ecConnect);
  Cmd.Factory :=
    function: ISerialPort
    begin
      FSim := TSimulatedAvt.Create;
      Result := FSim;
    end;
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eeVehicleInfo) end),
    'no vehicle info');
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FState = esConnected end), 'not connected');
end;

function TEngineTests.ValueOf(const S: TLiveSnapshot; PidId: Integer): Double;
var
  I: Integer;
begin
  for I := 0 to High(S.PidIds) do
    if S.PidIds[I] = PidId then
      Exit(S.Values[I]);
  Result := NaN;
end;

procedure TEngineTests.ConnectsAndReadsVehicleInfo;
var
  Ev: TEngineEvent;
begin
  Connect;
  Assert.IsTrue(FindEvent(eeVehicleInfo, Ev));
  Assert.AreEqual('04 0E', Ev.Vehicle.Firmware);
  Assert.AreEqual(SimulatedVin, Ev.Vehicle.Vin);
  Assert.AreEqual(IntToStr(SimulatedOsid), Ev.Vehicle.Osid);
  Assert.IsFalse(HasEvent(eeError));
end;

procedure TEngineTests.ConnectsWhenAvtHoldsHalfAFrame;
var
  Cmd: TEngineCommand;
  Ev: TEngineEvent;
begin
  // A program stopped while sending "09 6C 10 F1 ..." left the AVT waiting for
  // six more bytes: the first two E1 33 / B0 rounds only complete that frame.
  Cmd := Command(ecConnect);
  Cmd.Factory :=
    function: ISerialPort
    begin
      FSim := TSimulatedAvt.Create;
      FSim.Open;
      FSim.Write(HexToBytes('09 6C 10 F1'));
      Result := FSim;
    end;
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eeVehicleInfo) end), 'no vehicle info');
  Assert.IsTrue(FindEvent(eeVehicleInfo, Ev));
  Assert.AreEqual(SimulatedVin, Ev.Vehicle.Vin);
  Assert.IsFalse(HasEvent(eeError));
end;

procedure TEngineTests.ScansAndDecodesValues;
var
  Cmd: TEngineCommand;
  S: TLiveSnapshot;
  Rpm, Ect, Duty, Run: Double;
begin
  Connect;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := [IdRpm, IdIpw, IdEct, IdDuty, IdRuntime];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(
    function: Boolean
    begin
      S := FEngine.GetSnapshot;
      Result := S.Cycles >= 5;
    end), 'no scan cycles');
  Assert.AreEqual(Ord(esScanning), Ord(FState));
  Rpm := ValueOf(S, IdRpm);
  Ect := ValueOf(S, IdEct);
  Duty := ValueOf(S, IdDuty);
  Run := ValueOf(S, IdRuntime);
  Assert.IsTrue(InRange(Rpm, 790, 3410), 'rpm ' + FloatToStr(Rpm));
  Assert.IsTrue(InRange(Ect, 80, 96), 'ect ' + FloatToStr(Ect));
  Assert.IsFalse(IsNan(Duty), 'calculated PID not computed');
  Assert.IsTrue(Run > 0, 'runtime');

  FEngine.Post(Command(ecStopScan));
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FState = esConnected end), 'did not stop');
  Assert.IsFalse(HasEvent(eeError));
end;

{ Up to 4 DPIDs go in both PCM slots for about 10 updates a second; on the
  bench PCM they come evenly (every 0.1 s), so the simulator's must too, or
  the live chart and logs get pairs of nearly equal samples. }
procedure TEngineTests.UpdatesComeEvenly;
var
  Cmd: TEngineCommand;
  Samples: TArray<TLiveSample>;
  I: Integer;
  Gap, MinGap: Double;
begin
  Connect;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := [IdRpm, IdEct];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FEngine.GetSnapshot.Cycles >= 2 end), 'no scan cycles');
  FEngine.TakeSamples; // from here on
  Samples := nil;
  Assert.IsTrue(WaitUntil(
    function: Boolean
    begin
      Samples := Samples + FEngine.TakeSamples;
      Result := Length(Samples) >= 12;
    end), 'too few samples');
  MinGap := MaxDouble;
  for I := 1 to High(Samples) do
  begin
    Gap := Samples[I].Time - Samples[I - 1].Time;
    MinGap := Min(MinGap, Gap);
  end;
  Assert.IsTrue(MinGap > 0.06, Format('updates %.3f s apart', [MinGap]));
  Assert.IsTrue((Samples[High(Samples)].Time - Samples[0].Time) / High(Samples) < 0.13, 'about 10 a second');
end;

procedure TEngineTests.ReportsRejectedPidAndKeepsScanning;
var
  Cmd: TEngineCommand;
  Ev: TEngineEvent;
begin
  Connect;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := [IdRpm, IdBoost, IdEct];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FEngine.GetSnapshot.Cycles >= 3 end));
  Assert.IsTrue(FindEvent(eePidRejected, Ev));
  Assert.AreEqual(IdBoost, Ev.PidId);
  Assert.IsTrue(IsNan(ValueOf(FEngine.GetSnapshot, IdBoost)));
  Assert.IsFalse(IsNan(ValueOf(FEngine.GetSnapshot, IdRpm)));
end;

procedure TEngineTests.LogsToCsv;
var
  Cmd: TEngineCommand;
  FileName: string;
  Lines: TStringList;
begin
  FileName := TPath.Combine(TPath.GetTempPath, 'uvscan_test_log.csv');
  Connect;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := [IdRpm, IdEct];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FState = esScanning end));
  Cmd := Command(ecStartLog);
  Cmd.Text := FileName;
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FEngine.GetSnapshot.LogRows >= 5 end), 'no log rows');
  FEngine.Post(Command(ecStopLog));
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eeLogStopped) end));
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    Assert.AreEqual('Time (s),RPM (RPM),ECT (C)', Lines[0]);
    Assert.IsTrue(Lines.Count >= 6);
    Assert.AreEqual(3, Integer(Length(Lines[1].Split([',']))));
  finally
    Lines.Free;
    TFile.Delete(FileName);
  end;
end;

{ Phone in the background: after the set time the log is closed, the scan
  stopped and the adapter disconnected, with a warning saying so. }
procedure TEngineTests.StopsEverythingWhenAwayTooLong;
var
  Cmd: TEngineCommand;
  FileName: string;
  Ev: TEngineEvent;
  Lines: TStringList;
begin
  FileName := TPath.Combine(TPath.GetTempPath, 'uvscan_test_away.csv');
  Connect;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := [IdRpm, IdEct];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FState = esScanning end));
  Cmd := Command(ecStartLog);
  Cmd.Text := FileName;
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FEngine.GetSnapshot.LogRows >= 3 end), 'no log rows');
  Cmd := Command(ecBackground);
  Cmd.Seconds := 1;
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FState = esDisconnected end, 4000), 'still connected');
  Assert.IsTrue(HasEvent(eeLogStopped), 'log not closed');
  // the warning follows the disconnect
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eeWarning) end, 2000), 'no warning');
  Assert.IsTrue(FindEvent(eeWarning, Ev));
  Assert.IsTrue(Ev.Flag, 'marked as a stop for being away');
  Assert.Contains(Ev.Text, 'background for 1 s');
  Assert.Contains(Ev.Text, 'the log was closed, the scan stopped and the adapter was disconnected');
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    Assert.IsTrue(Lines.Count >= 4, 'rows written before it stopped are kept');
  finally
    Lines.Free;
    TFile.Delete(FileName);
  end;
  // Coming back afterwards changes nothing.
  Cmd := Command(ecForeground);
  Cmd.Seconds := 2;
  Cmd.Flag := True;
  FEngine.Post(Cmd);
  CheckSynchronize(200);
  Assert.IsTrue(FState = esDisconnected);
end;

procedure TEngineTests.CarriesOnWhenBackInTime;
var
  Cmd: TEngineCommand;
  Rows: Int64;
begin
  Connect;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := [IdRpm];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FState = esScanning end));
  Cmd := Command(ecBackground);
  Cmd.Seconds := 2;
  FEngine.Post(Cmd);
  WaitUntil(function: Boolean begin Result := False end, 500);
  Cmd := Command(ecForeground);
  Cmd.Seconds := 0;
  FEngine.Post(Cmd);
  WaitUntil(function: Boolean begin Result := False end, 2500); // past the 2 s
  Assert.IsTrue(FState = esScanning, 'stopped although back in time');
  Rows := FEngine.GetSnapshot.Cycles;
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FEngine.GetSnapshot.Cycles > Rows end), 'stream stopped');
  // Back too late by the wall clock (the app was frozen): stops even if the engine's clock says otherwise.
  Cmd := Command(ecBackground);
  Cmd.Seconds := 30;
  FEngine.Post(Cmd);
  Cmd := Command(ecForeground);
  Cmd.Seconds := 45;
  Cmd.Flag := True;
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FState = esDisconnected end), 'not stopped');
end;

procedure TEngineTests.TestsPids;
var
  Cmd: TEngineCommand;
  Ev: TEngineEvent;
  Supported, Unsupported: Integer;
begin
  Connect;
  Cmd := Command(ecTestPids); // empty list = every vehicle PID in the catalog
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(
    function: Boolean
    var
      E: TEngineEvent;
      N: Integer;
    begin
      N := 0;
      for E in FEvents do
        if E.Kind = eePidTest then
          Inc(N);
      Result := N = 4;
    end), 'expected 4 PID test results');
  Supported := 0;
  Unsupported := 0;
  for Ev in FEvents do
    if Ev.Kind = eePidTest then
      if Ev.Supported then
        Inc(Supported)
      else
      begin
        Inc(Unsupported);
        Assert.AreEqual(IdBoost, Ev.PidId);
      end;
  Assert.AreEqual(3, Supported);
  Assert.AreEqual(1, Unsupported);
end;

procedure TEngineTests.ReadsDtcs;
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
end;

procedure TEngineTests.SmallScanAfterLargeScanDoesNotReviveOldDpids;
var
  Cmd: TEngineCommand;
  I: Integer;
  Json: string;
begin
  // 5 DPIDs (two schedule slots), then a 1-DPID scan. On the real PCM the
  // second scan would resume the old slot unless the engine clears it.
  Json := '{"pids":[';
  for I := 0 to 14 do
  begin
    if I > 0 then
      Json := Json + ',';
    Json := Json + Format('{"id":%d,"name":"P%d","kind":"vehicle","pid":"%.4x","bytes":2,"formula":"N0","mci":"P%d"}',
      [100 + I, I, $2000 + I, I]);
  end;
  FCatalog.LoadFromJsonText(Json + ']}');
  Assert.AreEqual(15, FCatalog.Count);
  Connect;
  Cmd := Command(ecStartScan);
  for I := 0 to 14 do
    Cmd.PidIds := Cmd.PidIds + [100 + I];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FEngine.GetSnapshot.Cycles >= 2 end), 'large scan');
  Assert.AreEqual(5, Integer(Length(FSim.ActiveDpids)));

  Cmd := Command(ecStartScan);
  Cmd.PidIds := [100];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(
    function: Boolean
    var
      S: TLiveSnapshot;
    begin
      S := FEngine.GetSnapshot;
      Result := (Length(S.PidIds) = 1) and (S.Cycles >= 3);
    end), 'small scan');
  // Only $FE (scheduled in both slots), none of the earlier DPIDs.
  for I := 0 to High(FSim.ActiveDpids) do
    Assert.AreEqual(Integer($FE), Integer(FSim.ActiveDpids[I]), 'stale DPID still streaming');
  Assert.AreEqual(2, Integer(Length(FSim.ActiveDpids)));
end;

procedure TEngineTests.DiscoversSupportedPids;
var
  Cmd: TEngineCommand;
  Ev, Done: TEngineEvent;
  Found: TArray<Integer>;
begin
  Connect;
  Cmd := Command(ecDiscoverPids);
  Cmd.Text := '0000-001F, 1100-110F';
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eePidSearchDone) end, 15000), 'search did not finish');
  Found := nil;
  for Ev in FEvents do
    if Ev.Kind = eePidFound then
      Found := Found + [Ev.PidId];
  // Simulator answers $04-$11 (14) and $1100-$110F except $1107/$110F (every 8th) and $1108 (refused): 13
  Assert.AreEqual(27, Integer(Length(Found)));
  // the answer's size, as the PID search shows it: engine speed is 2 bytes, coolant 1
  for Ev in FEvents do
    if (Ev.Kind = eePidFound) and (Ev.PidId = $000C) then
      Assert.AreEqual(2, Ev.DataBytes, '$000C bytes')
    else if (Ev.Kind = eePidFound) and (Ev.PidId = $0005) then
      Assert.AreEqual(1, Ev.DataBytes, '$0005 bytes');
  Assert.IsTrue(FindEvent(eePidSearchDone, Done));
  Assert.AreEqual(48, Done.Total);
  Assert.AreEqual(48, Done.Progress);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := FState = esConnected end));
end;

procedure TEngineTests.RejectsScanWithNothingSelected;
var
  Cmd: TEngineCommand;
begin
  Connect;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := [IdDuty];
  FEngine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := HasEvent(eeError) end));
  Assert.AreEqual(Ord(esConnected), Ord(FState));
end;


function ControlCmd(const Name, OnHex, OffHex: string; TurnOn: Boolean): TEngineCommand;
var
  B: TBytes;
begin
  Result := Command(ecControl);
  Result.Text := Name;
  if TurnOn then
    B := HexToBytes(OnHex)
  else
    B := HexToBytes(OffHex);
  Result.Data := BuildMessage(AddrPcm, AddrTool, B[0], Copy(B, 1, MaxInt));
  B := HexToBytes(OffHex);
  Result.Release := BuildMessage(AddrPcm, AddrTool, B[0], Copy(B, 1, MaxInt));
  Result.Flag := TurnOn;
end;

{ Two lamps in CPID $01 must both stay on: the second packet carries both,
  and switching one off sends the one that is still on. }
procedure TEngineTests.DeviceControlsShareAPacket;
const
  Off = 'AE 01 00 00 00 00 00 00';
var
  Sent: TList<string>;
  E, Ev2: TEngineEvent;
  Results: Integer;
begin
  Connect;
  FEngine.SetTrace(True);
  FEvents.Clear;
  FEngine.Post(ControlCmd('MIL', 'AE 01 80 80 00 00 00 00', Off, True));
  FEngine.Post(ControlCmd('Fan', 'AE 01 00 00 80 80 00 00', Off, True));
  FEngine.Post(ControlCmd('MIL', 'AE 01 80 80 00 00 00 00', Off, False));
  Assert.IsTrue(WaitUntil(
    function: Boolean
    var
      Ev: TEngineEvent;
      N: Integer;
    begin
      N := 0;
      for Ev in FEvents do
        if Ev.Kind = eeControl then
          Inc(N);
      Result := N = 3;
    end), 'three control results');
  Sent := TList<string>.Create;
  try
    Results := 0;
    for Ev2 in FEvents do
    begin
      if (Ev2.Kind = eeLog) and Ev2.Text.StartsWith('Control "') and (Pos(': 6C 10 F1 AE', Ev2.Text) > 0) then
        Sent.Add(Copy(Ev2.Text, Pos(': 6C', Ev2.Text) + 2, MaxInt));
      if Ev2.Kind = eeControl then
      begin
        Assert.IsTrue(Ev2.Supported, Ev2.Raw);
        Inc(Results);
      end;
    end;
    Assert.AreEqual(3, Results);
    Assert.AreEqual(3, Integer(Sent.Count));
    Assert.AreEqual('6C 10 F1 AE 01 80 80 00 00 00 00', Sent[0]);
    Assert.AreEqual('6C 10 F1 AE 01 80 80 80 80 00 00', Sent[1], 'fan on keeps the MIL on');
    Assert.AreEqual('6C 10 F1 AE 01 00 00 80 80 00 00', Sent[2], 'MIL off keeps the fan on');
  finally
    Sent.Free;
  end;
  // Release all ends the fan too and returns the PCM to normal.
  FEvents.Clear;
  FEngine.Post(Command(ecReleaseControls));
  Assert.IsTrue(WaitUntil(
    function: Boolean
    begin
      Result := FindEvent(eeControl, E);
    end));
  Assert.AreEqual('Fan', E.Text);
  Assert.AreEqual('released', E.Raw);
end;

procedure TEngineTests.DeviceControlRefusalIsReported;
var
  E: TEngineEvent;
begin
  Connect;
  FEvents.Clear;
  FEngine.Post(ControlCmd('Bad', 'AE 09 00 00 00 00 00 00', 'AE 09 00 00 00 00 00 00', True));
  Assert.IsTrue(WaitUntil(
    function: Boolean
    begin
      Result := FindEvent(eeControl, E);
    end));
  Assert.IsFalse(E.Supported);
  Assert.IsFalse(E.Flag, 'a refused control is not held');
  Assert.Contains(E.Raw, 'out of range');
end;

initialization
  TDUnitX.RegisterTestFixture(TEngineTests);

end.
