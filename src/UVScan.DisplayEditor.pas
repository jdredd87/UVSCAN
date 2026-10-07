unit UVScan.DisplayEditor;

{ "Display & alerts" for one PID: its normal look in the live grid, and the
  alert levels (colours, flashing, sound) shared by the grid and the dashboard. }

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Edit,
  FMX.ListBox, FMX.Layouts, FMX.Objects, FMX.Menus, FMX.Controls.Presentation,
  UVScan.Pids, UVScan.Display, UVScan.UI.DataGrid;

type
  TDisplayEditorForm = class(TForm)
    lytButtons: TLayout;
    btnClear: TButton;
    btnCancel: TButton;
    btnOK: TButton;
    sbMain: TVertScrollBox;
    lblPid: TLabel;
    lblHelp: TLabel;
    gbNormal: TGroupBox;
    rowFont: TLayout;
    lblFontSize: TLabel;
    cbFontSize: TComboBox;
    rowNormalColors: TLayout;
    pairText: TLayout;
    lblTextColor: TLabel;
    cbxText: TComboBox;
    pairRow: TLayout;
    lblRowColor: TLabel;
    cbxRow: TComboBox;
    gbLevels: TGroupBox;
    lytLevelList: TLayout;
    lytLevelButtons: TLayout;
    btnAddLevel: TButton;
    btnDeleteLevel: TButton;
    btnUp: TButton;
    btnDown: TButton;
    btnPresets: TButton;
    lytLevelGrid: TLayout;
    rowName: TLayout;
    pairName: TLayout;
    lblLevelName: TLabel;
    edtLevelName: TEdit;
    pairWhen: TLayout;
    lblWhen: TLabel;
    cbOp: TComboBox;
    edtValue: TEdit;
    rowLevelColors: TLayout;
    pairLevelRow: TLayout;
    lblLevelRow: TLabel;
    cbxLevelRow: TComboBox;
    pairLevelText: TLayout;
    lblLevelText: TLabel;
    cbxLevelText: TComboBox;
    rowFlash: TLayout;
    chkFlash: TCheckBox;
    rowSound: TLayout;
    lblSound: TLabel;
    cbSound: TComboBox;
    btnTestSound: TButton;
    btnBrowseSound: TButton;
    edtSoundFile: TEdit;
    rowRepeat: TLayout;
    chkRepeat: TCheckBox;
    gbPreview: TGroupBox;
    lblPreviewValue: TLabel;
    edtPreview: TEdit;
    pbPreview: TPaintBox;
    tmrFlash: TTimer;
    pmPresets: TPopupMenu;
    miHighIsBad: TMenuItem;
    miLowIsBad: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure NormalChange(Sender: TObject);
    procedure btnAddLevelClick(Sender: TObject);
    procedure btnDeleteLevelClick(Sender: TObject);
    procedure btnUpClick(Sender: TObject);
    procedure btnDownClick(Sender: TObject);
    procedure btnPresetsClick(Sender: TObject);
    procedure LevelChange(Sender: TObject);
    procedure btnBrowseSoundClick(Sender: TObject);
    procedure btnTestSoundClick(Sender: TObject);
    procedure edtPreviewChange(Sender: TObject);
    procedure pbPreviewPaint(Sender: TObject; Canvas: TCanvas);
    procedure btnClearClick(Sender: TObject);
    procedure tmrFlashTimer(Sender: TObject);
    procedure miHighIsBadClick(Sender: TObject);
    procedure miLowIsBadClick(Sender: TObject);
  private
    FPid: TPidDef;
    FDisplay: TPidDisplay;
    FLoading: Boolean;
    FFlashOn: Boolean;
    FNarrow: Boolean;
    grdLevels: TDataGrid;
    procedure LoadAll;
    procedure FillLevels(Select: Integer);
    procedure ShowLevel;
    function CurrentLevel: Integer;
    procedure MoveLevel(Delta: Integer);
    procedure UpdateButtons;
    procedure ApplyPreset(HighIsBad: Boolean);
    procedure SetPreset(HighIsBad: Boolean; const Warn, Alarm: Double; const AlarmText: string);
    function PreviewValue: Double;
    procedure SetValueValid(Valid: Boolean);
    procedure LevelsGetText(Sender: TObject; Col, Row: Integer; var Text: string);
    procedure LevelsGetStyle(Sender: TObject; Col, Row: Integer; var Style: TCellStyle);
    procedure LevelsSelect(Sender: TObject);
    procedure ArrangeRows;
  public
    { Edits Settings' entry for Pid; the caller saves display.json. OnDone
      (may be nil) runs when the dialog closes: True = OK and Settings updated. }
    class procedure Execute(Pid: TPidDef; Settings: TDisplaySettings; const OnDone: TProc<Boolean>);
  end;

