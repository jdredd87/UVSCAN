unit UVScan.Tests.Json;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.JSON, DUnitX.TestFramework,
  UVScan.Pids, UVScan.Dtc, UVScan.Settings, UVScan.JsonFile;

type
  [TestFixture]
  TPidJsonTests = class
  public
    [Test] procedure RoundTrip;
    [Test] procedure ReportsBadEntries;
    [Test] procedure SkipsDisabledEntries;
  end;

  [TestFixture]
  TDtcJsonTests = class
  public
    [Test] procedure LoadsAndDescribes;
    [Test] procedure RoundTrip;
  end;

  [TestFixture]
  TSettingsTests = class
  private
    FDir: string;
    function TempFile(const Name: string): string;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure SaveAndLoadRoundTrip;
    [Test] procedure MissingFileGivesDefaults;
    [Test] procedure CorruptFileIsSetAside;
    [Test] procedure PartialFileKeepsDefaults;
  end;

implementation

{ TPidJsonTests }

procedure TPidJsonTests.RoundTrip;
const
  Source =
    '{"version":1,"pids":[' +
    '{"id":1,"name":"ENGINE SPEED","shortName":"RPM","kind":"vehicle","category":"engine","pid":"000C","bytes":2,"formula":"((N1 << 8) +N2) *0.25","units":"RPM","mci":"RPM"},' +
    '{"id":3,"name":"ECT, coolant","description":"Engine coolant \"hot\"","kind":"vehicle","category":"engine","pid":"0005","bytes":1,"formula":"N0-40","units":"\u00B0C","mci":"ECT"},' +
    '{"id":39,"name":"Inj Duty Cycle","shortName":"Inj DC","kind":"calculated","category":"calculated","formula":"(%IPW% / (1 / ((%RPM% / 60 ) / 2) * 1000)) * 100","units":"%","format":"%f","mci":"InjDutyCycle"},' +
    '{"id":17,"name":"AD2","kind":"analog","category":"analog","analogChannel":2,"formula":"N0 * 0.0196","units":"Volts","format":"%f","mci":"AD2"}]}';
var
  A, B: TPidCatalog;
  Root: TJSONObject;
  Text: string;
  I: Integer;
