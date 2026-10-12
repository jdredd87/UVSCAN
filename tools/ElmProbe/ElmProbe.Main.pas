unit ElmProbe.Main;

{ ELM327 probe: pick the adapter (a paired Bluetooth device on Android, a
  COM port or a Wi-Fi address on Windows), run the tests or type commands,
  and read the log (also written to a file).

  Started with a port (Windows: -port COM5 [-baud 38400] [-run] [-exit];
  Android: am start ... --es port vLinker --ez run true) it picks the first
  port whose name contains it and, with run, starts the tests. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit, FMX.Memo, FMX.ListBox, FMX.Layouts,
  FMX.Memo.Types, FMX.ScrollBox, FMX.Controls.Presentation,
  ElmProbe.Runner;

type
  TProbeForm = class(TForm)
  private
    cbPort: TComboBox;
    edAddress: TEdit;
    cbBaud: TComboBox;
    btnRefresh, btnRun, btnStop, btnStream, btnSend, btnClose: TButton;
    edCmd: TEdit;
    mmLog: TMemo;
    lblFile: TLabel;
    FRunner: TProbeRunner;
    FRunnerPort: string;
    FPending: TStringList;
    FTimer: TTimer;
    FExitWhenDone: Boolean;
    FDoneSeen: Boolean;
    procedure Build;
    function Row(Parent: TFmxObject; Height: Single): TLayout;
    function AddButton(Parent: TFmxObject; const Text: string; Width: Single; Handler: TNotifyEvent): TButton;
    procedure FillPorts;
    function ChosenPort: string;
    function Runner: TProbeRunner;
    procedure LogLine(const Line: string);
    procedure TimerTick(Sender: TObject);
    procedure RefreshClick(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure StreamClick(Sender: TObject);
    procedure SendClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure CmdKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure ApplyStartOptions;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  ProbeForm: TProbeForm;

implementation

uses
  System.IOUtils, System.SyncObjs, System.StrUtils, System.Math,
  {$IFDEF ANDROID}Androidapi.Helpers, Androidapi.JNI.App, Androidapi.JNI.GraphicsContentViewText, Androidapi.JNI.JavaTypes,
  UVScan.Bluetooth.Android,{$ENDIF}
  UVScan.Serial;

var
  PendingLock: TCriticalSection;

function LogFolder: string;
begin
  {$IFDEF ANDROID}
  Result := TPath.Combine(TPath.GetPublicPath, 'ElmProbe');
  {$ELSE}
  Result := TPath.Combine(TPath.GetDocumentsPath, 'ElmProbe');
  {$ENDIF}
end;

constructor TProbeForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'ELM327 probe';
  Width := 900;
  Height := 700;
  Position := TFormPosition.ScreenCenter;
  OnClose := FormClose;
  FPending := TStringList.Create;
  Build;
  FillPorts;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 100;
  FTimer.OnTimer := TimerTick;
  TThread.ForceQueue(nil, ApplyStartOptions);
end;

destructor TProbeForm.Destroy;
begin
  if FRunner <> nil then
  begin
    FRunner.RequestStop;
    FRunner.Post('QUIT');
    FRunner.WaitFor;
    FreeAndNil(FRunner);
  end;
  FPending.Free;
  inherited;
end;

procedure TProbeForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := TCloseAction.caFree;
end;

function TProbeForm.Row(Parent: TFmxObject; Height: Single): TLayout;
begin
  Result := TLayout.Create(Self);
  Result.Parent := Parent;
  // Top-aligned in the order made (FMX stacks them by position).
  Result.Position.Y := Parent.ChildrenCount * 100;
  Result.Align := TAlignLayout.Top;
  Result.Height := Height;
  Result.Margins.Rect := TRectF.Create(6, 6, 6, 0);
end;

function TProbeForm.AddButton(Parent: TFmxObject; const Text: string; Width: Single; Handler: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := Parent;
  Result.Align := TAlignLayout.Left;
  Result.Width := Width;
  Result.Margins.Right := 6;
  Result.Text := Text;
  Result.OnClick := Handler;
end;

procedure TProbeForm.Build;
const
  H = 44;
var
  R: TLayout;
  Top: TLayout;
begin
  Top := TLayout.Create(Self);
  Top.Parent := Self;
  Top.Align := TAlignLayout.Top;
  Top.Height := 4 * (H + 6) + 6;
  {$IFDEF ANDROID}
  Top.Margins.Top := 24; // below the status bar
  {$ENDIF}

  R := Row(Top, H);
  btnRefresh := AddButton(R, 'Refresh', 90, RefreshClick);
  btnRefresh.Align := TAlignLayout.Right;
  btnRefresh.Margins.Right := 0;
  btnRefresh.Margins.Left := 6;
  cbPort := TComboBox.Create(Self);
  cbPort.Parent := R;
  cbPort.Align := TAlignLayout.Client;

  R := Row(Top, H);
  cbBaud := TComboBox.Create(Self);
  cbBaud.Parent := R;
  cbBaud.Align := TAlignLayout.Right;
  cbBaud.Width := 110;
  cbBaud.Margins.Left := 6;
  cbBaud.Items.CommaText := '38400,115200,9600,57600,230400,500000';
  cbBaud.ItemIndex := 0;
  edAddress := TEdit.Create(Self);
  edAddress.Parent := R;
  edAddress.Align := TAlignLayout.Client;
  edAddress.TextPrompt := 'or a port / address, e.g. COM5 or 192.168.0.10:35000';

  R := Row(Top, H);
  btnRun := AddButton(R, 'Run tests', 110, RunClick);
  btnStream := AddButton(R, 'Stream 30 s', 110, StreamClick);
  btnStop := AddButton(R, 'Stop', 70, StopClick);
  btnClose := AddButton(R, 'Disconnect', 110, CloseClick);

  R := Row(Top, H);
  btnSend := AddButton(R, 'Send', 80, SendClick);
  btnSend.Align := TAlignLayout.Right;
  btnSend.Margins.Right := 0;
  btnSend.Margins.Left := 6;
  edCmd := TEdit.Create(Self);
  edCmd.Parent := R;
  edCmd.Align := TAlignLayout.Client;
  edCmd.TextPrompt := 'command, e.g. ATI or 6C10F13C01 is sent as typed';
  edCmd.OnKeyDown := CmdKeyDown;

  lblFile := TLabel.Create(Self);
  lblFile.Parent := Self;
  lblFile.Align := TAlignLayout.Bottom;
  lblFile.Height := 36;
  lblFile.Margins.Rect := TRectF.Create(6, 0, 6, 4);
  lblFile.Text := 'Log folder: ' + LogFolder;
  lblFile.WordWrap := True;

  mmLog := TMemo.Create(Self);
  mmLog.Parent := Self;
  mmLog.Align := TAlignLayout.Client;
  mmLog.Margins.Rect := TRectF.Create(6, 6, 6, 6);
  mmLog.ReadOnly := True;
  mmLog.TextSettings.Font.Family := {$IFDEF ANDROID}'monospace'{$ELSE}'Consolas'{$ENDIF};
  mmLog.TextSettings.Font.Size := {$IFDEF ANDROID}11{$ELSE}12{$ENDIF};
  mmLog.StyledSettings := mmLog.StyledSettings - [TStyledSetting.Family, TStyledSetting.Size];
end;

procedure TProbeForm.FillPorts;
var
  S, Old: string;
begin
  Old := cbPort.Text;
  cbPort.Items.Clear;
  {$IFDEF ANDROID}
  for S in ListBluetoothPorts do
    cbPort.Items.Add(S);
  if cbPort.Count = 0 then
    LogLine('No Bluetooth ports: ' + BluetoothDiagnostics);
  {$ENDIF}
  for S in ListSerialPorts do
    cbPort.Items.Add(S);
  cbPort.Items.Add('192.168.0.10:35000');
  cbPort.ItemIndex := Max(0, cbPort.Items.IndexOf(Old));
end;

function TProbeForm.ChosenPort: string;
begin
  Result := edAddress.Text.Trim;
  if Result = '' then
    Result := cbPort.Text;
end;

{ The runner for the chosen port (a new one when the port changed). }
function TProbeForm.Runner: TProbeRunner;
var
  Port: string;
begin
  Port := ChosenPort;
  if (FRunner <> nil) and (Port <> FRunnerPort) then
  begin
    FRunner.RequestStop;
    FRunner.Post('QUIT');
    FRunner.WaitFor;
    FreeAndNil(FRunner);
  end;
  if FRunner = nil then
  begin
    FRunnerPort := Port;
    FRunner := TProbeRunner.Create(Port, StrToIntDef(cbBaud.Text, 38400), LogFolder,
      procedure(const Line: string)
      begin
        PendingLock.Enter;
        try
          FPending.Add(Line);
        finally
          PendingLock.Leave;
        end;
      end);
    lblFile.Text := 'Log: ' + FRunner.LogFileName;
  end;
  Result := FRunner;
end;

procedure TProbeForm.LogLine(const Line: string);
begin
  PendingLock.Enter;
  try
    FPending.Add(Line);
  finally
    PendingLock.Leave;
  end;
end;

procedure TProbeForm.TimerTick(Sender: TObject);
var
  Lines: TArray<string>;
  S: string;
begin
  PendingLock.Enter;
  try
    Lines := FPending.ToStringArray;
    FPending.Clear;
  finally
    PendingLock.Leave;
  end;
  if Lines = nil then
    Exit;
  mmLog.BeginUpdate;
  try
    for S in Lines do
    begin
      mmLog.Lines.Add(S);
      if S.Contains('(done: TESTS)') then
        FDoneSeen := True;
    end;
    // Keep the memo light on a phone.
    while mmLog.Lines.Count > 3000 do
      mmLog.Lines.Delete(0);
  finally
    mmLog.EndUpdate;
  end;
  mmLog.GoToTextEnd;
  if FExitWhenDone and FDoneSeen then
    Close;
end;

procedure TProbeForm.RefreshClick(Sender: TObject);
begin
  FillPorts;
end;

procedure TProbeForm.RunClick(Sender: TObject);
begin
  Runner.Post('TESTS');
end;

procedure TProbeForm.StopClick(Sender: TObject);
begin
  if FRunner <> nil then
    FRunner.RequestStop;
end;

procedure TProbeForm.StreamClick(Sender: TObject);
begin
  Runner.Post('STREAM 30');
end;

procedure TProbeForm.SendClick(Sender: TObject);
begin
  if edCmd.Text.Trim = '' then
    Exit;
  Runner.Post('CMD ' + edCmd.Text.Trim);
  edCmd.Text := '';
end;

procedure TProbeForm.CmdKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if Key = vkReturn then
  begin
    Key := 0;
    SendClick(nil);
  end;
end;

procedure TProbeForm.CloseClick(Sender: TObject);
begin
  if FRunner <> nil then
    FRunner.Post('DISCONNECT');
end;

procedure TProbeForm.ApplyStartOptions;
var
  Port: string;
  Run: Boolean;
  I: Integer;
  {$IFDEF ANDROID}
  Intent: JIntent;
  {$ENDIF}
begin
  Port := '';
  Run := False;
  {$IFDEF ANDROID}
  Intent := TAndroidHelper.Activity.getIntent;
  if Intent <> nil then
  begin
    if Intent.hasExtra(StringToJString('port')) then
      Port := JStringToString(Intent.getStringExtra(StringToJString('port')));
    Run := Intent.getBooleanExtra(StringToJString('run'), False);
  end;
  {$ELSE}
  I := 1;
  while I <= ParamCount do
  begin
    if SameText(ParamStr(I), '-port') and (I < ParamCount) then
    begin
      Inc(I);
      Port := ParamStr(I);
    end
    else if SameText(ParamStr(I), '-baud') and (I < ParamCount) then
    begin
      Inc(I);
      if cbBaud.Items.IndexOf(ParamStr(I)) < 0 then
        cbBaud.Items.Add(ParamStr(I));
      cbBaud.ItemIndex := cbBaud.Items.IndexOf(ParamStr(I));
    end
    else if SameText(ParamStr(I), '-run') then
      Run := True
    else if SameText(ParamStr(I), '-exit') then
      FExitWhenDone := True;
    Inc(I);
  end;
  {$ENDIF}
  if Port <> '' then
  begin
    cbPort.ItemIndex := -1;
    for I := 0 to cbPort.Count - 1 do
      if (cbPort.ItemIndex < 0) and cbPort.Items[I].ToLower.Contains(Port.ToLower) then
        cbPort.ItemIndex := I;
    if cbPort.ItemIndex < 0 then
      edAddress.Text := Port;
  end;
  if Run then
    RunClick(nil);
end;

initialization
  PendingLock := TCriticalSection.Create;
finalization
  PendingLock.Free;
end.
