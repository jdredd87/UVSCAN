unit UVScan.DisplayEditor;

{ "Display & alerts" for one PID, as a page (full screen on a phone): its
  normal look in the live grid, and the alert levels (colours, flashing,
  sound) shared by the grid and the dashboard. The levels are cards; tapping
  one opens it on its own page. }

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Edit,
  FMX.ListBox, FMX.Layouts, FMX.Objects, FMX.Menus, FMX.Controls.Presentation,
  UVScan.Pids, UVScan.Display;

type
  TDisplayEditorForm = class(TForm)
    pnlBar: TRectangle;
    btnCancel: TSpeedButton;
    lblTitle: TLabel;
    btnOK: TButton;
    sbMain: TVertScrollBox;
    lblPid: TLabel;
    pbPreview: TPaintBox;
    rowPreview: TLayout;
    lblPreviewValue: TLabel;
    edtPreview: TEdit;
    lblNormalCap: TLabel;
    rowFont: TLayout;
    lblFontSize: TLabel;
    cbFontSize: TComboBox;
    rowText: TLayout;
    lblTextColor: TLabel;
    cbxText: TComboBox;
    rowRow: TLayout;
    lblRowColor: TLabel;
    cbxRow: TComboBox;
    lblLevelsCap: TLabel;
    lblLevelsHelp: TLabel;
    lytLevelList: TLayout;
    rowLevelButtons: TLayout;
    btnAddLevel: TButton;
    btnPresets: TButton;
    btnClear: TButton;
    pnlLevel: TRectangle;
    pnlLevelBar: TRectangle;
    btnLevelBack: TSpeedButton;
    lblLevelTitle: TLabel;
    btnDeleteLevel: TButton;
    sbLevel: TVertScrollBox;
    rowName: TLayout;
    lblLevelName: TLabel;
    edtLevelName: TEdit;
    lblWhen: TLabel;
    rowWhen: TLayout;
    edtValue: TEdit;
    cbOp: TComboBox;
    rowLevelRow: TLayout;
    lblLevelRow: TLabel;
    cbxLevelRow: TComboBox;
    rowLevelText: TLayout;
    lblLevelText: TLabel;
    cbxLevelText: TComboBox;
    chkFlash: TCheckBox;
    rowSound: TLayout;
    lblSound: TLabel;
    cbSound: TComboBox;
    rowSoundFile: TLayout;
    btnBrowseSound: TButton;
    edtSoundFile: TEdit;
    btnTestSound: TButton;
    chkRepeat: TCheckBox;
    rowMove: TLayout;
    btnUp: TButton;
    btnDown: TButton;
    tmrFlash: TTimer;
    pmPresets: TPopupMenu;
    miHighIsBad: TMenuItem;
    miLowIsBad: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure NormalChange(Sender: TObject);
    procedure btnAddLevelClick(Sender: TObject);
    procedure btnPresetsClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnLevelBackClick(Sender: TObject);
    procedure btnDeleteLevelClick(Sender: TObject);
    procedure LevelChange(Sender: TObject);
    procedure btnBrowseSoundClick(Sender: TObject);
    procedure btnTestSoundClick(Sender: TObject);
    procedure btnUpClick(Sender: TObject);
    procedure btnDownClick(Sender: TObject);
    procedure edtPreviewChange(Sender: TObject);
    procedure pbPreviewPaint(Sender: TObject; Canvas: TCanvas);
    procedure tmrFlashTimer(Sender: TObject);
    procedure miHighIsBadClick(Sender: TObject);
    procedure miLowIsBadClick(Sender: TObject);
  private
    FPid: TPidDef;
    FDisplay: TPidDisplay;
    FLoading: Boolean;
    FFitting: Boolean;
    FStart: string;                  // StateText when it opened
    FFlashOn: Boolean;
    FEditing: Integer;               // level shown on the level page, -1 = none
    FCards: TArray<TRectangle>;
    procedure LoadAll;
    procedure BuildCards;
    procedure CardClick(Sender: TObject);
    procedure OpenLevel(Index: Integer);
    procedure CloseLevel;
    procedure ShowLevel;
    procedure MoveLevel(Delta: Integer);
    procedure UpdateLevelButtons;
    procedure ApplyPreset(HighIsBad: Boolean);
    procedure SetPreset(HighIsBad: Boolean; const Warn, Alarm: Double; const AlarmText: string);
    function PreviewValue: Double;
    procedure SetValueValid(Valid: Boolean);
    procedure FitLayout;
    procedure LevelListResized(Sender: TObject);
    function StateText: string;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ApplyPalette;
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
  public
    { Edits Settings' entry for Pid; the caller saves display.json. OnDone
      (may be nil) runs when the page closes: True = saved and Settings updated. }
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
  System.StrUtils, System.JSON, FMX.DialogService, UVScan.UI.Common, UVScan.UI.Theme, UVScan.Sound;

