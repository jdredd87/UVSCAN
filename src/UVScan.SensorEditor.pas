unit UVScan.SensorEditor;

{ The Sensors page: the sensors UVScan reads beside the vehicle (see
  UVScan.Sensors), and the builder for them, in four steps:
    1. the device: a template, a shared sensor file (Import) or nothing;
       what it sends, its port...
    2. Test: every field it sends as it comes;
    3. its PIDs: one for any field (name, formula over the raw value N0,
       units, MCI), and calculated ones over them, each with its live value;
    4. Save, and Share / Export: the sensor, its PIDs and the calculated
       PIDs that use them, as a .uvsensor file for someone else. }

interface

uses
  System.SysUtils, UVScan.Pids, UVScan.Sensors;

{ Edits copies of Sensors and Catalog on a page of its own. Save writes
  SensorsFileName, and PidsFileName when PIDs were added, renamed or
  deleted with a sensor. OnDone (always called) gets True when saved. }
procedure EditSensors(Sensors: TSensorCatalog; Catalog: TPidCatalog; const SensorsFileName, PidsFileName: string;
  const OnDone: TProc<Boolean>);

implementation

uses
  System.Classes, System.Types, System.UITypes, System.Math, System.StrUtils, System.JSON, System.IOUtils,
  System.Generics.Collections, UVScan.Formula,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit, FMX.ComboEdit, FMX.ListBox, FMX.Layouts,
  FMX.Dialogs, FMX.Graphics,
  UVScan.Serial, UVScan.JsonFile, UVScan.Share, UVScan.UI.Common, UVScan.UI.Theme, UVScan.Paths;

const
  NarrowWidth = 600;
  RowHeight = 36;

type
  TSensorPage = class(TComponent)
  private
    FForm: TForm;
    FBox: TVertScrollBox;
    FY: Single;
    FWork: TSensorCatalog;
    FPids: TPidCatalog;
    FSensorsFile, FPidsFile: string;
    FCurrent: Integer;        // index in FWork, -1 = none
    FShownName: string;       // the current sensor's name as its PIDs have it
    FLoading: Boolean;
    FChanged, FPidsChanged, FSaved, FDiscardOk: Boolean;
    FReader: TSensorReader;   // the running test
    FTimer: TTimer;
    FNarrow: Boolean;
    FButtonsWidth: Single;    // the width the button row was flowed for
    FDetail: TArray<TControl>; // shown while a sensor is selected
    FOrder: TArray<TControl>;  // everything on the page, top to bottom
    FRows: TArray<TControl>;
    FCaps: TArray<TLabel>;
    rowSend, rowEvery: TLayout; // sensors that can be asked (text, packets)
    rowLayout: TLayout;         // packet sensors only
    edtLayout: TEdit;
    lblLayout: TLabel;
    FTemplates: TArray<TSensorTemplate>;
    lbSensors: TListBox;
    lblEmpty: TLabel;
    pnlButtons: TLayout;
    btnAdd, btnImport, btnShare, btnDelete: TButton;
    edtName: TEdit;
    cbProtocol: TComboBox;
    cbPort: TComboEdit;
    cbBaud: TComboEdit;
    edtSend: TEdit;
    edtEvery: TEdit;
    edtDescription: TEdit;
    chkEnabled: TCheckBox;
    lblPids: TLabel;            // no PIDs yet: how to add one
    pnlTest: TLayout;
    btnTest: TButton;
    lblPortHint: TLabel;        // no port yet: why Start test is off
    lblStatus, lblLast: TLabel;
    lbFields: TListBox;
    btnAddPid: TButton;
    lbPidList: TListBox;        // the sensor's PIDs, with live values
    FPidRows: TArray<TPidDef>;
    pnlPidButtons: TLayout;
    btnPidAdd, btnPidCalc, btnPidEdit, btnPidDelete: TButton;
    FPidButtonsWidth: Single;
    function Add(C: TControl; Height: Single; Detail: Boolean = True): TControl;
    function Caption(const Text: string; Detail: Boolean = True): TLabel;
    function Row(const Text: string; Field: TControl): TLayout;
    function Note(Detail: Boolean = True): TLabel;
    procedure Build;
    procedure Relayout;
    procedure FormResized(Sender: TObject);
    procedure ButtonsResized(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure CloseDiscarding;
    procedure FillList;
    procedure ShowSensor(Index: Integer);
    procedure ApplyFields;
    procedure FieldChanged(Sender: TObject);
    procedure NameChanged(Sender: TObject);
    procedure ProtocolChanged(Sender: TObject);
    procedure ShowProtocolRows(P: TSensorProtocol);
    procedure KeepOrder;
    procedure UpdateLayoutNote;
    function ListText(D: TSensorDef): string;
    procedure UpdatePids;
    procedure UpdateTestButton;
    procedure PortTyping(Sender: TObject);
    procedure PidButtonsResized(Sender: TObject);
    function LinkedCalcs(const SensorName: string): TArray<TPidDef>;
    function SensorPids(const SensorName: string): TArray<TPidDef>;
    function TestFields: TArray<string>;
    function LiveRaw(const Field: string): Double;
    function LiveValue(P: TPidDef; Depth: Integer = 0): Double;
    function LiveByMci(const Mci: string): Double;
    function PidRowText(P: TPidDef): string;
    function SelectedPid: TPidDef;
    procedure EditPid(P: TPidDef; Kind: TPidKind; const Field: string);
    procedure PidAddClick(Sender: TObject);
    procedure PidCalcClick(Sender: TObject);
    procedure PidEditClick(Sender: TObject);
    procedure PidDeleteClick(Sender: TObject);
    procedure SensorClick(Sender: TObject);
    procedure AddClick(Sender: TObject);
    procedure TemplateClick(Sender: TObject);
    procedure ImportClick(Sender: TObject);
    procedure ImportFile(const FileName: string);
    procedure ShareClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure TestClick(Sender: TObject);
    procedure StartTest;
    procedure StopTest;
    procedure TimerTick(Sender: TObject);
    procedure AddPidClick(Sender: TObject);
    function FreeMci(const Name: string): string;
    procedure SaveClick(Sender: TObject);
    function CurrentDef: TSensorDef;
    function PidsOf(const SensorName: string): TArray<TPidDef>;
    function CheckNames: Boolean;
  public
    destructor Destroy; override;
  end;

  { One PID of the sensor: a value it sends (the field) and a formula over
    it (N0), or a calculated PID over its PIDs; with what it shows now while
    the test runs, or for a value typed in. }
  TSensorPidDialog = class(TComponent)
  private
    FPage: TSensorPage;
    FForm: TForm;
    FPid: TPidDef;            // nil: a new one
    FKind: TPidKind;
    FBox: TVertScrollBox;
    FY: Single;
    FLoading: Boolean;
    FMciTyped: Boolean;       // the MCI was typed: a new name leaves it alone
    edtName, edtShort, edtFormula, edtMci, edtTry: TEdit;
    cbField, cbUnits: TComboEdit;
    lblHelp, lblResult: TLabel;
    FTimer: TTimer;
    procedure AddRow(const Caption: string; C: TControl);
    function AddNote: TLabel;
    procedure Relayout;
    procedure BoxResized(Sender: TObject);
    procedure Changed(Sender: TObject);
    procedure NameTyping(Sender: TObject);
    procedure MciTyping(Sender: TObject);
    procedure OkClick(Sender: TObject);
  public
    procedure Build(const Field: string);
  end;

function Num(V: Double): string;
begin
  if IsNan(V) then
    Result := '--'
  else
    Result := FormatFloat('0.###', V, TFormatSettings.Invariant);
end;

destructor TSensorPage.Destroy;
begin
  // The form's controls are gone by now: only the test's thread is stopped
  // (StopTest would update them).
  FreeAndNil(FReader);
  FWork.Free;
  FPids.Free;
  inherited;
end;

{ Building the page }

function TSensorPage.Add(C: TControl; Height: Single; Detail: Boolean): TControl;
begin
  C.Parent := FBox;
  C.Align := TAlignLayout.Top;
  C.Position.Y := FY;
  C.Height := Height;
  FY := FY + Height + 100; // the order; the realign closes the gaps
  FOrder := FOrder + [C];
  if Detail then
    FDetail := FDetail + [C];
  Result := C;
end;

function TSensorPage.Caption(const Text: string; Detail: Boolean): TLabel;
begin
  Result := TLabel.Create(FForm);
  Result.Margins.Top := 14;
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Style];
  Result.TextSettings.Font.Style := [TFontStyle.fsBold];
  Result.Text := Text;
  Add(Result, 24, Detail);
