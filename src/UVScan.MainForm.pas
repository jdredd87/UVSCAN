unit UVScan.MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Math, System.StrUtils, System.IOUtils, System.Generics.Collections, System.UITypes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Vcl.Grids,
  UVScan.Serial, UVScan.Simulator, UVScan.Pids, UVScan.Dpid, UVScan.Dtc, UVScan.Engine,
  UVScan.Class2, UVScan.Paths, UVScan.Settings, UVScan.PidEditor, UVScan.PidLists, UVScan.Defaults;

type
  TMainForm = class(TForm)
    pnlTop: TPanel;
    lblPort: TLabel;
    cbPort: TComboBox;
    btnRefreshPorts: TButton;
    cbBaud: TComboBox;
    btnConnect: TButton;
    btnDisconnect: TButton;
    bvlSep1: TBevel;
    btnStartScan: TButton;
    btnStopScan: TButton;
    bvlSep2: TBevel;
    btnLog: TButton;
    btnPause: TButton;
    pnlPids: TPanel;
    pnlListBar: TPanel;
    lblList: TLabel;
    cbLists: TComboBox;
    btnSaveList: TButton;
    btnDeleteList: TButton;
    edtSearch: TEdit;
    lvPids: TListView;
    pnlPidFooter: TPanel;
    lblBudget: TLabel;
    btnTestPids: TButton;
    btnClearSelection: TButton;
    btnEditPids: TButton;
    splLeft: TSplitter;
    pnlRight: TPanel;
    pnlNotice: TPanel;
    lblNotice: TLabel;
    pcMain: TPageControl;
    tsLive: TTabSheet;
    grdLive: TDrawGrid;
    pnlLiveFooter: TPanel;
    btnResetMinMax: TButton;
    lblLiveHint: TLabel;
    tsVehicle: TTabSheet;
    gbVehicle: TGroupBox;
    lblVinCaption: TLabel;
    lblVin: TLabel;
    lblOsidCaption: TLabel;
    lblOsid: TLabel;
    lblFirmwareCaption: TLabel;
    lblFirmware: TLabel;
    btnReadInfo: TButton;
    gbDtcs: TGroupBox;
    lvDtcs: TListView;
    pnlDtcButtons: TPanel;
    btnReadDtcs: TButton;
    btnClearDtcs: TButton;
    tsTools: TTabSheet;
    gbPcm: TGroupBox;
    btnResetLtft: TButton;
    btnCelOn: TButton;
    btnCelOff: TButton;
    gbWriteVin: TGroupBox;
    edtNewVin: TEdit;
    btnWriteVin: TButton;
    gbLogging: TGroupBox;
    lblLogFolderCaption: TLabel;
    edtLogFolder: TEdit;
    btnBrowseLogFolder: TButton;
    gbAdvanced: TGroupBox;
    lblRaw: TLabel;
    edtRaw: TEdit;
    btnSendRaw: TButton;
    chkTrace: TCheckBox;
    lblRate: TLabel;
    cbRate: TComboBox;
    tsMessages: TTabSheet;
    memLog: TMemo;
    pnlLogFooter: TPanel;
    btnClearMessages: TButton;
    sbMain: TStatusBar;
    tmrRefresh: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnRefreshPortsClick(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure btnStartScanClick(Sender: TObject);
    procedure btnStopScanClick(Sender: TObject);
    procedure btnLogClick(Sender: TObject);
    procedure btnPauseClick(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure lvPidsItemChecked(Sender: TObject; Item: TListItem);
    procedure btnTestPidsClick(Sender: TObject);
    procedure btnClearSelectionClick(Sender: TObject);
    procedure btnEditPidsClick(Sender: TObject);
    procedure cbListsChange(Sender: TObject);
    procedure btnSaveListClick(Sender: TObject);
    procedure btnDeleteListClick(Sender: TObject);
    procedure grdLiveDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure btnResetMinMaxClick(Sender: TObject);
    procedure btnReadInfoClick(Sender: TObject);
    procedure btnReadDtcsClick(Sender: TObject);
    procedure btnClearDtcsClick(Sender: TObject);
    procedure btnResetLtftClick(Sender: TObject);
    procedure btnCelOnClick(Sender: TObject);
    procedure btnCelOffClick(Sender: TObject);
    procedure btnWriteVinClick(Sender: TObject);
    procedure btnBrowseLogFolderClick(Sender: TObject);
    procedure btnSendRawClick(Sender: TObject);
    procedure chkTraceClick(Sender: TObject);
    procedure cbRateChange(Sender: TObject);
    procedure btnClearMessagesClick(Sender: TObject);
    procedure tmrRefreshTimer(Sender: TObject);
    procedure lblNoticeClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
  private
    FCatalog: TPidCatalog;
    FDtcs: TDtcCatalog;
    FEngine: TScanEngine;
    FState: TEngineState;
    FSelected: TList<Integer>;      // selected PID ids, catalog order
    FSupport: TDictionary<Integer, Boolean>; // PID test results
    FRejected: TList<Integer>;
    FLiveIds: TArray<Integer>;
    FLive: TLiveSnapshot;
    FMin, FMax: TArray<Double>;
    FUpdatingList: Boolean;
    FLogging: Boolean;
    FLogPaused: Boolean;
    FClosing: Boolean;
    FAutoScan: Boolean;
    FAutoLog: Boolean;
    FSettings: TAppSettings;
    FLists: TPidLists;
    procedure FillLists(const Select: string);
    procedure SaveLists;
    procedure ApplyCommandLine;
    procedure LoadData;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure FillPorts(const Select: string);
    procedure FillPidList;
    procedure SetSelected(Id: Integer; Checked: Boolean);
    procedure UpdateBudget;
    procedure UpdateControls;
    procedure HandleEvent(const Ev: TEngineEvent);
    procedure AddMessage(const Text: string);
    procedure ShowNotice(const Text: string; IsError: Boolean);
    procedure Post(Kind: TEngineCommandKind); overload;
    procedure Post(const Cmd: TEngineCommand); overload;
    function LogFolder: string;
    function PidName(Id: Integer): string;
    procedure SetStatus(Panel: Integer; const Text: string);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

const
  SimulatorPort = 'Simulator';
  ColName = 0;
  ColValue = 1;
  ColUnits = 2;
  ColMin = 3;
  ColMax = 4;
  PanelState = 0;
  PanelPort = 1;
  PanelVin = 2;
  PanelOsid = 3;
  PanelRate = 4;
  PanelLog = 5;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FSelected := TList<Integer>.Create;
  FSupport := TDictionary<Integer, Boolean>.Create;
  FRejected := TList<Integer>.Create;
  FCatalog := TPidCatalog.Create;
  FDtcs := TDtcCatalog.Create;
  FSettings := TAppSettings.Create;
  FLists := TPidLists.Create;
  Caption := 'UVScan';
  pnlNotice.Visible := False;
  LoadData;
  LoadSettings;
  FillPidList;
  FEngine := TScanEngine.Create(FCatalog, HandleEvent);
  cbRateChange(nil);
  FEngine.SetTrace(chkTrace.Checked);
  grdLive.ColWidths[ColName] := 220;
  grdLive.ColWidths[ColValue] := 140;
  grdLive.ColWidths[ColUnits] := 80;
  grdLive.ColWidths[ColMin] := 100;
  grdLive.ColWidths[ColMax] := 100;
  FormResize(nil);
  FState := esDisconnected;
  UpdateControls;
  pcMain.ActivePage := tsLive;
  ApplyCommandLine;
end;

{ Same switches as legacy UVSCAN: -connect [-scan [-log]], plus -port <name>. }
procedure TMainForm.ApplyCommandLine;
var
  PortName: string;
begin
  if FindCmdLineSwitch('port', PortName, True, [clstValueNextParam]) then
  begin
    if cbPort.Items.IndexOf(PortName) < 0 then
      cbPort.Items.Insert(0, PortName);
    cbPort.ItemIndex := cbPort.Items.IndexOf(PortName);
  end;
  if not FindCmdLineSwitch('connect') then
    Exit;
  FAutoScan := FindCmdLineSwitch('scan');
  FAutoLog := FAutoScan and FindCmdLineSwitch('log');
  TThread.ForceQueue(nil,
    procedure
    begin
      btnConnect.Click;
    end);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FEngine.Free; // stops the scan, closes the port, waits for the thread
  FCatalog.Free;
  FSettings.Free;
  FLists.Free;
  FDtcs.Free;
  FSelected.Free;
  FSupport.Free;
  FRejected.Free;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FLogging and (MessageDlg('A log is being recorded. Stop logging and exit?', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes) then
  begin
    CanClose := False;
    Exit;
  end;
  FClosing := True;
  SaveSettings;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_F8) and btnLog.Enabled then
  begin
    btnLog.Click;
    Key := 0;
  end
  else if (Key = VK_F9) and btnPause.Enabled then
  begin
    btnPause.Click;
    Key := 0;
  end;
end;

procedure TMainForm.LoadData;
var
  F: string;
begin
  try
    for F in CreateMissingDataFiles do
      AddMessage('Created ' + F + ' from the built-in defaults');
  except
    on E: Exception do
      AddMessage('Could not create default data files: ' + E.Message);
  end;

  try
    FLists.LoadFromFile(ListsFile);
    for F in FLists.Warnings do
      AddMessage('Scan lists: ' + F);
  except
    on E: Exception do
      AddMessage('Could not load scan lists: ' + E.Message);
  end;

  F := PidsFile;
  if not FileExists(F) then
  begin
    ShowNotice('PID definitions not found: ' + F, True);
    Exit;
  end;
  try
    FCatalog.LoadFromFile(F);
  except
    on E: Exception do
    begin
      ShowNotice('Could not load PID definitions: ' + E.Message, True);
      AddMessage('Error: ' + E.Message);
      Exit;
    end;
  end;
  AddMessage(Format('Loaded %d PIDs from %s', [FCatalog.Count, F]));
  for F in FCatalog.Warnings do
    AddMessage('PID definitions: ' + F);
  if FCatalog.Warnings.Count > 0 then
    ShowNotice(Format('%d problem(s) in the PID definitions - see Messages', [FCatalog.Warnings.Count]), False);
  F := DtcsFile;
  if not FileExists(F) then
    AddMessage('Trouble code descriptions not found: ' + F)
  else
    try
      FDtcs.LoadFromFile(F);
      for F in FDtcs.Warnings do
        AddMessage('Trouble code descriptions: ' + F);
    except
      on E: Exception do
        AddMessage('Could not load trouble code descriptions: ' + E.Message);
    end;
end;

procedure TMainForm.LoadSettings;
var
  Problem: string;
  N: Integer;
begin
  FSettings.LoadFromFile(SettingsFile, Problem);
  if Problem <> '' then
  begin
    AddMessage('Settings: ' + Problem);
    ShowNotice('Settings could not be read - defaults used (see Messages)', False);
  end;

  FillPorts(FSettings.Port);
  cbBaud.ItemIndex := cbBaud.Items.IndexOf(IntToStr(FSettings.Baud));
  if cbBaud.ItemIndex < 0 then
    cbBaud.ItemIndex := 0;
  edtLogFolder.Text := FSettings.LogFolder;
  cbRate.ItemIndex := Ord(FSettings.StreamSpeed);
  chkTrace.Checked := FSettings.Trace;
  for N in FSettings.SelectedPids do
    if (FCatalog.FindById(N) <> nil) and FCatalog.FindById(N).Enabled and not FSelected.Contains(N) then
      FSelected.Add(N);
  FillLists(FSettings.ActiveList);
  if FSettings.Window.Saved then
  begin
    Position := poDesigned;
    SetBounds(FSettings.Window.Left, FSettings.Window.Top, FSettings.Window.Width, FSettings.Window.Height);
    MakeFullyVisible;
    if FSettings.Window.Maximized then
      WindowState := wsMaximized;
    if FSettings.Window.PidPanelWidth > 0 then
      pnlPids.Width := FSettings.Window.PidPanelWidth;
  end;
end;

procedure TMainForm.SaveSettings;
var
  Placement: TWindowPlacement;
begin
  FSettings.Port := cbPort.Text;
  FSettings.Baud := StrToIntDef(cbBaud.Text, 115200);
  FSettings.LogFolder := edtLogFolder.Text;
  FSettings.StreamSpeed := TStreamSpeed(Max(0, cbRate.ItemIndex));
  FSettings.Trace := chkTrace.Checked;
  FSettings.SelectedPids := FSelected.ToArray;
  if cbLists.ItemIndex > 0 then
    FSettings.ActiveList := cbLists.Text
  else
    FSettings.ActiveList := '';
  Placement.length := SizeOf(Placement);
  GetWindowPlacement(Handle, @Placement);
  FSettings.Window.Left := Placement.rcNormalPosition.Left;
  FSettings.Window.Top := Placement.rcNormalPosition.Top;
  FSettings.Window.Width := Placement.rcNormalPosition.Width;
  FSettings.Window.Height := Placement.rcNormalPosition.Height;
  FSettings.Window.Maximized := WindowState = wsMaximized;
  FSettings.Window.PidPanelWidth := pnlPids.Width;
  FSettings.Window.Saved := True;
  try
    FSettings.SaveToFile(SettingsFile);
  except
    on E: Exception do
      MessageDlg('Settings could not be saved: ' + E.Message, mtWarning, [mbOK], 0);
  end;
end;

procedure TMainForm.FillPorts(const Select: string);
var
  P: string;
begin
  cbPort.Items.BeginUpdate;
  try
    cbPort.Items.Clear;
    for P in ListSerialPorts do
      cbPort.Items.Add(P);
    cbPort.Items.Add(SimulatorPort);
  finally
    cbPort.Items.EndUpdate;
  end;
  cbPort.ItemIndex := cbPort.Items.IndexOf(Select);
  if cbPort.ItemIndex < 0 then
    cbPort.ItemIndex := 0;
end;

procedure TMainForm.btnRefreshPortsClick(Sender: TObject);
begin
  FillPorts(cbPort.Text);
end;

{ PID list }

procedure TMainForm.FillPidList;
var
  Cat: TPidCategory;
  Group: TListGroup;
  GroupIds: array[TPidCategory] of Integer;
  I: Integer;
  P: TPidDef;
  Item: TListItem;
  Filter, Status: string;
  Supported: Boolean;
begin
  Filter := LowerCase(Trim(edtSearch.Text));
  FUpdatingList := True;
  lvPids.Items.BeginUpdate;
  try
    lvPids.Items.Clear;
    lvPids.Groups.Clear;
    for Cat := Low(TPidCategory) to High(TPidCategory) do
    begin
      Group := lvPids.Groups.Add;
      Group.Header := CategoryNames[Cat];
      Group.State := [lgsCollapsible];
      GroupIds[Cat] := Group.GroupID;
    end;
    for I := 0 to FCatalog.Count - 1 do
    begin
      P := FCatalog[I];
      if not P.Enabled then
        Continue;
      if (Filter <> '') and (Pos(Filter, LowerCase(P.LongName + ' ' + P.ShortName + ' ' + P.PidCode)) = 0) then
        Continue;
      Item := lvPids.Items.Add;
      Item.Caption := P.LongName;
      Item.SubItems.Add(P.Units);
      case P.Kind of
        pkVehicle: Item.SubItems.Add(IntToStr(P.DataLength));
        pkCalculated: Item.SubItems.Add('calc');
        pkAnalog: Item.SubItems.Add('A/D');
      end;
      Status := '';
      if FSupport.TryGetValue(P.Id, Supported) then
        Status := IfThen(Supported, 'yes', 'no');
      if FRejected.Contains(P.Id) then
        Status := 'rejected';
      Item.SubItems.Add(Status);
      Item.Data := Pointer(P.Id);
      Item.GroupID := GroupIds[P.Category];
      Item.Checked := FSelected.Contains(P.Id);
    end;
  finally
    lvPids.Items.EndUpdate;
    FUpdatingList := False;
  end;
  UpdateBudget;
end;

procedure TMainForm.SetSelected(Id: Integer; Checked: Boolean);
var
  I: Integer;
  Ordered: TList<Integer>;
begin
  if Checked = FSelected.Contains(Id) then
    Exit;
  if Checked then
    FSelected.Add(Id)
  else
    FSelected.Remove(Id);
  // Keep catalog order so the live view and log columns are stable.
  Ordered := TList<Integer>.Create;
  try
    for I := 0 to FCatalog.Count - 1 do
      if FSelected.Contains(FCatalog[I].Id) then
        Ordered.Add(FCatalog[I].Id);
    FSelected.Clear;
    FSelected.AddRange(Ordered);
  finally
    Ordered.Free;
  end;
end;

procedure TMainForm.lvPidsItemChecked(Sender: TObject; Item: TListItem);
begin
  if FUpdatingList then
    Exit;
  SetSelected(Integer(Item.Data), Item.Checked);
  UpdateBudget;
end;

procedure TMainForm.edtSearchChange(Sender: TObject);
begin
  FillPidList;
end;

procedure TMainForm.btnEditPidsClick(Sender: TObject);
var
  I: Integer;
  P: TPidDef;
begin
  // The engine only uses the catalog while scanning or busy, which this button excludes.
  if not (FState in [esDisconnected, esConnected]) then
    Exit;
  if not TPidEditorForm.Execute(FCatalog, PidsFile) then
    Exit;
  try
    FCatalog.LoadFromFile(PidsFile);
  except
    on E: Exception do
    begin
      ShowNotice('Could not reload PID definitions: ' + E.Message, True);
      Exit;
    end;
  end;
  for I := FSelected.Count - 1 downto 0 do
  begin
    P := FCatalog.FindById(FSelected[I]);
    if (P = nil) or not P.Enabled then
      FSelected.Delete(I);
  end;
  FSupport.Clear;
  FRejected.Clear;
  FillPidList;
  AddMessage(Format('PID definitions saved (%d PIDs) to %s', [FCatalog.Count, PidsFile]));
end;

{ Scan lists }

const
  NoListCaption = '(none)';

procedure TMainForm.FillLists(const Select: string);
var
  Name: string;
begin
  cbLists.Items.BeginUpdate;
  try
    cbLists.Items.Clear;
    cbLists.Items.Add(NoListCaption);
    for Name in FLists.Names do
      cbLists.Items.Add(Name);
  finally
    cbLists.Items.EndUpdate;
  end;
  cbLists.ItemIndex := Max(0, cbLists.Items.IndexOf(Select));
  btnDeleteList.Enabled := cbLists.ItemIndex > 0;
end;

procedure TMainForm.SaveLists;
begin
  try
    FLists.SaveToFile(ListsFile);
  except
    on E: Exception do
      MessageDlg('Could not save the scan lists: ' + E.Message, mtWarning, [mbOK], 0);
  end;
end;

procedure TMainForm.cbListsChange(Sender: TObject);
var
  I, Id, Missing: Integer;
  P: TPidDef;
begin
  btnDeleteList.Enabled := cbLists.ItemIndex > 0;
  if cbLists.ItemIndex <= 0 then
    Exit;
  I := FLists.IndexOf(cbLists.Text);
  if I < 0 then
    Exit;
  FSelected.Clear;
  Missing := 0;
  for Id in FLists[I].PidIds do
  begin
    P := FCatalog.FindById(Id);
    if (P <> nil) and P.Enabled then
      SetSelected(Id, True)
    else
      Inc(Missing);
  end;
  edtSearch.Text := '';
  FillPidList;
  if Missing > 0 then
    ShowNotice(Format('Scan list "%s": %d PID(s) no longer exist or are disabled', [cbLists.Text, Missing]), False);
end;

procedure TMainForm.btnSaveListClick(Sender: TObject);
var
  Name: string;
begin
  if FSelected.Count = 0 then
  begin
    ShowNotice('Tick some PIDs first, then save them as a list', True);
    Exit;
  end;
  if cbLists.ItemIndex > 0 then
    Name := cbLists.Text
  else
    Name := '';
  if not InputQuery('Save scan list', 'List name', Name) then
    Exit;
  Name := Trim(Name);
  if Name = '' then
    Exit;
  if (FLists.IndexOf(Name) >= 0) and not SameText(Name, cbLists.Text) and
    (MessageDlg(Format('Replace the existing list "%s"?', [Name]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;
  FLists.Put(Name, FSelected.ToArray);
  SaveLists;
  FillLists(Name);
  AddMessage(Format('Saved scan list "%s" (%d PIDs)', [Name, FSelected.Count]));
end;

procedure TMainForm.btnDeleteListClick(Sender: TObject);
var
  Name: string;
begin
  if cbLists.ItemIndex <= 0 then
    Exit;
  Name := cbLists.Text;
  if MessageDlg(Format('Delete the scan list "%s"? The PIDs themselves are not affected.', [Name]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FLists.Delete(Name);
  SaveLists;
  FillLists('');
end;

procedure TMainForm.btnClearSelectionClick(Sender: TObject);
begin
  FSelected.Clear;
  FillPidList;
end;

procedure TMainForm.UpdateBudget;
var
  Id, Bytes, Count: Integer;
  P: TPidDef;
  Reqs: TArray<TDpidRequest>;
  R: TDpidRequest;
  Dpids: string;
begin
  Bytes := 0;
  Count := 0;
  Reqs := nil;
  for Id in FSelected do
  begin
    P := FCatalog.FindById(Id);
    if P = nil then
      Continue;
    Inc(Count);
    if P.Kind = pkVehicle then
    begin
      Inc(Bytes, P.DataLength);
      R.Item := Length(Reqs);
      R.Pid := P.PidNumber;
      R.Size := P.DataLength;
      Reqs := Reqs + [R];
    end;
  end;
  try
    Dpids := Format('%d DPID(s)', [Length(PlanDpids(Reqs).Dpids)]);
    lblBudget.Font.Color := clWindowText;
  except
    on E: EDpidPlanError do
    begin
      Dpids := 'too many!';
      lblBudget.Font.Color := clRed;
    end;
  end;
  lblBudget.Caption := Format('%d selected  -  %d / %d bytes  -  %s',
    [Count, Bytes, MaxDpids * DpidDataBytes, Dpids]);
end;

procedure TMainForm.btnTestPidsClick(Sender: TObject);
var
  Cmd: TEngineCommand;
  Id: Integer;
  P: TPidDef;
begin
  Cmd := Command(ecTestPids);
  for Id in FSelected do
  begin
    P := FCatalog.FindById(Id);
    if (P <> nil) and (P.Kind = pkVehicle) then
      Cmd.PidIds := Cmd.PidIds + [Id];
  end;
  if (Length(Cmd.PidIds) = 0) and (MessageDlg('No vehicle PIDs are selected. Test every PID in the list?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;
  FSupport.Clear;
  Post(Cmd);
  pcMain.ActivePage := tsMessages;
end;

{ Connection and scanning }

procedure TMainForm.Post(Kind: TEngineCommandKind);
begin
  Post(Command(Kind));
end;

procedure TMainForm.Post(const Cmd: TEngineCommand);
begin
  pnlNotice.Visible := False;
  FEngine.Post(Cmd);
end;

procedure TMainForm.btnConnectClick(Sender: TObject);
var
  Cmd: TEngineCommand;
  PortName: string;
  Baud: Cardinal;
begin
  PortName := cbPort.Text;
  if PortName = '' then
  begin
    ShowNotice('Choose a COM port first', True);
    Exit;
  end;
  Baud := StrToIntDef(cbBaud.Text, 115200);
  Cmd := Command(ecConnect);
  if PortName = SimulatorPort then
    Cmd.Factory :=
      function: ISerialPort
      begin
        Result := TSimulatedAvt.Create;
      end
  else
    Cmd.Factory :=
      function: ISerialPort
      begin
        Result := TWin32SerialPort.Create(PortName, Baud, fcRtsCts);
      end;
  SetStatus(PanelPort, PortName);
  Post(Cmd);
end;

procedure TMainForm.btnDisconnectClick(Sender: TObject);
begin
  Post(ecDisconnect);
end;

procedure TMainForm.btnStartScanClick(Sender: TObject);
var
  Cmd: TEngineCommand;
begin
  if FSelected.Count = 0 then
  begin
    ShowNotice('Tick the PIDs to scan in the list on the left', True);
    Exit;
  end;
  FRejected.Clear;
  Cmd := Command(ecStartScan);
  Cmd.PidIds := FSelected.ToArray;
  Post(Cmd);
end;

procedure TMainForm.btnStopScanClick(Sender: TObject);
begin
  Post(ecStopScan);
end;

function TMainForm.LogFolder: string;
begin
  Result := Trim(edtLogFolder.Text);
  if Result = '' then
    Result := TPath.Combine(TPath.GetDocumentsPath, 'UVScan Logs');
end;

procedure TMainForm.btnLogClick(Sender: TObject);
var
  Cmd: TEngineCommand;
begin
  if FLogging then
  begin
    Post(ecStopLog);
    Exit;
  end;
  ForceDirectories(LogFolder);
  Cmd := Command(ecStartLog);
  Cmd.Text := TPath.Combine(LogFolder, 'UVScan_' + FormatDateTime('yyyy-mm-dd_hhnnss', Now) + '.csv');
  Post(Cmd);
end;

procedure TMainForm.btnPauseClick(Sender: TObject);
var
  Cmd: TEngineCommand;
begin
  Cmd := Command(ecPauseLog);
  Cmd.Flag := not FLogPaused;
  Post(Cmd);
end;

{ Engine events }

procedure TMainForm.HandleEvent(const Ev: TEngineEvent);
var
  D: TDtcEntry;
  Item: TListItem;
begin
  if FClosing then
    Exit;
  case Ev.Kind of
    eeLog:
      AddMessage(Ev.Text);
    eeWarning:
      begin
        AddMessage('Warning: ' + Ev.Text);
        ShowNotice(Ev.Text, False);
      end;
    eeError:
      begin
        AddMessage('Error: ' + Ev.Text);
        ShowNotice(Ev.Text, True);
      end;
    eeState:
      begin
        FState := Ev.State;
        SetStatus(PanelState, StateNames[FState]);
        if (FState = esConnected) and FAutoScan then
        begin
          FAutoScan := False;
          btnStartScan.Click;
        end;
        if FState = esDisconnected then
        begin
          FAutoScan := False;
          FAutoLog := False;
        end;
        if FState = esDisconnected then
        begin
          FLogging := False;
          SetStatus(PanelRate, '');
        end;
        UpdateControls;
      end;
    eeVehicleInfo:
      begin
        lblFirmware.Caption := IfThen(Ev.Vehicle.Firmware = '', '-', Ev.Vehicle.Firmware);
        lblVin.Caption := IfThen(Ev.Vehicle.Vin = '', '-', Ev.Vehicle.Vin);
        lblOsid.Caption := IfThen(Ev.Vehicle.Osid = '', '-', Ev.Vehicle.Osid);
        SetStatus(PanelVin, 'VIN ' + lblVin.Caption);
        SetStatus(PanelOsid, 'OSID ' + lblOsid.Caption);
      end;
    eeScanStarted:
      begin
        FLiveIds := Ev.PidIds;
        SetLength(FMin, Length(FLiveIds));
        SetLength(FMax, Length(FLiveIds));
        btnResetMinMax.Click;
        grdLive.RowCount := Max(2, Length(FLiveIds) + 1);
        lblLiveHint.Visible := False;
        pcMain.ActivePage := tsLive;
        grdLive.Invalidate;
        if FAutoLog then
        begin
          FAutoLog := False;
          btnLog.Click;
        end;
      end;
    eePidRejected:
      begin
        if not FRejected.Contains(Ev.PidId) then
          FRejected.Add(Ev.PidId);
        AddMessage(Ev.Text);
        FillPidList;
      end;
    eePidTest:
      begin
        FSupport.AddOrSetValue(Ev.PidId, Ev.Supported);
        AddMessage(Format('[%d/%d] %s: %s', [Ev.Progress, Ev.Total, PidName(Ev.PidId),
          IfThen(Ev.Supported, 'supported', 'NOT supported')]));
        if Ev.Progress = Ev.Total then
          FillPidList;
      end;
    eeDtcs:
      begin
        lvDtcs.Items.BeginUpdate;
        try
          lvDtcs.Items.Clear;
          for D in Ev.Dtcs do
          begin
            Item := lvDtcs.Items.Add;
            Item.Caption := D.Code;
            Item.SubItems.Add(ModuleName(D.Module));
            Item.SubItems.Add(FDtcs.Describe(D.Code));
            Item.SubItems.Add('$' + IntToHex(D.Status, 2));
          end;
          if Length(Ev.Dtcs) = 0 then
          begin
            Item := lvDtcs.Items.Add;
            Item.Caption := 'None';
            Item.SubItems.Add('');
            Item.SubItems.Add('No trouble codes reported');
          end;
        finally
          lvDtcs.Items.EndUpdate;
        end;
        pcMain.ActivePage := tsVehicle;
      end;
    eeLogStarted:
      begin
        FLogging := True;
        FLogPaused := False;
        SetStatus(PanelLog, 'Logging to ' + ExtractFileName(Ev.Text));
        UpdateControls;
      end;
    eeLogStopped:
      begin
        FLogging := False;
        FLogPaused := False;
        SetStatus(PanelLog, '');
        UpdateControls;
      end;
  end;
end;

procedure TMainForm.UpdateControls;
var
  Connected, Idle: Boolean;
begin
  Connected := FState in [esConnected, esScanning, esBusy];
  Idle := FState = esConnected;
  cbPort.Enabled := FState = esDisconnected;
  cbBaud.Enabled := FState = esDisconnected;
  btnRefreshPorts.Enabled := FState = esDisconnected;
  btnConnect.Enabled := FState = esDisconnected;
  btnDisconnect.Enabled := Connected;
  btnStartScan.Enabled := Idle or (FState = esScanning);
  btnStartScan.Caption := IfThen(FState = esScanning, 'Restart scan', 'Start scan');
  btnStopScan.Enabled := FState in [esScanning, esBusy];
  btnStopScan.Caption := IfThen(FState = esBusy, 'Cancel', 'Stop scan');
  btnLog.Enabled := FState = esScanning;
  btnLog.Caption := IfThen(FLogging, 'Stop log (F8)', 'Start log (F8)');
  btnPause.Enabled := FLogging;
  btnPause.Caption := IfThen(FLogPaused, 'Resume (F9)', 'Pause (F9)');
  btnTestPids.Enabled := Idle;
  btnEditPids.Enabled := FState in [esDisconnected, esConnected];
  btnReadInfo.Enabled := Idle;
  btnReadDtcs.Enabled := Idle;
  btnClearDtcs.Enabled := Idle;
  btnResetLtft.Enabled := Idle;
  btnCelOn.Enabled := Idle;
  btnCelOff.Enabled := Idle;
  btnWriteVin.Enabled := Idle;
  btnSendRaw.Enabled := Idle;
  if FState = esScanning then
    pnlTop.Color := $00D8F0D8
  else
    pnlTop.Color := clBtnFace;
  if FLogging then
    pnlTop.Color := IfThen(FLogPaused, $00B0E0FF, $0090EE90);
end;

procedure TMainForm.tmrRefreshTimer(Sender: TObject);
var
  I: Integer;
  V: Double;
begin
  if FState <> esScanning then
    Exit;
  FLive := FEngine.GetSnapshot;
  if Length(FLive.Values) <> Length(FLiveIds) then
    Exit;
  for I := 0 to High(FLive.Values) do
  begin
    V := FLive.Values[I];
    if IsNan(V) then
      Continue;
    if IsNan(FMin[I]) or (V < FMin[I]) then
      FMin[I] := V;
    if IsNan(FMax[I]) or (V > FMax[I]) then
      FMax[I] := V;
  end;
  if FLive.LogPaused <> FLogPaused then
  begin
    FLogPaused := FLive.LogPaused;
    UpdateControls;
  end;
  SetStatus(PanelRate, Format('%.1f updates/s', [FLive.CyclesPerSecond]));
  if FLive.Logging then
    SetStatus(PanelLog, Format('Logging: %d rows%s', [FLive.LogRows, IfThen(FLive.LogPaused, ' (paused)', '')]));
  grdLive.Invalidate;
end;

procedure TMainForm.grdLiveDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
const
  Headers: array[0..4] of string = ('PID', 'Value', 'Units', 'Min', 'Max');
var
  C: TCanvas;
  Text: string;
  P: TPidDef;
  Idx: Integer;
  Flags: Cardinal;
  R: TRect;
begin
  C := grdLive.Canvas;
  R := Rect;
  if ARow = 0 then
  begin
    C.Brush.Color := clBtnFace;
    C.FillRect(R);
    C.Font.Style := [fsBold];
    C.Font.Size := 9;
    C.Font.Color := clWindowText;
    InflateRect(R, -6, 0);
    Flags := DT_SINGLELINE or DT_VCENTER;
    if ACol in [ColValue, ColMin, ColMax] then
      Flags := Flags or DT_RIGHT;
    DrawText(C.Handle, PChar(Headers[ACol]), -1, R, Flags);
    Exit;
  end;

  Idx := ARow - 1;
  if Odd(ARow) then
    C.Brush.Color := clWindow
  else
    C.Brush.Color := $00F7F3F0;
  C.FillRect(R);
  if Idx > High(FLiveIds) then
    Exit;
  P := FCatalog.FindById(FLiveIds[Idx]);
  if P = nil then
    Exit;

  C.Font.Style := [];
  C.Font.Size := 10;
  C.Font.Color := clWindowText;
  Flags := DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS;
  Text := '';
  case ACol of
    ColName: Text := P.LongName;
    ColValue:
      begin
        if FRejected.Contains(P.Id) then
        begin
          Text := 'rejected';
          C.Font.Color := clGrayText;
        end
        else if Idx <= High(FLive.Text) then
        begin
          Text := FLive.Text[Idx];
          C.Font.Style := [fsBold];
          C.Font.Size := 14;
        end;
        Flags := Flags or DT_RIGHT;
      end;
    ColUnits: Text := P.Units;
    ColMin, ColMax:
      begin
        if ACol = ColMin then
          Text := P.FormatValue(FMin[Idx])
        else
          Text := P.FormatValue(FMax[Idx]);
        C.Font.Color := clGrayText;
        Flags := Flags or DT_RIGHT;
      end;
  end;
  InflateRect(R, -6, 0);
  DrawText(C.Handle, PChar(Text), -1, R, Flags);
end;

procedure TMainForm.btnResetMinMaxClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to High(FMin) do
  begin
    FMin[I] := NaN;
    FMax[I] := NaN;
  end;
  grdLive.Invalidate;
end;

{ Vehicle / tools }

procedure TMainForm.btnReadInfoClick(Sender: TObject);
begin
  Post(ecReadVehicleInfo);
end;

procedure TMainForm.btnReadDtcsClick(Sender: TObject);
begin
  lvDtcs.Items.Clear;
  Post(ecReadDtcs);
end;

procedure TMainForm.btnClearDtcsClick(Sender: TObject);
begin
  if MessageDlg('Clear trouble codes in the PCM?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    Post(ecClearDtcs);
end;

procedure TMainForm.btnResetLtftClick(Sender: TObject);
begin
  if MessageDlg('Reset long-term fuel trims?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    Post(ecResetLtft);
end;

procedure TMainForm.btnCelOnClick(Sender: TObject);
var
  Cmd: TEngineCommand;
begin
  Cmd := Command(ecCheckEngineLight);
  Cmd.Flag := True;
  Post(Cmd);
end;

procedure TMainForm.btnCelOffClick(Sender: TObject);
var
  Cmd: TEngineCommand;
begin
  Cmd := Command(ecCheckEngineLight);
  Cmd.Flag := False;
  Post(Cmd);
end;

procedure TMainForm.btnWriteVinClick(Sender: TObject);
var
  Cmd: TEngineCommand;
  Vin: string;
begin
  Vin := UpperCase(Trim(edtNewVin.Text));
  if not IsValidVin(Vin) then
  begin
    ShowNotice('A VIN is 17 characters, A-Z and 0-9', True);
    Exit;
  end;
  if MessageDlg(Format('Write VIN %s to the PCM?', [Vin]), mtWarning, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  Cmd := Command(ecWriteVin);
  Cmd.Text := Vin;
  Post(Cmd);
end;

procedure TMainForm.btnBrowseLogFolderClick(Sender: TObject);
var
  Dlg: TFileOpenDialog;
begin
  Dlg := TFileOpenDialog.Create(Self);
  try
    Dlg.Options := [fdoPickFolders, fdoPathMustExist];
    Dlg.DefaultFolder := LogFolder;
    if Dlg.Execute then
      edtLogFolder.Text := Dlg.FileName;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.btnSendRawClick(Sender: TObject);
var
  Cmd: TEngineCommand;
begin
  Cmd := Command(ecSendRaw);
  Cmd.Text := edtRaw.Text;
  Post(Cmd);
  pcMain.ActivePage := tsMessages;
end;

procedure TMainForm.chkTraceClick(Sender: TObject);
begin
  if FEngine <> nil then
    FEngine.SetTrace(chkTrace.Checked);
end;

procedure TMainForm.cbRateChange(Sender: TObject);
begin
  if (FEngine <> nil) and (cbRate.ItemIndex >= 0) then
    FEngine.StreamSpeed := StreamSpeedNibble(TStreamSpeed(cbRate.ItemIndex)); // applies from the next scan start
end;

{ Messages }

procedure TMainForm.AddMessage(const Text: string);
begin
  if memLog.Lines.Count > 5000 then
    memLog.Lines.Delete(0);
  memLog.Lines.Add(FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + Text);
end;

procedure TMainForm.btnClearMessagesClick(Sender: TObject);
begin
  memLog.Clear;
end;

procedure TMainForm.ShowNotice(const Text: string; IsError: Boolean);
begin
  lblNotice.Caption := Text + '   (click to dismiss)';
  if IsError then
    pnlNotice.Color := $00C8C8FF
  else
    pnlNotice.Color := $00C0F0FF;
  pnlNotice.Visible := True;
end;

procedure TMainForm.FormResize(Sender: TObject);
var
  Others: Integer;
begin
  if grdLive = nil then
    Exit;
  Others := grdLive.ColWidths[ColValue] + grdLive.ColWidths[ColUnits] + grdLive.ColWidths[ColMin] +
    grdLive.ColWidths[ColMax] + 5;
  grdLive.ColWidths[ColName] := Max(160, grdLive.ClientWidth - Others);
end;

procedure TMainForm.lblNoticeClick(Sender: TObject);
begin
  pnlNotice.Visible := False;
end;

function TMainForm.PidName(Id: Integer): string;
var
  P: TPidDef;
begin
  P := FCatalog.FindById(Id);
  if P <> nil then
    Result := P.LongName
  else
    Result := '#' + IntToStr(Id);
end;

procedure TMainForm.SetStatus(Panel: Integer; const Text: string);
begin
  sbMain.Panels[Panel].Text := Text;
end;

end.
