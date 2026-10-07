unit UVScan.Tests.Display;

{ Display levels (colours / flash / sound rules), display.json, gauge zones
  and the alert sound timing. }

interface

uses
  System.SysUtils, System.Math, System.UITypes, System.JSON, Vcl.Graphics, DUnitX.TestFramework,
  UVScan.Display, UVScan.Alerts, UVScan.Defaults, UVScan.JsonFile;

type
  [TestFixture]
  TDisplayTests = class
  private
    function KnockSettings: TDisplaySettings;
  public
    [Test] procedure FirstMatchingLevelWins;
    [Test] procedure AllOperators;
    [Test] procedure FlashShowsNormalLookInOffPhase;
    [Test] procedure ColorsAsHex;
    [Test] procedure JsonRoundTrip;
    [Test] procedure BadEntriesAreReported;
    [Test] procedure PutDropsAllDefaultEntries;
    [Test] procedure ZonesFromLevels;
    [Test] procedure BuiltInDefaultsLoad;
  end;

  [TestFixture]
  TAlertTrackerTests = class
  public
    [Test] procedure SoundsOnEnterNotWhileStaying;
    [Test] procedure RepeatsWhileActive;
    [Test] procedure HoveringOnAThresholdDoesNotSpam;
  end;

implementation

const
  Kr = 14;
  Red = TColor($005050FF);
  Amber = TColor($0080E6FF);
  Green = TColor($00C8F0C8);

function Level(const Name: string; Op: TCompareOp; const Value: Double; Row: TColor): TDisplayLevel;
begin
  Result := NewLevel;
  Result.Name := Name;
  Result.Op := Op;
  Result.Value := Value;
  Result.RowColor := Row;
end;

function TDisplayTests.KnockSettings: TDisplaySettings;
var
  D: TPidDisplay;
  L: TDisplayLevel;
begin
  Result := TDisplaySettings.Create;
  D := TPidDisplay.Create(Kr);
  try
    D.RowColor := Green;
    D.FontSize := 18;
    L := Level('Alarm', coGE, 4, Red);
    L.TextColor := clWhite;
    L.Flash := True;
    L.Sound := asAlarm;
    D.Levels := [L, Level('Warning', coGE, 1, Amber)];
    Result.Put(Kr, D);
  finally
    D.Free;
  end;
end;

procedure TDisplayTests.FirstMatchingLevelWins;
var
  S: TDisplaySettings;
  R: TResolvedStyle;
begin
  S := KnockSettings;
  try
    R := S.Resolve(Kr, 0.5);
    Assert.AreEqual(-1, R.Level);
    Assert.AreEqual(Integer(Green), Integer(R.RowColor), 'normal look');
    Assert.AreEqual(18, R.FontSize);

    R := S.Resolve(Kr, 2);
    Assert.AreEqual(1, R.Level);
    Assert.AreEqual('Warning', R.LevelName);
    Assert.AreEqual(Integer(Amber), Integer(R.RowColor));
    Assert.AreEqual(Integer(clNone), Integer(R.TextColor), 'warning keeps the normal text colour');

    R := S.Resolve(Kr, 7.5);
    Assert.AreEqual(0, R.Level, '>= 4 is listed first, so it wins over >= 1');
    Assert.AreEqual(Integer(Red), Integer(R.RowColor));
    Assert.AreEqual(Integer(clWhite), Integer(R.TextColor));
    Assert.IsTrue(R.Flash);

    Assert.AreEqual(-1, S.Resolve(Kr, NaN).Level, 'no data, no alert');
    Assert.AreEqual(-1, S.Resolve(999, 100).Level, 'PID without settings');
    Assert.AreEqual(Integer(clNone), Integer(S.Resolve(999, 100).RowColor));
  finally
    S.Free;
  end;
end;

procedure TDisplayTests.AllOperators;
var
  L: TDisplayLevel;