end;

function TSensorPage.Note(Detail: Boolean): TLabel;
begin
  Result := TLabel.Create(FForm);
  Result.WordWrap := True;
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.FontColor];
  Result.TextSettings.FontColor := Palette.Muted;
  Add(Result, 22, Detail);
end;

function TSensorPage.Row(const Text: string; Field: TControl): TLayout;
var
  L: TLabel;
begin
  Result := TLayout.Create(FForm);
  Result.Margins.Top := 4;
  Add(Result, RowHeight + 6);
  L := TLabel.Create(FForm);
  L.Parent := Result;
  L.Text := Text;
  Field.Parent := Result;
  Field.Align := TAlignLayout.Client;
  Field.Margins.Bottom := 6;
  FRows := FRows + [Result];
  FCaps := FCaps + [L];
end;

procedure TSensorPage.Build;
var
  P: TSensorProtocol;
  B: TButton;
  Bar: TLayout;
  Ok: TButton;
begin
  FForm.OnCloseQuery := FormCloseQuery;
  Bar := TLayout.Create(FForm);
  Bar.Parent := FForm;
  Bar.Align := TAlignLayout.Bottom;
  Bar.Height := 52;
  B := TButton.Create(FForm);
  B.Parent := Bar;
  B.Align := TAlignLayout.Right;
  B.Text := 'Cancel';
  B.Cancel := True;
  B.ModalResult := mrCancel;
  Ok := TButton.Create(FForm);
  Ok.Parent := Bar;
  Ok.Align := TAlignLayout.Right;
  Ok.Text := 'Save';
  Ok.OnClick := SaveClick;
  FBox := TVertScrollBox.Create(FForm);
  FBox.Parent := FForm;
  FBox.Align := TAlignLayout.Client;
  FBox.Padding.Rect := TRectF.Create(16, 4, 16, 16);
  FBox.OnResized := FormResized;
  FY := 0;

  with Note(False) do
    Text := 'Sensors are devices UVScan reads beside the car while it scans: a wideband controller, ' +
      'an EGT box, anything that sends numbers on a serial, Bluetooth or network port. What a sensor ' +
      'measures shows as sensor PIDs: tick them in the PID list like any other.';
  lbSensors := TListBox.Create(FForm);
  lbSensors.Margins.Top := 10;
  Add(lbSensors, 100, False);
  lbSensors.OnChange := SensorClick;
  lblEmpty := Note(False);
  lblEmpty.Text := 'No sensors yet. Add one: an Innovate or AEM wideband, or anything that prints numbers.';
  pnlButtons := TLayout.Create(FForm);
  pnlButtons.Margins.Top := 8;
  Add(pnlButtons, 48, False);
  pnlButtons.OnResized := ButtonsResized;
  btnAdd := TButton.Create(FForm);
  btnAdd.Parent := pnlButtons;
  btnAdd.Text := 'Add...';
  btnAdd.OnClick := AddClick;
  btnImport := TButton.Create(FForm);
  btnImport.Parent := pnlButtons;
  btnImport.Text := 'Import...';
  btnImport.OnClick := ImportClick;
  btnShare := TButton.Create(FForm);
  btnShare.Parent := pnlButtons;
  btnShare.Text := IfThen(CanShareFiles, 'Share...', 'Export...');
  btnShare.OnClick := ShareClick;
  btnDelete := TButton.Create(FForm);
  btnDelete.Parent := pnlButtons;
  btnDelete.Text := 'Delete';
  btnDelete.OnClick := DeleteClick;

  Caption('1. The device');
  edtName := TEdit.Create(FForm);
  edtName.OnChange := NameChanged;
  edtName.OnChangeTracking := NameChanged; // the list and its PIDs follow as it is typed
  Row('Name', edtName);
  cbProtocol := TComboBox.Create(FForm);
  for P := Low(TSensorProtocol) to High(TSensorProtocol) do
    cbProtocol.Items.Add(SensorProtocolNames[P]);
  cbProtocol.OnChange := ProtocolChanged;
  Row('Sends', cbProtocol);
  cbPort := TComboEdit.Create(FForm);
  cbPort.Items.AddStrings(ListSerialPorts);
  cbPort.Items.Add(SensorSimulatorPort);
  cbPort.TextPrompt := 'COM5, a Bluetooth port, 192.168.4.1:23...';
  cbPort.OnChange := FieldChanged;
  cbPort.OnChangeTracking := PortTyping;
  Row('Port', cbPort);
  cbBaud := TComboEdit.Create(FForm);
  cbBaud.Items.CommaText := '4800,9600,19200,38400,57600,115200';
  cbBaud.OnChange := FieldChanged;
  Row('Baud', cbBaud);
  edtSend := TEdit.Create(FForm);
  edtSend.TextPrompt := 'nothing (it sends by itself)';
  edtSend.OnChange := FieldChanged;
  edtLayout := TEdit.Create(FForm);
  edtLayout.TextPrompt := 'start 00 01 02; length 14; afr 3; egt 4-5 le';
  edtLayout.OnChange := FieldChanged;
  edtLayout.OnChangeTracking := FieldChanged;
  rowLayout := Row('Layout', edtLayout);
  lblLayout := Note;
  rowSend := Row('Ask with', edtSend);
  edtEvery := TEdit.Create(FForm);
  edtEvery.TextPrompt := '1000';
  edtEvery.OnChange := FieldChanged;
  rowEvery := Row('Every (ms)', edtEvery);
  edtDescription := TEdit.Create(FForm);
  edtDescription.OnChange := FieldChanged;
  Row('Description', edtDescription);
  chkEnabled := TCheckBox.Create(FForm);
  chkEnabled.Text := 'Read it when a scan has its PIDs';
  chkEnabled.OnChange := FieldChanged;
  Add(chkEnabled, 34);

  Caption('2. Test it');
  lblPortHint := Note;
  lblPortHint.Text := 'Choose its port above first (Simulator makes up data, to try this without the device).';
  pnlTest := TLayout.Create(FForm);
  Add(pnlTest, 44);
  btnTest := TButton.Create(FForm);
  btnTest.Parent := pnlTest;
  btnTest.Align := TAlignLayout.Left;
  btnTest.Margins.Bottom := 4;
  btnTest.Width := 140;
  btnTest.Text := 'Start test';
  btnTest.OnClick := TestClick;
  lblStatus := Note;
  lblLast := Note;
  lbFields := TListBox.Create(FForm);
  lbFields.Margins.Top := 6;
  Add(lbFields, 150);
  btnAddPid := TButton.Create(FForm);
  btnAddPid.Margins.Top := 8;
  btnAddPid.Text := 'Add a PID for this field...';
  btnAddPid.OnClick := AddPidClick;
  Add(btnAddPid, 40);
  lblStatus.Text := 'Start the test to see what the sensor sends: every field and its value.';

  Caption('3. Its PIDs');
  lblPids := Note;
  lbPidList := TListBox.Create(FForm);
  lbPidList.Margins.Top := 6;
  lbPidList.OnDblClick := PidEditClick;
  Add(lbPidList, 44);
  pnlPidButtons := TLayout.Create(FForm);
  pnlPidButtons.Margins.Top := 8;
  Add(pnlPidButtons, 48);
  pnlPidButtons.OnResized := PidButtonsResized;
  btnPidAdd := TButton.Create(FForm);
  btnPidAdd.Parent := pnlPidButtons;
  btnPidAdd.Text := 'Add PID...';
  btnPidAdd.OnClick := PidAddClick;
  btnPidCalc := TButton.Create(FForm);
  btnPidCalc.Parent := pnlPidButtons;
  btnPidCalc.Text := 'Add calculated...';
  btnPidCalc.OnClick := PidCalcClick;
  btnPidEdit := TButton.Create(FForm);
  btnPidEdit.Parent := pnlPidButtons;
  btnPidEdit.Text := 'Edit...';
  btnPidEdit.OnClick := PidEditClick;
  btnPidDelete := TButton.Create(FForm);
  btnPidDelete.Parent := pnlPidButtons;
  btnPidDelete.Text := 'Delete PID';
  btnPidDelete.OnClick := PidDeleteClick;

  Caption('4. Save it');
  with Note do
    Text := 'Save (top right) keeps the sensor and its PIDs; then tick them in the PID list to scan them. ' +
      IfThen(CanShareFiles, 'Share...', 'Export...') + ' (above) writes it all as a ' + SensorFileExt +
      ' file for someone else, who adds it with Import.';

  FTimer := TTimer.Create(FForm);
  FTimer.Enabled := False;
  FTimer.Interval := 250;
  FTimer.OnTimer := TimerTick;
  MakePage(FForm, 'Sensors', Ok);
