unit UVScan.SensorEditor;

{ The Sensors page: the sensors UVScan reads beside the vehicle (see
  UVScan.Sensors). A sensor comes from a template or a shared sensor file
  (Import), or is made from nothing; it gets its port here, and Test shows
  every field it sends as it comes, with a PID for any of them a tap away.
  Share writes the sensor and its PIDs to a file for someone else. }

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
    lblPids: TLabel;
    pnlTest: TLayout;
    btnTest: TButton;
    lblStatus, lblLast: TLabel;
    lbFields: TListBox;
    btnAddPid: TButton;
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

destructor TSensorPage.Destroy;
begin
  StopTest;
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

  Caption('Sensor');
  edtName := TEdit.Create(FForm);
  edtName.OnChange := NameChanged;
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
  lblPids := Note;

  Caption('Test');
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
  // every field without scrolling inside the page's own scrolling
  lbFields.Height := Max(1, lbFields.Count) * 36 + 4;
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
  Relayout;
end;

procedure TSensorPage.UpdatePids;
var
  Names: string;
  P: TPidDef;
  D: TSensorDef;
begin
  D := CurrentDef;
  if D = nil then
    Exit;
  Names := '';
  for P in PidsOf(D.Name) do
    Names := Names + IfThen(Names <> '', ', ') + Format('%s (%s)', [P.DisplayName, P.SensorField]);
  if Names = '' then
    lblPids.Text := 'No PIDs read it yet: start the test, pick a field and add a PID for it.'
  else
    lblPids.Text := 'Its PIDs: ' + Names + '. Formulas and units are in Edit PIDs.';
  Relayout;
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
  if FReader <> nil then
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
  Root := SensorPackage(D, PidsOf(D.Name));
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
  Pids := PidsOf(D.Name);
  Confirm(Format('Delete the sensor "%s"%s?', [D.Name,
    IfThen(Length(Pids) > 0, Format(' and its %d PID(s)', [Length(Pids)]))]),
    procedure
    var
      P: TPidDef;
    begin
      StopTest;
      for P in PidsOf(FWork[FCurrent].Name) do
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
  TimerTick(nil);
end;

procedure TSensorPage.StopTest;
begin
  if FTimer <> nil then
    FTimer.Enabled := False;
  FreeAndNil(FReader);
  if btnTest <> nil then
    btnTest.Text := 'Start test';
end;

procedure TSensorPage.TimerTick(Sender: TObject);
var
  F: TSensorField;
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
  if Length(Last) > 160 then
    Last := Copy(Last, 1, 160) + '...';
  lblLast.Text := IfThen(Last <> '', 'Last: ' + Last, '');
  Keep := '';
  if (lbFields.ItemIndex >= 0) and (lbFields.Selected <> nil) then
    Keep := lbFields.Selected.TagString;
  lbFields.BeginUpdate;
  try
    lbFields.Clear;
    for F in FReader.Fields do
    begin
      Item := TListBoxItem.Create(lbFields);
      Item.TagString := F.Name;
      Item.Height := 36;
      if IsNan(F.Value) then
        Item.Text := F.Name + '   --'
      else
        Item.Text := F.Name + '   ' + FormatFloat('0.###', F.Value, TFormatSettings.Invariant);
      if F.AgeMs > SensorMaxAgeMs then
        Item.Text := Item.Text + Format('   (%.0f s ago)', [F.AgeMs / 1000]);
      lbFields.AddObject(Item);
      if F.Name = Keep then
        Item.IsSelected := True;
    end;
  finally
    lbFields.EndUpdate;
  end;
  Relayout;
end;

procedure TSensorPage.AddPidClick(Sender: TObject);
var
  Field, Suggest, Title, Formula, Units: string;
  D: TSensorDef;
begin
  D := CurrentDef;
  if (D = nil) or (lbFields.Selected = nil) then
  begin
    ShowInfo('Start the test, then pick one of the fields the sensor sends.');
    Exit;
  end;
  Field := lbFields.Selected.TagString;
  if not SuggestSensorPid(D.Protocol, Field, Title, Formula, Units) then
    Title := Field;
  if Title = '' then
    Title := Field;
  // a second module or wideband of the kind: its number too
  if (D.Protocol in [spMts, spPlx]) and (Field.Length > 0) and CharInSet(Field[High(Field)], ['2'..'9']) and
    not Title.EndsWith(Field[High(Field)]) then
    Title := Title + ' ' + Field[High(Field)];
  Suggest := D.Name + ' ' + Title;
  AskText('Add a PID', Format('A name for %s''s %s', [D.Name, Field]), Suggest,
    procedure(Name: string)
    var
      P: TPidDef;
    begin
      if Name = '' then
        Exit;
      P := TPidDef.Create;
      P.Id := FPids.NextFreeId;
      P.LongName := Name;
      P.Kind := pkSensor;
      P.Category := pcSensors;
      P.SensorName := D.Name;
      P.SensorField := Field;
      P.PidCode := SensorPidCode;
      P.Mci := FreeMci(Name);
      P.Units := Units;
      P.FormulaText := Formula;
      FPids.Add(P);
      FPidsChanged := True;
      UpdatePids;
      ShowInfo(Format('Added the PID "%s" (in formulas: %%%s%%). After Save, tick it in the PID list ' +
        'to scan it; its formula and units are in Edit PIDs.', [Name, P.Mci]));
    end);
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
