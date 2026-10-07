unit UVScan.MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Math, System.StrUtils, System.IOUtils, System.Generics.Collections, System.UITypes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, Vcl.Grids, Vcl.Menus,
  UVScan.Serial, UVScan.Simulator, UVScan.Pids, UVScan.Dpid, UVScan.Dtc, UVScan.Engine,
  UVScan.Class2, UVScan.Paths, UVScan.Settings, UVScan.PidEditor, UVScan.PidLists, UVScan.Defaults,
  UVScan.PidDiscovery, UVScan.Display, UVScan.Alerts, UVScan.Gauge, UVScan.Controls;

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
    chkSound: TCheckBox;
    btnLogViewer: TButton;
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
    btnLiveTest: TButton;
    lblLiveHint: TLabel;
    chkMinMax: TCheckBox;
    btnZoomOut: TButton;
    lblZoom: TLabel;
    btnZoomIn: TButton;
    tsDashboard: TTabSheet;
    pnlDashBar: TPanel;
    lblDashHint: TLabel;
    btnAddGauge: TButton;
    btnTickDashPids: TButton;
    btnDashTest: TButton;
    sbDash: TScrollBox;
    tsControls: TTabSheet;
    pnlCtlWarn: TPanel;
    lblCtlWarn: TLabel;
    pnlCtlBar: TPanel;
    btnCtlAdd: TButton;
    btnCtlEdit: TButton;
    btnCtlDup: TButton;
    btnCtlDelete: TButton;
    btnCtlRestore: TButton;
    btnReleaseAll: TButton;
    lvControls: TListView;
    pnlCtlRun: TPanel;
    lblCtlName: TLabel;
    lblCtlNotes: TLabel;
    lblCtlUnits: TLabel;
    btnCtlSend: TButton;
    btnCtlOn: TButton;
    btnCtlHold: TButton;
    tbCtlValue: TTrackBar;
    edtCtlValue: TEdit;
    btnCtlApply: TButton;
    btnCtlOff: TButton;
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
    gbDiscover: TGroupBox;
    btnDiscoverPids: TButton;
    lblDiscoverHelp: TLabel;
    lblRate: TLabel;
    cbRate: TComboBox;
    tsMessages: TTabSheet;
    memLog: TMemo;
    pnlLogFooter: TPanel;
    btnClearMessages: TButton;
    sbMain: TStatusBar;
    pmPid: TPopupMenu;
    miPidDisplay: TMenuItem;
    miPidGauge: TMenuItem;
    pmGauge: TPopupMenu;
    miGaugeEdit: TMenuItem;
    miGaugeDisplay: TMenuItem;
    miGaugeSep1: TMenuItem;
    miGaugeEarlier: TMenuItem;
    miGaugeLater: TMenuItem;
    miGaugeSep2: TMenuItem;
    miGaugeRemove: TMenuItem;
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
    procedure btnDiscoverPidsClick(Sender: TObject);
    procedure cbListsChange(Sender: TObject);
    procedure btnSaveListClick(Sender: TObject);
    procedure btnDeleteListClick(Sender: TObject);
    procedure grdLiveDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure btnResetMinMaxClick(Sender: TObject);
    procedure btnReadInfoClick(Sender: TObject);
    procedure btnReadDtcsClick(Sender: TObject);
    procedure btnClearDtcsClick(Sender: TObject);
    procedure btnCtlAddClick(Sender: TObject);
    procedure btnCtlEditClick(Sender: TObject);
    procedure btnCtlDupClick(Sender: TObject);
    procedure btnCtlDeleteClick(Sender: TObject);
    procedure btnCtlRestoreClick(Sender: TObject);
    procedure btnReleaseAllClick(Sender: TObject);
    procedure lvControlsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure lvControlsCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
      var DefaultDraw: Boolean);
    procedure btnCtlSendClick(Sender: TObject);
    procedure btnCtlOnClick(Sender: TObject);
    procedure btnCtlOffClick(Sender: TObject);
    procedure btnCtlHoldMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure btnCtlHoldMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure tbCtlValueChange(Sender: TObject);
    procedure btnCtlApplyClick(Sender: TObject);
    procedure btnWriteVinClick(Sender: TObject);
    procedure btnBrowseLogFolderClick(Sender: TObject);
    procedure btnSendRawClick(Sender: TObject);
    procedure chkTraceClick(Sender: TObject);
    procedure cbRateChange(Sender: TObject);
    procedure btnClearMessagesClick(Sender: TObject);
    procedure tmrRefreshTimer(Sender: TObject);
    procedure lblNoticeClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure chkSoundClick(Sender: TObject);
    procedure btnLogViewerClick(Sender: TObject);
    procedure btnAddGaugeClick(Sender: TObject);
    procedure btnTickDashPidsClick(Sender: TObject);
    procedure btnTestDisplayClick(Sender: TObject);
    procedure chkMinMaxClick(Sender: TObject);
    procedure btnZoomOutClick(Sender: TObject);
    procedure btnZoomInClick(Sender: TObject);
    procedure lblZoomClick(Sender: TObject);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint; var Handled: Boolean);
    procedure sbDashResize(Sender: TObject);
    procedure pmPidPopup(Sender: TObject);
    procedure miPidDisplayClick(Sender: TObject);
    procedure miPidGaugeClick(Sender: TObject);
    procedure pmGaugePopup(Sender: TObject);
    procedure miGaugeEditClick(Sender: TObject);
    procedure miGaugeDisplayClick(Sender: TObject);
    procedure miGaugeEarlierClick(Sender: TObject);
    procedure miGaugeLaterClick(Sender: TObject);
    procedure miGaugeRemoveClick(Sender: TObject);
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
    FDiscovery: TPidDiscoveryForm;
    FPendingLog: TStringList;   // message lines waiting for the next timer tick
    FShownRows: TArray<string>; // what each live row last showed (value|min|max)
    FShownCycles: Int64;
    FDisplay: TDisplaySettings;      // display.json: PID looks, alert levels, gauges
    FAlerts: TAlertTracker;
    FRowStyles: TArray<TResolvedStyle>; // per live row, as last evaluated
    FFlashOn: Boolean;
    FGaugeViews: TList<TGaugeView>;
    FMenuPidId: Integer;             // PID the PID/grid right-click menu is about
    FMenuGauge: Integer;             // gauge index the gauge menu is about
    FTestMode: Boolean;              // "Test display": made-up values instead of the PCM
    FTestStart: UInt64;
    FTestLo, FTestHi: TArray<Double>;
    FControls: TControlList;         // controls.json
    FControlResult: TDictionary<string, string>;  // control name -> last result
    FControlActive: TDictionary<string, Boolean>; // control name -> held by the engine
    FHolding: Boolean;               // "hold to run" button is down
    FLastLogFile: string;            // the log recorded most recently
    FViewerLog: string;              // the log last handed to the viewer
    FZoom: Integer;                  // live grid zoom, percent
    FBaseRowHeight: Integer;         // the grid's row height at 100%
    procedure SetZoom(Percent: Integer);
    procedure ZoomStep(Direction: Integer);
    procedure ApplyGridLayout;
    function ZoomPx(N: Integer): Integer;
    function ZoomPt(Points: Integer): Integer;
    function LastLiveCol: Integer;
    procedure LoadControls;
    procedure SaveControls;
    procedure FillControls(const Select: string);
    function SelectedControl: TControlDef;
    procedure UpdateControlPanel;
    function ControlsUsable: Boolean;
    procedure SendControl(C: TControlDef; TurnOn: Boolean; const Value: Double = 0);
    procedure EditControl(C: TControlDef; IsNew: Boolean);
    procedure SetupLiveRows(const Ids: TArray<Integer>);
    procedure StartTest;
    procedure StopTest;
    function TestSnapshot: TLiveSnapshot;
    function LiveActive: Boolean;
    procedure RefreshLiveRows;
    procedure InvalidateLiveRow(Idx: Integer);
    procedure UpdateAlerts;
    procedure ApplyRowHeights;
    procedure LoadDisplay;
    procedure SaveDisplay;
    procedure DisplayChanged;
    procedure EditDisplay(PidId: Integer);
    procedure AddGauge(PidId: Integer);
    procedure EditGauge(Index: Integer);
    procedure MoveGauge(Delta: Integer);
    procedure BuildDashboard;
    procedure LayoutDashboard;
    procedure RefreshDashboard;
    procedure GaugeDblClick(Sender: TObject);
    function FlashPhase: Boolean;
    function LiveIndexOf(PidId: Integer): Integer;
    procedure FlushMessages;
    procedure ReloadCatalog;
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