end;

procedure TSensorPage.FormResized(Sender: TObject);
begin
  Relayout;
end;

{ The buttons wrap by the row's width, which is only known once the page
  has been laid out (flowed at the first, made-up width, each had a line). }
procedure TSensorPage.ButtonsResized(Sender: TObject);
begin
  if (btnDelete = nil) or SameValue(pnlButtons.Width, FButtonsWidth, 0.5) then
    Exit;
  FButtonsWidth := pnlButtons.Width;
  FlowControls(pnlButtons, [btnAdd, btnImport, btnShare, btnDelete]);
end;

procedure TSensorPage.Relayout;
var
  W: Single;
  L: TLabel;
  N: Integer;
  Moved: Boolean;
begin
  if pnlButtons = nil then
    Exit; // not built yet
  W := FBox.Width - FBox.Padding.Left - FBox.Padding.Right - 4;
  if W < 100 then
    Exit;
  FNarrow := InnerWidth(FForm) < NarrowWidth;
  ArrangeCaptionRows(FRows, FCaps, FNarrow, RowHeight);
  for var C in FBox.Content.Controls do
    if (C is TLabel) and TLabel(C).WordWrap then
    begin
      L := TLabel(C);
      L.Height := Max(20, WrappedTextHeight(L, W) + 4);
    end;
  FButtonsWidth := pnlButtons.Width;
  FlowControls(pnlButtons, [btnAdd, btnImport, btnShare, btnDelete]);
  FitTextWidth(btnTest, 140);
  N := Max(1, lbSensors.Count);
  lbSensors.Height := Min(N, 5) * 40 + 4;
  // every field and PID without scrolling inside the page's own scrolling
  lbFields.Height := Max(1, lbFields.Count) * 36 + 4;
  lbPidList.Height := Max(1, lbPidList.Count) * 40 + 4;
  // empty lists (no test yet, no PIDs yet) take no room
  if CurrentDef <> nil then
  begin
    Moved := False;
    for var Pair in [TPair<TControl, Boolean>.Create(lbFields, lbFields.Count > 0),
      TPair<TControl, Boolean>.Create(btnAddPid, lbFields.Count > 0),
      TPair<TControl, Boolean>.Create(lbPidList, lbPidList.Count > 0)] do
      if Pair.Key.Visible <> Pair.Value then
      begin
        Pair.Key.Visible := Pair.Value;
        Moved := True;
      end;
    if Moved then
      KeepOrder;
  end;
  FPidButtonsWidth := pnlPidButtons.Width;
  FlowControls(pnlPidButtons, [btnPidAdd, btnPidCalc, btnPidEdit, btnPidDelete]);
end;

procedure TSensorPage.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if (FForm.ModalResult = mrOk) or not (FChanged or FPidsChanged) or FDiscardOk then
  begin
    StopTest;
    Exit;
  end;
  CanClose := False;
  Confirm('Discard your changes to the sensors?',
    procedure
    begin
      FDiscardOk := True;
      TThread.ForceQueue(nil, CloseDiscarding);
    end);
end;

procedure TSensorPage.CloseDiscarding;
begin
  FForm.ModalResult := mrCancel;
end;

{ The list and the selected sensor }

function TSensorPage.CurrentDef: TSensorDef;
begin
  if (FCurrent >= 0) and (FCurrent < FWork.Count) then
    Result := FWork[FCurrent]
  else
    Result := nil;
end;

function TSensorPage.PidsOf(const SensorName: string): TArray<TPidDef>;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FPids.Count - 1 do
    if (FPids[I].Kind = pkSensor) and SameText(FPids[I].SensorName, SensorName) then
      Result := Result + [FPids[I]];
end;

procedure TSensorPage.FillList;
var
  I: Integer;
  D: TSensorDef;
  Item: TListBoxItem;
begin
  FLoading := True;
  try
    lbSensors.BeginUpdate;
    try
      lbSensors.Clear;
      for I := 0 to FWork.Count - 1 do
      begin
        D := FWork[I];
        Item := TListBoxItem.Create(lbSensors);
        Item.Height := 40;
        Item.Text := ListText(D);
        lbSensors.AddObject(Item);
      end;
    finally
      lbSensors.EndUpdate;
    end;
    lbSensors.ItemIndex := FCurrent;
  finally
    FLoading := False;
  end;
  lbSensors.Visible := FWork.Count > 0;
  lblEmpty.Visible := FWork.Count = 0;
  KeepOrder;
  btnShare.Enabled := FCurrent >= 0;
  btnDelete.Enabled := FCurrent >= 0;
  Relayout;
end;

procedure TSensorPage.ShowSensor(Index: Integer);
var
  D: TSensorDef;
  C: TControl;
begin
  StopTest;
  FCurrent := Index;
  D := CurrentDef;
  for C in FDetail do
    C.Visible := D <> nil;
  if D <> nil then
    ShowProtocolRows(D.Protocol)
  else
    KeepOrder;
  btnShare.Enabled := D <> nil;
  btnDelete.Enabled := D <> nil;
  if D = nil then
    Exit;
  FLoading := True;
  try
    FShownName := D.Name;
    edtName.Text := D.Name;
    cbProtocol.ItemIndex := Ord(D.Protocol);
    cbPort.Text := D.Port;
    cbBaud.Text := IntToStr(D.Baud);
    edtSend.Text := D.Send;
    edtEvery.Text := IfThen(D.Send <> '', IntToStr(D.SendEveryMs), '');
    edtDescription.Text := D.Description;
    edtLayout.Text := D.Layout;
    chkEnabled.IsChecked := D.Enabled;
  finally
    FLoading := False;
  end;
  UpdateLayoutNote;
  lbFields.Clear;
  lblLast.Text := '';
  lblStatus.Text := 'Start the test to see what the sensor sends: every field and its value.';
  UpdatePids;
  UpdateTestButton;
  Relayout;
end;

{ The PIDs list: the sensor's PIDs and the calculated ones over them, each
  with its value now while the test runs; the selection kept. }
procedure TSensorPage.UpdatePids;
var
  P, Keep: TPidDef;
  Item: TListBoxItem;
  D: TSensorDef;
  I: Integer;
