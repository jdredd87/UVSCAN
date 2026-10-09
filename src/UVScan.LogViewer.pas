unit UVScan.LogViewer;

{ Log viewer: opens UVScan CSV logs (or a made-up demo drive) and shows them
  as a chart and a grid that follow one cursor, with playback, per-channel
  colours / scales / alert levels, and saved view set-ups (logviews.json).

  Live: the same chart fed by the running scan (the main form keeps the last
  minutes in a TLogData and says when it changes). It shows the last few
  seconds or minutes as they come in; touching the chart pauses it there,
  Live (or the end button) goes back to now. }

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Math, System.Diagnostics, System.IOUtils,
  System.Types, System.Generics.Collections, System.Generics.Defaults,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Edit, FMX.ListBox, FMX.Layouts,
  FMX.Controls.Presentation, FMX.Objects,
  UVScan.Pids, UVScan.Display, UVScan.LogData, UVScan.LogViews, UVScan.LogChart, UVScan.UI.DataGrid;

type
  TViewerBounds = record
    Ctl: TControl;
    R: TRectF;
  end;

  TLogViewerForm = class(TForm)
    pnlBar: TPanel;
    sbBar: TLayout; // the bars wrap to fit (FlowWideBars / LayoutNarrow), so they never scroll
    btnOpen: TButton;
    cbRecent: TComboBox;
    btnDemo: TButton;
    lblView: TLabel;
    cbView: TComboBox;
    btnSaveView: TButton;
    btnDeleteView: TButton;
    lblMode: TLabel;
    cbMode: TComboBox;
    btnImage: TButton;
    pnlPlay: TPanel;
    sbPlay: TLayout;
    btnStart: TButton;
    btnPlay: TButton;
    btnEnd: TButton;
    cbSpeed: TComboBox;
    tbPos: TTrackBar;
    lblTime: TLabel;
    chkFollow: TCheckBox;
    chkBands: TCheckBox;
    chkUseDisplay: TCheckBox;
    btnSelect: TSpeedButton;
    pnlLeft: TLayout;
    layChannels: TLayout;
    gbChannel: TGroupBox;
    lblColor: TLabel;
    cbxColor: TComboBox;
    lblWidth: TLabel;
    cbWidth: TComboBox;
    chkAuto: TCheckBox;
    lblMin: TLabel;
    edtMin: TEdit;
    lblMax: TLabel;
    edtMax: TEdit;
    chkLevelColors: TCheckBox;
    btnLevels: TButton;
    lblLevelSource: TLabel;
    splLeft: TSplitter;
    pnlMain: TLayout;
    layChart: TLayout;
    splChart: TSplitter;
    layGrid: TLayout;
    sbLog: TStatusBar;
    lblStatus0: TLabel;
    lblStatus1: TLabel;
    lblStatus2: TLabel;
    tmrPlay: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure btnOpenClick(Sender: TObject);
    procedure cbRecentChange(Sender: TObject);
    procedure btnDemoClick(Sender: TObject);
    procedure cbViewChange(Sender: TObject);
    procedure btnSaveViewClick(Sender: TObject);
    procedure btnDeleteViewClick(Sender: TObject);
    procedure cbModeChange(Sender: TObject);
    procedure btnImageClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnPlayClick(Sender: TObject);
    procedure btnEndClick(Sender: TObject);
    procedure tbPosChange(Sender: TObject);
    procedure tmrPlayTimer(Sender: TObject);
    procedure chkBandsChange(Sender: TObject);
    procedure chkUseDisplayChange(Sender: TObject);
    procedure btnSelectClick(Sender: TObject);
    procedure ChannelSettingChange(Sender: TObject);
    procedure btnLevelsClick(Sender: TObject);
  private
    FData: TLogData;            // what is shown: FOwnData or the live data
    FOwnData: TLogData;         // logs and the demo
    FLive: Boolean;
    FSpeedIndex: Integer;       // playback speed, kept while the box shows live spans
    FLastStats: UInt64;
    btnLive: TButton;
    FChart: TLogChart;
    FChannels: TDataGrid;
    FGrid: TDataGrid;
    FViews: TLogViewList;
    FStyles: TArray<TChannelStyle>;
    FLevels: TArray<TArray<TDisplayLevel>>;   // what is in effect per channel
    FValueText: TArray<string>;               // channel list: value at the cursor
    FDecimals: TArray<Integer>;               // per channel: decimals every value is shown with
    FStatText: TArray<TArray<string>>;        // channel list: min / avg / max
    FCatalog: TPidCatalog;      // not owned: matches log columns to PIDs
    FDisplay: TDisplaySettings; // not owned: their alert levels
    FLogFolder: string;
    FViewsFile: string;
    FLoading: Boolean;
    FSyncing: Boolean;
    FPlaying: Boolean;
    FPlayClock: TStopwatch;
    FPlayFrom: Double;
    // Narrow window (phone): a top bar with a menu, the chart above either the
    // channel list or the data, and the channel settings as a page of their own.
    FNarrow: Boolean;
    FShort: Boolean; // narrow layout on a short, wide window (a phone held sideways)
    FMainHeight: Single; // pnlMain's height when last laid out: the chart keeps its share of it
    FLaidOut: Boolean;
    FTopBar: TRectangle;
    FTitle: TLabel;
    FMenuButton: TSpeedButton;
    FTabs: TLayout;
    FTabChips: TArray<TRectangle>;
    FDataTab: Boolean;
    FChannelButton: TButton;
    FChannelPage: TRectangle;
    FChannelTitle: TLabel;
    FChannelBox: TVertScrollBox;
    FOrig: TArray<TViewerBounds>;
    procedure BuildPhoneParts;
    function AddBar(Parent: TFmxObject; const Title: string; OnBack: TNotifyEvent): TLabel;
    procedure SaveBounds(const Ctls: array of TControl);
    procedure RestoreBounds;
    procedure LayoutNarrow;
    procedure PutLogRow(InTopBar: Boolean);
    procedure PlaceShortTitle;
    procedure MenuSelectRange(Sender: TObject);
    procedure MainResized(Sender: TObject);
    procedure LayoutWide;
    procedure FlowWideBars;
    procedure LayoutChannelWide;
    procedure LayoutChannelBox;
    procedure LayoutStatus;
    procedure PaintTabs;
    procedure ApplyPalette;
    procedure UpdateChannelButton;
    procedure TabClick(Sender: TObject);
    procedure TabsResize(Sender: TObject);
    procedure BackClick(Sender: TObject);
    procedure MenuClick(Sender: TObject);
    procedure MenuToggle(Sender: TObject);
    procedure MenuViews(Sender: TObject);
    procedure MenuModes(Sender: TObject);
    procedure MenuPick(Sender: TObject);
    procedure ChannelPageOpen(Sender: TObject);
    procedure ChannelPageClose(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure FillRecent;
    procedure FillViews(const Select: string);
    procedure FillColors;
    procedure ShowLog;
    procedure DefaultStyles;
    procedure ApplyView(V: TLogView);
    function CurrentView(const Name: string): TLogView;
    function ComboText(Combo: TComboBox): string;
    procedure ComputeLevels;
    procedure FillChannels;
    procedure RefreshValues;
    procedure ShowChannel;
    procedure StylesChanged;
    procedure SyncToCursor(FromGrid: Boolean);
    procedure ShowTime;
    procedure ChartCursorChange(Sender: TObject);
    procedure SetPlaying(Value: Boolean);
    function SelectedChannel: Integer;
    function DisplayLevelsFor(Ch: Integer): TArray<TDisplayLevel>;
    function ChannelValueText(Ch, Row: Integer): string;
    procedure MeasureChannels;
    procedure UpdateStatus;
    procedure SetLive(Value: Boolean);
    procedure LeaveLive;
    procedure LiveUpdated(NewChannels: Boolean);
    procedure FillSpeeds;
    procedure SpeedChange(Sender: TObject);
    procedure btnLiveClick(Sender: TObject);
    procedure ChartFollowChange(Sender: TObject);
    procedure TogglePlay;
    procedure UpdatePlayButton;
    procedure SaveViews;
    procedure SaveViewAs(const Name: string);
    procedure ChartSelectionChange(Sender: TObject);
    procedure RangeStats(Ch: Integer; out Lo, Avg, Hi: Double);
    procedure OpenFile(const FileName: string);
    procedure MoveCursorToRow(Row: Integer);
    // channel list
    procedure ChannelsGetText(Sender: TObject; Col, Row: Integer; var Text: string);
    procedure ChannelsGetStyle(Sender: TObject; Col, Row: Integer; var Style: TCellStyle);
    procedure ChannelsGetChecked(Sender: TObject; Row: Integer; var Checked: Boolean);
    procedure ChannelsToggleCheck(Sender: TObject; Row: Integer);
    procedure ChannelsSelect(Sender: TObject);
    // log grid
    procedure GridGetText(Sender: TObject; Col, Row: Integer; var Text: string);
    procedure GridGetStyle(Sender: TObject; Col, Row: Integer; var Style: TCellStyle);
    procedure GridSelect(Sender: TObject);
    // dropping a file on the window
    procedure FileDragOver(Sender: TObject; const Data: TDragObject; const Point: TPointF;
      var Operation: TDragOperation);
    procedure FileDragDrop(Sender: TObject; const Data: TDragObject; const Point: TPointF);
    class function Prepare(Catalog: TPidCatalog; Display: TDisplaySettings;
      const LogFolder, ViewsFile: string): TLogViewerForm;
    procedure Present;
  public
    { Opens the viewer (one window, reused). FileName '' = just show it. }
    class procedure ShowViewer(Catalog: TPidCatalog; Display: TDisplaySettings; const LogFolder, ViewsFile,
      FileName: string);
    { Opens it on the live data. }
    class procedure ShowLive(Catalog: TPidCatalog; Display: TDisplaySettings; const LogFolder, ViewsFile: string);
    { The live data (not owned; nil = none, e.g. when its owner goes). }
    class procedure SetLiveSource(Data: TLogData);
    { The live data has new samples, or (NewChannels) was started again for
      another scan. }
    class procedure LiveChanged(NewChannels: Boolean);
  end;

implementation

{$R *.fmx}

uses
  System.StrUtils, FMX.Dialogs, UVScan.UI.Common, UVScan.UI.Theme, UVScan.DisplayEditor;

var
  Viewer: TLogViewerForm;
  LiveSource: TLogData;

const
  Speeds: array[0..6] of Double = (0.25, 0.5, 1, 2, 5, 10, 20);
  NoView = '(this log)';
  ColName = 0;
  ColValue = 1;
  ColMin = 2;
  ColAvg = 3;
  ColMax = 4;
  NarrowWidth = 700;
  ShortHeight = 480; // below this height (and wider than tall): the short layout
  StatsColor = TAlphaColor($FF0060B0);  // selection statistics stand out
  CursorRowColor = TAlphaColor($FFC8E6F5);
  LiveSpans: array[0..5] of Double = (15, 30, 60, 120, 300, 600);

class function TLogViewerForm.Prepare(Catalog: TPidCatalog; Display: TDisplaySettings;
  const LogFolder, ViewsFile: string): TLogViewerForm;
begin
  if Viewer = nil then
    Viewer := TLogViewerForm.Create(Application);
  Result := Viewer;
  Result.FCatalog := Catalog;
  Result.FDisplay := Display;
  Result.FLogFolder := LogFolder;
  if Result.FViewsFile <> ViewsFile then
  begin
    Result.FViewsFile := ViewsFile;
    if FileExists(ViewsFile) then
      try
        Result.FViews.LoadFromFile(ViewsFile);
      except
        // a broken file just means no saved views
      end;
    Result.FillViews(Result.FViews.LastView);
    Result.FillSpeeds; // the saved live span
  end;
  Result.FillRecent;
  Result.ApplyPalette; // the theme may have changed since it was last open
end;

procedure TLogViewerForm.Present;
begin
  if IsMobile then
  begin
    WindowState := TWindowState.wsMaximized;
    KeepInSafeArea(Self);
  end
  else if WindowState = TWindowState.wsMinimized then
    WindowState := TWindowState.wsNormal;
  Show;
  Activate;
  if IsMobile then
    KeepInSafeArea(Self); // on screen now: the insets are known
  if FLive then
    LiveUpdated(False);
end;

class procedure TLogViewerForm.ShowViewer(Catalog: TPidCatalog; Display: TDisplaySettings; const LogFolder,
  ViewsFile, FileName: string);
var
  V: TLogViewerForm;
begin
  V := Prepare(Catalog, Display, LogFolder, ViewsFile);
  if FileName <> '' then
    try
      V.LeaveLive;
      V.FData.LoadFromFile(FileName);
      V.ShowLog;
    except
      on E: Exception do
      begin
        V.ShowLog;
        ShowWarning('Could not open the log: ' + E.Message);
      end;
    end;
  V.Present;
end;

class procedure TLogViewerForm.ShowLive(Catalog: TPidCatalog; Display: TDisplaySettings;
  const LogFolder, ViewsFile: string);
var
  V: TLogViewerForm;
begin
  V := Prepare(Catalog, Display, LogFolder, ViewsFile);
  V.SetLive(True);
  V.Present;
end;

class procedure TLogViewerForm.SetLiveSource(Data: TLogData);
begin
  LiveSource := Data;
  if Viewer <> nil then
  begin
    if Viewer.FLive and (Data = nil) then
      Viewer.SetLive(False);
    Viewer.btnLive.Enabled := Data <> nil;
  end;
end;

class procedure TLogViewerForm.LiveChanged(NewChannels: Boolean);
begin
  // Closed: only a new set of channels matters now; Present catches up.
  if (Viewer <> nil) and Viewer.FLive and (Viewer.Visible or NewChannels) then
    Viewer.LiveUpdated(NewChannels);
end;

procedure TLogViewerForm.FormCreate(Sender: TObject);
var
  M: TChartMode;
begin
  FOwnData := TLogData.Create;
  FData := FOwnData;
  FViews := TLogViewList.Create;
  FSpeedIndex := 2;

  pnlMain.OnResized := MainResized;
  FChart := TLogChart.Create(Self);
  FChart.Parent := layChart;
  FChart.Align := TAlignLayout.Client;
  FChart.OnCursorChange := ChartCursorChange;
  FChart.OnSelectionChange := ChartSelectionChange;
  FChart.OnFollowChange := ChartFollowChange;
  FChart.OnDragOver := FileDragOver;
  FChart.OnDragDrop := FileDragDrop;

  FChannels := TDataGrid.Create(Self);
  FChannels.Parent := layChannels;
  FChannels.Align := TAlignLayout.Client;
  FChannels.Checkboxes := True;
  FChannels.RowHeight := 24;
  FChannels.HeaderHeight := 24;
  FChannels.FontSize := 12;
  FChannels.AddColumn('Channel', 112, gaLeft, True);
  FChannels.AddColumn('Value', 56, gaRight);
  FChannels.AddColumn('Min', 50, gaRight);
  FChannels.AddColumn('Avg', 54, gaRight);
  FChannels.AddColumn('Max', 54, gaRight);
  for var C := ColValue to ColMax do
    FChannels.SetColumnShrink(C, True); // a long number smaller, not cut short
  FChannels.OnGetText := ChannelsGetText;
  FChannels.OnGetStyle := ChannelsGetStyle;
  FChannels.OnGetChecked := ChannelsGetChecked;
  FChannels.OnToggleCheck := ChannelsToggleCheck;
  FChannels.OnSelect := ChannelsSelect;

  FGrid := TDataGrid.Create(Self);
  FGrid.Parent := layGrid;
  FGrid.Align := TAlignLayout.Client;
  FGrid.RowHeight := 22;
  FGrid.HeaderHeight := 24;
  FGrid.FontSize := 12;
  FGrid.FixedStripes := True; // it scrolls a row at a time while playing
  FGrid.OnGetText := GridGetText;
  FGrid.OnGetStyle := GridGetStyle;
  FGrid.OnSelect := GridSelect;
  FGrid.OnDragOver := FileDragOver;
  FGrid.OnDragDrop := FileDragDrop;

  for M := Low(TChartMode) to High(TChartMode) do
    cbMode.Items.Add(ChartModeCaptions[M]);
  cbMode.ItemIndex := 0;
  FillSpeeds;
  cbSpeed.OnChange := SpeedChange;
  // The running scan, charted as it comes in.
  btnLive := TButton.Create(Self);
  btnLive.Parent := btnDemo.Parent;
  btnLive.Stored := False;
  btnLive.Text := 'Live scan';
  btnLive.Hint := 'Chart the values of the running scan (or the test display) as they come in';
  btnLive.ShowHint := True;
  btnLive.OnClick := btnLiveClick;
  btnLive.Enabled := LiveSource <> nil;
  btnLive.SetBounds(btnDemo.Position.X + btnDemo.Width + 6, btnDemo.Position.Y, 90, btnDemo.Height);
  for var I := 1 to 4 do
    cbWidth.Items.Add(IntToStr(I) + ' px');
  FillColors;
  lblTime.TextSettings.Font.Style := [TFontStyle.fsBold];
  chkUseDisplay.Text := 'Alert levels from Display && alerts'; // && = one &
  // Phones: no file dialogs (logs are picked from the log folder), and a
  // button to select a range with a finger.
  btnOpen.Visible := not IsMobile;
  btnSelect.Visible := IsMobile;
  OnKeyUp := FormKeyUp;
  // The wide layout (absolute positions), kept for when the window is wide again.
  SaveBounds([btnDemo, cbRecent, btnStart, btnPlay, btnEnd, cbSpeed, tbPos, lblTime, btnSelect, lblColor, cbxColor,
    lblWidth, cbWidth, chkAuto, lblMin, edtMin, lblMax, edtMax, chkLevelColors, btnLevels, lblLevelSource]);
  BuildPhoneParts;
  ShowLog;
  FormResize(nil);
end;

{ Phone parts }

function TLogViewerForm.AddBar(Parent: TFmxObject; const Title: string; OnBack: TNotifyEvent): TLabel;
var
  Bar: TRectangle;
  Back: TSpeedButton;
begin
  Bar := TRectangle.Create(Self);
  Bar.Parent := Parent;
  Bar.Stored := False;
  Bar.Align := TAlignLayout.Top;
  Bar.Position.Y := -100; // above every other top-aligned control
  Bar.Height := 52;
  Bar.Sides := [TSide.Bottom];
  Bar.Fill.Color := Palette.Bar;
  Bar.Stroke.Color := Palette.BarLine;
  Back := TSpeedButton.Create(Self);
  Back.Parent := Bar;
  Back.Stored := False;
  Back.Align := TAlignLayout.Left;
  Back.Width := 48;
  Back.Text := '';
  Back.Hint := 'Back';
  Back.OnClick := OnBack;
  AddLineIcon(Back, IconBack);
  Result := TLabel.Create(Self);
  Result.Parent := Bar;
  Result.Stored := False;
  Result.Align := TAlignLayout.Client;
  Result.Margins.Left := 6;
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Size];
  Result.TextSettings.Font.Size := 19;
  Result.TextSettings.WordWrap := False;
  Result.TextSettings.Trimming := TTextTrimming.Character;
  Result.Text := Title;