const
  { Colours the presets use; readable with the default black text. }
  GoodColor = TAlphaColor($FFC8F0C8);     // pale green
  WarnColor = TAlphaColor($FFFFE680);     // amber
  AlarmColor = TAlphaColor($FFFF5050);    // red
  FontSizes: array[0..9] of Integer = (0, 10, 12, 14, 16, 18, 20, 24, 28, 36);

implementation

{$R *.fmx}

uses
  System.StrUtils, FMX.DialogService, UVScan.UI.Common, UVScan.Sound;

const
  ColName = 0;
  ColWhen = 1;
  ColColours = 2;
  ColFlash = 3;
  ColSound = 4;
  NarrowWidth = 560;
  PtToDip = 96 / 72; // the live grid's font sizes are in points

class procedure TDisplayEditorForm.Execute(Pid: TPidDef; Settings: TDisplaySettings; const OnDone: TProc<Boolean>);
var
  F: TDisplayEditorForm;
  Existing: TPidDisplay;
begin
  F := TDisplayEditorForm.Create(Application);
  F.FPid := Pid;
  Existing := Settings.Find(Pid.Id);
  if Existing <> nil then
    F.FDisplay.Assign(Existing);
  F.FDisplay.PidId := Pid.Id;
  F.LoadAll;
  ShowDialog(F,
    procedure(R: TModalResult)
    begin
      StopAlertSound;
      if R = mrOk then
        Settings.Put(Pid.Id, F.FDisplay);
      if Assigned(OnDone) then
        OnDone(R = mrOk);
    end);
end;

procedure TDisplayEditorForm.FormCreate(Sender: TObject);
var
  Op: TCompareOp;
  S: TAlertSound;
  N: Integer;
begin
  FLoading := True; // filling the boxes fires their OnChange
  FDisplay := TPidDisplay.Create(0);
  for N in FontSizes do
    if N = 0 then
      cbFontSize.Items.Add('Default')
    else
      cbFontSize.Items.Add(IntToStr(N));
  for Op := Low(TCompareOp) to High(TCompareOp) do
    cbOp.Items.Add(CompareOpCaptions[Op]);
  for S := Low(TAlertSound) to High(TAlertSound) do
    cbSound.Items.Add(AlertSoundCaptions[S]);
  SetupColorCombo(cbxText, True);
  SetupColorCombo(cbxRow, True);
  SetupColorCombo(cbxLevelRow, True);
  SetupColorCombo(cbxLevelText, True);

  lblPid.StyledSettings := lblPid.StyledSettings - [TStyledSetting.Style, TStyledSetting.Size];
  lblPid.TextSettings.Font.Style := [TFontStyle.fsBold];
  lblPid.TextSettings.Font.Size := 14;
  lblHelp.StyledSettings := lblHelp.StyledSettings - [TStyledSetting.FontColor];
  lblHelp.TextSettings.FontColor := $FF707070;

  grdLevels := TDataGrid.Create(Self);
  grdLevels.Parent := lytLevelGrid;
  grdLevels.Align := TAlignLayout.Client;
  grdLevels.AddColumn('Name', 110);
  grdLevels.AddColumn('When', 90);
  grdLevels.AddColumn('Colours', 70);
  grdLevels.AddColumn('Flash', 46);
  grdLevels.AddColumn('Sound', 100, gaLeft, True);
  grdLevels.RowHeight := 24;
  grdLevels.HeaderHeight := 24;
  grdLevels.FontSize := 12;
  grdLevels.OnGetText := LevelsGetText;
  grdLevels.OnGetStyle := LevelsGetStyle;
  grdLevels.OnSelect := LevelsSelect;

  chkFlash.TextSettings.WordWrap := True;
  chkRepeat.TextSettings.WordWrap := True;
  btnBrowseSound.Visible := not IsMobile;
  ArrangeRows;
  FLoading := False;
end;

procedure TDisplayEditorForm.FormDestroy(Sender: TObject);
begin
  StopAlertSound;
  FDisplay.Free;
end;

{ Two label + box pairs per row on a wide window, one per row on a phone. }
procedure TDisplayEditorForm.ArrangeRows;
type
  TPair = record
    Row, Left, Right: TLayout;
  end;