begin
  A := TPidCatalog.Create;
  B := TPidCatalog.Create;
  try
    A.LoadFromJsonText(Source);
    Assert.AreEqual(4, A.Count);
    Assert.AreEqual(0, A.Warnings.Count, A.Warnings.Text);
    Assert.AreEqual(#$B0'C', A.FindById(3).Units);
    Assert.AreEqual('Engine coolant "hot"', A.FindById(3).Description);

    Root := A.ToJson;
    try
      Text := JsonText(Root);
    finally
      Root.Free;
    end;
    B.LoadFromJsonText(Text);
    Assert.AreEqual('', B.Warnings.Text);
    Assert.AreEqual(A.Count, B.Count);
    for I := 0 to A.Count - 1 do
    begin
      Assert.AreEqual(A[I].Id, B[I].Id);
      Assert.AreEqual(A[I].LongName, B[I].LongName);
      Assert.AreEqual(A[I].ShortName, B[I].ShortName);
      Assert.AreEqual(A[I].Description, B[I].Description);
      Assert.AreEqual(Ord(A[I].Kind), Ord(B[I].Kind));
      Assert.AreEqual(Ord(A[I].Category), Ord(B[I].Category));
      Assert.AreEqual(Integer(A[I].PidNumber), Integer(B[I].PidNumber));
      Assert.AreEqual(A[I].DataLength, B[I].DataLength);
      Assert.AreEqual(A[I].AnalogChannel, B[I].AnalogChannel);
      Assert.AreEqual(A[I].FormulaText, B[I].FormulaText);
      Assert.AreEqual(A[I].Units, B[I].Units);
      Assert.AreEqual(A[I].ResultFormat, B[I].ResultFormat);
      Assert.AreEqual(A[I].Mci, B[I].Mci);
      Assert.AreEqual(A[I].PidCode, B[I].PidCode);
    end;
    Assert.AreEqual(Double(800), B.FindById(1).Formula.Evaluate([$0C, $80], []), 1e-9);
    Assert.IsTrue(Pos('"kind": "analog"', Text) > 0);
    Assert.IsTrue(Pos('"pid": "0005"', Text) > 0);
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TPidJsonTests.ReportsBadEntries;
var
  C: TPidCatalog;
begin
  C := TPidCatalog.Create;
  try
    C.LoadFromJsonText(
      '{"version":1,"pids":[' +
      '{"id":1,"name":"Good","kind":"vehicle","pid":"000C","bytes":2,"formula":"N1"},' +
      '{"id":1,"name":"Duplicate","kind":"vehicle","pid":"000D","bytes":1},' +
      '{"id":2,"name":"Bad pid","kind":"vehicle","pid":"XYZ","bytes":1},' +
      '{"id":3,"name":"Bad kind","kind":"magic"},' +
      '{"id":4,"name":"Bad bytes","kind":"vehicle","pid":"0010","bytes":7},' +
      '{"id":5,"name":"Bad channel","kind":"analog","analogChannel":9},' +
      '{"id":6,"name":"Bad formula","kind":"calculated","formula":"(1 +"},' +
      '{"id":7,"name":"Odd category","kind":"calculated","category":"spaceship","formula":"1"},' +
      '"not an object"]}');
    Assert.AreEqual(3, C.Count, C.Warnings.Text); // Good, Bad formula (kept, shows --), Odd category
    Assert.AreEqual(8, C.Warnings.Count, C.Warnings.Text);
    Assert.AreEqual(Ord(pcOther), Ord(C.FindById(7).Category));
  finally
    C.Free;
  end;
end;

procedure TPidJsonTests.SkipsDisabledEntries;
var
  C: TPidCatalog;
begin
  C := TPidCatalog.Create;
  try
    C.LoadFromJsonText('{"pids":[{"id":1,"name":"On","kind":"calculated","formula":"1"},' +
      '{"id":2,"name":"Off","kind":"calculated","formula":"1","enabled":false}]}');
    Assert.AreEqual(1, C.Count);
    Assert.AreEqual(0, C.Warnings.Count);
  finally
    C.Free;
  end;
end;

{ TSettingsTests }

procedure TSettingsTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'uvscan_settings_test_' + IntToStr(Random(1000000)));
  ForceDirectories(FDir);
end;

procedure TSettingsTests.TearDown;
begin
  TDirectory.Delete(FDir, True);
end;

function TSettingsTests.TempFile(const Name: string): string;
begin
  Result := TPath.Combine(FDir, Name);
end;

procedure TSettingsTests.SaveAndLoadRoundTrip;
var
  A, B: TAppSettings;
  Problem: string;
begin
  A := TAppSettings.Create;
  B := TAppSettings.Create;
  try
    A.Port := 'COM9';
    A.Baud := 57600;
    A.SelectedPids := [1, 3, 12];
    A.StreamSpeed := ssMedium;
    A.LogFolder := 'D:\Logs\UVScan "car"';
    A.Trace := True;
    A.Window.Left := 10;
    A.Window.Top := 20;
    A.Window.Width := 1000;
    A.Window.Height := 700;
    A.Window.Maximized := True;
    A.Window.PidPanelWidth := 380;
    A.Window.Saved := True;
    A.SaveToFile(TempFile('settings.json'));
    Assert.IsFalse(FileExists(TempFile('settings.json.tmp')));

    B.LoadFromFile(TempFile('settings.json'), Problem);
    Assert.AreEqual('', Problem);
    Assert.AreEqual('COM9', B.Port);
    Assert.AreEqual(57600, B.Baud);
    Assert.AreEqual(3, Integer(Length(B.SelectedPids)));
    Assert.AreEqual(12, B.SelectedPids[2]);
    Assert.AreEqual(Ord(ssMedium), Ord(B.StreamSpeed));
    Assert.AreEqual(A.LogFolder, B.LogFolder);
    Assert.IsTrue(B.Trace);
    Assert.IsTrue(B.Window.Saved);
    Assert.AreEqual(1000, B.Window.Width);
    Assert.IsTrue(B.Window.Maximized);
    Assert.AreEqual(380, B.Window.PidPanelWidth);
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TSettingsTests.MissingFileGivesDefaults;
var
  S: TAppSettings;
  Problem: string;
