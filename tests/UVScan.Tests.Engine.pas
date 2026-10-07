unit UVScan.Tests.Engine;

{ End-to-end engine tests against the built-in AVT/PCM simulator. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Diagnostics, System.IOUtils,
  System.Generics.Collections, DUnitX.TestFramework,
  UVScan.Serial, UVScan.Pids, UVScan.Engine, UVScan.Simulator;

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
    [Test] procedure ScansAndDecodesValues;
    [Test] procedure ReportsRejectedPidAndKeepsScanning;
    [Test] procedure LogsToCsv;
    [Test] procedure TestsPids;
    [Test] procedure ReadsDtcs;
    [Test] procedure RejectsScanWithNothingSelected;
    [Test] procedure SmallScanAfterLargeScanDoesNotReviveOldDpids;
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
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('Counter,Long Name,Desc,Formula,Units,Datalength,PID,group,shortname,Results,PidCat,txtMCI');
    Lines.Add('1,ENGINE SPEED,,((N1 << 8) +N2) *0.25,RPM,2,000C,1,RPM,,1,%RPM%');
    Lines.Add('2,Injector PW,,(((N1<<8)+N2)/65.535),ms,2,1193,1,Injector PW,%f,1,%IPW%');
    Lines.Add('3,ECT,,N0-40,C,1,5,1,ECT,,1,%ECT%');
    Lines.Add('87,Boost Solenoid PWM,,N0,%,1,1108,1,Boost PWM,,2,%BOOST%');
    Lines.Add('25,Inj Duty Cycle,,(%IPW% / (1 / ((%RPM% / 60 ) / 2) * 1000)) * 100,%,0,FPID,1,Inj DC,%f,6,%InjDutyCycle%');
    Lines.Add('30,RUNTIME,,,,0,FPID,1,RUNTIME,,6,%RUNTIME%');
    FCatalog := TPidCatalog.Create;
    FCatalog.LoadFromCsvLines(Lines);
  finally
    Lines.Free;
  end;
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
    Assert.AreEqual(3, Integer(Length(ParseCsvLine(Lines[1]))));
  finally
    Lines.Free;
    TFile.Delete(FileName);
  end;
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
  Lines: TStringList;
begin
  // 5 DPIDs (two schedule slots), then a 1-DPID scan. On the real PCM the
  // second scan would resume the old slot unless the engine clears it.
  Lines := TStringList.Create;
  try
    Lines.Add('Counter,Long Name,Desc,Formula,Units,Datalength,PID,group,shortname,Results,PidCat,txtMCI');
    for I := 0 to 14 do
      Lines.Add(Format('%d,P%d,,N0,,2,%.4x,1,P%d,,1,%%P%d%%', [100 + I, I, $2000 + I, I, I]));
    FCatalog.LoadFromCsvLines(Lines);
  finally
    Lines.Free;
  end;
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

initialization
  TDUnitX.RegisterTestFixture(TEngineTests);

end.