var
  Pairs: array[0..2] of TPair;
  P: TPair;

  procedure FitGroup(G: TGroupBox);
  var
    I: Integer;
    H: Single;
    C: TControl;
  begin
    H := G.Padding.Top + G.Padding.Bottom;
    for I := 0 to G.ControlsCount - 1 do
    begin
      C := G.Controls[I];
      if C.Visible and (C.Align = TAlignLayout.Top) then
        H := H + C.Height + C.Margins.Top + C.Margins.Bottom;
    end;
    G.Height := H;
  end;

begin
  Pairs[0].Row := rowNormalColors;
  Pairs[0].Left := pairText;
  Pairs[0].Right := pairRow;
  Pairs[1].Row := rowName;
  Pairs[1].Left := pairName;
  Pairs[1].Right := pairWhen;
  Pairs[2].Row := rowLevelColors;
  Pairs[2].Left := pairLevelRow;
  Pairs[2].Right := pairLevelText;
  for P in Pairs do
    if FNarrow then
    begin
      P.Row.Height := 64;
      P.Left.Align := TAlignLayout.Top;
      P.Left.Height := 32;
      P.Right.Align := TAlignLayout.Client;
      P.Right.Margins.Left := 0;
    end
    else
    begin
      P.Row.Height := 32;
      P.Left.Align := TAlignLayout.Left;
      P.Left.Width := Max(200, (P.Row.Width - 12) / 2);
      P.Right.Align := TAlignLayout.Client;
      P.Right.Margins.Left := 12;
    end;
  if FNarrow then
  begin
    lblHelp.Height := 58;
    rowFlash.Height := 44;
    rowRepeat.Height := 44;
    grdLevels.SetColumnWidth(ColName, 80);
  end
  else
  begin
    lblHelp.Height := 40;
    rowFlash.Height := 28;
    rowRepeat.Height := 28;
    grdLevels.SetColumnWidth(ColName, 110);
  end;
  FitGroup(gbNormal);
  FitGroup(gbLevels);
end;

procedure TDisplayEditorForm.FormResize(Sender: TObject);
begin
  FNarrow := ClientWidth < NarrowWidth;
  if grdLevels <> nil then
    ArrangeRows;
end;

procedure TDisplayEditorForm.LoadAll;
var
  I: Integer;
begin
  FLoading := True;
  try
    lblPid.Text := FPid.LongName + IfThen(FPid.Units <> '', '  (' + FPid.Units + ')', '');
    cbFontSize.ItemIndex := 0;
    for I := 0 to High(FontSizes) do
      if FontSizes[I] = FDisplay.FontSize then
        cbFontSize.ItemIndex := I;
    if (FDisplay.FontSize > 0) and (cbFontSize.ItemIndex = 0) then
    begin
      cbFontSize.Items.Add(IntToStr(FDisplay.FontSize));
      cbFontSize.ItemIndex := cbFontSize.Items.Count - 1;
    end;
    SetComboColor(cbxText, FDisplay.TextColor);
    SetComboColor(cbxRow, FDisplay.RowColor);
  finally
    FLoading := False;
  end;
  FillLevels(0);
end;

procedure TDisplayEditorForm.NormalChange(Sender: TObject);
begin
  if FLoading then
    Exit;
  if cbFontSize.ItemIndex >= 0 then
    FDisplay.FontSize := StrToIntDef(cbFontSize.Items[cbFontSize.ItemIndex], 0)
  else
    FDisplay.FontSize := 0;
  FDisplay.TextColor := GetComboColor(cbxText);
  FDisplay.RowColor := GetComboColor(cbxRow);
  pbPreview.Repaint;
end;

{ Levels }

procedure TDisplayEditorForm.LevelsGetText(Sender: TObject; Col, Row: Integer; var Text: string);
var
  L: TDisplayLevel;
begin
  if Row > High(FDisplay.Levels) then
    Exit;
  L := FDisplay.Levels[Row];
  case Col of
    ColName: Text := L.Name;
    ColWhen: Text := L.Describe;
    ColColours: Text := 'Sample';
    ColFlash: Text := IfThen(L.Flash, 'flash', '');
    ColSound:
      begin
        if L.Sound = asFile then
          Text := ExtractFileName(L.SoundFile)
        else if L.Sound = asNone then
          Text := ''
        else
          Text := AlertSoundCaptions[L.Sound];
        if (Text <> '') and L.RepeatSound then
          Text := Text + ', repeat';
      end;
  end;