uses
  System.JSON, UVScan.JsonFile, UVScan.DisplayEditor, UVScan.GaugeEditor, UVScan.ControlEditor,
  UVScan.LogViewer;

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
  FZoom := 100;
  FBaseRowHeight := grdLive.DefaultRowHeight; // already scaled to the screen DPI
  FSelected := TList<Integer>.Create;
  FSupport := TDictionary<Integer, Boolean>.Create;
  FRejected := TList<Integer>.Create;
  FCatalog := TPidCatalog.Create;
  FDtcs := TDtcCatalog.Create;
  FSettings := TAppSettings.Create;
  FPendingLog := TStringList.Create;
  FLists := TPidLists.Create;
  FDisplay := TDisplaySettings.Create;
  FControls := TControlList.Create;
  FControlResult := TDictionary<string, string>.Create;
  FControlActive := TDictionary<string, Boolean>.Create;
  FAlerts := TAlertTracker.Create;
  FGaugeViews := TList<TGaugeView>.Create;
  FMenuPidId := -1;
  FMenuGauge := -1;
  Caption := 'UVScan';
  pnlNotice.Visible := False;
  LoadData;
  LoadSettings;
  FillPidList;
  FEngine := TScanEngine.Create(FCatalog, HandleEvent);
  cbRateChange(nil);
  FEngine.SetTrace(chkTrace.Checked);
  SetZoom(FSettings.LiveZoom);
  grdLive.DoubleBuffered := True; // paint off-screen, then copy: no flicker
  sbDash.DoubleBuffered := True;
  BuildDashboard;
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
  FPendingLog.Free;
  FLists.Free;
  FDisplay.Free;
  FControls.Free;
  FControlResult.Free;
  FControlActive.Free;
  FAlerts.Free;
  FGaugeViews.Free; // the views themselves are owned by the form
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
  if (Key = VK_F7) and (Shift = []) then
  begin
    btnLogViewer.Click;
    Key := 0;
    Exit;
  end;
  if (Shift = [ssCtrl]) and (pcMain.ActivePage = tsLive) and
    ((Key = VK_ADD) or (Key = VK_OEM_PLUS) or (Key = VK_SUBTRACT) or (Key = VK_OEM_MINUS) or (Key = Ord('0')) or (Key = VK_NUMPAD0)) then
  begin
    if (Key = VK_ADD) or (Key = VK_OEM_PLUS) then
      ZoomStep(1)
    else if (Key = VK_SUBTRACT) or (Key = VK_OEM_MINUS) then
      ZoomStep(-1)
    else
      SetZoom(100);
    Key := 0;
  end
  else if (Key = VK_F8) and btnLog.Enabled then
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
  LoadDisplay;
  LoadControls;
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
  chkSound.Checked := FSettings.AlertSounds;
  chkMinMax.Checked := FSettings.ShowMinMax;
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
  FSettings.AlertSounds := chkSound.Checked;
  FSettings.LiveZoom := FZoom;
  FSettings.ShowMinMax := chkMinMax.Checked;
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
begin
  // The engine only uses the catalog while scanning or busy, which this button excludes.
  if not (FState in [esDisconnected, esConnected]) then
    Exit;
  if not TPidEditorForm.Execute(FCatalog, PidsFile) then
    Exit;
  ReloadCatalog;
  AddMessage(Format('PID definitions saved (%d PIDs) to %s', [FCatalog.Count, PidsFile]));
end;

procedure TMainForm.ReloadCatalog;
var
  I: Integer;
  P: TPidDef;
begin
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
  BuildDashboard;
end;

procedure TMainForm.btnDiscoverPidsClick(Sender: TObject);
var
  Added: TArray<Integer>;
begin
  if FState <> esConnected then
    Exit;
  Added := TPidDiscoveryForm.Execute(FEngine, FCatalog, PidsFile, FDiscovery);
  if Length(Added) = 0 then
    Exit;
  ReloadCatalog;
  AddMessage(Format('PID search: added %d PIDs to %s', [Length(Added), PidsFile]));
  if (FState in [esDisconnected, esConnected]) and
    (MessageDlg(Format('%d new PIDs were added as raw "PID $xxxx" entries (category Other).' + sLineBreak +
      'Open the PID editor to name and define them now?', [Length(Added)]), mtConfirmation, [mbYes, mbNo], 0) = mrYes) and
    TPidEditorForm.Execute(FCatalog, PidsFile, 'PID $') then
    ReloadCatalog;
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
  if FTestMode then
    StopTest;
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
  if FDiscovery <> nil then
    FDiscovery.HandleEngineEvent(Ev);
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
        if FState <> esScanning then
        begin
          grdLive.Invalidate;
          RefreshDashboard;
        end;
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
          FControlActive.Clear; // the engine released everything
          FillControls('');
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
        if FTestMode then
          StopTest;
        SetupLiveRows(Ev.PidIds);
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
        FLastLogFile := Ev.Text;
        FLogging := True;
        FLogPaused := False;
        SetStatus(PanelLog, 'Logging to ' + ExtractFileName(Ev.Text));
        UpdateControls;
      end;
    eeControl:
      begin
        FControlResult.AddOrSetValue(Ev.Text, FormatDateTime('hh:nn:ss  ', Now) + Ev.Raw);
        FControlActive.AddOrSetValue(Ev.Text, Ev.Flag);
        if not Ev.Supported then
          ShowNotice(Ev.Text + ': ' + Ev.Raw, True);
        FillControls('');
      end;
    eeLogStopped:
      begin
        if FLastLogFile <> '' then
          AddMessage('Log saved: ' + FLastLogFile + '  (F7 opens it in the log viewer)');
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
  btnWriteVin.Enabled := Idle;
  btnSendRaw.Enabled := Idle;
  btnDiscoverPids.Enabled := Idle;
  UpdateControlPanel;
  btnLiveTest.Enabled := FTestMode or not (FState in [esScanning, esBusy]);
  btnLiveTest.Caption := IfThen(FTestMode, 'Stop test', 'Test display');
  btnDashTest.Enabled := btnLiveTest.Enabled;
  btnDashTest.Caption := btnLiveTest.Caption;
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
  Phase: Boolean;
