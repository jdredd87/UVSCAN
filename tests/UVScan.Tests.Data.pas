unit UVScan.Tests.Data;

{ Legacy PIDS.csv import, catalog merging, scan lists and built-in defaults. }

interface

uses
  System.SysUtils, System.Classes, System.JSON, DUnitX.TestFramework,
  UVScan.Pids, UVScan.LegacyImport, UVScan.PidLists, UVScan.Defaults, UVScan.Dtc, UVScan.JsonFile;

type
  [TestFixture]
  TLegacyImportTests = class
  private
    function LegacyLines: TStringList;
  public
    [Test] procedure ImportsKindsAndFixesUp;
    [Test] procedure ReportsBadRows;
    [Test] procedure MergeAddNewOnly;
    [Test] procedure MergeAddAndUpdate;
    [Test] procedure MergeReplace;
    [Test] procedure ImportsRealOldFile;
    [Test] procedure MergesRealOldFileIntoDefaults;
    [Test] procedure MatchesSamePidWithOtherName;
  end;

  [TestFixture]
  TPidListTests = class
  public
    [Test] procedure PutReplaceDeleteAndRoundTrip;
    [Test] procedure ReportsBadEntries;
  end;

  [TestFixture]
  TDefaultsTests = class
  public
    [Test] procedure BuiltInDataIsValid;
  end;

implementation

{ TLegacyImportTests }