end;

procedure TLogViewerForm.BuildPhoneParts;
const
  TabCaptions: array[0..1] of string = ('Channels', 'Data');
var
  I: Integer;
  R: TRectangle;
  L: TLabel;
begin
  FTitle := AddBar(Self, 'Log viewer', BackClick);
  FTopBar := TRectangle(FTitle.Parent);
  FMenuButton := TSpeedButton.Create(Self);
  FMenuButton.Parent := FTopBar;
  FMenuButton.Stored := False;
  FMenuButton.Align := TAlignLayout.Right;
  FMenuButton.Width := 48;
  FMenuButton.Text := #$22EE;
  FMenuButton.StyledSettings := FMenuButton.StyledSettings - [TStyledSetting.Size, TStyledSetting.Style];
  FMenuButton.TextSettings.Font.Size := 22;
  FMenuButton.TextSettings.Font.Style := [TFontStyle.fsBold];
  FMenuButton.Hint := 'More';
  FMenuButton.OnClick := MenuClick;

  // Channels | Data, under the chart
  FTabs := TLayout.Create(Self);
  FTabs.Parent := pnlMain;
  FTabs.Stored := False;
  FTabs.Align := TAlignLayout.Top;
  FTabs.Height := 40;
  FTabs.Margins.Rect := TRectF.Create(12, 8, 12, 6);
  FTabs.Visible := False;
  FTabs.OnResize := TabsResize;
  for I := 0 to High(TabCaptions) do
  begin
    R := TRectangle.Create(Self);
    R.Parent := FTabs;
    R.Stored := False;
    R.XRadius := 8;
    R.YRadius := 8;
    R.HitTest := True;
    R.Cursor := crHandPoint;
    R.Tag := I;
    R.OnClick := TabClick;
    L := TLabel.Create(Self);
    L.Parent := R;
    L.Stored := False;
    L.Align := TAlignLayout.Client;
    L.HitTest := False;
    L.StyledSettings := L.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Style];
    L.TextSettings.HorzAlign := TTextAlign.Center;
    L.TextSettings.WordWrap := False;
    L.Text := TabCaptions[I];
    FTabChips := FTabChips + [R];
  end;

  // Under the channel list: the selected channel's settings are a page.
  FChannelButton := TButton.Create(Self);
  FChannelButton.Parent := pnlLeft;
  FChannelButton.Stored := False;
  FChannelButton.Align := TAlignLayout.Bottom;
  FChannelButton.Height := 44;
  FChannelButton.Margins.Rect := TRectF.Create(6, 6, 12, 4);
  FChannelButton.TextSettings.Trimming := TTextTrimming.Character;
  FChannelButton.OnClick := ChannelPageOpen;
  FChannelButton.Visible := False;

  FChannelPage := TRectangle.Create(Self);
  FChannelPage.Parent := Self;
  FChannelPage.Stored := False;
  FChannelPage.Align := TAlignLayout.Contents;
  FChannelPage.HitTest := True;
  FChannelPage.Stroke.Kind := TBrushKind.None;
  FChannelPage.Visible := False;
  FChannelTitle := AddBar(FChannelPage, 'Channel', ChannelPageClose);
  FChannelBox := TVertScrollBox.Create(Self);
  FChannelBox.Parent := FChannelPage;
  FChannelBox.Stored := False;
  FChannelBox.Align := TAlignLayout.Client;
end;

procedure TLogViewerForm.SaveBounds(const Ctls: array of TControl);
var
  C: TControl;
  S: TViewerBounds;
begin
  for C in Ctls do
  begin
    S.Ctl := C;
    S.R := TRectF.Create(C.Position.X, C.Position.Y, C.Position.X + C.Width, C.Position.Y + C.Height);
    FOrig := FOrig + [S];
  end;
end;

procedure TLogViewerForm.RestoreBounds;
var
  S: TViewerBounds;
begin
  for S in FOrig do
    S.Ctl.SetBounds(S.R.Left, S.R.Top, S.R.Width, S.R.Height);
end;

procedure TLogViewerForm.ApplyPalette;

  procedure Icons(Parent: TFmxObject); // the back arrows
  var
    I: Integer;
  begin
    for I := 0 to Parent.ChildrenCount - 1 do
    begin
      if Parent.Children[I] is TPath then
        TPath(Parent.Children[I]).Stroke.Color := Palette.Text;
      Icons(Parent.Children[I]);
    end;
  end;

var
  Bar: TRectangle;