begin
  FlushMessages;
  if not LiveActive then
    Exit;
  Phase := FlashPhase;
  if Phase <> FFlashOn then
  begin
    FFlashOn := Phase;
    for I := 0 to High(FRowStyles) do
      if FRowStyles[I].Flash then
        InvalidateLiveRow(I);
  end;
  if FTestMode then
    FLive := TestSnapshot
  else
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
  if FTestMode then
    SetStatus(PanelRate, 'Test data')
  else
    SetStatus(PanelRate, Format('%.1f updates/s', [FLive.CyclesPerSecond]));
  if FLive.Logging then
    SetStatus(PanelLog, Format('Logging: %d rows%s', [FLive.LogRows, IfThen(FLive.LogPaused, ' (paused)', '')]));
  if FLive.Cycles <> FShownCycles then
  begin
    FShownCycles := FLive.Cycles;
    UpdateAlerts;
    RefreshLiveRows;
  end;
  RefreshDashboard;
end;

{ Live rows for a scan (or a display test): one row per PID, fresh min/max and alert state. }
procedure TMainForm.SetupLiveRows(const Ids: TArray<Integer>);
begin
  FLiveIds := Ids;
  FLive := Default(TLiveSnapshot);
  SetLength(FMin, Length(FLiveIds));
  SetLength(FMax, Length(FLiveIds));
  btnResetMinMax.Click;
  grdLive.RowCount := Max(2, Length(FLiveIds) + 1);
  FShownRows := nil;
  FShownCycles := -1;
  FRowStyles := nil;
  FAlerts.Reset;
  ApplyRowHeights;
  RefreshDashboard;
  lblLiveHint.Visible := False;
  if pcMain.ActivePage <> tsDashboard then
    pcMain.ActivePage := tsLive;
  grdLive.Invalidate;
end;

function TMainForm.LiveActive: Boolean;
begin
  Result := (FState = esScanning) or FTestMode;
end;

{ Test display }

procedure TMainForm.btnTestDisplayClick(Sender: TObject);
begin
  if FTestMode then
    StopTest
  else
    StartTest;
end;

{ Shows the ticked PIDs and the dashboard PIDs with made-up values that sweep
  slowly through each PID's range, so every alert level, colour, flash and
  sound can be tried without a car. Nothing is sent to the PCM or logged. }
procedure TMainForm.StartTest;
var
  Ids: TList<Integer>;
  I, J: Integer;
  P: TPidDef;
  G: TGauge;
  D: TPidDisplay;
  Lo, Hi, Margin: Double;
  Found: Boolean;
begin
  if FState in [esScanning, esBusy] then
    Exit;
  Ids := TList<Integer>.Create;
  try
    for I := 0 to FCatalog.Count - 1 do
    begin
      P := FCatalog[I];
      Found := FSelected.Contains(P.Id);
      for G in FDisplay.Gauges do
        Found := Found or (G.PidId = P.Id);
      if Found and P.Enabled then
        Ids.Add(P.Id);
    end;
    if Ids.Count = 0 then
    begin
      ShowNotice('Tick some PIDs or add gauges to the dashboard first', True);
      Exit;
    end;
    SetLength(FTestLo, Ids.Count);
    SetLength(FTestHi, Ids.Count);
    for I := 0 to Ids.Count - 1 do
    begin
      P := FCatalog.FindById(Ids[I]);
      Found := False;
      for G in FDisplay.Gauges do
        if not Found and (G.PidId = P.Id) then
        begin
          Lo := G.MinValue;
          Hi := G.MaxValue;
          Found := True;
        end;
      if not Found then
        SuggestScale(P, FDisplay, Lo, Hi);
      // Thresholds off the scale: reach a little past them so each level gets its turn.
      D := FDisplay.Find(P.Id);
      if D <> nil then
        for J := 0 to High(D.Levels) do
        begin
          Margin := 0.1 * (Hi - Lo);
          if D.Levels[J].Value <= Lo then
            Lo := D.Levels[J].Value - Margin;
          if D.Levels[J].Value >= Hi then
            Hi := D.Levels[J].Value + Margin;
        end;
      FTestLo[I] := Lo;
      FTestHi[I] := Hi;
    end;
    FTestMode := True;
    FTestStart := GetTickCount64;
    FRejected.Clear;
    SetupLiveRows(Ids.ToArray);
  finally
    Ids.Free;
  end;
  ShowNotice('Test display: made-up values, not from the vehicle. Nothing is sent to the PCM or logged.', False);
  AddMessage(Format('Test display started for %d PIDs', [Length(FLiveIds)]));
  UpdateControls;
end;

procedure TMainForm.StopTest;
begin
  if not FTestMode then
    Exit;
  FTestMode := False;
  StopAlertSound;
  pnlNotice.Visible := False;
  SetStatus(PanelRate, '');
  AddMessage('Test display stopped');
  grdLive.Invalidate;
  RefreshDashboard;
  UpdateControls;
end;

function TMainForm.TestSnapshot: TLiveSnapshot;
var
  I: Integer;
  T, F, Step: Double;
  P: TPidDef;
begin
  Result := Default(TLiveSnapshot);
  Result.PidIds := FLiveIds;
  SetLength(Result.Values, Length(FLiveIds));
  SetLength(Result.Text, Length(FLiveIds));
  T := (GetTickCount64 - FTestStart) / 1000;
  for I := 0 to High(FLiveIds) do
  begin
    P := FCatalog.FindById(FLiveIds[I]);
    if (P = nil) or (I > High(FTestLo)) then
    begin
      Result.Values[I] := NaN;
      Continue;
    end;
    // Each PID rises and falls over 16-28 s, starting low, out of step with the others.
    F := 0.5 - 0.5 * Cos(2 * Pi * T / (16 + 3 * (I mod 5)) + 0.7 * I);
    Step := NiceStep(FTestHi[I] - FTestLo[I], 200); // tidy values, like real sensor steps
    Result.Values[I] := Round((FTestLo[I] + (FTestHi[I] - FTestLo[I]) * F) / Step) * Step;
    Result.Text[I] := P.FormatValue(Result.Values[I]);
  end;
  Result.Cycles := FLive.Cycles + 1;
  Result.CyclesPerSecond := 10;
end;

function TMainForm.FlashPhase: Boolean;
begin
  Result := (GetTickCount64 div 400) mod 2 = 0;
end;

procedure TMainForm.InvalidateLiveRow(Idx: Integer);
var
  R, R2: TRect;
begin
  R := grdLive.CellRect(ColName, Idx + 1);
  R2 := grdLive.CellRect(LastLiveCol, Idx + 1);
  if IsRectEmpty(R) and IsRectEmpty(R2) then
    Exit; // scrolled out of view
  UnionRect(R, R, R2);
  InvalidateRect(grdLive.Handle, @R, False);
end;

{ Works out each live row's display level, repaints rows whose look changed,
  and plays / announces alerts. }
procedure TMainForm.UpdateAlerts;
var
  I, Id: Integer;
  V: Double;
  S, Old: TResolvedStyle;
  D: TPidDisplay;
  L: TDisplayLevel;
  Change: TAlertChange;
  Sounded: Boolean;