end;

procedure TDisplayEditorForm.LevelsGetStyle(Sender: TObject; Col, Row: Integer; var Style: TCellStyle);
var
  L: TDisplayLevel;
begin
  // (The selected row is drawn in the selection colours; the editor below shows its colours.)
  if (Col <> ColColours) or (Row > High(FDisplay.Levels)) or (Row = grdLevels.ItemIndex) then
    Exit;
  L := FDisplay.Levels[Row];
  if L.RowColor <> NoColor then
    Style.Back := L.RowColor
  else
    Style.Back := TAlphaColors.White;
  Style.Fore := L.TextColor;
end;

procedure TDisplayEditorForm.LevelsSelect(Sender: TObject);
begin
  ShowLevel;
end;

procedure TDisplayEditorForm.FillLevels(Select: Integer);
begin
  grdLevels.RowCount := Length(FDisplay.Levels);
  if Length(FDisplay.Levels) > 0 then
    Select := EnsureRange(Select, 0, High(FDisplay.Levels))
  else
    Select := -1;
  if grdLevels.ItemIndex = Select then
    ShowLevel // OnSelect does not fire for the same row
  else
    grdLevels.ItemIndex := Select; // shows the level
  grdLevels.Refresh;
end;

function TDisplayEditorForm.CurrentLevel: Integer;
begin
  if grdLevels = nil then
    Exit(-1);
  Result := grdLevels.ItemIndex;
  if Result > High(FDisplay.Levels) then
    Result := -1;
end;

procedure TDisplayEditorForm.SetValueValid(Valid: Boolean);
begin
  edtValue.StyledSettings := edtValue.StyledSettings - [TStyledSetting.FontColor];
  if Valid then
    edtValue.TextSettings.FontColor := TAlphaColors.Black
  else
    edtValue.TextSettings.FontColor := TAlphaColors.Red; // keeps the last good value
end;

procedure TDisplayEditorForm.ShowLevel;
var
  I: Integer;
  L: TDisplayLevel;
  Ctl: TControl;
begin
  I := CurrentLevel;
  FLoading := True;
  try
    if I >= 0 then
      L := FDisplay.Levels[I]
    else
      L := NewLevel;
    edtLevelName.Text := IfThen(I >= 0, L.Name, '');
    cbOp.ItemIndex := Ord(L.Op);
    edtValue.Text := IfThen(I >= 0, FormatFloat('0.###', L.Value), '');
    SetValueValid(True);
    SetComboColor(cbxLevelRow, L.RowColor);
    SetComboColor(cbxLevelText, L.TextColor);
    chkFlash.IsChecked := L.Flash;
    cbSound.ItemIndex := Ord(L.Sound);
    edtSoundFile.Text := L.SoundFile;
    chkRepeat.IsChecked := L.RepeatSound;
    for Ctl in TArray<TControl>.Create(lblLevelName, edtLevelName, lblWhen, cbOp, edtValue, lblLevelRow,
      cbxLevelRow, lblLevelText, cbxLevelText, chkFlash, lblSound, cbSound, btnTestSound, chkRepeat) do
      Ctl.Enabled := I >= 0;
  finally
    FLoading := False;
  end;
  UpdateButtons;
  pbPreview.Repaint;
end;

procedure TDisplayEditorForm.UpdateButtons;
var
  I: Integer;
  FileSound: Boolean;
begin
  I := CurrentLevel;
  btnDeleteLevel.Enabled := I >= 0;
  btnUp.Enabled := I > 0;
  btnDown.Enabled := (I >= 0) and (I < High(FDisplay.Levels));
  FileSound := (I >= 0) and (cbSound.ItemIndex = Ord(asFile));
  edtSoundFile.Enabled := FileSound;
  btnBrowseSound.Enabled := FileSound;
  btnTestSound.Enabled := (I >= 0) and (cbSound.ItemIndex > 0);
  chkRepeat.Enabled := (I >= 0) and (cbSound.ItemIndex > 0);
end;

procedure TDisplayEditorForm.LevelChange(Sender: TObject);
var
  I: Integer;
  L: TDisplayLevel;
  V: Double;
