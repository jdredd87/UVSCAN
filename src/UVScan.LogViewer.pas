unit UVScan.LogViewer;

{ Log viewer: opens UVScan CSV logs (or a made-up demo drive) and shows them
  as a chart and a grid that follow one cursor, with playback, per-channel
  colours / scales / alert levels, and saved view set-ups (logviews.json). }

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, System.SysUtils, System.Classes, System.UITypes, System.Math,
  System.Diagnostics, System.IOUtils, System.Types, System.Generics.Collections, System.Generics.Defaults,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Grids,
  UVScan.Pids, UVScan.Display, UVScan.LogData, UVScan.LogViews, UVScan.LogChart;

type
  TLogViewerForm = class(TForm)
    pnlBar: TPanel;
    btnOpen: TButton;
    cbRecent: TComboBox;
    btnDemo: TButton;
    lblView: TLabel;
    cbView: TComboBox;
    btnSaveView: TButton;
    btnDeleteView: TButton;
    btnImage: TButton;
    lblMode: TLabel;
    cbMode: TComboBox;
    pnlPlay: TPanel;
    btnStart: TButton;
    btnPlay: TButton;
    btnEnd: TButton;
    cbSpeed: TComboBox;
    tbPos: TTrackBar;
    lblTime: TLabel;
    chkFollow: TCheckBox;
    chkBands: TCheckBox;
    chkUseDisplay: TCheckBox;
    pnlLeft: TPanel;
    lvChannels: TListView;
    gbChannel: TGroupBox;
    lblColor: TLabel;
    cbxColor: TColorBox;
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
    pnlMain: TPanel;
    splChart: TSplitter;
    grdLog: TDrawGrid;
    sbLog: TStatusBar;
    tmrPlay: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnOpenClick(Sender: TObject);
    procedure cbRecentChange(Sender: TObject);
    procedure btnDemoClick(Sender: TObject);
    procedure cbViewChange(Sender: TObject);
    procedure btnSaveViewClick(Sender: TObject);
    procedure btnDeleteViewClick(Sender: TObject);
    procedure cbModeChange(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnPlayClick(Sender: TObject);
    procedure btnEndClick(Sender: TObject);
    procedure tbPosChange(Sender: TObject);
    procedure tmrPlayTimer(Sender: TObject);
    procedure chkBandsClick(Sender: TObject);
    procedure chkUseDisplayClick(Sender: TObject);
    procedure lvChannelsItemChecked(Sender: TObject; Item: TListItem);
    procedure lvChannelsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure lvChannelsCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure lvChannelsCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
      var DefaultDraw: Boolean);
    procedure ChannelSettingChange(Sender: TObject);
    procedure btnLevelsClick(Sender: TObject);
    procedure grdLogDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure grdLogSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure FormResize(Sender: TObject);
    procedure btnImageClick(Sender: TObject);
  private
    FData: TLogData;
    FChart: TLogChart;
    FViews: TLogViewList;
    FStyles: TArray<TChannelStyle>;
    FLevels: TArray<TArray<TDisplayLevel>>;   // what is in effect per channel
    FCatalog: TPidCatalog;      // not owned: matches log columns to PIDs
    FDisplay: TDisplaySettings; // not owned: their alert levels
    FLogFolder: string;
    FViewsFile: string;
    FLoading: Boolean;
    FSyncing: Boolean;
    FPlaying: Boolean;
    FPlayClock: TStopwatch;
    FPlayFrom: Double;
    procedure FillRecent;
    procedure FillViews(const Select: string);
    procedure ShowLog;
    procedure DefaultStyles;
    procedure ApplyView(V: TLogView);
    function CurrentView(const Name: string): TLogView;
    procedure ComputeLevels;
    procedure FillChannels;
    procedure RefreshValues;
    procedure ShowChannel;
    procedure StylesChanged;
    procedure SyncToCursor(FromGrid: Boolean);
    procedure ChartCursorChange(Sender: TObject);
    procedure SetPlaying(Value: Boolean);
    function SelectedChannel: Integer;
    function DisplayLevelsFor(Ch: Integer): TArray<TDisplayLevel>;
    function ChannelValueText(Ch, Row: Integer): string;
    procedure UpdateStatus;
    procedure SaveViews;
    procedure ColorBoxGetColors(Sender: TCustomColorBox; Items: TStrings);
    procedure ChartSelectionChange(Sender: TObject);
    procedure RangeStats(Ch: Integer; out Lo, Avg, Hi: Double);
    procedure OpenFile(const FileName: string);
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;
  protected
    procedure CreateWnd; override;
  public
    { Opens the viewer (one window, reused). FileName '' = just show it. }
    class procedure ShowViewer(Catalog: TPidCatalog; Display: TDisplaySettings; const LogFolder, ViewsFile,
      FileName: string);
  end;