begin
  for Bar in [FTopBar, TRectangle(FChannelTitle.Parent)] do
  begin
    Bar.Fill.Color := Palette.Bar;
    Bar.Stroke.Color := Palette.BarLine;
    Icons(Bar);
  end;
  FChannelPage.Fill.Color := Palette.Back;
  PaintTabs;
end;

procedure TLogViewerForm.PaintTabs;
var
  I: Integer;
  P: TPalette;
  L: TLabel;
  W: Single;
begin
  P := Palette;
  W := (FTabs.Width - 8) / Length(FTabChips);
  for I := 0 to High(FTabChips) do
  begin
    FTabChips[I].SetBounds(I * (W + 8), 0, W, FTabs.Height);
    L := TLabel(FTabChips[I].Controls[0]);
    if (I = 1) = FDataTab then
    begin
      FTabChips[I].Fill.Color := P.Accent;
      FTabChips[I].Stroke.Color := P.Accent;
      L.TextSettings.FontColor := ContrastColor(P.Accent);
      L.TextSettings.Font.Style := [TFontStyle.fsBold];
    end
    else
    begin
      FTabChips[I].Fill.Color := P.Bar;
      FTabChips[I].Stroke.Color := P.BarLine;
      L.TextSettings.FontColor := P.Text;
      L.TextSettings.Font.Style := [];
    end;
  end;
end;

procedure TLogViewerForm.TabsResize(Sender: TObject);
begin
  PaintTabs;
end;

procedure TLogViewerForm.TabClick(Sender: TObject);
begin
  FDataTab := TComponent(Sender).Tag = 1;
  FormResize(nil);
end;

procedure TLogViewerForm.UpdateChannelButton;
var
  Ch: Integer;
begin
  if FChannelButton = nil then
    Exit;
  Ch := SelectedChannel;
  FChannelButton.Enabled := Ch >= 0;
  if Ch >= 0 then
    FChannelButton.Text := 'Colour, scale, alerts: ' + FData.Channels[Ch].Caption
  else
    FChannelButton.Text := 'Tap a channel for its colour and scale';
  if gbChannel.Text <> '' then // the narrow channel box hides its caption (LayoutChannelBox)
    FChannelTitle.Text := gbChannel.Text;
end;

procedure TLogViewerForm.ChannelPageOpen(Sender: TObject);
begin
  if SelectedChannel < 0 then
    Exit;
  ShowChannel;
  FChannelPage.Fill.Color := Palette.Back;
  FChannelPage.Visible := True;
  FChannelPage.BringToFront;
  LayoutChannelBox;
  FChannelBox.ViewportPosition := TPointF.Zero;
end;

procedure TLogViewerForm.ChannelPageClose(Sender: TObject);
begin
  FChannelPage.Visible := False;
  FChannels.Refresh;
end;

procedure TLogViewerForm.BackClick(Sender: TObject);
begin
  SetPlaying(False);
  Close;
end;

procedure TLogViewerForm.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if Key <> vkHardwareBack then
    Exit;
  Key := 0;
  if CloseActionMenu then
  else if FChannelPage.Visible then
    ChannelPageClose(nil)
  else
    BackClick(nil);
end;

{ The page menu on a narrow window: what does not fit in its bars. }
procedure TLogViewerForm.MenuClick(Sender: TObject);

  function Item(const Text: string; OnClick: TNotifyEvent; Sender: TObject; Enabled: Boolean = True;
    Checked: Boolean = False): TActionItem;
  begin
    Result.Text := Text;
    Result.OnClick := OnClick;
    Result.Sender := Sender;
    Result.Enabled := Enabled;
    Result.Checked := Checked;
  end;

var
  Items: TArray<TActionItem>;
begin
  Items := nil;
  if not IsMobile then
    Items := Items + [Item('Open log...', btnOpenClick, btnOpen)];
  Items := Items + [
    Item('View: ' + ComboText(cbView), MenuViews, nil),
    Item('Save view...', btnSaveViewClick, btnSaveView),
    Item('Delete view', btnDeleteViewClick, btnDeleteView, btnDeleteView.Enabled),
    Item('Chart: ' + ComboText(cbMode), MenuModes, nil),
    Item('Save chart picture', btnImageClick, btnImage, FData.Count > 0),
    Item('-', nil, nil),
    Item('Follow the cursor', MenuToggle, chkFollow, True, chkFollow.IsChecked),
    Item('Level bands', MenuToggle, chkBands, True, chkBands.IsChecked),
    Item('Levels from Display && alerts', MenuToggle, chkUseDisplay, True, chkUseDisplay.IsChecked)];
  if FShort then
    Items := Items + [Item('Channel colour, scale, alerts...', ChannelPageOpen, nil, SelectedChannel >= 0)];
  if IsMobile and not btnSelect.Visible then // no room for it in the bar
    Items := Items + [Item('Select range', MenuSelectRange, nil, FData.Count > 0, btnSelect.IsPressed)];
  ShowActionMenu(Self, Items, PointF(ClientWidth, FTopBar.Height));
end;

procedure TLogViewerForm.MenuSelectRange(Sender: TObject);
begin
  btnSelect.IsPressed := not btnSelect.IsPressed;
  btnSelectClick(nil);
end;

procedure TLogViewerForm.MenuToggle(Sender: TObject);
begin
  TCheckBox(Sender).IsChecked := not TCheckBox(Sender).IsChecked;
end;

procedure TLogViewerForm.MenuViews(Sender: TObject);
var
  Items: TArray<TActionItem>;
  It: TActionItem;
  I: Integer;
begin
  Items := nil;
  for I := 0 to cbView.Count - 1 do
  begin
    It.Text := cbView.Items[I];
    It.Enabled := True;
    It.Checked := I = cbView.ItemIndex;
    It.OnClick := MenuPick;
    It.Sender := cbView.ListItems[I];
    Items := Items + [It];
  end;
  ShowActionMenu(Self, Items, PointF(ClientWidth, FTopBar.Height));
end;

procedure TLogViewerForm.MenuModes(Sender: TObject);
var
  Items: TArray<TActionItem>;
  It: TActionItem;
  I: Integer;
begin
  Items := nil;
  for I := 0 to cbMode.Count - 1 do
  begin
    It.Text := cbMode.Items[I];
    It.Enabled := True;
    It.Checked := I = cbMode.ItemIndex;
    It.OnClick := MenuPick;
    It.Sender := cbMode.ListItems[I];
    Items := Items + [It];
  end;
  ShowActionMenu(Self, Items, PointF(ClientWidth, FTopBar.Height));
end;

{ A view or chart mode picked in a menu: Sender is the combo box item. }
procedure TLogViewerForm.MenuPick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to cbView.Count - 1 do
    if cbView.ListItems[I] = Sender then
      cbView.ItemIndex := I;
  for I := 0 to cbMode.Count - 1 do
    if cbMode.ListItems[I] = Sender then
      cbMode.ItemIndex := I;
end;

{ Narrow: the channel settings stacked, captions above the fields. }
procedure TLogViewerForm.LayoutChannelBox;
var
  W, Y, Half: Single;

  procedure Put(C: TControl; H: Single; X: Single = 12; CW: Single = -1);
  begin
    if CW < 0 then
      CW := W;
    C.SetBounds(X, Y, CW, H);
  end;

begin
  W := FChannelBox.Width - 2 * 12 - 2 * 12;
  if W < 100 then
    W := InnerWidth(Self) - 48;
  gbChannel.Width := W + 24;
  gbChannel.Text := '';
  Half := (W - 12) / 2;
  Y := 12;
  lblColor.WordWrap := False;
  Put(lblColor, 24);
  Y := Y + 26;
  Put(cbxColor, 40);
  Y := Y + 50;
  lblWidth.WordWrap := False;
  Put(lblWidth, 24);
  Y := Y + 26;
  Put(cbWidth, 40, 12, Half);
  Y := Y + 50;
  chkAuto.TextSettings.WordWrap := True;
  Put(chkAuto, Max(40, WrappedTextHeight(chkAuto, W - 40) + 10));
  Y := Y + chkAuto.Height + 6;
  lblMin.WordWrap := False;
  lblMax.WordWrap := False;
  Put(lblMin, 24, 12, Half);
  Put(lblMax, 24, 24 + Half, Half);
  Y := Y + 26;
  Put(edtMin, 40, 12, Half);
  Put(edtMax, 40, 24 + Half, Half);
  Y := Y + 52;
  chkLevelColors.TextSettings.WordWrap := True;
  Put(chkLevelColors, Max(40, WrappedTextHeight(chkLevelColors, W - 40) + 10));
  Y := Y + chkLevelColors.Height + 6;
  lblLevelSource.WordWrap := True;
  Put(lblLevelSource, Max(24, WrappedTextHeight(lblLevelSource, W) + 4));
  Y := Y + lblLevelSource.Height + 8;
  FitTextWidth(btnLevels, 160);
  Put(btnLevels, 44, 12, Min(btnLevels.Width, W));
  Y := Y + 44 + 16;
  gbChannel.Height := Y;
end;

{ Narrow: the status lines one under the other, wrapped. Wide: side by
  side, the first two as wide as their text (within reason), the hint the rest. }
procedure TLogViewerForm.LayoutStatus;
var
  L: TLabel;
  H, W: Single;
begin
  if not FNarrow then
  begin
    W := InnerWidth(Self) - 16;
    for L in [lblStatus0, lblStatus1] do
    begin
      L.TextSettings.Trimming := TTextTrimming.Character;
      FitTextWidth(L);
      L.Width := Min(L.Width + 12, W * IfThen(L = lblStatus0, 0.3, 0.45));
    end;
    lblStatus0.Position.X := 0;
    lblStatus1.Position.X := lblStatus0.Width + 1;
    Exit;
  end;
  W := InnerWidth(Self) - 16;
  H := 0;
  if FShort or (InnerHeight(Self) < 700) then // a small phone: the lists need the room
  begin
    // One line: what the log is, then the hint, cut short.
    for L in [lblStatus0, lblStatus1, lblStatus2] do
    begin
      L.Visible := (L.Text <> '') and ((L <> lblStatus0) or (FData.Count = 0));
      L.WordWrap := False;
      L.TextSettings.Trimming := TTextTrimming.Character;
      L.Margins.Rect := TRectF.Create(8, 0, 8, 0);
      if L = lblStatus2 then
        L.Align := TAlignLayout.Client
      else
      begin
        L.Align := TAlignLayout.Left;
        FitTextWidth(L);
        L.Width := Min(L.Width, W / 2);
      end;
      if L.Visible then
        H := Max(H, WrappedTextHeight(L, 10000));
    end;
    lblStatus0.Position.X := 0;
    lblStatus1.Position.X := lblStatus0.Width + 20;
    sbLog.Height := H + 8;
    Exit;
  end;
  for L in [lblStatus0, lblStatus1, lblStatus2] do
  begin
    // with a log open its name is in the top bar and the log box already
    L.Visible := (L.Text <> '') and ((L <> lblStatus0) or (FData.Count = 0));
    if not L.Visible then
      Continue;
    L.Align := TAlignLayout.Top;
    L.WordWrap := True;
    L.TextSettings.Trimming := TTextTrimming.None;
    L.Margins.Rect := TRectF.Create(8, 2, 8, 0);
    L.Height := WrappedTextHeight(L, W) + 2;
    L.Position.Y := H + 1;
    H := H + L.Height + 2;
  end;
  sbLog.Height := H + 8;
end;

procedure ShowControls(const Ctls: array of TControl; Visible: Boolean);
var
  C: TControl;
begin
  for C in Ctls do
    C.Visible := Visible;
end;

procedure TLogViewerForm.LayoutNarrow;
var
  W, X, L: Single;
  S: string;
