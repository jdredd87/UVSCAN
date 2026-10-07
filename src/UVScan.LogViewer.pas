unit UVScan.LogViewer;

{ Log viewer: opens UVScan CSV logs (or a made-up demo drive) and shows them
  as a chart and a grid that follow one cursor, with playback, per-channel
  colours / scales / alert levels, and saved view set-ups (logviews.json). }

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Math, System.Diagnostics, System.IOUtils,
  System.Types, System.Generics.Collections, System.Generics.Defaults,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Edit, FMX.ListBox, FMX.Layouts,
  FMX.Controls.Presentation,
  UVScan.Pids, UVScan.Display, UVScan.LogData, UVScan.LogViews, UVScan.LogChart, UVScan.UI.DataGrid;

type
  TLogViewerForm = class(TForm)
    pnlBar: TPanel;
    sbBar: THorzScrollBox;
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
    sbPlay: THorzScrollBox;
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
    FData: TLogData;
    FChart: TLogChart;
    FChannels: TDataGrid;
    FGrid: TDataGrid;
    FViews: TLogViewList;
    FStyles: TArray<TChannelStyle>;
    FLevels: TArray<TArray<TDisplayLevel>>;   // what is in effect per channel
    FValueText: TArray<string>;               // channel list: value at the cursor
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
    procedure ChartCursorChange(Sender: TObject);
    procedure SetPlaying(Value: Boolean);
    function SelectedChannel: Integer;
    function DisplayLevelsFor(Ch: Integer): TArray<TDisplayLevel>;
    function ChannelValueText(Ch, Row: Integer): string;
    procedure UpdateStatus;
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
  public
    { Opens the viewer (one window, reused). FileName '' = just show it. }
    class procedure ShowViewer(Catalog: TPidCatalog; Display: TDisplaySettings; const LogFolder, ViewsFile,
      FileName: string);
  end;

implementation

{$R *.fmx}

uses
  System.StrUtils, FMX.Dialogs, UVScan.UI.Common, UVScan.DisplayEditor;

var
  Viewer: TLogViewerForm;

const
  Speeds: array[0..6] of Double = (0.25, 0.5, 1, 2, 5, 10, 20);
  NoView = '(this log)';
  ColName = 0;
  ColValue = 1;
  ColMin = 2;
  ColAvg = 3;
  ColMax = 4;
  StatsColor = TAlphaColor($FF0060B0);  // selection statistics stand out
  CursorRowColor = TAlphaColor($FFC8E6F5);

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
        ShowWarning('Could not open the log: ' + E.Message);
    end;
  if IsMobile then
  begin
    Viewer.WindowState := TWindowState.wsMaximized;
    KeepInSafeArea(Viewer);
  end
  else if Viewer.WindowState = TWindowState.wsMinimized then
    Viewer.WindowState := TWindowState.wsNormal;
  Viewer.Show;
  Viewer.Activate;
end;

procedure TLogViewerForm.FormCreate(Sender: TObject);
var
  M: TChartMode;
  S: Double;
begin
  FData := TLogData.Create;
  FViews := TLogViewList.Create;

  FChart := TLogChart.Create(Self);
  FChart.Parent := layChart;
  FChart.Align := TAlignLayout.Client;
  FChart.OnCursorChange := ChartCursorChange;
  FChart.OnSelectionChange := ChartSelectionChange;
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
  FGrid.OnGetText := GridGetText;
  FGrid.OnGetStyle := GridGetStyle;
  FGrid.OnSelect := GridSelect;
  FGrid.OnDragOver := FileDragOver;
  FGrid.OnDragDrop := FileDragDrop;

  for M := Low(TChartMode) to High(TChartMode) do
    cbMode.Items.Add(ChartModeCaptions[M]);
  cbMode.ItemIndex := 0;
  for S in Speeds do
    cbSpeed.Items.Add(FormatFloat('0.##', S) + 'x');
  cbSpeed.ItemIndex := 2;
  for var I := 1 to 4 do
    cbWidth.Items.Add(IntToStr(I) + ' px');
  FillColors;
  lblTime.TextSettings.Font.Style := [TFontStyle.fsBold];
  // Phones: no file dialogs (logs are picked from the log folder), and a
  // button to select a range with a finger.
  btnOpen.Visible := not IsMobile;
  btnSelect.Visible := IsMobile;
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
  if (layChart <> nil) and (layChart.Height > pnlMain.Height - 80) then
    layChart.Height := Max(120, pnlMain.Height - 120);
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
  try
    FData.LoadFromFile(FileName);
  except
    on E: Exception do
    begin
      ShowWarning('Could not open the log: ' + E.Message);
      Exit;
    end;
  end;
  ShowLog;
end;

procedure TLogViewerForm.cbRecentChange(Sender: TObject);
begin
  if not FLoading and (cbRecent.ItemIndex >= 0) then
    OpenFile(TPath.Combine(FLogFolder, ComboText(cbRecent)));
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
  Name := ChangeFileExt(IfThen(FData.FileName <> '', ExtractFileName(FData.FileName), 'demo'), '') + '.png';
  if IsMobile then
  begin
    // No save dialog on a phone: the picture goes next to the logs.
    try
      ForceDirectories(FLogFolder);
      F := TPath.Combine(FLogFolder, Name);
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
  FData.MakeDemo;
  ShowLog;
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
  FChart.SetData(FData);
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
  if FData.Count > 0 then
    FChart.SetCursorTime(FData.Times[0], False);
  SyncToCursor(False);
  if FData.FileName <> '' then
    Caption := 'Log viewer - ' + FData.Title
  else if FData.Title <> '' then
    Caption := 'Log viewer - ' + FData.Title
  else
    Caption := 'Log viewer';
  FLoading := True;
  cbRecent.ItemIndex := cbRecent.Items.IndexOf(ExtractFileName(FData.FileName));
  FLoading := False;
  UpdateStatus;
  FGrid.Refresh;
end;

procedure TLogViewerForm.UpdateStatus;
var
  Rate: Double;
begin
  if FData.Count = 0 then
  begin
    if IsMobile then
      lblStatus0.Text := 'No log open - pick a recent one, or try the demo'
    else
      lblStatus0.Text := 'No log open - press Open log, pick a recent one, or try the demo';
    lblStatus1.Text := '';
    lblStatus2.Text := '';
    Exit;
  end;
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
      // Keep the cursor row about a third of the way down.
      Vis := FGrid.VisibleRows;
      if (Row < FGrid.TopRow) or (Row >= FGrid.TopRow + Vis * 2 div 3) then
        FGrid.TopRow := Max(0, Row - Vis div 3);
      FGrid.ItemIndex := Row;
    end;
    FGrid.Refresh;
    if FData.Duration > 0 then
      tbPos.Value := Round((FChart.CursorTime - FData.Times[0]) / FData.Duration * tbPos.Max);
    lblTime.Text := FormatLogTime(FChart.CursorTime - FData.Times[0]) + ' / ' + FormatLogTime(FData.Duration);
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
  FChart.SetCursorTime(FData.Times[0] + tbPos.Value / tbPos.Max * FData.Duration, False);
  FChart.KeepVisible(FChart.CursorTime);
  SyncToCursor(False);
end;

procedure TLogViewerForm.SetPlaying(Value: Boolean);
begin
  if Value and (FData.Count < 2) then
    Value := False;
  FPlaying := Value;
  tmrPlay.Enabled := Value;
  btnPlay.Text := IfThen(Value, 'Pause', 'Play');
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
  if FData.Count > 0 then
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
    SetPlaying(not FPlaying);
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
