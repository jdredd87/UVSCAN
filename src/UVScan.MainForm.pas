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
  FMX.Platform, System.Messaging, System.Notification,
  UVScan.Serial, UVScan.Simulator, UVScan.Pids, UVScan.Dpid, UVScan.Dtc, UVScan.Engine,
  UVScan.Class2, UVScan.Paths, UVScan.Settings, UVScan.PidLists, UVScan.Defaults,
  UVScan.Display, UVScan.Alerts, UVScan.Controls, UVScan.Gauge, UVScan.UI.DataGrid, UVScan.LogData,
  UVScan.QuickStart;

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
    chkKeepAwake: TCheckBox;
    chkRound: TCheckBox;
    chkLockRotate: TCheckBox;
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
    procedure chkKeepAwakeChange(Sender: TObject);
    procedure chkRoundChange(Sender: TObject);
    procedure chkLockRotateChange(Sender: TObject);
    procedure ToggleLockRotateClick(Sender: TObject);
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
    FLiveIds: TArray<Integer>;       // live rows, top first (the order the user chose)
    FEngineIds: TArray<Integer>;     // the same PIDs in the scan's own order (its snapshots)
    FRowEngine: TArray<Integer>;     // live row -> index in FEngineIds
    FLive: TLiveSnapshot;            // in row order (see DisplaySnapshot)
    FAwaySince: TDateTime;    // phone: when the app left the screen, 0 = on screen
    FSaveDue: UInt64;         // tick count when changed settings are saved, 0 = nothing to save
    FNotes: TNotificationCenter; // phone: the notification while away
    lblAway: TLabel;
    cbAway: TComboBox;
    FLiveLog: TLogData;       // the last minutes of the scan, for the live chart
    FLiveStart: UInt64;
    btnChart: TSpeedButton;
    FMin, FMax: TArray<Double>;
    FLogging: Boolean;
    FLogPaused: Boolean;
    FClosing: Boolean;
    FForceClose: Boolean;
    FAutoScan: Boolean;
    FAutoLog: Boolean;
    edtTcpAddress: TEdit; // the network AVT's host:port (port NetworkPort)
    FSettings: TAppSettings;
    FLists: TPidLists;
    FPendingLog: TStringList;   // message lines waiting for the next timer tick
    FMessages: TStringList;     // what the Messages tab shows
    FShownRows: TArray<string>; // what each live row last showed (value|min|max)
    FGridCompact: Boolean;      // live columns share the width (phone, narrow window)
    FGridQueued: Boolean;
    FFlowQueued: Boolean;
    FPageGridsSet, FPageGridsCompact: Boolean;
    FShownCycles: Int64;
    FDisplay: TDisplaySettings;      // display.json: PID looks, alert levels, gauges
    FAlerts: TAlertTracker;
    FRowStyles: TArray<TResolvedStyle>; // per live row, as last evaluated
    FFlashOn: Boolean;
    FGaugeViews: TList<TGaugeView>;
    FMenuPidId: Integer;             // PID the PID/grid menu is about
    FMenuLiveRow: Integer;           // live row the grid menu is about, -1 from the PID list
    FMoveItems: TArray<TMenuItem>;   // grid menu: move the live row up / down / top / bottom
    FMinimizeItem: TMenuItem;        // gauge menu: Minimize / Restore
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
    FNavButtons: array[0..6] of TRectangle;
    FNavPages: array[0..6] of TTabItem; // nil: the log viewer (a window of its own)
    FMorePages: TArray<TTabItem>;    // lbMore row -> page
    FPageMenu: TPopupMenu;
    FPidsDocked: Boolean;            // wide window: the PID list sits beside the pages
    FWide: Boolean;                  // the window is wide enough for the PID list beside the pages
    FFullScreen: Boolean;            // the dashboard alone on the whole screen
    FQuick: TQuickStart;             // the quick start (or command line) being carried out
    FQuickActive: Boolean;           // ... until the user stops or disconnects
    FQuickDash: string;              // the dashboard it shows (kept when the scan starts)
    FRetryAt: UInt64;                // tick count to try connecting again, 0 = not
    FAutoChart: Boolean;             // open the live chart when the scan starts
    FQuickPicks: TComponent;         // owns the senders of the Quick start menu's items
    FQuickAction: Integer;           // what picking a quick start does: 0 run, 1 edit, 2 delete, 3 shortcut
    btnQuick: TButton;               // Connect page: the Quick start menu
    FWasMaximized: Boolean;          // before full screen
    FWasBounds: TRectF;              // Windows: the window before full screen
    FWasBorder: TFmxFormBorderStyle;
    FWasPadding: TRectF;             // phone: the safe area insets before full screen
    FSafeHold: UInt64;               // phone: ignore inset changes until this tick (see SetFullScreen)
    FExitFull: TCircle;              // full screen: the way back
    FFullState: TRectangle;          // full screen, not scanning: what is going on (no status strip there)
    btnPidPanel: TSpeedButton;       // wide windows: the PID list beside the pages or on its own page
    btnFullScreen: TSpeedButton;     // Gauges: the dashboard on the whole screen
    FRail: Boolean;                  // short window (a phone held sideways): the tabs go down the left side
    FCtlRunHeight: Single;           // the control panel's height under the list, while it is beside it
    FChromeReady: Boolean;
    FThemeSub: TMessageSubscriptionId;
    FAddGauge: TCircle;              // the round + on the Gauges page
    FDashEmpty: TLabel;              // shown when there are no gauges
    FDashSpacer: TLayout;            // keeps the + clear of the last gauge
    FDashBack: TRectangle;           // behind the gauges: the dashboard's colour, and its picture
    FDashBackImg: TImage;            // ... scaled to cover it (clipped by FDashBack)
    FDashBackFile: string;           // the picture loaded into FDashBackImg
    FDashCombo: TComboBox;           // which dashboard (wide windows; the page menu everywhere)
    FDashPicks: TComponent;          // owns the senders of the dashboard chooser's items
    procedure FillDashboards;
    procedure SelectDashboard(Index: Integer);
    procedure DashComboChange(Sender: TObject);
    procedure ChooseDashboardClick(Sender: TObject);
    procedure DashPickClick(Sender: TObject);
    procedure NewDashboardClick(Sender: TObject);
    procedure RenameDashboardClick(Sender: TObject);
    procedure DeleteDashboardClick(Sender: TObject);
    procedure CreateGrids;
    procedure BuildChrome;
    procedure ArrangeLayout;
    procedure FitFlowHeights;
    procedure FlowBoxResized(Sender: TObject);
    procedure FitVehicleColumns;
    procedure FitFormRows;
    procedure FitWrappedText;
    // navigation
    procedure ShowPage(Page: TTabItem);
    function CurrentPage: TTabItem;
    procedure UpdateAppBar;
    procedure PlaceAddGauge;
    procedure CtlWarnClick(Sender: TObject);
    procedure NavClick(Sender: TObject);
    procedure NavPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
    procedure NavResized(Sender: TObject);
    procedure OrderAppBar;
    procedure AppBarResized(Sender: TObject);
    procedure LayoutNav;
    procedure AddPageMenuItem(const Text: string; Handler: TNotifyEvent; Enabled: Boolean = True;
      Checked: Boolean = False);
    procedure ToggleMinMaxClick(Sender: TObject);
    procedure TogglePidPanelClick(Sender: TObject);
    procedure RunQuickStart(const Q: TQuickStart);
    procedure QuickConnect;
    procedure QuickStartClick(Sender: TObject);
    procedure QuickPickClick(Sender: TObject);
    procedure QuickNewClick(Sender: TObject);
    procedure QuickChooseClick(Sender: TObject);
    procedure ShowQuickMenu(Action: Integer);
    procedure EditQuick(Index: Integer);
    procedure FullScreenClick(Sender: TObject);
    procedure SetFullScreen(Value: Boolean);
    procedure PlaceExitFull;
    procedure UpdateFullState;
    procedure GaugeClick(Sender: TObject);
    procedure MinimizeGaugeClick(Sender: TObject);
    procedure FitScreenClick(Sender: TObject);
    procedure ApplyDashBackground;
    procedure PlaceDashBack;
    procedure DashBackgroundClick(Sender: TObject);
    procedure DashBackPickClick(Sender: TObject);
    procedure DashColorPickClick(Sender: TObject);
    procedure SetDashPicture(Bmp: TBitmap);
    procedure DashPictureTaken(Image: TBitmap);
    procedure SafeAreaChanged(Sender: TObject; const AInsets: TRectF);
    function RankLiveIds(const Ids: TArray<Integer>): TArray<Integer>;
    function DisplaySnapshot(const S: TLiveSnapshot): TLiveSnapshot;
    procedure MoveLiveRow(From, ToRow: Integer);
    procedure SaveLiveOrder;
    procedure MoveRowClick(Sender: TObject);
    procedure LiveKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
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
    procedure QueueGridLayout;
    procedure ApplyPageGridColumns;
    function LiveGridCompact: Boolean;
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
    function AddLiveSample(const Time: Double; const Text: TArray<string>): Boolean;
    procedure LiveChartClick(Sender: TObject);
    procedure ShowAwayNote(const Title, Body: string);
    procedure ClearAwayNote;
    procedure StartTest;
    procedure StopTest;
    function TestSnapshot: TLiveSnapshot;
    function LiveActive: Boolean;
    procedure RefreshLiveRows;
    function ReadingText(P: TPidDef; const Value: Double): string;
    function LiveValueText(I: Integer; P: TPidDef): string;
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
    procedure SettingsChanged;
    function AppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
    procedure FillPorts(const Select: string);
    procedure PortChanged(Sender: TObject);
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
  UVScan.PidDiscovery, UVScan.DisplayEditor, UVScan.GaugeEditor, UVScan.ControlEditor, UVScan.LogViewer,
  UVScan.QuickStartEditor, System.DateUtils, System.Permissions;

const
  AwayNote = 'uvscan_away';       // the notification's name
  AwayChannel = 'uvscan_running'; // its channel (Android 8+)

const
  SimulatorPort = 'Simulator';
  NetworkPort = 'Network (TCP/IP)'; // an AVT with an Ethernet port, at the address in edtTcpAddress
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
  FLiveLog := TLogData.Create;
  TLogViewerForm.SetLiveSource(FLiveLog);
  if IsMobile then
  begin
    FNotes := TNotificationCenter.Create(Self);
    var Channel := FNotes.CreateChannel(AwayChannel, 'Scanning while away',
      'Shown when you leave UVScan while it is connected, scanning or logging');
    try
      Channel.Importance := TImportance.High; // shows as a banner
      FNotes.CreateOrUpdateChannel(Channel);
    finally
      Channel.Free;
    end;
  end;
  FMenuPidId := -1;
  FMenuGauge := -1;
  Caption := 'UVScan';
  lblVin.TextSettings.Font.Style := [TFontStyle.fsBold];
  lblOsid.TextSettings.Font.Style := [TFontStyle.fsBold];
  lblFirmware.TextSettings.Font.Style := [TFontStyle.fsBold];
  if IsMobile then // their fixed size suits Windows; a phone's style text is bigger
    for var L in [lblVin, lblOsid, lblFirmware] do
      L.StyledSettings := L.StyledSettings + [TStyledSetting.Size];
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
  // A box of wrapping buttons fits its rows again whenever its width changes
  // (also when a page hidden during a resize is shown and laid out).
  // The same for wrapped text (a page hidden while the phone turned is laid out later).
  for var C in TArray<TControl>.Create(gbAdapter, gbScan, gbLogRec, pnlLiveFooter, pnlDashBar, pnlCtlBar,
    pnlPidFooter, pnlCtlRun, pnlCtlWarn, pnlNotice, gbDiscover) do
    C.OnResized := FlowBoxResized;
  ArrangeLayout;
  UpdateControls;
  ShowPage(tiLive);
  // Android ends an app without closing its form (swiped away, or killed in
  // the background), so save whenever the app leaves the screen.
  if TPlatformServices.Current.SupportsPlatformService(IFMXApplicationEventService, Events) then
    Events.SetApplicationEventHandler(AppEvent);
  HookBackGesture; // Android 16 no longer sends the back key
  ApplyCommandLine;
  TThread.ForceQueue(nil, FitFlowHeights);
end;

function TMainForm.AppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
var
  Cmd: TEngineCommand;
  Secs: Int64;
  Wait: string;
begin
  Result := False;
  if (AAppEvent in [TApplicationEvent.EnteredBackground, TApplicationEvent.WillTerminate]) and not FClosing then
    SaveSettings;
  if FClosing or not IsMobile then
    Exit;
  // Away from the screen: the engine stops the log, the scan and the
  // connection after a while (Settings > Logging); back sooner, it carries on.
  if (AAppEvent = TApplicationEvent.EnteredBackground) and (FAwaySince = 0) then
  begin
    FAwaySince := Now;
    if FState <> esDisconnected then
    begin
      Cmd := Command(ecBackground);
      Cmd.Seconds := FSettings.BackgroundStop;
      FEngine.Post(Cmd); // not Post: that hides the notice, as for a button press
      // A notification says it is still running, and for how long.
      if FSettings.BackgroundStop < 60 then
        Wait := Format('%d seconds', [FSettings.BackgroundStop])
      else
        Wait := Format('%d minute%s', [FSettings.BackgroundStop div 60, IfThen(FSettings.BackgroundStop >= 120, 's', '')]);
      if FLogging then
        ShowAwayNote('UVScan is logging', Format('Tap to go back. After %s away the log is closed and the ' +
          'adapter disconnected.', [Wait]))
      else if FState = esScanning then
        ShowAwayNote('UVScan is scanning', Format('Tap to go back. After %s away the scan stops and the ' +
          'adapter is disconnected.', [Wait]))
      else
        ShowAwayNote('UVScan is connected', Format('Tap to go back. After %s away the adapter is disconnected.',
          [Wait]));
    end;
  end
  else if (AAppEvent in [TApplicationEvent.WillBecomeForeground, TApplicationEvent.BecameActive]) and
    (FAwaySince <> 0) then
  begin
    // Wall-clock time: a frozen app's own clocks may not have counted it all.
    Secs := SecondsBetween(Now, FAwaySince);
    FAwaySince := 0;
    ClearAwayNote; // the notice in the app says the rest
    if FSettings.PendingNotice <> '' then
    begin
      FSettings.PendingNotice := ''; // still running: the notice is on screen now
      SaveSettings;
    end;
    Cmd := Command(ecForeground);
    Cmd.Seconds := Secs;
    Cmd.Flag := Secs >= FSettings.BackgroundStop;
    FEngine.Post(Cmd); // keeps the notice of a stop made while away
  end;
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
  grdPids.SetColumnShrink(1, True); // "Bitmapped" smaller rather than cut
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
  grdLive.OnKeyDown := LiveKeyDown;
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

  // Long names wrap rather than being cut (rows as tall as they need).
  grdPids.SetColumnWrap(0, True);
  grdPids.SetColumnWrap(1, True);
  grdPids.AutoHeights := True;
  for var I in [0, 1, 3] do
    grdControls.SetColumnWrap(I, True);
  grdControls.AutoHeights := True;
  for var I in [1, 2, 3] do
    grdDtcs.SetColumnWrap(I, True);
  grdDtcs.AutoHeights := True;
  ApplyPageGridColumns;
end;

{ Messages, controls and trouble codes: on a phone or a narrow window fewer,
  narrower columns (and the messages wrap); the usual columns otherwise.
  Redone when the window crosses the width. }
procedure TMainForm.ApplyPageGridColumns;
var
  Compact: Boolean;
  G: TDataGrid;
