unit UVScan.PidEditor;

{ Add / edit / delete PID definitions. Works on a copy of the catalog; Save
  validates with the same rules the loader uses and writes pids.json. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.UITypes, System.StrUtils, System.Types,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Edit, FMX.ListBox,
  FMX.Layouts, FMX.Controls.Presentation, FMX.ComboEdit, FMX.Objects,
  UVScan.Pids, UVScan.UI.DataGrid;

type
  TSavedBounds = record
    Ctl: TControl;
    R: TRectF;
    Anchors: TAnchors;
  end;

  TPidEditorForm = class(TForm)
    pnlList: TLayout;
    edtFilter: TEdit;
    pnlGrid: TLayout;
    pnlListButtons: TLayout;
    btnAdd: TButton;
    btnDuplicate: TButton;
    btnDelete: TButton;
    btnImport: TButton;
    btnDefaults: TButton;
    splMain: TSplitter;
    sbDetail: TVertScrollBox;
    pnlDetail: TLayout;
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
    cbFormat: TComboEdit;
    lblFormatHelp: TLabel;
    lblMci: TLabel;
    edtMci: TEdit;
    lblMciHelp: TLabel;
    gbTest: TGroupBox;
    lblTestInput: TLabel;
    edtTestInput: TEdit;
    lblTestResultCaption: TLabel;
    lblTestResult: TLabel;
    pnlProblems: TLayout;
    lbProblems: TListBox;
    pnlBottom: TLayout;
    lblProblems: TLabel;
    btnSave: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormResize(Sender: TObject);
    procedure edtFilterChange(Sender: TObject);
    procedure btnAddClick(Sender: TObject);
    procedure btnDuplicateClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure FieldChanged(Sender: TObject);
    procedure edtTestInputChange(Sender: TObject);
    procedure lblProblemsClick(Sender: TObject);
    procedure lbProblemsItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure btnSaveClick(Sender: TObject);
    procedure btnImportClick(Sender: TObject);
    procedure btnDefaultsClick(Sender: TObject);
  private
    lvList: TDataGrid;
    FRows: TArray<TPidDef>;    // the PIDs the list shows (filtered)
    FWork: TPidCatalog;
    FFileName: string;
    FCurrent: TPidDef;
    FLoading: Boolean;
    FModified: Boolean;
    FSaved: Boolean;
    FDiscardOk: Boolean;
    FNarrow: Boolean;
    FProblems: TArray<TPidProblem>;
    FDetailMode: Boolean;            // narrow window: the details page is showing
    FDetailBar: TRectangle;          // "< All PIDs" above the details
    FOrig: TArray<TSavedBounds>;     // the wide layout, to go back to
    procedure SaveBounds(const Ctls: array of TControl);
    procedure RestoreBounds;
    procedure StackDetail;
    procedure LayoutWideDetail;
    procedure SetDetailMode(Value: Boolean);
    procedure DetailBackClick(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure ListGetText(Sender: TObject; Col, Row: Integer; var Text: string);
    procedure ListSelect(Sender: TObject);
    procedure AfterBulkChange;
    procedure FillList;
    function RowOf(P: TPidDef): Integer;
    procedure Select(P: TPidDef);
    procedure ShowCurrent;
    procedure ApplyFields;
    procedure UpdateKindControls;
    procedure UpdateFormulaStatus;
    procedure UpdateTest;
    procedure UpdateProblems;
    procedure SetDetailEnabled(Value: Boolean);
    procedure ImportFile(const FileName: string);
    procedure CloseDiscarding;
  public
    { Edits a copy of Catalog; on Save writes FileName. OnDone (always called
      when the window closes) gets True if saved. }
    class procedure Execute(Catalog: TPidCatalog; const FileName: string; const Filter: string;
      const OnDone: TProc<Boolean>);
  end;

implementation

{$R *.fmx}

uses
  FMX.Dialogs, FMX.Memo, FMX.Memo.Types,
  UVScan.Formula, UVScan.LegacyImport, UVScan.Defaults, UVScan.UI.Common, UVScan.UI.Theme;

const
  KindCaptions: array[TPidKind] of string = ('Vehicle PID', 'Calculated', 'Analog input');
  ColorError = $FFE00000;
  ColorGrey = $FF808080;
  ColorWarn = $FFE07000;
  ColorGood = $FF008000;
  NarrowWidth = 760;

procedure SetLabelColor(L: TLabel; C: TAlphaColor);
begin
  L.StyledSettings := L.StyledSettings - [TStyledSetting.FontColor];
  L.TextSettings.FontColor := C;
end;

function ComboText(C: TComboBox): string;
begin
  if C.ItemIndex >= 0 then
    Result := C.Items[C.ItemIndex]
  else
    Result := '';
end;

{ A question with a few big answer buttons (what a Windows task dialog with
  command links did). OnChoice gets the chosen Result, or -1 for Cancel. }
type
  TChoice = record
    Caption, Hint: string;
    Result: Integer;
  end;

  { Remembers which answer button was pressed. }
  TChoiceClicker = class(TComponent)
  public
    Picked: Integer;
    procedure Click(Sender: TObject);
  end;

procedure TChoiceClicker.Click(Sender: TObject);
begin
  Picked := TButton(Sender).Tag;
  (Owner as TCommonCustomForm).ModalResult := mrOk;
end;

function Choice(const Caption, Hint: string; Value: Integer): TChoice;
begin
  Result.Caption := Caption;
  Result.Hint := Hint;
  Result.Result := Value;
end;

procedure ChooseOption(const Caption, Title, Text, Notes, NotesCaption: string; const Choices: array of TChoice;
  const OnChoice: TProc<Integer>);
var
  F: TForm;
  Box: TVertScrollBox;
  L: TLabel;
  B: TButton;
  M: TMemo;
  Bar: TLayout;
  C: TChoice;
  Y: Single;
  Clicker: TChoiceClicker;
begin
  F := TForm.CreateNew(nil);
  Clicker := TChoiceClicker.Create(F);
  Clicker.Picked := -1;
  F.Caption := Caption;
  F.Position := TFormPosition.MainFormCenter;
  F.BorderIcons := [TBorderIcon.biSystemMenu];
  F.ClientWidth := 520;
  F.ClientHeight := 300;
  Bar := TLayout.Create(F);
  Bar.Parent := F;
  Bar.Align := TAlignLayout.Bottom;
  Bar.Height := 48;
  B := TButton.Create(F);
  B.Parent := Bar;
  B.Align := TAlignLayout.Right;
  B.Margins.Rect := TRectF.Create(0, 10, 12, 10);
  B.Width := 95;
  B.Text := 'Cancel';
  B.Cancel := True;
  B.ModalResult := mrCancel;
  Box := TVertScrollBox.Create(F);
  Box.Parent := F;
  Box.Align := TAlignLayout.Client;
  Box.Padding.Rect := TRectF.Create(16, 12, 16, 4);
  Y := 0;

  L := TLabel.Create(F);
  L.Parent := Box;
  L.Align := TAlignLayout.Top;
  L.Height := 28;
  L.StyledSettings := L.StyledSettings - [TStyledSetting.Size, TStyledSetting.Style, TStyledSetting.FontColor];
  L.TextSettings.Font.Size := 16;
  L.TextSettings.Font.Style := [TFontStyle.fsBold];
  L.TextSettings.FontColor := $FF1F3F66;
  L.Text := Title;
  L.Position.Y := Y;
  Y := Y + 30;

  L := TLabel.Create(F);
  L.Parent := Box;
  L.Align := TAlignLayout.Top;
  L.Height := 44;
  L.TextSettings.WordWrap := True;
  L.Text := Text;
  L.Position.Y := Y;
  Y := Y + 46;

  for C in Choices do
  begin
    B := TButton.Create(F);
    B.Parent := Box;
    B.Align := TAlignLayout.Top;
    B.Margins.Rect := TRectF.Create(0, 6, 0, 0);
    B.Height := 48;
    B.TextSettings.WordWrap := True;
    B.TextSettings.HorzAlign := TTextAlign.Leading;
    B.Text := C.Caption + sLineBreak + C.Hint;
    B.Tag := C.Result;
    B.OnClick := Clicker.Click;
    B.Position.Y := Y;
    Y := Y + 56;
  end;

  if Notes <> '' then
  begin
    L := TLabel.Create(F);
    L.Parent := Box;
    L.Align := TAlignLayout.Top;
    L.Margins.Rect := TRectF.Create(0, 10, 0, 0);
    L.Height := 20;
    L.Text := NotesCaption;
    L.Position.Y := Y;
    Y := Y + 32;
    M := TMemo.Create(F);
    M.Parent := Box;
    M.Align := TAlignLayout.Top;
    M.Height := 110;
    M.ReadOnly := True;
    M.Text := Notes;
    M.Position.Y := Y;
    Y := Y + 112;
  end;
  F.ClientHeight := Round(Min(Y + 80, 620));

  ShowDialog(F,
    procedure(R: TModalResult)
    var
      Picked: Integer;
    begin
      Picked := Clicker.Picked;
      if R <> mrOk then
        Picked := -1;
      if Assigned(OnChoice) then
        OnChoice(Picked);
    end);
end;

class procedure TPidEditorForm.Execute(Catalog: TPidCatalog; const FileName: string; const Filter: string;
  const OnDone: TProc<Boolean>);
var
  F: TPidEditorForm;
begin
  F := TPidEditorForm.Create(Application);
  F.FFileName := FileName;
  F.FWork.Assign(Catalog);
  F.edtFilter.Text := Filter;
  F.FillList;
  if Length(F.FRows) > 0 then
    F.Select(F.FRows[0])
  else if F.FWork.Count > 0 then
    F.Select(F.FWork[0])
  else
    F.ShowCurrent;
  F.UpdateProblems;
  F.FModified := False;
  MakePage(F, 'PID definitions', F.btnSave);
  ShowDialog(F,
    procedure(R: TModalResult)
    begin
      if Assigned(OnDone) then
        OnDone(F.FSaved);
    end);
end;

procedure TPidEditorForm.FormCreate(Sender: TObject);
var
  K: TPidKind;
  C: TPidCategory;
begin
  FWork := TPidCatalog.Create;
  lvList := TDataGrid.Create(Self);
  lvList.Parent := pnlGrid;
  lvList.Align := TAlignLayout.Client;
  lvList.AddColumn('ID', 45);
  lvList.AddColumn('Name', 180, gaLeft, True);
  lvList.AddColumn('Kind', 75);
  lvList.AddColumn('PID', 55);
  lvList.AddColumn('Bytes', 50, gaRight);
  lvList.AddColumn('Units', 50);
  lvList.OnGetText := ListGetText;
  lvList.OnSelect := ListSelect;
  cbKind.Items.Clear;
  for K := Low(TPidKind) to High(TPidKind) do
    cbKind.Items.Add(KindCaptions[K]);
  cbCategory.Items.Clear;
  for C := Low(TPidCategory) to High(TPidCategory) do
    cbCategory.Items.Add(CategoryNames[C]);
  btnImport.Visible := not IsMobile; // no file picker for an old PC file on a phone
  lblTestResult.TextSettings.Font.Style := [TFontStyle.fsBold];
  OnKeyUp := FormKeyUp;
  // The wide layout (absolute positions), kept for when the window is wide again.
  SaveBounds([lblId, edtId, chkEnabled, lblName, edtName, lblShortName, edtShortName, lblUnits, edtUnits,
    lblDescription, edtDescription, lblKind, cbKind, lblCategory, cbCategory, lblPid, edtPid, lblBytes, cbBytes,
    lblChannel, cbChannel, lblFormula, edtFormula, lblFormulaStatus, lblFormat, cbFormat, lblFormatHelp, lblMci,
    edtMci, lblMciHelp, gbTest, lblTestInput, edtTestInput, lblTestResultCaption, lblTestResult, btnAdd,
    btnDuplicate, btnDelete, btnImport, btnDefaults, pnlDetail, pnlListButtons]);
  // Narrow window: "< All PIDs" above the details page.
  FDetailBar := TRectangle.Create(Self);
  FDetailBar.Parent := Self;
  FDetailBar.Stored := False;
  FDetailBar.Align := TAlignLayout.Top;
  FDetailBar.Height := 46;
  FDetailBar.Sides := [TSide.Bottom];
  FDetailBar.Fill.Color := Palette.Bar;
  FDetailBar.Stroke.Color := Palette.BarLine;
  FDetailBar.HitTest := True;
  FDetailBar.Cursor := crHandPoint;
  FDetailBar.OnClick := DetailBackClick;
  FDetailBar.Visible := False;
  with TLabel.Create(FDetailBar) do
  begin
    Parent := FDetailBar;
    Align := TAlignLayout.Client;
    Margins.Left := 46;
    HitTest := False;
    Text := 'All PIDs';
  end;
  AddLineIcon(FDetailBar, IconBack, 20).Align := TAlignLayout.Left;
  TControl(FDetailBar.Controls[FDetailBar.ControlsCount - 1]).Margins.Rect := TRectF.Create(14, 13, 0, 13);
  FormResize(nil);
end;

procedure TPidEditorForm.SaveBounds(const Ctls: array of TControl);
var
  C: TControl;
  S: TSavedBounds;
begin
  for C in Ctls do
  begin
    S.Ctl := C;
    S.R := TRectF.Create(C.Position.X, C.Position.Y, C.Position.X + C.Width, C.Position.Y + C.Height);
    S.Anchors := C.Anchors;
    FOrig := FOrig + [S];
  end;
end;

procedure TPidEditorForm.RestoreBounds;
var
  S: TSavedBounds;
begin
  for S in FOrig do
  begin
    if (S.Ctl = edtPid) or (S.Ctl = cbBytes) or (S.Ctl = cbChannel) or (S.Ctl = lblPid) or (S.Ctl = lblBytes) or
      (S.Ctl = lblChannel) then
      S.Ctl.Visible := True;
    S.Ctl.Anchors := S.Anchors;
    S.Ctl.SetBounds(S.R.Left, S.R.Top, S.R.Width, S.R.Height);
  end;
end;

{ Wide window: caption left of each field, all captions as wide as the
  widest; two short fields share a line. Sizes follow the active style's text
  (Win10Modern's fields are taller than the design's). }
procedure TPidEditorForm.LayoutWideDetail;
var
  H, X, R, Y, Half, CapW: Single;
  L: TLabel;

  procedure Cap(Lbl: TLabel; AX: Single);
  begin
    Lbl.SetBounds(AX, Y, Lbl.Width, H);
  end;

  procedure Field(C: TControl; AX, AW: Single);
  begin
    C.Anchors := [TAnchorKind.akLeft, TAnchorKind.akTop]; // placed again on every resize
    C.SetBounds(AX, Y, Max(40, AW), H);
  end;

  // a help text right of a field, wrapping in what is left of the line
  function Help(Lbl: TLabel; AX: Single): Single;
  begin
    Lbl.Anchors := [TAnchorKind.akLeft, TAnchorKind.akTop];
    Lbl.WordWrap := True;
    Lbl.TextSettings.VertAlign := TTextAlign.Center;
    Result := Max(H, WrappedTextHeight(Lbl, R - AX) + 4);
    Lbl.SetBounds(AX, Y, R - AX, Result);
  end;

begin
  H := 30;
  if IsMobile then
    H := 40;
  CapW := 0;
  for L in [lblId, lblName, lblShortName, lblDescription, lblKind, lblPid, lblFormula, lblFormat, lblMci, lblUnits,
    lblCategory, lblBytes, lblChannel] do
  begin
    L.WordWrap := False;
    L.TextSettings.VertAlign := TTextAlign.Center;
    L.Anchors := [TAnchorKind.akLeft, TAnchorKind.akTop];
    FitTextWidth(L);
  end;
  for L in [lblId, lblName, lblShortName, lblDescription, lblKind, lblPid, lblFormula, lblFormat, lblMci] do
    CapW := Max(CapW, L.Width);
  X := 16 + CapW + 10;
  R := sbDetail.Width - 24;
  if R < X + 260 then
    R := X + 260;
  Half := (R - X - 10) / 2;
  Y := 10;
  Cap(lblId, 16);
  Field(edtId, X, 90);
  chkEnabled.TextSettings.WordWrap := False;
  FitTextWidth(chkEnabled);
  Field(chkEnabled, X + 100, Min(chkEnabled.Width, R - X - 100));
  Y := Y + H + 6;
  Cap(lblName, 16);
  Field(edtName, X, R - X);
  Y := Y + H + 6;
  Cap(lblShortName, 16);
  Field(edtShortName, X, Half);
  Cap(lblUnits, X + Half + 10);
  Field(edtUnits, lblUnits.Position.X + lblUnits.Width + 6, R - (lblUnits.Position.X + lblUnits.Width + 6));
  Y := Y + H + 6;
  Cap(lblDescription, 16);
  Field(edtDescription, X, R - X);
  Y := Y + H + 6;
  Cap(lblKind, 16);
  Field(cbKind, X, Half);
  Cap(lblCategory, X + Half + 10);
  Field(cbCategory, lblCategory.Position.X + lblCategory.Width + 6, R - (lblCategory.Position.X + lblCategory.Width + 6));
  Y := Y + H + 6;
  Cap(lblPid, 16);
  Field(edtPid, X, 90);
  Cap(lblBytes, X + 100);
  Field(cbBytes, lblBytes.Position.X + lblBytes.Width + 6, 70);
  Cap(lblChannel, cbBytes.Position.X + 80);
  Field(cbChannel, lblChannel.Position.X + lblChannel.Width + 6, 80);
  Y := Y + H + 6;
  Cap(lblFormula, 16);
  Field(edtFormula, X, R - X);
  Y := Y + H + 2;
  lblFormulaStatus.Anchors := [TAnchorKind.akLeft, TAnchorKind.akTop];
  lblFormulaStatus.WordWrap := True;
  lblFormulaStatus.SetBounds(X, Y, R - X, Max(22, WrappedTextHeight(lblFormulaStatus, R - X) + 2));
  Y := Y + lblFormulaStatus.Height + 8;
  Cap(lblFormat, 16);
  Field(cbFormat, X, 120);
  Y := Y + Max(H, Help(lblFormatHelp, X + 130)) + 6;
  Cap(lblMci, 16);
  Field(edtMci, X, 160);
  Y := Y + Max(H, Help(lblMciHelp, X + 170)) + 10;
  gbTest.Anchors := [TAnchorKind.akLeft, TAnchorKind.akTop];
  gbTest.SetBounds(16, Y, R - 16, gbTest.Height);
  pnlDetail.Height := Y + gbTest.Height + 16;
end;

{ Narrow window: every caption above its field, one under the other. }
procedure TPidEditorForm.StackDetail;
type
  TPair = record
    Cap, Ctl: TControl;
  end;

  function Pair(Cap, Ctl: TControl): TPair;
  begin
    Result.Cap := Cap;
    Result.Ctl := Ctl;
  end;

var
  Pairs: TArray<TPair>;
  P: TPair;
  Y, W, H, TY: Single;
begin
  W := sbDetail.Width - 40;
  if W < 100 then
    W := InnerWidth(Self) - 40;
  Pairs := [Pair(lblId, edtId), Pair(nil, chkEnabled), Pair(lblName, edtName), Pair(lblShortName, edtShortName),
    Pair(lblUnits, edtUnits), Pair(lblDescription, edtDescription), Pair(lblKind, cbKind),
    Pair(lblCategory, cbCategory), Pair(lblPid, edtPid), Pair(lblBytes, cbBytes), Pair(lblChannel, cbChannel),
    Pair(lblFormula, edtFormula), Pair(nil, lblFormulaStatus), Pair(lblFormat, cbFormat), Pair(nil, lblFormatHelp),
    Pair(lblMci, edtMci), Pair(nil, lblMciHelp), Pair(nil, gbTest)];
  Y := 10;
  for P in Pairs do
  begin
    // Fields that do not apply to this kind of PID are left out on a phone.
    if (P.Ctl = edtPid) or (P.Ctl = cbBytes) or (P.Ctl = cbChannel) then
    begin
      P.Ctl.Visible := P.Ctl.Enabled;
      P.Cap.Visible := P.Ctl.Enabled;
    end;
    if not P.Ctl.Visible then
      Continue;
    // Positions here are final: right anchors would shrink fields later.
    P.Ctl.Anchors := [TAnchorKind.akLeft, TAnchorKind.akTop];
    if P.Cap <> nil then
    begin
      P.Cap.Anchors := [TAnchorKind.akLeft, TAnchorKind.akTop];
      TLabel(P.Cap).WordWrap := False;
      P.Cap.SetBounds(16, Y, W, 24);
      Y := Y + 26;
    end;
    if P.Ctl is TLabel then
    begin
      TLabel(P.Ctl).WordWrap := True;
      H := Max(20, WrappedTextHeight(TLabel(P.Ctl), W) + 4);
    end
    else if P.Ctl = chkEnabled then
    begin
      chkEnabled.TextSettings.WordWrap := True;
      H := Max(36, WrappedTextHeight(chkEnabled, W - 40) + 10);
    end
    else if P.Ctl = gbTest then
    begin
      // the test box: caption over field inside it too
      TY := 30;
      lblTestInput.SetBounds(12, TY, W - 24, 24);
      edtTestInput.SetBounds(12, TY + 26, W - 24, 36);
      lblTestResultCaption.SetBounds(12, TY + 70, W - 24, 24);
      lblTestResult.WordWrap := True;
      lblTestResult.SetBounds(12, TY + 96, W - 24, Max(26, WrappedTextHeight(lblTestResult, W - 24) + 4));
      H := lblTestResult.Position.Y + lblTestResult.Height + 12;
    end
    else
      H := 40;
    P.Ctl.SetBounds(16, Y, W, H);
    Y := Y + H + 10;
  end;
  pnlDetail.Height := Y + 10;
end;

procedure TPidEditorForm.SetDetailMode(Value: Boolean);
begin
  FDetailMode := Value;
  FormResize(nil);
  if Value then
    sbDetail.ViewportPosition := TPointF.Zero;
end;

procedure TPidEditorForm.DetailBackClick(Sender: TObject);
begin
  SetDetailMode(False);
  lvList.OnSelect := nil;
  try
    lvList.ItemIndex := -1; // so a tap on the same PID opens it again
  finally
    lvList.OnSelect := ListSelect;
  end;
  lvList.Refresh;
end;

procedure TPidEditorForm.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if (Key = vkHardwareBack) and FNarrow and FDetailMode then
  begin
    Key := 0; // back from the details to the list, not out of the editor
    DetailBackClick(nil);
  end;
end;

procedure TPidEditorForm.FormDestroy(Sender: TObject);
begin
  FWork.Free;
end;

procedure TPidEditorForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if (ModalResult = mrOk) or not FModified or FDiscardOk then
    Exit;
  CanClose := False;
  Confirm('Discard your changes to the PID definitions?',
    procedure
    begin
      FDiscardOk := True;
      // Close again once this question is out of the way.
      TThread.ForceQueue(nil, CloseDiscarding);
    end);
end;

procedure TPidEditorForm.CloseDiscarding;
begin
  ModalResult := mrCancel;
end;

{ Side by side on a wide window. On a narrow one (phone) two pages: the list,
  and the details of the PID tapped in it. }
procedure TPidEditorForm.FormResize(Sender: TObject);
var
  Narrow: Boolean;
begin
  if (pnlList = nil) or (FDetailBar = nil) then
    Exit;
  Narrow := InnerWidth(Self) < NarrowWidth;
  if not Narrow then
    FDetailMode := False;
  FNarrow := Narrow;
  if Narrow then
  begin
    splMain.Visible := False;
    pnlList.Visible := not FDetailMode;
    pnlList.Align := TAlignLayout.Client;
    sbDetail.Visible := FDetailMode;
    FDetailBar.Visible := FDetailMode;
    FDetailBar.Position.Y := 10000; // below the page's top bar
    lvList.SetColumnVisible(0, False); // ID
    lvList.SetColumnVisible(2, False); // kind
    lvList.SetColumnVisible(4, False); // bytes
    lvList.SetColumnWrap(1, True);
    lvList.SetColumnWrap(5, True);
    lvList.AutoHeights := True;
    lvList.AutoRowHeights;
    FlowControls(pnlListButtons, [btnAdd, btnDuplicate, btnDelete, btnImport, btnDefaults]);
    StackDetail;
  end
  else
  begin
    FDetailBar.Visible := False;
    pnlList.Visible := True;
    sbDetail.Visible := True;
    RestoreBounds;
    LayoutWideDetail;
    pnlList.Align := TAlignLayout.Left;
    pnlList.Width := 480;
    splMain.Visible := True;
    splMain.Align := TAlignLayout.Left;
    splMain.Width := 5;
    splMain.Position.X := pnlList.Position.X + pnlList.Width + 1;
    lvList.SetColumnVisible(0, True);
    lvList.SetColumnVisible(2, True);
    lvList.SetColumnVisible(4, True);
    lvList.SetColumnWrap(1, False);
    lvList.SetColumnWrap(5, False);
    lvList.AutoHeights := False;
    lvList.ResetRowHeights;
  end;
end;

{ List }

procedure TPidEditorForm.ListGetText(Sender: TObject; Col, Row: Integer; var Text: string);
var
  P: TPidDef;
begin
  if (Row < 0) or (Row > High(FRows)) then
    Exit;
  P := FRows[Row];
  case Col of
    0: Text := IntToStr(P.Id);
    1: Text := P.LongName + IfThen(P.Enabled, '', '  (disabled)');
    2: Text := KindKeys[P.Kind];
    3:
      case P.Kind of
        pkVehicle: Text := P.PidCode;
        pkAnalog: Text := 'A/D ' + IntToStr(P.AnalogChannel);
      end;
    4:
      if P.Kind = pkVehicle then
        Text := IntToStr(P.DataLength);
    5: Text := P.Units;
  end;
end;

procedure TPidEditorForm.FillList;
var
  I: Integer;
  P: TPidDef;
  Filter: string;
begin
  Filter := LowerCase(Trim(edtFilter.Text));
  FRows := nil;
  for I := 0 to FWork.Count - 1 do
  begin
    P := FWork[I];
    if (Filter <> '') and (Pos(Filter, LowerCase(Format('%d %s %s %s %s',
      [P.Id, P.LongName, P.ShortName, P.PidCode, P.Mci]))) = 0) then
      Continue;
    FRows := FRows + [P];
  end;
  lvList.OnSelect := nil;
  try
    lvList.RowCount := Length(FRows);
    lvList.AutoRowHeights;
    // A phone opens a PID with a tap, so nothing is selected in the list there.
    if FNarrow then
      lvList.ItemIndex := -1
    else
      lvList.ItemIndex := RowOf(FCurrent);
  finally
    lvList.OnSelect := ListSelect;
  end;
  lvList.Refresh;
end;

function TPidEditorForm.RowOf(P: TPidDef): Integer;
begin
  if P <> nil then
    for Result := 0 to High(FRows) do
      if FRows[Result] = P then
        Exit;
  Result := -1;
end;

procedure TPidEditorForm.Select(P: TPidDef);
begin
  FCurrent := P;
  lvList.OnSelect := nil;
  try
    lvList.ItemIndex := RowOf(P);
  finally
    lvList.OnSelect := ListSelect;
  end;
  ShowCurrent;
end;

procedure TPidEditorForm.ListSelect(Sender: TObject);
var
  Row: Integer;
begin
  Row := lvList.ItemIndex;
  if (Row >= 0) and (Row <= High(FRows)) and (FRows[Row] <> FCurrent) then
  begin
    FCurrent := FRows[Row];
    ShowCurrent;
  end;
  if FNarrow and (Row >= 0) then
    SetDetailMode(True); // a phone: the details get the whole page
end;

procedure TPidEditorForm.edtFilterChange(Sender: TObject);
begin
  FillList;
end;

{ Detail }

procedure TPidEditorForm.SetDetailEnabled(Value: Boolean);
begin
  pnlDetail.Enabled := Value;
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
    chkEnabled.IsChecked := P.Enabled;
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
  if FNarrow then
    StackDetail;
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
  P.Enabled := chkEnabled.IsChecked;
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
        P.DataLength := StrToIntDef(ComboText(cbBytes), 0);
        P.AnalogChannel := 0;
      end;
    pkAnalog:
      begin
        P.AnalogChannel := StrToIntDef(ComboText(cbChannel), 0);
        P.PidCode := IntToHex($FFFF - P.AnalogChannel + 1, 4);
        P.DataLength := 0;
      end;
  else
    P.PidCode := 'FPID';
    P.DataLength := 0;
    P.AnalogChannel := 0;
  end;
  FModified := True;
  lvList.Refresh;
end;

procedure TPidEditorForm.FieldChanged(Sender: TObject);
begin
  if FLoading or (FCurrent = nil) then
    Exit;
  ApplyFields;
  if Sender = cbKind then
  begin
    // Sensible defaults when the kind changes.
    FLoading := True;
    try
      if (FCurrent.Kind = pkVehicle) and (cbBytes.ItemIndex < 0) then
        cbBytes.ItemIndex := 0;
      if (FCurrent.Kind = pkAnalog) and (cbChannel.ItemIndex < 0) then
        cbChannel.ItemIndex := 0;
      if (FCurrent.Kind = pkCalculated) and (FCurrent.Category <> pcCalculated) then
        cbCategory.ItemIndex := Ord(pcCalculated);
      if (FCurrent.Kind = pkAnalog) and (FCurrent.Category <> pcAnalog) then
        cbCategory.ItemIndex := Ord(pcAnalog);
    finally
      FLoading := False;
    end;
    ApplyFields;
    UpdateKindControls;
  end;
  UpdateFormulaStatus;
  UpdateTest;
  UpdateProblems;
  if FNarrow then
    StackDetail; // status texts may need more or fewer lines
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
    pkVehicle: lblTestInput.Text := 'Data bytes (hex)';
    pkAnalog: lblTestInput.Text := 'A/D sample (hex)';
  else
    lblTestInput.Text := 'Inputs (NAME=value ...)';
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
    SetLabelColor(lblFormulaStatus, ColorError);
    lblFormulaStatus.Text := Err;
    Exit;
  end;
  if FCurrent.FormulaText = '' then
  begin
    SetLabelColor(lblFormulaStatus, ColorGrey);
    if FCurrent.Kind = pkCalculated then
      lblFormulaStatus.Text := 'No formula: shows the value of its MCI (e.g. RUNTIME, LOGTIME)'
    else
      lblFormulaStatus.Text := 'No formula: the value will show as --';
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
    SetLabelColor(lblFormulaStatus, ColorWarn);
    lblFormulaStatus.Text := 'Formula OK, but no PID has MCI:' + Missing;
  end
  else
  begin
    SetLabelColor(lblFormulaStatus, ColorGood);
    if Length(FCurrent.Formula.Variables) > 0 then
      lblFormulaStatus.Text := 'Formula OK - uses %' + string.Join('%, %', FCurrent.Formula.Variables) + '%'
    else
      lblFormulaStatus.Text := 'Formula OK';
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
  SetLabelColor(lblTestResult, $FF1E1E1E);
  if (FCurrent = nil) or (FCurrent.FormulaError <> '') then
  begin
    lblTestResult.Text := '-';
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
    lblTestResult.Text := FCurrent.FormatValue(V) + IfThen(FCurrent.Units <> '', ' ' + FCurrent.Units, '');
  except
    on E: Exception do
    begin
      SetLabelColor(lblTestResult, ColorError);
      lblTestResult.Text := E.Message;
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
  Keep: TPointF;
  Item: TListBoxItem;
begin
  FProblems := FWork.Validate;
  Keep := lbProblems.ViewportPosition;
  lbProblems.BeginUpdate;
  try
    lbProblems.Clear;
    for Pr in FProblems do
    begin
      Item := TListBoxItem.Create(lbProblems);
      Item.Text := Pr.Text;
      Item.StyledSettings := Item.StyledSettings - [TStyledSetting.FontColor];
      Item.TextSettings.FontColor := $FFA00000;
      lbProblems.AddObject(Item);
    end;
  finally
    lbProblems.EndUpdate;
  end;
  lbProblems.ViewportPosition := Keep;
  pnlProblems.Visible := Length(FProblems) > 0;
  if Length(FProblems) = 0 then
  begin
    SetLabelColor(lblProblems, ColorGood);
    lblProblems.Text := Format('%d PIDs, no problems', [FWork.Count]);
  end
  else
  begin
    SetLabelColor(lblProblems, ColorError);
    lblProblems.Text := Format('%d PIDs, %d problem(s) to fix before saving - click one above to go to the PID',
      [FWork.Count, Length(FProblems)]);
  end;
end;

procedure TPidEditorForm.lblProblemsClick(Sender: TObject);
begin
  if pnlProblems.Visible and (lbProblems.Count > 0) then
    lbProblems.SetFocus;
end;

procedure TPidEditorForm.lbProblemsItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
var
  I: Integer;
  P: TPidDef;
begin
  I := Item.Index;
  if (I < 0) or (I > High(FProblems)) or (FProblems[I].Index < 0) or (FProblems[I].Index >= FWork.Count) then
    Exit;
  P := FWork[FProblems[I].Index];
  if RowOf(P) < 0 then
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
  I: Integer;
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
  P := FCurrent;
  Confirm(Msg,
    procedure
    var
      Idx: Integer;
    begin
      Idx := FWork.IndexOf(P);
      if Idx < 0 then
        Exit;
      FWork.Delete(Idx);
      FCurrent := nil;
      FModified := True;
      FillList;
      if FWork.Count > 0 then
        Select(FWork[Min(Idx, FWork.Count - 1)])
      else
        ShowCurrent;
      UpdateProblems;
    end);
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
  FileName: string;
begin
  if IsMobile then
    Exit;
  FileName := '';
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := 'Import old UVSCAN PID file';
    Dlg.Filter := 'UVSCAN PID file (*.csv)|*.csv|All files (*.*)|*.*';
    Dlg.Options := Dlg.Options + [TOpenOption.ofFileMustExist];
    if Dlg.Execute then
      FileName := Dlg.FileName;
  finally
    Dlg.Free;
  end;
  if FileName <> '' then
    ImportFile(FileName);
end;

procedure TPidEditorForm.ImportFile(const FileName: string);
var
  Imported: TPidCatalog;
  NewCount, Disabled, I: Integer;
  Notes: string;
begin
  Imported := TPidCatalog.Create;
  try
    ImportLegacyPidsCsv(FileName, Imported);
  except
    on E: Exception do
    begin
      Imported.Free;
      ShowError('Could not read ' + FileName + ':' + sLineBreak + E.Message);
      Exit;
    end;
  end;
  if Imported.Count = 0 then
  begin
    ShowWarning('No PIDs found in ' + FileName + '.' + sLineBreak + sLineBreak +
      Lines(Imported.Warnings.ToStringArray, 15));
    Imported.Free;
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
  Notes := '';
  if Imported.Warnings.Count > 0 then
    Notes := Lines(Imported.Warnings.ToStringArray, 25);

  ChooseOption('Import PIDs',
    Format('%d PIDs read from %s', [Imported.Count, ExtractFileName(FileName)]),
    Format('%d are new to your list; %d match a PID you already have (same PID and name or formula).',
      [NewCount, Imported.Count - NewCount]) + sLineBreak + 'Nothing is written until you press Save.',
    Notes, Format('%d note(s) about this file', [Imported.Warnings.Count]),
    [Choice('Add the new PIDs', 'Keep every PID you have as it is; add the ones you do not have yet.', 101),
     Choice('Add new PIDs and update matching ones',
       'Matching PIDs are replaced by the imported definition (they keep their ID).', 102),
     Choice('Replace my list with this file', 'Use only the imported PIDs.', 100)],
    procedure(Picked: Integer)
    var
      Mode: TMergeMode;
      R: TMergeResult;
      Summary: string;
    begin
      try
        case Picked of
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
        ShowInfo(Summary);
      finally
        Imported.Free;
      end;
    end);
end;

procedure TPidEditorForm.btnDefaultsClick(Sender: TObject);
var
  Defaults: TPidCatalog;
  Missing, I: Integer;
begin
  Defaults := TPidCatalog.Create;
  try
    Defaults.LoadFromJsonText(DefaultPidsJson);
  except
    on E: Exception do
    begin
      Defaults.Free;
      ShowError('Could not load the built-in defaults: ' + E.Message);
      Exit;
    end;
  end;
  Missing := 0;
  for I := 0 to Defaults.Count - 1 do
    if FindMatchingPid(FWork, Defaults[I]) = nil then
      Inc(Missing);

  ChooseOption('Default PIDs',
    Format('The built-in list has %d PIDs', [Defaults.Count]),
    Format('%d of them are not in your list.', [Missing]) + sLineBreak + 'Nothing is written until you press Save.',
    '', '',
    [Choice('Add the default PIDs I do not have',
       'Keeps everything in your list, including your own changes and imports.', 101),
     Choice('Replace my list with the defaults', 'Throws away your changes, imports and added PIDs.', 100)],
    procedure(Picked: Integer)
    var
      R: TMergeResult;
      Msg: string;
    begin
      try
        case Picked of
          101:
            begin
              R := MergeCatalog(FWork, Defaults, mmAddNew);
              Msg := Format('Added %d default PIDs.', [R.Added]);
              if Length(R.MciCleared) > 0 then
                Msg := Msg + sLineBreak + Format('%d of them used an MCI name you already have, so it was removed:',
                  [Length(R.MciCleared)]) + sLineBreak + Lines(R.MciCleared, 10);
            end;
          100:
            begin
              FWork.Assign(Defaults);
              Msg := Format('Your list is now the %d default PIDs.', [Defaults.Count]);
            end;
        else
          Exit;
        end;
        AfterBulkChange;
        ShowInfo(Msg);
      finally
        Defaults.Free;
      end;
    end);
end;

{ Save }

procedure TPidEditorForm.btnSaveClick(Sender: TObject);
begin
  UpdateProblems;
  if Length(FProblems) > 0 then
  begin
    ShowWarning(Format('There are %d problem(s) to fix first. They are listed at the bottom of this window; ' +
      'click one to go to that PID.', [Length(FProblems)]));
    lbProblems.SetFocus;
    Exit;
  end;
  try
    FWork.SaveToJsonFile(FFileName);
  except
    on E: Exception do
    begin
      ShowError('Could not save ' + FFileName + ':' + sLineBreak + E.Message);
      Exit;
    end;
  end;
  FSaved := True;
  ModalResult := mrOk;
end;

end.