begin
  if FLoading then
    Exit;
  I := CurrentLevel;
  if I < 0 then
    Exit;
  L := FDisplay.Levels[I];
  L.Name := Trim(edtLevelName.Text);
  L.Op := TCompareOp(Max(0, cbOp.ItemIndex));
  if TryParseNumber(edtValue.Text, V) then
  begin
    L.Value := V;
    SetValueValid(True);
  end
  else
    SetValueValid(False);
  L.RowColor := GetComboColor(cbxLevelRow);
  L.TextColor := GetComboColor(cbxLevelText);
  L.Flash := chkFlash.IsChecked;
  L.Sound := TAlertSound(Max(0, cbSound.ItemIndex));
  L.SoundFile := Trim(edtSoundFile.Text);
  L.RepeatSound := chkRepeat.IsChecked;
  FDisplay.Levels[I] := L;
  grdLevels.Refresh;
  UpdateButtons;
  pbPreview.Repaint;
end;

procedure TDisplayEditorForm.btnAddLevelClick(Sender: TObject);
var
  L: TDisplayLevel;
begin
  L := NewLevel;
  L.Name := 'Level ' + IntToStr(Length(FDisplay.Levels) + 1);
  L.RowColor := WarnColor;
  FDisplay.Levels := FDisplay.Levels + [L];
  FillLevels(High(FDisplay.Levels));
  edtValue.SetFocus;
end;

procedure TDisplayEditorForm.btnDeleteLevelClick(Sender: TObject);
var
  I: Integer;
begin
  I := CurrentLevel;
  if I < 0 then
    Exit;
  Delete(FDisplay.Levels, I, 1);
  FillLevels(I);
end;

procedure TDisplayEditorForm.MoveLevel(Delta: Integer);
var
  I: Integer;
  L: TDisplayLevel;
begin
  I := CurrentLevel;
  if (I < 0) or (I + Delta < 0) or (I + Delta > High(FDisplay.Levels)) then
    Exit;
  L := FDisplay.Levels[I];
  FDisplay.Levels[I] := FDisplay.Levels[I + Delta];
  FDisplay.Levels[I + Delta] := L;
  FillLevels(I + Delta);
end;

procedure TDisplayEditorForm.btnUpClick(Sender: TObject);
begin
  MoveLevel(-1);
end;

procedure TDisplayEditorForm.btnDownClick(Sender: TObject);
begin
  MoveLevel(1);
end;

procedure TDisplayEditorForm.btnPresetsClick(Sender: TObject);
var
  P: TPointF;
begin
  P := btnPresets.LocalToScreen(TPointF.Create(0, btnPresets.Height));
  if IsMobile then
    ShowMenuAsActions(Self, pmPresets, ScreenToClient(P)) // FMX popup menus do not show on Android
  else
    pmPresets.Popup(P.X, P.Y);
end;

procedure TDisplayEditorForm.miHighIsBadClick(Sender: TObject);
begin
  ApplyPreset(True);
end;

procedure TDisplayEditorForm.miLowIsBadClick(Sender: TObject);
begin
  ApplyPreset(False);
end;

{ Green / yellow / red: asks for the two thresholds and replaces the levels. }
procedure TDisplayEditorForm.ApplyPreset(HighIsBad: Boolean);
var
  Ask: TProc;
begin
  Ask :=
    procedure
    var
      Prompts: TArray<string>;
    begin
      if HighIsBad then
        Prompts := ['Yellow at or above', 'Red at or above']
      else
        Prompts := ['Yellow at or below', 'Red at or below'];
      TDialogService.InputQuery('Green / yellow / red', Prompts, ['', ''],
        procedure(const AResult: TModalResult; const AValues: array of string)
        var
          Warn, Alarm: Double;
          AlarmText: string;
        begin
          if (AResult <> mrOk) or (Length(AValues) < 2) then
            Exit;
          AlarmText := AValues[1];
          if not TryParseNumber(AValues[0], Warn) or not TryParseNumber(AValues[1], Alarm) then
          begin
            ShowWarning('Both thresholds must be numbers.');
            Exit;
          end;
          SetPreset(HighIsBad, Warn, Alarm, AlarmText);
        end);
    end;
  if Length(FDisplay.Levels) > 0 then
    Confirm('Replace the existing alert levels?', Ask)
  else
    Ask();
end;

procedure TDisplayEditorForm.SetPreset(HighIsBad: Boolean; const Warn, Alarm: Double; const AlarmText: string);
var
  Op: TCompareOp;
  L: TDisplayLevel;