begin
  Compact := InnerWidth(Self) < 700;
  if FPageGridsSet and (Compact = FPageGridsCompact) then
    Exit;
  FPageGridsSet := True;
  FPageGridsCompact := Compact;
  grdMessages.SetColumnWrap(0, Compact);
  grdControls.SetColumnVisible(2, not Compact); // the raw command is on the edit screen
  if Compact then
  begin
    grdControls.SetColumnWidth(0, 120);
    grdControls.SetColumnWidth(1, 84);
    grdControls.SetColumnWidth(3, 110);
    grdDtcs.SetColumnWidth(0, 70);
    grdDtcs.SetColumnWidth(1, 90);
    grdDtcs.SetColumnWidth(3, 64);
  end
  else
  begin
    grdControls.SetColumnWidth(0, 230);
    grdControls.SetColumnWidth(1, 110);
    grdControls.SetColumnWidth(3, 200);
    grdDtcs.SetColumnWidth(0, 80);
    grdDtcs.SetColumnWidth(1, 140);
    grdDtcs.SetColumnWidth(3, 70);
  end;
  grdMessages.AutoHeights := Compact; // a long trace: only where lines must wrap
  if Compact then
    grdMessages.AutoRowHeights
  else
    grdMessages.ResetRowHeights;
  for G in [grdControls, grdDtcs] do
    G.AutoRowHeights;
end;

{ Phone: the PID list becomes the first tab; the bars wrap. }
{ Window layout: top bar (title, back, main action, page menu), pages, status
  strip and tab bar - the same on Windows and Android. On a wide Windows
  window the PID list sits beside the pages instead of on its own tab, and
  the pages show their tool bars instead of keeping them in the menu. }

const
  NavCaptions: array[0..6] of string = ('Connect', 'PIDs', 'Live', 'Gauges', 'Codes', 'Logs', 'More');
  AwayChoices: array[0..5] of Integer = (5, 10, 15, 30, 60, 120); // seconds, Settings > Logging
  // Tab bar icons on a 24 x 24 grid, drawn as 2 px lines (More: three dots).
  NavIcons: array[0..6] of string = (
    'M9 3 L9 8 M15 3 L15 8 M6 8 L18 8 L18 11 C18 14.3 15.3 17 12 17 C8.7 17 6 14.3 6 11 Z M12 17 L12 21',
    'M3.5 6 L5.5 8 L8.5 4.5 M12 6.5 L21 6.5 M3.5 12.5 L5.5 14.5 L8.5 11 M12 13 L21 13 ' +
      'M4 17.5 L8 17.5 L8 21.5 L4 21.5 Z M12 19.5 L21 19.5',
    'M2 12 L6 12 L9 5 L14 19 L17 12 L22 12',
    'M3 18 C3 11.4 7 6 12 6 C17 6 21 11.4 21 18 M12 18 L16.5 11 M12 8.5 L12 10 M6.4 11 L7.5 12.1 ' +
      'M17.6 11 L16.5 12.1',
    'M12 3.5 L21.5 20 L2.5 20 Z M12 9.5 L12 14 M12 17 L12 17.1',
    'M6 3 L14 3 L19 8 L19 21 L6 21 Z M14 3 L14 8 L19 8 M9 12.5 L16 12.5 M9 16.5 L16 16.5',
    '');
  WideLayoutWidth = 980; // Windows: from this client width the PID list sits beside the pages
  RailHeight = 480;      // below this height (and wider than tall) the tabs go down the left side
  RailWidth = 76;

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
  FNavPages[4] := tiVehicle;
  FNavPages[5] := nil;
  FNavPages[6] := tiMore;
  for I := 0 to High(FNavButtons) do
  begin
    Btn := TRectangle.Create(Self);
    Btn.Parent := pnlNav;
    Btn.Stored := False;
    Btn.SetBounds(I * 100, 0, 100, pnlNav.Height); // LayoutNav places them
    Btn.Fill.Color := TAlphaColors.Null;
    Btn.Stroke.Kind := TBrushKind.None;
    Btn.HitTest := True;
    Btn.Cursor := crHandPoint;
    Btn.Tag := I;
    Btn.OnClick := NavClick;
    Btn.OnPaint := NavPaint;
    FNavButtons[I] := Btn;
  end;
  pnlNav.OnResized := NavResized;

  btnBack.Text := '';
  Icon := AddIcon(btnBack);
  Icon.Data.Data := 'M15 4 L7 12 L15 20';
  Icon.Fill.Kind := TBrushKind.None;
  btnMenu.Text := '';
  Icon := AddIcon(btnMenu);
  for I := 0 to 2 do
    Icon.Data.AddEllipse(TRectF.Create(10, 3 + I * 7, 14, 7 + I * 7));
  Icon.Stroke.Kind := TBrushKind.None;
  // Live and Gauges: the live chart.
  btnChart := TSpeedButton.Create(Self);
  btnChart.Parent := pnlAppBar;
  btnChart.Stored := False;
  btnChart.Align := TAlignLayout.Right;
  btnChart.Position.X := btnAction.Position.X - 1; // left of the main action
  btnChart.Width := 44;
  btnChart.Text := '';
  btnChart.Hint := 'Live chart';
  btnChart.ShowHint := True;
  btnChart.OnClick := LiveChartClick;
  // OrderAppBar places the right side of the bar
  for var C in TArray<TControl>.Create(btnAction, btnMenu, btnChart) do
    C.Align := TAlignLayout.None;
  btnAction.Height := 36;
  pnlAppBar.OnResized := AppBarResized;
  Icon := AddIcon(btnChart);
  Icon.Data.Data := 'M3 4 L3 20 L21 20 M6 15 L10 10 L14 13 L20 6';
  Icon.Fill.Kind := TBrushKind.None;
  // Connect page: the Quick start menu, beside Start / Stop scan.
  btnQuick := TButton.Create(Self);
  btnQuick.Stored := False;
  btnQuick.Parent := btnStopScan.Parent;
  btnQuick.Size.Size := btnStopScan.Size.Size;
  btnQuick.Margins := btnStopScan.Margins;
  btnQuick.Text := 'Quick start...';
  btnQuick.Hint := 'Get going in one go: scan list, dashboard, connect, scan, log, full screen';
  btnQuick.ShowHint := True;
  btnQuick.OnClick := QuickStartClick;
  // Gauges: the dashboard on the whole screen.
  btnFullScreen := TSpeedButton.Create(Self);
  btnFullScreen.Parent := pnlAppBar;
  btnFullScreen.Stored := False;
  btnFullScreen.Width := 44;
  btnFullScreen.Text := '';
  btnFullScreen.Hint := 'Full screen (F11; Esc to come back)';
  btnFullScreen.ShowHint := True;
  btnFullScreen.OnClick := FullScreenClick;
  Icon := AddIcon(btnFullScreen);
  Icon.Data.Data := 'M4 9 L4 4 L9 4 M15 4 L20 4 L20 9 M20 15 L20 20 L15 20 M9 20 L4 20 L4 15';
  Icon.Fill.Kind := TBrushKind.None;
  // Wide windows: the PID list beside the pages, or on a page of its own.
  btnPidPanel := TSpeedButton.Create(Self);
  btnPidPanel.Parent := pnlAppBar;
  btnPidPanel.Stored := False;
  btnPidPanel.Align := TAlignLayout.Left;
  btnPidPanel.Position.X := btnBack.Position.X + btnBack.Width + 1; // after Back
  btnPidPanel.Width := 44;
  btnPidPanel.Text := '';
  btnPidPanel.ShowHint := True;
  btnPidPanel.OnClick := TogglePidPanelClick;
  Icon := AddIcon(btnPidPanel);
  Icon.Data.Data := 'M3 5 L21 5 L21 19 L3 19 Z M9 5 L9 19';
  Icon.Fill.Kind := TBrushKind.None;
  // Full screen: a quiet round button to come back.
  FExitFull := TCircle.Create(Self);
  FExitFull.Parent := tiDashboard;
  FExitFull.Stored := False;
  FExitFull.SetBounds(0, 0, 44, 44);
  FExitFull.Stroke.Kind := TBrushKind.None;
  FExitFull.Opacity := 0.55;
  FExitFull.HitTest := True;
  FExitFull.Cursor := crHandPoint;
  FExitFull.Hint := 'Leave full screen (Esc)';
  FExitFull.ShowHint := True;
  FExitFull.OnClick := FullScreenClick;
  FExitFull.Visible := False;
  Icon := AddIcon(FExitFull);
  Icon.Data.Data := 'M9 4 L9 9 L4 9 M15 4 L15 9 L20 9 M20 15 L15 15 L15 20 M9 20 L9 15 L4 15';
  Icon.Fill.Kind := TBrushKind.None;
  // Gauge menu: minimize (to a chip) or restore.
  FMinimizeItem := TMenuItem.Create(Self);
  FMinimizeItem.Stored := False;
  FMinimizeItem.Text := 'Minimize';
  FMinimizeItem.OnClick := MinimizeGaugeClick;
  pmGauge.InsertObject(miGaugeSep1.Index, FMinimizeItem);
  // Full screen: a pill at the top while not scanning (the values are old then).
  FFullState := TRectangle.Create(Self);
  FFullState.Parent := tiDashboard;
  FFullState.Stored := False;
  FFullState.HitTest := False;
  FFullState.Stroke.Kind := TBrushKind.None;
  FFullState.Fill.Color := $E0B03030;
  FFullState.XRadius := 16;
  FFullState.YRadius := 16;
  FFullState.Visible := False;
  with TLabel.Create(Self) do
  begin
    Parent := FFullState;
    Stored := False;
    Align := TAlignLayout.Client;
    HitTest := False;
    StyledSettings := StyledSettings - [TStyledSetting.Size, TStyledSetting.FontColor, TStyledSetting.Style];
    TextSettings.Font.Size := 16;
    TextSettings.Font.Style := [TFontStyle.fsBold];
    TextSettings.FontColor := TAlphaColors.White;
    TextSettings.HorzAlign := TTextAlign.Center;
  end;
  // Grid menu, live rows: move the row.
  FMenuLiveRow := -1;
  for I := 0 to 4 do
  begin
    FMoveItems := FMoveItems + [TMenuItem.Create(Self)];
    FMoveItems[I].Stored := False;
    FMoveItems[I].Tag := I - 1; // -1: the separator
    case I of
      0: FMoveItems[I].Text := '-';
      1: FMoveItems[I].Text := 'Move up';
      2: FMoveItems[I].Text := 'Move down';
      3: FMoveItems[I].Text := 'Move to the top';
    else
      FMoveItems[I].Text := 'Move to the bottom';
    end;
    if I > 0 then
      FMoveItems[I].OnClick := MoveRowClick;
    pmPid.AddObject(FMoveItems[I]);
  end;

  AddMore('Real-time controls', 'Switch outputs, hold values, reset learned values', tiControls);
  AddMore('Tools', 'Write VIN, raw AVT frames, PID discovery', tiTools);
  AddMore('Settings', 'Theme, rounding, alert sounds, log folder, stream speed', tiSettings);
  AddMore('Messages', 'Connection log and raw traffic', tiMessages);

  // Settings, phones and tablets: keep the screen from turning (bumps in a car).
  chkLockRotate := TCheckBox.Create(Self);
  chkLockRotate.Stored := False;
  chkLockRotate.Parent := gbAppearance;
  chkLockRotate.Position.X := chkRound.Position.X;
  chkLockRotate.Size.Size := chkRound.Size.Size;
  chkLockRotate.Text := 'Lock screen rotation (it stays the way it faces now)';
  chkLockRotate.Visible := IsMobile;
  chkLockRotate.OnChange := chkLockRotateChange;
  // Gauges page: the dashboard's own background behind the gauges.
  FDashBack := TRectangle.Create(Self);
  FDashBack.Parent := sbDash.Parent;
  FDashBack.Stored := False;
  FDashBack.Index := sbDash.Index; // under the gauges
  FDashBack.HitTest := False;
  FDashBack.Stroke.Kind := TBrushKind.None;
  FDashBack.Fill.Kind := TBrushKind.None;
  FDashBack.ClipChildren := True;
  FDashBackImg := TImage.Create(Self);
  FDashBackImg.Parent := FDashBack;
  FDashBackImg.Stored := False;
  FDashBackImg.HitTest := False;
  FDashBackImg.WrapMode := TImageWrapMode.Stretch;
  FDashBackImg.Visible := False;
  // Gauges page: a round + to add a gauge, and a hint while there are none.
  FAddGauge := TCircle.Create(Self);
  FAddGauge.Parent := tiDashboard;
  FAddGauge.Stored := False;
  FAddGauge.SetBounds(0, 0, 56, 56);
  FAddGauge.Stroke.Kind := TBrushKind.None;
  FAddGauge.HitTest := True;
  FAddGauge.Cursor := crHandPoint;
  FAddGauge.Hint := 'Add a gauge';
  FAddGauge.ShowHint := True;
  FAddGauge.OnClick := btnAddGaugeClick;
  Icon := AddIcon(FAddGauge);
  Icon.Data.Data := 'M12 5 L12 19 M5 12 L19 12';
  Icon.Fill.Kind := TBrushKind.None;
  Icon.Stroke.Thickness := 2.6;
  FDashCombo := TComboBox.Create(Self);
  FDashCombo.Stored := False;
  FDashCombo.Parent := pnlDashBar;
  FDashCombo.Index := 0;
  FDashCombo.SetBounds(0, 0, 190, 30);
  FDashCombo.Hint := 'Which dashboard to show (the page menu adds, renames and deletes them)';
  FDashCombo.ShowHint := True;
  FDashCombo.OnChange := DashComboChange;
  FDashEmpty := TLabel.Create(Self);
  FDashEmpty.Parent := tiDashboard;
  FDashEmpty.Stored := False;
  FDashEmpty.Align := TAlignLayout.Center;
  FDashEmpty.SetBounds(0, 0, 300, 120);
  FDashEmpty.HitTest := False;
  FDashEmpty.StyledSettings := FDashEmpty.StyledSettings - [TStyledSetting.Size];
  FDashEmpty.TextSettings.Font.Size := 16;
  FDashEmpty.TextSettings.HorzAlign := TTextAlign.Center;
  FDashEmpty.TextSettings.WordWrap := True;
  FDashEmpty.Text := 'No gauges yet.' + sLineBreak + 'Tap + to add one.';
  FDashEmpty.Visible := False;
  FDashSpacer := TLayout.Create(Self);
  FDashSpacer.Parent := sbDash;
  FDashSpacer.Stored := False;
  FDashSpacer.HitTest := False;

  FPageMenu := TPopupMenu.Create(Self);
  FPageMenu.Parent := Self;

  // Settings > Logging (phones): how long UVScan may be off the screen.
  lblAway := TLabel.Create(Self);
  lblAway.Parent := gbLogging;
  lblAway.Stored := False;
  lblAway.Text := 'Stop and disconnect when away for';
  cbAway := TComboBox.Create(Self);
  cbAway.Parent := gbLogging;
  cbAway.Stored := False;
  cbAway.Height := edtLogFolder.Height;
  for I := 0 to High(AwayChoices) do
    if AwayChoices[I] < 60 then
      cbAway.Items.Add(Format('%d seconds', [AwayChoices[I]]))
    else
      cbAway.Items.Add(Format('%d minute%s', [AwayChoices[I] div 60, IfThen(AwayChoices[I] > 60, 's', '')]));
  cbAway.Hint := 'Android stops an app it is not showing after a while: the log, the scan and the connection ' +
    'are closed properly first';
  lblAway.Visible := IsMobile;
  cbAway.Visible := IsMobile;
  tiConnect.Text := 'Connection';

  // Connection: the address of an AVT on the network, when that is the port.
  edtTcpAddress := TEdit.Create(Self);
  edtTcpAddress.Stored := False;
  edtTcpAddress.Parent := flAdapter;
  edtTcpAddress.Index := cbPort.Index + 1;
  edtTcpAddress.Size.Size := TSizeF.Create(230, cbPort.Height);
  edtTcpAddress.TextPrompt := Format('e.g. 192.168.2.99:%d', [DefaultTcpPort]);
  edtTcpAddress.Hint := Format('The interface''s IP address or name, and its port (%d if left out)', [DefaultTcpPort]);
  edtTcpAddress.ShowHint := True;
  edtTcpAddress.KeyboardType := TVirtualKeyboardType.URL;
  edtTcpAddress.Visible := False;
  cbPort.OnChange := PortChanged;

  // The controls warning hides with a tap (it takes a lot of a phone's screen).
  pnlCtlWarn.HitTest := True;
  pnlCtlWarn.Cursor := crHandPoint;
  pnlCtlWarn.OnClick := CtlWarnClick;
  lblCtlWarn.HitTest := False;
  lblCtlWarn.Text := lblCtlWarn.Text + IfThen(IsMobile, '  (Tap to hide.)', '  (Click to hide.)');
  if IsMobile then
  begin
    btnBrowseLogFolder.Visible := False; // no folder picker on a phone
    lblDashHint.Text := 'Long-press a gauge to change, move or remove it.';
    WindowState := TWindowState.wsMaximized;
    KeepInSafeArea(Self);
    OnSafeAreaChanged := SafeAreaChanged; // like KeepInSafeArea's, but full screen keeps its own
  end;
