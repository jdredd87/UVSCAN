unit UVScan.Tests.Json;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.JSON, DUnitX.TestFramework,
  UVScan.Pids, UVScan.Settings, UVScan.JsonFile;

type
  [TestFixture]
  TPidJsonTests = class
  public
    [Test] procedure CsvToJsonRoundTrip;
    [Test] procedure ReportsBadEntries;
    [Test] procedure SkipsDisabledEntries;
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
    [Test] procedure ImportsIni;
  end;

implementation

{ TPidJsonTests }

procedure TPidJsonTests.CsvToJsonRoundTrip;
var
  Lines: TStringList;
  Csv, Json: TPidCatalog;
  Root: TJSONObject;
  Text: string;
  I: Integer;
begin
  Lines := TStringList.Create;
  Csv := TPidCatalog.Create;
  Json := TPidCatalog.Create;
  try
    Lines.Add('Counter,Long Name,Desc,Formula,Units,Datalength,PID,group,shortname,Results,PidCat,txtMCI');
    Lines.Add('1,ENGINE SPEED,,((N1 << 8) +N2) *0.25,RPM,2,000C,1,RPM,,1,%RPM%');
    Lines.Add('3,"ECT, coolant",Engine coolant,N0-40,' + #$B0 + 'C,1,5,1,ECT,,1,%ECT%');
    Lines.Add('39,Inj Duty Cycle,,(%IPW% / (1 / ((%RPM% / 60 ) / 2) * 1000)) * 100,%,0,FPID,1,Inj DC,%f,6,%InjDutyCycle%');
    Lines.Add('17,AD2,,N0 * 0.0196,Volts,0,FFFE,1,AD2,%f,7,%AD2%');
    Csv.LoadFromCsvLines(Lines);
    Assert.AreEqual(4, Csv.Count);

    Root := Csv.ToJson;
    try
      Text := JsonText(Root);
    finally
      Root.Free;
    end;
    Json.LoadFromJsonText(Text);
    Assert.AreEqual('', Json.Warnings.Text);
    Assert.AreEqual(Csv.Count, Json.Count);
    for I := 0 to Csv.Count - 1 do
    begin
      Assert.AreEqual(Csv[I].Id, Json[I].Id);
      Assert.AreEqual(Csv[I].LongName, Json[I].LongName);
      Assert.AreEqual(Csv[I].ShortName, Json[I].ShortName);
      Assert.AreEqual(Csv[I].Description, Json[I].Description);
      Assert.AreEqual(Ord(Csv[I].Kind), Ord(Json[I].Kind));
      Assert.AreEqual(Ord(Csv[I].Category), Ord(Json[I].Category));
      Assert.AreEqual(Integer(Csv[I].PidNumber), Integer(Json[I].PidNumber));
      Assert.AreEqual(Csv[I].DataLength, Json[I].DataLength);
      Assert.AreEqual(Csv[I].AnalogChannel, Json[I].AnalogChannel);
      Assert.AreEqual(Csv[I].FormulaText, Json[I].FormulaText);
      Assert.AreEqual(Csv[I].Units, Json[I].Units);
      Assert.AreEqual(Csv[I].ResultFormat, Json[I].ResultFormat);
      Assert.AreEqual(Csv[I].Mci, Json[I].Mci);
      Assert.AreEqual(Csv[I].PidCode, Json[I].PidCode);
    end;
    Assert.AreEqual(Double(800), Json.FindById(1).Formula.Evaluate([$0C, $80], []), 1e-9);
    Assert.IsTrue(Pos('"kind": "analog"', Text) > 0);
    Assert.IsTrue(Pos('"pid": "0005"', Text) > 0);
  finally
    Json.Free;
    Csv.Free;
    Lines.Free;
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

procedure TSettingsTests.ImportsIni;
var
  S: TAppSettings;
begin
  TFile.WriteAllText(TempFile('settings.ini'),
    '[Connection]'#13#10'Port=COM9'#13#10'Baud=115200'#13#10 +
    '[Scan]'#13#10'Selected=1,2,12'#13#10 +
    '[Advanced]'#13#10'StreamRate=2'#13#10'Trace=1'#13#10 +
    '[Window]'#13#10'Left=5'#13#10'Top=6'#13#10'Width=900'#13#10'Height=600'#13#10'PidPanel=350'#13#10);
  S := TAppSettings.Create;
  try
    S.ImportIni(TempFile('settings.ini'));
    Assert.AreEqual('COM9', S.Port);
    Assert.AreEqual(3, Integer(Length(S.SelectedPids)));
    Assert.AreEqual(Ord(ssSlow), Ord(S.StreamSpeed));
    Assert.IsTrue(S.Trace);
    Assert.IsTrue(S.Window.Saved);
    Assert.AreEqual(350, S.Window.PidPanelWidth);
  finally
    S.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPidJsonTests);
  TDUnitX.RegisterTestFixture(TSettingsTests);

end.