begin
  if Length(FRowStyles) <> Length(FLiveIds) then
  begin
    SetLength(FRowStyles, Length(FLiveIds));
    for I := 0 to High(FRowStyles) do
      FRowStyles[I].Level := -2; // forces the first comparison to differ
  end;
  Sounded := False;
  for I := 0 to High(FLiveIds) do
  begin
    Id := FLiveIds[I];
    V := NaN;
    if (I <= High(FLive.Values)) and not FRejected.Contains(Id) then
      V := FLive.Values[I];
    S := FDisplay.Resolve(Id, V);
    Old := FRowStyles[I];
    FRowStyles[I] := S;
    if (S.Level <> Old.Level) or (S.RowColor <> Old.RowColor) or (S.TextColor <> Old.TextColor) then
      InvalidateLiveRow(I);
    D := FDisplay.Find(Id);
    if (D = nil) or (S.Level < 0) then
    begin
      FAlerts.Update(Id, -1, False, False, GetTickCount64);
      Continue;
    end;
    L := D.Levels[S.Level];
    Change := FAlerts.Update(Id, S.Level, chkSound.Checked and (L.Sound <> asNone), L.RepeatSound, GetTickCount64);
    if Change.PlaySound and not Sounded then
    begin
      Sounded := True; // one sound at a time; the first (top) row wins this tick
      if not PlayAlertSound(L.Sound, L.SoundFile) then
        AddMessage('Alert sound could not be played: ' + L.SoundFile);
    end;
    if Change.Announce and L.IsAttentionGrabbing then
      AddMessage(Format('Alert: %s %s %s (%s)', [PidName(Id), IfThen(L.Name <> '', L.Name, 'level'),
        FCatalog.FindById(Id).FormatValue(V), L.Describe]));
  end;
end;

procedure TMainForm.ApplyRowHeights;
var
  I, H: Integer;
  D: TPidDisplay;
begin
  for I := 0 to High(FLiveIds) do
  begin
    H := grdLive.DefaultRowHeight;
    D := FDisplay.Find(FLiveIds[I]);
    if (D <> nil) and (D.FontSize > 0) then
      H := Max(H, MulDiv(ZoomPt(D.FontSize), CurrentPPI, 72) + ZoomPx(12));
    if I + 1 < grdLive.RowCount then
      grdLive.RowHeights[I + 1] := H;
  end;
end;

function TMainForm.LiveIndexOf(PidId: Integer): Integer;
begin
  for Result := 0 to High(FLiveIds) do
    if FLiveIds[Result] = PidId then
      Exit;
  Result := -1;
end;

{ Live grid zoom and columns }

const
  ZoomSteps: array[0..8] of Integer = (75, 90, 100, 110, 125, 150, 175, 200, 250);

function TMainForm.ZoomPx(N: Integer): Integer;
begin
  Result := MulDiv(N, CurrentPPI * FZoom, 96 * 100);
end;

function TMainForm.ZoomPt(Points: Integer): Integer;
begin
  Result := Max(6, Round(Points * FZoom / 100));
end;

function TMainForm.LastLiveCol: Integer;
begin
  Result := grdLive.ColCount - 1;
end;

procedure TMainForm.SetZoom(Percent: Integer);
begin
  FZoom := EnsureRange(Percent, ZoomSteps[0], ZoomSteps[High(ZoomSteps)]);
  lblZoom.Caption := IntToStr(FZoom) + '%';
  btnZoomOut.Enabled := FZoom > ZoomSteps[0];
  btnZoomIn.Enabled := FZoom < ZoomSteps[High(ZoomSteps)];
  ApplyGridLayout;
end;

procedure TMainForm.ZoomStep(Direction: Integer);
var
  I: Integer;
begin
  if Direction > 0 then
  begin
    for I := 0 to High(ZoomSteps) do
      if ZoomSteps[I] > FZoom then
      begin
        SetZoom(ZoomSteps[I]);
        Exit;
      end;
  end
  else
    for I := High(ZoomSteps) downto 0 do
      if ZoomSteps[I] < FZoom then
      begin
        SetZoom(ZoomSteps[I]);
        Exit;
      end;
end;

{ Column widths, row heights and fonts follow the zoom; min / max are the
  last two columns, so hiding them is just two columns fewer. }
procedure TMainForm.ApplyGridLayout;
begin
  if FBaseRowHeight = 0 then
    Exit; // called while the form is still loading
  if chkMinMax.Checked then
    grdLive.ColCount := ColMax + 1
  else
    grdLive.ColCount := ColUnits + 1;
  grdLive.DefaultRowHeight := MulDiv(FBaseRowHeight, FZoom, 100); // resets every row height
  grdLive.ColWidths[ColValue] := ZoomPx(140);
  grdLive.ColWidths[ColUnits] := ZoomPx(80);
  if chkMinMax.Checked then
  begin
    grdLive.ColWidths[ColMin] := ZoomPx(100);
    grdLive.ColWidths[ColMax] := ZoomPx(100);
  end;
  ApplyRowHeights;
  FShownRows := nil;
  FormResize(nil);
  grdLive.Invalidate;
end;

procedure TMainForm.chkMinMaxClick(Sender: TObject);
begin
  ApplyGridLayout;
end;

procedure TMainForm.btnZoomOutClick(Sender: TObject);
begin
  ZoomStep(-1);
end;

procedure TMainForm.btnZoomInClick(Sender: TObject);
begin
  ZoomStep(1);
end;

procedure TMainForm.lblZoomClick(Sender: TObject);
begin
  SetZoom(100);
end;

{ Ctrl + mouse wheel over the live grid zooms it. }
procedure TMainForm.FormMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint; var Handled: Boolean);
begin
  if (ssCtrl in Shift) and (FindVCLWindow(Mouse.CursorPos) = grdLive) then
  begin
    ZoomStep(Sign(WheelDelta));
    Handled := True;
  end;
end;

{ Repaints only the value/min/max cells whose text changed, without erasing
  the background first (DrawCell paints every pixel of the cell itself).
  Invalidating the whole grid ten times a second is what made it flicker. }
procedure TMainForm.RefreshLiveRows;
var
  I: Integer;
  P: TPidDef;
  Shown: string;
  R, R2: TRect;
begin
  if Length(FShownRows) <> Length(FLiveIds) then
    SetLength(FShownRows, Length(FLiveIds));
  for I := 0 to High(FLiveIds) do
  begin
    P := FCatalog.FindById(FLiveIds[I]);
    if (P = nil) or (I > High(FLive.Text)) then
      Continue;
    Shown := FLive.Text[I] + #1 + P.FormatValue(FMin[I]) + #1 + P.FormatValue(FMax[I]);
    if Shown = FShownRows[I] then
      Continue;
    FShownRows[I] := Shown;
    R := grdLive.CellRect(ColValue, I + 1);
    R2 := grdLive.CellRect(LastLiveCol, I + 1);
    if IsRectEmpty(R) then
      Continue; // row scrolled out of view
    UnionRect(R, R, R2);
    InvalidateRect(grdLive.Handle, @R, False);
  end;
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
  V: Double;
  Style: TResolvedStyle;
  RowColor, TextColor: TColor;