end;

procedure TMainForm.ArrangeLayout;
var
  Wide, Docked: Boolean;
  W, H: Single;
begin
  if not FChromeReady then
    Exit;
  W := InnerWidth(Self);
  H := InnerHeight(Self);
  Wide := W >= WideLayoutWidth; // a big window or a tablet held sideways
  FWide := Wide;
  // Beside the pages unless the user put it on its own page (or full screen).
  Docked := Wide and not FSettings.Window.PidsHidden and not FFullScreen;
  if Docked and (pnlPids.Parent <> Self) then
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
  else if not Docked and (pnlPids.Parent <> tiPids) then
  begin
    if FPidsDocked then
      FSettings.Window.PidPanelWidth := Round(pnlPids.Width);
    pnlPids.Parent := tiPids;
    pnlPids.Align := TAlignLayout.Client;
    splLeft.Visible := False;
  end;
  FPidsDocked := Docked;
  FNavButtons[1].Visible := not Docked;
  if Docked then
    lblLiveHint.Text := 'Tick PIDs on the left, connect, then press Start scan.'
  else
    lblLiveHint.Text := 'Tick PIDs on the PIDs page, connect, then press Start scan.';
  if Docked and (tcMain.ActiveTab = tiPids) then
    ShowPage(tiLive);
  // Wide windows show the page tool bars; otherwise their buttons are in the menu.
  pnlLiveFooter.Visible := Wide;
  pnlDashBar.Visible := Wide and not FFullScreen;
  if btnPidPanel <> nil then
    btnPidPanel.Visible := Wide;
  pnlCtlBar.Visible := Wide;
  // A short window (a phone held sideways): the tabs down the left side, and the
  // PID search beside the scan list, so the pages keep their height.
  FRail := (H < RailHeight) and (W > H);
  if FRail then
  begin
    pnlNav.Align := TAlignLayout.MostLeft; // the whole height, beside the top bar too
    pnlNav.Width := RailWidth;
    pnlNav.Sides := [TSide.Right];
    // Controls: the selected control beside the list
    if pnlCtlRun.Align = TAlignLayout.Bottom then
      FCtlRunHeight := pnlCtlRun.Height;
    pnlCtlRun.Align := TAlignLayout.Right;
    pnlCtlRun.Width := Max(280, Round((W - RailWidth) * 0.42));
  end
  else
  begin
    pnlNav.Align := TAlignLayout.Bottom;
    pnlNav.Position.Y := ClientHeight + 100; // under the status strip
    pnlNav.Height := 56;
    pnlNav.Sides := [TSide.Top];
    if pnlCtlRun.Align <> TAlignLayout.Bottom then
    begin
      pnlCtlRun.Align := TAlignLayout.Bottom;
      pnlCtlRun.Position.Y := tiControls.Height + 100;
      pnlCtlRun.Height := FCtlRunHeight; // FitFlowHeights keeps it when no control is selected
    end;
  end;
  // The PID search beside the scan list when short - on the PIDs page, not in
  // the docked list (too narrow for both).
  if FRail and not Wide then
  begin
    if edtSearch.Parent <> pnlListBar then
    begin
      edtSearch.Parent := pnlListBar;
      edtSearch.Align := TAlignLayout.Right;
      edtSearch.Position.X := pnlListBar.Width + 100; // right of Save as
      edtSearch.Margins.Rect := TRectF.Create(8, 2, 0, 2);
    end;
    edtSearch.Width := Min(240, Round(W * 0.3));
  end
  else if edtSearch.Parent <> pnlPids then
  begin
    edtSearch.Parent := pnlPids;
    edtSearch.Align := TAlignLayout.Top;
    edtSearch.Position.Y := pnlListBar.Position.Y + pnlListBar.Height + 1;
    edtSearch.Margins.Rect := TRectF.Create(0, 4, 0, 4);
  end;
  LayoutNav;
  OrderAppBar;
end;

{ The tab bar buttons share its width, or (down the side) are stacked in the middle. }
procedure TMainForm.LayoutNav;
var
  I, N: Integer;
  S, P: Single;
begin
  N := 0;
  for I := 0 to High(FNavButtons) do
    if FNavButtons[I].Visible then
      Inc(N);
  N := Max(1, N);
  if FRail then
  begin
    S := Min(64, pnlNav.Height / N);
    P := Max(0, (pnlNav.Height - S * N) / 2);
  end
  else
  begin
    S := pnlNav.Width / N;
    P := 0;
  end;
  for I := 0 to High(FNavButtons) do
    if FNavButtons[I].Visible then
    begin
      if FRail then
        FNavButtons[I].SetBounds(0, P, pnlNav.Width, S)
      else
        FNavButtons[I].SetBounds(P, 0, S, pnlNav.Height);
      P := P + S;
    end;
end;

procedure TMainForm.NavResized(Sender: TObject);
begin
  if FChromeReady then
    LayoutNav;
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
  if Page = tiDashboard then
    TThread.ForceQueue(nil, PlaceAddGauge);
end;

procedure TMainForm.UpdateAppBar;
var
  P: TTabItem;
  I: Integer;
begin
  if not FChromeReady then
    Exit;
  P := CurrentPage;
  if (P = tiDashboard) and (FDisplay <> nil) and (FDisplay.DashboardCount > 1) then
    lblTitle.Text := FDisplay.Dashboards[FDisplay.Current].Name // which dashboard, also on a phone
  else
    lblTitle.Text := P.Text;
  btnBack.Visible := (tcMain.ActiveTab = tiMore) and (P <> tiMoreMenu);
  btnMenu.Visible := (P = tiLive) or (P = tiDashboard) or (P = tiPids) or (P = tiMessages) or (P = tiConnect) or
    (P = tiControls);
  btnChart.Visible := (P = tiLive) or (P = tiDashboard);
  btnFullScreen.Visible := P = tiDashboard;
  // Both can show: the PID list button after the back arrow (sharing its
  // place, a second tap on back hid the PID list).
  btnPidPanel.Visible := FWide;
  if btnBack.Visible then
    btnPidPanel.Position.X := btnBack.Position.X + btnBack.Width + 1;
  if FSettings.Window.PidsHidden then
    btnPidPanel.Hint := 'Show the PID list beside the pages (Ctrl+L)'
  else
    btnPidPanel.Hint := 'Hide the PID list - it gets a page of its own (Ctrl+L)';
  // Without the menu button, the main button keeps a gap to the edge.
  if btnMenu.Visible then
    btnAction.Margins.Right := 4
  else
    btnAction.Margins.Right := 12;
  OrderAppBar;
  for I := 0 to High(FNavButtons) do
    FNavButtons[I].Repaint;
end;

{ The top bar's right side, from the edge: menu, main button, chart - placed
  here rather than right aligned (the alignment mixed their order up after a
  turn with some of them hidden). The title gets the rest. }
procedure TMainForm.OrderAppBar;
var
  R, H: Single;
begin
  if btnChart = nil then
    Exit;
  H := pnlAppBar.Height;
  R := pnlAppBar.Width;
  if btnMenu.Visible then
  begin
    btnMenu.SetBounds(R - btnMenu.Width, 0, btnMenu.Width, H);
    R := R - btnMenu.Width;
  end;
  R := R - btnAction.Margins.Right;
  btnAction.SetBounds(R - btnAction.Width, Round((H - btnAction.Height) / 2), btnAction.Width, btnAction.Height);
  R := btnAction.Position.X - 4;
  if btnChart.Visible then
  begin
    btnChart.SetBounds(R - btnChart.Width, 0, btnChart.Width, H);
    R := R - btnChart.Width;
  end;
  if (btnFullScreen <> nil) and btnFullScreen.Visible then
  begin
    btnFullScreen.SetBounds(R - btnFullScreen.Width, 0, btnFullScreen.Width, H);
    R := R - btnFullScreen.Width;
  end;
  lblTitle.Margins.Right := pnlAppBar.Width - R + 4;
end;

procedure TMainForm.AppBarResized(Sender: TObject);
begin
  OrderAppBar;
end;

procedure TMainForm.CtlWarnClick(Sender: TObject);
begin
  pnlCtlWarn.Visible := False;
end;

{ The round + sits bottom right on the Gauges page, over the gauges. }
procedure TMainForm.PlaceAddGauge;
begin
  if (FAddGauge = nil) or (sbDash.Height < 100) then
    Exit;
  FAddGauge.Position.Point := TPointF.Create(sbDash.Position.X + sbDash.Width - FAddGauge.Width - 20,
    sbDash.Position.Y + sbDash.Height - FAddGauge.Height - 20);
  FAddGauge.BringToFront;
  PlaceExitFull;
  PlaceDashBack;
end;

{ The dashboard's background: its colour, and its picture scaled to cover the
  page (cut at the sides or the top and bottom, never stretched). }
procedure TMainForm.ApplyDashBackground;
var
  D: TDashboard;
  FileName: string;
begin
  if FDashBack = nil then
    Exit;
  D := FDisplay.Dashboards[FDisplay.Current];
  if D.BackColor <> NoColor then
  begin
    FDashBack.Fill.Kind := TBrushKind.Solid;
    FDashBack.Fill.Color := D.BackColor;
  end
  else
    FDashBack.Fill.Kind := TBrushKind.None;
  FileName := '';
  if D.BackImage <> '' then
    FileName := System.IOUtils.TPath.Combine(System.IOUtils.TPath.Combine(DataDir, 'images'), D.BackImage);
  if FileName <> FDashBackFile then
  begin
    FDashBackFile := FileName;
    FDashBackImg.Bitmap.SetSize(0, 0);
    if (FileName <> '') and FileExists(FileName) then
      try
        FDashBackImg.Bitmap.LoadFromFile(FileName);
      except
        on E: Exception do
          AddMessage('Dashboard picture could not be read: ' + E.Message);
      end;
  end;
  FDashBackImg.Visible := not FDashBackImg.Bitmap.IsEmpty;
  PlaceDashBack;
end;

procedure TMainForm.PlaceDashBack;
var
  W, H, S: Single;
begin
  if FDashBack = nil then
    Exit;
  FDashBack.SetBounds(sbDash.Position.X, sbDash.Position.Y, sbDash.Width, sbDash.Height);
  // Full screen: the window's own edge (a pixel or two past the page) in the
  // dashboard's colour, or black under a picture.
  if FFullScreen and ((FDashBack.Fill.Kind = TBrushKind.Solid) or FDashBackImg.Visible) then
  begin
    Fill.Kind := TBrushKind.Solid;
    if FDashBack.Fill.Kind = TBrushKind.Solid then
      Fill.Color := FDashBack.Fill.Color
    else
      Fill.Color := TAlphaColors.Black;
  end
  else
    Fill.Kind := TBrushKind.None;
  // Drawn in child order: the background, then the gauges, then what floats over them.
  if FDashBack.Index > sbDash.Index then
  begin
    sbDash.BringToFront;
    FDashEmpty.BringToFront;
    FAddGauge.BringToFront;
    FExitFull.BringToFront;
  end;
  if not FDashBackImg.Visible then
    Exit;
  W := FDashBackImg.Bitmap.Width;
  H := FDashBackImg.Bitmap.Height;
  if (W <= 0) or (H <= 0) then
    Exit;
  S := Max(FDashBack.Width / W, FDashBack.Height / H);
  FDashBackImg.SetBounds((FDashBack.Width - W * S) / 2, (FDashBack.Height - H * S) / 2, W * S, H * S);
end;