implementation

{$R *.dfm}

uses
  System.StrUtils, UVScan.DisplayEditor;

var
  Viewer: TLogViewerForm;

const
  Speeds: array[0..6] of Double = (0.25, 0.5, 1, 2, 5, 10, 20);
  NoView = '(this log)';

class procedure TLogViewerForm.ShowViewer(Catalog: TPidCatalog; Display: TDisplaySettings; const LogFolder,
  ViewsFile, FileName: string);
begin
  if Viewer = nil then
    Viewer := TLogViewerForm.Create(Application);
  Viewer.FCatalog := Catalog;
  Viewer.FDisplay := Display;
  Viewer.FLogFolder := LogFolder;
  if Viewer.FViewsFile <> ViewsFile then
  begin
    Viewer.FViewsFile := ViewsFile;
    if FileExists(ViewsFile) then
      try
        Viewer.FViews.LoadFromFile(ViewsFile);
      except
        // a broken file just means no saved views
      end;
    Viewer.FillViews(Viewer.FViews.LastView);
  end;
  Viewer.FillRecent;
  if FileName <> '' then
    try
      Viewer.FData.LoadFromFile(FileName);
      Viewer.ShowLog;
    except
      on E: Exception do
        MessageDlg('Could not open the log: ' + E.Message, mtWarning, [mbOK], 0);
    end;
  Viewer.Show;
  if Viewer.WindowState = wsMinimized then
    Viewer.WindowState := wsNormal;
  Viewer.BringToFront;
end;

procedure TLogViewerForm.FormCreate(Sender: TObject);
var
  M: TChartMode;
  S: Double;
begin
  FData := TLogData.Create;
  FViews := TLogViewList.Create;
  FChart := TLogChart.Create(Self);
  FChart.Parent := pnlMain;
  FChart.Align := alTop;
  FChart.Height := Round(pnlMain.ClientHeight * 0.62);
  FChart.OnCursorChange := ChartCursorChange;
  FChart.OnSelectionChange := ChartSelectionChange;
  splChart.Top := FChart.Height + 1; // keep the splitter under the chart
  for M := Low(TChartMode) to High(TChartMode) do
    cbMode.Items.Add(ChartModeCaptions[M]);
  cbMode.ItemIndex := 0;
  for S in Speeds do
    cbSpeed.Items.Add(FormatFloat('0.##', S) + 'x');
  cbSpeed.ItemIndex := 2;
  for var I := 1 to 4 do
    cbWidth.Items.Add(IntToStr(I) + ' px');
  grdLog.DoubleBuffered := True;
  pnlMain.DoubleBuffered := True;
  cbxColor.OnGetColors := ColorBoxGetColors;
  cbxColor.Style := cbxColor.Style + [cbCustomColors];
  ShowLog;
end;

procedure TLogViewerForm.FormDestroy(Sender: TObject);
begin
  FData.Free;
  FViews.Free;
  if Viewer = Self then
    Viewer := nil;
end;

procedure TLogViewerForm.FormResize(Sender: TObject);
begin
  if (FChart <> nil) and (FChart.Height > pnlMain.ClientHeight - 80) then
    FChart.Height := Max(120, pnlMain.ClientHeight - 120);
end;