begin
  S := TAppSettings.Create;
  try
    S.LoadFromFile(TempFile('nope.json'), Problem);
    Assert.AreEqual('', Problem);
    Assert.AreEqual(115200, S.Baud);
    Assert.AreEqual(Ord(ssFast), Ord(S.StreamSpeed));
    Assert.IsFalse(S.Window.Saved);
  finally
    S.Free;
  end;
end;

procedure TSettingsTests.CorruptFileIsSetAside;
var
  S: TAppSettings;
  Problem: string;
begin
  TFile.WriteAllText(TempFile('settings.json'), '{ "connection": { "port": "COM9", ');
  S := TAppSettings.Create;
  try
    S.LoadFromFile(TempFile('settings.json'), Problem);
    Assert.IsTrue(Problem <> '');
    Assert.IsFalse(FileExists(TempFile('settings.json')));
    Assert.IsTrue(FileExists(TempFile('settings.json.bad')));
    Assert.AreEqual('', S.Port);
  finally
    S.Free;
  end;
end;

procedure TSettingsTests.PartialFileKeepsDefaults;
var
  S: TAppSettings;
  Problem: string;
begin
  TFile.WriteAllText(TempFile('settings.json'), '{ "connection": { "port": "COM3" }, "scan": { "streamSpeed": "warp" } }');
  S := TAppSettings.Create;
  try
    S.LoadFromFile(TempFile('settings.json'), Problem);
    Assert.AreEqual('', Problem);
    Assert.AreEqual('COM3', S.Port);
    Assert.AreEqual(115200, S.Baud);
    Assert.AreEqual(Ord(ssFast), Ord(S.StreamSpeed));
  finally
    S.Free;
  end;
end;

{ TDtcJsonTests }

procedure TDtcJsonTests.LoadsAndDescribes;
var
  C: TDtcCatalog;
begin
  C := TDtcCatalog.Create;
  try
    C.LoadFromJsonText('{"version":1,"dtcs":[{"code":"P0300","description":"Random Misfire Detected"},' +
      '{"code":"p0171","description":"System Too Lean, Bank 1"},{"description":"no code"},"junk"]}');
    Assert.AreEqual(2, C.Count);
    Assert.AreEqual(2, C.Warnings.Count, C.Warnings.Text);
    Assert.AreEqual('System Too Lean, Bank 1', C.Describe('P0171'));
    Assert.AreEqual('Random Misfire Detected', C.Describe('p0300'));
    Assert.AreEqual('', C.Describe('P9999'));
  finally
    C.Free;
  end;
end;

procedure TDtcJsonTests.RoundTrip;
var
  A, B: TDtcCatalog;
  Root: TJSONObject;
begin
  A := TDtcCatalog.Create;
  B := TDtcCatalog.Create;
  try
    A.AddOrSet('P0300', 'Random Misfire Detected');
    A.AddOrSet('U0100', 'Lost Communication With ECM/PCM "A"');
    Root := A.ToJson;
    try
      B.LoadFromJsonText(JsonText(Root));
    finally
      Root.Free;
    end;
    Assert.AreEqual(2, B.Count);
    Assert.AreEqual('Lost Communication With ECM/PCM "A"', B.Describe('U0100'));
  finally
    A.Free;
    B.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPidJsonTests);
  TDUnitX.RegisterTestFixture(TDtcJsonTests);
  TDUnitX.RegisterTestFixture(TSettingsTests);

end.