{ Gauges: Background... - the theme's, a colour, or a picture. }
procedure TMainForm.DashBackgroundClick(Sender: TObject);
var
  Items: TArray<TActionItem>;
  D: TDashboard;
  Pt: TPointF;

  procedure Add(const Text: string; Tag: Integer; Enabled, Checked: Boolean);
  var
    It: TActionItem;
    Pick: TComponent;
  begin
    Pick := TComponent.Create(FDashPicks);
    Pick.Tag := Tag;
    It := Default(TActionItem);
    It.Text := Text;
    It.Enabled := Enabled;
    It.Checked := Checked;
    It.OnClick := DashBackPickClick;
    It.Sender := Pick;
    Items := Items + [It];
  end;

begin
  FDashPicks.Free;
  FDashPicks := TComponent.Create(Self);
  D := FDisplay.Dashboards[FDisplay.Current];
  Items := nil;
  Add('Plain (the theme''s)', 0, True, (D.BackColor = NoColor) and (D.BackImage = ''));
  Add('Solid colour...', 1, True, D.BackColor <> NoColor);
  Add('Picture...', 2, True, D.BackImage <> '');
  Add('No picture', 3, D.BackImage <> '', False);
  Pt := btnMenu.LocalToAbsolute(TPointF.Create(btnMenu.Width, btnMenu.Height));
  ShowActionMenu(Self, Items, Pt);
end;

procedure TMainForm.DashBackPickClick(Sender: TObject);
var
  D: TDashboard;
  Items: TArray<TActionItem>;
  It: TActionItem;
  Pick: TComponent;
begin
  D := FDisplay.Dashboards[FDisplay.Current];
  case TComponent(Sender).Tag of
    0:
      begin
        D.BackColor := NoColor;
        SetDashPicture(nil);
      end;
    1:
      // the colours to pick from (after this menu has closed)
      TThread.ForceQueue(nil,
        procedure
        var
          N: Integer;
        begin
          FDashPicks.Free;
          FDashPicks := TComponent.Create(Self);
          Items := nil;
          for N := 0 to High(NamedColors) do
          begin
            Pick := TComponent.Create(FDashPicks);
            Pick.Tag := N;
            It := Default(TActionItem);
            It.Text := NamedColors[N].Name;
            It.Enabled := True;
            It.Checked := FDisplay.Dashboards[FDisplay.Current].BackColor = NamedColors[N].Color;
            It.OnClick := DashColorPickClick;
            It.Sender := Pick;
            Items := Items + [It];
          end;
          ShowActionMenu(Self, Items, btnMenu.LocalToAbsolute(TPointF.Create(btnMenu.Width, btnMenu.Height)));
        end);
    2:
      PickPicture(sbDash, 'Dashboard picture', 2560, DashPictureTaken);
    3:
      SetDashPicture(nil);
  end;
end;

procedure TMainForm.DashPictureTaken(Image: TBitmap);
begin
  SetDashPicture(Image);
end;

procedure TMainForm.DashColorPickClick(Sender: TObject);
var
  N: Integer;
begin
  N := TComponent(Sender).Tag;
  if (N < 0) or (N > High(NamedColors)) then
    Exit;
  FDisplay.Dashboards[FDisplay.Current].BackColor := NamedColors[N].Color;
  SaveDisplay;
  ApplyDashBackground;
end;

{ Bmp = nil: no picture. Otherwise a copy (at most 2560 pixels across) goes
  to DataDir\images, so the original can be moved or deleted. }
procedure TMainForm.SetDashPicture(Bmp: TBitmap);
var
  D: TDashboard;
  Dir, Name, Old: string;
  Small: TBitmap;
  K: Single;
  Params: TBitmapCodecSaveParams;
begin
  D := FDisplay.Dashboards[FDisplay.Current];
  Dir := System.IOUtils.TPath.Combine(DataDir, 'images');
  Old := D.BackImage;
  D.BackImage := '';
  if (Bmp <> nil) and not Bmp.IsEmpty then
  begin
    ForceDirectories(Dir);
    Name := Format('dashboard-%s.jpg', [FormatDateTime('yyyymmdd-hhnnsszzz', Now)]);
    K := Min(1, 2560 / Max(Bmp.Width, Bmp.Height));
    Small := Bmp.CreateThumbnail(Max(1, Round(Bmp.Width * K)), Max(1, Round(Bmp.Height * K)));
    try
      Params.Quality := 88;
      Small.SaveToFile(System.IOUtils.TPath.Combine(Dir, Name), @Params);
      D.BackImage := Name;
    finally
      Small.Free;
    end;
  end;
  // The old picture goes, unless another dashboard shows it too.
  if (Old <> '') and (Old <> D.BackImage) then
  begin
    var Shared := False;
    for var I := 0 to FDisplay.DashboardCount - 1 do
      Shared := Shared or SameText(FDisplay.Dashboards[I].BackImage, Old);
    if not Shared then
      DeleteFile(System.IOUtils.TPath.Combine(Dir, Old));
  end;
  SaveDisplay;
  ApplyDashBackground;
end;

procedure TMainForm.SafeAreaChanged(Sender: TObject; const AInsets: TRectF);
begin
  if FFullScreen or (TThread.GetTickCount64 < FSafeHold) or (Padding.Rect = AInsets) then
    Exit;
  Padding.Rect := AInsets;
  FormResize(Self); // the insets move when the phone turns
end;

procedure TMainForm.UpdateFullState;
var
  S: string;
begin
  if FFullState = nil then
    Exit;
  S := '';
  if FFullScreen and not (FState in [esScanning]) and not FTestMode then
    case FState of
      esDisconnected:
        if FQuickActive and FQuick.Retry then
          S := 'Not connected - trying again'
        else
          S := 'Not connected';
      esConnected:
        S := 'Connected - not scanning';
    else
      S := 'Working...';
    end;
  FFullState.Visible := S <> '';
  if S = '' then
    Exit;
  TLabel(FFullState.Controls[0]).Text := S;
  FFullState.SetBounds((sbDash.Width - 320) / 2 + sbDash.Position.X, sbDash.Position.Y + 8, 320, 34);
  FFullState.BringToFront;
end;

procedure TMainForm.PlaceExitFull;
begin
  if (FExitFull = nil) or not FExitFull.Visible then
    Exit;
  FExitFull.Position.Point := TPointF.Create(sbDash.Position.X + sbDash.Width - FExitFull.Width - 4,
    sbDash.Position.Y + 4);
  FExitFull.BringToFront;
end;

{ Wide windows: the PID list beside the pages, or (more room for them) on a
  page of its own, like on a phone. }
procedure TMainForm.TogglePidPanelClick(Sender: TObject);
begin
  if FPidsDocked then
    FSettings.Window.PidPanelWidth := Round(pnlPids.Width);
  FSettings.Window.PidsHidden := not FSettings.Window.PidsHidden;
  SettingsChanged;
  FormResize(Self);
  UpdateAppBar;
end;

procedure TMainForm.FullScreenClick(Sender: TObject);
begin
  SetFullScreen(not FFullScreen);
end;

{ The dashboard alone on the whole screen - no bars, tabs or PID list - for
  driving. Esc, Back or the round button top right come back. }
procedure TMainForm.SetFullScreen(Value: Boolean);
begin
  if Value = FFullScreen then
    Exit;
  CloseActionMenu;
  if Value then
  begin
    FWasMaximized := WindowState = TWindowState.wsMaximized;
    if CurrentPage <> tiDashboard then
      ShowPage(tiDashboard);
  end;
  FFullScreen := Value;
  pnlAppBar.Visible := not Value;
  pnlNav.Visible := not Value;
  pnlStatus.Visible := not Value;
  if Value then
    pnlNotice.Visible := False;
  FAddGauge.Visible := not Value;
  FExitFull.Visible := Value;
  UpdateFullState;
  if IsMobile then
  begin
    // No status or navigation bar. The insets Android reports around this
    // are off (room for a navigation bar that is gone, or kept after it is
    // back), so full screen has none, and coming back has those from before.
    if Value then
      FWasPadding := Padding.Rect;
    FSafeHold := TThread.GetTickCount64 + 2000;
    FullScreen := Value;
    if Value then
      Padding.Rect := TRectF.Empty
    else
      Padding.Rect := FWasPadding;
  end
  else if Value then
  begin
    // Windows (FMX's FullScreen left the window without its frame afterwards):
    // no frame, over the whole screen it is on, taskbar too.
    FWasBorder := BorderStyle;
    FWasBounds := TRectF.Create(Left, Top, Left + Width, Top + Height);
    if FWasMaximized then
      WindowState := TWindowState.wsNormal;
    BorderStyle := TFmxFormBorderStyle.None;
    with Screen.DisplayFromForm(Self).Bounds do
      SetBoundsF(Left, Top, Width, Height);
  end
  else
  begin
    BorderStyle := FWasBorder;
    if FNormalBounds.Width > 0 then
      SetBoundsF(FNormalBounds.Left, FNormalBounds.Top, FNormalBounds.Width, FNormalBounds.Height)
    else
      SetBoundsF(FWasBounds.Left, FWasBounds.Top, FWasBounds.Width, FWasBounds.Height);
    if FWasMaximized then
      WindowState := TWindowState.wsMaximized;
  end;
  FormResize(Self);
  UpdateAppBar;
  TThread.ForceQueue(nil,
    procedure
    begin
      LayoutDashboard;
      PlaceExitFull;
    end);
end;

procedure TMainForm.NavClick(Sender: TObject);
begin
  if FNavPages[TControl(Sender).Tag] = nil then
    btnLogViewerClick(nil)
  else
    ShowPage(FNavPages[TControl(Sender).Tag]);
end;

procedure TMainForm.NavPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
var
  I: Integer;
  P: TPalette;
  Color: TAlphaColor;
  Path: TPathData;
  Cx, Y, PillTop, PillH, IconTop, TextTop, TextH, TextSize: Single;
  D: Integer;
begin
  I := TControl(Sender).Tag;
  P := Palette;
  Cx := (ARect.Left + ARect.Right) / 2;
  if ARect.Height >= 54 then
  begin
    Y := ARect.Top + Max(0, (ARect.Height - 56) / 2); // a taller button (down the side): in its middle
    PillTop := Y + 4;
    PillH := 28;
    IconTop := Y + 6;
    TextTop := Y + 33;
    TextH := 21;
    TextSize := 12;
  end
  else
  begin
    // Seven down the side of a small phone: tighter, the caption a little smaller.
    Y := ARect.Top + Max(0, (ARect.Height - 43) / 2);
    PillTop := Y + 1;
    PillH := 25;
    IconTop := Y + 1.5;
    TextTop := Y + 26;
    TextH := 17;
    TextSize := 10.5;
  end;
  if (FNavPages[I] <> nil) and (FNavPages[I] = tcMain.ActiveTab) then
  begin
    Color := P.Accent;
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := WithAlpha(P.Accent, $30);
    // no wider than the button (seven of them on a phone)
    Canvas.FillRect(TRectF.Create(Cx - Min(28, ARect.Width / 2 - 2), PillTop, Cx + Min(28, ARect.Width / 2 - 2),
      PillTop + PillH), PillH / 2, PillH / 2, AllCorners, 1);
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
    Path.Translate(Cx - 12, IconTop);
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
  Canvas.Font.Size := TextSize;
  Canvas.FillText(TRectF.Create(ARect.Left, TextTop, ARect.Right, TextTop + TextH), NavCaptions[I], False, 1, [],
    TTextAlign.Center, TTextAlign.Center);
end;

procedure TMainForm.btnBackClick(Sender: TObject);
begin
  ShowPage(tiMoreMenu);
end;

procedure TMainForm.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if (Key = vkEscape) and CloseActionMenu then // Windows
  begin
    Key := 0;
    Exit;
  end;
  if ((Key = vkEscape) or (Key = vkHardwareBack)) and FFullScreen then
  begin
    SetFullScreen(False);
    Key := 0;
    Exit;
  end;
  if Key <> vkHardwareBack then
    Exit;
  // Android back: an open menu closes; out of a More page, then back to Live;
  // from Live, to the background like Home (the scan carries on for a while,
  // see AppEvent).
  if CloseActionMenu then
  else if btnBack.Visible then
    btnBackClick(nil)
  else if CurrentPage <> tiLive then
    ShowPage(tiLive)
  else
    MoveAppToBack;
  Key := 0;
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
      ShowPage(Page);
    end);
end;

procedure TMainForm.btnActionClick(Sender: TObject);
begin
  if (FState = esDisconnected) and FQuickActive and FQuick.Retry then
  begin
    FQuickActive := False;
    FRetryAt := 0;
    SetStatus(spRate, '');
    AddMessage('Stopped trying to connect');
    UpdateControls;
    Exit;
  end;
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
    AddPageMenuItem('Live chart', LiveChartClick);
    AddPageMenuItem('Reset min / max', btnResetMinMaxClick);
    AddPageMenuItem(btnLiveTest.Text, btnTestDisplayClick, btnLiveTest.Enabled);
    AddPageMenuItem('Show min / max', ToggleMinMaxClick, True, chkMinMax.IsChecked);
    if IsMobile then
      AddPageMenuItem('Lock screen rotation', ToggleLockRotateClick, True, chkLockRotate.IsChecked);
    if FWide then
      AddPageMenuItem('PID list beside the pages', TogglePidPanelClick, True, not FSettings.Window.PidsHidden);
    AddPageMenuItem('-', nil);
    AddPageMenuItem('Bigger text', btnZoomInClick);
    AddPageMenuItem('Smaller text', btnZoomOutClick);
    AddPageMenuItem(Format('Normal size (now %d%%)', [FZoom]), lblZoomClick);
  end
  else if P = tiDashboard then
  begin
    AddPageMenuItem('Dashboards...', ChooseDashboardClick, FDisplay.DashboardCount > 1);
    AddPageMenuItem('Add gauge...', btnAddGaugeClick);
    AddPageMenuItem('Tick these PIDs', btnTickDashPidsClick);
    AddPageMenuItem(btnDashTest.Text, btnTestDisplayClick, btnDashTest.Enabled);
    AddPageMenuItem('Live chart', LiveChartClick);
    AddPageMenuItem('Full screen', FullScreenClick);
    AddPageMenuItem('Background...', DashBackgroundClick);
    AddPageMenuItem('Fit gauges to the screen', FitScreenClick, True, FDisplay.Dashboards[FDisplay.Current].FitScreen);
    if IsMobile then
      AddPageMenuItem('Lock screen rotation', ToggleLockRotateClick, True, chkLockRotate.IsChecked);
    if FWide then
      AddPageMenuItem('PID list beside the pages', TogglePidPanelClick, True, not FSettings.Window.PidsHidden);
    AddPageMenuItem('-', nil);
    AddPageMenuItem('New dashboard...', NewDashboardClick);
    AddPageMenuItem('Rename dashboard...', RenameDashboardClick);
    AddPageMenuItem('Delete dashboard...', DeleteDashboardClick);
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
  begin
    AddPageMenuItem('Quick start...', QuickStartClick);
    AddPageMenuItem('Refresh ports', btnRefreshPortsClick, btnRefreshPorts.Enabled);
  end
  else if P = tiControls then
  begin
    AddPageMenuItem('Add...', btnCtlAddClick, btnCtlAdd.Enabled);
    AddPageMenuItem('Edit...', btnCtlEditClick, btnCtlEdit.Enabled);
    AddPageMenuItem('Duplicate', btnCtlDupClick, btnCtlDup.Enabled);
    AddPageMenuItem('Delete', btnCtlDeleteClick, btnCtlDelete.Enabled);
    AddPageMenuItem('Restore built-ins', btnCtlRestoreClick, btnCtlRestore.Enabled);
    AddPageMenuItem('-', nil);
    AddPageMenuItem('Release all', btnReleaseAllClick, btnReleaseAll.Enabled);
  end;
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

procedure TMainForm.chkKeepAwakeChange(Sender: TObject);
begin
  if not FChromeReady then
    Exit;
  KeepAwake(chkKeepAwake.IsChecked);
  SaveSettings;
end;

procedure TMainForm.chkLockRotateChange(Sender: TObject);
begin
  if not FChromeReady then
    Exit;
  FSettings.LockRotation := chkLockRotate.IsChecked;
  LockRotation(FSettings.LockRotation);
  SaveSettings;
  if FSettings.LockRotation then
    ShowNotice('Screen rotation locked: it stays this way until you unlock it (page menu or Settings)', False)
  else
    pnlNotice.Visible := False;
end;

procedure TMainForm.ToggleLockRotateClick(Sender: TObject);
begin
  chkLockRotate.IsChecked := not chkLockRotate.IsChecked;
end;

procedure TMainForm.chkRoundChange(Sender: TObject);
begin
  if not FChromeReady then
    Exit;
  FSettings.RoundReadings := chkRound.IsChecked;
  SaveSettings;
  FShownRows := nil;
  RefreshLiveRows;
  RefreshDashboard;
end;

{ A reading as the live grid and the gauges show it. }
function TMainForm.ReadingText(P: TPidDef; const Value: Double): string;
begin
  if FSettings.RoundReadings then
    Result := P.FormatValue(Value, P.TidyDecimals)
  else
    Result := P.FormatValue(Value);
end;

{ Live row I's current reading ('' before the first one). }
function TMainForm.LiveValueText(I: Integer; P: TPidDef): string;
begin
  if (I > High(FLive.Text)) or (FLive.Text[I] = '') then
    Exit('');
  if FSettings.RoundReadings and (I <= High(FLive.Values)) then
    Result := ReadingText(P, FLive.Values[I])
  else
    Result := FLive.Text[I];
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
  Icon(btnChart);
  Icon(btnFullScreen);
  Icon(btnPidPanel);
  if FExitFull <> nil then
  begin
    FExitFull.Fill.Color := P.Panel;
    TPath(FExitFull.Controls[0]).Stroke.Color := P.Text;
  end;
  if FAddGauge <> nil then
  begin
    FAddGauge.Fill.Color := P.Accent;
    TPath(FAddGauge.Controls[0]).Stroke.Color := ContrastColor(P.Accent);
    Muted(FDashEmpty);
  end;
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
  for I := 0 to High(FNavButtons) do
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
  button at the right end, so they fit a phone as well as a wide window. A
  narrow box puts the caption above the field. }
procedure TMainForm.FitFormRows;
const
  RowTop = 32;

  // Lays out a row at the top of Box; the result is where the next control goes.
  function Row(Cap: TLabel; Field, Btn: TControl; Box: TControl; Top: Single = RowTop): Single;
  var
    X, R: Single;
  begin
    Result := Top + Field.Height + 8;
    if Box.Width < 50 then
      Exit; // not laid out yet
    X := 12;
    Field.Position.Y := Top;
    if Cap <> nil then
    begin
      Cap.WordWrap := False;
      FitTextWidth(Cap);
      Cap.Position.X := 12;
      if Box.Width < 480 then
      begin
        Cap.Position.Y := Top - 2;
        Cap.Height := 24;
        Field.Position.Y := Top + 24;
      end
      else
      begin
        Cap.Height := 22;
        Cap.Position.Y := Top + (Field.Height - Cap.Height) / 2;
        X := 12 + Cap.Width + 12;
      end;
    end;
    if Btn <> nil then
      Btn.Position.Y := Field.Position.Y;
    Result := Field.Position.Y + Field.Height + 8;
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

var
  Y: Single;

  procedure Wide(C: TControl; Box: TControl);
  begin
    if Box.Width >= 50 then
      C.Width := Box.Width - C.Position.X - 12;
  end;