const
  PtToDip = 96 / 72; // the live grid's font sizes are in points
  CardHeight = 64;

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
  F.FStart := F.StateText;
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
  L: TLabel;
begin
  lytLevelList.OnResized := LevelListResized;
  OnCloseQuery := FormCloseQuery;
  FLoading := True; // filling the boxes fires their OnChange
  FEditing := -1;
  FDisplay := TPidDisplay.Create(0);
  OnKeyUp := FormKeyUp;
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

  btnCancel.Text := '';
  btnLevelBack.Text := '';
  AddLineIcon(btnCancel, IconBack);
  AddLineIcon(btnLevelBack, IconBack);
  for L in [lblPid, lblNormalCap, lblLevelsCap] do
  begin
    L.StyledSettings := L.StyledSettings - [TStyledSetting.Style];
    L.TextSettings.Font.Style := [TFontStyle.fsBold];
  end;
  lblPid.StyledSettings := lblPid.StyledSettings - [TStyledSetting.Size];
  lblPid.TextSettings.Font.Size := 16;
  chkFlash.TextSettings.WordWrap := True;
  chkRepeat.TextSettings.WordWrap := True;
  rowSoundFile.Visible := False;
  btnBrowseSound.Visible := not IsMobile; // no file picker on a phone: type the path
  if not IsMobile then
    lblLevelsHelp.Text := StringReplace(lblLevelsHelp.Text, 'Tap a level', 'Click a level', []);
  ApplyPalette;
  FLoading := False;
end;

procedure TDisplayEditorForm.FormDestroy(Sender: TObject);
begin
  StopAlertSound;
  FDisplay.Free;
end;

procedure TDisplayEditorForm.ApplyPalette;
var
  P: TPalette;
  R: TRectangle;
begin
  P := Palette;
  for R in [pnlBar, pnlLevelBar] do
  begin
    R.Fill.Color := P.Bar;
    R.Stroke.Color := P.BarLine;
  end;
  pnlLevel.Fill.Color := P.Back;
  lblLevelsHelp.StyledSettings := lblLevelsHelp.StyledSettings - [TStyledSetting.FontColor];
  lblLevelsHelp.TextSettings.FontColor := P.Muted;
end;

procedure TDisplayEditorForm.FormResize(Sender: TObject);
begin
  FitLayout;
end;

{ Captions as wide as the widest of them (fonts differ by style), wrapped
  labels as tall as their text. }
procedure TDisplayEditorForm.FitLayout;
var
  Caps: TArray<TLabel>;
  L: TLabel;
  W: Single;
  C: TCheckBox;
begin
  if (lblPid = nil) or FFitting then
    Exit;
  FFitting := True;
  try
  Caps := [lblPreviewValue, lblFontSize, lblTextColor, lblRowColor];
  W := 0;
  for L in Caps do
  begin
    L.WordWrap := False;
    FitTextWidth(L);
    W := Max(W, L.Width);
  end;
  for L in Caps do
    L.Width := W + 8;
  Caps := [lblLevelName, lblLevelRow, lblLevelText, lblSound];
  W := 0;
  for L in Caps do
  begin
    L.WordWrap := False;
    FitTextWidth(L);
    W := Max(W, L.Width);
  end;
  for L in Caps do
    L.Width := W + 8;
  if lblPid.Width > 50 then
    lblPid.Height := WrappedTextHeight(lblPid, lblPid.Width) + 2;
  if lblLevelsHelp.Width > 50 then
    lblLevelsHelp.Height := WrappedTextHeight(lblLevelsHelp, lblLevelsHelp.Width) + 2;
  for C in [chkFlash, chkRepeat] do
    if C.Width > 80 then
      C.Height := Max(40, WrappedTextHeight(C, C.Width - 40) + 12); // the box takes about 40
  BuildCards;
  finally
    FFitting := False;
  end;