begin
  L := Level('', coGE, 4, Red);
  Assert.IsTrue(L.Matches(4));
  Assert.IsFalse(L.Matches(3.99));
  L.Op := coGT;
  Assert.IsFalse(L.Matches(4));
  Assert.IsTrue(L.Matches(4.01));
  L.Op := coLE;
  Assert.IsTrue(L.Matches(4));
  Assert.IsFalse(L.Matches(4.01));
  L.Op := coLT;
  Assert.IsFalse(L.Matches(4));
  Assert.IsTrue(L.Matches(-10));
  L.Op := coEQ;
  Assert.IsTrue(L.Matches(4));
  Assert.IsFalse(L.Matches(5));
  L.Op := coNE;
  Assert.IsFalse(L.Matches(4));
  Assert.IsTrue(L.Matches(5));
  Assert.IsFalse(L.Matches(NaN), 'NaN never matches');
  Assert.AreEqual('<> 4', L.Describe);
end;

procedure TDisplayTests.FlashShowsNormalLookInOffPhase;
var
  S: TDisplaySettings;
  R: TResolvedStyle;
  Row, Txt: TColor;
begin
  S := KnockSettings;
  try
    R := S.Resolve(Kr, 9);
    R.Colors(True, Row, Txt);
    Assert.AreEqual(Integer(Red), Integer(Row));
    Assert.AreEqual(Integer(clWhite), Integer(Txt));
    R.Colors(False, Row, Txt);
    Assert.AreEqual(Integer(Green), Integer(Row), 'off phase shows the normal look');
    Assert.AreEqual(Integer(clNone), Integer(Txt));
    R := S.Resolve(Kr, 2); // warning does not flash
    R.Colors(False, Row, Txt);
    Assert.AreEqual(Integer(Amber), Integer(Row));
  finally
    S.Free;
  end;
end;

procedure TDisplayTests.ColorsAsHex;
begin
  Assert.AreEqual('#FF5050', ColorToHex(Red));
  Assert.AreEqual('#FFE680', ColorToHex(Amber));
  Assert.AreEqual(Integer(Red), Integer(HexToColor('#FF5050', clNone)));
  Assert.AreEqual(Integer(Red), Integer(HexToColor('ff5050', clNone)), 'no # and lower case');
  Assert.AreEqual(Integer(clNone), Integer(HexToColor('red', clNone)));
  Assert.AreEqual(Integer(clNone), Integer(HexToColor('', clNone)));
end;

procedure TDisplayTests.JsonRoundTrip;
var
  S, S2: TDisplaySettings;
  Root: TJSONObject;
  D: TPidDisplay;
  G: TGauge;
  L: TDisplayLevel;
begin
  S := KnockSettings;
  S2 := TDisplaySettings.Create;
  try
    D := TPidDisplay.Create(3);
    try
      L := Level('Cold', coLT, -12.5, clNone);
      L.TextColor := clBlue;
      L.Sound := asFile;
      L.SoundFile := 'C:\Sounds\cold.wav';
      L.RepeatSound := True;
      D.Levels := [L];
      S.Put(3, D);
    finally
      D.Free;
    end;
    G.PidId := Kr;
    G.Style := gsBar;
    G.Size := gzLarge;
    G.MinValue := -5;
    G.MaxValue := 20;
    S.Gauges.Add(G);

    Root := S.ToJson;
    try
      S2.LoadFromJsonText(JsonText(Root));
    finally
      Root.Free;
    end;
    Assert.AreEqual(0, S2.Warnings.Count);
    D := S2.Find(Kr);
    Assert.IsNotNull(D);
    Assert.AreEqual(18, D.FontSize);
    Assert.AreEqual(Integer(Green), Integer(D.RowColor));
    Assert.AreEqual(Integer(clNone), Integer(D.TextColor));
    Assert.AreEqual(2, Integer(Length(D.Levels)));
    Assert.AreEqual('Alarm', D.Levels[0].Name);
    Assert.IsTrue(D.Levels[0].Flash);
    Assert.IsTrue(D.Levels[0].Sound = asAlarm);
    Assert.AreEqual(4.0, D.Levels[0].Value, 1E-9);
    Assert.IsFalse(D.Levels[1].Flash);

    D := S2.Find(3);
    Assert.IsNotNull(D);
    Assert.IsTrue(D.Levels[0].Op = coLT);
    Assert.AreEqual(-12.5, D.Levels[0].Value, 1E-9);
    Assert.AreEqual(Integer(clNone), Integer(D.Levels[0].RowColor));
    Assert.AreEqual(Integer(clBlue), Integer(D.Levels[0].TextColor));
    Assert.IsTrue(D.Levels[0].Sound = asFile);
    Assert.AreEqual('C:\Sounds\cold.wav', D.Levels[0].SoundFile);
    Assert.IsTrue(D.Levels[0].RepeatSound);

    Assert.AreEqual(1, Integer(S2.Gauges.Count));
    G := S2.Gauges[0];
    Assert.AreEqual(Kr, G.PidId);
    Assert.IsTrue(G.Style = gsBar);
    Assert.IsTrue(G.Size = gzLarge);
    Assert.AreEqual(-5.0, G.MinValue, 1E-9);
    Assert.AreEqual(20.0, G.MaxValue, 1E-9);
  finally
    S.Free;
    S2.Free;
  end;
