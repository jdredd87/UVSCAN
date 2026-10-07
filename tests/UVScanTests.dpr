program UVScanTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  UVScan.Hex in '..\src\UVScan.Hex.pas',
  UVScan.Avt in '..\src\UVScan.Avt.pas',
  UVScan.Class2 in '..\src\UVScan.Class2.pas',
  UVScan.Formula in '..\src\UVScan.Formula.pas',
  UVScan.JsonFile in '..\src\UVScan.JsonFile.pas',
  UVScan.Pids in '..\src\UVScan.Pids.pas',
  UVScan.Paths in '..\src\UVScan.Paths.pas',
  UVScan.Dtc in '..\src\UVScan.Dtc.pas',
  UVScan.Settings in '..\src\UVScan.Settings.pas',
  UVScan.Dpid in '..\src\UVScan.Dpid.pas',
  UVScan.Serial in '..\src\UVScan.Serial.pas',
  UVScan.Simulator in '..\src\UVScan.Simulator.pas',
  UVScan.Engine in '..\src\UVScan.Engine.pas',
  UVScan.Tests.Core in 'UVScan.Tests.Core.pas',
  UVScan.Tests.Engine in 'UVScan.Tests.Engine.pas',
  UVScan.Tests.Json in 'UVScan.Tests.Json.pas',
  UVScan.Defaults in '..\src\UVScan.Defaults.pas',
  UVScan.PidLists in '..\src\UVScan.PidLists.pas',
  UVScan.LegacyImport in '..\src\UVScan.LegacyImport.pas',
  UVScan.Tests.Data in 'UVScan.Tests.Data.pas';

{$R 'UVScan.Defaults.res' '..\UVScan.Defaults.rc'}

var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := False;
    Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
    Results := Runner.Execute;
    if not Results.AllPassed then
      System.ExitCode := EXIT_ERRORS;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
end.