function TLegacyImportTests.LegacyLines: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('Counter,Long Name,Desc,Formula,Units,Datalength,PID,group,shortname,Results,PidCat,txtMCI');
  Result.Add('1,ENGINE SPEED,,((N1 << 8) +N2) *0.25,RPM,2,000C,1,RPM,,1,%RPM%');
  Result.Add('3,"ECT, coolant",,N0-40,' + #$BA + 'C,1,5,1,ECT,,1,%ECT%');
  Result.Add('9,Old group,,N0,x,1,1234,2,OG,,4,');
  Result.Add('20,AFR (LC-1),,%AD1% * 3.008 + 7.35,AFR,0,FPID,1,AFR,%f,6,%AFRWideband%');
  Result.Add('21,AD1,,N0 * 0.0196,V,0,FFFF,1,AD1,%f,7,%AD1%');
  Result.Add('56,Trans Temp,,N0 - 40,' + #$BA + 'C,1,1940,1,Trans Temp,,2,');
end;

procedure TLegacyImportTests.ImportsKindsAndFixesUp;
var
  Lines: TStringList;
  C: TPidCatalog;
begin
  Lines := LegacyLines;
  C := TPidCatalog.Create;
  try
    ImportLegacyPidsCsvLines(Lines, C);
    Assert.AreEqual(6, C.Count);
    Assert.AreEqual(0, C.Warnings.Count, C.Warnings.Text);
    Assert.AreEqual(Ord(pkVehicle), Ord(C.FindById(1).Kind));
    Assert.AreEqual('0005', C.FindById(3).PidCode);
    Assert.AreEqual('ECT, coolant', C.FindById(3).LongName);
    Assert.AreEqual(#$B0'C', C.FindById(3).Units, 'degree sign fixed');
    Assert.IsFalse(C.FindById(9).Enabled, 'group <> 1 imports as disabled');
    Assert.AreEqual(Ord(pcBody), Ord(C.FindById(9).Category));
    Assert.AreEqual(Ord(pkCalculated), Ord(C.FindById(20).Kind));
    Assert.AreEqual('AFRWIDEBAND', C.FindById(20).Mci);
    Assert.AreEqual(Ord(pkAnalog), Ord(C.FindById(21).Kind));
    Assert.AreEqual(1, C.FindById(21).AnalogChannel);
    Assert.AreEqual(Ord(pcTransmission), Ord(C.FindById(56).Category));
  finally
    C.Free;
    Lines.Free;
  end;
end;

procedure TLegacyImportTests.ReportsBadRows;
var
  Lines: TStringList;
  C: TPidCatalog;
begin
  Lines := TStringList.Create;
  C := TPidCatalog.Create;
  try
    Lines.Add('header');
    Lines.Add('1,Good,,N0,x,1,000C,1,G,,1,G');
    Lines.Add('2,Too few,columns');
    Lines.Add('x,Bad counter,,N0,x,1,000D,1,B,,1,');
    Lines.Add('4,Bad pid,,N0,x,1,ZZZZ,1,B,,1,');
    Lines.Add('5,No MCI column,,N0,x,1,000E,1,NM,,2');           // 11 columns: fine
    Lines.Add('6,Short row,,N0,x,1,000F,1,SR');                   // 9 columns: fine
    Lines.Add('');
    ImportLegacyPidsCsvLines(Lines, C);
    Assert.AreEqual(3, C.Count, C.Warnings.Text);
    Assert.AreEqual(3, C.Warnings.Count, C.Warnings.Text);
    Assert.AreEqual(Ord(pcTransmission), Ord(C.FindById(5).Category));
    Assert.AreEqual('', C.FindById(5).Mci);
  finally
    C.Free;
    Lines.Free;
  end;
end;

function Catalog(const Json: string): TPidCatalog;
begin
  Result := TPidCatalog.Create;
  Result.LoadFromJsonText(Json);
end;

procedure TLegacyImportTests.MergeAddNewOnly;
var
  Target, Source: TPidCatalog;
  R: TMergeResult;
begin
  // Ids in another file mean different things: match by name, renumber clashes.
  Target := Catalog('{"pids":[{"id":1,"name":"Engine Speed","kind":"calculated","formula":"1"},' +
    '{"id":2,"name":"Coolant","kind":"calculated","formula":"1"}]}');
  Source := Catalog('{"pids":[{"id":1,"name":"Fuel System Status","kind":"calculated","formula":"2"},' +
    '{"id":2,"name":"ENGINE SPEED","kind":"calculated","formula":"9"},' +
    '{"id":7,"name":"Free id","kind":"calculated","formula":"3"}]}');
  try
    R := MergeCatalog(Target, Source, mmAddNew);
    Assert.AreEqual(2, R.Added);
    Assert.AreEqual(0, R.Updated);
    Assert.AreEqual(1, R.Skipped);
    Assert.AreEqual(1, R.Renumbered);
    Assert.AreEqual(4, Target.Count);
    Assert.AreEqual('Engine Speed', Target.FindById(1).LongName, 'existing PID kept');
    Assert.AreEqual('1', Target.FindById(1).FormulaText);
    Assert.AreEqual('Fuel System Status', Target.FindById(8).LongName, 'clashing id renumbered');
    Assert.AreEqual('Free id', Target.FindById(7).LongName, 'free id kept');
    Source.FindById(7).LongName := 'Changed later';
    Assert.AreEqual('Free id', Target.FindById(7).LongName, 'merge copies, not shares');
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TLegacyImportTests.MergeAddAndUpdate;
var
  Target, Source: TPidCatalog;
  R: TMergeResult;
begin
  Target := Catalog('{"pids":[{"id":1,"name":"Engine Speed","kind":"calculated","formula":"1"},' +
    '{"id":5,"name":"Untouched","kind":"calculated","formula":"5"}]}');
  Source := Catalog('{"pids":[{"id":40,"name":"engine speed","kind":"calculated","formula":"2"},' +
    '{"id":2,"name":"New","kind":"calculated","formula":"3"}]}');
  try
    R := MergeCatalog(Target, Source, mmAddAndUpdate);
    Assert.AreEqual(1, R.Added);
    Assert.AreEqual(1, R.Updated);
    Assert.AreEqual(3, Target.Count);
    Assert.AreEqual('2', Target.FindById(1).FormulaText, 'updated from the import');
    Assert.IsNull(Target.FindById(40), 'updated PID keeps its own id (scan lists stay valid)');
    Assert.AreEqual('Untouched', Target.FindById(5).LongName);
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TLegacyImportTests.MergeReplace;
var
  Target, Source: TPidCatalog;
  R: TMergeResult;
begin
  Target := Catalog('{"pids":[{"id":1,"name":"Mine","kind":"calculated","formula":"1"},' +
    '{"id":5,"name":"Gone","kind":"calculated","formula":"5"}]}');
  Source := Catalog('{"pids":[{"id":2,"name":"Only","kind":"calculated","formula":"3"}]}');
  try
    R := MergeCatalog(Target, Source, mmReplace);
    Assert.AreEqual(1, R.Added);
    Assert.AreEqual(1, Target.Count);
    Assert.AreEqual('Only', Target[0].LongName);
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TLegacyImportTests.ImportsRealOldFile;
var
  Dir, F: string;
  I, Disabled: Integer;
  C, Target: TPidCatalog;
  R: TMergeResult;
  Problems: string;
begin
  // tests\fixtures\Extra_Pids.csv: a 2008 UVSCAN file; 96 of its rows have no
  // trailing MCI column, two formulas use "a ? b : c", three have typos.
  Dir := ExtractFilePath(ParamStr(0));
  F := '';
  for I := 0 to 5 do
  begin
    if FileExists(Dir + 'fixtures\Extra_Pids.csv') then
      F := Dir + 'fixtures\Extra_Pids.csv'
    else if FileExists(Dir + 'tests\fixtures\Extra_Pids.csv') then
      F := Dir + 'tests\fixtures\Extra_Pids.csv';
    if F <> '' then
      Break;
    Dir := ExtractFilePath(ExcludeTrailingPathDelimiter(Dir));
  end;
  Assert.IsTrue(F <> '', 'fixture not found');
  C := TPidCatalog.Create;
  Target := TPidCatalog.Create;
  try
    ImportLegacyPidsCsv(F, C);
    Assert.AreEqual(273, C.Count, C.Warnings.Text);
    Disabled := 0;
    for I := 0 to C.Count - 1 do
      if not C[I].Enabled then
        Inc(Disabled);
    Assert.AreEqual(18, Disabled);
    Problems := C.Warnings.Text;
    Assert.AreEqual(3, C.Warnings.Count, Problems);
    Assert.IsTrue(Pos('FC Relay 1', Problems) > 0, Problems);
    Assert.IsTrue(Pos('Missing closing % after %AD1', Problems) > 0, Problems);
    Assert.IsTrue(Pos('Missing closing % after %MAFGmPerSec', Problems) > 0, Problems);

    // Same-named but different PIDs (e.g. two "1-2 Solenoid") must both arrive.
    R := MergeCatalog(Target, C, mmAddNew);
    Assert.AreEqual(273, R.Added);
    Assert.AreEqual(273, Target.Count);
    // Importing again adds nothing.
    R := MergeCatalog(Target, C, mmAddNew);
    Assert.AreEqual(0, R.Added);
    Assert.AreEqual(273, R.Skipped);
  finally
    C.Free;
    Target.Free;
  end;
end;

function FixtureFile(const Name: string): string;
var
  Dir, Candidate: string;
  I: Integer;
begin
  Dir := ExtractFilePath(ParamStr(0));
  for I := 0 to 5 do
  begin
    for Candidate in [Dir + 'fixtures\' + Name, Dir + 'tests\fixtures\' + Name] do
      if FileExists(Candidate) then
        Exit(Candidate);
    Dir := ExtractFilePath(ExcludeTrailingPathDelimiter(Dir));
  end;
  Result := '';
end;

procedure TLegacyImportTests.MergesRealOldFileIntoDefaults;
var
  Target, Old: TPidCatalog;
  R: TMergeResult;
  Problems: TArray<TPidProblem>;
  Text: string;
  Pr: TPidProblem;
begin
  Target := TPidCatalog.Create;
  Old := TPidCatalog.Create;
  try
    Target.LoadFromJsonText(DefaultPidsJson);
    ImportLegacyPidsCsv(FixtureFile('Extra_Pids.csv'), Old);
    R := MergeCatalog(Target, Old, mmAddNew);
    Assert.IsTrue(R.Skipped > 0, 'known PIDs (e.g. Engine Speed (RPM)) are recognised');
    Assert.IsNotNull(FindMatchingPid(Target, Old.FindById(2)), 'Engine Speed (RPM) matches ENGINE SPEED');
    Problems := Target.Validate;
    Text := '';
    for Pr in Problems do
      Text := Text + Pr.Text + sLineBreak;
    // Only two typos from the old file are left to fix by hand. The third
    // (Airflow mg/cyl, "%MAFGmPerSec * 1000") matches the correct PID that is
    // already in the defaults, so it is not added at all.
    Assert.AreEqual(2, Integer(Length(Problems)), Text);
    Assert.IsTrue(Pos('FC Relay 1', Text) > 0, Text);
    Assert.IsTrue(Pos('%AD1', Text) > 0, Text);
  finally
    Target.Free;
    Old.Free;
  end;
end;

procedure TLegacyImportTests.MatchesSamePidWithOtherName;
var
  Target, Source: TPidCatalog;
  R: TMergeResult;
begin
  Target := Catalog('{"pids":[{"id":1,"name":"ENGINE SPEED","kind":"vehicle","pid":"000C","bytes":2,' +
    '"formula":"((N1 << 8) +N2) *0.25","mci":"RPM"}]}');
  Source := Catalog('{"pids":[' +
    '{"id":2,"name":"Engine Speed (RPM)","kind":"vehicle","pid":"000C","bytes":2,"formula":"((N1<<8)+N2)*0.25","mci":"RPM"},' +
    '{"id":3,"name":"Engine Speed raw","kind":"vehicle","pid":"000C","bytes":2,"formula":"(N1<<8)+N2","mci":"RPM"}]}');
  try
    R := MergeCatalog(Target, Source, mmAddNew);
    Assert.AreEqual(1, R.Skipped, 'same PID and formula = same measurement');
    Assert.AreEqual(1, R.Added);
    Assert.AreEqual(1, Integer(Length(R.MciCleared)));
    Assert.AreEqual('', Target.FindById(3).Mci, 'clashing MCI removed from the added PID');
    Assert.AreEqual('RPM', Target.FindById(1).Mci);
    Assert.AreEqual(0, Integer(Length(Target.Validate)));
  finally
    Target.Free;
    Source.Free;
  end;
end;

{ TPidListTests }

procedure TPidListTests.PutReplaceDeleteAndRoundTrip;
var
  A, B: TPidLists;
  Root: TJSONObject;
begin
  A := TPidLists.Create;
  B := TPidLists.Create;
  try
    A.Put('Transmission', [15, 40, 41]);
    A.Put('Misfires', [20, 21]);
    Assert.AreEqual(2, A.Count);
    Assert.AreEqual('Misfires', A[0].Name, 'kept sorted by name');
    A.Put('misfires', [1, 20, 21, 22]);
    Assert.AreEqual(2, A.Count, 'names are case-insensitive');
    Assert.AreEqual(4, Integer(Length(A[A.IndexOf('Misfires')].PidIds)));
    try
      A.Put('  ', [1]);
      Assert.Fail('a blank list name must be rejected');
    except
      on EArgumentException do
        ;
    end;

    Root := A.ToJson;
    try
      B.LoadFromJsonText(JsonText(Root));
    finally
      Root.Free;
    end;
    Assert.AreEqual(2, B.Count);
    Assert.AreEqual(3, Integer(Length(B[B.IndexOf('TRANSMISSION')].PidIds)));
    B.Delete('Transmission');
    Assert.AreEqual(1, B.Count);
    Assert.AreEqual(-1, B.IndexOf('Transmission'));
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TPidListTests.ReportsBadEntries;
var
  L: TPidLists;
begin
  L := TPidLists.Create;
  try
    L.LoadFromJsonText('{"lists":[{"name":"A","pids":[1,2]},{"name":"a","pids":[3]},' +
      '{"pids":[4]},"junk",{"name":"B","pids":[5,"x",6]}]}');
    Assert.AreEqual(2, L.Count);
    Assert.AreEqual(3, L.Warnings.Count, L.Warnings.Text);
    Assert.AreEqual(2, Integer(Length(L[L.IndexOf('B')].PidIds)));
  finally
    L.Free;
  end;
end;

{ TDefaultsTests }

procedure TDefaultsTests.BuiltInDataIsValid;
var
  Pids: TPidCatalog;
  Dtcs: TDtcCatalog;
  Lists: TPidLists;
  I, Id: Integer;
begin
  Pids := TPidCatalog.Create;
  Dtcs := TDtcCatalog.Create;
  Lists := TPidLists.Create;
  try
    Pids.LoadFromJsonText(DefaultPidsJson);
    Assert.IsTrue(Pids.Count > 50);
    Assert.AreEqual('', Pids.Warnings.Text);
    Dtcs.LoadFromJsonText(DefaultDtcsJson);
    Assert.IsTrue(Dtcs.Count > 1000);
    Assert.AreEqual('', Dtcs.Warnings.Text);
    Lists.LoadFromJsonText(DefaultListsJson);
    Assert.IsTrue(Lists.Count >= 3);
    Assert.AreEqual('', Lists.Warnings.Text);
    for I := 0 to Lists.Count - 1 do
      for Id in Lists[I].PidIds do
        Assert.IsNotNull(Pids.FindById(Id), Format('list "%s" refers to unknown PID %d', [Lists[I].Name, Id]));
  finally
    Pids.Free;
    Dtcs.Free;
    Lists.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLegacyImportTests);
  TDUnitX.RegisterTestFixture(TPidListTests);
  TDUnitX.RegisterTestFixture(TDefaultsTests);

end.