procedure TLogViewerForm.ColorBoxGetColors(Sender: TCustomColorBox; Items: TStrings);
const
  Names: array[0..11] of string = ('Blue', 'Red', 'Green', 'Orange', 'Purple', 'Teal', 'Salmon', 'Grey',
    'Brown', 'Steel', 'Pink', 'Olive');
var
  I: Integer;
begin
  for I := 0 to High(ChannelPalette) do
    Items.InsertObject(I, 'Chart ' + Names[I], TObject(ChannelPalette[I]));
end;

{ Files and views }

procedure TLogViewerForm.FillRecent;
var
  Files: TArray<string>;
  F: string;
begin
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
  if cbRecent.Items.Count = 0 then
    cbRecent.TextHint := 'No logs in ' + FLogFolder
  else
    cbRecent.TextHint := 'Recent logs';
end;

procedure TLogViewerForm.btnOpenClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Filter := 'UVScan logs (*.csv)|*.csv|All files (*.*)|*.*';
    Dlg.InitialDir := FLogFolder;
    Dlg.Options := Dlg.Options + [ofFileMustExist];
    if not Dlg.Execute then
      Exit;
    SetPlaying(False);
    try
      FData.LoadFromFile(Dlg.FileName);
    except
      on E: Exception do
      begin
        MessageDlg('Could not open the log: ' + E.Message, mtWarning, [mbOK], 0);
        Exit;
      end;
    end;
    ShowLog;
  finally
    Dlg.Free;
  end;
end;

procedure TLogViewerForm.OpenFile(const FileName: string);
begin
  SetPlaying(False);
  try
    FData.LoadFromFile(FileName);
  except
    on E: Exception do
    begin
      MessageDlg('Could not open the log: ' + E.Message, mtWarning, [mbOK], 0);
      Exit;
    end;
  end;
  ShowLog;
end;

procedure TLogViewerForm.cbRecentChange(Sender: TObject);
begin
  if cbRecent.ItemIndex >= 0 then
    OpenFile(TPath.Combine(FLogFolder, cbRecent.Text));
end;

procedure TLogViewerForm.CreateWnd;
begin
  inherited;
  DragAcceptFiles(Handle, True);
end;

{ A log file dropped on the window opens it. }
procedure TLogViewerForm.WMDropFiles(var Msg: TWMDropFiles);
var
  Buf: array[0..MAX_PATH] of Char;
begin
  try
    if DragQueryFile(Msg.Drop, 0, Buf, Length(Buf)) > 0 then
      OpenFile(Buf);
  finally
    DragFinish(Msg.Drop);
  end;
  Msg.Result := 0;
end;

procedure TLogViewerForm.btnImageClick(Sender: TObject);
var
  Dlg: TSaveDialog;