begin
  W := InnerWidth(Self);
  FTopBar.Visible := True;
  FTopBar.Position.Y := -100; // above the log row
  FMenuButton.Visible := True;
  // The log row: the recent logs and the demo. A short window has them in the
  // top bar, between back and the menu.
  ShowControls([btnOpen, lblView, cbView, btnSaveView, btnDeleteView, lblMode, cbMode, btnImage], False);
  PutLogRow(FShort);
  btnDemo.Text := 'Demo';
  btnLive.Text := 'Live';
  FitTextWidth(btnDemo, 72);
  FitTextWidth(btnLive, 64);
  if FShort then
  begin
    X := W - FMenuButton.Width - 4;
    L := 56;
  end
  else
  begin
    pnlBar.Height := 52;
    X := W - 12;
    L := 12;
  end;
  btnLive.SetBounds(X - btnLive.Width, 8, btnLive.Width, 36);
  btnDemo.SetBounds(btnLive.Position.X - 8 - btnDemo.Width, 8, btnDemo.Width, 36);
  cbRecent.SetBounds(L, 8, Max(80, btnDemo.Position.X - 8 - L), 36);
  PlaceShortTitle;
  // Playback: the buttons, then the position and time (one row when short).
  ShowControls([chkFollow, chkBands, chkUseDisplay], False);
  btnStart.SetBounds(12, 6, 48, 38);
  btnPlay.SetBounds(68, 6, 84, 38);
  btnEnd.SetBounds(160, 6, 48, 38);
  cbSpeed.SetBounds(216, 6, 84, 38);
  lblTime.WordWrap := False;
  lblTime.TextSettings.HorzAlign := TTextAlign.Trailing;
  S := lblTime.Text; // as wide as the longest time it will show
  lblTime.Text := '00:00.0 / 00:00.0';
  FitTextWidth(lblTime, 100);
  lblTime.Text := S;
  // A phone has Select range (long-press does it too); on a short row too
  // tight for it and the slider it is in the menu instead.
  btnSelect.Visible := IsMobile;
  if FShort then
  begin
    pnlPlay.Height := 50;
    X := 308; // where the slider starts
    FitTextWidth(btnSelect, 90);
    if W - 20 - lblTime.Width - X - btnSelect.Width - 8 < 160 then
      btnSelect.Visible := False;
    if btnSelect.Visible then
    begin
      btnSelect.SetBounds(X, 6, btnSelect.Width, 38);
      X := X + btnSelect.Width + 8;
    end;
    lblTime.SetBounds(W - 12 - lblTime.Width, 6, lblTime.Width, 38);
    tbPos.SetBounds(X, 6, Max(60, W - 20 - lblTime.Width - X), 38);
  end
  else
  begin
    pnlPlay.Height := 96;
    X := 12; // where the slider starts
    if btnSelect.Visible then
    begin
      FitTextWidth(btnSelect, 90);
      if W - 12 - 308 >= btnSelect.Width then
        btnSelect.SetBounds(W - 12 - btnSelect.Width, 6, btnSelect.Width, 38)
      else
      begin
        // a small phone: first on the slider's line
        btnSelect.SetBounds(12, 52, btnSelect.Width, 38);
        X := 12 + btnSelect.Width + 8;
      end;
    end;
    lblTime.SetBounds(W - 12 - lblTime.Width, 52, lblTime.Width, 38);
    tbPos.SetBounds(X, 52, Max(60, W - 20 - lblTime.Width - X), 38);
  end;
  // The chart, then Channels | Data (beside it when short).
  splLeft.Visible := False;
  splChart.Visible := False;
  gbChannel.Parent := FChannelBox;
  gbChannel.Align := TAlignLayout.Top;
  gbChannel.Margins.Rect := TRectF.Create(12, 12, 12, 12);
  pnlLeft.Parent := pnlMain;
  pnlLeft.Align := TAlignLayout.Client;
  pnlLeft.Padding.Rect := TRectF.Create(6, 0, 0, 4);
  if FShort then
  begin
    layChart.Align := TAlignLayout.MostLeft; // the whole height; the tabs and lists beside it
    layChart.Width := Round(W * 0.58);
    FTabs.Position.Y := 0;
  end
  else
  begin
    layChart.Align := TAlignLayout.Top;
    layChart.Position.Y := 0;
    layChart.Height := Max(150, Round((pnlMain.Height - 60) * 0.45));
    FTabs.Position.Y := layChart.Height + 1;
  end;
  FTabs.Visible := True;
  PaintTabs;
  pnlLeft.Visible := not FDataTab;
  layGrid.Visible := FDataTab;
  FChannelButton.Visible := not FShort; // short: in the menu, the list needs the room
  UpdateChannelButton;
  if FChannelPage.Visible then
    LayoutChannelBox;
  LayoutStatus;
end;

{ A short window has the log row in the top bar, in place of the title (the
  log box names the log too). }
procedure TLogViewerForm.PutLogRow(InTopBar: Boolean);
var
  Bar: TFmxObject;
  C: TControl;
begin
  if InTopBar then
    Bar := FTopBar
  else
    Bar := sbBar;
  for C in TArray<TControl>.Create(cbRecent, btnDemo, btnLive) do
    if C.Parent <> Bar then
      C.Parent := Bar;
  FTitle.Visible := not InTopBar;
  if not InTopBar then
  begin
    FTitle.Margins.Left := 6;
    FTitle.Margins.Right := 0;
  end;
  if pnlBar.Visible = InTopBar then
  begin
    pnlBar.Position.Y := pnlPlay.Position.Y - 1; // back above the playback row
    pnlBar.Visible := not InTopBar;
  end;
end;

{ Short: a log's name is in the log box; the demo and the live chart have no
  file, so their title shows beside a narrower box. }
procedure TLogViewerForm.PlaceShortTitle;
var
  L: Single;
begin
  if not FShort or (FTitle = nil) then
    Exit;
  L := 56; // after the back arrow
  FTitle.Visible := cbRecent.ItemIndex < 0;
  if FTitle.Visible then
  begin
    cbRecent.Width := Min(140, Max(80, btnDemo.Position.X - 8 - L));
    FTitle.Margins.Left := cbRecent.Position.X + cbRecent.Width + 10 - 48;
    FTitle.Margins.Right := Max(0, FTopBar.Width - btnDemo.Position.X + 8 - FMenuButton.Width);
  end
  else
    cbRecent.Width := Max(80, btnDemo.Position.X - 8 - L);
end;

procedure TLogViewerForm.LayoutWide;
begin
  FTopBar.Visible := IsMobile; // a phone or tablet window has no caption to close it by
  FMenuButton.Visible := False;
  FChannelPage.Visible := False;
  FTabs.Visible := False;
  FChannelButton.Visible := False;
  PutLogRow(False);
  RestoreBounds;
  btnOpen.Visible := not IsMobile;
  ShowControls([lblView, cbView, btnSaveView, btnDeleteView, lblMode, cbMode, btnImage, chkFollow, chkBands,
    chkUseDisplay], True);
  btnSelect.Visible := IsMobile;
  btnDemo.Text := 'Demo drive (made up)';
  btnLive.Text := 'Live scan';
  lblTime.TextSettings.HorzAlign := TTextAlign.Leading;
  chkAuto.TextSettings.WordWrap := False;
  chkLevelColors.TextSettings.WordWrap := False;
  lblLevelSource.WordWrap := False;
  gbChannel.Parent := pnlLeft;
  gbChannel.Align := TAlignLayout.Bottom;
  gbChannel.Margins.Rect := TRectF.Create(0, 6, 0, 0);
  ShowChannel;
  pnlLeft.Visible := True;
  pnlLeft.Parent := Self;
  pnlLeft.Align := TAlignLayout.Left;
  pnlLeft.Padding.Rect := TRectF.Create(6, 0, 0, 4);
  if IsMobile then
    pnlLeft.Width := 430 // a tablet: bigger text
  else
    pnlLeft.Width := 340;
  pnlLeft.Position.X := 0;
  splLeft.Visible := True;
  splLeft.Position.X := pnlLeft.Width + 1;
  layChart.Align := TAlignLayout.Top;
  layGrid.Visible := True;
  splChart.Visible := True;
  splChart.Position.Y := layChart.Height + 1;
  for var L in [lblStatus0, lblStatus1, lblStatus2] do
  begin
    L.Visible := True;
    L.WordWrap := False;
    L.Margins.Rect := TRectF.Create(8, 0, 0, 0);
  end;
  lblStatus0.Align := TAlignLayout.Left;
  lblStatus0.Width := 520;
  lblStatus1.Align := TAlignLayout.Left;
  lblStatus1.Width := 380;
  lblStatus1.Position.X := 530;
  lblStatus2.Align := TAlignLayout.Client;
  sbLog.Height := 23;
  LayoutChannelWide; // now that the list has its width again
end;