begin
  C := grdLive.Canvas;
  R := Rect;
  if ARow = 0 then
  begin
    C.Brush.Color := clBtnFace;
    C.FillRect(R);
    C.Font.Style := [fsBold];
    C.Font.Size := ZoomPt(9);
    C.Font.Color := clWindowText;
    InflateRect(R, -6, 0);
    Flags := DT_SINGLELINE or DT_VCENTER;
    if ACol in [ColValue, ColMin, ColMax] then
      Flags := Flags or DT_RIGHT;
    DrawText(C.Handle, PChar(Headers[ACol]), -1, R, Flags);
    Exit;
  end;

  Idx := ARow - 1;
  RowColor := clNone;
  TextColor := clNone;
  Style := Default(TResolvedStyle);
  P := nil;
  if Idx <= High(FLiveIds) then
    P := FCatalog.FindById(FLiveIds[Idx]);
  if P <> nil then
  begin
    V := NaN;
    if (Idx <= High(FLive.Values)) and not FRejected.Contains(P.Id) then
      V := FLive.Values[Idx];
    Style := FDisplay.Resolve(P.Id, V);
    // Rows only flash while scanning; otherwise they keep the level's colours.
    Style.Colors(FFlashOn or not LiveActive, RowColor, TextColor);
  end;
  if RowColor <> clNone then
    C.Brush.Color := RowColor
  else if Odd(ARow) then
    C.Brush.Color := clWindow
  else
    C.Brush.Color := $00F7F3F0;
  C.FillRect(R);
  if P = nil then
    Exit;

  C.Font.Style := [];
  C.Font.Size := ZoomPt(10);
  if TextColor <> clNone then
    C.Font.Color := TextColor
  else
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
          C.Font.Size := ZoomPt(IfThen(Style.FontSize > 0, Style.FontSize, 14));
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
        if TextColor = clNone then
          C.Font.Color := clGrayText;
        Flags := Flags or DT_RIGHT;
      end;
  end;
  InflateRect(R, -ZoomPx(6), 0);
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
  FShownRows := nil;
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

{ Real-time controls }

procedure TMainForm.LoadControls;
var
  W: string;
  Defaults: TControlList;
  N: Integer;
begin
  if not FileExists(ControlsFile) then
    Exit;
  try
    FControls.LoadFromFile(ControlsFile);
    for W in FControls.Warnings do
      AddMessage('Real-time controls: ' + W);
    // A newer UVScan ships more built-in controls: add the new ones once.
    Defaults := TControlList.Create;
    try
      Defaults.LoadFromJsonText(DefaultControlsJson);
      if FControls.DefaultsVersion < Defaults.DefaultsVersion then
      begin
        N := FControls.RestoreBuiltIns(Defaults);
        FControls.DefaultsVersion := Defaults.DefaultsVersion;
        SaveControls;
        if N > 0 then
          AddMessage(Format('Added %d new built-in real-time control(s)', [N]));
      end;
    finally
      Defaults.Free;
    end;
  except
    on E: Exception do
      AddMessage('Could not load real-time controls: ' + E.Message);
  end;
  FillControls('');
end;

procedure TMainForm.SaveControls;
begin
  try
    FControls.SaveToFile(ControlsFile);
  except
    on E: Exception do
      MessageDlg('Could not save the real-time controls: ' + E.Message, mtWarning, [mbOK], 0);
  end;
end;

procedure TMainForm.FillControls(const Select: string);
var
  I: Integer;
  C: TControlDef;
  Item: TListItem;
  Groups: TStringList;
  G, Keep, Res: string;
begin
  Keep := Select;
  if (Keep = '') and (SelectedControl <> nil) then
    Keep := SelectedControl.Name;
  Groups := TStringList.Create;
  lvControls.Items.BeginUpdate;
  try
    lvControls.Items.Clear;
    lvControls.Groups.Clear;
    for I := 0 to FControls.Count - 1 do
    begin
      G := IfThen(FControls[I].Group = '', 'Other', FControls[I].Group);
      if Groups.IndexOf(G) < 0 then
        Groups.AddObject(G, TObject(lvControls.Groups.Add.GroupID));
      lvControls.Groups[Groups.IndexOf(G)].Header := G;
    end;
    for I := 0 to FControls.Count - 1 do
    begin
      C := FControls[I];
      Item := lvControls.Items.Add;
      Item.Caption := C.Name;
      Item.SubItems.Add(ControlKindCaptions[C.Kind]);
      Item.SubItems.Add(ModuleName(C.Module) + ': ' + C.OnText);
      if C.Problem <> '' then
        Res := 'Needs fixing: ' + C.Problem
      else if not FControlResult.TryGetValue(C.Name, Res) then
        Res := '';
      if FControlActive.ContainsKey(C.Name) and FControlActive[C.Name] then
        Res := 'ACTIVE  ' + Res;
      Item.SubItems.Add(Res);
      Item.Data := C;
      Item.GroupID := Integer(Groups.Objects[Groups.IndexOf(IfThen(C.Group = '', 'Other', C.Group))]);
      if SameText(C.Name, Keep) then
        Item.Selected := True;
    end;
  finally
    lvControls.Items.EndUpdate;
    Groups.Free;
  end;
  UpdateControlPanel;
end;

function TMainForm.SelectedControl: TControlDef;
begin
  if (lvControls.Selected <> nil) and (FControls <> nil) and
    (FControls.IndexOfName(TControlDef(lvControls.Selected.Data).Name) >= 0) then
    Result := TControlDef(lvControls.Selected.Data)
  else
    Result := nil;
end;

function TMainForm.ControlsUsable: Boolean;
begin
  Result := FState in [esConnected, esScanning];
end;

{ Shows the buttons that fit the selected control's kind. }
procedure TMainForm.UpdateControlPanel;
var
  C: TControlDef;
  Ok, Active: Boolean;
begin
  if FControls = nil then
    Exit;
  C := SelectedControl;
  Ok := (C <> nil) and (C.Problem = '') and ControlsUsable;
  Active := (C <> nil) and FControlActive.ContainsKey(C.Name) and FControlActive[C.Name];
  btnCtlSend.Visible := (C <> nil) and (C.Kind = ckAction);
  btnCtlOn.Visible := (C <> nil) and (C.Kind = ckToggle);
  btnCtlHold.Visible := (C <> nil) and (C.Kind = ckHold);
  tbCtlValue.Visible := (C <> nil) and (C.Kind = ckValue);
  edtCtlValue.Visible := tbCtlValue.Visible;
  lblCtlUnits.Visible := tbCtlValue.Visible;
  btnCtlApply.Visible := tbCtlValue.Visible;
  btnCtlOff.Visible := (C <> nil) and (C.Kind in [ckToggle, ckValue]);
  if (C <> nil) and (C.Kind = ckValue) then
  begin
    btnCtlOff.Left := btnCtlApply.Left + btnCtlApply.Width + 6;
    btnCtlOff.Caption := 'Release';
  end
  else
  begin
    btnCtlOff.Left := btnCtlOn.Left + btnCtlOn.Width + 6;
    btnCtlOff.Caption := 'Off';
  end;
  for var B in TArray<TButton>.Create(btnCtlSend, btnCtlOn, btnCtlHold, btnCtlApply, btnCtlOff) do
    B.Enabled := Ok;
  tbCtlValue.Enabled := Ok;
  btnCtlEdit.Enabled := C <> nil;
  btnCtlDup.Enabled := C <> nil;
  btnCtlDelete.Enabled := C <> nil;
  btnReleaseAll.Enabled := ControlsUsable;
  if C = nil then
  begin
    lblCtlName.Caption := IfThen(FControls.Count = 0, 'No controls yet - press Add', 'Select a control');
    lblCtlNotes.Caption := '';
    Exit;
  end;
  lblCtlName.Caption := C.Name + IfThen(Active, '   (active)', '');
  if C.Problem <> '' then
    lblCtlNotes.Caption := 'Needs fixing: ' + C.Problem
  else if not ControlsUsable then
    lblCtlNotes.Caption := 'Connect first. ' + C.Notes
  else
    lblCtlNotes.Caption := C.Notes;
  if C.Kind = ckValue then
  begin
    tbCtlValue.OnChange := nil;
    tbCtlValue.Max := Max(1, Round((C.MaxValue - C.MinValue) / C.Step));
    tbCtlValue.OnChange := tbCtlValueChange;
    lblCtlUnits.Caption := C.Units;
    if edtCtlValue.Tag <> NativeInt(C) then
    begin
      edtCtlValue.Tag := NativeInt(C);
      tbCtlValue.Position := 0;
      tbCtlValueChange(nil);
    end;
  end;
end;

procedure TMainForm.lvControlsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  UpdateControlPanel;
end;

procedure TMainForm.lvControlsCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
  var DefaultDraw: Boolean);
