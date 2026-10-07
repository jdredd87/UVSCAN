unit UVScan.ControlEditor;

{ Add / edit one real-time control: name, kind, module, the command bytes and,
  for value controls, the range and scaling. Shows the exact message that
  will be sent, and what is wrong while something is. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.UITypes, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  UVScan.Controls;

type
  TControlEditorForm = class(TForm)
    lblName: TLabel;
    edtName: TEdit;
    lblGroup: TLabel;
    cbGroup: TComboBox;
    rgKind: TRadioGroup;
    lblModule: TLabel;
    cbModule: TComboBox;
    lblOn: TLabel;
    edtOn: TEdit;
    lblOff: TLabel;
    edtOff: TEdit;
    lblHelp: TLabel;
    gbValue: TGroupBox;
    lblMin: TLabel;
    edtMin: TEdit;
    lblMax: TLabel;
    edtMax: TEdit;
    lblStep: TLabel;
    edtStep: TEdit;
    lblScale: TLabel;
    edtScale: TEdit;
    lblOffset: TLabel;
    edtOffset: TEdit;
    lblUnits: TLabel;
    edtUnits: TEdit;
    lblConfirm: TLabel;
    edtConfirm: TEdit;
    lblNotes: TLabel;
    memNotes: TMemo;
    lblSendsCaption: TLabel;
    lblSends: TLabel;
    lblProblem: TLabel;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Changed(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FControl: TControlDef;
    FList: TControlList;
    FOriginal: TControlDef;
    FLoading: Boolean;
    procedure LoadFrom(C: TControlDef);
    function ReadInto(C: TControlDef): string; // '' or the problem
  public
    { Edits C in place when OK is pressed. Original = the list entry being edited
      (nil for a new one), so its own name does not count as a duplicate. }
    class function Execute(C: TControlDef; Groups: TStrings; List: TControlList; Original: TControlDef): Boolean;
  end;

implementation

{$R *.dfm}

uses
  System.StrUtils, UVScan.Class2, UVScan.Hex, UVScan.Display;

const
  Modules: array[0..8] of Byte = ($10, $18, $20, $28, $40, $58, $60, $80, $C0);

class function TControlEditorForm.Execute(C: TControlDef; Groups: TStrings; List: TControlList;
  Original: TControlDef): Boolean;
var
  F: TControlEditorForm;
begin
  F := TControlEditorForm.Create(Application);
  try
    F.FControl := C;
    F.FList := List;
    F.FOriginal := Original;
    F.cbGroup.Items.Assign(Groups);
    if Original = nil then
      F.Caption := 'Add real-time control'
    else
      F.Caption := 'Edit real-time control';
    F.LoadFrom(C);
    Result := F.ShowModal = mrOk;
    if Result then
      F.ReadInto(C);
  finally
    F.Free;
  end;
end;

procedure TControlEditorForm.FormCreate(Sender: TObject);
var
  K: TControlKind;
  M: Byte;
begin
  for K := Low(TControlKind) to High(TControlKind) do
    rgKind.Items.Add(ControlKindCaptions[K]);
  for M in Modules do
    cbModule.Items.Add(Format('%.2x - %s', [M, ModuleName(M)]));
end;

procedure TControlEditorForm.LoadFrom(C: TControlDef);
var
  I: Integer;
begin
  FLoading := True;
  try
    edtName.Text := C.Name;
    cbGroup.Text := C.Group;
    rgKind.ItemIndex := Ord(C.Kind);
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
  C.Kind := TControlKind(Max(0, rgKind.ItemIndex));
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
begin
  if FLoading then
    Exit;
  gbValue.Enabled := rgKind.ItemIndex = Ord(ckValue);
  for var I := 0 to gbValue.ControlCount - 1 do
    gbValue.Controls[I].Enabled := gbValue.Enabled;
  lblOn.Caption := IfThen(rgKind.ItemIndex = Ord(ckAction), 'Command', 'On command');
  lblOff.Caption := IfThen(rgKind.ItemIndex = Ord(ckValue), 'Release', 'Off command');
  // An action is sent once and has nothing to undo.
  lblOff.Visible := rgKind.ItemIndex <> Ord(ckAction);
  edtOff.Visible := lblOff.Visible;
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
  lblSends.Caption := Sends;
  lblProblem.Caption := Problem;
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
    MessageDlg(Problem, mtWarning, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOk;
end;

end.