begin
  Y := Row(lblTheme, cbTheme, nil, gbAppearance);
  if gbAppearance.Width >= 50 then
  begin
    // the check boxes wrap on a narrow screen
    Wide(chkKeepAwake, gbAppearance);
    chkKeepAwake.TextSettings.WordWrap := True;
    chkKeepAwake.Height := Max(30, WrappedTextHeight(chkKeepAwake, chkKeepAwake.Width - 40) + 8);
    chkKeepAwake.Position.Y := Y;
    Y := Y + chkKeepAwake.Height + 4;
    Wide(chkRound, gbAppearance);
    chkRound.TextSettings.WordWrap := True;
    chkRound.Height := Max(30, WrappedTextHeight(chkRound, chkRound.Width - 40) + 8);
    chkRound.Position.Y := Y;
    Y := Y + chkRound.Height + 4;
    if chkLockRotate.Visible then
    begin
      Wide(chkLockRotate, gbAppearance);
      chkLockRotate.TextSettings.WordWrap := True;
      chkLockRotate.Height := Max(30, WrappedTextHeight(chkLockRotate, chkLockRotate.Width - 40) + 8);
      chkLockRotate.Position.Y := Y;
      Y := Y + chkLockRotate.Height + 4;
    end;
    gbAppearance.Height := Y + 6;
  end;
  Y := Row(lblLogFolderCaption, edtLogFolder, btnBrowseLogFolder, gbLogging);
  if cbAway.Visible then
    Y := Row(lblAway, cbAway, nil, gbLogging, Y + 6);
  if gbLogging.Width >= 50 then
    gbLogging.Height := Y + 4;
  Y := Row(lblRate, cbRate, nil, gbStream);
  if gbStream.Width >= 50 then
    gbStream.Height := Y + 4;
  Row(nil, edtNewVin, btnWriteVin, gbWriteVin);
  Row(nil, edtRaw, btnSendRaw, gbAdvanced);
  Wide(lblRaw, gbAdvanced);
  Wide(chkTrace, gbAdvanced);
  Wide(chkSound, gbAlerts);
  Wide(chkKeepAwake, gbAppearance);
  Wide(chkRound, gbAppearance);
  Wide(lblDiscoverHelp, gbDiscover);
  lblDiscoverHelp.WordWrap := True;
  // Advanced: caption, then the frame row, then the trace box, one under another.
  if gbAdvanced.Width >= 50 then
  begin
    lblRaw.WordWrap := True;
    lblRaw.Position.Y := 34;
    lblRaw.Height := WrappedTextHeight(lblRaw, lblRaw.Width);
    edtRaw.Position.Y := lblRaw.Position.Y + lblRaw.Height + 4;
    btnSendRaw.Position.Y := edtRaw.Position.Y;
    chkTrace.Position.Y := edtRaw.Position.Y + edtRaw.Height + 8;
    gbAdvanced.Height := chkTrace.Position.Y + chkTrace.Height + 10;
  end;
  if gbDiscover.Width >= 50 then
  begin
    FitTextWidth(btnDiscoverPids);
    btnDiscoverPids.Width := Min(btnDiscoverPids.Width, gbDiscover.Width - 24);
    btnDiscoverPids.Position.Y := 34;
    lblDiscoverHelp.Position.Y := btnDiscoverPids.Position.Y + btnDiscoverPids.Height + 6;
  end;
end;

{ Boxes with word-wrapped text grow to show all of it (a phone wraps a lot). }
procedure TMainForm.FitWrappedText;
var
  H: Single;
begin
  // Status strip: wraps on a phone rather than hiding the VIN and the rate.
  if pnlStatus.Width > 50 then
  begin
    lblStatus.WordWrap := True;
    lblStatus.TextSettings.Trimming := TTextTrimming.None;
    H := WrappedTextHeight(lblStatus, pnlStatus.Width - lblStatus.Position.X - lblStatus.Margins.Right);
    // A short screen keeps its height for the pages: one line, cut short
    // (tap the strip for the Connect page with all of it).
    if FRail or (IsMobile and (InnerHeight(Self) < 700)) then
    begin
      H := WrappedTextHeight(lblStatus, 100000);
      lblStatus.WordWrap := False;
      lblStatus.TextSettings.Trimming := TTextTrimming.Character;
    end;
    pnlStatus.Height := Max(28, H + 8);
  end;
  if pnlNotice.Width > 50 then
  begin
    lblNotice.WordWrap := True;
    H := WrappedTextHeight(lblNotice, pnlNotice.Width - lblNotice.Margins.Left - lblNotice.Margins.Right);
    pnlNotice.Height := Max(30, H + 10);
  end;
  if pnlCtlWarn.Width > 50 then
  begin
    lblCtlWarn.WordWrap := True;
    H := WrappedTextHeight(lblCtlWarn, pnlCtlWarn.Width - lblCtlWarn.Margins.Left - lblCtlWarn.Margins.Right);
    pnlCtlWarn.Height := H + lblCtlWarn.Margins.Top + lblCtlWarn.Margins.Bottom + 4;
  end;
  if pnlCtlRun.Width > 50 then
  begin
    lblCtlNotes.WordWrap := True;
    lblCtlNotes.Height := Max(18, WrappedTextHeight(lblCtlNotes, pnlCtlRun.Width - pnlCtlRun.Padding.Left -
      pnlCtlRun.Padding.Right));
  end;
  if gbDiscover.Width > 50 then
  begin
    lblDiscoverHelp.WordWrap := True;
    lblDiscoverHelp.Height := WrappedTextHeight(lblDiscoverHelp, lblDiscoverHelp.Width);
    gbDiscover.Height := lblDiscoverHelp.Position.Y + lblDiscoverHelp.Height + 12;
  end;
end;

procedure TMainForm.FlowBoxResized(Sender: TObject);
begin
  if FFlowQueued then
    Exit;
  FFlowQueued := True;
  TThread.ForceQueue(nil,
    procedure
    begin
      FFlowQueued := False;
      FitFlowHeights;
    end);
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

  procedure FitHint(L: TLabel; Bar: TControl);
  begin
    L.WordWrap := False;
    L.TextSettings.Trimming := TTextTrimming.Character;
    FitTextWidth(L);
    if Bar.Width > 50 then
      L.Width := Min(L.Width, Bar.Width - Bar.Padding.Left - Bar.Padding.Right - 4);
  end;

  // Bar as tall as Flow's rows. The rows are worked out here from the widths
  // (as the flow layout will wrap them): the flow itself may not have been
  // laid out yet - on a page that was hidden while the window was resized,
  // or right after FitWidths changed the widths.
  procedure Fit(Flow: TFlowLayout; Bar: TControl; Extra: Single);
  var
    I: Integer;
    C: TControl;
    W, X, Y, RowH, CW, Bottom: Single;
  begin
    if Flow = Bar then
      W := Flow.Width
    else
      W := Bar.Width - Bar.Padding.Left - Bar.Padding.Right - Flow.Margins.Left - Flow.Margins.Right;
    W := W - Flow.Padding.Left - Flow.Padding.Right;
    if W < 50 then
      Exit; // not laid out at all yet
    X := 0;
    Y := 0;
    RowH := 0;
    for I := 0 to Flow.ControlsCount - 1 do
    begin
      C := Flow.Controls[I];
      if not C.Visible then
        Continue;
      CW := C.Width + C.Margins.Left + C.Margins.Right;
      if (X > 0) and (X + CW > W + 0.5) then
      begin
        Y := Y + RowH + Flow.VerticalGap;
        X := 0;
        RowH := 0;
      end;
      X := X + CW + Flow.HorizontalGap;
      RowH := Max(RowH, C.Height + C.Margins.Top + C.Margins.Bottom);
    end;
    if RowH <= 0 then
      Exit;
    Bottom := Flow.Padding.Top + Y + RowH + Flow.Padding.Bottom + Extra;
    if Abs(Bar.Height - Bottom) > 0.5 then
      Bar.Height := Bottom;
  end;

begin
  if FClosing then
    Exit;
  FitWidths(pnlLiveFooter, 0);
  // The hints: one line, as wide as their text; cut short only past the bar's width.
  FitHint(lblLiveHint, pnlLiveFooter);
  FitHint(lblDashHint, pnlDashBar);
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
  FitWrappedText;
  // Connect page: group boxes around flow layouts (title + padding = 36).
  Fit(flAdapter, gbAdapter, 36);
  Fit(flScan, gbScan, 36);
  Fit(flLogRec, gbLogRec, 36);
  Fit(pnlLiveFooter, pnlLiveFooter, 0);
  Fit(pnlDashBar, pnlDashBar, 0);
  Fit(pnlCtlBar, pnlCtlBar, 0);
  Fit(flPidButtons, pnlPidFooter, lblBudget.Height);
  // (beside the list it is as tall as the page: setting its height would only
  // resize it back and start this again)
  if pnlCtlRun.Align = TAlignLayout.Bottom then
    Fit(flCtlRun, pnlCtlRun, lblCtlName.Height + lblCtlNotes.Height + pnlCtlRun.Padding.Top + pnlCtlRun.Padding.Bottom);
end;

{ The legacy UVSCAN switches -port, -connect, -scan, -log, and the quick
  start ones (-list, -dashboard, -fullscreen, -chart, -retry, -quick <name>):
  see UVScan.QuickStart. A desktop shortcut made by Quick start has them. }
procedure TMainForm.ApplyCommandLine;
var
  Q: TQuickStart;
  Problem: string;
begin
  if not QuickStartFromCommandLine(FSettings.QuickStarts, Q, Problem) then
  begin
    ShowNotice('Command line: ' + Problem, True);
    Exit;
  end;
  if Q.Any then
    TThread.ForceQueue(nil,
      procedure
      begin
        RunQuickStart(Q);
      end);
end;

{ Carries out a quick start: the scan list and dashboard at once, then
  connect, scan, log and the live chart one after the other as each is ready
  (see the engine events). With Retry a failed or lost connection is tried
  again every 3 s, until the user stops the scan or disconnects. }
procedure TMainForm.RunQuickStart(const Q: TQuickStart);
var
  PortName: string;
  I, D: Integer;
begin
  CloseActionMenu;
  if FTestMode then
    StopTest;
  FQuick := Q;
  FQuickActive := Q.Connect;
  FRetryAt := 0;
  if Q.Name <> '' then
    AddMessage(Format('Quick start "%s": %s', [Q.Name, Q.Describe]))
  else
    AddMessage('Starting: ' + Q.Describe);
  if Q.Port <> '' then
  begin
    PortName := Q.Port;
    if IsTcpAddress(PortName) then
    begin
      // 192.168.2.99:10001 (or tcp:...): the network AVT at that address
      edtTcpAddress.Text := PortName;
      PortName := NetworkPort;
    end;
    if cbPort.Items.IndexOf(PortName) < 0 then
      cbPort.Items.Insert(0, PortName);
    cbPort.ItemIndex := cbPort.Items.IndexOf(PortName);
    PortChanged(nil);
  end;
  if Q.List <> '' then
  begin
    I := FLists.IndexOf(Q.List);
    if I < 0 then
      ShowNotice(Format('There is no scan list "%s"; scanning the ticked PIDs', [Q.List]), True)
    else if FState in [esDisconnected, esConnected] then
    begin
      cbLists.ItemIndex := cbLists.Items.IndexOf(FLists[I].Name);
      cbListsChange(nil); // ticks its PIDs (also when it was chosen already)
    end
    else if not SameText(ComboText(cbLists), FLists[I].Name) then
      ShowNotice('Scanning already: stop the scan to change the scan list', True);
  end;
  // The dashboard: the one asked for, or the scan list's.
  D := -1;
  if Q.Dashboard <> '' then
  begin
    D := FDisplay.IndexOfDashboard(Q.Dashboard);
    if D < 0 then
      ShowNotice(Format('There is no dashboard "%s"', [Q.Dashboard]), True);
  end
  else if Q.List <> '' then
    D := FDisplay.IndexOfDashboard(Q.List);
  FQuickDash := '';
  if D >= 0 then
  begin
    SelectDashboard(D);
    FQuickDash := FDisplay.Dashboards[D].Name;
  end;
  if Q.FullScreen then
    SetFullScreen(True)
  else if (D >= 0) and not Q.Chart then
    ShowPage(tiDashboard);
  if Q.Connect then
    QuickConnect;
end;

{ The next step of the quick start from where things are now. }
procedure TMainForm.QuickConnect;
begin
  FAutoScan := FQuick.Scan;
  FAutoLog := FQuick.Log;
  FAutoChart := FQuick.Chart;
  case FState of
    esDisconnected:
      btnConnectClick(nil);
    esConnected:
      if FAutoScan then
      begin
        FAutoScan := False;
        btnStartScanClick(nil);
      end;
    esScanning:
      begin
        FAutoScan := False;
        if FAutoLog and not FLogging then
          btnLogClick(nil);
        FAutoLog := False;
        if FAutoChart then
          LiveChartClick(nil);
        FAutoChart := False;
      end;
  end;
end;

procedure TMainForm.QuickStartClick(Sender: TObject);
begin
  ShowQuickMenu(0);
end;

{ The Quick start menu. Action 0: each quick start runs, with New / Edit /
  Delete / Desktop shortcut below; 1..3: pick the quick start to edit,
  delete or make a shortcut for. }
procedure TMainForm.ShowQuickMenu(Action: Integer);
var
  Items: TArray<TActionItem>;
  It: TActionItem;
  Pick: TComponent;
  I: Integer;
  Pt: TPointF;

  procedure Add(const Text: string; Handler: TNotifyEvent; Tag: Integer; Enabled: Boolean = True);
  begin
    Pick := TComponent.Create(FQuickPicks);
    Pick.Tag := Tag;
    It := Default(TActionItem);
    It.Text := Text;
    It.Enabled := Enabled;
    It.OnClick := Handler;
    It.Sender := Pick;
    Items := Items + [It];
  end;

begin
  FQuickPicks.Free;
  FQuickPicks := TComponent.Create(Self);
  FQuickAction := Action;
  Items := nil;
  case Action of
    1: Add('Edit which quick start?', nil, -1, False);
    2: Add('Delete which quick start?', nil, -1, False);
    3: Add('Desktop shortcut for which?', nil, -1, False);
  end;
  for I := 0 to High(FSettings.QuickStarts) do
    if Action = 0 then
      Add(FSettings.QuickStarts[I].Name + '  -  ' + FSettings.QuickStarts[I].Describe, QuickPickClick, I)
    else
      Add(FSettings.QuickStarts[I].Name, QuickPickClick, I);
  if Action = 0 then
  begin
    if Items <> nil then
      Add('-', nil, -1);
    Add('New quick start...', QuickNewClick, -1);
    Add('Edit a quick start...', QuickChooseClick, 1, FSettings.QuickStarts <> nil);
    Add('Delete a quick start...', QuickChooseClick, 2, FSettings.QuickStarts <> nil);
    {$IFDEF MSWINDOWS}
    Add('Desktop shortcut for one...', QuickChooseClick, 3, FSettings.QuickStarts <> nil);
    {$ENDIF}
  end;
  if (CurrentPage = tiConnect) and btnQuick.IsVisible then
    Pt := btnQuick.LocalToAbsolute(TPointF.Create(0, btnQuick.Height))
  else
    Pt := btnMenu.LocalToAbsolute(TPointF.Create(btnMenu.Width, btnMenu.Height));
  ShowActionMenu(Self, Items, Pt);
end;

procedure TMainForm.QuickChooseClick(Sender: TObject);
begin
  // the menu is closing: open the next one after it
  TThread.ForceQueue(nil,
    procedure
    begin
      ShowQuickMenu(TComponent(Sender).Tag);
    end);
end;

procedure TMainForm.QuickPickClick(Sender: TObject);
var
  I: Integer;
  Q: TQuickStart;
  FileName: string;
begin
  I := TComponent(Sender).Tag;
  if (I < 0) or (I > High(FSettings.QuickStarts)) then
    Exit;
  Q := FSettings.QuickStarts[I];
  case FQuickAction of
    0: TThread.ForceQueue(nil,
         procedure
         begin
           RunQuickStart(Q);
         end);
    1: TThread.ForceQueue(nil,
         procedure
         begin
           EditQuick(I);
         end);
    2: Confirm(Format('Delete the quick start "%s"?', [Q.Name]),
         procedure
         var
           J: Integer;
         begin
           J := IndexOfQuickStart(FSettings.QuickStarts, Q.Name);
           if J >= 0 then
             Delete(FSettings.QuickStarts, J, 1);
           SaveSettings;
         end);
    3:
      {$IFDEF MSWINDOWS}
      try
        FileName := CreateQuickStartShortcut(Q);
        AddMessage('Desktop shortcut: ' + FileName + '  (UVScan.exe ' + Q.Arguments + ')');
        ShowNotice(Format('Made "%s" on the desktop', [ExtractFileName(FileName)]), False);
      except
        on E: Exception do
          ShowWarning('Could not make the shortcut: ' + E.Message);
      end;
      {$ELSE}
      ;
      {$ENDIF}
  end;