var
  C: TControlDef;
begin
  C := TControlDef(Item.Data);
  if (C <> nil) and FControlActive.ContainsKey(C.Name) and FControlActive[C.Name] then
  begin
    Sender.Canvas.Brush.Color := $0080E6FF; // amber: something is being controlled
    Sender.Canvas.Font.Style := [fsBold];
  end
  else if (C <> nil) and (C.Problem <> '') then
    Sender.Canvas.Font.Color := clGrayText;
end;

procedure TMainForm.SendControl(C: TControlDef; TurnOn: Boolean; const Value: Double);
var
  Cmd: TEngineCommand;
begin
  if (C = nil) or (C.Problem <> '') or not ControlsUsable then
    Exit;
  Cmd := Command(ecControl);
  Cmd.Text := C.Name;
  try
    if TurnOn then
    begin
      Cmd.Data := C.OnMessage(Value);
      Cmd.Release := C.OffMessage;
      Cmd.Flag := C.HoldsControl;
    end
    else
    begin
      Cmd.Data := C.OffMessage;
      Cmd.Flag := False;
      if Length(Cmd.Data) = 0 then
        Exit;
    end;
  except
    on E: EControlError do
    begin
      ShowNotice(C.Name + ': ' + E.Message, True);
      Exit;
    end;
  end;
  Post(Cmd);
end;

procedure TMainForm.btnCtlSendClick(Sender: TObject);
var
  C: TControlDef;