begin
  if HighIsBad then
    Op := coGE
  else
    Op := coLE;
  FDisplay.Levels := nil;
  L := NewLevel;
  L.Name := 'Alarm';
  L.Op := Op;
  L.Value := Alarm;
  L.RowColor := AlarmColor;
  L.TextColor := TAlphaColors.White;
  L.Flash := True;
  L.Sound := asAlarm;
  FDisplay.Levels := FDisplay.Levels + [L];
  L := NewLevel;
  L.Name := 'Warning';
  L.Op := Op;
  L.Value := Warn;
  L.RowColor := WarnColor;
  FDisplay.Levels := FDisplay.Levels + [L];
  FDisplay.RowColor := GoodColor;
  FLoading := True;
  try
    SetComboColor(cbxRow, GoodColor);
  finally
    FLoading := False;
  end;
  FillLevels(0);
  edtPreview.Text := AlarmText;
  pbPreview.Repaint;
end;

procedure TDisplayEditorForm.btnBrowseSoundClick(Sender: TObject);
{$IFDEF MSWINDOWS}
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Filter := 'Wave sounds (*.wav)|*.wav|All files (*.*)|*.*';
    Dlg.FileName := edtSoundFile.Text;
    Dlg.Options := Dlg.Options + [TOpenOption.ofFileMustExist];
    if Dlg.Execute then
    begin
      edtSoundFile.Text := Dlg.FileName;
      LevelChange(nil);
    end;
  finally
    Dlg.Free;
  end;
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure TDisplayEditorForm.btnTestSoundClick(Sender: TObject);
begin
  if not PlayAlertSound(TAlertSound(Max(0, cbSound.ItemIndex)), Trim(edtSoundFile.Text)) then
    ShowWarning('The sound file could not be played.');
end;

procedure TDisplayEditorForm.btnClearClick(Sender: TObject);
begin
  FDisplay.FontSize := 0;
  FDisplay.TextColor := NoColor;
  FDisplay.RowColor := NoColor;
  FDisplay.Levels := nil;
  LoadAll;
end;

{ Preview: one live-grid row painted the way the grid will paint it. }

function TDisplayEditorForm.PreviewValue: Double;
begin
  if not TryParseNumber(edtPreview.Text, Result) then
    Result := NaN;
end;

procedure TDisplayEditorForm.edtPreviewChange(Sender: TObject);
begin
  pbPreview.Repaint;
end;

procedure TDisplayEditorForm.tmrFlashTimer(Sender: TObject);
begin
  FFlashOn := not FFlashOn;
  if ResolveDisplay(FDisplay, PreviewValue).Flash then
    pbPreview.Repaint;
end;

procedure TDisplayEditorForm.pbPreviewPaint(Sender: TObject; Canvas: TCanvas);
var
  R: TRectF;
  S: TResolvedStyle;
  Row, Txt: TAlphaColor;
  V: Double;
  Status: string;
begin
  if FPid = nil then
    Exit;
  V := PreviewValue;
  S := ResolveDisplay(FDisplay, V);
  S.Colors(FFlashOn, Row, Txt);
  if Row = NoColor then
    Row := TAlphaColors.White;
  if Txt = NoColor then
    Txt := $FF1E1E1E;
  R := pbPreview.LocalRect;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := Row;
  Canvas.FillRect(R, 0, 0, [], 1);
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Color := $FFA0A0A0;
  Canvas.Stroke.Thickness := 1;
  Canvas.DrawRect(TRectF.Create(R.Left + 0.5, R.Top + 0.5, R.Right - 0.5, R.Bottom - 0.5), 0, 0, [], 1);
  R.Inflate(-8, 0);
  if S.Level >= 0 then
    Status := FPid.LongName + '   [' + IfThen(S.LevelName <> '', S.LevelName, 'level ' + IntToStr(S.Level + 1)) + ']'
  else
    Status := FPid.LongName;
  Canvas.Fill.Color := Txt;
  Canvas.Font.Style := [];
  Canvas.Font.Size := 10 * PtToDip;
  Canvas.FillText(TRectF.Create(R.Left, R.Top, R.Left + R.Width * 0.6, R.Bottom), Status, False, 1, [],
    TTextAlign.Leading, TTextAlign.Center);
  Canvas.Font.Style := [TFontStyle.fsBold];
  if S.FontSize > 0 then
    Canvas.Font.Size := S.FontSize * PtToDip
  else
    Canvas.Font.Size := 14 * PtToDip;
  Canvas.FillText(R, FPid.FormatValue(V) + ' ' + FPid.Units, False, 1, [], TTextAlign.Trailing, TTextAlign.Center);
end;

end.