begin
  D := CurrentDef;
  if D = nil then
    Exit;
  Keep := SelectedPid;
  FPidRows := SensorPids(D.Name);
  if lbPidList.Count = Length(FPidRows) then
  begin
    // the same rows: only their text (a rebuild would lose a tap)
    for I := 0 to High(FPidRows) do
      lbPidList.ListItems[I].Text := PidRowText(FPidRows[I]);
  end
  else
  begin
    lbPidList.BeginUpdate;
    try
      lbPidList.Clear;
      for P in FPidRows do
      begin
        Item := TListBoxItem.Create(lbPidList);
        Item.Height := 40;
        Item.Text := PidRowText(P);
        lbPidList.AddObject(Item);
        if P = Keep then
          Item.IsSelected := True;
      end;
    finally
      lbPidList.EndUpdate;
    end;
  end;
  if Length(FPidRows) = 0 then
    lblPids.Text := 'None yet. Start the test, pick one of the values it sends and Add a PID for this field; ' +
      'or Add PID... and type the field.'
  else
    lblPids.Text := 'Tap one to change its name, formula (N0 = the value it sends) or units. ' +
      'Calculated PIDs work out a value from these, e.g. %WBAFR% - 14.7.';
  btnPidEdit.Enabled := Length(FPidRows) > 0;
  btnPidDelete.Enabled := Length(FPidRows) > 0;
  Relayout;
end;

function TSensorPage.PidRowText(P: TPidDef): string;
var
  V: Double;
begin
  if P.Kind = pkSensor then
    Result := Format('%s   %s', [P.DisplayName, P.SensorField])
  else
    Result := Format('%s   = %s', [P.DisplayName, P.FormulaText]);
  if FReader <> nil then
  begin
    V := LiveValue(P);
    Result := Result + '   ' + P.FormatValue(V) + IfThen((P.Units <> '') and not IsNan(V), ' ' + P.Units);
  end
  else if P.Units <> '' then
    Result := Result + '   (' + P.Units + ')';
end;

function TSensorPage.SelectedPid: TPidDef;
begin
  if (lbPidList <> nil) and (lbPidList.ItemIndex >= 0) and (lbPidList.ItemIndex <= High(FPidRows)) then
    Result := FPidRows[lbPidList.ItemIndex]
  else
    Result := nil;
end;

