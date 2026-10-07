unit UVScan.MainForm;

{ The main window: connection bar, PID list, and the tabs (live data,
  dashboard, real-time controls, vehicle & codes, tools, messages).

  FireMonkey, so the same window runs on Windows and Android. On a phone the
  PID list becomes the first tab and every dialog opens full screen; nothing
  waits on a modal dialog (questions answer through callbacks). }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, System.Math,
  System.StrUtils, System.IOUtils, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Edit,
  FMX.ListBox, FMX.Layouts, FMX.Objects, FMX.TabControl, FMX.Menus, FMX.Controls.Presentation,
  FMX.Platform, System.Messaging,
  UVScan.Serial, UVScan.Simulator, UVScan.Pids, UVScan.Dpid, UVScan.Dtc, UVScan.Engine,
  UVScan.Class2, UVScan.Paths, UVScan.Settings, UVScan.PidLists, UVScan.Defaults,
  UVScan.Display, UVScan.Alerts, UVScan.Controls, UVScan.Gauge, UVScan.UI.DataGrid;

type
  { Parts of the one-line status strip. }
  TStatusPart = (spState, spPort, spVin, spOsid, spRate, spLog);

  TMainForm = class(TForm)
    pnlAppBar: TRectangle;
    btnBack: TSpeedButton;
    lblTitle: TLabel;
    btnAction: TButton;
    btnMenu: TSpeedButton;
    pnlNav: TRectangle;
    pnlStatus: TRectangle;
    shpStatus: TCircle;
    lblStatus: TLabel;
    tiConnect: TTabItem;
    sbConnect: TVertScrollBox;
    gbAdapter: TGroupBox;
    flAdapter: TFlowLayout;
    cbPort: TComboBox;
    btnRefreshPorts: TButton;
    cbBaud: TComboBox;
    btnConnect: TButton;
    btnDisconnect: TButton;
    gbScan: TGroupBox;
    flScan: TFlowLayout;
    btnStartScan: TButton;
    btnStopScan: TButton;
    gbLogRec: TGroupBox;
    flLogRec: TFlowLayout;
    btnLog: TButton;
    btnPause: TButton;
    btnLogViewer: TButton;
    tiPids: TTabItem;
    tiMore: TTabItem;
    tcMore: TTabControl;
    tiMoreMenu: TTabItem;
    lbMore: TListBox;
    tiSettings: TTabItem;
    sbSettings: TVertScrollBox;
    gbAppearance: TGroupBox;
    lblTheme: TLabel;
    cbTheme: TComboBox;
    gbAlerts: TGroupBox;
    chkSound: TCheckBox;
    gbStream: TGroupBox;
    pnlPids: TLayout;
    pnlListBar: TLayout;
    lblList: TLabel;
    btnDeleteList: TButton;
    btnSaveList: TButton;
    cbLists: TComboBox;
    edtSearch: TEdit;
    pnlPidFooter: TLayout;
    lblBudget: TLabel;
    flPidButtons: TFlowLayout;
    btnTestPids: TButton;
    btnClearSelection: TButton;
    btnEditPids: TButton;
    lyPids: TLayout;
    splLeft: TSplitter;
    pnlRight: TLayout;
    pnlNotice: TRectangle;
    lblNotice: TLabel;
    tcMain: TTabControl;
    tiLive: TTabItem;
    pnlLiveFooter: TFlowLayout;
    btnResetMinMax: TButton;
    btnLiveTest: TButton;
    chkMinMax: TCheckBox;
    btnZoomOut: TButton;
    lblZoom: TLabel;
    btnZoomIn: TButton;
    lblLiveHint: TLabel;
    lyLive: TLayout;
    tiDashboard: TTabItem;
    pnlDashBar: TFlowLayout;
    btnAddGauge: TButton;
    btnTickDashPids: TButton;
    btnDashTest: TButton;
    lblDashHint: TLabel;
    sbDash: TVertScrollBox;
    tiControls: TTabItem;
    pnlCtlWarn: TRectangle;
    lblCtlWarn: TLabel;
    pnlCtlBar: TFlowLayout;
    btnCtlAdd: TButton;
    btnCtlEdit: TButton;
    btnCtlDup: TButton;
    btnCtlDelete: TButton;
    btnCtlRestore: TButton;
    btnReleaseAll: TButton;
    pnlCtlRun: TRectangle;
    lblCtlName: TLabel;
    lblCtlNotes: TLabel;
    flCtlRun: TFlowLayout;
    btnCtlSend: TButton;
    btnCtlOn: TButton;
    btnCtlHold: TButton;
    tbCtlValue: TTrackBar;
    edtCtlValue: TEdit;
    lblCtlUnits: TLabel;
    btnCtlApply: TButton;
    btnCtlOff: TButton;
    lyControls: TLayout;
    tiVehicle: TTabItem;
    gbVehicle: TGroupBox;
    lblVinCaption: TLabel;
    lblVin: TLabel;
    lblOsidCaption: TLabel;
    lblOsid: TLabel;
    lblFirmwareCaption: TLabel;
    lblFirmware: TLabel;
    btnReadInfo: TButton;
    gbDtcs: TGroupBox;
    pnlDtcButtons: TLayout;
    btnReadDtcs: TButton;
    btnClearDtcs: TButton;
    lyDtcs: TLayout;
    tiTools: TTabItem;
    sbTools: TVertScrollBox;
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
    gbDiscover: TGroupBox;
    btnDiscoverPids: TButton;
    lblDiscoverHelp: TLabel;
    tiMessages: TTabItem;
    pnlLogFooter: TLayout;
    btnClearMessages: TButton;
    btnCopyMessages: TButton;
    lyMessages: TLayout;
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
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure btnBackClick(Sender: TObject);
    procedure btnMenuClick(Sender: TObject);
    procedure btnActionClick(Sender: TObject);
    procedure pnlStatusClick(Sender: TObject);
    procedure lbMoreItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure cbThemeChange(Sender: TObject);
    procedure btnRefreshPortsClick(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure btnStartScanClick(Sender: TObject);
    procedure btnStopScanClick(Sender: TObject);
    procedure btnLogClick(Sender: TObject);
    procedure btnPauseClick(Sender: TObject);
    procedure btnLogViewerClick(Sender: TObject);
    procedure chkSoundChange(Sender: TObject);
    procedure btnDeleteListClick(Sender: TObject);
    procedure btnSaveListClick(Sender: TObject);
    procedure cbListsChange(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure btnTestPidsClick(Sender: TObject);
    procedure btnClearSelectionClick(Sender: TObject);
    procedure btnEditPidsClick(Sender: TObject);
    procedure pnlNoticeClick(Sender: TObject);
    procedure btnResetMinMaxClick(Sender: TObject);
    procedure btnTestDisplayClick(Sender: TObject);
    procedure chkMinMaxChange(Sender: TObject);
    procedure btnZoomOutClick(Sender: TObject);
    procedure lblZoomClick(Sender: TObject);
    procedure btnZoomInClick(Sender: TObject);
    procedure btnAddGaugeClick(Sender: TObject);
    procedure btnTickDashPidsClick(Sender: TObject);
    procedure sbDashResized(Sender: TObject);
    procedure btnCtlAddClick(Sender: TObject);
    procedure btnCtlEditClick(Sender: TObject);
    procedure btnCtlDupClick(Sender: TObject);
    procedure btnCtlDeleteClick(Sender: TObject);
    procedure btnCtlRestoreClick(Sender: TObject);
    procedure btnReleaseAllClick(Sender: TObject);
    procedure btnCtlSendClick(Sender: TObject);
    procedure btnCtlOnClick(Sender: TObject);
    procedure btnCtlHoldMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure btnCtlHoldMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure btnCtlHoldMouseLeave(Sender: TObject);
    procedure tbCtlValueChange(Sender: TObject);
    procedure btnCtlApplyClick(Sender: TObject);
    procedure btnCtlOffClick(Sender: TObject);
    procedure btnReadInfoClick(Sender: TObject);
    procedure btnReadDtcsClick(Sender: TObject);
    procedure btnClearDtcsClick(Sender: TObject);
    procedure btnWriteVinClick(Sender: TObject);
    procedure btnBrowseLogFolderClick(Sender: TObject);
    procedure btnSendRawClick(Sender: TObject);
    procedure chkTraceChange(Sender: TObject);
    procedure cbRateChange(Sender: TObject);
    procedure btnDiscoverPidsClick(Sender: TObject);
    procedure btnClearMessagesClick(Sender: TObject);
    procedure btnCopyMessagesClick(Sender: TObject);
    procedure miPidDisplayClick(Sender: TObject);
    procedure miPidGaugeClick(Sender: TObject);
    procedure miGaugeEditClick(Sender: TObject);
    procedure miGaugeDisplayClick(Sender: TObject);
    procedure miGaugeEarlierClick(Sender: TObject);
    procedure miGaugeLaterClick(Sender: TObject);
    procedure miGaugeRemoveClick(Sender: TObject);
    procedure tmrRefreshTimer(Sender: TObject);
  private
    grdPids: TDataGrid;
    grdLive: TDataGrid;
    grdControls: TDataGrid;
    grdDtcs: TDataGrid;
    grdMessages: TDataGrid;
    FCatalog: TPidCatalog;
    FDtcs: TDtcCatalog;
    FEngine: TScanEngine;
    FState: TEngineState;
    FSelected: TList<Integer>;      // selected PID ids, catalog order
    FSupport: TDictionary<Integer, Boolean>; // PID test results
    FRejected: TList<Integer>;
    FPidRows: TArray<Integer>;      // PID list rows: PID id, or -(category + 1) for a group row
    FLiveIds: TArray<Integer>;
    FLive: TLiveSnapshot;
    FMin, FMax: TArray<Double>;
    FLogging: Boolean;
    FLogPaused: Boolean;
    FClosing: Boolean;
    FForceClose: Boolean;
    FAutoScan: Boolean;
    FAutoLog: Boolean;
    FSettings: TAppSettings;
    FLists: TPidLists;
    FPendingLog: TStringList;   // message lines waiting for the next timer tick
    FMessages: TStringList;     // what the Messages tab shows
    FShownRows: TArray<string>; // what each live row last showed (value|min|max)
    FShownCycles: Int64;
    FDisplay: TDisplaySettings;      // display.json: PID looks, alert levels, gauges
    FAlerts: TAlertTracker;
    FRowStyles: TArray<TResolvedStyle>; // per live row, as last evaluated
    FFlashOn: Boolean;
    FGaugeViews: TList<TGaugeView>;
    FMenuPidId: Integer;             // PID the PID/grid menu is about
    FMenuGauge: Integer;             // gauge index the gauge menu is about
    FTestMode: Boolean;              // "Test display": made-up values instead of the PCM
    FTestStart: UInt64;
    FTestLo, FTestHi: TArray<Double>;
    FControls: TControlList;         // controls.json
    FCtlRows: TArray<TControlDef>;   // control list rows (nil = group row)
    FCtlGroups: TArray<string>;      // group caption per row ('' for controls)
    FControlResult: TDictionary<string, string>;  // control name -> last result
    FControlActive: TDictionary<string, Boolean>; // control name -> held by the engine
    FConfirmed: TDictionary<string, Boolean>;     // "hold to run" controls whose question was answered
    FValueControl: TControlDef;      // control the value slider was set up for
    FHolding: Boolean;               // "hold to run" button is down
    FDtcRows: TArray<TArray<string>>;
    FLastLogFile: string;            // the log recorded most recently
    FViewerLog: string;              // the log last handed to the viewer
    FZoom: Integer;                  // live grid zoom, percent
    FNormalBounds: TRect;            // window bounds when not maximized
    FStatus: array[TStatusPart] of string;
    FNavButtons: array[0..4] of TRectangle;
    FNavPages: array[0..4] of TTabItem;
    FMorePages: TArray<TTabItem>;    // lbMore row -> page (nil = log viewer)
    FPageMenu: TPopupMenu;
    FPidsDocked: Boolean;            // wide window: the PID list sits beside the pages
    FChromeReady: Boolean;
    FThemeSub: TMessageSubscriptionId;
    procedure CreateGrids;
    procedure BuildChrome;
    procedure ArrangeLayout;
    procedure FitFlowHeights;
    procedure FitVehicleColumns;
    procedure FitFormRows;
    // navigation
    procedure ShowPage(Page: TTabItem);
    function CurrentPage: TTabItem;
    procedure UpdateAppBar;
    procedure NavClick(Sender: TObject);
    procedure NavPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
    procedure AddPageMenuItem(const Text: string; Handler: TNotifyEvent; Enabled: Boolean = True;
      Checked: Boolean = False);
    procedure ToggleMinMaxClick(Sender: TObject);
    // theme
    procedure ApplyPalette;
    procedure ThemeChanged(const Sender: TObject; const M: TMessage);
    // grid events
    procedure PidsGetText(Sender: TObject; Col, Row: Integer; var Text: string);
    procedure PidsGetStyle(Sender: TObject; Col, Row: Integer; var Style: TCellStyle);
    procedure PidsGetChecked(Sender: TObject; Row: Integer; var Checked: Boolean);
    procedure PidsToggle(Sender: TObject; Row: Integer);
    procedure PidsIsGroup(Sender: TObject; Row: Integer; var IsGroup: Boolean);
    procedure PidsDblClick(Sender: TObject; Row: Integer);
    procedure LiveGetText(Sender: TObject; Col, Row: Integer; var Text: string);
    procedure LiveGetStyle(Sender: TObject; Col, Row: Integer; var Style: TCellStyle);
    procedure LiveDblClick(Sender: TObject; Row: Integer);
    procedure LiveMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
    procedure GridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure GridGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
    procedure ControlsGetText(Sender: TObject; Col, Row: Integer; var Text: string);
    procedure ControlsGetStyle(Sender: TObject; Col, Row: Integer; var Style: TCellStyle);
    procedure ControlsIsGroup(Sender: TObject; Row: Integer; var IsGroup: Boolean);
    procedure ControlsSelect(Sender: TObject);
    procedure ControlsDblClick(Sender: TObject; Row: Integer);
    procedure DtcsGetText(Sender: TObject; Col, Row: Integer; var Text: string);
    procedure MessagesGetText(Sender: TObject; Col, Row: Integer; var Text: string);
    procedure GaugeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure GaugeDblClick(Sender: TObject);
    procedure GaugeGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
    // zoom
    procedure SetZoom(Percent: Integer);
    procedure ZoomStep(Direction: Integer);
    procedure ApplyGridLayout;
    function Z(N: Single): Single;
    // controls
    procedure LoadControls;
    procedure SaveControls;
    procedure FillControls(const Select: string);
    function SelectedControl: TControlDef;
    function ControlActive(C: TControlDef): Boolean;
    procedure UpdateControlPanel;
    function ControlsUsable: Boolean;
    procedure SendControl(C: TControlDef; TurnOn: Boolean; const Value: Double = 0);
    procedure EditControl(C: TControlDef; IsNew: Boolean);
    procedure StopHolding;
    // live data
    procedure SetupLiveRows(const Ids: TArray<Integer>);
    procedure StartTest;
    procedure StopTest;
    function TestSnapshot: TLiveSnapshot;
    function LiveActive: Boolean;
    procedure RefreshLiveRows;
    procedure UpdateAlerts;
    procedure ApplyRowHeights;
    function LiveIndexOf(PidId: Integer): Integer;
    function FlashPhase: Boolean;
    // display & dashboard
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
    procedure PreparePidMenu(PidId: Integer);
    procedure PrepareGaugeMenu(Index: Integer);
    // data, settings, lists
    procedure FlushMessages;
    procedure ReloadCatalog;
    procedure FillLists(const Select: string);
    procedure SaveLists;
    procedure ApplyCommandLine;
    procedure LoadData;
    procedure LoadSettings;
    procedure SaveSettings;
    function AppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
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
    procedure SetStatus(Part: TStatusPart; const Text: string);
    procedure OpenPidEditor(const Filter: string);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

uses
  System.JSON, UVScan.JsonFile, UVScan.UI.Common, UVScan.UI.Theme, UVScan.Sound, UVScan.PidEditor,
  UVScan.PidDiscovery, UVScan.DisplayEditor, UVScan.GaugeEditor, UVScan.ControlEditor, UVScan.LogViewer;

const
  SimulatorPort = 'Simulator';
  ColName = 0;
  ColValue = 1;
  ColUnits = 2;
  ColMin = 3;
  ColMax = 4;
  PtToDip = 96 / 72;
  ZoomSteps: array[0..8] of Integer = (75, 90, 100, 110, 125, 150, 175, 200, 250);
  NoListCaption = '(none)';
  MaxMessageLines = 5000;

function ComboText(Combo: TComboBox): string;
begin
  if Combo.ItemIndex >= 0 then
    Result := Combo.Items[Combo.ItemIndex]
  else
    Result := '';
end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  Events: IFMXApplicationEventService;
begin
  FZoom := 100;
  FSelected := TList<Integer>.Create;
  FSupport := TDictionary<Integer, Boolean>.Create;
  FRejected := TList<Integer>.Create;
  FCatalog := TPidCatalog.Create;
  FDtcs := TDtcCatalog.Create;
  FSettings := TAppSettings.Create;
  FPendingLog := TStringList.Create;
  FMessages := TStringList.Create;
  FLists := TPidLists.Create;
  FDisplay := TDisplaySettings.Create;
  FControls := TControlList.Create;
  FControlResult := TDictionary<string, string>.Create;
  FControlActive := TDictionary<string, Boolean>.Create;
  FConfirmed := TDictionary<string, Boolean>.Create;
  FAlerts := TAlertTracker.Create;
  FGaugeViews := TList<TGaugeView>.Create;
  FMenuPidId := -1;
  FMenuGauge := -1;
  Caption := 'UVScan';
  lblVin.TextSettings.Font.Style := [TFontStyle.fsBold];
  lblOsid.TextSettings.Font.Style := [TFontStyle.fsBold];
  lblFirmware.TextSettings.Font.Style := [TFontStyle.fsBold];
  lblCtlName.TextSettings.Font.Style := [TFontStyle.fsBold];
  pnlNotice.Visible := False;
  CreateGrids;
  BuildChrome;
  LoadData;
  LoadSettings;
  ApplyTheme(ThemeModeFromKey(FSettings.Theme));
  FThemeSub := TMessageManager.DefaultManager.SubscribeToMessage(TThemeChangedMessage, ThemeChanged);
  ApplyPalette;
  FillPidList;
  FEngine := TScanEngine.Create(FCatalog, HandleEvent);
  cbRateChange(nil);
  FEngine.SetTrace(chkTrace.IsChecked);
  SetZoom(FSettings.LiveZoom);
  BuildDashboard;
  FState := esDisconnected;
  FChromeReady := True;
  ArrangeLayout;
  UpdateControls;
  ShowPage(tiLive);
  // Android ends an app without closing its form (swiped away, or killed in
  // the background), so save whenever the app leaves the screen.
  if TPlatformServices.Current.SupportsPlatformService(IFMXApplicationEventService, Events) then
    Events.SetApplicationEventHandler(AppEvent);
  ApplyCommandLine;
  TThread.ForceQueue(nil, FitFlowHeights);
end;

function TMainForm.AppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
begin
  Result := False;
  if (AAppEvent in [TApplicationEvent.EnteredBackground, TApplicationEvent.WillTerminate]) and not FClosing then
    SaveSettings;
end;

procedure TMainForm.CreateGrids;

  function NewGrid(Parent: TFmxObject): TDataGrid;
  begin
    Result := TDataGrid.Create(Self);
    Result.Parent := Parent;
    Result.Align := TAlignLayout.Client;
  end;

begin
  grdPids := NewGrid(lyPids);
  grdPids.Checkboxes := True;
  grdPids.AddColumn('PID', 200, gaLeft, True);
  grdPids.AddColumn('Units', 55);
  grdPids.AddColumn('Bytes', 45, gaRight);
  grdPids.AddColumn('Test', 60);
  grdPids.OnGetText := PidsGetText;
  grdPids.OnGetStyle := PidsGetStyle;
  grdPids.OnGetChecked := PidsGetChecked;
  grdPids.OnToggleCheck := PidsToggle;
  grdPids.OnIsGroupRow := PidsIsGroup;
  grdPids.OnRowDblClick := PidsDblClick;
  grdPids.OnMouseDown := GridMouseDown;
  grdPids.PopupMenu := pmPid;
  grdPids.Touch.InteractiveGestures := [TInteractiveGesture.LongTap];
  grdPids.OnGesture := GridGesture;

  grdLive := NewGrid(lyLive);
  grdLive.AddColumn('PID', 160, gaLeft, True);
  grdLive.AddColumn('Value', 140, gaRight);
  grdLive.AddColumn('Units', 80);
  grdLive.AddColumn('Min', 100, gaRight);
  grdLive.AddColumn('Max', 100, gaRight);
  grdLive.OnGetText := LiveGetText;
  grdLive.OnGetStyle := LiveGetStyle;
  grdLive.OnRowDblClick := LiveDblClick;
  grdLive.OnMouseDown := GridMouseDown;
  grdLive.OnMouseWheel := LiveMouseWheel;
  grdLive.PopupMenu := pmPid;
  grdLive.Touch.InteractiveGestures := [TInteractiveGesture.LongTap];
  grdLive.OnGesture := GridGesture;

  grdControls := NewGrid(lyControls);
  grdControls.AddColumn('Control', 230, gaLeft, True);
  grdControls.AddColumn('Type', 110);
  grdControls.AddColumn('Command', 220);
  grdControls.AddColumn('Last result', 260);
  grdControls.OnGetText := ControlsGetText;
  grdControls.OnGetStyle := ControlsGetStyle;
  grdControls.OnIsGroupRow := ControlsIsGroup;
  grdControls.OnSelect := ControlsSelect;
  grdControls.OnRowDblClick := ControlsDblClick;

  grdDtcs := NewGrid(lyDtcs);
  grdDtcs.AddColumn('Code', 80);
  grdDtcs.AddColumn('Module', 140);
  grdDtcs.AddColumn('Description', 300, gaLeft, True);
  grdDtcs.AddColumn('Status', 70);
  grdDtcs.OnGetText := DtcsGetText;

  grdMessages := NewGrid(lyMessages);
  grdMessages.ShowHeader := False;
  grdMessages.Striped := False;
  grdMessages.GridLines := False;
  grdMessages.RowHeight := 19;
  grdMessages.FontSize := 12;
  {$IFDEF MSWINDOWS}
  grdMessages.FontFamily := 'Consolas';
  {$ENDIF}
  grdMessages.AddColumn('', 400, gaLeft, True);
  grdMessages.OnGetText := MessagesGetText;
end;

{ Phone: the PID list becomes the first tab; the bars wrap. }
{ Window layout: top bar (title, back, main action, page menu), pages, status
  strip and tab bar - the same on Windows and Android. On a wide Windows
  window the PID list sits beside the pages instead of on its own tab, and
  the pages show their tool bars instead of keeping them in the menu. }

const
  NavCaptions: array[0..4] of string = ('Connect', 'PIDs', 'Live', 'Gauges', 'More');
  // Tab bar icons on a 24 x 24 grid, drawn as 2 px lines (More: three dots).
  NavIcons: array[0..4] of string = (
    'M9 3 L9 8 M15 3 L15 8 M6 8 L18 8 L18 11 C18 14.3 15.3 17 12 17 C8.7 17 6 14.3 6 11 Z M12 17 L12 21',
    'M3.5 6 L5.5 8 L8.5 4.5 M12 6.5 L21 6.5 M3.5 12.5 L5.5 14.5 L8.5 11 M12 13 L21 13 ' +
      'M4 17.5 L8 17.5 L8 21.5 L4 21.5 Z M12 19.5 L21 19.5',
    'M2 12 L6 12 L9 5 L14 19 L17 12 L22 12',
    'M3 18 C3 11.4 7 6 12 6 C17 6 21 11.4 21 18 M12 18 L16.5 11 M12 8.5 L12 10 M6.4 11 L7.5 12.1 ' +
      'M17.6 11 L16.5 12.1',
    '');
  WideLayoutWidth = 980; // Windows: from this client width the PID list sits beside the pages

procedure TMainForm.BuildChrome;

  procedure AddMore(const Text, Detail: string; Page: TTabItem);
  var
    Item: TListBoxItem;
  begin
    Item := TListBoxItem.Create(lbMore);
    Item.StyleLookup := 'listboxitembottomdetail';
    Item.Text := Text;
    Item.ItemData.Detail := Detail;
    Item.ItemData.Accessory := TListBoxItemData.TAccessory.aMore;
    Item.Height := 64;
    lbMore.AddObject(Item);
    FMorePages := FMorePages + [Page];
  end;

  function AddIcon(Button: TControl): TPath;
  begin
    Result := TPath.Create(Self);
    Result.Parent := Button;
    Result.Stored := False;
    Result.Align := TAlignLayout.Center;
    Result.Width := 22;
    Result.Height := 22;
    Result.HitTest := False;
    Result.WrapMode := TPathWrapMode.Fit;
    Result.Stroke.Thickness := 2.2;
    Result.Stroke.Cap := TStrokeCap.Round;
    Result.Stroke.Join := TStrokeJoin.Round;
  end;

var
  I: Integer;
  Btn: TRectangle;
  Icon: TPath;
begin
  FNavPages[0] := tiConnect;
  FNavPages[1] := tiPids;
  FNavPages[2] := tiLive;
  FNavPages[3] := tiDashboard;
  FNavPages[4] := tiMore;
  for I := 0 to 4 do
  begin
    Btn := TRectangle.Create(Self);
    Btn.Parent := pnlNav;
    Btn.Stored := False;
    Btn.Align := TAlignLayout.Left;
    Btn.Position.X := I * 100;
    Btn.Width := 100;
    Btn.Fill.Color := TAlphaColors.Null;
    Btn.Stroke.Kind := TBrushKind.None;
    Btn.HitTest := True;
    Btn.Cursor := crHandPoint;
    Btn.Tag := I;
    Btn.OnClick := NavClick;
    Btn.OnPaint := NavPaint;
    FNavButtons[I] := Btn;
  end;

  btnBack.Text := '';
  Icon := AddIcon(btnBack);
  Icon.Data.Data := 'M15 4 L7 12 L15 20';
  Icon.Fill.Kind := TBrushKind.None;
  btnMenu.Text := '';
  Icon := AddIcon(btnMenu);
  for I := 0 to 2 do
    Icon.Data.AddEllipse(TRectF.Create(10, 3 + I * 7, 14, 7 + I * 7));
  Icon.Stroke.Kind := TBrushKind.None;

  AddMore('Real-time controls', 'Switch outputs, hold values, reset learned values', tiControls);
  AddMore('Trouble codes', 'Read and clear stored codes', tiVehicle);
  AddMore('Log viewer', 'Open recorded logs as a chart and table', nil);
  AddMore('Tools', 'Write VIN, raw AVT frames, PID discovery', tiTools);
  AddMore('Settings', 'Theme, alert sounds, log folder, stream speed', tiSettings);
  AddMore('Messages', 'Connection log and raw traffic', tiMessages);

  FPageMenu := TPopupMenu.Create(Self);
  FPageMenu.Parent := Self;
  tiConnect.Text := 'Connection';

  if IsMobile then
  begin
    btnBrowseLogFolder.Visible := False; // no folder picker on a phone
    lblDashHint.Text := 'Long-press a gauge to change, move or remove it.';
    WindowState := TWindowState.wsMaximized;
    KeepInSafeArea(Self);
  end;
end;

procedure TMainForm.ArrangeLayout;
var
  Wide: Boolean;
  I, N: Integer;
  W, X: Single;
begin
  if not FChromeReady then
    Exit;
  Wide := (not IsMobile) and (ClientWidth >= WideLayoutWidth);
  if Wide and (pnlPids.Parent <> Self) then
  begin
    pnlPids.Parent := Self;
    pnlPids.Align := TAlignLayout.Left;
    pnlPids.Position.X := 0;
    if FSettings.Window.PidPanelWidth > 0 then
      pnlPids.Width := FSettings.Window.PidPanelWidth
    else
      pnlPids.Width := 400;
    splLeft.Visible := True;
    splLeft.Position.X := pnlPids.Width + 1;
  end
  else if not Wide and (pnlPids.Parent <> tiPids) then
  begin
    if FPidsDocked then
      FSettings.Window.PidPanelWidth := Round(pnlPids.Width);
    pnlPids.Parent := tiPids;
    pnlPids.Align := TAlignLayout.Client;
    splLeft.Visible := False;
  end;
  FPidsDocked := Wide;
  FNavButtons[1].Visible := not Wide;
  if Wide and (tcMain.ActiveTab = tiPids) then
    ShowPage(tiLive);
  // Wide windows show the page tool bars; otherwise their buttons are in the menu.
  pnlLiveFooter.Visible := Wide;
  pnlDashBar.Visible := Wide;
  // The tab bar buttons share the width.
  N := 0;
  for I := 0 to 4 do
    if FNavButtons[I].Visible then
      Inc(N);
  W := ClientWidth / Max(1, N);
  X := 0;
  for I := 0 to 4 do
    if FNavButtons[I].Visible then
    begin
      FNavButtons[I].Position.X := X;
      FNavButtons[I].Width := W;
      X := X + W;
    end;
end;

{ Navigation }

function TMainForm.CurrentPage: TTabItem;
begin
  if tcMain.ActiveTab = tiMore then
    Result := tcMore.ActiveTab
  else
    Result := tcMain.ActiveTab;
  if Result = nil then
    Result := tiLive;
end;

procedure TMainForm.ShowPage(Page: TTabItem);
begin
  if Page = nil then
    Exit;
  if (Page = tiPids) and FPidsDocked then
    Page := tiLive;
  if Page.TabControl = tcMore then
  begin
    tcMain.ActiveTab := tiMore;
    tcMore.ActiveTab := Page;
  end
  else
  begin
    tcMain.ActiveTab := Page;
    if Page = tiMore then
      tcMore.ActiveTab := tiMoreMenu; // the More tab always opens on its list
  end;
  UpdateAppBar;
  TThread.ForceQueue(nil, FitFlowHeights); // a page has no layout until it is shown
end;

procedure TMainForm.UpdateAppBar;
var
  P: TTabItem;
  I: Integer;
begin
  if not FChromeReady then
    Exit;
  P := CurrentPage;
  lblTitle.Text := P.Text;
  btnBack.Visible := (tcMain.ActiveTab = tiMore) and (P <> tiMoreMenu);
  btnMenu.Visible := (P = tiLive) or (P = tiDashboard) or (P = tiPids) or (P = tiMessages) or (P = tiConnect);
  for I := 0 to 4 do
    FNavButtons[I].Repaint;
end;

procedure TMainForm.NavClick(Sender: TObject);
begin
  ShowPage(FNavPages[TControl(Sender).Tag]);
end;

procedure TMainForm.NavPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
var
  I: Integer;
  P: TPalette;
  Color: TAlphaColor;
  Path: TPathData;
  Cx: Single;
  D: Integer;
begin
  I := TControl(Sender).Tag;
  P := Palette;
  Cx := (ARect.Left + ARect.Right) / 2;
  if FNavPages[I] = tcMain.ActiveTab then
  begin
    Color := P.Accent;
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := WithAlpha(P.Accent, $30);
    Canvas.FillRect(TRectF.Create(Cx - 28, 4, Cx + 28, 32), 14, 14, AllCorners, 1);
  end
  else
    Color := P.Muted;
  Path := TPathData.Create;
  try
    if NavIcons[I] = '' then
      for D := -1 to 1 do
        Path.AddEllipse(TRectF.Create(12 + D * 6 - 2, 10, 12 + D * 6 + 2, 14))
    else
      Path.Data := NavIcons[I];
    Path.Translate(Cx - 12, 6);
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := Color;
    Canvas.Stroke.Thickness := 2;
    Canvas.Stroke.Cap := TStrokeCap.Round;
    Canvas.Stroke.Join := TStrokeJoin.Round;
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := Color;
    if NavIcons[I] = '' then
      Canvas.FillPath(Path, 1)
    else
      Canvas.DrawPath(Path, 1);
  finally
    Path.Free;
  end;
  Canvas.Font.Size := 12;
  Canvas.FillText(TRectF.Create(ARect.Left, 33, ARect.Right, ARect.Bottom - 2), NavCaptions[I], False, 1, [],
    TTextAlign.Center, TTextAlign.Center);
end;

procedure TMainForm.btnBackClick(Sender: TObject);
begin
  ShowPage(tiMoreMenu);
end;

procedure TMainForm.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if Key <> vkHardwareBack then
    Exit;
  // Android back: out of a More page, then back to Live; from Live, leave the app.
  if btnBack.Visible then
  begin
    btnBackClick(nil);
    Key := 0;
  end
  else if CurrentPage <> tiLive then
  begin
    ShowPage(tiLive);
    Key := 0;
  end;
end;

procedure TMainForm.pnlStatusClick(Sender: TObject);
begin
  ShowPage(tiConnect);
end;

procedure TMainForm.lbMoreItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
var
  Page: TTabItem;
begin
  if (Item = nil) or (Item.Index > High(FMorePages)) then
    Exit;
  Page := FMorePages[Item.Index];
  TThread.ForceQueue(nil,
    procedure
    begin
      lbMore.ItemIndex := -1;
      if Page = nil then
        btnLogViewerClick(nil)
      else
        ShowPage(Page);
    end);
end;

procedure TMainForm.btnActionClick(Sender: TObject);
begin
  case FState of
    esDisconnected: btnConnectClick(nil);
    esConnected: btnStartScanClick(nil);
  else
    btnStopScanClick(nil);
  end;
end;

procedure TMainForm.AddPageMenuItem(const Text: string; Handler: TNotifyEvent; Enabled: Boolean;
  Checked: Boolean);
var
  M: TMenuItem;
begin
  M := TMenuItem.Create(FPageMenu);
  M.Text := Text;
  M.OnClick := Handler;
  M.Enabled := Enabled;
  M.IsChecked := Checked;
  FPageMenu.AddObject(M);
end;

procedure TMainForm.ToggleMinMaxClick(Sender: TObject);
begin
  chkMinMax.IsChecked := not chkMinMax.IsChecked;
end;

{ The page's actions (on narrow windows and phones its tool bar is hidden). }
procedure TMainForm.btnMenuClick(Sender: TObject);
var
  P: TTabItem;
  Pt: TPointF;
begin
  while FPageMenu.ItemsCount > 0 do
    FPageMenu.Items[0].Free;
  P := CurrentPage;
  if P = tiLive then
  begin
    AddPageMenuItem('Reset min / max', btnResetMinMaxClick);
    AddPageMenuItem(btnLiveTest.Text, btnTestDisplayClick, btnLiveTest.Enabled);
    AddPageMenuItem('Show min / max', ToggleMinMaxClick, True, chkMinMax.IsChecked);
    AddPageMenuItem('-', nil);
    AddPageMenuItem('Bigger text', btnZoomInClick);
    AddPageMenuItem('Smaller text', btnZoomOutClick);
    AddPageMenuItem(Format('Normal size (now %d%%)', [FZoom]), lblZoomClick);
  end
  else if P = tiDashboard then
  begin
    AddPageMenuItem('Add gauge...', btnAddGaugeClick);
    AddPageMenuItem('Tick these PIDs', btnTickDashPidsClick);
    AddPageMenuItem(btnDashTest.Text, btnTestDisplayClick, btnDashTest.Enabled);
  end
  else if P = tiPids then
  begin
    AddPageMenuItem('Test PIDs', btnTestPidsClick, btnTestPids.Enabled);
    AddPageMenuItem('Clear selection', btnClearSelectionClick);
    AddPageMenuItem('Edit PIDs...', btnEditPidsClick, btnEditPids.Enabled);
  end
  else if P = tiMessages then
  begin
    AddPageMenuItem('Copy all', btnCopyMessagesClick);
    AddPageMenuItem('Clear', btnClearMessagesClick);
  end
  else if P = tiConnect then
    AddPageMenuItem('Refresh ports', btnRefreshPortsClick, btnRefreshPorts.Enabled);
  if FPageMenu.ItemsCount = 0 then
    Exit;
  // Right-aligned under the button (the menu keeps itself on the form).
  Pt := btnMenu.LocalToAbsolute(TPointF.Create(0, btnMenu.Height));
  ShowMenuAsActions(Self, FPageMenu, TPointF.Create(ClientWidth, Pt.Y));
end;

{ Theme }

procedure TMainForm.cbThemeChange(Sender: TObject);
begin
  if not FChromeReady then
    Exit;
  ApplyTheme(TThemeMode(Max(0, cbTheme.ItemIndex)));
  SaveSettings;
end;

procedure TMainForm.ThemeChanged(const Sender: TObject; const M: TMessage);
begin
  ApplyPalette;
end;

procedure TMainForm.ApplyPalette;
var
  P: TPalette;

  procedure Bar(R: TRectangle);
  begin
    R.Fill.Kind := TBrushKind.Solid;
    R.Fill.Color := P.Bar;
    R.Stroke.Kind := TBrushKind.Solid;
    R.Stroke.Color := P.BarLine;
    R.Stroke.Thickness := 1;
  end;

  procedure Muted(L: TLabel);
  begin
    L.StyledSettings := L.StyledSettings - [TStyledSetting.FontColor];
    L.TextSettings.FontColor := P.Muted;
  end;

  procedure Icon(Button: TControl);
  var
    I: Integer;
  begin
    for I := 0 to Button.ControlsCount - 1 do
      if Button.Controls[I] is TPath then
      begin
        TPath(Button.Controls[I]).Stroke.Color := P.Text;
        TPath(Button.Controls[I]).Fill.Color := P.Text;
      end;
  end;

var
  I: Integer;
begin
  P := Palette;
  Bar(pnlAppBar);
  Bar(pnlNav);
  Bar(pnlStatus);
  Icon(btnBack);
  Icon(btnMenu);
  pnlCtlWarn.Fill.Color := P.PanelWarn;
  pnlCtlRun.Fill.Color := P.Panel;
  Muted(lblLiveHint);
  Muted(lblDashHint);
  Muted(lblDiscoverHelp);
  Muted(lblCtlNotes);
  lblNotice.StyledSettings := lblNotice.StyledSettings - [TStyledSetting.FontColor];
  lblNotice.TextSettings.FontColor := P.NoticeText;
  if pnlNotice.Tag = 1 then
    pnlNotice.Fill.Color := P.NoticeError
  else
    pnlNotice.Fill.Color := P.NoticeWarn;
  if FEngine <> nil then
    UpdateBudget;
  if FChromeReady then
    TThread.ForceQueue(nil, FitFlowHeights);
  for I := 0 to 4 do
    if FNavButtons[I] <> nil then
      FNavButtons[I].Repaint;
end;

{ Flow layouts wrap their buttons on narrow windows; grow their bars to fit. }
{ Vehicle box: the values start after the widest caption (fonts differ by style). }
procedure TMainForm.FitVehicleColumns;
var
  Caps: array[0..2] of TLabel;
  Vals: array[0..2] of TLabel;
  I: Integer;
  W: Single;
begin
  Caps[0] := lblVinCaption;
  Caps[1] := lblOsidCaption;
  Caps[2] := lblFirmwareCaption;
  Vals[0] := lblVin;
  Vals[1] := lblOsid;
  Vals[2] := lblFirmware;
  W := 0;
  for I := 0 to 2 do
  begin
    Caps[I].WordWrap := False;
    FitTextWidth(Caps[I]);
    W := Max(W, Caps[I].Width);
  end;
  for I := 0 to 2 do
  begin
    Caps[I].Height := 30;
    Vals[I].Height := 30;
    Caps[I].Position.Y := 30 + I * 32;
    Vals[I].Position.Y := Caps[I].Position.Y;
    Vals[I].Position.X := Caps[I].Position.X + W + 12;
    Vals[I].Width := Max(120, gbVehicle.Width - Vals[I].Position.X - 12);
  end;
  btnReadInfo.Position.Y := 30 + 3 * 32 + 4;
  gbVehicle.Height := btnReadInfo.Position.Y + btnReadInfo.Height + 12;
end;

{ Settings and Tools rows: caption, a field filling the rest of the box, and a
  button at the right end, so they fit a phone as well as a wide window. }
procedure TMainForm.FitFormRows;

  procedure Row(Cap: TLabel; Field, Btn: TControl; Box: TControl);
  var
    X, R: Single;
  begin
    if Box.Width < 50 then
      Exit; // not laid out yet
    X := 12;
    if Cap <> nil then
    begin
      Cap.WordWrap := False;
      FitTextWidth(Cap);
      Cap.Position.X := 12;
      X := 12 + Cap.Width + 12;
    end;
    R := Box.Width - 12;
    if (Btn <> nil) and Btn.Visible then
    begin
      FitTextWidth(Btn, 80);
      Btn.Position.X := R - Btn.Width;
      R := Btn.Position.X - 8;
    end;
    Field.Position.X := X;
    Field.Width := Max(80, R - X);
  end;

  procedure Wide(C: TControl; Box: TControl);
  begin
    if Box.Width >= 50 then
      C.Width := Box.Width - C.Position.X - 12;
  end;

begin
  Row(lblTheme, cbTheme, nil, gbAppearance);
  Row(lblLogFolderCaption, edtLogFolder, btnBrowseLogFolder, gbLogging);
  Row(lblRate, cbRate, nil, gbStream);
  Row(nil, edtNewVin, btnWriteVin, gbWriteVin);
  Row(nil, edtRaw, btnSendRaw, gbAdvanced);
  Wide(lblRaw, gbAdvanced);
  Wide(chkTrace, gbAdvanced);
  Wide(chkSound, gbAlerts);
  Wide(lblDiscoverHelp, gbDiscover);
  lblDiscoverHelp.WordWrap := True;
end;

procedure TMainForm.FitFlowHeights;

  // Buttons and check boxes as wide as their text (the style sets the font).
  procedure FitWidths(Flow: TControl; MinWidth: Single);
  var
    I: Integer;
  begin
    for I := 0 to Flow.ControlsCount - 1 do
      if (Flow.Controls[I] is TButton) or (Flow.Controls[I] is TCheckBox) then
        FitTextWidth(Flow.Controls[I], MinWidth);
  end;

  procedure Fit(Flow: TFlowLayout; Bar: TControl; Extra: Single);
  var
    I: Integer;
    C: TControl;
    Bottom: Single;
  begin
    Bottom := 0;
    for I := 0 to Flow.ControlsCount - 1 do
    begin
      C := Flow.Controls[I];
      if C.Visible then
        Bottom := Max(Bottom, C.Position.Y + C.Height);
    end;
    if Bottom <= 0 then
      Exit;
    Bottom := Bottom + Flow.Padding.Bottom + Extra;
    if Abs(Bar.Height - Bottom) > 0.5 then
      Bar.Height := Bottom;
  end;

begin
  if FClosing then
    Exit;
  FitWidths(pnlLiveFooter, 0);
  FitWidths(pnlDashBar, 0);
  FitWidths(pnlCtlBar, 70);
  FitWidths(flPidButtons, 90);
  FitWidths(flCtlRun, 70);
  FitWidths(flAdapter, 120);
  FitWidths(flScan, 150);
  FitWidths(flLogRec, 140);
  FitTextWidth(lblList);
  FitVehicleColumns;
  FitFormRows;
  // Connect page: group boxes around flow layouts (title + padding = 36).
  Fit(flAdapter, gbAdapter, 36);
  Fit(flScan, gbScan, 36);
  Fit(flLogRec, gbLogRec, 36);
  Fit(pnlLiveFooter, pnlLiveFooter, 0);
  Fit(pnlDashBar, pnlDashBar, 0);
  Fit(pnlCtlBar, pnlCtlBar, 0);
  Fit(flPidButtons, pnlPidFooter, lblBudget.Height);
  Fit(flCtlRun, pnlCtlRun, lblCtlName.Height + lblCtlNotes.Height + pnlCtlRun.Padding.Top + pnlCtlRun.Padding.Bottom);
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
      btnConnectClick(nil);
    end);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FClosing := True;
  TMessageManager.DefaultManager.Unsubscribe(TThemeChangedMessage, FThemeSub);
  tmrRefresh.Enabled := False;
  FEngine.Free; // stops the scan, closes the port, waits for the thread
  FCatalog.Free;
  FSettings.Free;
  FPendingLog.Free;
  FMessages.Free;
  FLists.Free;
  FDisplay.Free;
  FControls.Free;
  FControlResult.Free;
  FControlActive.Free;
  FConfirmed.Free;
  FAlerts.Free;
  FGaugeViews.Free; // the views themselves are owned by the form
  FDtcs.Free;
  FSelected.Free;
  FSupport.Free;
  FRejected.Free;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FLogging and not FForceClose then
  begin
    CanClose := False;
    Confirm('A log is being recorded. Stop logging and exit?',
      procedure
      begin
        FForceClose := True;
        Close;
      end);
    Exit;
  end;
  FClosing := True;
  SaveSettings;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if (Key = vkF7) and (Shift = []) then
  begin
    btnLogViewerClick(nil);
    Key := 0;
  end
  else if (Key = vkF8) and btnLog.Enabled then
  begin
    btnLogClick(nil);
    Key := 0;
  end
  else if (Key = vkF9) and btnPause.Enabled then
  begin
    btnPauseClick(nil);
    Key := 0;
  end
  else if (ssCtrl in Shift) and (tcMain.ActiveTab = tiLive) then
  begin
    if (Key = vkAdd) or (KeyChar = '+') or (KeyChar = '=') then
      ZoomStep(1)
    else if (Key = vkSubtract) or (KeyChar = '-') then
      ZoomStep(-1)
    else if (Key = vkNumpad0) or (KeyChar = '0') then
      SetZoom(100)
    else
      Exit;
    Key := 0;
    KeyChar := #0;
  end;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  if grdLive = nil then
    Exit; // the form is still loading
  if WindowState = TWindowState.wsNormal then
    FNormalBounds := TRect.Create(Left, Top, Left + Width, Top + Height);
  ArrangeLayout;
  if FPidsDocked then
    pnlPids.Width := Min(pnlPids.Width, Max(200, ClientWidth - 400));
  TThread.ForceQueue(nil, FitFlowHeights);
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
  cbBaud.ItemIndex := Max(0, cbBaud.Items.IndexOf(IntToStr(FSettings.Baud)));
  edtLogFolder.Text := FSettings.LogFolder;
  cbRate.ItemIndex := Ord(FSettings.StreamSpeed);
  chkTrace.IsChecked := FSettings.Trace;
  chkSound.IsChecked := FSettings.AlertSounds;
  chkMinMax.IsChecked := FSettings.ShowMinMax;
  cbTheme.ItemIndex := Ord(ThemeModeFromKey(FSettings.Theme));
  for N in FSettings.SelectedPids do
    if (FCatalog.FindById(N) <> nil) and FCatalog.FindById(N).Enabled and not FSelected.Contains(N) then
      FSelected.Add(N);
  FillLists(FSettings.ActiveList);
  if FSettings.Window.Saved and not IsMobile then
  begin
    SetBounds(FSettings.Window.Left, FSettings.Window.Top, FSettings.Window.Width, FSettings.Window.Height);
    // Keep the window on a screen that still exists.
    if (Left > Screen.Width - 100) or (Top > Screen.Height - 100) or (Left + Width < 100) or (Top < -20) then
    begin
      Left := 40;
      Top := 40;
    end;
    FNormalBounds := TRect.Create(Left, Top, Left + Width, Top + Height);
    if FSettings.Window.Maximized then
      WindowState := TWindowState.wsMaximized;
    if FSettings.Window.PidPanelWidth > 0 then
      pnlPids.Width := FSettings.Window.PidPanelWidth;
  end;
end;

procedure TMainForm.SaveSettings;
begin
  FSettings.Port := ComboText(cbPort);
  FSettings.Baud := StrToIntDef(ComboText(cbBaud), 115200);
  FSettings.LogFolder := edtLogFolder.Text;
  FSettings.StreamSpeed := TStreamSpeed(Max(0, cbRate.ItemIndex));
  FSettings.Trace := chkTrace.IsChecked;
  FSettings.AlertSounds := chkSound.IsChecked;
  FSettings.LiveZoom := FZoom;
  FSettings.ShowMinMax := chkMinMax.IsChecked;
  FSettings.Theme := ThemeKeys[TThemeMode(Max(0, cbTheme.ItemIndex))];
  FSettings.SelectedPids := FSelected.ToArray;
  if cbLists.ItemIndex > 0 then
    FSettings.ActiveList := ComboText(cbLists)
  else
    FSettings.ActiveList := '';
  if not IsMobile then
  begin
    if FNormalBounds.Width > 0 then
    begin
      FSettings.Window.Left := FNormalBounds.Left;
      FSettings.Window.Top := FNormalBounds.Top;
      FSettings.Window.Width := FNormalBounds.Width;
      FSettings.Window.Height := FNormalBounds.Height;
      FSettings.Window.Saved := True;
    end;
    FSettings.Window.Maximized := WindowState = TWindowState.wsMaximized;
    if FPidsDocked then
      FSettings.Window.PidPanelWidth := Round(pnlPids.Width);
  end;
  try
    FSettings.SaveToFile(SettingsFile);
  except
    on E: Exception do
      AddMessage('Settings could not be saved: ' + E.Message);
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
  FillPorts(ComboText(cbPort));
end;

{ PID list }

procedure TMainForm.FillPidList;
var
  Cat: TPidCategory;
  I, Keep: Integer;
  P: TPidDef;
  Filter: string;
  Rows: TList<Integer>;
  Added: Boolean;
begin
  Keep := -1;
  if (grdPids.ItemIndex >= 0) and (grdPids.ItemIndex <= High(FPidRows)) then
    Keep := FPidRows[grdPids.ItemIndex];
  Filter := LowerCase(Trim(edtSearch.Text));
  Rows := TList<Integer>.Create;
  try
    for Cat := Low(TPidCategory) to High(TPidCategory) do
    begin
      Added := False;
      for I := 0 to FCatalog.Count - 1 do
      begin
        P := FCatalog[I];
        if not P.Enabled or (P.Category <> Cat) then
          Continue;
        if (Filter <> '') and (Pos(Filter, LowerCase(P.LongName + ' ' + P.ShortName + ' ' + P.PidCode)) = 0) then
          Continue;
        if not Added then
        begin
          Rows.Add(-(Ord(Cat) + 1));
          Added := True;
        end;
        Rows.Add(P.Id);
      end;
    end;
    FPidRows := Rows.ToArray;
  finally
    Rows.Free;
  end;
  grdPids.RowCount := Length(FPidRows);
  grdPids.ItemIndex := -1;
  if Keep >= 0 then
    for I := 0 to High(FPidRows) do
      if FPidRows[I] = Keep then
        grdPids.ItemIndex := I;
  grdPids.Refresh;
  UpdateBudget;
end;

procedure TMainForm.PidsIsGroup(Sender: TObject; Row: Integer; var IsGroup: Boolean);
begin
  IsGroup := (Row <= High(FPidRows)) and (FPidRows[Row] < 0);
end;

procedure TMainForm.PidsGetText(Sender: TObject; Col, Row: Integer; var Text: string);
var
  P: TPidDef;
  Supported: Boolean;
begin
  if Row > High(FPidRows) then
    Exit;
  if FPidRows[Row] < 0 then
  begin
    if Col = 0 then
      Text := CategoryNames[TPidCategory(-FPidRows[Row] - 1)];
    Exit;
  end;
  P := FCatalog.FindById(FPidRows[Row]);
  if P = nil then
    Exit;
  case Col of
    0: Text := P.LongName;
    1: Text := P.Units;
    2:
      case P.Kind of
        pkVehicle: Text := IntToStr(P.DataLength);
        pkCalculated: Text := 'calc';
        pkAnalog: Text := 'A/D';
      end;
    3:
      begin
        if FSupport.TryGetValue(P.Id, Supported) then
          Text := IfThen(Supported, 'yes', 'no');
        if FRejected.Contains(P.Id) then
          Text := 'rejected';
      end;
  end;
end;

procedure TMainForm.PidsGetStyle(Sender: TObject; Col, Row: Integer; var Style: TCellStyle);
var
  Supported: Boolean;
begin
  if (Col <> 3) or (Row > High(FPidRows)) or (FPidRows[Row] < 0) then
    Exit;
  if FRejected.Contains(FPidRows[Row]) or (FSupport.TryGetValue(FPidRows[Row], Supported) and not Supported) then
    Style.Fore := Palette.Bad
  else if FSupport.TryGetValue(FPidRows[Row], Supported) then
    Style.Fore := Palette.Good;
end;

procedure TMainForm.PidsGetChecked(Sender: TObject; Row: Integer; var Checked: Boolean);
begin
  Checked := (Row <= High(FPidRows)) and (FPidRows[Row] >= 0) and FSelected.Contains(FPidRows[Row]);
end;

procedure TMainForm.PidsToggle(Sender: TObject; Row: Integer);
begin
  if (Row > High(FPidRows)) or (FPidRows[Row] < 0) then
    Exit;
  SetSelected(FPidRows[Row], not FSelected.Contains(FPidRows[Row]));
  UpdateBudget;
end;

procedure TMainForm.PidsDblClick(Sender: TObject; Row: Integer);
begin
  PidsToggle(Sender, Row);
  grdPids.Refresh;
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

procedure TMainForm.edtSearchChange(Sender: TObject);
begin
  FillPidList;
end;

procedure TMainForm.OpenPidEditor(const Filter: string);
begin
  TPidEditorForm.Execute(FCatalog, PidsFile, Filter,
    procedure(Saved: Boolean)
    begin
      if not Saved then
        Exit;
      ReloadCatalog;
      AddMessage(Format('PID definitions saved (%d PIDs) to %s', [FCatalog.Count, PidsFile]));
    end);
end;

procedure TMainForm.btnEditPidsClick(Sender: TObject);
begin
  // The engine only uses the catalog while scanning or busy, which this button excludes.
  if FState in [esDisconnected, esConnected] then
    OpenPidEditor('');
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
begin
  if FState <> esConnected then
    Exit;
  TPidDiscoveryForm.Execute(FEngine, FCatalog, PidsFile,
    procedure(Added: TArray<Integer>)
    var
      N: Integer;
    begin
      N := Length(Added);
      if N = 0 then
        Exit;
      ReloadCatalog;
      AddMessage(Format('PID search: added %d PIDs to %s', [N, PidsFile]));
      if FState in [esDisconnected, esConnected] then
        Confirm(Format('%d new PIDs were added as raw "PID $xxxx" entries (category Other).' + sLineBreak +
          'Open the PID editor to name and define them now?', [N]),
          procedure
          begin
            OpenPidEditor('PID $');
          end);
    end);
end;

{ Scan lists }

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
  cbLists.OnChange := nil;
  cbLists.ItemIndex := Max(0, cbLists.Items.IndexOf(Select));
  cbLists.OnChange := cbListsChange;
  btnDeleteList.Enabled := cbLists.ItemIndex > 0;
end;

procedure TMainForm.SaveLists;
begin
  try
    FLists.SaveToFile(ListsFile);
  except
    on E: Exception do
      ShowWarning('Could not save the scan lists: ' + E.Message);
  end;
end;

procedure TMainForm.cbListsChange(Sender: TObject);
var
  I, Id, Missing: Integer;
  P: TPidDef;
begin
  if FLists = nil then
    Exit; // the form is still loading
  btnDeleteList.Enabled := cbLists.ItemIndex > 0;
  if cbLists.ItemIndex <= 0 then
    Exit;
  I := FLists.IndexOf(ComboText(cbLists));
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
    ShowNotice(Format('Scan list "%s": %d PID(s) no longer exist or are disabled', [ComboText(cbLists), Missing]), False);
end;

procedure TMainForm.btnSaveListClick(Sender: TObject);
var
  Current: string;
begin
  if FSelected.Count = 0 then
  begin
    ShowNotice('Tick some PIDs first, then save them as a list', True);
    Exit;
  end;
  if cbLists.ItemIndex > 0 then
    Current := ComboText(cbLists)
  else
    Current := '';
  AskText('Save scan list', 'List name', Current,
    procedure(Name: string)
    var
      Save: TProc;
    begin
      if Name = '' then
        Exit;
      Save :=
        procedure
        begin
          FLists.Put(Name, FSelected.ToArray);
          SaveLists;
          FillLists(Name);
          AddMessage(Format('Saved scan list "%s" (%d PIDs)', [Name, FSelected.Count]));
        end;
      if (FLists.IndexOf(Name) >= 0) and not SameText(Name, Current) then
        Confirm(Format('Replace the existing list "%s"?', [Name]), Save)
      else
        Save();
    end);
end;

procedure TMainForm.btnDeleteListClick(Sender: TObject);
var
  Name: string;
begin
  if cbLists.ItemIndex <= 0 then
    Exit;
  Name := ComboText(cbLists);
  Confirm(Format('Delete the scan list "%s"? The PIDs themselves are not affected.', [Name]),
    procedure
    begin
      FLists.Delete(Name);
      SaveLists;
      FillLists('');
    end);
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
  lblBudget.StyledSettings := lblBudget.StyledSettings - [TStyledSetting.FontColor];
  try
    Dpids := Format('%d DPID(s)', [Length(PlanDpids(Reqs).Dpids)]);
    lblBudget.TextSettings.FontColor := Palette.Text;
  except
    on E: EDpidPlanError do
    begin
      Dpids := 'too many!';
      lblBudget.TextSettings.FontColor := Palette.Bad;
    end;
  end;
  lblBudget.Text := Format('%d selected  -  %d / %d bytes  -  %s',
    [Count, Bytes, MaxDpids * DpidDataBytes, Dpids]);
end;

procedure TMainForm.btnTestPidsClick(Sender: TObject);
var
  Cmd: TEngineCommand;
  Id: Integer;
  P: TPidDef;
  Run: TProc;
begin
  Cmd := Command(ecTestPids);
  for Id in FSelected do
  begin
    P := FCatalog.FindById(Id);
    if (P <> nil) and (P.Kind = pkVehicle) then
      Cmd.PidIds := Cmd.PidIds + [Id];
  end;
  Run :=
    procedure
    begin
      FSupport.Clear;
      Post(Cmd);
      ShowPage(tiMessages);
    end;
  if Length(Cmd.PidIds) = 0 then
    Confirm('No vehicle PIDs are selected. Test every PID in the list?', Run)
  else
    Run();
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
  PortName := ComboText(cbPort);
  if PortName = '' then
  begin
    ShowNotice('Choose a port first', True);
    Exit;
  end;
  Baud := StrToIntDef(ComboText(cbBaud), 115200);
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
        Result := CreateSerialPort(PortName, Baud, fcRtsCts);
      end;
  SetStatus(spPort, PortName);
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
    ShowNotice('Tick the PIDs to scan in the PID list', True);
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
    Result := DefaultLogFolder;
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
  Cmd.Text := System.IOUtils.TPath.Combine(LogFolder, 'UVScan_' + FormatDateTime('yyyy-mm-dd_hhnnss', Now) + '.csv');
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
begin
  if FClosing then
    Exit;
  if TPidDiscoveryForm.Current <> nil then
    TPidDiscoveryForm.Current.HandleEngineEvent(Ev);
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
        SetStatus(spState, StateNames[FState]);
        if FState <> esScanning then
        begin
          grdLive.Refresh;
          RefreshDashboard;
        end;
        if (FState = esConnected) and FAutoScan then
        begin
          FAutoScan := False;
          btnStartScanClick(nil);
        end;
        if FState = esDisconnected then
        begin
          FAutoScan := False;
          FAutoLog := False;
          FControlActive.Clear; // the engine released everything
          FillControls('');
          FLogging := False;
          SetStatus(spRate, '');
        end;
        UpdateControls;
      end;
    eeVehicleInfo:
      begin
        lblFirmware.Text := IfThen(Ev.Vehicle.Firmware = '', '-', Ev.Vehicle.Firmware);
        lblVin.Text := IfThen(Ev.Vehicle.Vin = '', '-', Ev.Vehicle.Vin);
        lblOsid.Text := IfThen(Ev.Vehicle.Osid = '', '-', Ev.Vehicle.Osid);
        SetStatus(spVin, 'VIN ' + lblVin.Text);
        SetStatus(spOsid, 'OSID ' + lblOsid.Text);
      end;
    eeScanStarted:
      begin
        if FTestMode then
          StopTest;
        SetupLiveRows(Ev.PidIds);
        if FAutoLog then
        begin
          FAutoLog := False;
          btnLogClick(nil);
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
        FDtcRows := nil;
        for D in Ev.Dtcs do
          FDtcRows := FDtcRows + [TArray<string>.Create(D.Code, ModuleName(D.Module), FDtcs.Describe(D.Code),
            '$' + IntToHex(D.Status, 2))];
        if Length(Ev.Dtcs) = 0 then
          FDtcRows := [TArray<string>.Create('None', '', 'No trouble codes reported', '')];
        grdDtcs.RowCount := Length(FDtcRows);
        grdDtcs.Refresh;
        ShowPage(tiVehicle);
      end;
    eeLogStarted:
      begin
        FLastLogFile := Ev.Text;
        FLogging := True;
        FLogPaused := False;
        SetStatus(spLog, 'Logging to ' + ExtractFileName(Ev.Text));
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
        SetStatus(spLog, '');
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
  btnStartScan.Text := IfThen(FState = esScanning, 'Restart scan', 'Start scan');
  btnStopScan.Enabled := FState in [esScanning, esBusy];
  btnStopScan.Text := IfThen(FState = esBusy, 'Cancel', 'Stop scan');
  btnLog.Enabled := FState = esScanning;
  btnLog.Text := IfThen(FLogging, 'Stop log', 'Start log') + IfThen(IsMobile, '', ' (F8)');
  btnPause.Enabled := FLogging;
  btnPause.Text := IfThen(FLogPaused, 'Resume', 'Pause') + IfThen(IsMobile, '', ' (F9)');
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
  btnLiveTest.Text := IfThen(FTestMode, 'Stop test', 'Test display');
  btnDashTest.Enabled := btnLiveTest.Enabled;
  btnDashTest.Text := btnLiveTest.Text;
  if FChromeReady then
    TThread.ForceQueue(nil, FitFlowHeights);
  // Status dot: grey idle, blue connected, green scanning, red recording, amber paused.
  if FLogging and FLogPaused then
    shpStatus.Fill.Color := $FFFFA000
  else if FLogging then
    shpStatus.Fill.Color := $FFE53935
  else if FState = esScanning then
    shpStatus.Fill.Color := $FF2EAD4B
  else if FState in [esConnected, esBusy] then
    shpStatus.Fill.Color := $FF2D7FF9
  else
    shpStatus.Fill.Color := $FF9E9E9E;
  // The top bar's main action follows the connection.
  case FState of
    esDisconnected:
      begin
        btnAction.Text := 'Connect';
        btnAction.Enabled := cbPort.ItemIndex >= 0;
      end;
    esConnected:
      begin
        btnAction.Text := 'Start scan';
        btnAction.Enabled := True;
      end;
    esScanning:
      begin
        btnAction.Text := 'Stop';
        btnAction.Enabled := True;
      end;
  else
    btnAction.Text := 'Cancel';
    btnAction.Enabled := True;
  end;
end;

procedure TMainForm.tmrRefreshTimer(Sender: TObject);
var
  I: Integer;
  V: Double;
  Phase, Repaint: Boolean;
begin
  FlushMessages;
  if not LiveActive then
    Exit;
  Repaint := False;
  Phase := FlashPhase;
  if Phase <> FFlashOn then
  begin
    FFlashOn := Phase;
    for I := 0 to High(FRowStyles) do
      if FRowStyles[I].Flash then
        Repaint := True;
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
    SetStatus(spRate, 'Test data')
  else
    SetStatus(spRate, Format('%.1f updates/s', [FLive.CyclesPerSecond]));
  if FLive.Logging then
    SetStatus(spLog, Format('Logging: %d rows%s', [FLive.LogRows, IfThen(FLive.LogPaused, ' (paused)', '')]));
  if FLive.Cycles <> FShownCycles then
  begin
    FShownCycles := FLive.Cycles;
    UpdateAlerts;
    RefreshLiveRows;
  end
  else if Repaint then
    grdLive.Refresh;
  RefreshDashboard;
end;

{ Live rows for a scan (or a display test): one row per PID, fresh min/max and alert state. }
procedure TMainForm.SetupLiveRows(const Ids: TArray<Integer>);
begin
  FLiveIds := Ids;
  FLive := Default(TLiveSnapshot);
  SetLength(FMin, Length(FLiveIds));
  SetLength(FMax, Length(FLiveIds));
  btnResetMinMaxClick(nil);
  grdLive.RowCount := Length(FLiveIds);
  FShownRows := nil;
  FShownCycles := -1;
  FRowStyles := nil;
  FAlerts.Reset;
  ApplyRowHeights;
  RefreshDashboard;
  lblLiveHint.Visible := False;
  if CurrentPage <> tiDashboard then
    ShowPage(tiLive);
  grdLive.Refresh;
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
    FTestStart := TThread.GetTickCount64;
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
  SetStatus(spRate, '');
  AddMessage('Test display stopped');
  grdLive.Refresh;
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
  T := (TThread.GetTickCount64 - FTestStart) / 1000;
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
  Result := (TThread.GetTickCount64 div 400) mod 2 = 0;
end;

{ Works out each live row's display level and plays / announces alerts. }
procedure TMainForm.UpdateAlerts;
var
  I, Id: Integer;
  V: Double;
  S: TResolvedStyle;
  D: TPidDisplay;
  L: TDisplayLevel;
  Change: TAlertChange;
  Sounded: Boolean;
  Now_: UInt64;
begin
  if Length(FRowStyles) <> Length(FLiveIds) then
    SetLength(FRowStyles, Length(FLiveIds));
  Sounded := False;
  Now_ := TThread.GetTickCount64;
  for I := 0 to High(FLiveIds) do
  begin
    Id := FLiveIds[I];
    V := NaN;
    if (I <= High(FLive.Values)) and not FRejected.Contains(Id) then
      V := FLive.Values[I];
    S := FDisplay.Resolve(Id, V);
    FRowStyles[I] := S;
    D := FDisplay.Find(Id);
    if (D = nil) or (S.Level < 0) then
    begin
      FAlerts.Update(Id, -1, False, False, Now_);
      Continue;
    end;
    L := D.Levels[S.Level];
    Change := FAlerts.Update(Id, S.Level, chkSound.IsChecked and (L.Sound <> asNone), L.RepeatSound, Now_);
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

{ Rows of PIDs with a bigger font are taller. }
procedure TMainForm.ApplyRowHeights;
var
  I: Integer;
  D: TPidDisplay;
begin
  grdLive.ResetRowHeights;
  for I := 0 to High(FLiveIds) do
  begin
    D := FDisplay.Find(FLiveIds[I]);
    if (D <> nil) and (D.FontSize > 0) then
      grdLive.RowHeights[I] := Z(D.FontSize * PtToDip + 12);
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

function TMainForm.Z(N: Single): Single;
begin
  Result := N * FZoom / 100;
end;

procedure TMainForm.SetZoom(Percent: Integer);
begin
  FZoom := EnsureRange(Percent, ZoomSteps[0], ZoomSteps[High(ZoomSteps)]);
  lblZoom.Text := IntToStr(FZoom) + '%';
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

{ Column widths, row heights and fonts follow the zoom. }
procedure TMainForm.ApplyGridLayout;
begin
  if grdLive = nil then
    Exit; // the form is still loading
  grdLive.SetColumnVisible(ColMin, chkMinMax.IsChecked);
  grdLive.SetColumnVisible(ColMax, chkMinMax.IsChecked);
  grdLive.RowHeight := Z(30);
  grdLive.HeaderHeight := Z(26);
  grdLive.FontSize := Z(13);
  grdLive.CellPadding := Z(6);
  if IsMobile then
  begin
    grdLive.SetColumnWidth(ColName, Z(120));
    grdLive.SetColumnWidth(ColValue, Z(96));
    grdLive.SetColumnWidth(ColUnits, Z(52));
    grdLive.SetColumnWidth(ColMin, Z(64));
    grdLive.SetColumnWidth(ColMax, Z(64));
  end
  else
  begin
    grdLive.SetColumnWidth(ColName, Z(160));
    grdLive.SetColumnWidth(ColValue, Z(140));
    grdLive.SetColumnWidth(ColUnits, Z(80));
    grdLive.SetColumnWidth(ColMin, Z(100));
    grdLive.SetColumnWidth(ColMax, Z(100));
  end;
  ApplyRowHeights;
  FShownRows := nil;
  grdLive.Refresh;
end;

procedure TMainForm.chkMinMaxChange(Sender: TObject);
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
procedure TMainForm.LiveMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  if ssCtrl in Shift then
  begin
    ZoomStep(Sign(WheelDelta));
    Handled := True;
  end;
end;

{ Repaints the grid when any value / min / max text changed. }
procedure TMainForm.RefreshLiveRows;
var
  I: Integer;
  P: TPidDef;
  Shown: string;
  Changed: Boolean;
begin
  if Length(FShownRows) <> Length(FLiveIds) then
    SetLength(FShownRows, Length(FLiveIds));
  Changed := False;
  for I := 0 to High(FLiveIds) do
  begin
    P := FCatalog.FindById(FLiveIds[I]);
    if (P = nil) or (I > High(FLive.Text)) then
      Continue;
    Shown := FLive.Text[I] + #1 + P.FormatValue(FMin[I]) + #1 + P.FormatValue(FMax[I]) + #1 +
      IntToStr(FRowStyles[I].Level);
    if Shown <> FShownRows[I] then
    begin
      FShownRows[I] := Shown;
      Changed := True;
    end;
  end;
  if Changed or (Length(FRowStyles) > 0) then
    grdLive.Refresh;
end;

procedure TMainForm.LiveGetText(Sender: TObject; Col, Row: Integer; var Text: string);
var
  P: TPidDef;
begin
  if Row > High(FLiveIds) then
    Exit;
  P := FCatalog.FindById(FLiveIds[Row]);
  if P = nil then
    Exit;
  case Col of
    ColName: Text := P.LongName;
    ColValue:
      if FRejected.Contains(P.Id) then
        Text := 'rejected'
      else if Row <= High(FLive.Text) then
        Text := FLive.Text[Row];
    ColUnits: Text := P.Units;
    ColMin: if Row <= High(FMin) then Text := P.FormatValue(FMin[Row]);
    ColMax: if Row <= High(FMax) then Text := P.FormatValue(FMax[Row]);
  end;
end;

procedure TMainForm.LiveGetStyle(Sender: TObject; Col, Row: Integer; var Style: TCellStyle);
var
  P: TPidDef;
  V: Double;
  S: TResolvedStyle;
  RowColor, TextColor: TAlphaColor;
begin
  if Row > High(FLiveIds) then
    Exit;
  P := FCatalog.FindById(FLiveIds[Row]);
  if P = nil then
    Exit;
  V := NaN;
  if (Row <= High(FLive.Values)) and not FRejected.Contains(P.Id) then
    V := FLive.Values[Row];
  S := FDisplay.Resolve(P.Id, V);
  // Rows only flash while scanning; otherwise they keep the level's colours.
  S.Colors(FFlashOn or not LiveActive, RowColor, TextColor);
  Style.Back := RowColor;
  Style.Fore := TextColor;
  case Col of
    ColValue:
      if FRejected.Contains(P.Id) then
        Style.Fore := $FF808080
      else
      begin
        Style.Bold := True;
        if S.FontSize > 0 then
          Style.FontSize := Z(S.FontSize * PtToDip)
        else
          Style.FontSize := Z(14 * PtToDip);
      end;
    ColMin, ColMax:
      if TextColor = NoColor then
        Style.Fore := $FF808080;
  end;
end;

procedure TMainForm.LiveDblClick(Sender: TObject; Row: Integer);
begin
  if Row <= High(FLiveIds) then
    EditDisplay(FLiveIds[Row]);
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
  grdLive.Refresh;
end;

{ Grid menus (right-click on a PC, long-press on a phone) }

procedure TMainForm.PreparePidMenu(PidId: Integer);
var
  Name: string;
begin
  FMenuPidId := PidId;
  miPidDisplay.Enabled := FMenuPidId >= 0;
  miPidGauge.Enabled := FMenuPidId >= 0;
  if FMenuPidId >= 0 then
    Name := ' for ' + StringReplace(PidName(FMenuPidId), '&', '&&', [rfReplaceAll])
  else
    Name := '';
  miPidDisplay.Text := 'Display && alerts' + Name + '...';
end;

function GridPidAt(Form: TMainForm; Grid: TDataGrid; Row: Integer): Integer;
begin
  Result := -1;
  if Row < 0 then
    Exit;
  if (Grid = Form.grdLive) and (Row <= High(Form.FLiveIds)) then
    Result := Form.FLiveIds[Row]
  else if (Grid = Form.grdPids) and (Row <= High(Form.FPidRows)) and (Form.FPidRows[Row] >= 0) then
    Result := Form.FPidRows[Row];
end;

procedure TMainForm.GridMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Button = TMouseButton.mbRight then
    PreparePidMenu(GridPidAt(Self, TDataGrid(Sender), TDataGrid(Sender).RowAt(Y)));
end;

procedure TMainForm.GridGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
var
  Grid: TDataGrid;
  Local, Scr: TPointF;
  Row: Integer;
begin
  if EventInfo.GestureID <> igiLongTap then
    Exit;
  Grid := TDataGrid(Sender);
  Local := Grid.AbsoluteToLocal(EventInfo.Location);
  Row := Grid.RowAt(Local.Y);
  if Row < 0 then
    Exit;
  Grid.ItemIndex := Row;
  PreparePidMenu(GridPidAt(Self, Grid, Row));
  if FMenuPidId < 0 then
    Exit;
  Scr := Grid.LocalToScreen(Local);
  ShowMenuAsActions(Self, pmPid, ScreenToClient(Scr)); // long-press: phones
  Handled := True;
end;

procedure TMainForm.miPidDisplayClick(Sender: TObject);
begin
  EditDisplay(FMenuPidId);
end;

procedure TMainForm.miPidGaugeClick(Sender: TObject);
begin
  AddGauge(FMenuPidId);
end;

{ Vehicle / tools }

procedure TMainForm.btnReadInfoClick(Sender: TObject);
begin
  Post(ecReadVehicleInfo);
end;

procedure TMainForm.btnReadDtcsClick(Sender: TObject);
begin
  FDtcRows := nil;
  grdDtcs.RowCount := 0;
  Post(ecReadDtcs);
end;

procedure TMainForm.btnClearDtcsClick(Sender: TObject);
begin
  Confirm('Clear trouble codes in the PCM?',
    procedure
    begin
      Post(ecClearDtcs);
    end);
end;

procedure TMainForm.DtcsGetText(Sender: TObject; Col, Row: Integer; var Text: string);
begin
  if (Row <= High(FDtcRows)) and (Col <= High(FDtcRows[Row])) then
    Text := FDtcRows[Row][Col];
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
      ShowWarning('Could not save the real-time controls: ' + E.Message);
  end;
end;

function GroupOf(C: TControlDef): string;
begin
  Result := IfThen(C.Group = '', 'Other', C.Group);
end;

procedure TMainForm.FillControls(const Select: string);
var
  I, J: Integer;
  Groups: TStringList;
  Keep: string;
begin
  Keep := Select;
  if (Keep = '') and (SelectedControl <> nil) then
    Keep := SelectedControl.Name;
  FCtlRows := nil;
  FCtlGroups := nil;
  Groups := TStringList.Create;
  try
    // Groups in order of first appearance, controls under their group.
    for I := 0 to FControls.Count - 1 do
      if Groups.IndexOf(GroupOf(FControls[I])) < 0 then
        Groups.Add(GroupOf(FControls[I]));
    for J := 0 to Groups.Count - 1 do
    begin
      FCtlRows := FCtlRows + [nil];
      FCtlGroups := FCtlGroups + [Groups[J]];
      for I := 0 to FControls.Count - 1 do
        if GroupOf(FControls[I]) = Groups[J] then
        begin
          FCtlRows := FCtlRows + [FControls[I]];
          FCtlGroups := FCtlGroups + [''];
        end;
    end;
  finally
    Groups.Free;
  end;
  grdControls.OnSelect := nil;
  try
    grdControls.RowCount := Length(FCtlRows);
    grdControls.ItemIndex := -1;
    for I := 0 to High(FCtlRows) do
      if (FCtlRows[I] <> nil) and SameText(FCtlRows[I].Name, Keep) then
        grdControls.ItemIndex := I;
  finally
    grdControls.OnSelect := ControlsSelect;
  end;
  grdControls.Refresh;
  UpdateControlPanel;
end;

procedure TMainForm.ControlsIsGroup(Sender: TObject; Row: Integer; var IsGroup: Boolean);
begin
  IsGroup := (Row <= High(FCtlRows)) and (FCtlRows[Row] = nil);
end;

procedure TMainForm.ControlsGetText(Sender: TObject; Col, Row: Integer; var Text: string);
var
  C: TControlDef;
  Res: string;
begin
  if Row > High(FCtlRows) then
    Exit;
  C := FCtlRows[Row];
  if C = nil then
  begin
    if Col = 0 then
      Text := FCtlGroups[Row];
    Exit;
  end;
  case Col of
    0: Text := C.Name;
    1: Text := ControlKindCaptions[C.Kind];
    2: Text := ModuleName(C.Module) + ': ' + C.OnText;
    3:
      begin
        if C.Problem <> '' then
          Res := 'Needs fixing: ' + C.Problem
        else if not FControlResult.TryGetValue(C.Name, Res) then
          Res := '';
        if ControlActive(C) then
          Res := 'ACTIVE  ' + Res;
        Text := Res;
      end;
  end;
end;

procedure TMainForm.ControlsGetStyle(Sender: TObject; Col, Row: Integer; var Style: TCellStyle);
var
  C: TControlDef;
begin
  if Row > High(FCtlRows) then
    Exit;
  C := FCtlRows[Row];
  if C = nil then
    Exit;
  if ControlActive(C) then
  begin
    Style.Back := $FFFFE680; // amber: something is being controlled
    Style.Bold := True;
  end
  else if C.Problem <> '' then
    Style.Fore := $FF808080;
end;

procedure TMainForm.ControlsSelect(Sender: TObject);
begin
  UpdateControlPanel;
end;

procedure TMainForm.ControlsDblClick(Sender: TObject; Row: Integer);
begin
  btnCtlEditClick(nil);
end;

function TMainForm.SelectedControl: TControlDef;
var
  Row: Integer;
begin
  Result := nil;
  if (grdControls = nil) or (FControls = nil) then
    Exit;
  Row := grdControls.ItemIndex;
  if (Row >= 0) and (Row <= High(FCtlRows)) and (FCtlRows[Row] <> nil) and
    (FControls.IndexOfName(FCtlRows[Row].Name) >= 0) then
    Result := FCtlRows[Row];
end;

function TMainForm.ControlActive(C: TControlDef): Boolean;
begin
  Result := (C <> nil) and FControlActive.ContainsKey(C.Name) and FControlActive[C.Name];
end;

function TMainForm.ControlsUsable: Boolean;
begin
  Result := FState in [esConnected, esScanning];
end;

{ Shows the buttons that fit the selected control's kind. }
procedure TMainForm.UpdateControlPanel;
var
  C: TControlDef;
  Ok: Boolean;
  B: TButton;
begin
  if (FControls = nil) or (grdControls = nil) then
    Exit;
  C := SelectedControl;
  Ok := (C <> nil) and (C.Problem = '') and ControlsUsable;
  btnCtlSend.Visible := (C <> nil) and (C.Kind = ckAction);
  btnCtlOn.Visible := (C <> nil) and (C.Kind = ckToggle);
  btnCtlHold.Visible := (C <> nil) and (C.Kind = ckHold);
  tbCtlValue.Visible := (C <> nil) and (C.Kind = ckValue);
  edtCtlValue.Visible := tbCtlValue.Visible;
  lblCtlUnits.Visible := tbCtlValue.Visible;
  btnCtlApply.Visible := tbCtlValue.Visible;
  btnCtlOff.Visible := (C <> nil) and (C.Kind in [ckToggle, ckValue]);
  btnCtlOff.Text := IfThen((C <> nil) and (C.Kind = ckValue), 'Release', 'Off');
  for B in TArray<TButton>.Create(btnCtlSend, btnCtlOn, btnCtlHold, btnCtlApply, btnCtlOff) do
    B.Enabled := Ok;
  tbCtlValue.Enabled := Ok;
  btnCtlEdit.Enabled := C <> nil;
  btnCtlDup.Enabled := C <> nil;
  btnCtlDelete.Enabled := C <> nil;
  btnReleaseAll.Enabled := ControlsUsable;
  TThread.ForceQueue(nil, FitFlowHeights);
  if C = nil then
  begin
    lblCtlName.Text := IfThen(FControls.Count = 0, 'No controls yet - press Add', 'Select a control');
    lblCtlNotes.Text := '';
    Exit;
  end;
  lblCtlName.Text := C.Name + IfThen(ControlActive(C), '   (active)', '');
  if C.Problem <> '' then
    lblCtlNotes.Text := 'Needs fixing: ' + C.Problem
  else if not ControlsUsable then
    lblCtlNotes.Text := 'Connect first. ' + C.Notes
  else
    lblCtlNotes.Text := C.Notes;
  if C.Kind = ckValue then
  begin
    lblCtlUnits.Text := C.Units;
    if FValueControl <> C then
    begin
      FValueControl := C;
      tbCtlValue.OnChange := nil;
      tbCtlValue.Min := 0;
      tbCtlValue.Max := Max(1, Round((C.MaxValue - C.MinValue) / C.Step));
      tbCtlValue.Frequency := 1;
      tbCtlValue.Value := 0;
      tbCtlValue.OnChange := tbCtlValueChange;
      tbCtlValueChange(nil);
    end;
  end;
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
  if C = nil then
    Exit;
  if C.Confirm <> '' then
    Confirm(C.Confirm,
      procedure
      begin
        SendControl(C, True);
      end)
  else
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

{ "Hold to run": on while the button is pressed. A control with a question
  asks it once (per session) on the first press; then press and hold. }
procedure TMainForm.btnCtlHoldMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  C: TControlDef;
begin
  C := SelectedControl;
  if (Button <> TMouseButton.mbLeft) or (C = nil) or not btnCtlHold.Enabled then
    Exit;
  if (C.Confirm <> '') and not FConfirmed.ContainsKey(C.Name) then
  begin
    Confirm(C.Confirm,
      procedure
      begin
        FConfirmed.AddOrSetValue(C.Name, True);
        ShowNotice('Now press and hold "Hold to run"', False);
      end);
    Exit;
  end;
  FHolding := True;
  btnCtlHold.Text := 'Running - let go to stop';
  SendControl(C, True);
end;

procedure TMainForm.StopHolding;
begin
  if not FHolding then
    Exit;
  FHolding := False;
  btnCtlHold.Text := 'Hold to run';
  SendControl(SelectedControl, False);
end;

procedure TMainForm.btnCtlHoldMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  StopHolding;
end;

procedure TMainForm.btnCtlHoldMouseLeave(Sender: TObject);
begin
  StopHolding;
end;

procedure TMainForm.tbCtlValueChange(Sender: TObject);
var
  C: TControlDef;
begin
  C := SelectedControl;
  if (C = nil) or (C.Kind <> ckValue) then
    Exit;
  edtCtlValue.Text := FormatFloat('0.###', C.MinValue + Round(tbCtlValue.Value) * C.Step);
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
  if (C.Confirm <> '') and not ControlActive(C) then
    Confirm(C.Confirm,
      procedure
      begin
        SendControl(C, True, V);
      end)
  else
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
  if ControlActive(C) then
  begin
    ShowNotice('Release "' + C.Name + '" before changing it', True);
    Exit;
  end;
  Work := TControlDef.Create;
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
  Groups := TStringList.Create;
  try
    Groups.Sorted := True;
    Groups.Duplicates := dupIgnore;
    for I := 0 to FControls.Count - 1 do
      if FControls[I].Group <> '' then
        Groups.Add(FControls[I].Group);
    TControlEditorForm.Execute(Work, Groups, FControls, Original,
      procedure(Ok: Boolean)
      begin
        if not Ok then
        begin
          Work.Free;
          Exit;
        end;
        if IsNew then
        begin
          FControls.Add(Work);
          FillControls(Work.Name);
        end
        else
        begin
          C.Assign(Work);
          Work.Free;
          FillControls(C.Name);
        end;
        SaveControls;
      end);
  finally
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
  if ControlActive(C) then
  begin
    ShowNotice('Release "' + C.Name + '" before deleting it', True);
    Exit;
  end;
  Confirm(Format('Delete the control "%s"?', [C.Name]),
    procedure
    begin
      FControls.Delete(FControls.IndexOfName(C.Name));
      if FValueControl = C then
        FValueControl := nil;
      SaveControls;
      FillControls('');
    end);
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
  Vin: string;
begin
  Vin := UpperCase(Trim(edtNewVin.Text));
  if not IsValidVin(Vin) then
  begin
    ShowNotice('A VIN is 17 characters, A-Z and 0-9', True);
    Exit;
  end;
  Confirm(Format('Write VIN %s to the PCM?', [Vin]),
    procedure
    var
      Cmd: TEngineCommand;
    begin
      Cmd := Command(ecWriteVin);
      Cmd.Text := Vin;
      Post(Cmd);
    end);
end;

procedure TMainForm.btnBrowseLogFolderClick(Sender: TObject);
{$IFDEF MSWINDOWS}
var
  Dir: string;
begin
  Dir := LogFolder;
  if SelectDirectory('Log folder', '', Dir) then
    edtLogFolder.Text := Dir;
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure TMainForm.btnSendRawClick(Sender: TObject);
var
  Cmd: TEngineCommand;
begin
  Cmd := Command(ecSendRaw);
  Cmd.Text := edtRaw.Text;
  Post(Cmd);
  ShowPage(tiMessages);
end;

procedure TMainForm.chkTraceChange(Sender: TObject);
begin
  if FEngine <> nil then
    FEngine.SetTrace(chkTrace.IsChecked);
end;

procedure TMainForm.cbRateChange(Sender: TObject);
begin
  if (FEngine <> nil) and (cbRate.ItemIndex >= 0) then
    FEngine.StreamSpeed := StreamSpeedNibble(TStreamSpeed(cbRate.ItemIndex)); // applies from the next scan start
end;

{ Messages }

{ Messages are queued and shown in one go by the refresh timer (thousands
  per minute with traffic tracing on). The list is virtual: only the lines
  on screen are drawn. }
procedure TMainForm.AddMessage(const Text: string);
begin
  FPendingLog.Add(FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + Text);
  {$IFDEF ANDROID}
  // Also to the system log (adb logcat), where the messages can be read off the phone.
  Log.d('UVScan: ' + Text.Replace('%', '%%'));
  {$ENDIF}
  if FPendingLog.Count > MaxMessageLines then
    FPendingLog.Delete(0);
end;

procedure TMainForm.FlushMessages;
var
  AtEnd: Boolean;
  Cut: Integer;
begin
  if (FPendingLog.Count = 0) or (grdMessages = nil) then
    Exit;
  AtEnd := (FMessages.Count = 0) or (grdMessages.TopRow + grdMessages.VisibleRows >= FMessages.Count - 1);
  FMessages.AddStrings(FPendingLog);
  FPendingLog.Clear;
  if FMessages.Count > MaxMessageLines + 500 then
  begin
    Cut := FMessages.Count - MaxMessageLines;
    FMessages.BeginUpdate;
    try
      while Cut > 0 do
      begin
        FMessages.Delete(0);
        Dec(Cut);
      end;
    finally
      FMessages.EndUpdate;
    end;
  end;
  grdMessages.RowCount := FMessages.Count;
  if AtEnd then
    grdMessages.ScrollIntoView(FMessages.Count - 1);
  grdMessages.Refresh;
end;

procedure TMainForm.MessagesGetText(Sender: TObject; Col, Row: Integer; var Text: string);
begin
  if Row < FMessages.Count then
    Text := FMessages[Row];
end;

procedure TMainForm.btnClearMessagesClick(Sender: TObject);
begin
  FPendingLog.Clear;
  FMessages.Clear;
  grdMessages.RowCount := 0;
  grdMessages.Refresh;
end;

procedure TMainForm.btnCopyMessagesClick(Sender: TObject);
var
  Clip: IFMXClipboardService;
begin
  FlushMessages;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clip) then
    Clip.SetClipboard(FMessages.Text);
end;

procedure TMainForm.ShowNotice(const Text: string; IsError: Boolean);
begin
  lblNotice.Text := Text + IfThen(IsMobile, '   (tap to dismiss)', '   (click to dismiss)');
  if IsError then
    pnlNotice.Fill.Color := Palette.NoticeError
  else
    pnlNotice.Fill.Color := Palette.NoticeWarn;
  pnlNotice.Tag := Ord(IsError);
  pnlNotice.Visible := True;
end;

procedure TMainForm.pnlNoticeClick(Sender: TObject);
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
      ShowWarning('Could not save the display settings: ' + E.Message);
  end;
end;

{ After display.json changed: save, repaint the grid, rebuild the gauges. }
procedure TMainForm.DisplayChanged;
begin
  SaveDisplay;
  FShownRows := nil;
  FRowStyles := nil;
  ApplyRowHeights;
  grdLive.Refresh;
  BuildDashboard;
end;

procedure TMainForm.EditDisplay(PidId: Integer);
var
  P: TPidDef;
begin
  P := FCatalog.FindById(PidId);
  if P = nil then
    Exit;
  TDisplayEditorForm.Execute(P, FDisplay,
    procedure(Ok: Boolean)
    begin
      if Ok then
        DisplayChanged;
    end);
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

procedure TMainForm.chkSoundChange(Sender: TObject);
begin
  if not chkSound.IsChecked then
    StopAlertSound;
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
  for View in FGaugeViews do
    View.Free;
  FGaugeViews.Clear;
  sbDash.BeginUpdate;
  try
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
      View.OnMouseDown := GaugeMouseDown;
      View.OnDblClick := GaugeDblClick;
      View.Touch.InteractiveGestures := [TInteractiveGesture.LongTap];
      View.OnGesture := GaugeGesture;
      View.Setup(G.Style, G.Size, Title, Units, G.MinValue, G.MaxValue,
        FDisplay.Zones(G.PidId, G.MinValue, G.MaxValue));
      FGaugeViews.Add(View);
    end;
  finally
    sbDash.EndUpdate;
  end;
  if FGaugeViews.Count = 0 then
    lblDashHint.Text := IfThen(IsMobile, 'No gauges yet: press Add gauge, or long-press a PID.',
      'No gauges yet: press Add gauge, or right-click a PID and choose Add to dashboard.')
  else
    lblDashHint.Text := IfThen(IsMobile, 'Long-press a gauge to change, move or remove it. Double-tap to edit.',
      'Right-click a gauge to change, move or remove it. Double-click to edit.');
  LayoutDashboard;
  RefreshDashboard;
end;

{ Left to right, wrapping to the width of the dashboard. }
procedure TMainForm.LayoutDashboard;
var
  View: TGaugeView;
  I: Integer;
  X, Y, RowH, Avail: Single;
  Sz: TSizeF;
const
  Gap = 12;
begin
  if (FGaugeViews = nil) or (FGaugeViews.Count = 0) then
    Exit;
  Avail := sbDash.Width - 16;
  X := Gap;
  Y := Gap;
  RowH := 0;
  for I := 0 to FGaugeViews.Count - 1 do
  begin
    View := FGaugeViews[I];
    Sz := TGaugeView.PreferredSize(FDisplay.Gauges[I].Style, FDisplay.Gauges[I].Size);
    if (X > Gap) and (X + Sz.cx + Gap > Avail) then
    begin
      X := Gap;
      Y := Y + RowH + Gap;
      RowH := 0;
    end;
    View.SetBounds(X, Y, Sz.cx, Sz.cy);
    X := X + Sz.cx + Gap;
    RowH := Max(RowH, Sz.cy);
  end;
end;

procedure TMainForm.sbDashResized(Sender: TObject);
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
  TGaugeEditorForm.Execute(G, FCatalog, FDisplay, 'Add gauge',
    procedure(Ok: Boolean; NewGauge: TGauge)
    begin
      if not Ok then
        Exit;
      FDisplay.Gauges.Add(NewGauge);
      SaveDisplay;
      BuildDashboard;
      ShowPage(tiDashboard);
    end);
end;

procedure TMainForm.EditGauge(Index: Integer);
begin
  if (Index < 0) or (Index >= FDisplay.Gauges.Count) then
    Exit;
  TGaugeEditorForm.Execute(FDisplay.Gauges[Index], FCatalog, FDisplay, 'Edit gauge',
    procedure(Ok: Boolean; NewGauge: TGauge)
    begin
      if not Ok or (Index >= FDisplay.Gauges.Count) then
        Exit;
      FDisplay.Gauges[Index] := NewGauge;
      SaveDisplay;
      BuildDashboard;
    end);
end;

procedure TMainForm.MoveGauge(Delta: Integer);
begin
  if (FMenuGauge < 0) or (FMenuGauge + Delta < 0) or (FMenuGauge + Delta >= FDisplay.Gauges.Count) then
    Exit;
  FDisplay.Gauges.Exchange(FMenuGauge, FMenuGauge + Delta);
  SaveDisplay;
  TThread.ForceQueue(nil, BuildDashboard);
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

procedure TMainForm.PrepareGaugeMenu(Index: Integer);
begin
  FMenuGauge := Index;
  miGaugeEarlier.Enabled := FMenuGauge > 0;
  miGaugeLater.Enabled := (FMenuGauge >= 0) and (FMenuGauge < FDisplay.Gauges.Count - 1);
  miGaugeDisplay.Enabled := (FMenuGauge >= 0) and (FMenuGauge < FDisplay.Gauges.Count) and
    (FCatalog.FindById(FDisplay.Gauges[FMenuGauge].PidId) <> nil);
end;

procedure TMainForm.GaugeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  PrepareGaugeMenu(TGaugeView(Sender).Tag);
end;

procedure TMainForm.GaugeDblClick(Sender: TObject);
begin
  EditGauge(TGaugeView(Sender).Tag);
end;

procedure TMainForm.GaugeGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
var
  Scr: TPointF;
begin
  if EventInfo.GestureID <> igiLongTap then
    Exit;
  PrepareGaugeMenu(TGaugeView(Sender).Tag);
  Scr := TControl(Sender).LocalToScreen(TControl(Sender).AbsoluteToLocal(EventInfo.Location));
  ShowMenuAsActions(Self, pmGauge, ScreenToClient(Scr)); // long-press: phones
  Handled := True;
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

procedure TMainForm.SetStatus(Part: TStatusPart; const Text: string);
var
  P: TStatusPart;
  S: string;
begin
  if FStatus[Part] = Text then
    Exit; // avoid repainting the status strip for nothing
  FStatus[Part] := Text;
  S := '';
  for P := Low(TStatusPart) to High(TStatusPart) do
    if FStatus[P] <> '' then
      S := S + IfThen(S <> '', '  ' + #$00B7 + '  ', '') + FStatus[P];
  lblStatus.Text := S;
end;

end.
