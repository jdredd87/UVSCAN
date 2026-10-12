program ElmProbe;

{ Test program for ELM327 type adapters (Bluetooth, Wi-Fi, USB) on GM
  Class 2, before they are added to UVScan. See ElmProbe.Runner. }

uses
  System.StartUpCopy,
  FMX.Forms,
  UVScan.Hex in '..\..\src\UVScan.Hex.pas',
  UVScan.Serial in '..\..\src\UVScan.Serial.pas',
  UVScan.Serial.Android in '..\..\src\UVScan.Serial.Android.pas',
  UVScan.Bluetooth.Android in '..\..\src\UVScan.Bluetooth.Android.pas',
  UVScan.Class2 in '..\..\src\UVScan.Class2.pas',
  UVScan.Elm in '..\..\src\UVScan.Elm.pas',
  ElmProbe.Runner in 'ElmProbe.Runner.pas',
  ElmProbe.Main in 'ElmProbe.Main.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'ElmProbe';
  Application.CreateForm(TProbeForm, ProbeForm);
  Application.Run;
end.