end;

{ The form's resize comes before its contents have their new widths (the
  first layout on a phone, a turn): the list's own resize lays out again. }
{ What the user can change, to tell whether closing loses anything. }
function TDisplayEditorForm.StateText: string;
var
  J: TJSONArray;
begin
  J := LevelsToJson(FDisplay.Levels);
  try
    Result := Format('%d|%d|%d|', [FDisplay.FontSize, FDisplay.TextColor, FDisplay.RowColor]) + J.ToJSON;
  finally
    J.Free;
  end;
end;

procedure TDisplayEditorForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := CanCloseEditor(Self, StateText <> FStart, 'Discard your changes to the display and alerts?');
end;

procedure TDisplayEditorForm.LevelListResized(Sender: TObject);
begin
  FitLayout;
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
  FitLayout;
  pbPreview.Repaint;
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

{ Level cards: a swatch in the level's colours, its name and condition, and a
  line with what else it does. }

function LevelDetails(const L: TDisplayLevel): string;
var
  Parts: TArray<string>;
begin
  Parts := nil;
  if L.RowColor <> NoColor then
    Parts := Parts + [ColorName(L.RowColor)];
  if L.TextColor <> NoColor then
    Parts := Parts + [ColorName(L.TextColor) + ' text'];
  if L.Flash then
    Parts := Parts + ['flashes'];
  if L.Sound = asFile then
    Parts := Parts + [ExtractFileName(L.SoundFile)]
  else if L.Sound <> asNone then
    Parts := Parts + [AlertSoundCaptions[L.Sound]];
  if (L.Sound <> asNone) and L.RepeatSound then
    Parts := Parts + ['repeats'];
  if Parts = nil then
    Result := 'no change'
  else
    Result := string.Join('  ' + #$00B7 + '  ', Parts);
end;

procedure TDisplayEditorForm.BuildCards;
var
  I: Integer;
  P: TPalette;
  Card, Swatch: TRectangle;
  Texts: TLayout;
  Top, Sub: TLabel;
  H: Single;
  L: TDisplayLevel;
  Y: Single;
begin
  for Card in FCards do
    Card.Free;
  FCards := nil;
  P := Palette;
  Y := 0;
  for I := 0 to High(FDisplay.Levels) do
  begin
    L := FDisplay.Levels[I];
    Card := TRectangle.Create(Self);
    Card.Parent := lytLevelList;
    Card.Stored := False;
    Card.SetBounds(8, Y, Max(100, lytLevelList.Width - 16), CardHeight);
    Card.Fill.Color := P.Bar;
    Card.Stroke.Color := P.BarLine;
    Card.XRadius := 8;
    Card.YRadius := 8;
    Card.HitTest := True;
    Card.Cursor := crHandPoint;
    Card.Tag := I;
    Card.OnClick := CardClick;
    Swatch := TRectangle.Create(Card);
    Swatch.Parent := Card;
    Swatch.Align := TAlignLayout.Left;
    Swatch.Width := 26;
    Swatch.Margins.Rect := TRectF.Create(12, 18, 6, 18);
    Swatch.HitTest := False;
    Swatch.XRadius := 4;
    Swatch.YRadius := 4;
    if L.RowColor <> NoColor then
      Swatch.Fill.Color := L.RowColor
    else
      Swatch.Fill.Color := P.GridBack;
    Swatch.Stroke.Color := P.BarLine;
    AddChevron(Card);
    // Name line and details in their own box: top-aligned controls would
    // otherwise take the card's full width before the swatch and the chevron.
    Texts := TLayout.Create(Card);
    Texts.Parent := Card;
    Texts.Align := TAlignLayout.Client;
    Texts.HitTest := False;
    Top := TLabel.Create(Card);
    Top.Parent := Texts;
    Top.Align := TAlignLayout.Top;
    Top.Height := 28;
    Top.Margins.Rect := TRectF.Create(8, 6, 4, 0);
    Top.HitTest := False;
    Top.StyledSettings := Top.StyledSettings - [TStyledSetting.Style];
    Top.TextSettings.Font.Style := [TFontStyle.fsBold];
    Top.TextSettings.WordWrap := False;
    Top.TextSettings.Trimming := TTextTrimming.Character;
    Top.Text := IfThen(L.Name <> '', L.Name, 'Level ' + IntToStr(I + 1)) + '     ' + L.Describe;
    Sub := TLabel.Create(Card);
    Sub.Parent := Texts;
    Sub.Align := TAlignLayout.Client;
    Sub.Margins.Rect := TRectF.Create(8, 0, 4, 6);
    Sub.HitTest := False;
    Sub.StyledSettings := Sub.StyledSettings - [TStyledSetting.FontColor];
    Sub.TextSettings.FontColor := P.Muted;
    Sub.TextSettings.WordWrap := True;
    Sub.TextSettings.VertAlign := TTextAlign.Leading;
    Sub.Text := LevelDetails(L);
    // as tall as the details need (swatch 26 + chevron 34 + margins take ~100)
    H := Max(CardHeight, 34 + WrappedTextHeight(Sub, Card.Width - 100) + 10);
    Card.Height := H;
    FCards := FCards + [Card];
    Y := Y + H + 8;
  end;
  if Length(FDisplay.Levels) = 0 then
    lytLevelList.Height := 4
  else
    lytLevelList.Height := Y;
end;

procedure TDisplayEditorForm.CardClick(Sender: TObject);
begin
  OpenLevel(TControl(Sender).Tag);
end;

{ The level page }

procedure TDisplayEditorForm.OpenLevel(Index: Integer);
begin
  if (Index < 0) or (Index > High(FDisplay.Levels)) then
    Exit;
  FEditing := Index;
  ShowLevel;
  pnlLevel.Visible := True;
  pnlLevel.BringToFront;
  sbLevel.ViewportPosition := TPointF.Zero;
  FitLayout;
end;

procedure TDisplayEditorForm.CloseLevel;
begin
  StopAlertSound;
  pnlLevel.Visible := False;
  FEditing := -1;
  BuildCards;
  pbPreview.Repaint;
end;

procedure TDisplayEditorForm.btnLevelBackClick(Sender: TObject);
begin
  CloseLevel;
end;

procedure TDisplayEditorForm.SetValueValid(Valid: Boolean);
begin
  edtValue.StyledSettings := edtValue.StyledSettings - [TStyledSetting.FontColor];
  if Valid then
    edtValue.TextSettings.FontColor := Palette.Text
  else
    edtValue.TextSettings.FontColor := Palette.Bad; // keeps the last good value
end;

procedure TDisplayEditorForm.ShowLevel;
var
  L: TDisplayLevel;
begin
  if FEditing < 0 then
    Exit;
  L := FDisplay.Levels[FEditing];
  FLoading := True;
  try
    lblLevelTitle.Text := IfThen(L.Name <> '', L.Name, 'Level ' + IntToStr(FEditing + 1));
    edtLevelName.Text := L.Name;
    cbOp.ItemIndex := Ord(L.Op);
    edtValue.Text := FormatFloat('0.###', L.Value);
    SetValueValid(True);
    SetComboColor(cbxLevelRow, L.RowColor);
    SetComboColor(cbxLevelText, L.TextColor);
    chkFlash.IsChecked := L.Flash;
    cbSound.ItemIndex := Ord(L.Sound);
    edtSoundFile.Text := L.SoundFile;
    chkRepeat.IsChecked := L.RepeatSound;
  finally
    FLoading := False;
  end;
  UpdateLevelButtons;
end;

procedure TDisplayEditorForm.UpdateLevelButtons;
var
  Sound: Boolean;
begin
  btnUp.Enabled := FEditing > 0;
  btnDown.Enabled := (FEditing >= 0) and (FEditing < High(FDisplay.Levels));
  Sound := cbSound.ItemIndex > 0;
  rowSoundFile.Visible := cbSound.ItemIndex = Ord(asFile);
  btnTestSound.Enabled := Sound;
  chkRepeat.Enabled := Sound;
end;

procedure TDisplayEditorForm.LevelChange(Sender: TObject);
var
  L: TDisplayLevel;
  V: Double;
begin
  if FLoading or (FEditing < 0) then
    Exit;
  L := FDisplay.Levels[FEditing];
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
  FDisplay.Levels[FEditing] := L;
  lblLevelTitle.Text := IfThen(L.Name <> '', L.Name, 'Level ' + IntToStr(FEditing + 1));
  UpdateLevelButtons;
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
  BuildCards;
  OpenLevel(High(FDisplay.Levels));
  if not IsMobile then
    edtValue.SetFocus;
end;

procedure TDisplayEditorForm.btnDeleteLevelClick(Sender: TObject);
var
  I: Integer;
begin
  I := FEditing;
  if I < 0 then
    Exit;
  Confirm(Format('Delete the level "%s"?', [IfThen(FDisplay.Levels[I].Name <> '', FDisplay.Levels[I].Name,
    'Level ' + IntToStr(I + 1))]),
    procedure
    begin
      if I <= High(FDisplay.Levels) then
        Delete(FDisplay.Levels, I, 1);
      CloseLevel;
    end);
end;

procedure TDisplayEditorForm.MoveLevel(Delta: Integer);
var
  I: Integer;
  L: TDisplayLevel;
begin
  I := FEditing;
  if (I < 0) or (I + Delta < 0) or (I + Delta > High(FDisplay.Levels)) then
    Exit;
  L := FDisplay.Levels[I];
  FDisplay.Levels[I] := FDisplay.Levels[I + Delta];
  FDisplay.Levels[I + Delta] := L;
  FEditing := I + Delta;
  UpdateLevelButtons;
  pbPreview.Repaint;
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
  BuildCards;
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
  Confirm('Clear the normal look and all alert levels of this PID?',
    procedure
    begin
      FDisplay.FontSize := 0;
      FDisplay.TextColor := NoColor;
      FDisplay.RowColor := NoColor;
      FDisplay.Levels := nil;
      LoadAll;
    end);
end;

procedure TDisplayEditorForm.btnOKClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TDisplayEditorForm.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TDisplayEditorForm.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if (Key = vkHardwareBack) or (Key = vkEscape) then
  begin
    Key := 0;
    if CloseActionMenu then // the presets menu first
      Exit;
    if pnlLevel.Visible then
      CloseLevel
    else
      ModalResult := mrCancel;
  end;
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
    Row := Palette.GridBack;
  if Txt = NoColor then
  begin
    if (S.RowColor <> NoColor) or (FDisplay.RowColor <> NoColor) then
      Txt := ContrastColor(Row)
    else
      Txt := Palette.GridText;
  end;
  R := pbPreview.LocalRect;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := Row;
  Canvas.FillRect(R, 6, 6, AllCorners, 1);
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Color := Palette.BarLine;
  Canvas.Stroke.Thickness := 1;
  Canvas.DrawRect(TRectF.Create(R.Left + 0.5, R.Top + 0.5, R.Right - 0.5, R.Bottom - 0.5), 6, 6, AllCorners, 1);
  R.Inflate(-10, 0);
  if S.Level >= 0 then
    Status := IfThen(S.LevelName <> '', S.LevelName, 'level ' + IntToStr(S.Level + 1))
  else if IsNan(V) then
    Status := 'type a value below'
  else
    Status := 'normal';
  Canvas.Fill.Color := Txt;
  Canvas.Font.Style := [];
  Canvas.Font.Size := 11 * PtToDip;
  Canvas.FillText(TRectF.Create(R.Left, R.Top, R.Left + R.Width * 0.5, R.Bottom), Status, False, 1, [],
    TTextAlign.Leading, TTextAlign.Center);
  Canvas.Font.Style := [TFontStyle.fsBold];
  if S.FontSize > 0 then
    Canvas.Font.Size := Min(S.FontSize, 22) * PtToDip
  else
    Canvas.Font.Size := 14 * PtToDip;
  Canvas.FillText(R, FPid.FormatValue(V) + ' ' + FPid.Units, False, 1, [], TTextAlign.Trailing, TTextAlign.Center);
end;

end.