end;

procedure TMainForm.QuickNewClick(Sender: TObject);
begin
  TThread.ForceQueue(nil,
    procedure
    begin
      EditQuick(-1);
    end);
end;

{ Index -1: a new one, starting from what is chosen now. }
procedure TMainForm.EditQuick(Index: Integer);
var
  Q: TQuickStart;
  Taken: TArray<string>;
  I: Integer;
begin
  if Index >= 0 then
    Q := FSettings.QuickStarts[Index]
  else
  begin
    Q := Default(TQuickStart);
    if cbLists.ItemIndex > 0 then
    begin
      Q.List := ComboText(cbLists);
      Q.Name := Q.List;
    end;
    if FDisplay.DashboardCount > 0 then
      Q.Dashboard := FDisplay.Dashboards[FDisplay.Current].Name;
    Q.Scan := True;
    Q.Normalize;
  end;
  Taken := nil;
  for I := 0 to High(FSettings.QuickStarts) do
    if I <> Index then
      Taken := Taken + [FSettings.QuickStarts[I].Name];
  EditQuickStart(Q, FLists.Names, FDisplay.DashboardNames, Taken,
    IfThen(Index >= 0, 'Edit quick start', 'New quick start'),
    procedure(R: TQuickStart)
    var
      J: Integer;
    begin
      J := IndexOfQuickStart(FSettings.QuickStarts, Q.Name);
      if (Index >= 0) and (J >= 0) then
        FSettings.QuickStarts[J] := R
      else
        FSettings.QuickStarts := FSettings.QuickStarts + [R];
      SaveSettings;
      AddMessage(Format('Quick start "%s": %s  (command line: %s)', [R.Name, R.Describe, R.Arguments]));
    end);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FClosing := True;
  TMessageManager.DefaultManager.Unsubscribe(TThemeChangedMessage, FThemeSub);
  KeepAwake(False);
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
  TLogViewerForm.SetLiveSource(nil);
  FLiveLog.Free;
  ClearAwayNote;
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
  if (Key = vkF11) and (Shift = []) then
  begin
    SetFullScreen(not FFullScreen);
    Key := 0;
  end
  else if (Shift = [ssCtrl]) and ((Key = vkL) or (KeyChar = 'l') or (KeyChar = 'L')) and FWide then
  begin
    TogglePidPanelClick(nil);
    Key := 0;
    KeyChar := #0;
  end
  else if (Key = vkF7) and (Shift = []) then
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
  if (WindowState = TWindowState.wsNormal) and not FFullScreen then
    FNormalBounds := TRect.Create(Left, Top, Left + Width, Top + Height);
  ArrangeLayout;
  QueueGridLayout;
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
    for F in AddNewBuiltIns do
      AddMessage('Added the built-in ' + F);
  except
    on E: Exception do
      AddMessage('Could not add the new built-in scan lists and chart views: ' + E.Message);
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

  if FSettings.PendingNotice <> '' then
  begin
    AddMessage('Last time: ' + FSettings.PendingNotice);
    ShowNotice('Last time ' + FSettings.PendingNotice, False);
    FSettings.PendingNotice := '';
  end;
  edtTcpAddress.Text := FSettings.TcpAddress;
  FillPorts(FSettings.Port);
  cbBaud.ItemIndex := Max(0, cbBaud.Items.IndexOf(IntToStr(FSettings.Baud)));
  edtLogFolder.Text := FSettings.LogFolder;
  cbAway.ItemIndex := High(AwayChoices);
  for N := High(AwayChoices) downto 0 do
    if AwayChoices[N] >= FSettings.BackgroundStop then
      cbAway.ItemIndex := N;
  cbRate.ItemIndex := Ord(FSettings.StreamSpeed);
  chkTrace.IsChecked := FSettings.Trace;
  chkSound.IsChecked := FSettings.AlertSounds;
  chkMinMax.IsChecked := FSettings.ShowMinMax;
  cbTheme.ItemIndex := Ord(ThemeModeFromKey(FSettings.Theme));
  chkKeepAwake.IsChecked := FSettings.KeepScreenOn;
  KeepAwake(FSettings.KeepScreenOn);
  chkRound.IsChecked := FSettings.RoundReadings;
  chkLockRotate.IsChecked := FSettings.LockRotation;
  LockRotation(FSettings.LockRotation);
  for N in FSettings.SelectedPids do
    if (FCatalog.FindById(N) <> nil) and FCatalog.FindById(N).Enabled and not FSelected.Contains(N) then
      FSelected.Add(N);
  FillLists(FSettings.ActiveList);
  if FSettings.Window.Saved and not IsMobile then
  begin
    // Designed: where it was saved, even at the form's own 0,0 (Default lets
    // Windows cascade it then, maybe past the bottom of the screen)
    Position := TFormPosition.Designed;
    SetBounds(FSettings.Window.Left, FSettings.Window.Top, FSettings.Window.Width, FSettings.Window.Height);
    // Keep the window on a screen that still exists.
    if (Left > Screen.Width - 100) or (Top > Screen.Height - 100) or (Left + Width < 100) or (Top < -20) then
    begin
      Left := 40;
      Top := 40;
    end;
    FitToScreen(Self); // the screen turned upright since (a tablet), or a smaller one
    FNormalBounds := TRect.Create(Left, Top, Left + Width, Top + Height);
    if FSettings.Window.Maximized then
      WindowState := TWindowState.wsMaximized;
    if FSettings.Window.PidPanelWidth > 0 then
      pnlPids.Width := FSettings.Window.PidPanelWidth;
  end
  else if not IsMobile then
  begin
    FitToScreen(Self); // a first run on a screen smaller than the designed window
    Position := TFormPosition.ScreenCenter;
  end;
end;

procedure TMainForm.SaveSettings;
begin
  FSettings.Port := ComboText(cbPort);
  FSettings.Baud := StrToIntDef(ComboText(cbBaud), 115200);
  FSettings.TcpAddress := Trim(edtTcpAddress.Text);
  FSettings.LogFolder := edtLogFolder.Text;
  if cbAway.ItemIndex >= 0 then
    FSettings.BackgroundStop := AwayChoices[cbAway.ItemIndex];
  FSettings.StreamSpeed := TStreamSpeed(Max(0, cbRate.ItemIndex));
  FSettings.Trace := chkTrace.IsChecked;
  FSettings.AlertSounds := chkSound.IsChecked;
  FSettings.LiveZoom := FZoom;
  FSettings.ShowMinMax := chkMinMax.IsChecked;
  FSettings.Theme := ThemeKeys[TThemeMode(Max(0, cbTheme.ItemIndex))];
  FSettings.KeepScreenOn := chkKeepAwake.IsChecked;
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
    if FFullScreen then
      FSettings.Window.Maximized := FWasMaximized
    else
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
    cbPort.Items.Add(NetworkPort);
    cbPort.Items.Add(SimulatorPort);
    // The port chosen before but not plugged in now stays the choice (not
    // whatever comes first): connecting reports it missing, and a quick start
    // that keeps trying connects once it is plugged in.
    if (Select <> '') and (cbPort.Items.IndexOf(Select) < 0) then
      cbPort.Items.Insert(0, Select);
  finally
    cbPort.Items.EndUpdate;
  end;
  cbPort.ItemIndex := cbPort.Items.IndexOf(Select);
  if cbPort.ItemIndex < 0 then
    cbPort.ItemIndex := 0;
  PortChanged(nil);
end;

{ A network AVT has an address instead of a baud rate (the interface's
  serial side has its own), and no port list to refresh (the page menu
  still has Refresh ports). }
procedure TMainForm.PortChanged(Sender: TObject);
var
  Network: Boolean;
begin
  if edtTcpAddress = nil then
    Exit;
  Network := ComboText(cbPort) = NetworkPort;
  if (edtTcpAddress.Visible = Network) and (cbBaud.Visible = not Network) then
    Exit;
  edtTcpAddress.Visible := Network;
  cbBaud.Visible := not Network;
  btnRefreshPorts.Visible := not Network;
  FlowBoxResized(nil); // the row's height may change
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
  grdPids.AutoRowHeights;
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
  SettingsChanged;
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
  SettingsChanged;
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
          FLists.Put(Name, RankLiveIds(FSelected.ToArray)); // in the live rows' order
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
  SettingsChanged;
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
  PortName, Host: string;
  Baud: Cardinal;
  TcpPort: Word;
begin
  PortName := ComboText(cbPort);
  if PortName = '' then
  begin
    FQuickActive := False; // trying again would not help
    ShowNotice('Choose a port first', True);
    Exit;
  end;
  Baud := StrToIntDef(ComboText(cbBaud), 115200);
  SettingsChanged; // the port and speed
  {$IFDEF ANDROID}
  // Android 13+: notifications need the user's yes (for the one shown while away).
  if TOSVersion.Check(13) and not PermissionsService.IsPermissionGranted('android.permission.POST_NOTIFICATIONS') then
    PermissionsService.RequestPermissions(['android.permission.POST_NOTIFICATIONS'],
      procedure(const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray)
      begin
        if (Length(AGrantResults) > 0) and (AGrantResults[0] <> TPermissionStatus.Granted) then
          AddMessage('Notifications are off: leaving UVScan while scanning will not show one');
      end);
  {$ENDIF}
  Cmd := Command(ecConnect);
  if PortName = NetworkPort then
  begin
    if not ParseTcpAddress(edtTcpAddress.Text, Host, TcpPort) then
    begin
      FQuickActive := False; // trying again would not help
      UpdateControls;
      ShowNotice(Format('Type the interface''s address, e.g. 192.168.2.99:%d', [DefaultTcpPort]), True);
      if edtTcpAddress.CanFocus then
        edtTcpAddress.SetFocus;
      Exit;
    end;
    Cmd.Factory :=
      function: ISerialPort
      begin
        Result := TTcpSerialPort.Create(Host, TcpPort);
      end;
    PortName := Format('%s:%d', [Host, TcpPort]);
  end
  else if PortName = SimulatorPort then
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
  FQuickActive := False; // no more retries
  FRetryAt := 0;
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
  FQuickActive := False; // no more retries
  FRetryAt := 0;
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
        if Ev.Flag then
        begin
          // Stopped for being away: a quick start does not connect again
          // behind the user's back (the next stop would only follow).
          FQuickActive := False;
          FRetryAt := 0;
        end;
        if Ev.Flag and (FAwaySince <> 0) then
        begin
          // Stopped while away: Android may end the app before the user is
          // back, so the notice is kept for the next start too.
          FSettings.PendingNotice := Ev.Text;
          SaveSettings;
          ShowAwayNote('UVScan stopped', Ev.Text);
        end;
      end;
    eeError:
      begin
        AddMessage('Error: ' + Ev.Text);
        ShowNotice(Ev.Text, True);
      end;
    eeStreamBack:
      begin
        AddMessage(Ev.Text);
        if lblNotice.Text.StartsWith('No data from the PCM') then
          pnlNotice.Visible := False;
      end;
    eeState:
      begin
        FState := Ev.State;
        SetStatus(spState, StateNames[FState]);
        if FState <> esScanning then
        begin
          grdLive.Refresh;
          RefreshDashboard;
          if not FTestMode then
            SetStatus(spRate, ''); // no updates any more
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
          FAutoChart := False;
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
        if FQuickActive and (FQuickDash <> '') and (FDisplay.IndexOfDashboard(FQuickDash) >= 0) then
          SelectDashboard(FDisplay.IndexOfDashboard(FQuickDash)); // the quick start's
        if FAutoLog then
        begin
          FAutoLog := False;
          btnLogClick(nil);
        end;
        if FAutoChart then
        begin
          FAutoChart := False;
          LiveChartClick(nil);
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
        if grdDtcs.AutoHeights then
          grdDtcs.AutoRowHeights; // descriptions wrap on a phone
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
          AddMessage('Log saved: ' + FLastLogFile + IfThen(IsMobile, '', '  (F7 opens it in the log viewer)'));
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
  UpdateFullState;
  Connected := FState in [esConnected, esScanning, esBusy];
  Idle := FState = esConnected;
  cbPort.Enabled := FState = esDisconnected;
  cbBaud.Enabled := FState = esDisconnected;
  edtTcpAddress.Enabled := FState = esDisconnected;
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
      if FQuickActive and FQuick.Retry then
      begin
        btnAction.Text := 'Stop trying'; // a quick start that keeps connecting
        btnAction.Enabled := True;
      end
      else
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

{ Saves soon (from the refresh timer): Android may end the app without
  closing it - updated, force-stopped, short of memory - and the ticked PIDs
  or the port would be lost. }
procedure TMainForm.SettingsChanged;
begin
  FSaveDue := TThread.GetTickCount64 + 1000;
end;

procedure TMainForm.tmrRefreshTimer(Sender: TObject);
var
  I: Integer;
  V: Double;
  Phase, Repaint, Charted: Boolean;
  Samples: TArray<TLiveSample>;
  Raw: TLiveSnapshot;
begin
  FlushMessages;
  if (FSaveDue <> 0) and (TThread.GetTickCount64 >= FSaveDue) then
  begin
    FSaveDue := 0;
    SaveSettings;
  end;
  // Quick start with Retry: not connected (it failed, or the link went) -
  // again in 3 s. (A port that does not open never leaves Disconnected.)
  if FQuickActive and FQuick.Retry and (FState = esDisconnected) then
  begin
    if FRetryAt = 0 then
    begin
      FRetryAt := TThread.GetTickCount64 + 3000;
      SetStatus(spRate, 'trying again in 3 s');
      UpdateControls; // the main button: Stop trying
    end
    else if TThread.GetTickCount64 >= FRetryAt then
    begin
      FRetryAt := 0;
      SetStatus(spRate, 'connecting again');
      QuickConnect;
    end;
  end
  else
    FRetryAt := 0;
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
  Samples := nil;
  if FTestMode then
    Raw := TestSnapshot
  else
  begin
    Raw := FEngine.GetSnapshot;
    Samples := FEngine.TakeSamples;
  end;
  FLive := DisplaySnapshot(Raw);
  if Length(FLive.Values) <> Length(FLiveIds) then
    Exit;
  // The live chart (its channels in the scan's order): every cycle of the
  // scan; the test display as shown.
  Charted := False;
  if FTestMode then
  begin
    if FLive.Cycles <> FShownCycles then
      Charted := AddLiveSample((TThread.GetTickCount64 - FLiveStart) / 1000, Raw.Text);
  end
  else
    for var S in Samples do
      Charted := AddLiveSample(S.Time, S.Text) or Charted;
  if Charted then
    TLogViewerForm.LiveChanged(False);
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
var
  Names, Units: TArray<string>;
  Switches: TArray<Boolean>;
  Id, R: Integer;
  P: TPidDef;
  Fmt: string;
begin
  FEngineIds := Copy(Ids);
  FLiveIds := RankLiveIds(Ids);
  SetLength(FRowEngine, Length(FLiveIds));
  for R := 0 to High(FLiveIds) do
    FRowEngine[R] := TArray.IndexOf<Integer>(FEngineIds, FLiveIds[R]);
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
  // The live chart: one channel per PID, named like the columns of a log so
  // saved log views fit it too.
  Names := nil;
  Units := nil;
  Switches := nil;
  for Id in Ids do
  begin
    P := FCatalog.FindById(Id);
    if P <> nil then
    begin
      Names := Names + [P.DisplayName];
      Units := Units + [P.Units];
      Fmt := LowerCase(P.ResultFormat);
      Switches := Switches + [(Pos('%o', Fmt) > 0) or (Pos('%y', Fmt) > 0)];
    end
    else
    begin
      Names := Names + ['#' + IntToStr(Id)];
      Units := Units + [''];
      Switches := Switches + [False];
    end;
  end;
  FLiveLog.StartLive(IfThen(FTestMode, 'Test display', 'Live scan'), Names, Units, Switches);
  FLiveStart := TThread.GetTickCount64;
  // A scan list's own chart view and dashboard (the built-in lists each have both).
  if not FTestMode and (cbLists.ItemIndex > 0) then
  begin
    TLogViewerForm.SuggestLiveView(ComboText(cbLists));
    SelectDashboard(FDisplay.IndexOfDashboard(ComboText(cbLists)));
  end
  else
    TLogViewerForm.SuggestLiveView('');
  TLogViewerForm.LiveChanged(True);
