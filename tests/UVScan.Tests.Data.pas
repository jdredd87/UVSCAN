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
    Lines.Add('');
    ImportLegacyPidsCsvLines(Lines, C);
    Assert.AreEqual(1, C.Count);
    Assert.AreEqual(3, C.Warnings.Count, C.Warnings.Text);
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
  Target := Catalog('{"pids":[{"id":1,"name":"Mine","kind":"calculated","formula":"1"}]}');
  Source := Catalog('{"pids":[{"id":1,"name":"Theirs","kind":"calculated","formula":"2"},' +
    '{"id":2,"name":"New","kind":"calculated","formula":"3"}]}');
  try
    R := MergeCatalog(Target, Source, mmAddNew);
    Assert.AreEqual(1, R.Added);
    Assert.AreEqual(0, R.Updated);
    Assert.AreEqual(1, R.Skipped);
    Assert.AreEqual(2, Target.Count);
    Assert.AreEqual('Mine', Target.FindById(1).LongName);
    Source.FindById(2).LongName := 'Changed later';
    Assert.AreEqual('New', Target.FindById(2).LongName, 'merge copies, not shares');
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
  Target := Catalog('{"pids":[{"id":1,"name":"Mine","kind":"calculated","formula":"1"},' +
    '{"id":5,"name":"Untouched","kind":"calculated","formula":"5"}]}');
  Source := Catalog('{"pids":[{"id":1,"name":"Theirs","kind":"calculated","formula":"2"},' +
    '{"id":2,"name":"New","kind":"calculated","formula":"3"}]}');
  try
    R := MergeCatalog(Target, Source, mmAddAndUpdate);
    Assert.AreEqual(1, R.Added);
    Assert.AreEqual(1, R.Updated);
    Assert.AreEqual(3, Target.Count);
    Assert.AreEqual('Theirs', Target.FindById(1).LongName);
    Assert.AreEqual('2', Target.FindById(1).FormulaText);
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
    Assert.WillRaise(procedure begin A.Put('  ', [1]) end, EArgumentException);

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