{ Row height of the wide layout: a tablet's controls are taller. }
function WideRowHeight: Single;
begin
  if IsMobile then
    Result := 40
  else
    Result := 30;
end;

{ Wide: the bar and playback rows left to right, each control as wide as its
  text in the active style, wrapping to another line when the window is too
  narrow. A label stays on the line of the field after it. }
procedure TLogViewerForm.FlowWideBars;

  function Ctls(const A: array of TControl): TArray<TControl>;
  var
    I: Integer;
  begin
    SetLength(Result, Length(A));
    for I := 0 to High(A) do
      Result[I] := A[I];
  end;

  function Flow(const Groups: array of TArray<TControl>; W: Single): Single;
  const
    Gap = 6;
    GroupGap = 14;
  var
    G: TArray<TControl>;
    C: TControl;
    X, Y, GW, RowH: Single;
  begin
    RowH := WideRowHeight;
    X := 8;
    Y := 5;
    for G in Groups do
    begin
      GW := 0;
      for C in G do
        if C.Visible then
        begin
          if ((C is TLabel) or (C is TCheckBox) or (C is TCustomButton)) and (C <> lblTime) then
          begin
            if C is TLabel then
              TLabel(C).WordWrap := False;
            FitTextWidth(C, IfThen(C is TCustomButton, 36, 0));
          end;
          GW := GW + C.Width + Gap;
        end;
      if GW = 0 then
        Continue;
      if (X > 8) and (X + GW > W - 8) then
      begin
        X := 8;
        Y := Y + RowH + 6;
      end;
      for C in G do
        if C.Visible then
        begin
          if C is TTrackBar then
            C.SetBounds(X, Y + (RowH - 20) / 2, C.Width, 20)
          else
            C.SetBounds(X, Y, C.Width, RowH);
          X := X + C.Width + Gap;
        end;
      X := X + GroupGap - Gap;
    end;
    Result := Y + RowH + 5;
  end;

var
  S: string;
begin
  S := lblTime.Text; // as wide as the longest time it will show
  lblTime.Text := '00:00.0 / 00:00.0';
  FitTextWidth(lblTime);
  lblTime.Width := lblTime.Width + 12; // bold
  lblTime.Text := S;
  tbPos.Width := 300;
  cbMode.Width := 210;
  cbSpeed.Width := 84; // "10 min" too
  pnlBar.Height := Flow([Ctls([btnOpen, cbRecent, btnDemo, btnLive]), Ctls([lblView, cbView, btnSaveView, btnDeleteView]),
    Ctls([lblMode, cbMode, btnImage])], InnerWidth(Self));
  pnlPlay.Height := Flow([Ctls([btnStart, btnPlay, btnEnd, cbSpeed]), Ctls([tbPos, lblTime]), Ctls([chkFollow, chkBands]),
    Ctls([chkUseDisplay]), Ctls([btnSelect])], InnerWidth(Self));
end;

{ Wide: the channel box under the list, captions as wide as their text. }
procedure TLogViewerForm.LayoutChannelWide;
var
  W, Y, X, FW, RowH: Single;
begin
  RowH := WideRowHeight;
  W := pnlLeft.Width - pnlLeft.Padding.Left - pnlLeft.Padding.Right - 24;
  for var L in [lblColor, lblWidth, lblMin, lblMax] do
  begin
    L.WordWrap := False;
    FitTextWidth(L);
  end;
  Y := 30;
  // Colour [.....] Width [..]
  cbWidth.Width := 76;
  lblColor.SetBounds(12, Y, lblColor.Width, RowH);
  X := 12 + lblColor.Width + 4;
  FW := Max(90, W - lblColor.Width - 4 - 12 - lblWidth.Width - 4 - cbWidth.Width);
  cbxColor.SetBounds(X, Y, FW, RowH);
  X := X + FW + 12;
  lblWidth.SetBounds(X, Y, lblWidth.Width, RowH);
  cbWidth.SetBounds(X + lblWidth.Width + 4, Y, cbWidth.Width, RowH);
  Y := Y + RowH + 6;
  FitTextWidth(chkAuto);
  chkAuto.SetBounds(12, Y, Min(chkAuto.Width, W), RowH - 6);
  Y := Y + RowH;
  // Min [....] Max [....]
  FW := Max(60, (W - lblMin.Width - lblMax.Width - 4 * 2 - 12) / 2);
  lblMin.SetBounds(12, Y, lblMin.Width, RowH);
  edtMin.SetBounds(12 + lblMin.Width + 4, Y, FW, RowH);
  X := 12 + lblMin.Width + 4 + FW + 12;
  lblMax.SetBounds(X, Y, lblMax.Width, RowH);
  edtMax.SetBounds(X + lblMax.Width + 4, Y, FW, RowH);
  Y := Y + RowH + 6;
  FitTextWidth(chkLevelColors);
  chkLevelColors.SetBounds(12, Y, Min(chkLevelColors.Width, W), RowH - 6);
  Y := Y + RowH;
  FitTextWidth(btnLevels, 120);
  btnLevels.SetBounds(12, Y, btnLevels.Width, RowH);
  Y := Y + RowH + 4;
  lblLevelSource.SetBounds(12, Y, W, 22);
  Y := Y + 22 + 10;
  gbChannel.Height := Y;
end;

procedure TLogViewerForm.FormDestroy(Sender: TObject);
begin
  FOwnData.Free;
  FViews.Free;
  if Viewer = Self then
    Viewer := nil;
end;

{ Wide: the chart keeps its share of the height when the window changes
  (a tablet turned), rather than the grid taking all of the change. }
procedure TLogViewerForm.MainResized(Sender: TObject);
begin
  if not FNarrow and (FMainHeight > 100) and (pnlMain.Height > 100) and
    (Abs(pnlMain.Height - FMainHeight) > 1) then
    layChart.Height := Max(120, Min(pnlMain.Height - 80, Round(layChart.Height * pnlMain.Height / FMainHeight)));
  FMainHeight := pnlMain.Height;
end;

procedure TLogViewerForm.FormResize(Sender: TObject);
var
  Narrow: Boolean;
  W, H: Single;
begin
  if FTopBar = nil then
    Exit;
  W := InnerWidth(Self);
  H := InnerHeight(Self);
  FShort := (H < ShortHeight) and (W > H);
  Narrow := FShort or (W < NarrowWidth);
  if Narrow then
  begin
    FNarrow := True;
    LayoutNarrow;
  end
  else
  begin
    if FNarrow or not FLaidOut then
    begin
      FNarrow := False;
      LayoutWide;
    end;
    FlowWideBars;
    LayoutStatus;
    // a tablet: the list no wider than it needs to be upright
    if IsMobile and (pnlLeft.Width <> Min(430, Round(W * 0.4))) then
    begin
      pnlLeft.Width := Min(430, Round(W * 0.4));
      LayoutChannelWide;
    end;
    if layChart.Height > pnlMain.Height - 80 then
      layChart.Height := Max(120, pnlMain.Height - 120);
  end;
  FLaidOut := True;
end;

{ The colour box: the chart palette first, then the usual named colours. }
procedure TLogViewerForm.FillColors;
const
  Names: array[0..11] of string = ('Blue', 'Red', 'Green', 'Orange', 'Purple', 'Teal', 'Salmon', 'Grey',
    'Brown', 'Steel', 'Pink', 'Olive');
var
  I: Integer;
  Item: TListBoxItem;
  Bmp: TBitmap;
begin
  SetupColorCombo(cbxColor, False);
  for I := High(ChannelPalette) downto 0 do
  begin
    Item := TListBoxItem.Create(cbxColor);
    Item.Text := 'Chart ' + Names[I];
    Item.Tag := Integer(ChannelPalette[I]);
    Bmp := TBitmap.Create(16, 16);
    try
      if Bmp.Canvas.BeginScene then
      try
        Bmp.Canvas.Clear(TAlphaColors.Null);
        Bmp.Canvas.Fill.Kind := TBrushKind.Solid;
        Bmp.Canvas.Fill.Color := ChannelPalette[I];
        Bmp.Canvas.FillRect(TRectF.Create(1, 1, 15, 15), 0, 0, [], 1);
        Bmp.Canvas.Stroke.Kind := TBrushKind.Solid;
        Bmp.Canvas.Stroke.Color := $FF707070;
        Bmp.Canvas.Stroke.Thickness := 1;
        Bmp.Canvas.DrawRect(TRectF.Create(1.5, 1.5, 14.5, 14.5), 0, 0, [], 1);
      finally
        Bmp.Canvas.EndScene;
      end;
      Item.ItemData.Bitmap.Assign(Bmp);
    finally
      Bmp.Free;
    end;
    cbxColor.InsertObject(0, Item);
  end;
  cbxColor.ItemIndex := 0;
end;

function TLogViewerForm.ComboText(Combo: TComboBox): string;
begin
  if Combo.ItemIndex >= 0 then
    Result := Combo.Items[Combo.ItemIndex]
  else
    Result := '';
end;

{ Files and views }

procedure TLogViewerForm.FillRecent;
var
  Files: TArray<string>;
  F: string;
begin
  FLoading := True;
  cbRecent.Items.BeginUpdate;
  try
    cbRecent.Items.Clear;
    if (FLogFolder <> '') and TDirectory.Exists(FLogFolder) then
    begin
      Files := TDirectory.GetFiles(FLogFolder, '*.csv');
      TArray.Sort<string>(Files, TComparer<string>.Construct(
        function(const A, B: string): Integer
        begin
          Result := CompareValue(TFile.GetLastWriteTime(B), TFile.GetLastWriteTime(A));
        end));
      for F in Files do
        if cbRecent.Items.Count < 40 then
          cbRecent.Items.Add(ExtractFileName(F));
    end;
  finally
    cbRecent.Items.EndUpdate;
  end;
  cbRecent.ItemIndex := cbRecent.Items.IndexOf(ExtractFileName(FData.FileName));
  FLoading := False;
  if cbRecent.Items.Count = 0 then
    cbRecent.Hint := 'No logs in ' + FLogFolder
  else
    cbRecent.Hint := 'Recent logs';
end;

procedure TLogViewerForm.btnOpenClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Filter := 'UVScan logs (*.csv)|*.csv|All files (*.*)|*.*';
    Dlg.InitialDir := FLogFolder;
    Dlg.Options := Dlg.Options + [TOpenOption.ofFileMustExist];
    if Dlg.Execute then
      OpenFile(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

procedure TLogViewerForm.OpenFile(const FileName: string);
begin
  SetPlaying(False);
  LeaveLive;
  try
    FData.LoadFromFile(FileName);
  except
    on E: Exception do
    begin
      ShowLog;
      ShowWarning('Could not open the log: ' + E.Message);
      Exit;
    end;
  end;
  ShowLog;
end;

procedure TLogViewerForm.cbRecentChange(Sender: TObject);
begin
  if not FLoading and (cbRecent.ItemIndex >= 0) then
    OpenFile(System.IOUtils.TPath.Combine(FLogFolder, ComboText(cbRecent)));
end;

{ A log file dropped on the chart or the grid opens it. }
procedure TLogViewerForm.FileDragOver(Sender: TObject; const Data: TDragObject; const Point: TPointF;
  var Operation: TDragOperation);
begin
  if Length(Data.Files) > 0 then
    Operation := TDragOperation.Copy;
end;

procedure TLogViewerForm.FileDragDrop(Sender: TObject; const Data: TDragObject; const Point: TPointF);
begin
  if Length(Data.Files) > 0 then
    OpenFile(Data.Files[0]);
end;

procedure TLogViewerForm.btnImageClick(Sender: TObject);
var
  Name, F: string;
  {$IFNDEF ANDROID}
  Dlg: TSaveDialog;
  {$ENDIF}
begin
  if FData.Count = 0 then
    Exit;
  if FLive then
    Name := 'live ' + FormatDateTime('yyyy-mm-dd hhnnss', Now) + '.png'
  else
    Name := ChangeFileExt(IfThen(FData.FileName <> '', ExtractFileName(FData.FileName), 'demo'), '') + '.png';
  if IsMobile then
  begin
    // No save dialog on a phone: the picture goes next to the logs.
    try
      ForceDirectories(FLogFolder);
      F := System.IOUtils.TPath.Combine(FLogFolder, Name);
      FChart.SaveImage(F);
      ShowInfo('Chart saved as ' + F);
    except
      on E: Exception do
        ShowWarning('Could not save the chart: ' + E.Message);
    end;
    Exit;
  end;
  {$IFNDEF ANDROID}
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Filter := 'PNG picture (*.png)|*.png';
    Dlg.DefaultExt := 'png';
    Dlg.InitialDir := FLogFolder;
    Dlg.FileName := Name;
    Dlg.Options := Dlg.Options + [TOpenOption.ofOverwritePrompt];
    if Dlg.Execute then
      FChart.SaveImage(Dlg.FileName);
  finally
    Dlg.Free;
  end;
  {$ENDIF}
end;

procedure TLogViewerForm.btnDemoClick(Sender: TObject);
begin
  SetPlaying(False);
  LeaveLive;
  FData.MakeDemo;
  ShowLog;
end;

{ Live }

procedure TLogViewerForm.btnLiveClick(Sender: TObject);
begin
  if FLive then
    FChart.Follow := True // back to now
  else
    SetLive(True);
end;

procedure TLogViewerForm.SetLive(Value: Boolean);
begin
  if Value and (LiveSource = nil) then
    Value := False;
  if Value = FLive then
  begin
    if Value then
      FChart.Follow := True;
    Exit;
  end;
  SetPlaying(False);
  FLive := Value;
  if Value then
    FData := LiveSource
  else
    FData := FOwnData;
  FillSpeeds;
  ShowLog;
end;

{ Before a log or the demo is loaded (into the viewer's own data). }
procedure TLogViewerForm.LeaveLive;
begin
  if not FLive then
    Exit;
  FLive := False;
  FData := FOwnData;
  FillSpeeds;
  UpdatePlayButton;
end;

{ The box after the playback buttons: playback speed for a log, how much to
  show for live data. }
procedure TLogViewerForm.FillSpeeds;
var
  I, Best: Integer;
  S: Double;
begin
  FLoading := True;
  cbSpeed.Items.BeginUpdate;
  try
    cbSpeed.Items.Clear;
    if FLive then
    begin
      Best := 0;
      for I := 0 to High(LiveSpans) do
      begin
        S := LiveSpans[I];
        if S < 60 then
          cbSpeed.Items.Add(Format('%d s', [Round(S)]))
        else
          cbSpeed.Items.Add(Format('%d min', [Round(S / 60)]));
        if Abs(S - FViews.LiveSpan) < Abs(LiveSpans[Best] - FViews.LiveSpan) then
          Best := I;
      end;
      cbSpeed.ItemIndex := Best;
      cbSpeed.Hint := 'How much of the scan the chart shows';
      FChart.LiveSpan := LiveSpans[Best];
    end
    else
    begin
      for S in Speeds do
        cbSpeed.Items.Add(FormatFloat('0.##', S) + 'x');
      cbSpeed.ItemIndex := FSpeedIndex;
      cbSpeed.Hint := 'Playback speed';
    end;
  finally
    cbSpeed.Items.EndUpdate;
    FLoading := False;
  end;
  if FLive then
  begin
    btnStart.Hint := 'Go to the oldest values kept';
    btnPlay.Hint := 'Pause here / go back to now (Space)';
    btnEnd.Hint := 'Back to now';
  end
  else
  begin
    btnStart.Hint := 'Go to the start';
    btnPlay.Hint := 'Play / pause (Space)';
    btnEnd.Hint := 'Go to the end';
  end;
end;

procedure TLogViewerForm.SpeedChange(Sender: TObject);
begin
  if FLoading or (cbSpeed.ItemIndex < 0) then
    Exit;
  if not FLive then
  begin
    FSpeedIndex := cbSpeed.ItemIndex;
    Exit;
  end;
  FViews.LiveSpan := LiveSpans[Min(cbSpeed.ItemIndex, High(LiveSpans))];
  SaveViews;
  FChart.LiveSpan := FViews.LiveSpan;
  if FChart.Follow then
    FChart.ShowLatest
  else
    FChart.Follow := True; // picking how much to see means: show it now
end;

procedure TLogViewerForm.ChartFollowChange(Sender: TObject);
begin
  UpdatePlayButton;
  if FLive then
  begin
    UpdateStatus;
    if FChart.Follow then
      SyncToCursor(False);
  end;
end;

procedure TLogViewerForm.UpdatePlayButton;
begin
  if FLive then
    btnPlay.Text := IfThen(FChart.Follow, 'Pause', 'Live')
  else
    btnPlay.Text := IfThen(FPlaying, 'Pause', 'Play');
end;

procedure TLogViewerForm.TogglePlay;
begin
  if FLive then
    FChart.Follow := not FChart.Follow
  else
    SetPlaying(not FPlaying);
end;

procedure TLogViewerForm.LiveUpdated(NewChannels: Boolean);
var
  Ch: Integer;
  Lo, Hi: Double;
begin
  if NewChannels then
  begin
    ShowLog; // another scan: its PIDs, the view applied to them
    Exit;
  end;
  FSyncing := True;
  try
    FGrid.RowCount := FData.Count;
  finally
    FSyncing := False;
  end;
  FChart.ShowLatest;
  if FChart.Follow then
    SyncToCursor(False)
  else
  begin
    FGrid.Refresh;
    ShowTime;
  end;
  // The min / avg / max, the status and an automatic scale twice a second.
  if TThread.GetTickCount64 - FLastStats >= 500 then
  begin
    FLastStats := TThread.GetTickCount64;
    ChartSelectionChange(nil);
    MeasureChannels; // new values may need more decimals or room
    // an automatic scale grows with the data: its range in the boxes too
    Ch := SelectedChannel;
    if (Ch >= 0) and FStyles[Ch].AutoScale then
    begin
      AutoRange(FData.Channels[Ch], Lo, Hi);
      FLoading := True;
      try
        edtMin.Text := FormatFloat('0.###', Lo);
        edtMax.Text := FormatFloat('0.###', Hi);
      finally
        FLoading := False;
      end;
    end;
  end;
end;

procedure TLogViewerForm.FillViews(const Select: string);
var
  I: Integer;
begin
  FLoading := True;
  try
    cbView.Items.BeginUpdate;
    try
      cbView.Items.Clear;
      cbView.Items.Add(NoView);
      for I := 0 to FViews.Count - 1 do
        cbView.Items.Add(FViews[I].Name);
    finally
      cbView.Items.EndUpdate;
    end;
    cbView.ItemIndex := Max(0, cbView.Items.IndexOf(Select));
  finally
    FLoading := False;
  end;
  btnDeleteView.Enabled := cbView.ItemIndex > 0;
end;

function TLogViewerForm.CurrentView(const Name: string): TLogView;
var
  I: Integer;
begin
  I := FViews.IndexOf(Name);
  if I >= 0 then
    Result := FViews[I]
  else
    Result := nil;
end;

{ All channels visible (the first eight), colours from the palette. }
procedure TLogViewerForm.DefaultStyles;
var
  I: Integer;
begin
  SetLength(FStyles, FData.ChannelCount);
  for I := 0 to FData.ChannelCount - 1 do
  begin
    FStyles[I] := DefaultChannelStyle(FData.Channels[I].Name, I);
    FStyles[I].Visible := I < 8;
  end;
end;

procedure TLogViewerForm.ApplyView(V: TLogView);
var
  I, J: Integer;
begin
  DefaultStyles;
  if V = nil then
    Exit;
  for I := 0 to FData.ChannelCount - 1 do
  begin
    J := V.IndexOf(FData.Channels[I].Name);
    if J < 0 then
      J := V.IndexOf(FData.Channels[I].Caption);
    if J >= 0 then
    begin
      FStyles[I] := V.Channels[J];
      FStyles[I].Name := FData.Channels[I].Name;
    end
    else
      FStyles[I].Visible := False;
  end;
  FLoading := True;
  try
    cbMode.ItemIndex := Ord(V.Mode);
    chkUseDisplay.IsChecked := V.UseDisplayLevels;
  finally
    FLoading := False;
  end;
  FChart.Mode := V.Mode;
end;

procedure TLogViewerForm.cbViewChange(Sender: TObject);
begin
  if FLoading then
    Exit;
  btnDeleteView.Enabled := cbView.ItemIndex > 0;
  ApplyView(CurrentView(ComboText(cbView)));
  if cbView.ItemIndex > 0 then
    FViews.LastView := ComboText(cbView)
  else
    FViews.LastView := '';
  SaveViews;
  StylesChanged;
  FillChannels;
end;

procedure TLogViewerForm.SaveViews;
begin
  if FViewsFile = '' then
    Exit;
  try
    FViews.SaveToFile(FViewsFile);
  except
    on E: Exception do
      ShowWarning('Could not save the log views: ' + E.Message);
  end;
end;

procedure TLogViewerForm.btnSaveViewClick(Sender: TObject);
var
  Current: string;
begin
  if FData.ChannelCount = 0 then
    Exit;
  if cbView.ItemIndex > 0 then
    Current := ComboText(cbView)
  else
    Current := '';
  AskText('Save log view', 'Name for these channels, colours and scales', Current,
    procedure(Name: string)
    begin
      if (Name = '') or SameText(Name, NoView) then
        Exit;
      if (FViews.IndexOf(Name) >= 0) and not SameText(Name, Current) then
        Confirm(Format('Replace the view "%s"?', [Name]),
          procedure
          begin
            SaveViewAs(Name);
          end)
      else
        SaveViewAs(Name);
    end);
end;

procedure TLogViewerForm.SaveViewAs(const Name: string);
var
  V: TLogView;
begin
  V := TLogView.Create;
  try
    V.Name := Name;
    V.Mode := TChartMode(Max(0, cbMode.ItemIndex));
    V.UseDisplayLevels := chkUseDisplay.IsChecked;
    V.Channels := Copy(FStyles);
    FViews.Put(V);
  finally
    V.Free;
  end;
  FViews.LastView := Name;
  SaveViews;
  FillViews(Name);
end;

procedure TLogViewerForm.btnDeleteViewClick(Sender: TObject);
var
  Name: string;
begin
  Name := ComboText(cbView);
  if FViews.IndexOf(Name) < 0 then
    Exit;
  Confirm(Format('Delete the view "%s"?', [Name]),
    procedure
    var
      I: Integer;
    begin
      I := FViews.IndexOf(Name);
      if I < 0 then
        Exit;
      FViews.Delete(I);
      FViews.LastView := '';
      SaveViews;
      FillViews('');
    end);
end;

procedure TLogViewerForm.cbModeChange(Sender: TObject);
begin
  if FLoading then
    Exit;
  FChart.Mode := TChartMode(Max(0, cbMode.ItemIndex));
end;

{ Showing a log }

procedure TLogViewerForm.ShowLog;
var
  I: Integer;
begin
  SetPlaying(False);
  ApplyView(CurrentView(ComboText(cbView)));
  FChart.Live := FLive;
  FChart.SetData(FData);
  if FLive then
  begin
    FChart.EmptyText := 'Start a scan (or the test display) to chart its values here';
    FChart.NoSamplesText := 'Waiting for values...';
  end
  else
  begin
    FChart.EmptyText := 'Open a log (or the demo) to see it here';
    FChart.NoSamplesText := 'This log has no samples';
  end;
  ComputeLevels;
  FChart.SetStyles(FStyles, FLevels);
  FGrid.ClearColumns;
  FGrid.AddColumn('Time', 80, gaRight);
  for I := 0 to FData.ChannelCount - 1 do
    FGrid.AddColumn(FData.Channels[I].Caption, 96, gaRight);
  FSyncing := True;
  try
    FGrid.RowCount := FData.Count;
    FGrid.TopRow := 0;
  finally
    FSyncing := False;
  end;
  FillChannels;
  if FLive then
    FChart.Follow := True
  else if FData.Count > 0 then
    FChart.SetCursorTime(FData.Times[0], False);
  FChart.ShowLatest;
  UpdatePlayButton;
  SyncToCursor(False);
  if FLive then
    Caption := 'Live chart'
  else if FData.FileName <> '' then
    Caption := 'Log viewer - ' + FData.Title
  else if FData.Title <> '' then
    Caption := 'Log viewer - ' + FData.Title
  else
    Caption := 'Log viewer';
  if FTitle <> nil then
    if FLive then
      FTitle.Text := 'Live chart'
    else
      FTitle.Text := IfThen(FData.Title <> '', FData.Title, 'Log viewer');
  FLoading := True;
  cbRecent.ItemIndex := cbRecent.Items.IndexOf(ExtractFileName(FData.FileName));
  FLoading := False;
  PlaceShortTitle;
  UpdateStatus;
  FGrid.Refresh;
end;

procedure TLogViewerForm.UpdateStatus;
var
  Rate: Double;
begin
  if FLive then
  begin
    if FData.ChannelCount = 0 then
      lblStatus0.Text := 'Live: no scan yet - start one (or the test display) on the Live page'
    else
      lblStatus0.Text := FData.Title + ': the values as they come in'; // Live scan / Test display
    Rate := 0;
    if FData.Duration > 0 then
      Rate := (FData.Count - 1) / FData.Duration;
    if FData.Count > 0 then
      lblStatus1.Text := Format('Last %s kept, %d samples, %.1f /s, %d channels',
        [FormatLogTime(FData.Duration), FData.Count, Rate, FData.ChannelCount])
    else
      lblStatus1.Text := '';
    if FData.Count = 0 then
      lblStatus2.Text := ''
    else if FChart.Follow and IsMobile then
      lblStatus2.Text := 'Touch the chart to pause there and look back'
    else if FChart.Follow then
      lblStatus2.Text := 'Click or drag in the chart to pause there and look back'
    else
      lblStatus2.Text := 'Paused - Live goes back to now';
    LayoutStatus;
    Exit;
  end;
  if FData.Count = 0 then
  begin
    if IsMobile then
      lblStatus0.Text := 'No log open - pick a recent one, or try the demo'
    else
      lblStatus0.Text := 'No log open - press Open log, pick a recent one, or try the demo';
    lblStatus1.Text := '';
    lblStatus2.Text := '';
    LayoutStatus;
    Exit;
  end;
  if IsMobile then
    lblStatus0.Text := IfThen(FData.FileName <> '', ExtractFileName(FData.FileName), FData.Title)
  else
    lblStatus0.Text := IfThen(FData.FileName <> '', FData.FileName, FData.Title);
  Rate := 0;
  if FData.Duration > 0 then
    Rate := (FData.Count - 1) / FData.Duration;
  lblStatus1.Text := Format('%s long, %d samples, %.1f /s, %d channels',
    [FormatLogTime(FData.Duration), FData.Count, Rate, FData.ChannelCount]);
  if FData.Skipped > 0 then
    lblStatus2.Text := Format('%d unreadable rows skipped', [FData.Skipped])
  else if IsMobile then
    lblStatus2.Text := 'Long-press (or Select range) and drag in the chart to select a range'
  else
    lblStatus2.Text := 'Shift+drag in the chart to select a range';
  LayoutStatus;
end;

{ Levels: a channel's own levels, else (if wanted) the ones Display & alerts
  has for the PID with the same name. }
function TLogViewerForm.DisplayLevelsFor(Ch: Integer): TArray<TDisplayLevel>;
var
  I: Integer;
  P: TPidDef;
  D: TPidDisplay;
  Best: TPidDef;
begin
  Result := nil;
  if (FCatalog = nil) or (FDisplay = nil) then
    Exit;
  Best := nil;
  for I := 0 to FCatalog.Count - 1 do
  begin
    P := FCatalog[I];
    // Same name, and the same units: levels in deg C mean nothing to a deg F column.
    if (SameText(P.DisplayName, FData.Channels[Ch].Name) or SameText(P.LongName, FData.Channels[Ch].Name)) and
      (SameText(Trim(P.Units), Trim(FData.Channels[Ch].Units)) or (Trim(FData.Channels[Ch].Units) = '')) then
      Best := P;
  end;
  if Best = nil then
    Exit;
  D := FDisplay.Find(Best.Id);
  if D <> nil then
    Result := Copy(D.Levels);
end;

procedure TLogViewerForm.ComputeLevels;
var
  I: Integer;
begin
  SetLength(FLevels, FData.ChannelCount);
  for I := 0 to FData.ChannelCount - 1 do
    if (I <= High(FStyles)) and (Length(FStyles[I].Levels) > 0) then
      FLevels[I] := FStyles[I].Levels
    else if chkUseDisplay.IsChecked then
      FLevels[I] := DisplayLevelsFor(I)
    else
      FLevels[I] := nil;
end;

procedure TLogViewerForm.StylesChanged;
begin
  ComputeLevels;
  FChart.SetStyles(FStyles, FLevels);
  RefreshValues;
  FGrid.Refresh;
end;

procedure TLogViewerForm.chkBandsChange(Sender: TObject);
begin
  FChart.ShowBands := chkBands.IsChecked;
end;

procedure TLogViewerForm.chkUseDisplayChange(Sender: TObject);
begin
  if not FLoading then
  begin
    StylesChanged;
    ShowChannel;
  end;
end;

procedure TLogViewerForm.btnSelectClick(Sender: TObject);
begin
  FChart.SelectMode := btnSelect.IsPressed;
end;

{ Channel list }

procedure TLogViewerForm.FillChannels;
var
  Keep: Integer;
begin
  Keep := Max(0, SelectedChannel);
  FLoading := True;
  try
    SetLength(FValueText, FData.ChannelCount);
    SetLength(FStatText, FData.ChannelCount);
    MeasureChannels;
    for var I := 0 to High(FStatText) do
      FStatText[I] := ['', '', ''];
    FChannels.RowCount := FData.ChannelCount;
    if FChannels.RowCount > 0 then
      FChannels.ItemIndex := Min(Keep, FChannels.RowCount - 1)
    else
      FChannels.ItemIndex := -1;
  finally
    FLoading := False;
  end;
  RefreshValues;
  ChartSelectionChange(nil);
  ShowChannel;
end;

procedure TLogViewerForm.ChannelsGetText(Sender: TObject; Col, Row: Integer; var Text: string);
begin
  if (Row < 0) or (Row >= FData.ChannelCount) then
    Exit;
  case Col of
    ColName: Text := FData.Channels[Row].Caption;
    ColValue:
      if Row <= High(FValueText) then
        Text := FValueText[Row];
    ColMin, ColAvg, ColMax:
      if Row <= High(FStatText) then
        Text := FStatText[Row][Col - ColMin];
  end;
end;

procedure TLogViewerForm.ChannelsGetStyle(Sender: TObject; Col, Row: Integer; var Style: TCellStyle);
var
  Idx, Lvl: Integer;
  V: Double;
begin
  if (Row < 0) or (Row >= FData.ChannelCount) then
    Exit;
  case Col of
    ColName:
      if Row <= High(FStyles) then
      begin
        Style.Fore := FStyles[Row].Color;
        Style.Bold := True;
      end;
    ColValue:
      begin
        Style.Bold := True;
        if Row > High(FLevels) then
          Exit;
        Idx := FData.IndexAt(FChart.CursorTime);
        if Idx < 0 then
          Exit;
        V := FData.Channels[Row].Values[Idx];
        Lvl := LevelIndexFor(FLevels[Row], V);
        if Lvl >= 0 then
        begin
          Style.Back := FLevels[Row][Lvl].RowColor;
          Style.Fore := FLevels[Row][Lvl].TextColor;
        end;
      end;
  else
    if FChart.HasSelection then
      Style.Fore := StatsColor
    else
      Style.Fore := TAlphaColors.Gray;
  end;
end;

procedure TLogViewerForm.ChannelsGetChecked(Sender: TObject; Row: Integer; var Checked: Boolean);
begin
  Checked := (Row >= 0) and (Row <= High(FStyles)) and FStyles[Row].Visible;
end;

procedure TLogViewerForm.ChannelsToggleCheck(Sender: TObject; Row: Integer);
begin
  if FLoading or (Row < 0) or (Row > High(FStyles)) then
    Exit;
  FStyles[Row].Visible := not FStyles[Row].Visible;
  StylesChanged;
end;

procedure TLogViewerForm.ChannelsSelect(Sender: TObject);
begin
  if not FLoading then
    ShowChannel;
end;

{ Row = sample index; -1 = the channel's minimum, -2 = its maximum. }
function TLogViewerForm.ChannelValueText(Ch, Row: Integer): string;
var
  V: Double;
begin
  case Row of
    -1: V := FData.Channels[Ch].MinValue;
    -2: V := FData.Channels[Ch].MaxValue;
  else
    if (Row < 0) or (Row >= FData.Count) then
      Exit('');
    V := FData.Channels[Ch].Values[Row];
  end;
  if IsNan(V) then
    Result := '--'
  else if FData.Channels[Ch].IsSwitch then
    Result := IfThen(V >= 0.5, 'ON', 'OFF')
  else if Ch <= High(FDecimals) then
    Result := FormatFloat('0.' + StringOfChar('0', FDecimals[Ch]), V) // fixed decimals: the same width every row
  else
    Result := FormatFloat('0.###', V);
end;

{ Each channel's decimals, and a Value column wide enough for every channel's
  widest value. While playing, values of changing width (1948 / 1945.25) were
  sometimes too wide and drawn smaller, sometimes not: the column flickered. }
procedure TLogViewerForm.MeasureChannels;
var
  C: Integer;
  W, Need: Single;
begin
  SetLength(FDecimals, FData.ChannelCount);
  for C := 0 to FData.ChannelCount - 1 do
    FDecimals[C] := DecimalsNeeded(FData.Channels[C].Values, FData.Count);
  Need := 0;
  for C := 0 to FData.ChannelCount - 1 do
    if not FData.Channels[C].IsSwitch then
    begin
      W := Max(FChannels.TextWidth(ChannelValueText(C, -1), FChannels.FontSize, True),
        FChannels.TextWidth(ChannelValueText(C, -2), FChannels.FontSize, True));
      Need := Max(Need, W);
    end;
  Need := Max(56, Ceil(Need + 2 * FChannels.CellPadding + 3));
  // grow at once; shrink only for a new log (live data: no jumping back and forth)
  if (Need > FChannels.ColumnWidth(ColValue) + 0.5) or (not FLive and (Need < FChannels.ColumnWidth(ColValue) - 0.5)) then
    FChannels.SetColumnWidth(ColValue, Need);
end;

function NumText(const V: Double): string;
begin
  if IsNan(V) then
    Result := '--'
  else if Abs(V) >= 1000 then
    Result := FormatFloat('0', V)
  else if Abs(V) >= 100 then
    Result := FormatFloat('0.#', V)
  else
    Result := FormatFloat('0.##', V);
end;

{ Lowest, average and highest value in the selected range (the whole log
  when nothing is selected). }
procedure TLogViewerForm.RangeStats(Ch: Integer; out Lo, Avg, Hi: Double);
var
  I0, I1, I, N: Integer;
  V, Sum: Double;
begin
  Lo := NaN;
  Hi := NaN;
  Avg := NaN;
  if FData.Count = 0 then
    Exit;
  if FChart.HasSelection then
  begin
    I0 := FData.IndexAt(Min(FChart.SelStart, FChart.SelEnd));
    I1 := FData.IndexAt(Max(FChart.SelStart, FChart.SelEnd));
  end
  else
  begin
    I0 := 0;
    I1 := FData.Count - 1;
  end;
  Sum := 0;
  N := 0;
  for I := I0 to I1 do
  begin
    V := FData.Channels[Ch].Values[I];
    if IsNan(V) then
      Continue;
    if IsNan(Lo) or (V < Lo) then
      Lo := V;
    if IsNan(Hi) or (V > Hi) then
      Hi := V;
    Sum := Sum + V;
    Inc(N);
  end;
  if N > 0 then
    Avg := Sum / N;
end;

{ Min / avg / max of the selection (or the whole log) in the channel list. }
procedure TLogViewerForm.ChartSelectionChange(Sender: TObject);
var
  I: Integer;
  Lo, Avg, Hi: Double;
  Suffix: string;
begin
  if FChart.HasSelection then
  begin
    Suffix := '*';
    lblStatus2.Text := Format('Selection %s - %s (%s): min / avg / max marked *.%s',
      [FormatLogTime(Min(FChart.SelStart, FChart.SelEnd) - FData.Times[0]),
       FormatLogTime(Max(FChart.SelStart, FChart.SelEnd) - FData.Times[0]),
       FormatLogTime(Abs(FChart.SelEnd - FChart.SelStart)),
       IfThen(IsMobile, '', ' Enter = zoom, Esc = clear')]);
  end
  else
  begin
    Suffix := '';
    UpdateStatus;
  end;
  FChannels.SetColumnCaption(ColMin, 'Min' + Suffix);
  FChannels.SetColumnCaption(ColAvg, 'Avg' + Suffix);
  FChannels.SetColumnCaption(ColMax, 'Max' + Suffix);
  for I := 0 to Min(Length(FStatText), FData.ChannelCount) - 1 do
  begin
    RangeStats(I, Lo, Avg, Hi);
    if FData.Channels[I].IsSwitch then
    begin
      // ON / OFF: show how much of the time it was on
      if IsNan(Avg) then
        FStatText[I] := [NumText(Lo), '--', NumText(Hi)]
      else
        FStatText[I] := [NumText(Lo), FormatFloat('0', Avg * 100) + '% on', NumText(Hi)];
    end
    else
      FStatText[I] := [NumText(Lo), NumText(Avg), NumText(Hi)];
  end;
  FChannels.Refresh;
end;

procedure TLogViewerForm.RefreshValues;
var
  I, Row: Integer;
begin
  Row := FData.IndexAt(FChart.CursorTime);
  for I := 0 to Min(Length(FValueText), FData.ChannelCount) - 1 do
    FValueText[I] := ChannelValueText(I, Row);
  FChannels.Refresh;
end;

function TLogViewerForm.SelectedChannel: Integer;
begin
  Result := FChannels.ItemIndex;
  if (Result < 0) or (Result >= FData.ChannelCount) or (Result > High(FStyles)) then
    Result := -1;
end;

{ Selected channel settings }

procedure TLogViewerForm.ShowChannel;
var
  Ch: Integer;
  S: TChannelStyle;
  Lo, Hi: Double;
begin
  Ch := SelectedChannel;
  gbChannel.Enabled := Ch >= 0;
  if Ch < 0 then
  begin
    gbChannel.Text := 'Channel';
    UpdateChannelButton;
    Exit;
  end;
  S := FStyles[Ch];
  FLoading := True;
  try
    gbChannel.Text := FData.Channels[Ch].Caption;
    SetComboColor(cbxColor, S.Color);
    cbWidth.ItemIndex := EnsureRange(S.Width, 1, 4) - 1;
    chkAuto.IsChecked := S.AutoScale;
    if S.AutoScale then
      AutoRange(FData.Channels[Ch], Lo, Hi)
    else
    begin
      Lo := S.MinValue;
      Hi := S.MaxValue;
    end;
    edtMin.Text := FormatFloat('0.###', Lo);
    edtMax.Text := FormatFloat('0.###', Hi);
    edtMin.Enabled := not S.AutoScale;
    edtMax.Enabled := not S.AutoScale;
    chkLevelColors.IsChecked := S.LevelColors;
    if Length(S.Levels) > 0 then
      lblLevelSource.Text := Format('%d alert level(s) of its own', [Length(S.Levels)])
    else if (Ch <= High(FLevels)) and (Length(FLevels[Ch]) > 0) then
      lblLevelSource.Text := Format('%d level(s) from Display & alerts', [Length(FLevels[Ch])])
    else
      lblLevelSource.Text := 'No alert levels';
  finally
    FLoading := False;
  end;
  UpdateChannelButton;
  if FNarrow then
    gbChannel.Text := ''; // the page's title says which channel
end;

procedure TLogViewerForm.ChannelSettingChange(Sender: TObject);
var
  Ch: Integer;
  A, B: Double;
begin
  Ch := SelectedChannel;
  if FLoading or (Ch < 0) then
    Exit;
  FStyles[Ch].Color := GetComboColor(cbxColor);
  FStyles[Ch].Width := Max(0, cbWidth.ItemIndex) + 1;
  FStyles[Ch].LevelColors := chkLevelColors.IsChecked;
  if Sender = chkAuto then
  begin
    FStyles[Ch].AutoScale := chkAuto.IsChecked;
    if not chkAuto.IsChecked then
    begin
      AutoRange(FData.Channels[Ch], A, B);
      FStyles[Ch].MinValue := A;
      FStyles[Ch].MaxValue := B;
    end;
    ShowChannel;
  end
  else if not chkAuto.IsChecked and TryParseNumber(edtMin.Text, A) and TryParseNumber(edtMax.Text, B) and (B > A) then
  begin
    FStyles[Ch].MinValue := A;
    FStyles[Ch].MaxValue := B;
  end;
  StylesChanged;
end;

{ Edits the channel's own alert levels with the Display & alerts dialog. }
procedure TLogViewerForm.btnLevelsClick(Sender: TObject);
var
  Ch: Integer;
  P: TPidDef;
  Temp: TDisplaySettings;
  D: TPidDisplay;
begin
  Ch := SelectedChannel;
  if Ch < 0 then
    Exit;
  P := TPidDef.Create;
  Temp := TDisplaySettings.Create;
  try
    P.Id := 1;
    P.LongName := FData.Channels[Ch].Name;
    P.Units := FData.Channels[Ch].Units;
    D := TPidDisplay.Create(1);
    try
      if Ch <= High(FLevels) then
        D.Levels := Copy(FLevels[Ch]);
      Temp.Put(1, D);
    finally
      D.Free;
    end;
  except
    Temp.Free;
    P.Free;
    raise;
  end;
  // The dialog may return later (phones): P and Temp live until it does.
  TDisplayEditorForm.Execute(P, Temp,
    procedure(OK: Boolean)
    begin
      try
        if OK and (Viewer = Self) and (Ch <= High(FStyles)) then
        begin
          if Temp.Find(1) <> nil then
            FStyles[Ch].Levels := Copy(Temp.Find(1).Levels)
          else
            FStyles[Ch].Levels := nil;
          if (Length(FStyles[Ch].Levels) > 0) and not FStyles[Ch].LevelColors then
            FStyles[Ch].LevelColors := True;
          StylesChanged;
          ShowChannel;
        end;
      finally
        Temp.Free;
        P.Free;
      end;
    end);
end;

{ Grid }

procedure TLogViewerForm.GridGetText(Sender: TObject; Col, Row: Integer; var Text: string);
begin
  if (Row < 0) or (Row >= FData.Count) then
    Exit;
  if Col = 0 then
    Text := FormatLogTime(FData.Times[Row])
  else if Col - 1 < FData.ChannelCount then
    Text := ChannelValueText(Col - 1, Row);
end;

procedure TLogViewerForm.GridGetStyle(Sender: TObject; Col, Row: Integer; var Style: TCellStyle);
var
  Ch, Lvl: Integer;
  V: Double;
begin
  if (Row < 0) or (Row >= FData.Count) then
    Exit;
  if Row = FData.IndexAt(FChart.CursorTime) then
  begin
    Style.Bold := True;
    Style.Back := CursorRowColor;
  end;
  if Col = 0 then
  begin
    Style.Fore := TAlphaColors.Gray;
    Exit;
  end;
  Ch := Col - 1;
  if Ch > High(FLevels) then
    Exit;
  V := FData.Channels[Ch].Values[Row];
  Lvl := LevelIndexFor(FLevels[Ch], V);
  if Lvl >= 0 then
  begin
    if FLevels[Ch][Lvl].RowColor <> NoColor then
      Style.Back := FLevels[Ch][Lvl].RowColor;
    if FLevels[Ch][Lvl].TextColor <> NoColor then
      Style.Fore := FLevels[Ch][Lvl].TextColor;
  end;
end;

procedure TLogViewerForm.GridSelect(Sender: TObject);
var
  Row: Integer;
begin
  Row := FGrid.ItemIndex;
  if FSyncing or (Row < 0) or (Row >= FData.Count) then
    Exit;
  SetPlaying(False);
  FChart.SetCursorTime(FData.Times[Row], False);
  FChart.KeepVisible(FChart.CursorTime);
  SyncToCursor(True);
end;

{ Cursor and playback }

procedure TLogViewerForm.ChartCursorChange(Sender: TObject);
begin
  SetPlaying(False);
  SyncToCursor(False);
end;

{ Moves the grid, the slider, the time and the channel values to the cursor. }
procedure TLogViewerForm.SyncToCursor(FromGrid: Boolean);
var
  Row, Vis: Integer;
begin
  if FSyncing then
    Exit;
  FSyncing := True;
  try
    if FData.Count = 0 then
    begin
      lblTime.Text := '';
      Exit;
    end;
    Row := FData.IndexAt(FChart.CursorTime);
    if not FromGrid and (FGrid.ItemIndex <> Row) then
    begin
      Vis := FGrid.VisibleRows;
      if FPlaying or (FLive and FChart.Follow) then
      begin
        // Moving by itself: the cursor row stays put and the rows scroll
        // under it one at a time. (Jumping a third of the grid every few
        // rows moved every row and colour at once: it looked like flashing.)
        if FLive then
          FGrid.TopRow := Max(0, Row - Vis + 1) // the newest at the bottom
        else
          FGrid.TopRow := Max(0, Row - Vis div 3);
      end
      // Moved by hand: keep the cursor row about a third of the way down.
      else if (Row < FGrid.TopRow) or (Row >= FGrid.TopRow + Vis * 2 div 3) then
        FGrid.TopRow := Max(0, Row - Vis div 3);
      FGrid.ItemIndex := Row;
    end
    else if FPlaying and (Row = FGrid.ItemIndex) then
    begin
      ShowTime; // still on the same row: the grid and the values have not changed
      Exit;
    end;
    FGrid.Refresh;
    ShowTime;
    RefreshValues;
  finally
    FSyncing := False;
  end;
end;

{ The slider and the time: the cursor in the log (live: since the scan started). }
procedure TLogViewerForm.ShowTime;
var
  Was: Boolean;
begin
  if FData.Count = 0 then
    Exit;
  Was := FSyncing;
  FSyncing := True; // moving the slider is not the user's doing
  try
    if FData.Duration > 0 then
      tbPos.Value := Round((FChart.CursorTime - FData.Times[0]) / FData.Duration * tbPos.Max);
  finally
    FSyncing := Was;
  end;
  if FLive then
    lblTime.Text := FormatLogTime(FChart.CursorTime) + ' / ' + FormatLogTime(FData.Times[FData.Count - 1])
  else
    lblTime.Text := FormatLogTime(FChart.CursorTime - FData.Times[0]) + ' / ' + FormatLogTime(FData.Duration);
end;

procedure TLogViewerForm.tbPosChange(Sender: TObject);
begin
  if FSyncing or (FData.Count = 0) then
    Exit;
  SetPlaying(False);
  FChart.SetCursorTime(FData.Times[0] + tbPos.Value / tbPos.Max * FData.Duration, False);
  FChart.KeepVisible(FChart.CursorTime);
  SyncToCursor(False);
end;

procedure TLogViewerForm.SetPlaying(Value: Boolean);
begin
  if (Value and (FData.Count < 2)) or FLive then
    Value := False;
  FPlaying := Value;
  tmrPlay.Enabled := Value;
  UpdatePlayButton;
  if Value then
  begin
    if FChart.CursorTime >= FData.Times[FData.Count - 1] then
      FChart.SetCursorTime(FData.Times[0], False);
    FPlayFrom := FChart.CursorTime;
    FPlayClock := TStopwatch.StartNew;
  end;
end;

procedure TLogViewerForm.btnPlayClick(Sender: TObject);
begin
  TogglePlay;
end;

procedure TLogViewerForm.MoveCursorToRow(Row: Integer);
begin
  SetPlaying(False);
  FChart.SetCursorTime(FData.Times[Row], False);
  FChart.KeepVisible(FChart.CursorTime);
  SyncToCursor(False);
end;

procedure TLogViewerForm.btnStartClick(Sender: TObject);
begin
  if FData.Count > 0 then
    MoveCursorToRow(0);
end;

procedure TLogViewerForm.btnEndClick(Sender: TObject);
begin
  if FLive then
    FChart.Follow := True
  else if FData.Count > 0 then
    MoveCursorToRow(FData.Count - 1);
end;

procedure TLogViewerForm.tmrPlayTimer(Sender: TObject);
var
  T: Double;
begin
  if not FPlaying or (FData.Count < 2) then
    Exit;
  T := FPlayFrom + FPlayClock.Elapsed.TotalSeconds * Speeds[Max(0, cbSpeed.ItemIndex)];
  if T >= FData.Times[FData.Count - 1] then
  begin
    T := FData.Times[FData.Count - 1];
    SetPlaying(False);
  end;
  FChart.SetCursorTime(T, False);
  if chkFollow.IsChecked then
    FChart.KeepVisible(T);
  SyncToCursor(False);
end;

procedure TLogViewerForm.FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  Row: Integer;
  OnChart: Boolean;
begin
  if (Focused <> nil) and ((Focused.GetObject is TCustomEdit) or (Focused.GetObject is TCustomComboBox)) then
    Exit;
  OnChart := (Focused <> nil) and (Focused.GetObject = FChart);
  if KeyChar = ' ' then
  begin
    TogglePlay;
    Key := 0;
    KeyChar := #0;
  end
  else if OnChart and (Key = vkReturn) then
  begin
    FChart.ZoomToSelection;
    Key := 0;
  end
  else if OnChart and (Key = vkEscape) and FChart.HasSelection then
  begin
    FChart.ClearSelection;
    Key := 0;
  end
  else if OnChart and ((Key = vkLeft) or (Key = vkRight) or (Key = vkHome) or (Key = vkEnd)) and
    (FData.Count > 0) then
  begin
    Row := FData.IndexAt(FChart.CursorTime);
    case Key of
      vkLeft: Row := Max(0, Row - IfThen(ssShift in Shift, 10, 1));
      vkRight: Row := Min(FData.Count - 1, Row + IfThen(ssShift in Shift, 10, 1));
      vkHome: Row := 0;
      vkEnd: Row := FData.Count - 1;
    end;
    MoveCursorToRow(Row);
    Key := 0;
  end;
end;

end.
