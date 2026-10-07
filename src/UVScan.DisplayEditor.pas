unit UVScan.DisplayEditor;

{ "Display & alerts" for one PID: its normal look in the live grid, and the
  alert levels (colours, flashing, sound) shared by the grid and the dashboard. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.UITypes, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Menus, UVScan.Pids, UVScan.Display;

type
  TDisplayEditorForm = class(TForm)
    lblPid: TLabel;
    lblHelp: TLabel;
    gbNormal: TGroupBox;
    lblFontSize: TLabel;
    cbFontSize: TComboBox;
    lblTextColor: TLabel;
    cbxText: TColorBox;
    lblRowColor: TLabel;
    cbxRow: TColorBox;
    gbLevels: TGroupBox;
    lvLevels: TListView;
    btnAddLevel: TButton;
    btnDeleteLevel: TButton;
    btnUp: TButton;
    btnDown: TButton;
    btnPresets: TButton;
    lblLevelName: TLabel;
    edtLevelName: TEdit;
    lblWhen: TLabel;
    cbOp: TComboBox;
    edtValue: TEdit;
    lblLevelRow: TLabel;
    cbxLevelRow: TColorBox;
    lblLevelText: TLabel;
    cbxLevelText: TColorBox;
    chkFlash: TCheckBox;
    lblSound: TLabel;
    cbSound: TComboBox;
    edtSoundFile: TEdit;
    btnBrowseSound: TButton;
    btnTestSound: TButton;
    chkRepeat: TCheckBox;
    gbPreview: TGroupBox;
    lblPreviewValue: TLabel;
    edtPreview: TEdit;
    pbPreview: TPaintBox;
    btnClear: TButton;
    btnOK: TButton;
    btnCancel: TButton;
    tmrFlash: TTimer;
    pmPresets: TPopupMenu;
    miHighIsBad: TMenuItem;
    miLowIsBad: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure NormalChange(Sender: TObject);
    procedure lvLevelsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure lvLevelsCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure btnAddLevelClick(Sender: TObject);
    procedure btnDeleteLevelClick(Sender: TObject);
    procedure btnUpClick(Sender: TObject);
    procedure btnDownClick(Sender: TObject);
    procedure btnPresetsClick(Sender: TObject);
    procedure LevelChange(Sender: TObject);
    procedure btnBrowseSoundClick(Sender: TObject);
    procedure btnTestSoundClick(Sender: TObject);
    procedure edtPreviewChange(Sender: TObject);
    procedure pbPreviewPaint(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure tmrFlashTimer(Sender: TObject);
    procedure miHighIsBadClick(Sender: TObject);
    procedure miLowIsBadClick(Sender: TObject);
  private
    FPid: TPidDef;
    FDisplay: TPidDisplay;
    FLoading: Boolean;
    FFlashOn: Boolean;
    procedure LoadAll;
    procedure FillLevels(Select: Integer);
    procedure SetLevelItem(Item: TListItem; const L: TDisplayLevel);
    procedure ShowLevel;
    function CurrentLevel: Integer;
    procedure MoveLevel(Delta: Integer);
    procedure UpdateButtons;
    procedure ApplyPreset(HighIsBad: Boolean);
    function PreviewValue: Double;
    procedure ColorBoxGetColors(Sender: TCustomColorBox; Items: TStrings);
    procedure PrepareColorBox(Box: TColorBox);
  public
    { Edits Settings' entry for Pid; the caller saves display.json. }
    class function Execute(Pid: TPidDef; Settings: TDisplaySettings): Boolean;
  end;

const
  { Colours the presets use; readable with the default black text. }
  GoodColor = TColor($00C8F0C8);     // pale green
  WarnColor = TColor($0080E6FF);     // amber
  AlarmColor = TColor($005050FF);    // red
  FontSizes: array[0..9] of Integer = (0, 10, 12, 14, 16, 18, 20, 24, 28, 36);

implementation

{$R *.dfm}

uses
  System.StrUtils, UVScan.Alerts;

{ Colour boxes: "Default" (clNone), the preset colours by name, the standard
  colours and "Custom..." for anything else. }
procedure TDisplayEditorForm.ColorBoxGetColors(Sender: TCustomColorBox; Items: TStrings);
begin
  // clNone is one of the system colours, which are left out; add it by hand.
  Items.InsertObject(0, 'Default', TObject(clNone));
  Items.InsertObject(1, 'Alarm red', TObject(AlarmColor));
  Items.InsertObject(2, 'Warning amber', TObject(WarnColor));
  Items.InsertObject(3, 'Good green', TObject(GoodColor));
end;

procedure TDisplayEditorForm.PrepareColorBox(Box: TColorBox);
begin
  Box.OnGetColors := ColorBoxGetColors;
  Box.NoneColorColor := clWindow;
  Box.Style := [cbStandardColors, cbExtendedColors, cbCustomColor, cbCustomColors, cbPrettyNames];
end;

class function TDisplayEditorForm.Execute(Pid: TPidDef; Settings: TDisplaySettings): Boolean;
var
  F: TDisplayEditorForm;
  Existing: TPidDisplay;
begin
  F := TDisplayEditorForm.Create(Application);
  try
    F.FPid := Pid;
    Existing := Settings.Find(Pid.Id);
    if Existing <> nil then
      F.FDisplay.Assign(Existing);
    F.FDisplay.PidId := Pid.Id;
    F.LoadAll;
    Result := F.ShowModal = mrOk;
    if Result then
      Settings.Put(Pid.Id, F.FDisplay);
  finally
    F.Free;
  end;
end;

procedure TDisplayEditorForm.FormCreate(Sender: TObject);
var
  Op: TCompareOp;
  S: TAlertSound;
  N: Integer;
begin
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
  PrepareColorBox(cbxText);
  PrepareColorBox(cbxRow);
  PrepareColorBox(cbxLevelRow);
  PrepareColorBox(cbxLevelText);
  pbPreview.ControlStyle := pbPreview.ControlStyle + [csOpaque];
  gbPreview.DoubleBuffered := True;
end;

procedure TDisplayEditorForm.FormDestroy(Sender: TObject);
begin
  StopAlertSound;
  FDisplay.Free;
end;

procedure TDisplayEditorForm.LoadAll;
var
  I: Integer;
begin
  FLoading := True;
  try
    lblPid.Caption := FPid.LongName + IfThen(FPid.Units <> '', '  (' + FPid.Units + ')', '');
    cbFontSize.ItemIndex := 0;
    for I := 0 to High(FontSizes) do
      if FontSizes[I] = FDisplay.FontSize then
        cbFontSize.ItemIndex := I;
    if (FDisplay.FontSize > 0) and (cbFontSize.ItemIndex = 0) then
    begin
      cbFontSize.Items.Add(IntToStr(FDisplay.FontSize));
      cbFontSize.ItemIndex := cbFontSize.Items.Count - 1;
    end;
    cbxText.Selected := FDisplay.TextColor;
    cbxRow.Selected := FDisplay.RowColor;
  finally
    FLoading := False;
  end;
  FillLevels(0);
end;

procedure TDisplayEditorForm.NormalChange(Sender: TObject);
begin
  if FLoading then
    Exit;
  FDisplay.FontSize := StrToIntDef(cbFontSize.Text, 0);
  FDisplay.TextColor := cbxText.Selected;
  FDisplay.RowColor := cbxRow.Selected;
  pbPreview.Invalidate;
end;

{ Levels }

procedure TDisplayEditorForm.SetLevelItem(Item: TListItem; const L: TDisplayLevel);
var
  Sound: string;
begin
  Item.Caption := L.Name;
  Item.SubItems.Clear;
  Item.SubItems.Add(L.Describe);
  Item.SubItems.Add('Sample');
  Item.SubItems.Add(IfThen(L.Flash, 'flash', ''));
  if L.Sound = asFile then
    Sound := ExtractFileName(L.SoundFile)
  else if L.Sound = asNone then
    Sound := ''
  else
    Sound := AlertSoundCaptions[L.Sound];
  if (Sound <> '') and L.RepeatSound then
    Sound := Sound + ', repeat';
  Item.SubItems.Add(Sound);
end;

procedure TDisplayEditorForm.FillLevels(Select: Integer);
var
  L: TDisplayLevel;
begin
  lvLevels.Items.BeginUpdate;
  try
    lvLevels.Items.Clear;
    for L in FDisplay.Levels do
      SetLevelItem(lvLevels.Items.Add, L);
  finally
    lvLevels.Items.EndUpdate;
  end;
  if Length(FDisplay.Levels) > 0 then
    lvLevels.ItemIndex := EnsureRange(Select, 0, High(FDisplay.Levels))
  else
    lvLevels.ItemIndex := -1;
  ShowLevel;
end;

function TDisplayEditorForm.CurrentLevel: Integer;
begin
  Result := lvLevels.ItemIndex;
  if Result > High(FDisplay.Levels) then
    Result := -1;
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
    edtValue.Color := clWindow;
    cbxLevelRow.Selected := L.RowColor;
    cbxLevelText.Selected := L.TextColor;
    chkFlash.Checked := L.Flash;
    cbSound.ItemIndex := Ord(L.Sound);
    edtSoundFile.Text := L.SoundFile;
    chkRepeat.Checked := L.RepeatSound;
    for Ctl in TArray<TControl>.Create(lblLevelName, edtLevelName, lblWhen, cbOp, edtValue, lblLevelRow, cbxLevelRow, lblLevelText,
      cbxLevelText, chkFlash, lblSound, cbSound, btnTestSound, chkRepeat) do
      Ctl.Enabled := I >= 0;
  finally
    FLoading := False;
  end;
  UpdateButtons;
  pbPreview.Invalidate;
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

procedure TDisplayEditorForm.lvLevelsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected then
    ShowLevel;
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
    edtValue.Color := clWindow;
  end
  else
    edtValue.Color := $00C8C8FF; // keeps the last good value
  L.RowColor := cbxLevelRow.Selected;
  L.TextColor := cbxLevelText.Selected;
  L.Flash := chkFlash.Checked;
  L.Sound := TAlertSound(Max(0, cbSound.ItemIndex));
  L.SoundFile := Trim(edtSoundFile.Text);
  L.RepeatSound := chkRepeat.Checked;
  FDisplay.Levels[I] := L;
  SetLevelItem(lvLevels.Items[I], L);
  UpdateButtons;
  pbPreview.Invalidate;
end;

procedure TDisplayEditorForm.lvLevelsCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
  State: TCustomDrawState; var DefaultDraw: Boolean);
var
  L: TDisplayLevel;
begin
  Sender.Canvas.Brush.Color := clWindow;
  Sender.Canvas.Font.Color := clWindowText;
  if (SubItem = 2) and (Item.Index <= High(FDisplay.Levels)) then
  begin
    L := FDisplay.Levels[Item.Index];
    if L.RowColor <> clNone then
      Sender.Canvas.Brush.Color := L.RowColor;
    if L.TextColor <> clNone then
      Sender.Canvas.Font.Color := L.TextColor;
  end;
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
  P: TPoint;
begin
  P := btnPresets.ClientToScreen(Point(0, btnPresets.Height));
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
  Values: array of string;
  Warn, Alarm: Double;
  Op: TCompareOp;
  L: TDisplayLevel;
begin
  if (Length(FDisplay.Levels) > 0) and (MessageDlg('Replace the existing alert levels?', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes) then
    Exit;
  SetLength(Values, 2);
  if HighIsBad then
  begin
    if not InputQuery('Green / yellow / red', ['Yellow at or above', 'Red at or above'], Values) then
      Exit;
    Op := coGE;
  end
  else
  begin
    if not InputQuery('Green / yellow / red', ['Yellow at or below', 'Red at or below'], Values) then
      Exit;
    Op := coLE;
  end;
  if not TryParseNumber(Values[0], Warn) or not TryParseNumber(Values[1], Alarm) then
  begin
    MessageDlg('Both thresholds must be numbers.', mtWarning, [mbOK], 0);
    Exit;
  end;
  FDisplay.Levels := nil;
  L := NewLevel;
  L.Name := 'Alarm';
  L.Op := Op;
  L.Value := Alarm;
  L.RowColor := AlarmColor;
  L.TextColor := clWhite;
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
    cbxRow.Selected := GoodColor;
  finally
    FLoading := False;
  end;
  FillLevels(0);
  edtPreview.Text := Values[1];
end;

procedure TDisplayEditorForm.btnBrowseSoundClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Filter := 'Wave sounds (*.wav)|*.wav|All files (*.*)|*.*';
    Dlg.FileName := edtSoundFile.Text;
    Dlg.Options := Dlg.Options + [ofFileMustExist];
    if Dlg.Execute then
      edtSoundFile.Text := Dlg.FileName; // LevelChange stores it
  finally
    Dlg.Free;
  end;
end;

procedure TDisplayEditorForm.btnTestSoundClick(Sender: TObject);
begin
  if not PlayAlertSound(TAlertSound(Max(0, cbSound.ItemIndex)), Trim(edtSoundFile.Text)) then
    MessageDlg('The sound file could not be played.', mtWarning, [mbOK], 0);
end;

procedure TDisplayEditorForm.btnClearClick(Sender: TObject);
begin
  FDisplay.FontSize := 0;
  FDisplay.TextColor := clNone;
  FDisplay.RowColor := clNone;
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
  pbPreview.Invalidate;
end;

procedure TDisplayEditorForm.tmrFlashTimer(Sender: TObject);
begin
  FFlashOn := not FFlashOn;
  if ResolveDisplay(FDisplay, PreviewValue).Flash then
    pbPreview.Invalidate;
end;

procedure TDisplayEditorForm.pbPreviewPaint(Sender: TObject);
var
  C: TCanvas;
  R: TRect;
  S: TResolvedStyle;
  Row, Txt: TColor;
  V: Double;
  Status: string;
begin
  C := pbPreview.Canvas;
  V := PreviewValue;
  S := ResolveDisplay(FDisplay, V);
  S.Colors(FFlashOn, Row, Txt);
  if Row = clNone then
    Row := clWindow;
  if Txt = clNone then
    Txt := clWindowText;
  R := pbPreview.ClientRect;
  C.Brush.Color := Row;
  C.FillRect(R);
  C.Pen.Color := clBtnShadow;
  C.Brush.Style := bsClear;
  C.Rectangle(R);
  C.Brush.Style := bsSolid;
  InflateRect(R, -8, 0);
  C.Font.Name := 'Segoe UI';
  C.Font.Style := [];
  C.Font.Size := 10;
  C.Font.Color := Txt;
  C.Brush.Style := bsClear;
  if S.Level >= 0 then
    Status := FPid.LongName + '   [' + IfThen(S.LevelName <> '', S.LevelName, 'level ' + IntToStr(S.Level + 1)) + ']'
  else
    Status := FPid.LongName;
  DrawText(C.Handle, PChar(Status), -1, R, DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS);
  C.Font.Style := [fsBold];
  C.Font.Size := IfThen(S.FontSize > 0, S.FontSize, 14);
  DrawText(C.Handle, PChar(FPid.FormatValue(V) + ' ' + FPid.Units), -1, R, DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
  C.Brush.Style := bsSolid;
end;

end.
