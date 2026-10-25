unit UVScan.Tests.LogFiles;

(* Log files: the name a new log gets from its pattern ({date}, {time}, {n}
  counting up, {vin}), names made safe and unique, and the list the Logs
  page shows (newest first, with each log's length). *)

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.DateUtils, DUnitX.TestFramework,
  UVScan.LogFiles;

type
  [TestFixture]
  TLogFilesTests = class
  private
    FDir: string;
    procedure Touch(const Name: string; const Text: string = ''; Age: Integer = 0);
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure DefaultIsTheOldName;
    [Test] procedure CountsUpPerName;
    [Test] procedure VinOrNothing;
    [Test] procedure CleansNames;
    [Test] procedure UniqueGetsANumber;
    [Test] procedure ListsNewestFirstWithLength;
  end;

implementation

function When: TDateTime;
begin
  Result := EncodeDateTime(2026, 10, 25, 19, 17, 0, 0);
end;

procedure TLogFilesTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'UVScanLogFiles' + IntToStr(Random(MaxInt)));
  ForceDirectories(FDir);
end;

procedure TLogFilesTests.TearDown;
begin
  try
    TDirectory.Delete(FDir, True);
  except
    // left in Temp
  end;
end;

procedure TLogFilesTests.Touch(const Name, Text: string; Age: Integer);
var
  F: string;
begin
  F := TPath.Combine(FDir, Name);
  TFile.WriteAllText(F, Text, TEncoding.UTF8);
  if Age > 0 then
    TFile.SetLastWriteTime(F, IncDay(Now, -Age));
end;

procedure TLogFilesTests.DefaultIsTheOldName;
begin
  Assert.AreEqual('UVScan_' + FormatDateTime('yyyy-mm-dd_hhnnss', When),
    ExpandLogName(DefaultLogNamePattern, FDir, When));
  Assert.AreEqual(ExpandLogName(DefaultLogNamePattern, FDir, When), ExpandLogName('  ', FDir, When), 'empty');
end;

procedure TLogFilesTests.CountsUpPerName;
var
  D: string;
begin
  D := FormatDateTime('yyyy-mm-dd', When);
  Assert.AreEqual('Camaro_' + D + '_1', ExpandLogName('Camaro_{date}_{n}', FDir, When));
  Touch('Camaro_' + D + '_1.csv');
  Touch('Camaro_' + D + '_7.csv');
  Touch('Camaro_2026-10-24_9.csv'); // another day
  Touch('Other_' + D + '_20.csv');
  Assert.AreEqual('Camaro_' + D + '_8', ExpandLogName('Camaro_{date}_{n}', FDir, When));
  Touch('Camaro_' + D + '_8 - hot lap.csv'); // renamed when it started: still number 8
  Assert.AreEqual('Camaro_' + D + '_9', ExpandLogName('Camaro_{date}_{n}', FDir, When));
  Assert.AreEqual('Run 1', ExpandLogName('Run {N}', FDir, When), 'nothing like it: 1');
end;

procedure TLogFilesTests.VinOrNothing;
begin
  Assert.AreEqual('1G1FP87S1XN000001_1', ExpandLogName('{vin}_{n}', FDir, When, '1G1FP87S1XN000001'));
  Assert.AreEqual('Camaro_1', ExpandLogName('Camaro_{vin}_{n}', FDir, When, ''), 'no VIN: no gap');
end;

procedure TLogFilesTests.CleansNames;
begin
  Assert.AreEqual('Run 3 - hot lap', CleanLogName('  Run 3 - hot lap.csv '));
  Assert.AreEqual('a-b-c-d', CleanLogName('a/b:c?d'));
  Assert.AreEqual('', CleanLogName(' ... '));
end;

procedure TLogFilesTests.UniqueGetsANumber;
begin
  Assert.AreEqual(TPath.Combine(FDir, 'Run.csv'), UniqueLogFile(FDir, 'Run'));
  Touch('Run.csv');
  Touch('Run_2.csv');
  Assert.AreEqual(TPath.Combine(FDir, 'Run_3.csv'), UniqueLogFile(FDir, 'Run'));
end;

procedure TLogFilesTests.ListsNewestFirstWithLength;
var
  L: TArray<TLogFileInfo>;
begin
  Touch('old.csv', #$FEFF'Time (s),RPM,Mark'#13#10'0.0,800,'#13#10'95.5,900,'#13#10, 10);
  Touch('new.csv', 'Time (s),RPM,Mark'#13#10, 1);
  Touch('notes.txt', 'not a log');
  L := ListLogs(FDir);
  Assert.AreEqual(2, Length(L));
  Assert.AreEqual('new.csv', ExtractFileName(L[0].FileName));
  Assert.AreEqual(0.0, L[0].Seconds, 0.001, 'the header only');
  Assert.AreEqual('old.csv', ExtractFileName(L[1].FileName));
  Assert.AreEqual(95.5, L[1].Seconds, 0.001);
  Assert.IsTrue(L[1].Size > 0);
  Assert.AreEqual(0, Length(ListLogs(TPath.Combine(FDir, 'none'))));
end;

initialization
  TDUnitX.RegisterTestFixture(TLogFilesTests);

end.