{ Calculated PIDs whose formula uses one of the sensor's PIDs. }
function TSensorPage.LinkedCalcs(const SensorName: string): TArray<TPidDef>;
var
  Mcis: TArray<string>;
  P: TPidDef;
  I: Integer;
  V: string;
begin
  Result := nil;
  Mcis := nil;
  for P in PidsOf(SensorName) do
    if P.Mci <> '' then
      Mcis := Mcis + [UpperCase(P.Mci)];
  if Mcis = nil then
    Exit;
  for I := 0 to FPids.Count - 1 do
  begin
    P := FPids[I];
    if (P.Kind <> pkCalculated) or (P.FormulaError <> '') then
      Continue;
    for V in P.Formula.Variables do
      if IndexStr(V, Mcis) >= 0 then
      begin
        Result := Result + [P];
        Break;
      end;
  end;
end;

function TSensorPage.SensorPids(const SensorName: string): TArray<TPidDef>;
begin
  Result := PidsOf(SensorName) + LinkedCalcs(SensorName);
end;

{ Live values from the running test }

function TSensorPage.LiveRaw(const Field: string): Double;
begin
  if (FReader = nil) or not FReader.TryGet(Field, SensorMaxAgeMs, Result) then
    Result := NaN;
end;

function TSensorPage.LiveValue(P: TPidDef; Depth: Integer): Double;
var
  Raw: Double;
  Vars: TArray<string>;
  Values: TArray<Double>;
  I: Integer;
begin
  Result := NaN;
  if (P = nil) or (Depth > 4) or (P.FormulaError <> '') then
    Exit;
  try
    if P.Kind = pkSensor then
    begin
      if (CurrentDef = nil) or not SameText(P.SensorName, CurrentDef.Name) then
        Exit;
      Raw := LiveRaw(P.SensorField);
      if IsNan(Raw) or P.Formula.IsEmpty then
        Exit(Raw);
      Result := P.Formula.Evaluate([Raw], []);
    end
    else if P.Kind = pkCalculated then
    begin
      Vars := P.Formula.Variables;
      SetLength(Values, Length(Vars));
      for I := 0 to High(Vars) do
        Values[I] := LiveValue(FPids.FindByMci(Vars[I]), Depth + 1);
      if not P.Formula.IsEmpty then
        Result := P.Formula.Evaluate([], Values);
    end;
  except
    Result := NaN;
  end;
end;

function TSensorPage.LiveByMci(const Mci: string): Double;
begin
  Result := LiveValue(FPids.FindByMci(Mci));
end;

{ The fields the test has seen, for the PID dialog's field box. }
function TSensorPage.TestFields: TArray<string>;
var
  F: TSensorField;
begin
  Result := nil;
  if FReader <> nil then
    for F in FReader.Fields do
      Result := Result + [F.Name];
end;

procedure TSensorPage.UpdateTestButton;
var
  HasPort: Boolean;
begin
  if btnTest = nil then
    Exit;
  HasPort := Trim(cbPort.Text) <> '';
  btnTest.Enabled := HasPort or (FReader <> nil);
  if lblPortHint.Visible = HasPort then
  begin
    lblPortHint.Visible := not HasPort;
    KeepOrder;
    Relayout;
  end;
end;

procedure TSensorPage.PortTyping(Sender: TObject);
begin
  UpdateTestButton;
end;

procedure TSensorPage.PidButtonsResized(Sender: TObject);
begin
  if (btnPidDelete = nil) or SameValue(pnlPidButtons.Width, FPidButtonsWidth, 0.5) then
    Exit;
  FPidButtonsWidth := pnlPidButtons.Width;
  FlowControls(pnlPidButtons, [btnPidAdd, btnPidCalc, btnPidEdit, btnPidDelete]);
end;

procedure TSensorPage.ApplyFields;
var
  D: TSensorDef;
begin
  D := CurrentDef;
  if (D = nil) or FLoading then
    Exit;
  D.Protocol := TSensorProtocol(Max(0, cbProtocol.ItemIndex));
  D.Port := Trim(cbPort.Text);
  D.Baud := StrToIntDef(Trim(cbBaud.Text), SensorProtocolBaud[D.Protocol]);
  D.Send := edtSend.Text;
  D.SendEveryMs := StrToIntDef(Trim(edtEvery.Text), 1000);
  if D.Send = '' then
    D.SendEveryMs := 0;
  D.Description := Trim(edtDescription.Text);
  D.Layout := Trim(edtLayout.Text);
  D.Enabled := chkEnabled.IsChecked;
end;

procedure TSensorPage.FieldChanged(Sender: TObject);
begin
  if FLoading or (CurrentDef = nil) then
    Exit;
  ApplyFields;
  FChanged := True;
  if Sender = edtLayout then
  begin
    UpdateLayoutNote;
    Relayout;
    Exit; // typing: a running test goes on with the layout it started with
  end;
  if Sender = cbPort then
    UpdateTestButton;
  if (FReader <> nil) and (Sender <> edtName) and (Sender <> edtDescription) then
    StartTest; // test what is there now
  FLoading := True;
  try
    if (lbSensors.ItemIndex >= 0) and (lbSensors.ItemIndex < lbSensors.Count) then
      lbSensors.ListItems[lbSensors.ItemIndex].Text := ListText(CurrentDef);
  finally
    FLoading := False;
  end;
end;

{ A new name: its PIDs follow it. }
procedure TSensorPage.NameChanged(Sender: TObject);
var
  D: TSensorDef;
  NewName: string;
  P: TPidDef;
begin
  D := CurrentDef;
  if FLoading or (D = nil) then
    Exit;
  NewName := Trim(edtName.Text);
  if (NewName = '') or (NewName = FShownName) then
    Exit;
  for P in PidsOf(FShownName) do
  begin
    P.SensorName := NewName;
    FPidsChanged := True;
  end;
  D.Name := NewName;
  FShownName := NewName;
  FieldChanged(Sender);
  UpdatePids;
end;

procedure TSensorPage.ProtocolChanged(Sender: TObject);
var
  P: TSensorProtocol;
begin
  if FLoading or (CurrentDef = nil) then
    Exit;
  P := TSensorProtocol(Max(0, cbProtocol.ItemIndex));
  // the other protocol's usual speed: this one's
  FLoading := True;
  try
    for var Q := Low(TSensorProtocol) to High(TSensorProtocol) do
      if (Q <> P) and (Trim(cbBaud.Text) = IntToStr(SensorProtocolBaud[Q])) then
        cbBaud.Text := IntToStr(SensorProtocolBaud[P]);
  finally
    FLoading := False;
  end;
  ShowProtocolRows(P);
  FieldChanged(Sender);
  UpdateLayoutNote;
  Relayout;
end;

procedure TSensorPage.ShowProtocolRows(P: TSensorProtocol);
begin
  // MTS and PLX devices send by themselves: nothing to ask with
  rowSend.Visible := P in [spText, spPacket];
  rowEvery.Visible := P in [spText, spPacket];
  rowLayout.Visible := P = spPacket;
  lblLayout.Visible := P = spPacket;
  KeepOrder;
end;

{ A top-aligned control shown again goes to the bottom: back to its place. }
procedure TSensorPage.KeepOrder;
var
  I: Integer;
begin
  FBox.BeginUpdate;
  try
    for I := 0 to High(FOrder) do
      FOrder[I].Position.Y := I * 10000;
  finally
    FBox.EndUpdate; // realigns
  end;
end;

procedure TSensorPage.UpdateLayoutNote;
var
  L: TPacketLayout;
  Err, Names: string;
  F: TPacketField;
begin
  if (CurrentDef = nil) or (CurrentDef.Protocol <> spPacket) then
    Exit;
  lblLayout.StyledSettings := lblLayout.StyledSettings - [TStyledSetting.FontColor];
  if ParsePacketLayout(edtLayout.Text, L, Err) then
  begin
    Names := '';
    for F in L.Fields do
      Names := Names + IfThen(Names <> '', ', ') + F.Name;
    lblLayout.TextSettings.FontColor := Palette.Muted;
    lblLayout.Text := Format('%d-byte packets; fields: %s', [L.Length, Names]);
  end
  else
  begin
    lblLayout.TextSettings.FontColor := Palette.Bad;
    lblLayout.Text := Err + '. Items split by ";": start 00 01 02; length 14; NAME 3; NAME 4-5 [le] [signed].';
  end;
end;

function TSensorPage.ListText(D: TSensorDef): string;
begin
  Result := Format('%s  -  %s on %s%s', [D.Name, SensorProtocolShort[D.Protocol],
    IfThen(D.Port <> '', D.Port, '(no port yet)'), IfThen(D.Enabled, '', ', off')]);
end;

procedure TSensorPage.SensorClick(Sender: TObject);
begin
  if FLoading then
    Exit;
  ApplyFields;
  ShowSensor(lbSensors.ItemIndex);
end;

{ Add, import, share, delete }

procedure TSensorPage.AddClick(Sender: TObject);
var
  Items: TArray<TActionItem>;
  It: TActionItem;
  I: Integer;
  Tag: TComponent;
  Pt: TPointF;
begin
  FTemplates := SensorTemplates;
  Items := nil;
  for I := 0 to High(FTemplates) + 1 do
  begin
    It := Default(TActionItem);
    if I <= High(FTemplates) then
      It.Text := FTemplates[I].Title
    else
      It.Text := 'Something else (set it up yourself)';
    It.Enabled := True;
    It.OnClick := TemplateClick;
    Tag := TComponent.Create(Self);
    Tag.Tag := I;
    It.Sender := Tag;
    Items := Items + [It];
  end;
  Pt := btnAdd.LocalToAbsolute(TPointF.Create(0, btnAdd.Height));
  ShowActionMenu(FForm, Items, Pt);
end;

procedure TSensorPage.TemplateClick(Sender: TObject);
var
  I: Integer;
  Root: TJSONObject;
  Ids: TArray<Integer>;
  Name: string;
  D: TSensorDef;
begin
  I := TComponent(Sender).Tag;
  ApplyFields;
  if I <= High(FTemplates) then
  begin
    Root := ParseJsonObject(FTemplates[I].Json, FTemplates[I].Title);
    try
      Name := ImportSensorPackage(Root, FWork, FPids, Ids);
    finally
      Root.Free;
    end;
    if Length(Ids) > 0 then
      FPidsChanged := True;
  end
  else
  begin
    D := TSensorDef.Create;
    D.Name := FWork.FreeName('Sensor');
    D.Protocol := spText;
    D.Baud := SensorProtocolBaud[spText];
    FWork.Add(D);
    Name := D.Name;
  end;
  FChanged := True;
  FCurrent := FWork.IndexOf(Name);
  FillList;
  ShowSensor(FCurrent);
  if (FWork[FCurrent].Port = '') and not IsMobile then
    cbPort.SetFocus; // (a phone would open its keyboard)
end;

procedure TSensorPage.ImportFile(const FileName: string);
var
  Root: TJSONObject;
  Ids: TArray<Integer>;
  Name: string;
begin
  try
    Root := ReadJsonObject(FileName);
    try
      Name := ImportSensorPackage(Root, FWork, FPids, Ids);
    finally
      Root.Free;
    end;
  except
    on E: Exception do
    begin
      ShowError('Could not import the sensor: ' + E.Message);
      Exit;
    end;
  end;
  FChanged := True;
  if Length(Ids) > 0 then
    FPidsChanged := True;
  FCurrent := FWork.IndexOf(Name);
  FillList;
  ShowSensor(FCurrent);
  ShowInfo(Format('Added the sensor "%s" with %d PID(s). Choose its port, then Save.', [Name, Length(Ids)]));
end;

procedure TSensorPage.ImportClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  ApplyFields;
  if CanShareFiles then
  begin
    OpenFileCopy('*/*',
      procedure(const FileName, Error: string)
      begin
        if Error <> '' then
          ShowError('Could not read the file: ' + Error)
        else
          ImportFile(FileName);
      end);
    Exit;
  end;
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Title := 'Import a sensor';
    if DirectoryExists(SensorExamplesDir) then
      Dlg.InitialDir := SensorExamplesDir; // the examples the setup installed
    Dlg.Filter := 'UVScan sensors (*' + SensorFileExt + ')|*' + SensorFileExt + '|All files (*.*)|*.*';
    if Dlg.Execute then
      ImportFile(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

procedure TSensorPage.ShareClick(Sender: TObject);
var
  D: TSensorDef;
  Root: TJSONObject;
  Name, FileName: string;
  Dlg: TSaveDialog;
begin
  ApplyFields;
  D := CurrentDef;
  if D = nil then
    Exit;
  Name := D.Name;
  for var C in '\/:*?"<>|' do
    Name := StringReplace(Name, C, ' ', [rfReplaceAll]);
  Root := SensorPackage(D, SensorPids(D.Name));
  try
    if CanShareFiles then
    begin
      FileName := TPath.Combine(ShareFolder, Trim(Name) + SensorFileExt);
      WriteJsonFile(FileName, Root);
      ShareFile(FileName, 'application/json', 'UVScan sensor: ' + D.Name,
        'A sensor for UVScan. To add it: More > Sensors > Import.');
      Exit;
    end;
    Dlg := TSaveDialog.Create(nil);
    try
      Dlg.Title := 'Export the sensor';
      Dlg.FileName := Trim(Name) + SensorFileExt;
      Dlg.DefaultExt := Copy(SensorFileExt, 2, MaxInt);
      Dlg.Filter := 'UVScan sensors (*' + SensorFileExt + ')|*' + SensorFileExt;
      Dlg.Options := Dlg.Options + [TOpenOption.ofOverwritePrompt];
      if Dlg.Execute then
      begin
        WriteJsonFile(Dlg.FileName, Root);
        ShowInfo('Saved ' + Dlg.FileName + '. Whoever gets it adds it with More > Sensors > Import.');
      end;
    finally
      Dlg.Free;
    end;
  finally
    Root.Free;
  end;
end;

procedure TSensorPage.DeleteClick(Sender: TObject);
var
  D: TSensorDef;
  Pids: TArray<TPidDef>;
begin
  D := CurrentDef;
  if D = nil then
    Exit;
  Pids := SensorPids(D.Name);
  Confirm(Format('Delete the sensor "%s"%s?', [D.Name,
    IfThen(Length(Pids) > 0, Format(' and its %d PID(s)', [Length(Pids)]))]),
    procedure
    var
      P: TPidDef;
    begin
      StopTest;
      for P in SensorPids(FWork[FCurrent].Name) do
      begin
        FPids.Delete(FPids.IndexOf(P));
        FPidsChanged := True;
      end;
      FWork.Delete(FCurrent);
      FChanged := True;
      FCurrent := Min(FCurrent, FWork.Count - 1);
      FillList;
      ShowSensor(FCurrent);
    end);
end;

{ Test }

procedure TSensorPage.TestClick(Sender: TObject);
begin
  if FReader <> nil then
  begin
    StopTest;
    lblStatus.Text := 'Test stopped.';
    Relayout;
  end
  else
  begin
    ApplyFields;
    StartTest;
  end;
end;

procedure TSensorPage.StartTest;
begin
  StopTest;
  if CurrentDef = nil then
    Exit;
  FReader := TSensorReader.Create(CurrentDef);
  btnTest.Text := 'Stop test';
  FTimer.Enabled := True;
  UpdateTestButton;
  TimerTick(nil);
end;

procedure TSensorPage.StopTest;
begin
  if FTimer <> nil then
    FTimer.Enabled := False;
  FreeAndNil(FReader);
  if btnTest <> nil then
  begin
    btnTest.Text := 'Start test';
    UpdateTestButton;
    UpdatePids; // no live values now
  end;
end;

procedure TSensorPage.TimerTick(Sender: TObject);
var
  F: TSensorField;
  Fields: TArray<TSensorField>;
  Same: Boolean;
  I: Integer;
  Keep: string;
  Item: TListBoxItem;
  Last, S: string;
begin
  if FReader = nil then
    Exit;
  S := FReader.Status;
  if FReader.Packets > 0 then
    S := S + Format(' (%d %s)', [FReader.Packets, IfThen(FReader.Def.Protocol = spText, 'lines', 'packets')]);
  lblStatus.Text := S;
  Last := FReader.LastData;
  if (FReader.Def.Protocol = spPacket) and (Last <> '') then
  begin
    // each byte with its number, for the layout
    var Bytes := Last.Split([' ']);
    Last := '';
    for I := 0 to High(Bytes) do
      Last := Last + IfThen(I > 0, '  ') + Format('%d:%s', [I, Bytes[I]]);
  end;
  if Length(Last) > 240 then
    Last := Copy(Last, 1, 240) + '...';
  lblLast.Text := IfThen(Last <> '', 'Last: ' + Last, '');
  Keep := '';
  if (lbFields.ItemIndex >= 0) and (lbFields.Selected <> nil) then
    Keep := lbFields.Selected.TagString;
  Fields := FReader.Fields;
  // The same fields as shown: their values only. A rebuild four times a
  // second could lose a tap (the item gone between touch and release).
  Same := lbFields.Count = Length(Fields);
  for I := 0 to High(Fields) do
    Same := Same and (lbFields.ListItems[I].TagString = Fields[I].Name);
  if not Same then
  begin
    lbFields.BeginUpdate;
    try
      lbFields.Clear;
      for F in Fields do
      begin
        Item := TListBoxItem.Create(lbFields);
        Item.TagString := F.Name;
        Item.Height := 36;
        lbFields.AddObject(Item);
        if F.Name = Keep then
          Item.IsSelected := True;
      end;
    finally
      lbFields.EndUpdate;
    end;
  end;
  for I := 0 to High(Fields) do
  begin
    F := Fields[I];
    if IsNan(F.Value) then
      S := F.Name + '   --'
    else
      S := F.Name + '   ' + FormatFloat('0.###', F.Value, TFormatSettings.Invariant);
    if F.AgeMs > SensorMaxAgeMs then
      S := S + Format('   (%.0f s ago)', [F.AgeMs / 1000]);
    if lbFields.ListItems[I].Text <> S then
      lbFields.ListItems[I].Text := S;
  end;
  UpdatePids; // their live values
end;

procedure TSensorPage.AddPidClick(Sender: TObject);
begin
  if (CurrentDef = nil) or (lbFields.Selected = nil) then
  begin
    ShowInfo('Start the test, then pick one of the values the sensor sends.');
    Exit;
  end;
  EditPid(nil, pkSensor, lbFields.Selected.TagString);
end;

procedure TSensorPage.PidAddClick(Sender: TObject);
var
  Field: string;
begin
  if CurrentDef = nil then
    Exit;
  Field := '';
  if lbFields.Selected <> nil then
    Field := lbFields.Selected.TagString;
  EditPid(nil, pkSensor, Field);
end;

procedure TSensorPage.PidCalcClick(Sender: TObject);
begin
  if CurrentDef <> nil then
    EditPid(nil, pkCalculated, '');
end;

procedure TSensorPage.PidEditClick(Sender: TObject);
var
  P: TPidDef;
begin
  P := SelectedPid;
  if P = nil then
  begin
    if Length(FPidRows) > 0 then
      ShowInfo('Pick one of its PIDs first.');
    Exit;
  end;
  EditPid(P, P.Kind, P.SensorField);
end;

procedure TSensorPage.PidDeleteClick(Sender: TObject);
var
  P: TPidDef;
begin
  P := SelectedPid;
  if P = nil then
    Exit;
  Confirm(Format('Delete the PID "%s"?', [P.DisplayName]),
    procedure
    begin
      FPids.Delete(FPids.IndexOf(P));
      FPidsChanged := True;
      lbPidList.Clear; // rebuilt
      UpdatePids;
    end);
end;

{ The PID dialog }

procedure TSensorPage.EditPid(P: TPidDef; Kind: TPidKind; const Field: string);
var
  F: TForm;
  Dlg: TSensorPidDialog;
begin
  F := TForm.CreateNew(nil);
  Dlg := TSensorPidDialog.Create(F);
  Dlg.FPage := Self;
  Dlg.FForm := F;
  Dlg.FPid := P;
  Dlg.FKind := Kind;
  Dlg.Build(Field);
  ShowDialog(F,
    procedure(R: TModalResult)
    begin
      Dlg.FTimer.Enabled := False;
      if R = mrOk then
      begin
        lbPidList.Clear; // rebuilt with the change
        UpdatePids;
      end;
    end);
end;

procedure TSensorPidDialog.AddRow(const Caption: string; C: TControl);
var
  L: TLabel;
begin
  L := TLabel.Create(FForm);
  L.Parent := FBox;
  L.Align := TAlignLayout.Top;
  L.Margins.Top := 10;
  L.Height := 22;
  L.Position.Y := FY;
  L.Text := Caption;
  FY := FY + 1000;
  C.Parent := FBox;
  C.Align := TAlignLayout.Top;
  C.Margins.Top := 2;
  C.Height := IfThen(IsMobile, 40, 32);
  C.Position.Y := FY;
  FY := FY + 1000;
end;

function TSensorPidDialog.AddNote: TLabel;
begin
  Result := TLabel.Create(FForm);
  Result.Parent := FBox;
  Result.Align := TAlignLayout.Top;
  Result.Margins.Top := 4;
  Result.WordWrap := True;
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.FontColor];
  Result.TextSettings.FontColor := Palette.Muted;
  Result.Position.Y := FY;
  FY := FY + 1000;
end;

procedure TSensorPidDialog.Relayout;
var
  W: Single;
begin
  W := FBox.Width - FBox.Padding.Left - FBox.Padding.Right - 4;
  if W < 100 then
    Exit;
  for var L in [lblHelp, lblResult] do
    if L <> nil then
      L.Height := Max(20, WrappedTextHeight(L, W) + 4);
end;

procedure TSensorPidDialog.BoxResized(Sender: TObject);
begin
  Relayout;
end;

procedure TSensorPidDialog.Build(const Field: string);
var
  Bar: TLayout;
  B, Ok: TButton;
  D: TSensorDef;
  Title, Formula, Units, F: string;
begin
  D := FPage.CurrentDef;
  if FPid <> nil then
    FForm.Caption := 'PID: ' + FPid.DisplayName
  else if FKind = pkCalculated then
    FForm.Caption := 'Add a calculated PID'
  else
    FForm.Caption := 'Add a PID';
  FForm.Position := TFormPosition.MainFormCenter;
  FForm.ClientWidth := 500;
  FForm.ClientHeight := 620;
  Bar := TLayout.Create(FForm);
  Bar.Parent := FForm;
  Bar.Align := TAlignLayout.Bottom;
  Bar.Height := 52;
  B := TButton.Create(FForm);
  B.Parent := Bar;
  B.Align := TAlignLayout.Right;
  B.Text := 'Cancel';
  B.Cancel := True;
  B.ModalResult := mrCancel;
  Ok := TButton.Create(FForm);
  Ok.Parent := Bar;
  Ok.Align := TAlignLayout.Right;
  Ok.Text := 'OK';
  Ok.OnClick := OkClick;
  FBox := TVertScrollBox.Create(FForm);
  FBox.Parent := FForm;
  FBox.Align := TAlignLayout.Client;
  FBox.Padding.Rect := TRectF.Create(16, 4, 16, 12);
  FBox.OnResized := BoxResized;
  FY := 0;

  FLoading := True;
  try
    edtName := TEdit.Create(FForm);
    edtName.OnChangeTracking := NameTyping;
    AddRow('Name', edtName);
    edtShort := TEdit.Create(FForm);
    edtShort.TextPrompt := 'optional: for the grid and gauges';
    AddRow('Short name', edtShort);
    if FKind = pkSensor then
    begin
      cbField := TComboEdit.Create(FForm);
      for F in FPage.TestFields do
        cbField.Items.Add(F);
      cbField.TextPrompt := 'afr1, egt, 1... (the test lists them)';
      cbField.OnChange := Changed;
      cbField.OnChangeTracking := Changed;
      AddRow('The value it sends (field)', cbField);
    end;
    edtFormula := TEdit.Create(FForm);
    edtFormula.OnChangeTracking := Changed;
    AddRow('Formula', edtFormula);
    lblHelp := AddNote;
    if FKind = pkSensor then
      lblHelp.Text := 'N0 is the value it sends; empty shows it as it is. For example N0 * 9 / 5 + 32 ' +
        'turns degrees C into F, N0 / 100 undoes a value sent x 100.'
    else
      lblHelp.Text := 'Other PIDs by their name in formulas, for example %WBAFR% - 14.7, or ' +
        '(%EGT1% + %EGT2%) / 2 for the average of two.';
    if FKind = pkSensor then
    begin
      edtTry := TEdit.Create(FForm);
      edtTry.TextPrompt := 'a number, when the test is not running';
      edtTry.OnChangeTracking := Changed;
      AddRow('Try it with N0 =', edtTry);
    end;
    lblResult := AddNote;
    lblResult.StyledSettings := lblResult.StyledSettings - [TStyledSetting.Style];
    lblResult.TextSettings.Font.Style := [TFontStyle.fsBold];
    cbUnits := TComboEdit.Create(FForm);
    for F in ['AFR', 'lambda', #$00B0'C', #$00B0'F', 'psi', 'kPa', 'bar', 'inHg', 'V', '%', 'RPM', 'MPH', 'ms'] do
      cbUnits.Items.Add(F);
    cbUnits.OnChangeTracking := Changed;
    cbUnits.OnChange := Changed;
    AddRow('Units', cbUnits);
    edtMci := TEdit.Create(FForm);
    edtMci.CharCase := TEditCharCase.ecUpperCase;
    edtMci.TextPrompt := 'e.g. WBAFR: other formulas use it as %WBAFR%';
    edtMci.OnChangeTracking := MciTyping;
    AddRow('Name in formulas (MCI)', edtMci);

    if FPid <> nil then
    begin
      edtName.Text := FPid.LongName;
      edtShort.Text := FPid.ShortName;
      edtFormula.Text := FPid.FormulaText;
      cbUnits.Text := FPid.Units;
      edtMci.Text := FPid.Mci;
      FMciTyped := True;
      if cbField <> nil then
        cbField.Text := FPid.SensorField;
    end
    else if (FKind = pkSensor) and (Field <> '') then
    begin
      // what the protocol knows about the field
      cbField.Text := Field;
      if not SuggestSensorPid(D.Protocol, Field, Title, Formula, Units) or (Title = '') then
        Title := Field;
      // a second module or wideband of the kind: its number too
      if (D.Protocol in [spMts, spPlx]) and CharInSet(Field[High(Field)], ['2'..'9']) and
        not Title.EndsWith(Field[High(Field)]) then
        Title := Title + ' ' + Field[High(Field)];
      edtName.Text := D.Name + ' ' + Title;
      edtFormula.Text := Formula;
      cbUnits.Text := Units;
      edtMci.Text := FPage.FreeMci(edtName.Text);
    end;
  finally
    FLoading := False;
  end;
  FTimer := TTimer.Create(FForm);
  FTimer.Interval := 500;
  FTimer.OnTimer := Changed; // live values
  FTimer.Enabled := True;
  MakePage(FForm, FForm.Caption, Ok, 'OK');
  if not IsMobile then
    FForm.ActiveControl := edtName; // (a phone would open its keyboard over the page)
  Changed(nil);
end;

procedure TSensorPidDialog.NameTyping(Sender: TObject);
begin
  if FLoading or FMciTyped or (FPid <> nil) then
    Exit;
  FLoading := True;
  try
    edtMci.Text := FPage.FreeMci(edtName.Text);
  finally
    FLoading := False;
  end;
end;

procedure TSensorPidDialog.MciTyping(Sender: TObject);
begin
  if not FLoading then
    FMciTyped := True;
end;

{ What the PID shows now (live, or for the value typed in), or what is wrong. }
procedure TSensorPidDialog.Changed(Sender: TObject);
var
  F: TFormula;
  Raw, V: Double;
  Vars, Missing: TArray<string>;
  Values: TArray<Double>;
  I: Integer;
  Field, Msg, Units: string;
  Bad: Boolean;
begin
  if (lblResult = nil) or FLoading then
    Exit;
  Bad := False;
  Units := Trim(cbUnits.Text);
  try
    F := TFormula.Create(Trim(edtFormula.Text));
  except
    on E: EFormulaError do
    begin
      F := nil;
      Bad := True;
      Msg := 'Formula: ' + E.Message;
    end;
  end;
  if F <> nil then
    try
      if FKind = pkSensor then
      begin
        Field := LowerCase(Trim(cbField.Text));
        Raw := FPage.LiveRaw(Field);
        if not IsNan(Raw) then
          Msg := Format('Now: %s = %s', [Field, Num(Raw)])
        else if TryStrToFloat(Trim(edtTry.Text), Raw, TFormatSettings.Invariant) then
          Msg := 'With N0 = ' + Num(Raw)
        else
          Raw := NaN;
        if Field = '' then
          Msg := 'Choose the value it sends.'
        else if IsNan(Raw) then
          Msg := 'Start the test on the Sensors page to see it with live values, or try a number above.'
        else
        begin
          if F.IsEmpty then
            V := Raw
          else
            V := F.Evaluate([Raw], []);
          Msg := Msg + '   ' + #$2192 + '   ' + Num(V) + IfThen(Units <> '', ' ' + Units);
        end;
      end
      else if F.IsEmpty then
        Msg := 'Type a formula over other PIDs.'
      else
      begin
        Vars := F.Variables;
        Missing := nil;
        SetLength(Values, Length(Vars));
        for I := 0 to High(Vars) do
        begin
          if FPage.FPids.FindByMci(Vars[I]) = nil then
            Missing := Missing + ['%' + Vars[I] + '%'];
          Values[I] := FPage.LiveByMci(Vars[I]);
        end;
        V := F.Evaluate([], Values);
        if Missing <> nil then
        begin
          Bad := True;
          Msg := 'No PID has the name ' + string.Join(', ', Missing);
        end
        else if IsNan(V) then
          Msg := 'Uses %' + string.Join('%, %', Vars) + '%. Start the test to see it with live values.'
        else
          Msg := 'Now: ' + Num(V) + IfThen(Units <> '', ' ' + Units);
      end;
    finally
      F.Free;
    end;
  lblResult.StyledSettings := lblResult.StyledSettings - [TStyledSetting.FontColor];
  if Bad then
    lblResult.TextSettings.FontColor := Palette.Bad
  else
    lblResult.TextSettings.FontColor := Palette.Text;
  lblResult.Text := Msg;
  Relayout;
end;

procedure TSensorPidDialog.OkClick(Sender: TObject);
var
  Name, Mci, OldMci, Field: string;
  P, Q: TPidDef;
  New: Boolean;
  Renamed: TDictionary<string, string>;
  I: Integer;
begin
  Name := Trim(edtName.Text);
  if Name = '' then
  begin
    ShowWarning('Give the PID a name');
    Exit;
  end;
  Field := '';
  if FKind = pkSensor then
  begin
    Field := LowerCase(Trim(cbField.Text));
    if Field = '' then
    begin
      ShowWarning('Choose the value it sends (the field): the test lists them');
      Exit;
    end;
  end
  else if Trim(edtFormula.Text) = '' then
  begin
    ShowWarning('A calculated PID needs a formula over other PIDs, e.g. %WBAFR% - 14.7');
    Exit;
  end;
  try
    TFormula.Create(Trim(edtFormula.Text)).Free;
  except
    on E: EFormulaError do
    begin
      ShowWarning('Formula: ' + E.Message);
      Exit;
    end;
  end;
  Mci := UpperCase(StringReplace(StringReplace(Trim(edtMci.Text), '%', '', [rfReplaceAll]), ' ', '', [rfReplaceAll]));
  if Mci <> '' then
  begin
    Q := FPage.FPids.FindByMci(Mci);
    if (Q <> nil) and (Q <> FPid) then
    begin
      ShowWarning(Format('"%s" already has the name %%%s%% in formulas: choose another', [Q.DisplayName, Mci]));
      Exit;
    end;
  end;
  New := FPid = nil;
  if New then
  begin
    P := TPidDef.Create;
    P.Id := FPage.FPids.NextFreeId;
    P.Kind := FKind;
    if FKind = pkSensor then
    begin
      P.Category := pcSensors;
      P.PidCode := SensorPidCode;
      P.SensorName := FPage.CurrentDef.Name;
    end
    else
    begin
      P.Category := pcCalculated;
      P.PidCode := 'FPID';
    end;
  end
  else
    P := FPid;
  OldMci := P.Mci;
  P.LongName := Name;
  P.ShortName := Trim(edtShort.Text);
  P.FormulaText := Trim(edtFormula.Text);
  P.Units := Trim(cbUnits.Text);
  P.Mci := Mci;
  if FKind = pkSensor then
    P.SensorField := Field;
  if New then
    FPage.FPids.Add(P);
  // formulas that used its old name follow it
  if (OldMci <> '') and (Mci <> '') and not SameText(OldMci, Mci) then
  begin
    Renamed := TDictionary<string, string>.Create;
    try
      Renamed.Add(UpperCase(OldMci), Mci);
      for I := 0 to FPage.FPids.Count - 1 do
        if Pos('%', FPage.FPids[I].FormulaText) > 0 then
          FPage.FPids[I].FormulaText := RenameMcis(FPage.FPids[I].FormulaText, Renamed);
    finally
      Renamed.Free;
    end;
  end;
  FPage.FPidsChanged := True;
  FForm.ModalResult := mrOk;
end;

{ An MCI for a new PID, so formulas can use it as %NAME%: its name in
  capitals, letters and digits only, with a number when that is taken. }
function TSensorPage.FreeMci(const Name: string): string;
var
  Base: string;
  C: Char;
  N: Integer;
begin
  Base := '';
  for C in UpperCase(Name) do
    if CharInSet(C, ['A'..'Z', '0'..'9', '_']) then
      Base := Base + C;
  if Base = '' then
    Base := 'SENSOR';
  Result := Base;
  N := 1;
  while FPids.FindByMci(Result) <> nil do
  begin
    Inc(N);
    Result := Base + IntToStr(N);
  end;
end;

{ Save }

function TSensorPage.CheckNames: Boolean;
var
  I, J: Integer;
begin
  for I := 0 to FWork.Count - 1 do
  begin
    if Trim(FWork[I].Name) = '' then
    begin
      ShowWarning('Every sensor needs a name');
      Exit(False);
    end;
    if FWork[I].Protocol = spPacket then
    begin
      var L: TPacketLayout;
      var Err: string;
      if not ParsePacketLayout(FWork[I].Layout, L, Err) then
      begin
        ShowWarning(Format('The packet layout of "%s": %s', [FWork[I].Name, Err]));
        Exit(False);
      end;
    end;
    for J := 0 to I - 1 do
      if SameText(FWork[I].Name, FWork[J].Name) then
      begin
        ShowWarning(Format('There are two sensors called "%s"', [FWork[I].Name]));
        Exit(False);
      end;
  end;
  Result := True;
end;

procedure TSensorPage.SaveClick(Sender: TObject);
var
  Problems: TArray<TPidProblem>;
begin
  ApplyFields;
  NameChanged(nil);
  if not CheckNames then
    Exit;
  StopTest;
  try
    if FPidsChanged then
    begin
      Problems := FPids.Validate;
      if Length(Problems) > 0 then
      begin
        ShowWarning('The PID definitions have a problem: ' + Problems[0].Text);
        Exit;
      end;
      FPids.SaveToJsonFile(FPidsFile);
    end;
    FWork.SaveToFile(FSensorsFile);
  except
    on E: Exception do
    begin
      ShowError('Could not save: ' + E.Message);
      Exit;
    end;
  end;
  FSaved := True;
  FForm.ModalResult := mrOk;
end;

procedure EditSensors(Sensors: TSensorCatalog; Catalog: TPidCatalog; const SensorsFileName, PidsFileName: string;
  const OnDone: TProc<Boolean>);
var
  F: TForm;
  Page: TSensorPage;
begin
  F := TForm.CreateNew(nil);
  F.Caption := 'Sensors';
  F.Position := TFormPosition.MainFormCenter;
  F.ClientWidth := 640;
  F.ClientHeight := 720;
  Page := TSensorPage.Create(F);
  Page.FForm := F;
  Page.FWork := TSensorCatalog.Create;
  Page.FWork.Assign(Sensors);
  Page.FPids := TPidCatalog.Create;
  Page.FPids.Assign(Catalog);
  Page.FSensorsFile := SensorsFileName;
  Page.FPidsFile := PidsFileName;
  Page.FCurrent := IfThen(Sensors.Count > 0, 0, -1);
  Page.Build;
  Page.FillList;
  Page.ShowSensor(Page.FCurrent);
  FitToScreen(F);
  ShowDialog(F,
    procedure(R: TModalResult)
    begin
      Page.StopTest;
      if Assigned(OnDone) then
        OnDone(Page.FSaved);
    end);
end;

end.