end;

procedure TDisplayTests.BadEntriesAreReported;
var
  S: TDisplaySettings;
begin
  S := TDisplaySettings.Create;
  try
    S.LoadFromJsonText('{"version":1,"pids":[{"fontSize":12},{"pid":5,"levels":[{"when":"??","value":"2.5"}]}],' +
      '"gauges":[{"pid":5,"style":"weird","min":10,"max":10}]}');
    Assert.AreEqual(1, S.Warnings.Count, 'entry without "pid"');
    Assert.IsNull(S.Find(-1));
    Assert.IsTrue(S.Find(5).Levels[0].Op = coGE, 'unknown operator falls back to >=');
    Assert.AreEqual(2.5, S.Find(5).Levels[0].Value, 1E-9, 'number given as text');
    Assert.IsTrue(S.Gauges[0].Style = gsDial);
    Assert.IsTrue(S.Gauges[0].MaxValue > S.Gauges[0].MinValue, 'empty scale is widened');
  finally
    S.Free;
  end;
end;

procedure TDisplayTests.PutDropsAllDefaultEntries;
var
  S: TDisplaySettings;
  D: TPidDisplay;
begin
  S := KnockSettings;
  D := TPidDisplay.Create(Kr);
  try
    S.Put(Kr, D); // everything default
    Assert.IsNull(S.Find(Kr));
  finally
    D.Free;
    S.Free;
  end;
end;

procedure TDisplayTests.ZonesFromLevels;
var
  S: TDisplaySettings;
  Z: TArray<TGaugeZone>;
  D: TPidDisplay;
begin
  S := KnockSettings;
  try
    Z := S.Zones(Kr, 0, 20);
    Assert.AreEqual(2, Integer(Length(Z)));
    // lowest priority first, so the winning level is painted on top
    Assert.AreEqual(1.0, Z[0].FromValue, 1E-9);
    Assert.AreEqual(20.0, Z[0].ToValue, 1E-9);
    Assert.AreEqual(Integer(Amber), Integer(Z[0].Color));
    Assert.AreEqual(4.0, Z[1].FromValue, 1E-9);
    Assert.AreEqual(Integer(Red), Integer(Z[1].Color));

    D := TPidDisplay.Create(12);
    try
      D.Levels := [Level('Low', coLE, 11.5, Red), Level('Off scale', coGE, 50, Amber), Level('No colour', coLE, 12, clNone)];
      S.Put(12, D);
    finally
      D.Free;
    end;
    Z := S.Zones(12, 8, 18);
    Assert.AreEqual(1, Integer(Length(Z)), 'off-scale and colourless levels give no band');
    Assert.AreEqual(8.0, Z[0].FromValue, 1E-9);
    Assert.AreEqual(11.5, Z[0].ToValue, 1E-9);
    Assert.AreEqual(0, Integer(Length(S.Zones(999, 0, 10))));
  finally
    S.Free;
  end;
end;

procedure TDisplayTests.BuiltInDefaultsLoad;
var
  S: TDisplaySettings;
  Root: TJSONObject;
  G: TGauge;
