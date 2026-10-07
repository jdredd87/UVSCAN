unit UVScan.PidEditor;

{ Add / edit / delete PID definitions. Works on a copy of the catalog; Save
  validates with the same rules the loader uses and writes pids.json. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Math,
  System.UITypes, System.StrUtils, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  UVScan.Pids;

type
  TPidEditorForm = class(TForm)
    pnlList: TPanel;
    edtFilter: TEdit;
    lvList: TListView;
    pnlListButtons: TPanel;
    btnAdd: TButton;
    btnDuplicate: TButton;
    btnDelete: TButton;
    btnImport: TButton;
    btnDefaults: TButton;
    splMain: TSplitter;
    pnlDetail: TPanel;
    lblId: TLabel;
    edtId: TEdit;
    chkEnabled: TCheckBox;
    lblName: TLabel;
    edtName: TEdit;
    lblShortName: TLabel;
    edtShortName: TEdit;
    lblUnits: TLabel;
    edtUnits: TEdit;
    lblDescription: TLabel;
    edtDescription: TEdit;
    lblKind: TLabel;
    cbKind: TComboBox;
    lblCategory: TLabel;
    cbCategory: TComboBox;
    lblPid: TLabel;
    edtPid: TEdit;
    lblBytes: TLabel;
    cbBytes: TComboBox;
    lblChannel: TLabel;
    cbChannel: TComboBox;
    lblFormula: TLabel;
    edtFormula: TEdit;
    lblFormulaStatus: TLabel;
    lblFormat: TLabel;
    cbFormat: TComboBox;
    lblFormatHelp: TLabel;
    lblMci: TLabel;
    edtMci: TEdit;
    lblMciHelp: TLabel;
    gbTest: TGroupBox;
    lblTestInput: TLabel;
    edtTestInput: TEdit;
    lblTestResultCaption: TLabel;
    lblTestResult: TLabel;
    pnlProblems: TPanel;
    lbProblems: TListBox;
    pnlBottom: TPanel;
    lblProblems: TLabel;
    btnSave: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure edtFilterChange(Sender: TObject);
    procedure lvListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure btnAddClick(Sender: TObject);
    procedure btnDuplicateClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure FieldChanged(Sender: TObject);
    procedure edtTestInputChange(Sender: TObject);
    procedure lblProblemsClick(Sender: TObject);
    procedure lbProblemsClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnImportClick(Sender: TObject);
    procedure btnDefaultsClick(Sender: TObject);
  private
    FWork: TPidCatalog;
    FFileName: string;
    FCurrent: TPidDef;
    FLoading: Boolean;
    FModified: Boolean;
    FSaved: Boolean;
    FProblems: TArray<TPidProblem>;
    procedure AfterBulkChange;
    procedure AddChoice(Task: TTaskDialog; const Caption, Hint: string; Result: Integer);
    procedure FillList;
    function ItemFor(P: TPidDef): TListItem;
    procedure UpdateItem(Item: TListItem; P: TPidDef);
    procedure Select(P: TPidDef);
    procedure ShowCurrent;
    procedure ApplyFields;
    procedure UpdateKindControls;
    procedure UpdateFormulaStatus;
    procedure UpdateTest;
    procedure UpdateProblems;
    procedure SetDetailEnabled(Value: Boolean);
  public
    { Edits a copy of Catalog; on Save writes FileName. Returns True if saved. }
    class function Execute(Catalog: TPidCatalog; const FileName: string): Boolean;
  end;

implementation

{$R *.dfm}

uses
  UVScan.Formula, UVScan.LegacyImport, UVScan.Defaults;

const
  KindCaptions: array[TPidKind] of string = ('Vehicle PID', 'Calculated', 'Analog input');

class function TPidEditorForm.Execute(Catalog: TPidCatalog; const FileName: string): Boolean;
var
  F: TPidEditorForm;
begin
  F := TPidEditorForm.Create(Application);
  try
    F.FFileName := FileName;
    F.FWork.Assign(Catalog);
    F.FillList;
    if F.FWork.Count > 0 then
      F.Select(F.FWork[0])
    else
      F.ShowCurrent;
    F.UpdateProblems;
    F.FModified := False;
    F.ShowModal;
    Result := F.FSaved;
  finally
    F.Free;
  end;
end;

procedure TPidEditorForm.FormCreate(Sender: TObject);
var
  K: TPidKind;
  C: TPidCategory;
begin
  FWork := TPidCatalog.Create;
  cbKind.Items.Clear;
  for K := Low(TPidKind) to High(TPidKind) do
    cbKind.Items.Add(KindCaptions[K]);
  cbCategory.Items.Clear;
  for C := Low(TPidCategory) to High(TPidCategory) do
    cbCategory.Items.Add(CategoryNames[C]);
end;

procedure TPidEditorForm.FormDestroy(Sender: TObject);
begin
  FWork.Free;
end;

procedure TPidEditorForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if (ModalResult <> mrOk) and FModified then
    CanClose := MessageDlg('Discard your changes to the PID definitions?', mtConfirmation,
      [mbYes, mbNo], 0) = mrYes;
end;

{ List }

procedure TPidEditorForm.UpdateItem(Item: TListItem; P: TPidDef);
begin
  Item.Data := P;
  Item.Caption := IntToStr(P.Id);
  Item.SubItems.Clear;
  Item.SubItems.Add(P.LongName + IfThen(P.Enabled, '', '  (disabled)'));
  Item.SubItems.Add(KindKeys[P.Kind]);
  case P.Kind of
    pkVehicle:
      begin
        Item.SubItems.Add(P.PidCode);
        Item.SubItems.Add(IntToStr(P.DataLength));
      end;
    pkAnalog:
      begin
        Item.SubItems.Add('A/D ' + IntToStr(P.AnalogChannel));
        Item.SubItems.Add('');
      end;
  else
    Item.SubItems.Add('');
    Item.SubItems.Add('');
  end;
  Item.SubItems.Add(P.Units);
end;

procedure TPidEditorForm.FillList;
var
  I: Integer;
  P: TPidDef;
  Filter: string;
begin
  Filter := LowerCase(Trim(edtFilter.Text));
  lvList.Items.BeginUpdate;
  try
    lvList.Items.Clear;
    for I := 0 to FWork.Count - 1 do
    begin
      P := FWork[I];
      if (Filter <> '') and (Pos(Filter, LowerCase(Format('%d %s %s %s %s',
        [P.Id, P.LongName, P.ShortName, P.PidCode, P.Mci]))) = 0) then
        Continue;
      UpdateItem(lvList.Items.Add, P);
    end;
  finally
    lvList.Items.EndUpdate;
  end;
end;

function TPidEditorForm.ItemFor(P: TPidDef): TListItem;
var
  I: Integer;
begin
  for I := 0 to lvList.Items.Count - 1 do
    if lvList.Items[I].Data = P then
      Exit(lvList.Items[I]);
  Result := nil;
end;

procedure TPidEditorForm.Select(P: TPidDef);
var
  Item: TListItem;
begin
  FCurrent := P;
  Item := ItemFor(P);
  if Item <> nil then
  begin
    lvList.Selected := Item;
    Item.MakeVisible(False);
  end;
  ShowCurrent;
end;

procedure TPidEditorForm.lvListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected and (Item <> nil) and (Item.Data <> FCurrent) then
  begin
    FCurrent := TPidDef(Item.Data);
    ShowCurrent;
  end;
end;

procedure TPidEditorForm.edtFilterChange(Sender: TObject);
begin
  FillList;
  if (FCurrent <> nil) and (ItemFor(FCurrent) <> nil) then
    ItemFor(FCurrent).Selected := True;
end;

{ Detail }

procedure TPidEditorForm.SetDetailEnabled(Value: Boolean);
var
  I: Integer;
begin
  for I := 0 to pnlDetail.ControlCount - 1 do
    pnlDetail.Controls[I].Enabled := Value;
end;

procedure TPidEditorForm.ShowCurrent;
var
  P: TPidDef;
begin
  P := FCurrent;
  SetDetailEnabled(P <> nil);
  btnDuplicate.Enabled := P <> nil;
  btnDelete.Enabled := P <> nil;
  if P = nil then
    Exit;
  FLoading := True;
  try
    edtId.Text := IntToStr(P.Id);
    chkEnabled.Checked := P.Enabled;
    edtName.Text := P.LongName;
    edtShortName.Text := P.ShortName;
    edtUnits.Text := P.Units;
    edtDescription.Text := P.Description;
    cbKind.ItemIndex := Ord(P.Kind);
    cbCategory.ItemIndex := Ord(P.Category);
    edtPid.Text := IfThen(P.Kind = pkVehicle, P.PidCode, '');
    cbBytes.ItemIndex := cbBytes.Items.IndexOf(IntToStr(P.DataLength));
    cbChannel.ItemIndex := cbChannel.Items.IndexOf(IntToStr(P.AnalogChannel));
    edtFormula.Text := P.FormulaText;
    cbFormat.Text := P.ResultFormat;
    edtMci.Text := P.Mci;
    case P.Kind of
      pkVehicle: edtTestInput.Text := IfThen(P.DataLength = 2, '0C 80', '50');
      pkAnalog: edtTestInput.Text := '80';
    else
      edtTestInput.Text := '';
    end;
  finally
    FLoading := False;
  end;
  UpdateKindControls;
  UpdateFormulaStatus;
  UpdateTest;
end;

function ParseHexPid(const S: string; out Value: Integer): Boolean;
var
  T: string;
begin
  T := UpperCase(Trim(S));
  if T.StartsWith('0X') then
    Delete(T, 1, 2)
  else if T.StartsWith('$') then
    Delete(T, 1, 1);
  Result := (T <> '') and (Length(T) <= 4) and TryStrToInt('$' + T, Value);
end;

procedure TPidEditorForm.ApplyFields;
var
  P: TPidDef;
  N: Integer;
begin
  P := FCurrent;
  if (P = nil) or FLoading then
    Exit;
  P.Id := StrToIntDef(Trim(edtId.Text), -1);
  P.Enabled := chkEnabled.Checked;
  P.LongName := Trim(edtName.Text);
  P.ShortName := Trim(edtShortName.Text);
  P.Units := edtUnits.Text;
  P.Description := Trim(edtDescription.Text);
  P.Kind := TPidKind(Max(0, cbKind.ItemIndex));
  P.Category := TPidCategory(Max(0, cbCategory.ItemIndex));
  P.FormulaText := Trim(edtFormula.Text);
  P.ResultFormat := Trim(cbFormat.Text);
  P.Mci := UpperCase(StringReplace(Trim(edtMci.Text), '%', '', [rfReplaceAll]));
  case P.Kind of
    pkVehicle:
      begin
        if ParseHexPid(edtPid.Text, N) then
        begin
          P.PidNumber := N;
          P.PidCode := IntToHex(N, 4);
        end
        else
          P.PidCode := Trim(edtPid.Text); // reported by validation
        P.DataLength := StrToIntDef(cbBytes.Text, 0);
        P.AnalogChannel := 0;
      end;
    pkAnalog:
      begin
        P.AnalogChannel := StrToIntDef(cbChannel.Text, 0);
        P.PidCode := IntToHex($FFFF - P.AnalogChannel + 1, 4);
        P.DataLength := 0;
      end;
  else
    P.PidCode := 'FPID';
    P.DataLength := 0;
    P.AnalogChannel := 0;
  end;
  FModified := True;
  if ItemFor(P) <> nil then
    UpdateItem(ItemFor(P), P);
end;

procedure TPidEditorForm.FieldChanged(Sender: TObject);
begin
  if FLoading then
    Exit;
  ApplyFields;
  if Sender = cbKind then
  begin
    // Sensible defaults when the kind changes.
    if (FCurrent.Kind = pkVehicle) and (cbBytes.ItemIndex < 0) then
      cbBytes.ItemIndex := 0;
    if (FCurrent.Kind = pkAnalog) and (cbChannel.ItemIndex < 0) then
      cbChannel.ItemIndex := 0;
    if (FCurrent.Kind = pkCalculated) and (FCurrent.Category <> pcCalculated) then
      cbCategory.ItemIndex := Ord(pcCalculated);
    if (FCurrent.Kind = pkAnalog) and (FCurrent.Category <> pcAnalog) then
      cbCategory.ItemIndex := Ord(pcAnalog);
    ApplyFields;
    UpdateKindControls;
  end;
  UpdateFormulaStatus;
  UpdateTest;
  UpdateProblems;
end;

procedure TPidEditorForm.UpdateKindControls;
var
  K: TPidKind;
begin
  if FCurrent = nil then
    Exit;
  K := FCurrent.Kind;
  lblPid.Enabled := K = pkVehicle;
  edtPid.Enabled := K = pkVehicle;
  lblBytes.Enabled := K = pkVehicle;
  cbBytes.Enabled := K = pkVehicle;
  lblChannel.Enabled := K = pkAnalog;
  cbChannel.Enabled := K = pkAnalog;
  case K of
    pkVehicle: lblTestInput.Caption := 'Data bytes (hex)';
    pkAnalog: lblTestInput.Caption := 'A/D sample (hex)';
  else
    lblTestInput.Caption := 'Inputs (NAME=value ...)';
  end;
end;

procedure TPidEditorForm.UpdateFormulaStatus;
var
  Err, Missing: string;
  V: string;
  Ref: TPidDef;
begin
  if FCurrent = nil then
    Exit;
  Err := FCurrent.FormulaError;
  if Err <> '' then
  begin
    lblFormulaStatus.Font.Color := clRed;
    lblFormulaStatus.Caption := Err;
    Exit;
  end;
  if FCurrent.FormulaText = '' then
  begin
    lblFormulaStatus.Font.Color := clGrayText;
    if FCurrent.Kind = pkCalculated then
      lblFormulaStatus.Caption := 'No formula: shows the value of its MCI (e.g. RUNTIME, LOGTIME)'
    else
      lblFormulaStatus.Caption := 'No formula: the value will show as --';
    Exit;
  end;
  Missing := '';
  for V in FCurrent.Formula.Variables do
  begin
    if (V = BuiltinRuntime) or (V = BuiltinLogTime) then
      Continue;
    Ref := FWork.FindByMci(V);
    if (Ref = nil) or (Ref = FCurrent) then
      Missing := Missing + ' %' + V + '%';
  end;
  if Missing <> '' then
  begin
    lblFormulaStatus.Font.Color := $000080FF;
    lblFormulaStatus.Caption := 'Formula OK, but no PID has MCI:' + Missing;
  end
  else
  begin
    lblFormulaStatus.Font.Color := clGreen;
    if Length(FCurrent.Formula.Variables) > 0 then
      lblFormulaStatus.Caption := 'Formula OK - uses %' + string.Join('%, %', FCurrent.Formula.Variables) + '%'
    else
      lblFormulaStatus.Caption := 'Formula OK';
  end;
end;

procedure TPidEditorForm.UpdateTest;
var
  Inputs: array[0..3] of Double;
  Bytes: TArray<Byte>;
  Vars: TArray<string>;
  Values: TArray<Double>;
  Pairs: TArray<string>;
  Pair, Hex: string;
  I, J, P: Integer;
  V: Double;
begin
  lblTestResult.Font.Color := clWindowText;
  if (FCurrent = nil) or (FCurrent.FormulaError <> '') then
  begin
    lblTestResult.Caption := '-';
    Exit;
  end;
  try
    for I := 0 to 3 do
      Inputs[I] := 0;
    if FCurrent.Kind = pkCalculated then
    begin
      Vars := FCurrent.Formula.Variables;
      SetLength(Values, Length(Vars));
      for I := 0 to High(Values) do
        Values[I] := NaN;
      Pairs := Trim(edtTestInput.Text).Split([' ', ','], TStringSplitOptions.ExcludeEmpty);
      for Pair in Pairs do
      begin
        P := Pos('=', Pair);
        if P < 2 then
          raise EConvertError.Create('Use NAME=value pairs, e.g. RPM=3000 IPW=3');
        for J := 0 to High(Vars) do
          if SameText(Vars[J], Copy(Pair, 1, P - 1)) then
            Values[J] := StrToFloat(Copy(Pair, P + 1, MaxInt), TFormatSettings.Invariant);
      end;
      V := FCurrent.Formula.Evaluate([], Values);
    end
    else
    begin
      Hex := StringReplace(Trim(edtTestInput.Text), ' ', '', [rfReplaceAll]);
      if Odd(Length(Hex)) then
        raise EConvertError.Create('Enter whole hex bytes, e.g. 0C 80');
      SetLength(Bytes, Length(Hex) div 2);
      for I := 0 to High(Bytes) do
        Bytes[I] := StrToInt('$' + Copy(Hex, I * 2 + 1, 2));
      for I := 0 to Min(High(Bytes), 3) do
        Inputs[I] := Bytes[I];
      V := FCurrent.Formula.Evaluate(Inputs, []);
    end;
    lblTestResult.Caption := FCurrent.FormatValue(V) + IfThen(FCurrent.Units <> '', ' ' + FCurrent.Units, '');
  except
    on E: Exception do
    begin
      lblTestResult.Font.Color := clRed;
      lblTestResult.Caption := E.Message;
    end;
  end;
end;

procedure TPidEditorForm.edtTestInputChange(Sender: TObject);
begin
  if not FLoading then
    UpdateTest;
end;

procedure TPidEditorForm.UpdateProblems;
var
  Pr: TPidProblem;
  Top: Integer;
begin
  FProblems := FWork.Validate;
  Top := lbProblems.TopIndex;
  lbProblems.Items.BeginUpdate;
  try
    lbProblems.Items.Clear;
    for Pr in FProblems do
      lbProblems.Items.Add(Pr.Text);
  finally
    lbProblems.Items.EndUpdate;
  end;
  if Top < lbProblems.Items.Count then
    lbProblems.TopIndex := Top;
  pnlProblems.Visible := Length(FProblems) > 0;
  if Length(FProblems) = 0 then
  begin
    lblProblems.Font.Color := clGreen;
    lblProblems.Caption := Format('%d PIDs, no problems', [FWork.Count]);
  end
  else
  begin
    lblProblems.Font.Color := clRed;
    lblProblems.Caption := Format('%d PIDs, %d problem(s) to fix before saving - click one above to go to the PID',
      [FWork.Count, Length(FProblems)]);
  end;
end;

procedure TPidEditorForm.lblProblemsClick(Sender: TObject);
begin
  if pnlProblems.Visible and (lbProblems.Items.Count > 0) then
    lbProblems.SetFocus;
end;

procedure TPidEditorForm.lbProblemsClick(Sender: TObject);
var
  I: Integer;
  P: TPidDef;
begin
  I := lbProblems.ItemIndex;
  if (I < 0) or (I > High(FProblems)) or (FProblems[I].Index < 0) or (FProblems[I].Index >= FWork.Count) then
    Exit;
  P := FWork[FProblems[I].Index];
  if ItemFor(P) = nil then
  begin
    edtFilter.Text := ''; // the PID is filtered out of the list
    FillList;
  end;
  Select(P);
  if Pos('formula', FProblems[I].Text) > 0 then
    edtFormula.SetFocus
  else if Pos('MCI', FProblems[I].Text) > 0 then
    edtMci.SetFocus
  else
    edtName.SetFocus;
end;

{ Add / duplicate / delete }

procedure TPidEditorForm.btnAddClick(Sender: TObject);
var
  P: TPidDef;
begin
  P := TPidDef.Create;
  P.Id := FWork.NextFreeId;
  P.LongName := 'New PID';
  P.Kind := pkVehicle;
  P.Category := pcEngine;
  P.PidCode := '0000';
  P.DataLength := 1;
  P.FormulaText := 'N0';
  FWork.Add(P);
  FModified := True;
  edtFilter.Text := '';
  FillList;
  Select(P);
  UpdateProblems;
  edtName.SetFocus;
  edtName.SelectAll;
end;

procedure TPidEditorForm.btnDuplicateClick(Sender: TObject);
var
  P: TPidDef;
begin
  if FCurrent = nil then
    Exit;
  P := TPidDef.Create;
  P.Assign(FCurrent);
  P.Id := FWork.NextFreeId;
  P.LongName := FCurrent.LongName + ' (copy)';
  P.Mci := ''; // MCI names must be unique
  FWork.Add(P);
  FModified := True;
  FillList;
  Select(P);
  UpdateProblems;
  edtName.SetFocus;
end;

procedure TPidEditorForm.btnDeleteClick(Sender: TObject);
var
  Msg, Users: string;
  I, Idx: Integer;
  P: TPidDef;
  V: string;
begin
  if FCurrent = nil then
    Exit;
  Users := '';
  if FCurrent.Mci <> '' then
    for I := 0 to FWork.Count - 1 do
    begin
      P := FWork[I];
      if (P <> FCurrent) and (P.FormulaError = '') then
        for V in P.Formula.Variables do
          if SameText(V, FCurrent.Mci) then
            Users := Users + sLineBreak + '  ' + P.LongName;
    end;
  Msg := Format('Delete "%s"?', [FCurrent.LongName]);
  if Users <> '' then
    Msg := Msg + sLineBreak + sLineBreak + Format('These PIDs use %%%s%% and will show -- without it:', [FCurrent.Mci]) + Users;
  if MessageDlg(Msg, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  Idx := FWork.IndexOf(FCurrent);
  FWork.Delete(Idx);
  FCurrent := nil;
  FModified := True;
  FillList;
  if FWork.Count > 0 then
    Select(FWork[Min(Idx, FWork.Count - 1)])
  else
    ShowCurrent;
  UpdateProblems;
end;

{ Import / defaults }

procedure TPidEditorForm.AfterBulkChange;
begin
  FModified := True;
  FCurrent := nil;
  edtFilter.Text := '';
  FillList;
  if FWork.Count > 0 then
    Select(FWork[0])
  else
    ShowCurrent;
  UpdateProblems;
end;

procedure TPidEditorForm.AddChoice(Task: TTaskDialog; const Caption, Hint: string; Result: Integer);
var
  B: TTaskDialogButtonItem;
begin
  B := Task.Buttons.Add as TTaskDialogButtonItem;
  B.Caption := Caption;
  B.CommandLinkHint := Hint;
  B.ModalResult := Result;
end;

function Lines(const Items: TArray<string>; MaxLines: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Min(High(Items), MaxLines - 1) do
    Result := Result + Items[I] + sLineBreak;
  if Length(Items) > MaxLines then
    Result := Result + Format('... and %d more', [Length(Items) - MaxLines]);
end;

procedure TPidEditorForm.btnImportClick(Sender: TObject);
var
  Dlg: TOpenDialog;
  Imported: TPidCatalog;
  Task: TTaskDialog;
  NewCount, Disabled, I: Integer;
  Mode: TMergeMode;
  R: TMergeResult;
  Summary: string;
begin
  Dlg := TOpenDialog.Create(Self);
  Imported := TPidCatalog.Create;
  Task := TTaskDialog.Create(Self);
  try
    Dlg.Title := 'Import old UVSCAN PID file';
    Dlg.Filter := 'UVSCAN PID file (*.csv)|*.csv|All files (*.*)|*.*';
    Dlg.Options := Dlg.Options + [ofFileMustExist];
    if not Dlg.Execute then
      Exit;
    try
      ImportLegacyPidsCsv(Dlg.FileName, Imported);
    except
      on E: Exception do
      begin
        MessageDlg('Could not read ' + Dlg.FileName + ':' + sLineBreak + E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
    if Imported.Count = 0 then
    begin
      MessageDlg('No PIDs found in ' + Dlg.FileName + '.' + sLineBreak + sLineBreak +
        Lines(Imported.Warnings.ToStringArray, 15), mtWarning, [mbOK], 0);
      Exit;
    end;

    NewCount := 0;
    Disabled := 0;
    for I := 0 to Imported.Count - 1 do
    begin
      if FindMatchingPid(FWork, Imported[I]) = nil then
        Inc(NewCount);
      if not Imported[I].Enabled then
        Inc(Disabled);
    end;

    Task.Caption := 'Import PIDs';
    Task.MainIcon := tdiInformation;
    Task.Title := Format('%d PIDs read from %s', [Imported.Count, ExtractFileName(Dlg.FileName)]);
    Task.Text := Format('%d are new to your list; %d match a PID you already have (same PID and name or formula).',
      [NewCount, Imported.Count - NewCount]) + sLineBreak + 'Nothing is written until you press Save.';
    if Imported.Warnings.Count > 0 then
    begin
      Task.ExpandButtonCaption := Format('%d note(s) about this file', [Imported.Warnings.Count]);
      Task.ExpandedText := Lines(Imported.Warnings.ToStringArray, 25);
    end;
    Task.CommonButtons := [tcbCancel];
    Task.Flags := [tfUseCommandLinks, tfAllowDialogCancellation];
    AddChoice(Task, 'Add the new PIDs',
      'Keep every PID you have as it is; add the ones you do not have yet.', 101);
    AddChoice(Task, 'Add new PIDs and update matching ones',
      'Matching PIDs are replaced by the imported definition (they keep their ID).', 102);
    AddChoice(Task, 'Replace my list with this file',
      'Use only the imported PIDs.', 100);
    if not Task.Execute then
      Exit;
    case Task.ModalResult of
      100: Mode := mmReplace;
      101: Mode := mmAddNew;
      102: Mode := mmAddAndUpdate;
    else
      Exit;
    end;

    R := MergeCatalog(FWork, Imported, Mode);
    AfterBulkChange;

    if Mode = mmReplace then
      Summary := Format('Your list now has the %d imported PIDs.', [R.Added])
    else
    begin
      Summary := Format('Added %d PIDs', [R.Added]);
      if R.Updated > 0 then
        Summary := Summary + Format(', updated %d', [R.Updated]);
      if R.Skipped > 0 then
        Summary := Summary + Format(', left %d you already had unchanged', [R.Skipped]);
      Summary := Summary + '.';
      if R.Renumbered > 0 then
        Summary := Summary + sLineBreak + Format('%d imported PIDs got a new ID because theirs was already taken.',
          [R.Renumbered]);
      if Length(R.MciCleared) > 0 then
        Summary := Summary + sLineBreak + sLineBreak + Format('%d imported PIDs used an MCI name you already have, ' +
          'so their MCI was removed (formulas keep using your existing PID):', [Length(R.MciCleared)]) +
          sLineBreak + Lines(R.MciCleared, 10);
    end;
    if Disabled > 0 then
      Summary := Summary + sLineBreak + Format('%d were disabled in the old file (group not 1) and stay disabled.', [Disabled]);
    if Length(FProblems) > 0 then
      Summary := Summary + sLineBreak + sLineBreak +
        Format('%d problem(s) need fixing before you can save; they are listed at the bottom of the editor.',
        [Length(FProblems)]);
    MessageDlg(Summary, mtInformation, [mbOK], 0);
  finally
    Task.Free;
    Imported.Free;
    Dlg.Free;
  end;
end;

procedure TPidEditorForm.btnDefaultsClick(Sender: TObject);
begin
  if MessageDlg('Replace all PID definitions with the factory defaults?' + sLineBreak + sLineBreak +
    'Nothing is written until you press Save.', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  try
    FWork.LoadFromJsonText(DefaultPidsJson);
  except
    on E: Exception do
    begin
      MessageDlg('Could not load the built-in defaults: ' + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  AfterBulkChange;
end;

{ Save }

procedure TPidEditorForm.btnSaveClick(Sender: TObject);
begin
  UpdateProblems;
  if Length(FProblems) > 0 then
  begin
    MessageDlg(Format('There are %d problem(s) to fix first. They are listed at the bottom of this window; ' +
      'click one to go to that PID.', [Length(FProblems)]), mtWarning, [mbOK], 0);
    lbProblems.SetFocus;
    Exit;
  end;
  try
    FWork.SaveToJsonFile(FFileName);
  except
    on E: Exception do
    begin
      MessageDlg('Could not save ' + FFileName + ':' + sLineBreak + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  FSaved := True;
  ModalResult := mrOk;
end;

end.
