program UVScan;

uses
  System.StartUpCopy,
  System.SysUtils,
  FMX.Types,
  FMX.Forms,
  UVScan.Hex in 'src\UVScan.Hex.pas',
  UVScan.Serial in 'src\UVScan.Serial.pas',
  UVScan.Serial.Android in 'src\UVScan.Serial.Android.pas',
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
  UVScan.Sound in 'src\UVScan.Sound.pas',
  UVScan.Controls in 'src\UVScan.Controls.pas',
  UVScan.LogData in 'src\UVScan.LogData.pas',
  UVScan.LogViews in 'src\UVScan.LogViews.pas',
  UVScan.UI.Common in 'src\UVScan.UI.Common.pas',
  UVScan.UI.DataGrid in 'src\UVScan.UI.DataGrid.pas',
  UVScan.Gauge in 'src\UVScan.Gauge.pas',
  UVScan.LogChart in 'src\UVScan.LogChart.pas',
  UVScan.DisplayEditor in 'src\UVScan.DisplayEditor.pas' {DisplayEditorForm},
  UVScan.GaugeEditor in 'src\UVScan.GaugeEditor.pas' {GaugeEditorForm},
  UVScan.ControlEditor in 'src\UVScan.ControlEditor.pas' {ControlEditorForm},
  UVScan.LogViewer in 'src\UVScan.LogViewer.pas' {LogViewerForm},
  UVScan.PidEditor in 'src\UVScan.PidEditor.pas' {PidEditorForm},
  UVScan.PidDiscovery in 'src\UVScan.PidDiscovery.pas' {PidDiscoveryForm},
  UVScan.MainForm in 'src\UVScan.MainForm.pas' {MainForm};

type
  TStartupLog = class
    class procedure AppException(Sender: TObject; E: Exception);
  end;

class procedure TStartupLog.AppException(Sender: TObject; E: Exception);
begin
  Log.d('UVScan error: %s: %s', [E.ClassName, E.Message]);
end;

{$R *.res}
{$R 'UVScan.Defaults.res' 'UVScan.Defaults.rc'}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  try
    Application.OnException := TStartupLog.AppException;
    Application.Initialize;
    Application.Title := 'UVScan';
    Application.CreateForm(TMainForm, MainForm);
    Application.Run;
  except
    on E: Exception do
    begin
      // Shows in "adb logcat" on Android, where a failed start leaves no window.
      Log.d('UVScan failed to start: %s: %s', [E.ClassName, E.Message]);
      raise;
    end;
  end;
end.
