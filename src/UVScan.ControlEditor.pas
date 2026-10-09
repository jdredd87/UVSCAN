unit UVScan.ControlEditor;

{ Add / edit one real-time control: name, kind, module, the command bytes and,
  for value controls, the range and scaling. Shows the exact message that
  will be sent, and what is wrong while something is. }

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Edit, FMX.ComboEdit,
  FMX.Memo, FMX.Memo.Types, FMX.Layouts, FMX.ScrollBox, FMX.Controls.Presentation,
  UVScan.Controls;

type
  TControlEditorForm = class(TForm)
    lytButtons: TLayout;
    btnCancel: TButton;
    btnOK: TButton;
    sbMain: TVertScrollBox;
    rowName: TLayout;
    pairName: TLayout;
    lblName: TLabel;
    edtName: TEdit;
    pairGroup: TLayout;
    lblGroup: TLabel;
    cbGroup: TComboEdit;
    gbKind: TGroupBox;
    rowModule: TLayout;
    lblModule: TLabel;
    cbModule: TComboEdit;
    rowOn: TLayout;
    lblOn: TLabel;
    edtOn: TEdit;
    rowOff: TLayout;
    lblOff: TLabel;
    edtOff: TEdit;
    lblHelp: TLabel;
    gbValue: TGroupBox;
    flowValue: TFlowLayout;
    pairMin: TLayout;
    lblMin: TLabel;
    edtMin: TEdit;
    pairMax: TLayout;
    lblMax: TLabel;
    edtMax: TEdit;
    pairStep: TLayout;
    lblStep: TLabel;
    edtStep: TEdit;
    pairUnits: TLayout;
    lblUnits: TLabel;
    edtUnits: TEdit;
    pairScale: TLayout;
    lblScale: TLabel;
    edtScale: TEdit;
    pairOffset: TLayout;
    lblOffset: TLabel;
    edtOffset: TEdit;
    rowConfirm: TLayout;
    lblConfirm: TLabel;
    edtConfirm: TEdit;
    rowNotes: TLayout;
    lblNotes: TLabel;
    memNotes: TMemo;
    rowSends: TLayout;
    lblSendsCaption: TLabel;
    lblSends: TLabel;
    lblProblem: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure Changed(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FControl: TControlDef;
    FList: TControlList;
    FOriginal: TControlDef;
    FLoading: Boolean;
    FKindButtons: TArray<TRadioButton>;
    procedure LoadFrom(C: TControlDef);
    function ReadInto(C: TControlDef): string; // '' or the problem
    function KindIndex: Integer;
  public
    { Edits C in place when OK is pressed. Original = the list entry being edited
      (nil for a new one), so its own name does not count as a duplicate.
      Groups is copied at once. OnDone (may be nil) runs when the dialog
      closes: True = OK and C updated. }
    class procedure Execute(C: TControlDef; Groups: TStrings; List: TControlList; Original: TControlDef;
      const OnDone: TProc<Boolean>);
  end;

implementation

{$R *.fmx}

uses
  System.StrUtils, UVScan.Class2, UVScan.Hex, UVScan.Display, UVScan.UI.Common, UVScan.UI.Theme;

const
  Modules: array[0..8] of Byte = ($10, $18, $20, $28, $40, $58, $60, $80, $C0);
  NarrowWidth = 560;
  {$IFDEF MSWINDOWS}
  MonoFont = 'Consolas';
  {$ELSE}
  MonoFont = 'monospace';
  {$ENDIF}

class procedure TControlEditorForm.Execute(C: TControlDef; Groups: TStrings; List: TControlList;
  Original: TControlDef; const OnDone: TProc<Boolean>);
var
  F: TControlEditorForm;
begin
  F := TControlEditorForm.Create(Application);
  F.FControl := C;
  F.FList := List;
  F.FOriginal := Original;
  F.cbGroup.Items.Assign(Groups);
  if Original = nil then
    F.Caption := 'Add real-time control'
  else
    F.Caption := 'Edit real-time control';
  F.LoadFrom(C);
  MakePage(F, F.Caption, F.btnOK);
  ShowDialog(F,
    procedure(R: TModalResult)
    begin
      if R = mrOk then
        F.ReadInto(C);
      if Assigned(OnDone) then
        OnDone(R = mrOk);
    end);
end;

procedure TControlEditorForm.FormCreate(Sender: TObject);
var
  K: TControlKind;
  M: Byte;
  B: TRadioButton;
  Lbl: TLabel;
begin
  FLoading := True;
  for K := Low(TControlKind) to High(TControlKind) do
  begin
    B := TRadioButton.Create(Self);
    B.Parent := gbKind;
    B.Position.X := Ord(K) * 150; // Align = Left keeps them in this order
    B.Align := TAlignLayout.Left;
    B.Width := 140;
    B.Text := ControlKindCaptions[K];
    B.GroupName := 'ControlKind' + IntToHex(NativeInt(Self), SizeOf(Pointer) * 2);
    B.OnChange := Changed;
    FKindButtons := FKindButtons + [B];
  end;
  for M in Modules do
    cbModule.Items.Add(Format('%.2x - %s', [M, ModuleName(M)]));
  for var E in TArray<TEdit>.Create(edtOn, edtOff) do
  begin
    E.StyledSettings := E.StyledSettings - [TStyledSetting.Family];
    E.TextSettings.Font.Family := MonoFont;
  end;
  lblSends.StyledSettings := lblSends.StyledSettings - [TStyledSetting.Family];
  lblSends.TextSettings.Font.Family := MonoFont;
  lblHelp.StyledSettings := lblHelp.StyledSettings - [TStyledSetting.FontColor];
  lblHelp.TextSettings.FontColor := Palette.Muted;
  lblProblem.StyledSettings := lblProblem.StyledSettings - [TStyledSetting.FontColor];
  lblProblem.TextSettings.FontColor := Palette.Bad;
  for Lbl in TArray<TLabel>.Create(lblNotes, lblSendsCaption) do
    Lbl.TextSettings.VertAlign := TTextAlign.Leading;
  FLoading := False;
end;

procedure TControlEditorForm.FormResize(Sender: TObject);
var
  Narrow: Boolean;
  W, PairW, H: Single;
  PerRow, Rows, I: Integer;
  L: TLabel;
  Pairs: TArray<TLayout>;
begin
  Narrow := InnerWidth(Self) < NarrowWidth;
  // Name and group: side by side on a wide window, one under the other on a phone.
  if Narrow then
  begin
    pairName.Align := TAlignLayout.Top;
    pairGroup.Margins.Left := 0;
  end
  else
  begin
    pairName.Align := TAlignLayout.Left;
    pairName.Width := Max(200, rowName.Width * 0.58);
    pairGroup.Margins.Left := 12;
  end;
  ArrangeCaptionRows([pairName, pairGroup, rowModule, rowOn, rowOff, rowConfirm],
    [lblName, lblGroup, lblModule, lblOn, lblOff, lblConfirm], Narrow);
  if Narrow then
    rowName.Height := pairName.Height * 2
  else
    rowName.Height := pairName.Height;
  ArrangeCaptionRows([rowNotes], [lblNotes], Narrow, 80);
  lblSends.WordWrap := True;
  H := Max(30, WrappedTextHeight(lblSends, Max(100, lblSends.Width)) + 6);
  ArrangeCaptionRows([rowSends], [lblSendsCaption], Narrow, H);
  for L in [lblHelp, lblProblem] do
  begin
    // under the fields on a wide window, full width on a phone
    if Narrow then
      L.Margins.Left := 12
    else
      L.Margins.Left := lblOn.Width + 8;
    L.WordWrap := True;
    L.Height := Max(20, WrappedTextHeight(L, Max(100, InnerWidth(Self) - L.Margins.Left - L.Margins.Right - 30)) + 4);
  end;
  // Value boxes: the captions as wide as the widest, the boxes wrap; the group
  // as tall as the rows they need.
  W := 0;
  for L in [lblMin, lblMax, lblStep, lblUnits, lblScale, lblOffset] do
  begin
    L.WordWrap := False;
    FitTextWidth(L);
    W := Max(W, L.Width);
  end;
  PairW := W + 8 + 100;
  Pairs := [pairMin, pairMax, pairStep, pairUnits, pairScale, pairOffset];
  for I := 0 to High(Pairs) do
  begin
    TLabel(Pairs[I].Controls[0]).Width := W + 8;
    Pairs[I].Width := PairW;
    Pairs[I].Height := 42;
  end;
  PerRow := Max(1, Trunc((gbValue.Width - gbValue.Padding.Left - gbValue.Padding.Right) / PairW));
  Rows := (Length(Pairs) + PerRow - 1) div PerRow;
  gbValue.Height := gbValue.Padding.Top + gbValue.Padding.Bottom + Rows * 42 + 4;
  // Type: one per line on a phone, all on one line on a wide window.
  for I := 0 to High(FKindButtons) do
    if Narrow then
    begin
      FKindButtons[I].Align := TAlignLayout.None;
      FKindButtons[I].SetBounds(gbKind.Padding.Left + 4, 28 + I * 36, gbKind.Width - 24, 34);
    end
    else
    begin
      FKindButtons[I].Position.X := I * 170;
      FKindButtons[I].Align := TAlignLayout.Left;
      FKindButtons[I].Margins.Right := 12;
      FitTextWidth(FKindButtons[I], 90);
    end;
  if Narrow then
    gbKind.Height := 28 + Length(FKindButtons) * 36 + 6
  else
    gbKind.Height := 28 + 34 + 8;
end;

function TControlEditorForm.KindIndex: Integer;
begin
  for Result := 0 to High(FKindButtons) do
    if FKindButtons[Result].IsChecked then
      Exit;
  Result := 0;
end;

procedure TControlEditorForm.LoadFrom(C: TControlDef);
var
  I: Integer;
begin
  FLoading := True;
  try
    edtName.Text := C.Name;
    cbGroup.Text := C.Group;
    for I := 0 to High(FKindButtons) do
      FKindButtons[I].IsChecked := I = Ord(C.Kind);
    cbModule.Text := Format('%.2x - %s', [C.Module, ModuleName(C.Module)]);
    for I := 0 to cbModule.Items.Count - 1 do
      if cbModule.Items[I].StartsWith(IntToHex(C.Module, 2)) then
        cbModule.ItemIndex := I;
    edtOn.Text := C.OnText;
    edtOff.Text := C.OffText;
    edtMin.Text := FormatFloat('0.###', C.MinValue);
    edtMax.Text := FormatFloat('0.###', C.MaxValue);
    edtStep.Text := FormatFloat('0.###', C.Step);
    edtScale.Text := FormatFloat('0.######', C.Scale);
    edtOffset.Text := FormatFloat('0.###', C.Offset);
    edtUnits.Text := C.Units;
    edtConfirm.Text := C.Confirm;
    memNotes.Text := C.Notes;
  finally
    FLoading := False;
  end;
  Changed(nil);
end;

function TControlEditorForm.ReadInto(C: TControlDef): string;
var
  V: Double;
  M: Integer;
  I: Integer;
begin
  Result := '';
  C.Name := Trim(edtName.Text);
  C.Group := Trim(cbGroup.Text);
  C.Kind := TControlKind(KindIndex);
  if not TryStrToInt('$' + Copy(Trim(cbModule.Text), 1, 2), M) or (M < 0) or (M > $FF) then
    Exit('Module: start with the hex address, e.g. "10" for the PCM');
  C.Module := M;
  C.OnText := Trim(edtOn.Text);
  if C.Kind = ckAction then
    C.OffText := ''
  else
    C.OffText := Trim(edtOff.Text);
  C.Units := Trim(edtUnits.Text);
  C.Confirm := Trim(edtConfirm.Text);
  C.Notes := Trim(memNotes.Text);
  if C.Kind = ckValue then
  begin
    if not TryParseNumber(edtMin.Text, V) then Exit('Min is not a number');
    C.MinValue := V;
    if not TryParseNumber(edtMax.Text, V) then Exit('Max is not a number');
    C.MaxValue := V;
    if not TryParseNumber(edtStep.Text, V) then Exit('Step is not a number');
    C.Step := V;
    if not TryParseNumber(edtScale.Text, V) then Exit('Scale is not a number');
    C.Scale := V;
    if not TryParseNumber(edtOffset.Text, V) then Exit('Offset is not a number');
    C.Offset := V;
  end;
  for I := 0 to FList.Count - 1 do
    if (FList[I] <> FOriginal) and SameText(FList[I].Name, C.Name) then
      Exit('Another control already has this name');
  Result := C.Problem;
end;

procedure TControlEditorForm.Changed(Sender: TObject);
var
  Work: TControlDef;
  Problem, Sends: string;
  Kind: Integer;
begin
  if FLoading or (FList = nil) then
    Exit;
  Kind := KindIndex;
  gbValue.Enabled := Kind = Ord(ckValue);
  lblOn.Text := IfThen(Kind = Ord(ckAction), 'Command', 'On command');
  lblOff.Text := IfThen(Kind = Ord(ckValue), 'Release', 'Off command');
  // An action is sent once and has nothing to undo.
  rowOff.Visible := Kind <> Ord(ckAction);
  Work := TControlDef.Create;
  try
    Problem := ReadInto(Work);
    Sends := '';
    if Problem = '' then
      try
        Sends := BytesToHex(Work.OnMessage(Work.MinValue));
        if Work.Kind = ckValue then
          Sends := 'at ' + FormatFloat('0.###', Work.MinValue) + ':  ' + Sends + sLineBreak + 'at ' +
            FormatFloat('0.###', Work.MaxValue) + ':  ' + BytesToHex(Work.OnMessage(Work.MaxValue));
        if Length(Work.OffMessage) > 0 then
          Sends := Sends + sLineBreak + 'off:  ' + BytesToHex(Work.OffMessage);
      except
        on E: Exception do
          Problem := E.Message;
      end;
  finally
    Work.Free;
  end;
  lblSends.Text := Sends;
  lblProblem.Text := Problem;
  FormResize(nil); // their wrapped height may have changed
  btnOK.Enabled := Problem = '';
end;

procedure TControlEditorForm.btnOKClick(Sender: TObject);
var
  Work: TControlDef;
  Problem: string;
begin
  Work := TControlDef.Create;
  try
    Problem := ReadInto(Work);
  finally
    Work.Free;
  end;
  if Problem <> '' then
  begin
    ShowWarning(Problem);
    Exit;
  end;
  ModalResult := mrOk;
end;

end.
