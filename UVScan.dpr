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
  UVScan.Paths in 'src\UVScan.Paths.pas',
  UVScan.JsonFile in 'src\UVScan.JsonFile.pas',
  UVScan.Settings in 'src\UVScan.Settings.pas',
  UVScan.Defaults in 'src\UVScan.Defaults.pas',
  UVScan.PidLists in 'src\UVScan.PidLists.pas',
  UVScan.LegacyImport in 'src\UVScan.LegacyImport.pas',
  UVScan.Display in 'src\UVScan.Display.pas',
  UVScan.Alerts in 'src\UVScan.Alerts.pas',
  UVScan.Gauge in 'src\UVScan.Gauge.pas',
  UVScan.DisplayEditor in 'src\UVScan.DisplayEditor.pas' {DisplayEditorForm},
  UVScan.GaugeEditor in 'src\UVScan.GaugeEditor.pas' {GaugeEditorForm},
  UVScan.Controls in 'src\UVScan.Controls.pas',
  UVScan.ControlEditor in 'src\UVScan.ControlEditor.pas' {ControlEditorForm},
  UVScan.LogData in 'src\UVScan.LogData.pas',
  UVScan.LogViews in 'src\UVScan.LogViews.pas',
  UVScan.LogChart in 'src\UVScan.LogChart.pas',
  UVScan.LogViewer in 'src\UVScan.LogViewer.pas' {LogViewerForm},
  UVScan.PidEditor in 'src\UVScan.PidEditor.pas' {PidEditorForm},
  UVScan.PidDiscovery in 'src\UVScan.PidDiscovery.pas' {PidDiscoveryForm},
  UVScan.MainForm in 'src\UVScan.MainForm.pas' {MainForm};

{$R *.res}
{$R 'UVScan.Defaults.res' 'UVScan.Defaults.rc'}

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