begin
  S := TDisplaySettings.Create;
  Root := ParseJsonObject(DefaultDisplayJson, 'default display.json');
  try
    // A catalog with knock retard (11A6) as id 14, ignition voltage (1141) as
    // 12, two vehicle speeds (000D, km/h = 20, MPH = 8) and no coolant / rpm.
    Assert.AreEqual(2, ResolveSeedJson(Root,
      function(const PidCode, Units: string): Integer
      begin
        if PidCode = '11A6' then
          Result := 14
        else if PidCode = '1141' then
          Result := 12
        else if PidCode = '000D' then
          Result := IfThen(SameText(Units, 'MPH'), 8, 20)
        else
          Result := -1;
      end), 'coolant has no PID here, so its entry is dropped');
    S.LoadFromJson(Root);
    Assert.AreEqual(0, S.Warnings.Count);
    Assert.IsNull(S.Find(-1));
    Assert.AreEqual(3, Integer(S.Gauges.Count), 'rpm and coolant gauges dropped');
    for G in S.Gauges do
      Assert.IsTrue(G.PidId in [8, 12, 14]);
    Assert.IsNotNull(S.Find(Kr), 'knock retard example');
    Assert.AreEqual(0, S.Resolve(Kr, 5).Level);
    Assert.IsTrue(S.Resolve(Kr, 5).Flash);
    Assert.AreEqual(1, S.Resolve(12, 11).Level, 'low voltage is caught before "not charging"');
  finally
    Root.Free;
    S.Free;
  end;
end;

{ TAlertTrackerTests }

procedure TAlertTrackerTests.SoundsOnEnterNotWhileStaying;
var
  T: TAlertTracker;
  C: TAlertChange;
begin
  T := TAlertTracker.Create;
  try
    C := T.Update(Kr, -1, False, False, 0);
    Assert.IsFalse(C.Entered, 'starts normal');
    C := T.Update(Kr, 0, True, False, 100);
    Assert.IsTrue(C.Entered);
    Assert.IsTrue(C.PlaySound);
    Assert.IsTrue(C.Announce);
    C := T.Update(Kr, 0, True, False, 10000);
    Assert.IsFalse(C.Entered);
    Assert.IsFalse(C.PlaySound, 'no repeat');
    Assert.AreEqual(0, T.LevelOf(Kr));
    C := T.Update(Kr, 1, False, False, 10100);
    Assert.IsTrue(C.Entered);
    Assert.IsFalse(C.PlaySound, 'level without sound');
  finally
    T.Free;
  end;
end;

procedure TAlertTrackerTests.RepeatsWhileActive;
var
  T: TAlertTracker;
begin
  T := TAlertTracker.Create;
  try
    Assert.IsTrue(T.Update(Kr, 0, True, True, 1000).PlaySound);
    Assert.IsFalse(T.Update(Kr, 0, True, True, 1000 + RepeatIntervalMs - 1).PlaySound);
    Assert.IsTrue(T.Update(Kr, 0, True, True, 1000 + RepeatIntervalMs).PlaySound);
    Assert.IsFalse(T.Update(Kr, 0, True, True, 1000 + RepeatIntervalMs + 100).PlaySound);
  finally
    T.Free;
  end;
end;

procedure TAlertTrackerTests.HoveringOnAThresholdDoesNotSpam;
var
  T: TAlertTracker;
  I, Sounds, Announces: Integer;
  C: TAlertChange;
begin
  T := TAlertTracker.Create;
  try
    Sounds := 0;
    Announces := 0;
    // in and out of the level every 100 ms for 2.5 s
    for I := 0 to 24 do
    begin
      if Odd(I) then
        C := T.Update(Kr, -1, False, False, I * 100)
      else
        C := T.Update(Kr, 0, True, False, I * 100);
      Inc(Sounds, Ord(C.PlaySound));
      Inc(Announces, Ord(C.Announce));
    end;
    Assert.AreEqual(1, Sounds);
    Assert.AreEqual(1, Announces);
    // after the gap it may sound again
    T.Update(Kr, -1, False, False, MinSoundGapMs + 50);
    Assert.IsTrue(T.Update(Kr, 0, True, False, MinSoundGapMs + 100).PlaySound);
  finally
    T.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDisplayTests);
  TDUnitX.RegisterTestFixture(TAlertTrackerTests);

end.
