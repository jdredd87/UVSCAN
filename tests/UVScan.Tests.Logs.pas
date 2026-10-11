unit UVScan.Tests.Logs;

{ Log viewer data: reading UVScan CSV logs, the demo drive, and saved views. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.JSON, System.IOUtils, System.UITypes,
  DUnitX.TestFramework, UVScan.LogData, UVScan.LogViews, UVScan.Display, UVScan.JsonFile, UVScan.Defaults,
  UVScan.LogChart, UVScan.Pids, UVScan.PidLists;

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
    [Test] procedure LiveAppendKeepsTheLastMinutes;
    [Test] procedure PausedLiveChartKeepsItsSpan;
    [Test] procedure DecimalsForSteadyText;
  end;

  [TestFixture]
  TLogViewTests = class
  public
    [Test] procedure RoundTrip;
    [Test] procedure PutReplacesByName;
    [Test] procedure BuiltInViewsLoad;
    [Test] procedure BuiltInViewsFitTheirLists;
    [Test] procedure UpdateAddsNewBuiltIns;
  end;

implementation

procedure SameColor(Expected, Actual: TAlphaColor; const Msg: string = '');
begin
  Assert.AreEqual(IntToHex(Expected, 8), IntToHex(Actual, 8), Msg);
end;

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

{ The live chart paused (zoom, pan, cursor) while the scan is shorter than
  the span shown: the window stays as wide as it was, not the scan so far. }
procedure TLogDataTests.PausedLiveChartKeepsItsSpan;
var
  D: TLogData;
  C: TLogChart;
  I: Integer;
begin
  D := TLogData.Create;
  C := TLogChart.Create(nil);
  try
    D.StartLive('Live', ['RPM'], ['RPM'], [False]);
    for I := 0 to 300 do
      D.Append(5 + I / 10, [800 + I], 15 * 60); // 30 s of scan, from 5 s
    C.Live := True;
    C.LiveSpan := 60;
    C.SetData(D);
    C.Follow := True;
    Assert.AreEqual(5.0, C.WindowStart, 1E-9, 'follow: from the start');
    Assert.AreEqual(65.0, C.WindowEnd, 1E-9, 'follow: a full span');
    C.Zoom(1, 20); // as a pan or a pause does: the same window again
    Assert.IsFalse(C.Follow, 'paused');
    Assert.AreEqual(5.0, C.WindowStart, 1E-9, 'paused: start kept');
    Assert.AreEqual(65.0, C.WindowEnd, 1E-9, 'paused: span kept');
    C.Zoom(0.5, 20); // zooming in still works
    Assert.AreEqual(30.0, C.WindowEnd - C.WindowStart, 1E-9);
    // A log (not live) still fits its data.
    C.Live := False;
    C.SetData(D);
    C.Zoom(2, 20);
    Assert.AreEqual(5.0, C.WindowStart, 1E-9);
    Assert.AreEqual(35.0, C.WindowEnd, 1E-9);
  finally
    C.Free;
    D.Free;
  end;
end;

{ The channel list shows each channel with fixed decimals (steady width). }
procedure TLogDataTests.DecimalsForSteadyText;
begin
  Assert.AreEqual(0, DecimalsNeeded([195, 196, NaN, 210], 4), 'whole numbers');
  Assert.AreEqual(1, DecimalsNeeded([14.1, 14, 13.9], 3));
  Assert.AreEqual(2, DecimalsNeeded([1948, 1945.25, 1941.5], 3), 'rpm in quarters');
  Assert.AreEqual(3, DecimalsNeeded([0.125, 1], 2));
  Assert.AreEqual(3, DecimalsNeeded([1 / 3], 1), 'at most 3');
  Assert.AreEqual(0, DecimalsNeeded([1, 2.5], 1), 'only the first Count');
  Assert.AreEqual(0, DecimalsNeeded(nil, 0));
end;

{ TLogViewTests }

procedure TLogDataTests.LiveAppendKeepsTheLastMinutes;
var
  D: TLogData;
  I: Integer;
  V: Double;
begin
  D := TLogData.Create;
  try
    D.StartLive('Live', ['RPM', 'Fan'], ['RPM', ''], [False, True]);
    Assert.AreEqual(0, D.Count);
    Assert.AreEqual(2, D.ChannelCount);
    Assert.IsTrue(D.Channels[1].IsSwitch);
    Assert.IsTrue(IsNan(D.Channels[0].MinValue));
    // 10 samples a second for 100 s, keeping 30 s
    for I := 0 to 999 do
    begin
      if I = 5 then
        V := NaN
      else
        V := 1000 + I;
      D.Append(I / 10, [V, I mod 2], 30);
    end;
    Assert.AreEqual(99.9, D.Times[D.Count - 1], 1E-9, 'newest kept');
    Assert.IsTrue(D.Times[0] <= 99.9 - 30, 'at least the last 30 s');
    Assert.IsTrue(D.Times[0] > 99.9 - 30 * 1.5, 'old samples dropped (in chunks)');
    Assert.AreEqual(1999.0, D.Channels[0].MaxValue, 1E-9);
    Assert.AreEqual(1000 + D.Times[0] * 10, D.Channels[0].MinValue, 1E-6, 'min of what is kept');
    Assert.AreEqual(D.Times[0], D.Times[D.IndexAt(D.Times[0])], 1E-9);
    Assert.AreEqual(D.Count - 1, D.IndexAt(1000));
    // a sample older than the last one is ignored
    I := D.Count;
    D.Append(50, [1, 1], 30);
    Assert.AreEqual(I, D.Count);
  finally
    D.Free;
  end;
end;

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
    Lvl.RowColor := TAlphaColors.Red;
    C.Levels := [Lvl];
    V.Channels := V.Channels + [C];
    L.Put(V);
    L.LastView := 'Knock';
    L.LiveSpan := 300;
    Root := L.ToJson;
    try
      L2.LoadFromJson(Root);
    finally
      Root.Free;
    end;
    Assert.AreEqual(1, L2.Count);
    Assert.AreEqual('Knock', L2.LastView);
    Assert.AreEqual(300.0, L2.LiveSpan, 1E-9);
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
    SameColor(TAlphaColors.Red, (Got.Channels[1].Levels[0].RowColor));
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

{ What a live scan charts: every channel of a built-in view is a PID of the
  built-in catalog (by its short name, as the live chart names them), and a
  view named like a built-in scan list only charts PIDs of that list. }
procedure TLogViewTests.BuiltInViewsFitTheirLists;
var
  Views: TLogViewList;
  Lists: TPidLists;
  Catalog: TPidCatalog;
  Root: TJSONObject;
  V: TLogView;
  C: TChannelStyle;
  Names: TStringList;
  I, L, Id: Integer;
  P: TPidDef;
begin
  Views := TLogViewList.Create;
  Lists := TPidLists.Create;
  Catalog := TPidCatalog.Create;
  Names := TStringList.Create;
  Root := ParseJsonObject(DefaultLogViewsJson, 'logviews.json');
  try
    Views.LoadFromJson(Root);
    Lists.LoadFromJsonText(DefaultListsJson);
    Catalog.LoadFromJsonText(DefaultPidsJson);
    Assert.IsTrue(Views.Count >= 10);
    Assert.AreEqual(Views.Count, Integer(Length(Views.BuiltIns)), 'every built-in view is listed in builtIns');
    Assert.AreEqual(Lists.Count, Integer(Length(Lists.BuiltIns)), 'every built-in list is listed in builtIns');
    for I := 0 to Views.Count - 1 do
    begin
      V := Views[I];
      Names.Clear;
      L := Lists.IndexOf(V.Name);
      if L >= 0 then
        for Id in Lists[L].PidIds do
        begin
          P := Catalog.FindById(Id);
          Assert.IsNotNull(P, Format('list "%s": no PID %d', [V.Name, Id]));
          Names.Add(P.DisplayName);
        end
      else
        for Id := 0 to Catalog.Count - 1 do
          Names.Add(Catalog[Id].DisplayName);
      for C in V.Channels do
        Assert.IsTrue(Names.IndexOf(C.Name) >= 0, Format('view "%s": %s', [V.Name, C.Name]));
    end;
  finally
    Root.Free;
    Names.Free;
    Catalog.Free;
    Lists.Free;
    Views.Free;
  end;
end;

{ An install from before the built-ins grew: it gets the new lists and views,
  the old broken Knock check is fixed, a list of its own is not touched, and
  running it again changes nothing. }
procedure TLogViewTests.UpdateAddsNewBuiltIns;
var
  Dir, PidsName, ListsName, ViewsName: string;
  Added: TArray<string>;
  Lists: TPidLists;
  Views: TLogViewList;
  K: Integer;
begin
  Dir := TPath.Combine(TPath.GetTempPath, 'UVScanBuiltIns' + IntToStr(Random(1000000)));
  ForceDirectories(Dir);
  PidsName := TPath.Combine(Dir, 'pids.json');
  ListsName := TPath.Combine(Dir, 'lists.json');
  ViewsName := TPath.Combine(Dir, 'logviews.json');
  Lists := TPidLists.Create;
  Views := TLogViewList.Create;
  try
    TFile.WriteAllText(PidsName, DefaultPidsJson);
    TFile.WriteAllText(ListsName,
      '{"version":1,"lists":[{"name":"Basic engine","pids":[1,3]},{"name":"Idle","pids":[1]}]}');
    TFile.WriteAllText(ViewsName,
      '{"version":1,"views":[{"name":"Knock check","channels":[{"name":"RPM"},{"name":"TPS"},{"name":"MAP"},' +
      '{"name":"KR"}]},{"name":"Mine","channels":[{"name":"RPM"}]}]}');
    Added := AddNewBuiltInsTo(PidsName, ListsName, ViewsName);
    Assert.IsTrue(Length(Added) > 5, string.Join(', ', Added));

    Lists.LoadFromFile(ListsName);
    Assert.IsTrue(Lists.IndexOf('Fuel trims') >= 0);
    Assert.IsTrue(Lists.IndexOf('Misfires') < 0, 'the first built-ins were offered already (deleted here)');
    Assert.AreEqual(1, Integer(Length(Lists[Lists.IndexOf('Idle')].PidIds)), 'a list of its own stays');
    Assert.AreEqual(2, Integer(Length(Lists[Lists.IndexOf('Basic engine')].PidIds)));

    Views.LoadFromFile(ViewsName);
    Assert.IsTrue(Views.IndexOf('Fuel trims') >= 0);
    Assert.IsTrue(Views.IndexOf('Mine') >= 0);
    K := Views.IndexOf('Knock check');
    Assert.IsTrue(Views[K].IndexOf('TP %') >= 0, 'Knock check fixed');
    Assert.IsTrue(Views.IndexOf('MPH vs RPM vs IAT') < 0, 'the first built-ins were offered already');

    // Deleted after the update: stays deleted.
    Views.Delete(Views.IndexOf('Fuel trims'));
    Views.SaveToFile(ViewsName);
    Added := AddNewBuiltInsTo(PidsName, ListsName, ViewsName);
    Assert.AreEqual(0, Integer(Length(Added)), string.Join(', ', Added));
    Views.LoadFromFile(ViewsName);
    Assert.IsTrue(Views.IndexOf('Fuel trims') < 0);
  finally
    Views.Free;
    Lists.Free;
    TDirectory.Delete(Dir, True);
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
    // the views for what the demo drive has show all of it there
    D.MakeDemo;
    for var I := 0 to L.Count - 1 do
    begin
      V := L[I];
      if not SameText(V.Name, 'MPH vs RPM vs IAT') then
        Continue;
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
