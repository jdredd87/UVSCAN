unit UVScan.Tests.Sensors;

{ Sensors: the MTS and text decoders, sensors.json, sensor files, and a scan
  of a simulated wideband beside the simulated PCM. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Diagnostics, System.JSON,
  System.Generics.Collections, DUnitX.TestFramework,
  UVScan.Serial, UVScan.Pids, UVScan.Engine, UVScan.Simulator, UVScan.Sensors;

type
  [TestFixture]
  TSensorTests = class
  private
    FFields: TDictionary<string, Double>;
    procedure Collect(const Field: string; Value: Double);
    function Field(const Name: string): Double;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure DecodesMtsPacket;
    [Test] procedure DecodesMtsInPiecesAfterNoise;
    [Test] procedure SkipsAMtsPacketCutShort;
    [Test] procedure ReportsMtsWarmUp;
    [Test] procedure ReadsNumbersAndNamesFromText;
    [Test] procedure TextLinesArriveInPieces;
    [Test] procedure SensorsJsonRoundTrip;
    [Test] procedure SensorPidRoundTrip;
    [Test] procedure ImportsASensorFile;
    [Test] procedure SharesASensorFile;
    [Test] procedure ScansASimulatedWideband;
    [Test] procedure ScansSensorsOnly;
    [Test] procedure WarnsAboutAMissingSensor;
  end;

implementation

procedure TSensorTests.Setup;
begin
  FFields := TDictionary<string, Double>.Create;
end;

procedure TSensorTests.TearDown;
begin
  FFields.Free;
end;

procedure TSensorTests.Collect(const Field: string; Value: Double);
begin
  FFields.AddOrSetValue(Field, Value);
end;

function TSensorTests.Field(const Name: string): Double;
begin
  if not FFields.TryGetValue(Name, Result) then
    Assert.Fail('no field ' + Name);
end;

procedure TSensorTests.DecodesMtsPacket;
var
  P: TMtsParser;
  B: TBytes;
begin
  // An LC-1 at lambda 0.950 set for petrol, then two aux inputs.
  B := BuildMtsPacket([MtsLambda(0, 147, 450)], [1023, 5]);
  Assert.AreEqual(2 + 4 * 2, Length(B));
  Assert.AreEqual($B2, Integer(B[0]), 'header: bits 15, 13, 12 (sensor data), 9');
  Assert.AreEqual($84, Integer(B[1]), 'header: 4 words follow');
  P := TMtsParser.Create;
  try
    P.Push(B, Length(B), Collect);
    Assert.AreEqual(Int64(1), P.Count);
    Assert.AreEqual(0.95, Field('lambda1'), 1E-9);
    Assert.AreEqual(0.95 * 14.7, Field('afr1'), 1E-9);
    Assert.AreEqual(0.0, Field('status1'), 1E-9);
    Assert.AreEqual(1023.0, Field('aux1'), 1E-9);
    Assert.AreEqual(5.0, Field('aux2'), 1E-9);
    Assert.AreEqual('', P.Note);
  finally
    P.Free;
  end;
end;

procedure TSensorTests.DecodesMtsInPiecesAfterNoise;
var
  P: TMtsParser;
  B, Chunk: TBytes;
  I: Integer;
begin
  // The middle of an earlier packet, then two wideband chained (an LM-2's
  // two channels), arriving a byte or three at a time.
  B := [$12, $05, $7F] + BuildMtsPacket([MtsLambda(0, 147, 500), MtsLambda(0, 64, 700)], []);
  P := TMtsParser.Create;
  try
    I := 0;
    while I < Length(B) do
    begin
      Chunk := Copy(B, I, 1 + I mod 3);
      P.Push(Chunk, Length(Chunk), Collect);
      Inc(I, Length(Chunk));
    end;
    Assert.AreEqual(Int64(1), P.Count);
    Assert.AreEqual(1.0, Field('lambda1'), 1E-9);
    Assert.AreEqual(14.7, Field('afr1'), 1E-9);
    Assert.AreEqual(1.2, Field('lambda2'), 1E-9);
    Assert.AreEqual(1.2 * 6.4, Field('afr2'), 1E-9);
  finally
    P.Free;
  end;
end;

procedure TSensorTests.SkipsAMtsPacketCutShort;
var
  P: TMtsParser;
  A, B: TBytes;
begin
  // A packet that lost its last bytes, then a whole one: only the whole one.
  A := BuildMtsPacket([MtsLambda(0, 147, 100)], []);
  SetLength(A, Length(A) - 2);
  B := A + BuildMtsPacket([MtsLambda(0, 147, 300)], []);
  P := TMtsParser.Create;
  try
    P.Push(B, Length(B), Collect);
    Assert.AreEqual(Int64(1), P.Count);
    Assert.AreEqual(0.8, Field('lambda1'), 1E-9);
  finally
    P.Free;
  end;
end;

procedure TSensorTests.ReportsMtsWarmUp;
var
  P: TMtsParser;
  B: TBytes;
begin
  B := BuildMtsPacket([MtsLambda(4, 147, 455)], []);
  P := TMtsParser.Create;
  try
    P.Push(B, Length(B), Collect);
    Assert.IsTrue(IsNan(Field('lambda1')), 'no lambda while warming up');
    Assert.IsTrue(IsNan(Field('afr1')));
    Assert.AreEqual(4.0, Field('status1'), 1E-9);
    Assert.AreEqual(45.5, Field('warmup1'), 1E-9);
    Assert.AreEqual('warming up', P.Note);
    B := BuildMtsPacket([MtsLambda(0, 147, 470)], []);
    P.Push(B, Length(B), Collect);
    Assert.AreEqual('', P.Note, 'reading again');
    Assert.AreEqual(0.97, Field('lambda1'), 1E-9);
  finally
    P.Free;
  end;
end;

procedure TSensorTests.ReadsNumbersAndNamesFromText;
begin
  TTextParser.ParseLine('afr=14.72 EGT: 812  oilp = -1.5', Collect);
  Assert.AreEqual(14.72, Field('1'), 1E-9);
  Assert.AreEqual(812.0, Field('2'), 1E-9);
  Assert.AreEqual(-1.5, Field('3'), 1E-9);
  Assert.AreEqual(14.72, Field('afr'), 1E-9);
  Assert.AreEqual(812.0, Field('egt'), 1E-9);
  Assert.AreEqual(-1.5, Field('oilp'), 1E-9);
  FFields.Clear;
  // Digits in a name are no number; a plain list is numbered.
  TTextParser.ParseLine('T1 23.4,T2 .5', Collect);
  Assert.AreEqual(2, FFields.Count, 'only the two values');
  Assert.AreEqual(23.4, Field('1'), 1E-9);
  Assert.AreEqual(0.5, Field('2'), 1E-9);
  FFields.Clear;
  TTextParser.ParseLine('14.7', Collect);
  Assert.AreEqual(14.7, Field('1'), 1E-9);
  FFields.Clear;
  TTextParser.ParseLine('10.2.3 1-2', Collect);
  Assert.AreEqual(10.2, Field('1'), 1E-9, 'an IP-like run gives its first number only');
  Assert.AreEqual(1.0, Field('2'), 1E-9);
end;

procedure TSensorTests.TextLinesArriveInPieces;
var
  P: TTextParser;
  B: TBytes;
begin
  P := TTextParser.Create;
  try
    B := TEncoding.ASCII.GetBytes('14.');
    P.Push(B, Length(B), Collect);
    Assert.AreEqual(0, FFields.Count, 'half a line');
    B := TEncoding.ASCII.GetBytes('7'#13#10'15.1'#13#10'1');
    P.Push(B, Length(B), Collect);
    Assert.AreEqual(Int64(2), P.Count);
    Assert.AreEqual(15.1, Field('1'), 1E-9);
    Assert.AreEqual('15.1', P.Last);
  finally
    P.Free;
  end;
end;

procedure TSensorTests.SensorsJsonRoundTrip;
var
  A, B: TSensorCatalog;
  D: TSensorDef;
  J: TJSONObject;
begin
  A := TSensorCatalog.Create;
  B := TSensorCatalog.Create;
  try
    D := TSensorDef.Create;
    D.Name := 'LC-1';
    D.Port := 'COM5';
    A.Add(D);
    D := TSensorDef.Create;
    D.Name := 'EGT';
    D.Protocol := spText;
    D.Port := '192.168.4.1:23';
    D.Baud := 115200;
    D.Send := 'R\r';
    D.SendEveryMs := 250;
    D.Enabled := False;
    D.Description := 'four thermocouples';
    A.Add(D);
    J := A.ToJson;
    try
      // a second one of a name, and one with an unknown protocol, are left out
      J.GetValue<TJSONArray>('sensors').AddElement(TJSONObject.ParseJSONValue(
        '{"name":"lc-1","protocol":"mts"}') as TJSONObject);
      J.GetValue<TJSONArray>('sensors').AddElement(TJSONObject.ParseJSONValue(
        '{"name":"X","protocol":"can"}') as TJSONObject);
      B.LoadFromJson(J);
    finally
      J.Free;
    end;
    Assert.AreEqual(2, B.Count);
    Assert.AreEqual(2, B.Warnings.Count, B.Warnings.Text);
    Assert.AreEqual('COM5', B[0].Port);
    Assert.AreEqual(19200, B[0].Baud, 'MTS default baud');
    Assert.IsTrue(B[0].Enabled);
    Assert.AreEqual(Ord(spText), Ord(B.Find('egt').Protocol));
    Assert.AreEqual(115200, B[1].Baud);
    Assert.AreEqual('R\r', B[1].Send);
    Assert.AreEqual('R'#13, UnescapeSensorText(B[1].Send));
    Assert.AreEqual(250, B[1].SendEveryMs);
    Assert.IsFalse(B[1].Enabled);
    Assert.AreEqual('four thermocouples', B[1].Description);
    Assert.AreEqual('LC-1 2', B.FreeName('LC-1'));
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TSensorTests.SensorPidRoundTrip;
var
  C, D: TPidCatalog;
  J: TJSONObject;
begin
  C := TPidCatalog.Create;
  D := TPidCatalog.Create;
  try
    C.LoadFromJsonText('{"pids":[{"id":7,"name":"Wideband AFR","kind":"sensor","category":"sensors",' +
      '"sensor":"LC-1","field":"AFR1","units":"AFR","mci":"WBAFR"},' +
      '{"id":8,"name":"Broken","kind":"sensor","sensor":"LC-1"}]}');
    Assert.AreEqual(1, C.Count, 'a sensor PID without a field is left out');
    Assert.AreEqual(1, C.Warnings.Count);
    Assert.AreEqual(Ord(pkSensor), Ord(C[0].Kind));
    Assert.AreEqual(Ord(pcSensors), Ord(C[0].Category));
    Assert.AreEqual('LC-1', C[0].SensorName);
    Assert.AreEqual('afr1', C[0].SensorField, 'fields are lower case');
    Assert.AreEqual(1, C[0].TidyDecimals, 'AFR: one decimal');
    J := C.ToJson;
    try
      D.LoadFromJson(J);
    finally
      J.Free;
    end;
    Assert.AreEqual(0, D.Warnings.Count, D.Warnings.Text);
    Assert.AreEqual(C[0].Fingerprint, D[0].Fingerprint);
  finally
    C.Free;
    D.Free;
  end;
end;

procedure TSensorTests.ImportsASensorFile;
var
  S: TSensorCatalog;
  C: TPidCatalog;
  T: TSensorTemplate;
  Root: TJSONObject;
  Ids: TArray<Integer>;
  Name: string;
  Added: TPidDef;
  Raised: Boolean;
begin
  S := TSensorCatalog.Create;
  C := TPidCatalog.Create;
  try
    C.LoadFromJsonText('{"pids":[{"id":5,"name":"Old AFR","kind":"analog","analogChannel":1,"mci":"WBAFR"}]}');
    for T in SensorTemplates do
    begin
      Root := TJSONObject.ParseJSONValue(T.Json) as TJSONObject;
      Assert.IsNotNull(Root, T.Title + ': JSON');
      try
        Name := ImportSensorPackage(Root, S, C, Ids);
      finally
        Root.Free;
      end;
      Assert.IsTrue(Length(Ids) >= 1, T.Title + ': PIDs');
      for var Id in Ids do
        Assert.AreEqual(Name, C.FindById(Id).SensorName, T.Title);
    end;
    Assert.AreEqual(Length(SensorTemplates), S.Count);
    Assert.AreEqual(0, Length(C.Validate), 'the catalog is still fine');
    // The first template's AFR: a free id and MCI.
    Root := TJSONObject.ParseJSONValue(SensorTemplates[0].Json) as TJSONObject;
    try
      Name := ImportSensorPackage(Root, S, C, Ids);
    finally
      Root.Free;
    end;
    Assert.AreEqual('Wideband 2', Name, 'a taken name gets a number');
    Added := C.FindById(Ids[0]);
    Assert.AreEqual('afr1', Added.SensorField);
    Assert.IsTrue(Added.Mci.StartsWith('WBAFR') and (Added.Mci <> 'WBAFR'), Added.Mci);
    Assert.AreEqual('Simulator', S.Find('Demo wideband').Port);
    // Not a sensor file.
    Root := TJSONObject.ParseJSONValue('{"pids":[]}') as TJSONObject;
    try
      Raised := False;
      try
        ImportSensorPackage(Root, S, C, Ids);
      except
        on EConvertError do
          Raised := True;
      end;
      Assert.IsTrue(Raised, 'not a sensor file');
    finally
      Root.Free;
    end;
  finally
    S.Free;
    C.Free;
  end;
end;

procedure TSensorTests.SharesASensorFile;
var
  S, S2: TSensorCatalog;
  C, C2: TPidCatalog;
  D: TSensorDef;
  Root: TJSONObject;
  Ids: TArray<Integer>;
  Text: string;
begin
  S := TSensorCatalog.Create;
  C := TPidCatalog.Create;
  S2 := TSensorCatalog.Create;
  C2 := TPidCatalog.Create;
  try
    C.LoadFromJsonText('{"pids":[{"id":40,"name":"EGT 1","kind":"sensor","sensor":"EGT box","field":"egt",' +
      '"formula":"N0 * 9 / 5 + 32","units":"F"}]}');
    D := TSensorDef.Create;
    D.Name := 'EGT box';
    D.Protocol := spText;
    D.Port := 'COM12';
    D.Baud := 57600;
    S.Add(D);
    Root := SensorPackage(D, [C[0]]);
    try
      Assert.IsNull(Root.GetValue<TJSONObject>('sensor').FindValue('port'), 'the port is the receiver''s own');
      Text := Root.ToJSON;
    finally
      Root.Free;
    end;
    Root := TJSONObject.ParseJSONValue(Text) as TJSONObject; // as read from the file
    try
      Assert.AreEqual('EGT box', ImportSensorPackage(Root, S2, C2, Ids));
    finally
      Root.Free;
    end;
    Assert.AreEqual(57600, S2[0].Baud);
    Assert.AreEqual('', S2[0].Port);
    Assert.AreEqual(1, Length(Ids));
    Assert.AreEqual('N0 * 9 / 5 + 32', C2.FindById(Ids[0]).FormulaText);
    Assert.AreEqual('EGT box', C2.FindById(Ids[0]).SensorName);
  finally
    S.Free;
    C.Free;
    S2.Free;
    C2.Free;
  end;
end;

type
  TSensorScan = class
  public
    Catalog: TPidCatalog;
    Sensors: TSensorCatalog;
    Engine: TScanEngine;
    Events: TList<TEngineEvent>;
    State: TEngineState;
    constructor Create(const PidsJson: string);
    destructor Destroy; override;
    function WaitUntil(const Cond: TFunc<Boolean>; TimeoutMs: Integer = 8000): Boolean;
    procedure Connect;
    function ValueOf(const S: TLiveSnapshot; PidId: Integer): Double;
    function Messages: string;
  end;

constructor TSensorScan.Create(const PidsJson: string);
var
  D: TSensorDef;
begin
  Catalog := TPidCatalog.Create;
  Catalog.LoadFromJsonText(PidsJson);
  Assert.AreEqual(0, Catalog.Warnings.Count, Catalog.Warnings.Text);
  Sensors := TSensorCatalog.Create;
  D := TSensorDef.Create;
  D.Name := 'LC-1';
  D.Port := SensorSimulatorPort;
  Sensors.Add(D);
  D := TSensorDef.Create;
  D.Name := 'Box';
  D.Protocol := spText;
  D.Port := SensorSimulatorPort;
  Sensors.Add(D);
  Events := TList<TEngineEvent>.Create;
  Engine := TScanEngine.Create(Catalog,
    procedure(const Ev: TEngineEvent)
    begin
      Events.Add(Ev);
      if Ev.Kind = eeState then
        State := Ev.State;
    end, Sensors);
end;

destructor TSensorScan.Destroy;
begin
  Engine.Free;
  CheckSynchronize(0);
  Events.Free;
  Sensors.Free;
  Catalog.Free;
  inherited;
end;

function TSensorScan.WaitUntil(const Cond: TFunc<Boolean>; TimeoutMs: Integer): Boolean;
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

procedure TSensorScan.Connect;
var
  Cmd: TEngineCommand;
begin
  Cmd := Command(ecConnect);
  Cmd.Factory :=
    function: ISerialPort
    begin
      Result := TSimulatedAvt.Create;
    end;
  Engine.Post(Cmd);
  Assert.IsTrue(WaitUntil(function: Boolean begin Result := State = esConnected end), 'not connected');
end;

function TSensorScan.ValueOf(const S: TLiveSnapshot; PidId: Integer): Double;
var
  I: Integer;
begin
  for I := 0 to High(S.PidIds) do
    if S.PidIds[I] = PidId then
      Exit(S.Values[I]);
  Result := NaN;
end;

function TSensorScan.Messages: string;
var
  E: TEngineEvent;
begin
  Result := '';
  for E in Events do
    if E.Text <> '' then
      Result := Result + E.Text + sLineBreak;
end;

const
  ScanPids =
    '{"pids":[' +
    '{"id":1,"name":"ENGINE SPEED","shortName":"RPM","kind":"vehicle","pid":"000C","bytes":2,"formula":"((N1 << 8) +N2) *0.25","units":"RPM","mci":"RPM"},' +
    '{"id":50,"name":"Wideband AFR","kind":"sensor","sensor":"LC-1","field":"afr1","units":"AFR","mci":"WBAFR"},' +
    '{"id":51,"name":"Wideband lambda x 100","kind":"sensor","sensor":"LC-1","field":"lambda1","formula":"N0 * 100"},' +
    '{"id":52,"name":"EGT","kind":"sensor","sensor":"Box","field":"egt","units":"C"},' +
    '{"id":53,"name":"AFR error","kind":"calculated","formula":"%WBAFR% - 14.7"},' +
    '{"id":54,"name":"Nowhere","kind":"sensor","sensor":"Missing box","field":"1"}]}';

{ The simulated LC-1 warms up for 2 s, then reads; its values come in each
  cycle with the PCM's, through formulas and into calculated PIDs. }
procedure TSensorTests.ScansASimulatedWideband;
var
  T: TSensorScan;
  Cmd: TEngineCommand;
  S: TLiveSnapshot;
begin
  T := TSensorScan.Create(ScanPids);
  try
    T.Connect;
    Cmd := Command(ecStartScan);
    Cmd.PidIds := [1, 50, 51, 52, 53];
    T.Engine.Post(Cmd);
    Assert.IsTrue(T.WaitUntil(
      function: Boolean
      begin
        S := T.Engine.GetSnapshot;
        Result := (S.Cycles > 5) and not IsNan(T.ValueOf(S, 50)) and not IsNan(T.ValueOf(S, 52));
      end), 'no wideband values: ' + T.Messages);
    Assert.IsTrue(InRange(T.ValueOf(S, 1), 600, 6000), 'rpm still read');
    Assert.IsTrue(InRange(T.ValueOf(S, 50), 10, 18), 'afr');
    Assert.IsTrue(InRange(T.ValueOf(S, 51), 70, 125), 'lambda x 100');
    Assert.IsTrue(InRange(T.ValueOf(S, 52), 400, 900), 'egt');
    Assert.IsTrue(InRange(T.ValueOf(S, 53), -5, 4), 'calculated from the AFR');
    Assert.Contains(T.Messages, 'Sensor LC-1: Reading Simulator');
    Assert.Contains(T.Messages, 'Sensor LC-1: Reading Simulator: warming up', 'the warm-up was reported');
    T.Engine.Post(Command(ecStopScan));
    Assert.IsTrue(T.WaitUntil(function: Boolean begin Result := T.State = esConnected end), 'not stopped');
  finally
    T.Free;
  end;
end;

{ Only sensors ticked: the engine makes the cycles itself. }
procedure TSensorTests.ScansSensorsOnly;
var
  T: TSensorScan;
  Cmd: TEngineCommand;
  S: TLiveSnapshot;
  Clock: TStopwatch;
  C0: Int64;
begin
  T := TSensorScan.Create(ScanPids);
  try
    T.Connect;
    Cmd := Command(ecStartScan);
    Cmd.PidIds := [52];
    T.Engine.Post(Cmd);
    Assert.IsTrue(T.WaitUntil(
      function: Boolean
      begin
        S := T.Engine.GetSnapshot;
        Result := not IsNan(T.ValueOf(S, 52));
      end), 'no EGT: ' + T.Messages);
    C0 := S.Cycles;
    Clock := TStopwatch.StartNew;
    T.WaitUntil(function: Boolean begin Result := Clock.ElapsedMilliseconds >= 1000 end);
    S := T.Engine.GetSnapshot;
    Assert.IsTrue(InRange(S.Cycles - C0, 7, 12), Format('about 10 cycles a second (%d)', [S.Cycles - C0]));
    Assert.IsFalse(T.Messages.Contains('No data from the PCM'), T.Messages);
  finally
    T.Free;
  end;
end;

procedure TSensorTests.WarnsAboutAMissingSensor;
var
  T: TSensorScan;
  Cmd: TEngineCommand;
  S: TLiveSnapshot;
begin
  T := TSensorScan.Create(ScanPids);
  try
    T.Connect;
    Cmd := Command(ecStartScan);
    Cmd.PidIds := [1, 54];
    T.Engine.Post(Cmd);
    Assert.IsTrue(T.WaitUntil(
      function: Boolean
      begin
        S := T.Engine.GetSnapshot;
        Result := S.Cycles > 3;
      end), 'the scan did not run');
    Assert.IsTrue(IsNan(T.ValueOf(S, 54)));
    Assert.Contains(T.Messages, 'Nowhere reads the sensor "Missing box", which is not set up');
  finally
    T.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSensorTests);

end.