begin
  C := SelectedControl;
  if (C <> nil) and (C.Confirm <> '') and
    (MessageDlg(C.Confirm, mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;
  SendControl(C, True);
end;

procedure TMainForm.btnCtlOnClick(Sender: TObject);
begin
  btnCtlSendClick(Sender);
end;

procedure TMainForm.btnCtlOffClick(Sender: TObject);
begin
  SendControl(SelectedControl, False);
end;

procedure TMainForm.btnCtlHoldMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  C: TControlDef;
begin
  C := SelectedControl;
  if (Button <> mbLeft) or (C = nil) or not btnCtlHold.Enabled then
    Exit;
  if (C.Confirm <> '') and (MessageDlg(C.Confirm, mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;
  FHolding := True;
  btnCtlHold.Caption := 'Running - let go to stop';
  SendControl(C, True);
end;

procedure TMainForm.btnCtlHoldMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if not FHolding then
    Exit;
  FHolding := False;
  btnCtlHold.Caption := 'Hold to run';
  SendControl(SelectedControl, False);
end;

procedure TMainForm.tbCtlValueChange(Sender: TObject);
var
  C: TControlDef;
begin
  C := SelectedControl;
  if (C = nil) or (C.Kind <> ckValue) then
    Exit;
  edtCtlValue.Text := FormatFloat('0.###', C.MinValue + tbCtlValue.Position * C.Step);
end;

procedure TMainForm.btnCtlApplyClick(Sender: TObject);
var
  C: TControlDef;
  V: Double;
begin
  C := SelectedControl;
  if C = nil then
    Exit;
  if not TryParseNumber(edtCtlValue.Text, V) or (V < C.MinValue) or (V > C.MaxValue) then
  begin
    ShowNotice(Format('Enter a value from %s to %s', [FormatFloat('0.###', C.MinValue),
      FormatFloat('0.###', C.MaxValue)]), True);
    Exit;
  end;
  if (C.Confirm <> '') and not (FControlActive.ContainsKey(C.Name) and FControlActive[C.Name]) and
    (MessageDlg(C.Confirm, mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;
  SendControl(C, True, V);
end;

procedure TMainForm.btnReleaseAllClick(Sender: TObject);
begin
  Post(ecReleaseControls);
end;

procedure TMainForm.EditControl(C: TControlDef; IsNew: Boolean);
var
  Work, Original: TControlDef;
  Groups: TStringList;
  I: Integer;
begin
  if (C <> nil) and FControlActive.ContainsKey(C.Name) and FControlActive[C.Name] then
  begin
    ShowNotice('Release "' + C.Name + '" before changing it', True);
    Exit;
  end;
  Work := TControlDef.Create;
  Groups := TStringList.Create;
  try
    Groups.Sorted := True;
    Groups.Duplicates := dupIgnore;
    for I := 0 to FControls.Count - 1 do
      if FControls[I].Group <> '' then
        Groups.Add(FControls[I].Group);
    if C <> nil then
      Work.Assign(C);
    if IsNew and (C <> nil) then
    begin
      Work.Name := C.Name + ' (copy)';
      Work.BuiltIn := False;
    end;
    if IsNew then
      Original := nil
    else
      Original := C;
    if not TControlEditorForm.Execute(Work, Groups, FControls, Original) then
      Exit;
    if IsNew then
    begin
      FControls.Add(Work);
      Work := nil;
      FillControls(FControls[FControls.Count - 1].Name);
    end
    else
    begin
      C.Assign(Work);
      FillControls(C.Name);
    end;
    SaveControls;
  finally
    Work.Free;
    Groups.Free;
  end;
end;

procedure TMainForm.btnCtlAddClick(Sender: TObject);
begin
  EditControl(nil, True);
end;

procedure TMainForm.btnCtlEditClick(Sender: TObject);
begin
  if SelectedControl <> nil then
    EditControl(SelectedControl, False);
end;

procedure TMainForm.btnCtlDupClick(Sender: TObject);
begin
  if SelectedControl <> nil then
    EditControl(SelectedControl, True);
end;

procedure TMainForm.btnCtlDeleteClick(Sender: TObject);
var
  C: TControlDef;
begin
  C := SelectedControl;
  if C = nil then
    Exit;
  if FControlActive.ContainsKey(C.Name) and FControlActive[C.Name] then
  begin
    ShowNotice('Release "' + C.Name + '" before deleting it', True);
    Exit;
  end;
  if MessageDlg(Format('Delete the control "%s"?', [C.Name]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FControls.Delete(FControls.IndexOfName(C.Name));
  SaveControls;
  FillControls('');
end;

procedure TMainForm.btnCtlRestoreClick(Sender: TObject);
var
  Defaults: TControlList;
  N: Integer;
begin
  Defaults := TControlList.Create;
  try
    Defaults.LoadFromJsonText(DefaultControlsJson);
    N := FControls.RestoreBuiltIns(Defaults);
  finally
    Defaults.Free;
  end;
  if N = 0 then
    ShowNotice('All built-in controls are already in the list', False)
  else
  begin
    SaveControls;
    FillControls('');
    AddMessage(Format('Restored %d built-in control(s)', [N]));
  end;
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

const
  MaxMessageLines = 5000;

{ Messages are queued and written to the memo in one go by the refresh timer.
  Adding them one by one (thousands per minute with traffic tracing on) kept
  the UI thread so busy that windows stopped repainting. }
procedure TMainForm.AddMessage(const Text: string);
begin
  FPendingLog.Add(FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + Text);
  if FPendingLog.Count > MaxMessageLines then
    FPendingLog.Delete(0);
end;

procedure TMainForm.FlushMessages;
var
  Cut: Integer;
begin
  if FPendingLog.Count = 0 then
    Exit;
  // Append the batch at the end (one EM_REPLACESEL) ...
  memLog.SelStart := memLog.GetTextLen;
  memLog.SelLength := 0;
  memLog.SelText := string.Join(sLineBreak, FPendingLog.ToStringArray) + sLineBreak;
  FPendingLog.Clear;
  // ... and drop old lines in one cut once there are clearly too many.
  if memLog.Lines.Count > MaxMessageLines + 500 then
  begin
    Cut := memLog.Perform(EM_LINEINDEX, memLog.Lines.Count - MaxMessageLines, 0);
    memLog.SelStart := 0;
    memLog.SelLength := Cut;
    memLog.SelText := '';
  end;
  memLog.SelStart := memLog.GetTextLen;
  memLog.Perform(EM_SCROLLCARET, 0, 0);
end;

procedure TMainForm.btnClearMessagesClick(Sender: TObject);
begin
  FPendingLog.Clear;
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
  Others, I: Integer;
begin
  if grdLive = nil then
    Exit;
  Others := 5;
  for I := ColValue to grdLive.ColCount - 1 do
    Inc(Others, grdLive.ColWidths[I]);
  grdLive.ColWidths[ColName] := Max(ZoomPx(160), grdLive.ClientWidth - Others);
end;

procedure TMainForm.lblNoticeClick(Sender: TObject);
begin
  pnlNotice.Visible := False;
end;

{ Display settings and alerts }

procedure TMainForm.LoadDisplay;
var
  W: string;
  Root: TJSONObject;
  Count: Integer;
begin
  if not FileExists(DisplayFile) then
  begin
    // First run: start from the built-in examples, matched to this catalog's PIDs.
    try
      Root := ParseJsonObject(DefaultDisplayJson, 'default display.json');
      try
        Count := ResolveSeedJson(Root,
          function(const PidCode, Units: string): Integer
          var
            I: Integer;
            P: TPidDef;
          begin
            Result := -1;
            for I := 0 to FCatalog.Count - 1 do
            begin
              P := FCatalog[I];
              if not P.Enabled or (P.Kind <> pkVehicle) or not SameText(P.PidCode, PidCode) then
                Continue;
              if (Units = '') or SameText(P.Units, Units) then
                Exit(P.Id);
              if Result < 0 then
                Result := P.Id;
            end;
          end);
        WriteJsonFile(DisplayFile, Root);
        FDisplay.LoadFromJson(Root);
      finally
        Root.Free;
      end;
      AddMessage(Format('Created %s with alert examples for %d PIDs', [DisplayFile, Count]));
    except
      on E: Exception do
        AddMessage('Could not create display settings: ' + E.Message);
    end;
    Exit;
  end;
  try
    FDisplay.LoadFromFile(DisplayFile);
    for W in FDisplay.Warnings do
      AddMessage('Display settings: ' + W);
  except
    on E: Exception do
    begin
      AddMessage('Could not load display settings: ' + E.Message);
      ShowNotice('Display settings could not be read - see Messages', False);
    end;
  end;
end;

procedure TMainForm.SaveDisplay;
begin
  try
    FDisplay.SaveToFile(DisplayFile);
  except
    on E: Exception do
      MessageDlg('Could not save the display settings: ' + E.Message, mtWarning, [mbOK], 0);
  end;
end;

{ After display.json changed: save, repaint the grid, rebuild the gauges. }
procedure TMainForm.DisplayChanged;
begin
  SaveDisplay;
  FShownRows := nil;
  FRowStyles := nil;
  ApplyRowHeights;
  grdLive.Invalidate;
  BuildDashboard;
end;

procedure TMainForm.EditDisplay(PidId: Integer);
var
  P: TPidDef;
begin
  P := FCatalog.FindById(PidId);
  if P = nil then
    Exit;
  if TDisplayEditorForm.Execute(P, FDisplay) then
    DisplayChanged;
end;

{ Opens the log viewer with the log just recorded, or the newest log in the
  folder; if that is already what the viewer shows, just brings it up. }
procedure TMainForm.btnLogViewerClick(Sender: TObject);
var
  Last: string;
  Files: TArray<string>;
  F: string;
begin
  Last := FLastLogFile;
  if (Last = '') and TDirectory.Exists(LogFolder) then
  begin
    Files := TDirectory.GetFiles(LogFolder, '*.csv');
    for F in Files do
      if (Last = '') or (TFile.GetLastWriteTime(F) > TFile.GetLastWriteTime(Last)) then
        Last := F;
  end;
  if SameText(Last, FViewerLog) or FLogging then
    Last := '' // keep what the viewer shows (a log still being written is incomplete)
  else
    FViewerLog := Last;
  TLogViewerForm.ShowViewer(FCatalog, FDisplay, LogFolder, LogViewsFile, Last);
end;

procedure TMainForm.chkSoundClick(Sender: TObject);
begin
  if not chkSound.Checked then
    StopAlertSound;
end;

procedure TMainForm.pmPidPopup(Sender: TObject);
var
  Pt: TPoint;
  Col, Row: Integer;
  Item: TListItem;
  Name: string;
begin
  FMenuPidId := -1;
  if pmPid.PopupComponent = grdLive then
  begin
    Pt := grdLive.ScreenToClient(pmPid.PopupPoint);
    grdLive.MouseToCell(Pt.X, Pt.Y, Col, Row);
    if (Row >= 1) and (Row - 1 <= High(FLiveIds)) then
      FMenuPidId := FLiveIds[Row - 1];
  end
  else if pmPid.PopupComponent = lvPids then
  begin
    Pt := lvPids.ScreenToClient(pmPid.PopupPoint);
    Item := lvPids.GetItemAt(Pt.X, Pt.Y);
    if Item = nil then
      Item := lvPids.Selected;
    if Item <> nil then
    begin
      Item.Selected := True;
      FMenuPidId := Integer(Item.Data);
    end;
  end;
  miPidDisplay.Enabled := FMenuPidId >= 0;
  miPidGauge.Enabled := FMenuPidId >= 0;
  if FMenuPidId >= 0 then
    Name := ' for ' + StringReplace(PidName(FMenuPidId), '&', '&&', [rfReplaceAll])
  else
    Name := '';
  miPidDisplay.Caption := 'Display && alerts' + Name + '...';
end;

procedure TMainForm.miPidDisplayClick(Sender: TObject);
begin
  EditDisplay(FMenuPidId);
end;

procedure TMainForm.miPidGaugeClick(Sender: TObject);
begin
  AddGauge(FMenuPidId);
end;

{ Dashboard }

procedure TMainForm.BuildDashboard;
var
  I: Integer;
  G: TGauge;
  P: TPidDef;
  View: TGaugeView;
  Title, Units: string;
begin
  sbDash.DisableAlign;
  try
    for View in FGaugeViews do
      View.Free;
    FGaugeViews.Clear;
    for I := 0 to FDisplay.Gauges.Count - 1 do
    begin
      G := FDisplay.Gauges[I];
      P := FCatalog.FindById(G.PidId);
      if P <> nil then
      begin
        Title := P.LongName;
        Units := P.Units;
      end
      else
      begin
        Title := Format('PID #%d (missing)', [G.PidId]);
        Units := '';
      end;
      View := TGaugeView.Create(Self);
      View.Parent := sbDash;
      View.Tag := I;
      View.PopupMenu := pmGauge;
      View.OnDblClick := GaugeDblClick;
      View.Setup(G.Style, G.Size, Title, Units, G.MinValue, G.MaxValue,
        FDisplay.Zones(G.PidId, G.MinValue, G.MaxValue));
      FGaugeViews.Add(View);
    end;
  finally
    sbDash.EnableAlign;
  end;
  if FGaugeViews.Count = 0 then
    lblDashHint.Caption := 'No gauges yet: press Add gauge, or right-click a PID and choose Add to dashboard.'
  else
    lblDashHint.Caption := 'Right-click a gauge to change, move or remove it. Double-click to edit.';
  LayoutDashboard;
  RefreshDashboard;
end;

{ Left to right, wrapping to the width of the dashboard. }
procedure TMainForm.LayoutDashboard;
var
  View: TGaugeView;
  I, X, Y, RowH, Gap, Avail: Integer;
  Sz: TSize;
begin
  if FGaugeViews.Count = 0 then
    Exit;
  Gap := MulDiv(12, CurrentPPI, 96);
  Avail := sbDash.ClientWidth;
  X := Gap;
  Y := Gap;
  RowH := 0;
  sbDash.DisableAlign;
  try
    for I := 0 to FGaugeViews.Count - 1 do
    begin
      View := FGaugeViews[I];
      Sz := TGaugeView.PreferredSize(FDisplay.Gauges[I].Style, FDisplay.Gauges[I].Size, CurrentPPI);
      if (X > Gap) and (X + Sz.cx + Gap > Avail) then
      begin
        X := Gap;
        Inc(Y, RowH + Gap);
        RowH := 0;
      end;
      View.SetBounds(X - sbDash.HorzScrollBar.Position, Y - sbDash.VertScrollBar.Position, Sz.cx, Sz.cy);
      Inc(X, Sz.cx + Gap);
      RowH := Max(RowH, Sz.cy);
    end;
  finally
    sbDash.EnableAlign;
  end;
end;

procedure TMainForm.sbDashResize(Sender: TObject);
begin
  LayoutDashboard;
end;

procedure TMainForm.RefreshDashboard;
var
  I, Idx: Integer;
  G: TGauge;
  P: TPidDef;
  V: Double;
  Text, Note: string;
  Scanning: Boolean;
begin
  Scanning := LiveActive;
  for I := 0 to FGaugeViews.Count - 1 do
  begin
    if I >= FDisplay.Gauges.Count then
      Break;
    G := FDisplay.Gauges[I];
    P := FCatalog.FindById(G.PidId);
    V := NaN;
    Text := '-';
    Note := '';
    Idx := LiveIndexOf(G.PidId);
    if P = nil then
      Note := ''
    else if Idx < 0 then
    begin
      if Scanning then
        Note := 'not in this scan';
    end
    else if FRejected.Contains(G.PidId) then
      Note := 'rejected'
    else if Idx <= High(FLive.Values) then
    begin
      V := FLive.Values[Idx];
      Text := FLive.Text[Idx];
      if Text = '' then
        Text := '-';
    end;
    ShowGaugeReading(FGaugeViews[I], FDisplay.Resolve(G.PidId, V), FFlashOn or not Scanning, V, Text, Note);
  end;
end;

procedure TMainForm.AddGauge(PidId: Integer);
var
  G: TGauge;
  I: Integer;
begin
  if (PidId < 0) and (FSelected.Count > 0) then
    PidId := FSelected[0];
  if PidId < 0 then
    for I := 0 to FCatalog.Count - 1 do
      if FCatalog[I].Enabled then
      begin
        PidId := FCatalog[I].Id;
        Break;
      end;
  G := Default(TGauge);
  G.PidId := PidId;
  G.Style := gsDial;
  G.Size := gzMedium;
  SuggestScale(FCatalog.FindById(PidId), FDisplay, G.MinValue, G.MaxValue);
  if not TGaugeEditorForm.Execute(G, FCatalog, FDisplay, 'Add gauge') then
    Exit;
  FDisplay.Gauges.Add(G);
  SaveDisplay;
  BuildDashboard;
  pcMain.ActivePage := tsDashboard;
end;

procedure TMainForm.EditGauge(Index: Integer);
var
  G: TGauge;
begin
  if (Index < 0) or (Index >= FDisplay.Gauges.Count) then
    Exit;
  G := FDisplay.Gauges[Index];
  if not TGaugeEditorForm.Execute(G, FCatalog, FDisplay, 'Edit gauge') then
    Exit;
  FDisplay.Gauges[Index] := G;
  SaveDisplay;
  BuildDashboard;
end;

procedure TMainForm.MoveGauge(Delta: Integer);
begin
  if (FMenuGauge < 0) or (FMenuGauge + Delta < 0) or (FMenuGauge + Delta >= FDisplay.Gauges.Count) then
    Exit;
  FDisplay.Gauges.Exchange(FMenuGauge, FMenuGauge + Delta);
  SaveDisplay;
  BuildDashboard;
end;

procedure TMainForm.btnAddGaugeClick(Sender: TObject);
begin
  AddGauge(-1);
end;

procedure TMainForm.btnTickDashPidsClick(Sender: TObject);
var
  G: TGauge;
  P: TPidDef;
  Added: Integer;
begin
  Added := 0;
  for G in FDisplay.Gauges do
  begin
    P := FCatalog.FindById(G.PidId);
    if (P <> nil) and P.Enabled and not FSelected.Contains(G.PidId) then
    begin
      SetSelected(G.PidId, True);
      Inc(Added);
    end;
  end;
  FillPidList;
  if Added = 0 then
    ShowNotice('The dashboard PIDs are already ticked', False)
  else if FState = esScanning then
    ShowNotice(Format('%d PID(s) ticked - press Restart scan to include them', [Added]), False);
end;

procedure TMainForm.GaugeDblClick(Sender: TObject);
begin
  EditGauge(TGaugeView(Sender).Tag);
end;

procedure TMainForm.pmGaugePopup(Sender: TObject);
begin
  FMenuGauge := -1;
  if pmGauge.PopupComponent is TGaugeView then
    FMenuGauge := TGaugeView(pmGauge.PopupComponent).Tag;
  miGaugeEarlier.Enabled := FMenuGauge > 0;
  miGaugeLater.Enabled := (FMenuGauge >= 0) and (FMenuGauge < FDisplay.Gauges.Count - 1);
  miGaugeDisplay.Enabled := (FMenuGauge >= 0) and (FCatalog.FindById(FDisplay.Gauges[FMenuGauge].PidId) <> nil);
end;

procedure TMainForm.miGaugeEditClick(Sender: TObject);
begin
  EditGauge(FMenuGauge);
end;

procedure TMainForm.miGaugeDisplayClick(Sender: TObject);
begin
  if (FMenuGauge >= 0) and (FMenuGauge < FDisplay.Gauges.Count) then
    EditDisplay(FDisplay.Gauges[FMenuGauge].PidId);
end;

procedure TMainForm.miGaugeEarlierClick(Sender: TObject);
begin
  MoveGauge(-1);
end;

procedure TMainForm.miGaugeLaterClick(Sender: TObject);
begin
  MoveGauge(1);
end;

procedure TMainForm.miGaugeRemoveClick(Sender: TObject);
begin
  if (FMenuGauge < 0) or (FMenuGauge >= FDisplay.Gauges.Count) then
    Exit;
  FDisplay.Gauges.Delete(FMenuGauge);
  SaveDisplay;
  // Rebuilding frees the gauge whose menu is running; let the menu finish first.
  TThread.ForceQueue(nil, BuildDashboard);
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
  if sbMain.Panels[Panel].Text <> Text then // avoid repainting the status bar for nothing
    sbMain.Panels[Panel].Text := Text;
end;

end.
