unit UVScan.Tests.Logs;

{ Log viewer data: reading UVScan CSV logs, the demo drive, and saved views. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.JSON, System.IOUtils, System.UITypes, Vcl.Graphics,
  DUnitX.TestFramework, UVScan.LogData, UVScan.LogViews, UVScan.Display, UVScan.JsonFile, UVScan.Defaults;

type
  [TestFixture]
  TLogDataTests = class
  public
    [Test] procedure ReadsAUVScanLog;
    [Test] procedure SwitchesAndMissingValues;
    [Test] procedure SkipsBrokenRows;
    [Test] procedure RejectsOtherFiles;
    [Test] procedure FindsSamplesByTime;
    [Test] procedure CsvAndHeaderSplitting;
    [Test] procedure DemoDriveIsPlausible;
    [Test] procedure SaveAndReload;
  end;

  [TestFixture]
  TLogViewTests = class
  public
    [Test] procedure RoundTrip;
    [Test] procedure PutReplacesByName;
    [Test] procedure BuiltInViewsLoad;
  end;

implementation

function Lines(const S: array of string): TStringList;
var
  L: string;
begin
  Result := TStringList.Create;
  for L in S do
    Result.Add(L);
end;

procedure TLogDataTests.ReadsAUVScanLog;
var
  D: TLogData;
  L: TStringList;
begin
  D := TLogData.Create;
  L := Lines([#$FEFF'Time (s),RPM (RPM),MAF(g/s) (g/s),Runtime,ECT (Deg C)',
    '0.023,800,4.5,--,-39', '0.123,812.25,4.6,1,-38']);
  try
    D.LoadFromStrings(L, 'test');
    Assert.AreEqual(2, D.Count);
    Assert.AreEqual(4, D.ChannelCount);
    Assert.AreEqual('RPM', D.Channels[0].Name);
    Assert.AreEqual('RPM', D.Channels[0].Units);
    Assert.AreEqual('MAF(g/s)', D.Channels[1].Name, 'units only from the last " (...)"');
    Assert.AreEqual('Runtime', D.Channels[2].Name);
    Assert.AreEqual('', D.Channels[2].Units);
    Assert.AreEqual(812.25, D.Channels[0].Values[1], 1E-9);
    Assert.IsTrue(IsNan(D.Channels[2].Values[0]));
    Assert.AreEqual(-39.0, D.Channels[3].MinValue, 1E-9);
    Assert.AreEqual(-38.0, D.Channels[3].MaxValue, 1E-9);
    Assert.AreEqual(0.1, D.Duration, 1E-9);
    Assert.AreEqual(3, D.IndexOfChannel('ECT (Deg C)'), 'by caption too');
  finally
    L.Free;
    D.Free;
  end;
end;

procedure TLogDataTests.SwitchesAndMissingValues;
var
  D: TLogData;
  L: TStringList;
begin
  D := TLogData.Create;
  L := Lines(['Time (s),Fan,A/C', '0,ON,NO', '0.1,OFF,YES', '0.2', '0.3,--,']);
  try
    D.LoadFromStrings(L, 'test');
    Assert.AreEqual(4, D.Count);
    Assert.IsTrue(D.Channels[0].IsSwitch);
    Assert.AreEqual(1.0, D.Channels[0].Values[0], 1E-9);
    Assert.AreEqual(0.0, D.Channels[0].Values[1], 1E-9);
    Assert.AreEqual(1.0, D.Channels[1].Values[1], 1E-9);
    Assert.IsTrue(IsNan(D.Channels[0].Values[2]), 'short row');
    Assert.IsTrue(IsNan(D.Channels[1].Values[3]), 'empty field');
  finally
    L.Free;
    D.Free;
  end;
end;

procedure TLogDataTests.SkipsBrokenRows;
var
  D: TLogData;
  L: TStringList;
begin
  D := TLogData.Create;
  L := Lines(['Time (s),RPM (RPM)', '0,800', 'garbage,1', '', '0.1,810', '0.05,999', '0.2,"8,20"']);
  try
    D.LoadFromStrings(L, 'test');
    Assert.AreEqual(3, D.Count);
    Assert.AreEqual(2, D.Skipped, 'bad time and time going backwards');
    Assert.IsTrue(IsNan(D.Channels[0].Values[2]), '"8,20" is not a number');
  finally
    L.Free;
    D.Free;
  end;
end;

procedure TLogDataTests.RejectsOtherFiles;
var
  D: TLogData;
  L: TStringList;
  Raised: Boolean;
begin
  D := TLogData.Create;
  L := Lines(['Id,Name,PID', '1,RPM,000C']);
  try
    Raised := False;
    try
      D.LoadFromStrings(L, 'pids.csv');
    except
      on ELogError do
        Raised := True;
    end;
    Assert.IsTrue(Raised);
  finally
    L.Free;
    D.Free;
  end;
end;

procedure TLogDataTests.FindsSamplesByTime;
var
  D: TLogData;
  L: TStringList;
begin
  D := TLogData.Create;
  L := Lines(['Time (s),X', '1,10', '2,20', '3,30', '4,40']);
  try
    D.LoadFromStrings(L, 'test');
    Assert.AreEqual(0, D.IndexAt(0));
    Assert.AreEqual(0, D.IndexAt(1));
    Assert.AreEqual(0, D.IndexAt(1.99));
    Assert.AreEqual(1, D.IndexAt(2));
    Assert.AreEqual(2, D.IndexAt(3.5));
    Assert.AreEqual(3, D.IndexAt(99));
  finally
    L.Free;
    D.Free;
  end;
end;

procedure TLogDataTests.CsvAndHeaderSplitting;
var
  F: TArray<string>;
  N, U: string;
  Sw: Boolean;
begin
  F := SplitCsvLine('a,"b,c","d ""q""",');
  Assert.AreEqual(4, Integer(Length(F)));
  Assert.AreEqual('b,c', F[1]);
  Assert.AreEqual('d "q"', F[2]);
  Assert.AreEqual('', F[3]);
  SplitHeader('IGN V (V)', N, U);
  Assert.AreEqual('IGN V', N);
  Assert.AreEqual('V', U);
  SplitHeader('Time (s)', N, U);
  Assert.AreEqual('s', U);
  Assert.AreEqual(12.5, ParseLogValue(' 12.5 ', Sw), 1E-9);
  Assert.IsFalse(Sw);
  Assert.IsTrue(IsNan(ParseLogValue('--', Sw)));
  Assert.AreEqual('1:05.5', FormatLogTime(65.5));
end;

procedure TLogDataTests.DemoDriveIsPlausible;
var
  D: TLogData;
  Rpm, Mph, Kr, Ect: Integer;
begin
  D := TLogData.Create;
  try
    D.MakeDemo;
    Assert.AreEqual(6000, D.Count);
    Assert.AreEqual(599.9, D.Duration, 1E-6);
    Rpm := D.IndexOfChannel('RPM');
    Mph := D.IndexOfChannel('MPH');
    Kr := D.IndexOfChannel('KR');
    Ect := D.IndexOfChannel('ECT');
    Assert.IsTrue((Rpm >= 0) and (Mph >= 0) and (Kr >= 0) and (Ect >= 0));
    Assert.IsTrue(D.Channels[Rpm].MinValue > 500, 'idles, never stalls');
    Assert.IsTrue(D.Channels[Rpm].MaxValue < 7000);
    Assert.IsTrue(D.Channels[Mph].MaxValue > 90, 'the hard pull');
    Assert.AreEqual(0.0, D.Channels[Mph].Values[0], 1E-9, 'starts parked');
    Assert.IsTrue(D.Channels[Kr].MaxValue >= 2, 'some knock to see');
    Assert.IsTrue(D.Channels[Ect].MaxValue > D.Channels[Ect].Values[0] + 50, 'warms up');
  finally
    D.Free;
  end;
end;

procedure TLogDataTests.SaveAndReload;
var
  A, B: TLogData;
  F: string;
begin
  A := TLogData.Create;
  B := TLogData.Create;
  F := TPath.Combine(TPath.GetTempPath, 'uvscan_logtest.csv');
  try
    A.MakeDemo;
    A.SaveToFile(F);
    B.LoadFromFile(F);
    Assert.AreEqual(A.Count, B.Count);
    Assert.AreEqual(A.ChannelCount, B.ChannelCount);
    Assert.AreEqual(0, B.Skipped);
    Assert.AreEqual(A.Channels[0].Values[1234], B.Channels[0].Values[1234], 1E-3);
    Assert.AreEqual(A.Channels[0].Caption, B.Channels[0].Caption);
  finally
    System.SysUtils.DeleteFile(F);
    A.Free;
    B.Free;
  end;
end;

{ TLogViewTests }

procedure TLogViewTests.RoundTrip;
var
  L, L2: TLogViewList;
  V, Got: TLogView;
  C: TChannelStyle;
  Lvl: TDisplayLevel;
  Root: TJSONObject;
begin
  L := TLogViewList.Create;
  L2 := TLogViewList.Create;
  V := TLogView.Create;
  try
    V.Name := 'Knock';
    V.Mode := cmOverlay;
    V.UseDisplayLevels := False;
    C := DefaultChannelStyle('RPM', 0);
    C.Width := 3;
    V.Channels := V.Channels + [C];
    C := DefaultChannelStyle('KR', 1);
    C.AutoScale := False;
    C.MinValue := 0;
    C.MaxValue := 10;
    C.LevelColors := True;
    C.Visible := False;
    Lvl := NewLevel;
    Lvl.Value := 2;
    Lvl.RowColor := clRed;
    C.Levels := [Lvl];
    V.Channels := V.Channels + [C];
    L.Put(V);
    L.LastView := 'Knock';
    Root := L.ToJson;
    try
      L2.LoadFromJson(Root);
    finally
      Root.Free;
    end;
    Assert.AreEqual(1, L2.Count);
    Assert.AreEqual('Knock', L2.LastView);
    Got := L2[0];
    Assert.IsTrue(Got.Mode = cmOverlay);
    Assert.IsFalse(Got.UseDisplayLevels);
    Assert.AreEqual(2, Integer(Length(Got.Channels)));
    Assert.AreEqual(3, Got.Channels[0].Width);
    Assert.IsTrue(Got.Channels[0].AutoScale);
    Assert.IsFalse(Got.Channels[1].AutoScale);
    Assert.AreEqual(10.0, Got.Channels[1].MaxValue, 1E-9);
    Assert.IsFalse(Got.Channels[1].Visible);
    Assert.IsTrue(Got.Channels[1].LevelColors);
    Assert.AreEqual(1, Integer(Length(Got.Channels[1].Levels)));
    Assert.AreEqual(Integer(clRed), Integer(Got.Channels[1].Levels[0].RowColor));
    Assert.AreEqual(1, Got.IndexOf('kr'));
  finally
    V.Free;
    L.Free;
    L2.Free;
  end;
end;

procedure TLogViewTests.PutReplacesByName;
var
  L: TLogViewList;
  V: TLogView;
begin
  L := TLogViewList.Create;
  V := TLogView.Create;
  try
    V.Name := 'A';
    L.Put(V);
    V.Mode := cmShared;
    V.Name := 'a';
    L.Put(V);
    Assert.AreEqual(1, L.Count);
    Assert.IsTrue(L[0].Mode = cmShared);
    L.Delete(0);
    Assert.AreEqual(0, L.Count);
  finally
    V.Free;
    L.Free;
  end;
end;

procedure TLogViewTests.BuiltInViewsLoad;
var
  L: TLogViewList;
  Root: TJSONObject;
  D: TLogData;
  V: TLogView;
  Name: string;
begin
  L := TLogViewList.Create;
  D := TLogData.Create;
  Root := ParseJsonObject(DefaultLogViewsJson, 'logviews.json');
  try
    L.LoadFromJson(Root);
    Assert.IsTrue(L.Count >= 2);
    Assert.IsTrue(L.IndexOf(L.LastView) >= 0);
    // every channel the built-in views name exists in the demo drive
    D.MakeDemo;
    for var I := 0 to L.Count - 1 do
    begin
      V := L[I];
      for var C in V.Channels do
      begin
        Name := C.Name;
        Assert.IsTrue(D.IndexOfChannel(Name) >= 0, V.Name + ': ' + Name);
      end;
    end;
  finally
    Root.Free;
    D.Free;
    L.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLogDataTests);
  TDUnitX.RegisterTestFixture(TLogViewTests);

end.
