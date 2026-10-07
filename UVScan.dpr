program UVScan;

uses
  Vcl.Forms,
  UVScan.Hex in 'src\UVScan.Hex.pas',
  UVScan.Serial in 'src\UVScan.Serial.pas',
  UVScan.Avt in 'src\UVScan.Avt.pas',
  UVScan.Class2 in 'src\UVScan.Class2.pas',
  UVScan.Formula in 'src\UVScan.Formula.pas',
  UVScan.Pids in 'src\UVScan.Pids.pas',
  UVScan.Dpid in 'src\UVScan.Dpid.pas',
  UVScan.Dtc in 'src\UVScan.Dtc.pas',
  UVScan.Simulator in 'src\UVScan.Simulator.pas',
  UVScan.Engine in 'src\UVScan.Engine.pas',
  UVScan.MainForm in 'src\UVScan.MainForm.pas' {MainForm};

{$R *.res}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'UVScan';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