end;

{ A sample of the live chart, read back from the values' text like a log (so
  units conversions and ON / OFF match a log). The last 15 minutes are kept. }
function TMainForm.AddLiveSample(const Time: Double; const Text: TArray<string>): Boolean;
const
  KeepSeconds = 15 * 60;
var
  Values: TArray<Double>;
  I: Integer;
  Switch: Boolean;
begin
  Result := (FLiveLog.ChannelCount = Length(FLiveIds)) and (Length(Text) = Length(FLiveIds));
  if not Result then
    Exit;
  SetLength(Values, Length(FLiveIds));
  for I := 0 to High(FLiveIds) do
    if FRejected.Contains(FLiveIds[I]) then
      Values[I] := NaN
    else
      Values[I] := ParseLogValue(Text[I], Switch);
  FLiveLog.Append(Time, Values, KeepSeconds);
end;

{ Phone: the notification while away (one, replaced as things change; a tap
  brings UVScan back). }
procedure TMainForm.ShowAwayNote(const Title, Body: string);
var
  N: TNotification;
begin
  if FNotes = nil then
    Exit;
  N := FNotes.CreateNotification;
  try
    N.Name := AwayNote;
    N.Title := Title;
    N.AlertBody := Body;
    N.ChannelId := AwayChannel;
    N.EnableSound := False;
    FNotes.CancelNotification(AwayNote);
    FNotes.PresentNotification(N);
  finally
    N.Free;
  end;
end;

procedure TMainForm.ClearAwayNote;
begin
  if FNotes <> nil then
    FNotes.CancelNotification(AwayNote);
end;

procedure TMainForm.LiveChartClick(Sender: TObject);
begin
  TLogViewerForm.ShowLive(FCatalog, FDisplay, LogFolder, LogViewsFile);
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
  Result.PidIds := FEngineIds; // like the engine's: DisplaySnapshot puts it in row order
  SetLength(Result.Values, Length(FEngineIds));
  SetLength(Result.Text, Length(FEngineIds));
  T := (TThread.GetTickCount64 - FTestStart) / 1000;
  for I := 0 to High(FEngineIds) do
  begin
    P := FCatalog.FindById(FEngineIds[I]);
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
    // A wrapped PID name may need more lines than that.
    if FGridCompact then
    begin
      grdLive.RowHeights[I] := Max(grdLive.RowHeights[I],
        grdLive.WrappedTextHeight(ColName, PidName(FLiveIds[I]), grdLive.FontSize));
      if FCatalog.FindById(FLiveIds[I]) <> nil then
        grdLive.RowHeights[I] := Max(grdLive.RowHeights[I],
          grdLive.WrappedTextHeight(ColUnits, FCatalog.FindById(FLiveIds[I]).Units, grdLive.FontSize));
    end;
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
{ True when the live columns share the grid's width: always on a phone, and
  on a window too narrow for the usual widths at this zoom. }
function TMainForm.LiveGridCompact: Boolean;
var
  Need: Single;
begin
  Need := Z(160) + Z(140) + Z(80) + 14;
  if chkMinMax.IsChecked then
    Need := Need + 2 * Z(100);
  if grdLive.Width <= 50 then
    Result := IsMobile // not laid out yet: a phone most likely is narrow
  else
    Result := grdLive.Width < Need;
end;

{ After a resize: lay the live grid out again if it changes between compact
  and normal (or is compact: its columns follow the width). Once per burst. }
procedure TMainForm.QueueGridLayout;
begin
  if FGridQueued then
    Exit;
  FGridQueued := True;
  TThread.ForceQueue(nil,
    procedure
    begin
      FGridQueued := False;
      if FGridCompact or LiveGridCompact then
        ApplyGridLayout;
      ApplyPageGridColumns;
    end);
end;

procedure TMainForm.ApplyGridLayout;
var
  W: Single;
begin
  if grdLive = nil then
    Exit; // the form is still loading
  grdLive.SetColumnVisible(ColMin, chkMinMax.IsChecked);
  grdLive.SetColumnVisible(ColMax, chkMinMax.IsChecked);
  grdLive.RowHeight := Z(30);
  grdLive.HeaderHeight := Z(26);
  grdLive.FontSize := Z(13);
  grdLive.CellPadding := Z(6);
  FGridCompact := LiveGridCompact;
  grdLive.ReserveScrollBar := FGridCompact; // wrapped names keep fitting when it shows
  grdLive.SetColumnShrink(ColUnits, FGridCompact); // "Degrees" smaller rather than cut
  grdLive.SetColumnShrink(ColValue, True); // a long value gets smaller, not cut
  grdLive.SetColumnShrink(ColMin, True);
  grdLive.SetColumnShrink(ColMax, True);
  if FGridCompact then
  begin
    // A phone or narrow window: the columns share the width whatever the zoom
    // (zoom only changes the text), and PID names wrap rather than being cut.
    W := grdLive.Width - 14;
    if W < 100 then
      W := 380;
    if chkMinMax.IsChecked then
    begin
      grdLive.SetColumnWidth(ColValue, W * 0.24);
      grdLive.SetColumnWidth(ColUnits, W * 0.17);
      grdLive.SetColumnWidth(ColMin, W * 0.15);
      grdLive.SetColumnWidth(ColMax, W * 0.15);
    end
    else
    begin
      grdLive.SetColumnWidth(ColValue, W * 0.32);
      grdLive.SetColumnWidth(ColUnits, W * 0.18);
    end;
    grdLive.SetColumnWidth(ColName, 60); // stretches into the rest
    grdLive.SetColumnWrap(ColName, True);
    grdLive.SetColumnWrap(ColUnits, True);
  end
  else
  begin
    grdLive.SetColumnWrap(ColName, False);
    grdLive.SetColumnWrap(ColUnits, False);
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
    Shown := LiveValueText(I, P) + #1 + ReadingText(P, FMin[I]) + #1 + ReadingText(P, FMax[I]) + #1 +
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
      else
        Text := LiveValueText(Row, P);
    ColUnits: Text := P.Units;
    ColMin: if Row <= High(FMin) then Text := ReadingText(P, FMin[Row]);
    ColMax: if Row <= High(FMax) then Text := ReadingText(P, FMax[Row]);
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
  // Live rows: move up / down / top / bottom.
  for var M in FMoveItems do
  begin
    M.Visible := (FMenuLiveRow >= 0) and (FMenuLiveRow <= High(FLiveIds)) and (Length(FLiveIds) > 1);
    case M.Tag of
      0, 2: M.Enabled := FMenuLiveRow > 0;
      1, 3: M.Enabled := FMenuLiveRow < High(FLiveIds);
    end;
  end;
end;

{ Alt+Up / Alt+Down move the selected live row (before the grid moves the selection). }
procedure TMainForm.LiveKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if (Shift = [ssAlt]) and ((Key = vkUp) or (Key = vkDown)) and (grdLive.ItemIndex >= 0) then
  begin
    if Key = vkUp then
      MoveLiveRow(grdLive.ItemIndex, grdLive.ItemIndex - 1)
    else
      MoveLiveRow(grdLive.ItemIndex, grdLive.ItemIndex + 1);
    Key := 0;
  end;
end;

procedure TMainForm.MoveRowClick(Sender: TObject);
var
  Row: Integer;
begin
  Row := FMenuLiveRow;
  case TMenuItem(Sender).Tag of
    0: MoveLiveRow(Row, Row - 1);
    1: MoveLiveRow(Row, Row + 1);
    2: MoveLiveRow(Row, 0);
    3: MoveLiveRow(Row, High(FLiveIds));
  end;
end;

type
  TArrayMove = record
    { Takes A[From] out and puts it back at index ToIndex. }
    class procedure Move<T>(var A: TArray<T>; From, ToIndex: Integer); static;
  end;

class procedure TArrayMove.Move<T>(var A: TArray<T>; From, ToIndex: Integer);
var
  Item: T;
  I: Integer;
begin
  if (From < 0) or (From > High(A)) or (ToIndex < 0) or (ToIndex > High(A)) or (From = ToIndex) then
    Exit;
  Item := A[From];
  if From < ToIndex then
    for I := From to ToIndex - 1 do
      A[I] := A[I + 1]
  else
    for I := From downto ToIndex + 1 do
      A[I] := A[I - 1];
  A[ToIndex] := Item;
end;

{ Moves a live row (while scanning too: only what is shown changes, not what
  is asked of the PCM) and remembers the order for the scan list. }
procedure TMainForm.MoveLiveRow(From, ToRow: Integer);
var
  N: Integer;
begin
  N := Length(FLiveIds);
  if (From < 0) or (From >= N) or (ToRow < 0) or (ToRow >= N) or (From = ToRow) then
    Exit;
  TArrayMove.Move<Integer>(FLiveIds, From, ToRow);
  if Length(FRowEngine) = N then
    TArrayMove.Move<Integer>(FRowEngine, From, ToRow);
  if Length(FMin) = N then
    TArrayMove.Move<Double>(FMin, From, ToRow);
  if Length(FMax) = N then
    TArrayMove.Move<Double>(FMax, From, ToRow);
  if Length(FRowStyles) = N then
    TArrayMove.Move<TResolvedStyle>(FRowStyles, From, ToRow);
  if Length(FLive.Values) = N then
    TArrayMove.Move<Double>(FLive.Values, From, ToRow);
  if Length(FLive.Text) = N then
    TArrayMove.Move<string>(FLive.Text, From, ToRow);
  if Length(FLive.PidIds) = N then
    TArrayMove.Move<Integer>(FLive.PidIds, From, ToRow);
  FShownRows := nil;
  ApplyRowHeights;
  grdLive.ItemIndex := ToRow;
  grdLive.Refresh;
  SaveLiveOrder;
end;

{ The live rows' order goes to the chosen scan list (lists.json) and, for
  scans without one, to the settings. }
procedure TMainForm.SaveLiveOrder;
var
  Order, Ids: TArray<Integer>;
  Id, I: Integer;
begin
  Order := Copy(FLiveIds);
  for Id in FSettings.LiveOrder do
    if TArray.IndexOf<Integer>(Order, Id) < 0 then
      Order := Order + [Id];
  FSettings.LiveOrder := Order;
  SettingsChanged;
  if cbLists.ItemIndex <= 0 then
    Exit;
  I := FLists.IndexOf(ComboText(cbLists));
  if I < 0 then
    Exit;
  // The list's PIDs in the rows' order; ones not on screen keep their places after.
  Ids := nil;
  for Id in FLiveIds do
    if TArray.IndexOf<Integer>(FLists[I].PidIds, Id) >= 0 then
      Ids := Ids + [Id];
  for Id in FLists[I].PidIds do
    if TArray.IndexOf<Integer>(Ids, Id) < 0 then
      Ids := Ids + [Id];
  FLists.Put(FLists[I].Name, Ids);
  SaveLists;
end;

{ Ids in the order the rows should show them: the chosen scan list's order,
  then the order last set without a list, then as given. }
function TMainForm.RankLiveIds(const Ids: TArray<Integer>): TArray<Integer>;
var
  ListIds: TArray<Integer>;
  Keys: TArray<Integer>;
  I, J, K, Id: Integer;
begin
  ListIds := nil;
  if (cbLists.ItemIndex > 0) and (FLists.IndexOf(ComboText(cbLists)) >= 0) then
    ListIds := FLists[FLists.IndexOf(ComboText(cbLists))].PidIds;
  Result := Copy(Ids);
  SetLength(Keys, Length(Result));
  for I := 0 to High(Result) do
  begin
    K := TArray.IndexOf<Integer>(ListIds, Result[I]);
    if K < 0 then
    begin
      K := TArray.IndexOf<Integer>(FSettings.LiveOrder, Result[I]);
      if K >= 0 then
        K := 100000 + K
      else
        K := 200000 + I;
    end;
    Keys[I] := K;
  end;
  // insertion sort: few rows, and it keeps equal keys in place
  for I := 1 to High(Result) do
  begin
    Id := Result[I];
    K := Keys[I];
    J := I - 1;
    while (J >= 0) and (Keys[J] > K) do
    begin
      Result[J + 1] := Result[J];
      Keys[J + 1] := Keys[J];
      Dec(J);
    end;
    Result[J + 1] := Id;
    Keys[J + 1] := K;
  end;
end;