begin
  if FData.Count = 0 then
    Exit;
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Filter := 'PNG picture (*.png)|*.png';
    Dlg.DefaultExt := 'png';
    Dlg.InitialDir := FLogFolder;
    Dlg.FileName := ChangeFileExt(IfThen(FData.FileName <> '', ExtractFileName(FData.FileName), 'demo'), '') + '.png';
    Dlg.Options := Dlg.Options + [ofOverwritePrompt];
    if Dlg.Execute then
      FChart.SaveImage(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

procedure TLogViewerForm.btnDemoClick(Sender: TObject);
begin
  SetPlaying(False);
  FData.MakeDemo;
  ShowLog;
end;

procedure TLogViewerForm.FillViews(const Select: string);
var
  I: Integer;
begin
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
    chkUseDisplay.Checked := V.UseDisplayLevels;
  finally
    FLoading := False;
  end;
  FChart.Mode := V.Mode;
end;

procedure TLogViewerForm.cbViewChange(Sender: TObject);
begin
  btnDeleteView.Enabled := cbView.ItemIndex > 0;
  ApplyView(CurrentView(cbView.Text));
  if cbView.ItemIndex > 0 then
    FViews.LastView := cbView.Text
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
      MessageDlg('Could not save the log views: ' + E.Message, mtWarning, [mbOK], 0);
  end;
end;

procedure TLogViewerForm.btnSaveViewClick(Sender: TObject);
var
  Name: string;
  V: TLogView;
begin
  if FData.ChannelCount = 0 then
    Exit;
  if cbView.ItemIndex > 0 then
    Name := cbView.Text
  else
    Name := '';
  if not InputQuery('Save log view', 'Name for these channels, colours and scales', Name) then
    Exit;
  Name := Trim(Name);
  if (Name = '') or SameText(Name, NoView) then
    Exit;
  if (FViews.IndexOf(Name) >= 0) and not SameText(Name, cbView.Text) and
    (MessageDlg(Format('Replace the view "%s"?', [Name]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;
  V := TLogView.Create;
  try
    V.Name := Name;
    V.Mode := TChartMode(Max(0, cbMode.ItemIndex));
    V.UseDisplayLevels := chkUseDisplay.Checked;
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
  I: Integer;
begin
  I := FViews.IndexOf(cbView.Text);
  if (I < 0) or (MessageDlg(Format('Delete the view "%s"?', [cbView.Text]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then
    Exit;
  FViews.Delete(I);
  FViews.LastView := '';
  SaveViews;
  FillViews('');
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
  ApplyView(CurrentView(cbView.Text));
  FChart.SetData(FData);
  ComputeLevels;
  FChart.SetStyles(FStyles, FLevels);
  grdLog.ColCount := Max(2, FData.ChannelCount + 1);
  grdLog.RowCount := Max(2, FData.Count + 1);
  grdLog.ColWidths[0] := 80;
  for I := 1 to grdLog.ColCount - 1 do
    grdLog.ColWidths[I] := 96;
  FillChannels;
  if FData.Count > 0 then
    FChart.SetCursorTime(FData.Times[0], False);
  SyncToCursor(False);
  if FData.FileName <> '' then
    Caption := 'Log viewer - ' + FData.Title
  else if FData.Title <> '' then
    Caption := 'Log viewer - ' + FData.Title
  else
    Caption := 'Log viewer';
  cbRecent.ItemIndex := cbRecent.Items.IndexOf(ExtractFileName(FData.FileName));
  UpdateStatus;
  grdLog.Invalidate;
end;

procedure TLogViewerForm.UpdateStatus;
var
  Rate: Double;
begin
  if FData.Count = 0 then
  begin
    sbLog.Panels[0].Text := 'No log open - press Open log, pick a recent one, or try the demo';
    sbLog.Panels[1].Text := '';
    sbLog.Panels[2].Text := '';
    Exit;
  end;
  sbLog.Panels[0].Text := IfThen(FData.FileName <> '', FData.FileName, FData.Title);
  Rate := 0;
  if FData.Duration > 0 then
    Rate := (FData.Count - 1) / FData.Duration;
  sbLog.Panels[1].Text := Format('%s long, %d samples, %.1f /s, %d channels',
    [FormatLogTime(FData.Duration), FData.Count, Rate, FData.ChannelCount]);
  if FData.Skipped > 0 then
    sbLog.Panels[2].Text := Format('%d unreadable rows skipped', [FData.Skipped])
  else
    sbLog.Panels[2].Text := 'Shift+drag in the chart to select a range';
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
    else if chkUseDisplay.Checked then
      FLevels[I] := DisplayLevelsFor(I)
    else
      FLevels[I] := nil;
end;

procedure TLogViewerForm.StylesChanged;
begin
  ComputeLevels;
  FChart.SetStyles(FStyles, FLevels);
  RefreshValues;
  grdLog.Invalidate;
end;

procedure TLogViewerForm.chkBandsClick(Sender: TObject);
begin
  FChart.ShowBands := chkBands.Checked;
end;

procedure TLogViewerForm.chkUseDisplayClick(Sender: TObject);
begin
  if not FLoading then
  begin
    StylesChanged;
    ShowChannel;
  end;
end;

{ Channel list }

procedure TLogViewerForm.FillChannels;
var
  I, Keep: Integer;
  Item: TListItem;
  C: TLogChannel;
begin
  Keep := Max(0, SelectedChannel);
  FLoading := True;
  lvChannels.Items.BeginUpdate;
  try
    lvChannels.Items.Clear;
    for I := 0 to FData.ChannelCount - 1 do
    begin
      C := FData.Channels[I];
      Item := lvChannels.Items.Add;
      Item.Caption := C.Caption;
      Item.SubItems.Add('');
      Item.SubItems.Add('');
      Item.SubItems.Add('');
      Item.SubItems.Add('');
      Item.Checked := (I <= High(FStyles)) and FStyles[I].Visible;
    end;
  finally
    lvChannels.Items.EndUpdate;
    FLoading := False;
  end;
  if lvChannels.Items.Count > 0 then
    lvChannels.ItemIndex := Min(Keep, lvChannels.Items.Count - 1);
  RefreshValues;
  ChartSelectionChange(nil);
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
  else
    Result := FormatFloat('0.###', V);
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
    sbLog.Panels[2].Text := Format('Selection %s - %s (%s): min / avg / max marked *. Enter = zoom, Esc = clear',
      [FormatLogTime(Min(FChart.SelStart, FChart.SelEnd) - FData.Times[0]),
       FormatLogTime(Max(FChart.SelStart, FChart.SelEnd) - FData.Times[0]),
       FormatLogTime(Abs(FChart.SelEnd - FChart.SelStart))]);
  end
  else
  begin
    Suffix := '';
    UpdateStatus;
  end;
  lvChannels.Columns[2].Caption := 'Min' + Suffix;
  lvChannels.Columns[3].Caption := 'Avg' + Suffix;
  lvChannels.Columns[4].Caption := 'Max' + Suffix;
  lvChannels.Items.BeginUpdate;
  try
    for I := 0 to Min(lvChannels.Items.Count, FData.ChannelCount) - 1 do
    begin
      RangeStats(I, Lo, Avg, Hi);
      if FData.Channels[I].IsSwitch then
      begin
        // ON / OFF: show how much of the time it was on
        lvChannels.Items[I].SubItems[1] := NumText(Lo);
        if IsNan(Avg) then
          lvChannels.Items[I].SubItems[2] := '--'
        else
          lvChannels.Items[I].SubItems[2] := FormatFloat('0', Avg * 100) + '% on';
        lvChannels.Items[I].SubItems[3] := NumText(Hi);
      end
      else
      begin
        lvChannels.Items[I].SubItems[1] := NumText(Lo);
        lvChannels.Items[I].SubItems[2] := NumText(Avg);
        lvChannels.Items[I].SubItems[3] := NumText(Hi);
      end;
    end;
  finally
    lvChannels.Items.EndUpdate;
  end;
end;

procedure TLogViewerForm.RefreshValues;
var
  I, Row: Integer;
begin
  Row := FData.IndexAt(FChart.CursorTime);
  lvChannels.Items.BeginUpdate;
  try
    for I := 0 to Min(lvChannels.Items.Count, FData.ChannelCount) - 1 do
      lvChannels.Items[I].SubItems[0] := ChannelValueText(I, Row);
  finally
    lvChannels.Items.EndUpdate;
  end;
end;

function TLogViewerForm.SelectedChannel: Integer;
begin
  Result := lvChannels.ItemIndex;
  if (Result < 0) or (Result >= FData.ChannelCount) or (Result > High(FStyles)) then
    Result := -1;
end;

procedure TLogViewerForm.lvChannelsItemChecked(Sender: TObject; Item: TListItem);
begin
  if FLoading or (Item.Index > High(FStyles)) then
    Exit;
  FStyles[Item.Index].Visible := Item.Checked;
  StylesChanged;
end;

procedure TLogViewerForm.lvChannelsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected then
    ShowChannel;
end;

procedure TLogViewerForm.lvChannelsCustomDrawItem(Sender: TCustomListView; Item: TListItem;
  State: TCustomDrawState; var DefaultDraw: Boolean);
begin
  Sender.Canvas.Brush.Color := clWindow;
  Sender.Canvas.Font.Color := clWindowText;
  if Item.Index <= High(FStyles) then
  begin
    Sender.Canvas.Font.Color := FStyles[Item.Index].Color;
    Sender.Canvas.Font.Style := [fsBold];
  end;
end;

procedure TLogViewerForm.lvChannelsCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
  State: TCustomDrawState; var DefaultDraw: Boolean);
var
  Row, Lvl: Integer;
  V: Double;
begin
  Sender.Canvas.Brush.Color := clWindow;
  Sender.Canvas.Font.Color := clWindowText;
  Sender.Canvas.Font.Style := [];
  if (SubItem = 1) and (Item.Index <= High(FLevels)) then
  begin
    Sender.Canvas.Font.Style := [fsBold];
    Row := FData.IndexAt(FChart.CursorTime);
    if Row < 0 then
      Exit;
    V := FData.Channels[Item.Index].Values[Row];
    Lvl := LevelIndexFor(FLevels[Item.Index], V);
    if Lvl >= 0 then
    begin
      if FLevels[Item.Index][Lvl].RowColor <> clNone then
        Sender.Canvas.Brush.Color := FLevels[Item.Index][Lvl].RowColor;
      if FLevels[Item.Index][Lvl].TextColor <> clNone then
        Sender.Canvas.Font.Color := FLevels[Item.Index][Lvl].TextColor;
    end;
  end
  else if SubItem > 1 then
  begin
    Sender.Canvas.Font.Color := clGrayText;
    if FChart.HasSelection then
      Sender.Canvas.Font.Color := TColor($00B06000); // selection statistics stand out
  end;
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
  for var I := 0 to gbChannel.ControlCount - 1 do
    gbChannel.Controls[I].Enabled := Ch >= 0;
  if Ch < 0 then
  begin
    gbChannel.Caption := ' Channel ';
    Exit;
  end;
  S := FStyles[Ch];
  FLoading := True;
  try
    gbChannel.Caption := ' ' + FData.Channels[Ch].Caption + ' ';
    cbxColor.Selected := S.Color;
    cbWidth.ItemIndex := EnsureRange(S.Width, 1, 4) - 1;
    chkAuto.Checked := S.AutoScale;
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
    chkLevelColors.Checked := S.LevelColors;
    if Length(S.Levels) > 0 then
      lblLevelSource.Caption := Format('%d alert level(s) of its own', [Length(S.Levels)])
    else if (Ch <= High(FLevels)) and (Length(FLevels[Ch]) > 0) then
      lblLevelSource.Caption := Format('%d level(s) from Display && alerts', [Length(FLevels[Ch])])
    else
      lblLevelSource.Caption := 'No alert levels';
  finally
    FLoading := False;
  end;
end;

procedure TLogViewerForm.ChannelSettingChange(Sender: TObject);
var
  Ch: Integer;
  A, B: Double;
begin
  Ch := SelectedChannel;
  if FLoading or (Ch < 0) then
    Exit;
  FStyles[Ch].Color := cbxColor.Selected;
  FStyles[Ch].Width := Max(0, cbWidth.ItemIndex) + 1;
  FStyles[Ch].LevelColors := chkLevelColors.Checked;
  if Sender = chkAuto then
  begin
    FStyles[Ch].AutoScale := chkAuto.Checked;
    if not chkAuto.Checked then
    begin
      AutoRange(FData.Channels[Ch], A, B);
      FStyles[Ch].MinValue := A;
      FStyles[Ch].MaxValue := B;
    end;
    ShowChannel;
  end
  else if not chkAuto.Checked and TryParseNumber(edtMin.Text, A) and TryParseNumber(edtMax.Text, B) and (B > A) then
  begin
    FStyles[Ch].MinValue := A;
    FStyles[Ch].MaxValue := B;
  end;
  StylesChanged;
  lvChannels.Invalidate;
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
  D := TPidDisplay.Create(1);
  try
    P.Id := 1;
    P.LongName := FData.Channels[Ch].Name;
    P.Units := FData.Channels[Ch].Units;
    if Ch <= High(FLevels) then
      D.Levels := Copy(FLevels[Ch]);
    Temp.Put(1, D);
    if not TDisplayEditorForm.Execute(P, Temp) then
      Exit;
    if Temp.Find(1) <> nil then
      FStyles[Ch].Levels := Copy(Temp.Find(1).Levels)
    else
      FStyles[Ch].Levels := nil;
    if (Length(FStyles[Ch].Levels) > 0) and not FStyles[Ch].LevelColors then
      FStyles[Ch].LevelColors := True;
    StylesChanged;
    ShowChannel;
  finally
    D.Free;
    Temp.Free;
    P.Free;
  end;
end;

{ Grid }

procedure TLogViewerForm.grdLogDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
var
  C: TCanvas;
  R: TRect;
  Text: string;
  Row, Ch, Lvl: Integer;
  V: Double;
  Flags: Cardinal;
  Cursor: Boolean;
begin
  C := grdLog.Canvas;
  R := Rect;
  C.Font.Size := 9;
  C.Font.Style := [];
  C.Font.Color := clWindowText;
  Flags := DT_SINGLELINE or DT_VCENTER or DT_RIGHT or DT_END_ELLIPSIS;
  if ARow = 0 then
  begin
    C.Brush.Color := clBtnFace;
    C.FillRect(R);
    C.Font.Style := [fsBold];
    if ACol = 0 then
      Text := 'Time'
    else if ACol - 1 < FData.ChannelCount then
    begin
      Text := FData.Channels[ACol - 1].Caption;
      if ACol - 1 <= High(FStyles) then
        C.Font.Color := FStyles[ACol - 1].Color;
    end;
    InflateRect(R, -4, 0);
    DrawText(C.Handle, PChar(Text), -1, R, Flags);
    Exit;
  end;
  Row := ARow - 1;
  Cursor := Row = FData.IndexAt(FChart.CursorTime);
  if Cursor then
    C.Brush.Color := TColor($00F5E6C8)
  else if Odd(ARow) then
    C.Brush.Color := clWindow
  else
    C.Brush.Color := $00F7F3F0;
  Text := '';
  if Row < FData.Count then
  begin
    if ACol = 0 then
    begin
      Text := FormatLogTime(FData.Times[Row]);
      C.Font.Color := clGrayText;
    end
    else
    begin
      Ch := ACol - 1;
      Text := ChannelValueText(Ch, Row);
      if Ch <= High(FLevels) then
      begin
        V := FData.Channels[Ch].Values[Row];
        Lvl := LevelIndexFor(FLevels[Ch], V);
        if Lvl >= 0 then
        begin
          if FLevels[Ch][Lvl].RowColor <> clNone then
            C.Brush.Color := FLevels[Ch][Lvl].RowColor;
          if FLevels[Ch][Lvl].TextColor <> clNone then
            C.Font.Color := FLevels[Ch][Lvl].TextColor;
        end;
      end;
    end;
  end;
  if Cursor then
    C.Font.Style := [fsBold];
  C.FillRect(R);
  InflateRect(R, -4, 0);
  DrawText(C.Handle, PChar(Text), -1, R, Flags);
end;

procedure TLogViewerForm.grdLogSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
begin
  if FSyncing or (ARow < 1) or (ARow > FData.Count) then
    Exit;
  SetPlaying(False);
  FChart.SetCursorTime(FData.Times[ARow - 1], False);
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
  Row, OldRow: Integer;
begin
  if FSyncing then
    Exit;
  FSyncing := True;
  try
    if FData.Count = 0 then
    begin
      lblTime.Caption := '';
      Exit;
    end;
    Row := FData.IndexAt(FChart.CursorTime);
    OldRow := grdLog.Row;
    if not FromGrid and (grdLog.Row <> Row + 1) then
    begin
      // Move without the grid's own scrolling (it blits rows around and can
      // leave stale ones behind at playback speed), then repaint once.
      SendMessage(grdLog.Handle, WM_SETREDRAW, 0, 0);
      try
        if (Row + 1 < grdLog.TopRow) or (Row + 1 >= grdLog.TopRow + grdLog.VisibleRowCount * 2 div 3) then
          grdLog.TopRow := EnsureRange(Row + 1 - grdLog.VisibleRowCount div 3, 1,
            Max(1, grdLog.RowCount - grdLog.VisibleRowCount));
        grdLog.Row := Row + 1;
      finally
        SendMessage(grdLog.Handle, WM_SETREDRAW, 1, 0);
      end;
      grdLog.Invalidate;
    end
    else if OldRow <> Row + 1 then
      grdLog.Invalidate;
    if FData.Duration > 0 then
      tbPos.Position := Round((FChart.CursorTime - FData.Times[0]) / FData.Duration * tbPos.Max);
    lblTime.Caption := FormatLogTime(FChart.CursorTime - FData.Times[0]) + ' / ' + FormatLogTime(FData.Duration);
    RefreshValues;
  finally
    FSyncing := False;
  end;
end;

procedure TLogViewerForm.tbPosChange(Sender: TObject);
begin
  if FSyncing or (FData.Count = 0) then
    Exit;
  SetPlaying(False);
  FChart.SetCursorTime(FData.Times[0] + tbPos.Position / tbPos.Max * FData.Duration, False);
  FChart.KeepVisible(FChart.CursorTime);
  SyncToCursor(False);
end;

procedure TLogViewerForm.SetPlaying(Value: Boolean);
begin
  if Value and (FData.Count < 2) then
    Value := False;
  FPlaying := Value;
  tmrPlay.Enabled := Value;
  btnPlay.Caption := IfThen(Value, 'Pause', 'Play');
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
  SetPlaying(not FPlaying);
end;

procedure TLogViewerForm.btnStartClick(Sender: TObject);
begin
  if FData.Count = 0 then
    Exit;
  SetPlaying(False);
  FChart.SetCursorTime(FData.Times[0], False);
  FChart.KeepVisible(FChart.CursorTime);
  SyncToCursor(False);
end;

procedure TLogViewerForm.btnEndClick(Sender: TObject);
begin
  if FData.Count = 0 then
    Exit;
  SetPlaying(False);
  FChart.SetCursorTime(FData.Times[FData.Count - 1], False);
  FChart.KeepVisible(FChart.CursorTime);
  SyncToCursor(False);
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
  if chkFollow.Checked then
    FChart.KeepVisible(T);
  SyncToCursor(False);
end;

procedure TLogViewerForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Row: Integer;
begin
  if (ActiveControl is TCustomEdit) or (ActiveControl is TCustomComboBox) then
    Exit;
  if Key = VK_SPACE then
  begin
    SetPlaying(not FPlaying);
    Key := 0;
  end
  else if (ActiveControl = FChart) and (Key = VK_RETURN) then
  begin
    FChart.ZoomToSelection;
    Key := 0;
  end
  else if (ActiveControl = FChart) and (Key = VK_ESCAPE) and FChart.HasSelection then
  begin
    FChart.ClearSelection;
    Key := 0;
  end
  else if (ActiveControl = FChart) and (Key in [VK_LEFT, VK_RIGHT, VK_HOME, VK_END]) and (FData.Count > 0) then
  begin
    SetPlaying(False);
    Row := FData.IndexAt(FChart.CursorTime);
    case Key of
      VK_LEFT: Row := Max(0, Row - IfThen(ssShift in Shift, 10, 1));
      VK_RIGHT: Row := Min(FData.Count - 1, Row + IfThen(ssShift in Shift, 10, 1));
      VK_HOME: Row := 0;
      VK_END: Row := FData.Count - 1;
    end;
    FChart.SetCursorTime(FData.Times[Row], False);
    FChart.KeepVisible(FChart.CursorTime);
    SyncToCursor(False);
    Key := 0;
  end;
end;

end.