{ A snapshot (in the scan's order) in the order of the live rows. }
function TMainForm.DisplaySnapshot(const S: TLiveSnapshot): TLiveSnapshot;
var
  R: Integer;
begin
  Result := S;
  if (Length(S.Values) <> Length(FRowEngine)) or (Length(FRowEngine) = 0) then
    Exit;
  SetLength(Result.Values, Length(FRowEngine));
  for R := 0 to High(FRowEngine) do
    Result.Values[R] := S.Values[FRowEngine[R]];
  if Length(S.Text) = Length(FRowEngine) then
  begin
    SetLength(Result.Text, Length(FRowEngine));
    for R := 0 to High(FRowEngine) do
      Result.Text[R] := S.Text[FRowEngine[R]];
  end;
  if Length(S.PidIds) = Length(FRowEngine) then
  begin
    SetLength(Result.PidIds, Length(FRowEngine));
    for R := 0 to High(FRowEngine) do
      Result.PidIds[R] := S.PidIds[FRowEngine[R]];
  end;
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
  begin
    if Sender = grdLive then
      FMenuLiveRow := grdLive.RowAt(Y)
    else
      FMenuLiveRow := -1;
    PreparePidMenu(GridPidAt(Self, TDataGrid(Sender), TDataGrid(Sender).RowAt(Y)));
  end;
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
  if Grid = grdLive then
    FMenuLiveRow := Row
  else
    FMenuLiveRow := -1;
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
    grdControls.AutoRowHeights;
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
  Cut, First: Integer;
begin
  if (FPendingLog.Count = 0) or (grdMessages = nil) then
    Exit;
  AtEnd := (FMessages.Count = 0) or (grdMessages.TopRow + grdMessages.VisibleRows >= FMessages.Count - 1);
  First := FMessages.Count;
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
    First := 0; // every row moved
  end;
  grdMessages.RowCount := FMessages.Count;
  grdMessages.AutoRowHeights(First);
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
  TThread.ForceQueue(nil, FitWrappedText);
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
          function(const PidCode, Units, Name: string): Integer
          begin
            Result := ResolvePid(FCatalog, PidCode, Units, Name);
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
  FillDashboards;
  ApplyDashBackground;
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
      View.OnClick := GaugeClick;
      View.Chip := G.Minimized;
      View.Touch.InteractiveGestures := [TInteractiveGesture.LongTap];
      View.OnGesture := GaugeGesture;
      View.Setup(G.Style, G.Size, Title, Units, G.MinValue, G.MaxValue,
        FDisplay.Zones(G.PidId, G.MinValue, G.MaxValue));
      FGaugeViews.Add(View);
    end;
  finally
    sbDash.EndUpdate;
  end;
  if FDashEmpty <> nil then
    FDashEmpty.Visible := FGaugeViews.Count = 0;
  if FGaugeViews.Count = 0 then
    lblDashHint.Text := IfThen(IsMobile, 'No gauges yet: press Add gauge, or long-press a PID.',
      'No gauges yet: press Add gauge, or right-click a PID and choose Add to dashboard.')
  else
    lblDashHint.Text := IfThen(IsMobile, 'Long-press a gauge to change, move or remove it. Double-tap to edit.',
      'Right-click a gauge to change, move or remove it. Double-click to edit.');
  LayoutDashboard;
  RefreshDashboard;
end;

procedure TMainForm.FillDashboards;
var
  Name: string;
begin
  if FDashCombo = nil then
    Exit;
  FDashCombo.OnChange := nil;
  try
    FDashCombo.Items.BeginUpdate;
    try
      FDashCombo.Items.Clear;
      for Name in FDisplay.DashboardNames do
        FDashCombo.Items.Add(Name);
    finally
      FDashCombo.Items.EndUpdate;
    end;
    FDashCombo.ItemIndex := FDisplay.Current;
  finally
    FDashCombo.OnChange := DashComboChange;
  end;
  UpdateAppBar;
end;

procedure TMainForm.SelectDashboard(Index: Integer);
begin
  if (Index < 0) or (Index >= FDisplay.DashboardCount) or (Index = FDisplay.Current) then
    Exit;
  FDisplay.Current := Index;
  SaveDisplay; // remembers which one
  BuildDashboard;
end;

procedure TMainForm.DashComboChange(Sender: TObject);
begin
  SelectDashboard(FDashCombo.ItemIndex);
end;

{ The dashboards to pick from, as a menu (a phone has no room for the box). }
procedure TMainForm.ChooseDashboardClick(Sender: TObject);
var
  Items: TArray<TActionItem>;
  It: TActionItem;
  Pick: TComponent;
  I: Integer;
  Pt: TPointF;
begin
  FDashPicks.Free;
  FDashPicks := TComponent.Create(Self);
  Items := nil;
  for I := 0 to FDisplay.DashboardCount - 1 do
  begin
    Pick := TComponent.Create(FDashPicks);
    Pick.Tag := I;
    It := Default(TActionItem);
    It.Text := FDisplay.Dashboards[I].Name;
    It.Enabled := True;
    It.Checked := I = FDisplay.Current;
    It.OnClick := DashPickClick;
    It.Sender := Pick;
    Items := Items + [It];
  end;
  Pt := btnMenu.LocalToAbsolute(TPointF.Create(0, btnMenu.Height));
  ShowActionMenu(Self, Items, TPointF.Create(ClientWidth, Pt.Y));
end;

procedure TMainForm.DashPickClick(Sender: TObject);
begin
  if Sender is TComponent then
    SelectDashboard(TComponent(Sender).Tag);
end;

procedure TMainForm.NewDashboardClick(Sender: TObject);
begin
  AskText('New dashboard', 'Name (a scan list of the same name shows it when it starts)', '',
    procedure(Name: string)
    begin
      Name := Trim(Name);
      if Name = '' then
        Exit;
      if FDisplay.IndexOfDashboard(Name) >= 0 then
      begin
        ShowNotice(Format('There is a dashboard "%s" already', [Name]), True);
        Exit;
      end;
      FDisplay.Current := FDisplay.AddDashboard(Name);
      SaveDisplay;
      BuildDashboard;
    end);
end;

procedure TMainForm.RenameDashboardClick(Sender: TObject);
var
  Old: string;
begin
  Old := FDisplay.Dashboards[FDisplay.Current].Name;
  AskText('Rename dashboard', 'Name', Old,
    procedure(Name: string)
    var
      I: Integer;
    begin
      Name := Trim(Name);
      I := FDisplay.IndexOfDashboard(Name);
      if (Name = '') or (Name = Old) then
        Exit;
      if (I >= 0) and (I <> FDisplay.Current) then
      begin
        ShowNotice(Format('There is a dashboard "%s" already', [Name]), True);
        Exit;
      end;
      FDisplay.Dashboards[FDisplay.Current].Name := Name;
      SaveDisplay;
      BuildDashboard;
    end);
end;

procedure TMainForm.DeleteDashboardClick(Sender: TObject);
var
  Name: string;
begin
  Name := FDisplay.Dashboards[FDisplay.Current].Name;
  if FDisplay.DashboardCount = 1 then
    Confirm(Format('Remove all the gauges of "%s"? (It is the only dashboard.)', [Name]),
      procedure
      begin
        FDisplay.DeleteDashboard(FDisplay.Current);
        SaveDisplay;
        BuildDashboard;
      end)
  else
    Confirm(Format('Delete the dashboard "%s" and its gauges?', [Name]),
      procedure
      begin
        FDisplay.DeleteDashboard(FDisplay.IndexOfDashboard(Name));
        SaveDisplay;
        BuildDashboard;
      end);
end;

{ Left to right, wrapping to the width of the dashboard. On a narrow one (a
  phone) the sizes stay apart: small gauges shrink so two fit a row, medium
  ones keep their size, large ones fill the width; bars take the width at
  their size's height. }
{ The gauges in order, in rows centred in the width. A gauge shorter than its
  row goes under the one before it when both fit the row's height (a large
  dial with two small ones beside it, one above the other), rather than
  leaving that room empty. }
procedure TMainForm.LayoutDashboard;
var
  J, RowFirst, InRow: Integer;
  Avail, AvailH, K, Cap, Y, RowH, ColX, ColW, ColH, Shift, Lo, Hi, Mid, ChipsH, MainH: Single;
  Sz, Chip: TSizeF;
  R: TArray<TRectF>;
  Fit: Boolean;
  ChipsW: Single;           // how far right the chips reach
  Keep: array[0..1] of TRectF; // fitting: the chips' and the + button's corners
const
  Gap = 12;

  function IsChip(I: Integer): Boolean;
  begin
    Result := FDisplay.Gauges[I].Minimized;
  end;

  // The gauges of a full row, centred in the width.
  procedure PlaceRow(Last: Integer);
  var
    N: Integer;
    Right: Single;
  begin
    if Last < RowFirst then
      Exit;
    Right := 0;
    for N := RowFirst to Last do
      if not IsChip(N) then
        Right := Max(Right, R[N].Right);
    Shift := Max(0, (Avail - (Right - Gap)) / 2 - Gap);
    for N := RowFirst to Last do
      if not IsChip(N) then
        R[N].Offset(Shift, 0);
  end;

  // Lays the gauges (not the minimized ones) out at Scale times their size;
  // the height they take.
  function Arrange(Scale: Single): Single;
  var
    I: Integer;
  begin
    Y := Gap;
    RowH := 0;
    RowFirst := 0;
    InRow := 0;
    ColX := Gap; // the column the last gauge is in: its left, width and filled height
    ColW := 0;
    ColH := 0;
    for I := 0 to FGaugeViews.Count - 1 do
    begin
      if IsChip(I) then
        Continue;
      Sz := TGaugeView.PreferredSize(FDisplay.Gauges[I].Style, FDisplay.Gauges[I].Size);
      if (Sz.cx > 0) and (Sz.cx * 2 + 3 * Gap > Avail) and (FDisplay.Gauges[I].Style = gsBar) then
        Sz := TSizeF.Create(Floor(Avail - 2 * Gap), Sz.cy) // a bar is wide anyway: the width, its size's height
      else if (Sz.cx > 0) and (Sz.cx * 2 + 3 * Gap > Avail) then
      begin
        K := 1;
        case FDisplay.Gauges[I].Size of
          gzSmall:
            K := Floor((Avail - 3 * Gap) / 2) / Sz.cx; // two to a row
          gzLarge:
            begin
              // the whole width (at most double on a desktop, where it gets huge)
              K := Floor(Avail - 2 * Gap) / Sz.cx;
              if not IsMobile then
                K := Min(K, 2);
            end;
        end;
        // never wider than the dashboard
        K := Min(K, Floor(Avail - 2 * Gap) / Sz.cx);
        Sz := TSizeF.Create(Round(Sz.cx * K), Round(Sz.cy * K));
      end;
      if Scale <> 1 then
        Sz := TSizeF.Create(Round(Min(Sz.cx * Scale, Avail - 2 * Gap)), Round(Sz.cy * Scale));
      // A short dashboard (a phone held sideways): two rows of small gauges to
      // the screen, a whole medium or large one. (Fitting sizes them itself.)
      if not Fit and (FDisplay.Gauges[I].Style <> gsBar) and (AvailH > 100) then
      begin
        // (not so small its scale cannot be read: a small phone gets one row)
        if FDisplay.Gauges[I].Size = gzSmall then
          Cap := Max(120, Floor((AvailH - 3 * Gap) / 2))
        else
          Cap := Max(160, Floor(AvailH - 2 * Gap));
        if Sz.cy > Cap then
          Sz := TSizeF.Create(Round(Sz.cx * Cap / Sz.cy), Cap);
      end;
      if (InRow > 0) and (Sz.cx <= ColW + 0.5) and (ColH + Gap + Sz.cy <= RowH + 0.5) then
      begin
        // under the one before it, in its column
        R[I] := TRectF.Create(TPointF.Create(ColX + (ColW - Sz.cx) / 2, Y + ColH + Gap), Sz.cx, Sz.cy);
        ColH := ColH + Gap + Sz.cy;
        Continue;
      end;
      if (InRow > 0) and (ColX + ColW + Gap + Sz.cx + Gap > Avail) then
      begin
        PlaceRow(I - 1);
        Y := Y + RowH + Gap;
        RowH := 0;
        RowFirst := I;
        InRow := 0;
        ColX := Gap;
        ColW := 0;
      end
      else if InRow > 0 then
        ColX := ColX + ColW + Gap;
      R[I] := TRectF.Create(TPointF.Create(ColX, Y), Sz.cx, Sz.cy);
      Inc(InRow);
      ColW := Sz.cx;
      ColH := Sz.cy;
      RowH := Max(RowH, Sz.cy);
    end;
    PlaceRow(FGaugeViews.Count - 1);
    if RowH = 0 then
      Result := 0 // only chips
    else
      Result := Y + RowH + Gap;
  end;

  // The minimized gauges: chips in rows, left to right from Top; their height.
  function PlaceChips(Top: Single): Single;
  var
    I: Integer;
    X, Yc, RowW: Single;
    Any: Boolean;
  begin
    // beside the + button when fitting (the band at the bottom is shared)
    RowW := Avail;
    if Fit and not FFullScreen and (FAddGauge <> nil) then
      RowW := Avail - FAddGauge.Width - 24;
    Chip := TGaugeView.ChipSize;
    Chip.cx := Min(Chip.cx, Max(120, (RowW - 3 * Gap) / 2));
    X := Gap;
    Yc := Top;
    Any := False;
    for I := 0 to FGaugeViews.Count - 1 do
    begin
      if not IsChip(I) then
        Continue;
      if Any and (X + Chip.cx + Gap > RowW) then
      begin
        X := Gap;
        Yc := Yc + Chip.cy + Gap / 2;
      end;
      R[I] := TRectF.Create(TPointF.Create(X, Yc), Chip.cx, Chip.cy);
      X := X + Chip.cx + Gap / 2;
      ChipsW := Max(ChipsW, X);
      Any := True;
    end;
    if Any then
      Result := Yc + Chip.cy + Gap - Top
    else
      Result := 0;
  end;

  // Fitting at Scale: all on the page, none under the chips or the +.
  function Fits(Scale: Single): Boolean;
  var
    I, K2: Integer;
  begin
    Result := Arrange(Scale) <= AvailH;
    if Result then
      for I := 0 to FGaugeViews.Count - 1 do
        if not IsChip(I) then
          for K2 := 0 to 1 do
            if not Keep[K2].IsEmpty and R[I].IntersectsWith(Keep[K2]) then
              Exit(False);
  end;

begin
  PlaceAddGauge;
  if (FGaugeViews = nil) or (FGaugeViews.Count = 0) then
    Exit;
  Fit := FFullScreen or FDisplay.Dashboards[FDisplay.Current].FitScreen;
  Avail := sbDash.Width;
  if not IsMobile and not Fit then
    Avail := Avail - 16; // the scroll bar (a phone's floats over the page)
  SetLength(R, FGaugeViews.Count);
  // The chips' size first (where they go comes after).
  ChipsW := 0;
  ChipsH := PlaceChips(0);
  AvailH := sbDash.Height;
  // Fitting, the gauges keep clear of the chips (bottom left) and the +
  // (bottom right); a short last row can still sit between them.
  Keep[0] := TRectF.Create(0, sbDash.Height - ChipsH, ChipsW, sbDash.Height);
  Keep[1] := TRectF.Empty;
  if not FFullScreen and (FAddGauge <> nil) then
    Keep[1] := TRectF.Create(sbDash.Width - FAddGauge.Width - 28, sbDash.Height - FAddGauge.Height - 28,
      sbDash.Width, sbDash.Height);
  if Fit then
  begin
    // Fit to the screen (and full screen): as big as they go and still all
    // fit, smaller too (down to 0.3, e.g. a phone held sideways).
    Lo := 0.3;
    Hi := 4;
    while Hi - Lo > 0.02 do
    begin
      Mid := (Lo + Hi) / 2;
      if Fits(Mid) then
        Lo := Mid
      else
        Hi := Mid;
    end;
    MainH := Arrange(Lo);
    // the chips along the bottom of the screen
    PlaceChips(Max(MainH, sbDash.Height - ChipsH));
  end
  else
  begin
    MainH := Arrange(1);
    PlaceChips(MainH);
  end;
  for J := 0 to High(R) do
  begin
    FGaugeViews[J].Chip := IsChip(J);
    FGaugeViews[J].SetBounds(R[J].Left, R[J].Top, R[J].Width, R[J].Height);
  end;
  // Room below the last row so the + button does not cover a gauge.
  if Fit then
    FDashSpacer.SetBounds(0, 0, 1, 1) // no scrolling
  else if FAddGauge <> nil then
    FDashSpacer.SetBounds(0, MainH + ChipsH, 1, FAddGauge.Height + 40);
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
      Text := LiveValueText(Idx, P);
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
    end, DisplayChanged);
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
    end, DisplayChanged);
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
  if FMinimizeItem <> nil then
  begin
    FMinimizeItem.Enabled := (FMenuGauge >= 0) and (FMenuGauge < FDisplay.Gauges.Count);
    if FMinimizeItem.Enabled and FDisplay.Gauges[FMenuGauge].Minimized then
      FMinimizeItem.Text := 'Restore'
    else
      FMinimizeItem.Text := 'Minimize';
  end;
end;

procedure TMainForm.GaugeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  PrepareGaugeMenu(TGaugeView(Sender).Tag);
end;

{ A minimized gauge: a tap or click restores it. }
procedure TMainForm.GaugeClick(Sender: TObject);
var
  I: Integer;
  G: TGauge;
begin
  I := TGaugeView(Sender).Tag;
  if (I < 0) or (I >= FDisplay.Gauges.Count) or not FDisplay.Gauges[I].Minimized then
    Exit;
  G := FDisplay.Gauges[I];
  G.Minimized := False;
  FDisplay.Gauges[I] := G;
  SaveDisplay;
  LayoutDashboard;
end;

procedure TMainForm.MinimizeGaugeClick(Sender: TObject);
var
  G: TGauge;
begin
  if (FMenuGauge < 0) or (FMenuGauge >= FDisplay.Gauges.Count) then
    Exit;
  G := FDisplay.Gauges[FMenuGauge];
  G.Minimized := not G.Minimized;
  FDisplay.Gauges[FMenuGauge] := G;
  SaveDisplay;
  LayoutDashboard;
end;

procedure TMainForm.FitScreenClick(Sender: TObject);
var
  D: TDashboard;
begin
  D := FDisplay.Dashboards[FDisplay.Current];
  D.FitScreen := not D.FitScreen;
  SaveDisplay;
  LayoutDashboard;
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
  Refit: Boolean;
begin
  if FStatus[Part] = Text then
    Exit; // avoid repainting the status strip for nothing
  // The rate changes every tick: its lines are only measured again when it
  // appears, goes or changes length (it may need another line then).
  Refit := (Part <> spRate) or (Length(FStatus[Part]) <> Length(Text));
  FStatus[Part] := Text;
  S := '';
  for P := Low(TStatusPart) to High(TStatusPart) do
    if FStatus[P] <> '' then
      S := S + IfThen(S <> '', '  ' + #$00B7 + '  ', '') + FStatus[P];
  lblStatus.Text := S;
  if FChromeReady and Refit then
    FitWrappedText;
end;

end.
