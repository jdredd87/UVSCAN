unit UVScan.GaugeEditor;

{ Add or edit one dashboard gauge, as a page (full screen on a phone): a live
  preview, the PID (picked from a searchable list), dial / bar / big number,
  size, scale, and the PID's alert levels - the same levels the live grid
  uses, edited with the Display & alerts editor. }

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Edit,
  FMX.Layouts, FMX.Objects, FMX.Controls.Presentation,
  UVScan.Pids, UVScan.Display, UVScan.Gauge, UVScan.UI.DataGrid;

type
  TGaugeEditorForm = class(TForm)
    pnlBar: TRectangle;
    btnCancel: TSpeedButton;
    lblTitle: TLabel;
    btnOK: TButton;
    sbBody: TVertScrollBox;
    pnlPreview: TRectangle;
    rowPreview: TLayout;
    lblPreview: TLabel;
    tbPreview: TTrackBar;
    lblPidCap: TLabel;
    pnlPid: TRectangle;
    lblPidName: TLabel;
    lblStyleCap: TLabel;
    lyStyle: TLayout;
    lblSizeCap: TLabel;
    lySize: TLayout;
    lblScaleCap: TLabel;
    rowScale: TLayout;
    lblFrom: TLabel;
    edtMin: TEdit;
    lblTo: TLabel;
    edtMax: TEdit;
    btnSuggest: TButton;
    lblAlertCap: TLabel;
    lblAlerts: TLabel;
    btnAlerts: TButton;
    pnlPicker: TRectangle;
    pnlPickerBar: TRectangle;
    btnPickerBack: TSpeedButton;
    edtPidSearch: TEdit;
    lyPickerList: TLayout;
    tmrFlash: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure SettingChange(Sender: TObject);
    procedure pnlPidClick(Sender: TObject);
    procedure btnSuggestClick(Sender: TObject);
    procedure btnAlertsClick(Sender: TObject);
    procedure btnPickerBackClick(Sender: TObject);
    procedure edtPidSearchChange(Sender: TObject);
    procedure tmrFlashTimer(Sender: TObject);
  private
    FCatalog: TPidCatalog;
    FSettings: TDisplaySettings;
    FGaugeView: TGaugeView;
    FPidId: Integer;
    FStyle: TGaugeStyle;
    FSize: TGaugeSize;
    FLoading: Boolean;
    FFlashOn: Boolean;
    FStyleChips: TArray<TRectangle>;
    FSizeChips: TArray<TRectangle>;
    FPickGrid: TDataGrid;
    FPickRows: TArray<Integer>;      // PID id, or -(category + 1) for a group row
    FOnAlertsChanged: TProc;
    function SelectedPid: TPidDef;
    function ReadGauge(out G: TGauge): Boolean;
    procedure UpdatePreview;
    procedure UpdatePid;
    procedure UpdateAlerts;
    procedure UpdateChips;
    procedure FitLayout;
    procedure ApplyPalette;
    function AddChips(Parent: TLayout; const Captions: array of string; OnClick: TNotifyEvent): TArray<TRectangle>;
    procedure LayoutChips(const Chips: TArray<TRectangle>; Parent: TLayout);
    procedure StyleChipClick(Sender: TObject);
    procedure SizeChipClick(Sender: TObject);
    procedure SuggestForPid;
    // PID picker
    procedure ShowPicker(Show: Boolean);
    procedure FillPicker;
    procedure PickGetText(Sender: TObject; Col, Row: Integer; var Text: string);
    procedure PickIsGroup(Sender: TObject; Row: Integer; var IsGroup: Boolean);
    procedure PickSelect(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
  public
    { G = gauge to edit (or the PID to start from). OnDone (may be nil) runs
      when the page closes: True and the edited gauge on Save. OnAlertsChanged
      (may be nil) runs as soon as the PID's alert levels are changed - they
      are shared with the live grid, so they count even if the gauge is not
      saved. }
    class procedure Execute(const G: TGauge; Catalog: TPidCatalog; Settings: TDisplaySettings;
      const Caption: string; const OnDone: TProc<Boolean, TGauge>; const OnAlertsChanged: TProc = nil);
  end;

{ A starting scale for a PID: from its formula's output range (raw 00 / FF),
  or a sensible fixed range for a few units. }
procedure SuggestScale(P: TPidDef; Settings: TDisplaySettings; out MinValue, MaxValue: Double);

{ Feeds a gauge one reading in the colours the PID's display levels choose.
  Shared by the dashboard and the preview so both look the same. }
procedure ShowGaugeReading(Gauge: TGaugeView; const Style: TResolvedStyle; FlashOn: Boolean;
  const Value: Double; const Text, Note: string);

implementation

{$R *.fmx}

uses
  System.StrUtils, UVScan.UI.Common, UVScan.UI.Theme, UVScan.DisplayEditor;

const
  StyleChipCaptions: array[TGaugeStyle] of string = ('Dial', 'Bar', 'Number');
  SizeChipCaptions: array[TGaugeSize] of string = ('Small', 'Medium', 'Large');
  ChipGap = 8;

procedure SuggestScale(P: TPidDef; Settings: TDisplaySettings; out MinValue, MaxValue: Double);
var
  U: string;
  A, B, Step: Double;
  Zero, Full: array[0..3] of Double;
  I: Integer;
  D: TPidDisplay;
begin
  MinValue := 0;
  MaxValue := 100;
  if P = nil then
    Exit;
  U := LowerCase(Trim(P.Units));
  if U = 'rpm' then
  begin
    MaxValue := 7000;
    Exit;
  end;
  if (U = 'v') or (U = 'volts') then
  begin
    MaxValue := 18;
    Exit;
  end;
  if U = '%' then
  begin
    if (P.Kind = pkVehicle) and (Pos('TRIM', UpperCase(P.LongName)) > 0) then
      MinValue := -25;
    MaxValue := IfThen(MinValue < 0, 25, 100);
    Exit;
  end;
  if (P.Kind = pkVehicle) and (P.DataLength in [1, 2]) then
    try
      for I := 0 to 3 do
      begin
        Zero[I] := 0;
        Full[I] := IfThen(I < P.DataLength, 255, 0);
      end;
      A := P.Formula.Evaluate(Zero, []);
      B := P.Formula.Evaluate(Full, []);
      if not IsNan(A) and not IsNan(B) and not IsInfinite(A) and not IsInfinite(B) and not SameValue(A, B) then
      begin
        MinValue := Min(A, B);
        MaxValue := Max(A, B);
      end;
    except
      // a formula that needs other PIDs: keep 0..100
    end;
  // Levels above the formula range would never show; make room for them.
  D := Settings.Find(P.Id);
  if D <> nil then
    for I := 0 to High(D.Levels) do
      if D.Levels[I].Value > MaxValue then
        MaxValue := D.Levels[I].Value * 1.25;
  Step := NiceStep(MaxValue - MinValue, 8);
  MinValue := Floor(MinValue / Step + 1E-9) * Step;
  MaxValue := Ceil(MaxValue / Step - 1E-9) * Step;
  if MaxValue <= MinValue then
    MaxValue := MinValue + 1;
end;

procedure ShowGaugeReading(Gauge: TGaugeView; const Style: TResolvedStyle; FlashOn: Boolean;
  const Value: Double; const Text, Note: string);
var
  Card, Txt: TAlphaColor;
  N: string;
begin
  Card := NoColor;
  Txt := NoColor;
  N := Note;
  // The card takes the level's colours (blinking if the level flashes); in the
  // normal state it stays dark and the value arc shows the PID's own colour.
  if Style.Level >= 0 then
  begin
    if not Style.Flash or FlashOn then
    begin
      Card := Style.RowColor;
      Txt := Style.TextColor;
    end;
    if N = '' then
      N := Style.LevelName;
  end;
  Gauge.SetReading(Value, Text, Card, Txt, Style.NormalRowColor, N);
end;

{ TGaugeEditorForm }

class procedure TGaugeEditorForm.Execute(const G: TGauge; Catalog: TPidCatalog; Settings: TDisplaySettings;
  const Caption: string; const OnDone: TProc<Boolean, TGauge>; const OnAlertsChanged: TProc);
var
  F: TGaugeEditorForm;
begin
  F := TGaugeEditorForm.Create(Application);
  F.Caption := Caption;
  F.lblTitle.Text := Caption;
  F.FCatalog := Catalog;
  F.FSettings := Settings;
  F.FOnAlertsChanged := OnAlertsChanged;
  F.FLoading := True;
  F.FPidId := G.PidId;
  F.FStyle := G.Style;
  F.FSize := G.Size;
  F.edtMin.Text := FormatFloat('0.###', G.MinValue);
  F.edtMax.Text := FormatFloat('0.###', G.MaxValue);
  F.FLoading := False;
  F.UpdateChips;
  F.UpdatePid;
  F.UpdateAlerts;
  F.UpdatePreview;
  ShowDialog(F,
    procedure(R: TModalResult)
    var
      Got: TGauge;
    begin
      Got := G;
      if R = mrOk then
        F.ReadGauge(Got);
      if Assigned(OnDone) then
        OnDone(R = mrOk, Got);
    end);
end;

procedure TGaugeEditorForm.FormCreate(Sender: TObject);
var
  L: TLabel;
  S: TGaugeStyle;
  Z: TGaugeSize;
  Caps: array of string;
begin
  FLoading := True;
  OnKeyUp := FormKeyUp;
  btnCancel.Text := '';
  btnPickerBack.Text := '';
  AddLineIcon(btnCancel, IconBack);
  AddLineIcon(btnPickerBack, IconBack);
  AddLineIcon(pnlPid, IconChevron, 18).Align := TAlignLayout.Right;
  for L in [lblPidCap, lblStyleCap, lblSizeCap, lblScaleCap, lblAlertCap] do
  begin
    L.StyledSettings := L.StyledSettings - [TStyledSetting.Style];
    L.TextSettings.Font.Style := [TFontStyle.fsBold];
  end;
  Caps := nil;
  for S := Low(TGaugeStyle) to High(TGaugeStyle) do
    Caps := Caps + [StyleChipCaptions[S]];
  FStyleChips := AddChips(lyStyle, Caps, StyleChipClick);
  Caps := nil;
  for Z := Low(TGaugeSize) to High(TGaugeSize) do
    Caps := Caps + [SizeChipCaptions[Z]];
  FSizeChips := AddChips(lySize, Caps, SizeChipClick);

  FGaugeView := TGaugeView.Create(Self);
  FGaugeView.Parent := pnlPreview;
  FGaugeView.HitTest := False;

  FPickGrid := TDataGrid.Create(Self);
  FPickGrid.Parent := lyPickerList;
  FPickGrid.Align := TAlignLayout.Client;
  FPickGrid.ShowHeader := False;
  FPickGrid.AddColumn('PID', 200, gaLeft, True);
  FPickGrid.AddColumn('Units', 90);
  FPickGrid.SetColumnWrap(0, True);
  FPickGrid.AutoHeights := True;
  if IsMobile then
  begin
    FPickGrid.RowHeight := 44;
    FPickGrid.FontSize := 15;
  end
  else
    FPickGrid.RowHeight := 30;
  FPickGrid.OnGetText := PickGetText;
  FPickGrid.OnIsGroupRow := PickIsGroup;
  FPickGrid.OnSelect := PickSelect;

  ApplyPalette;
  FLoading := False;
end;

procedure TGaugeEditorForm.ApplyPalette;
var
  P: TPalette;
  R: TRectangle;
begin
  P := Palette;
  for R in [pnlBar, pnlPickerBar] do
  begin
    R.Fill.Color := P.Bar;
    R.Stroke.Color := P.BarLine;
  end;
  pnlPicker.Fill.Color := P.Back;
  pnlPreview.Fill.Color := P.Panel;
  pnlPid.Fill.Color := P.Bar;
  pnlPid.Stroke.Color := P.BarLine;
  lblAlerts.StyledSettings := lblAlerts.StyledSettings - [TStyledSetting.FontColor];
  lblAlerts.TextSettings.FontColor := P.Muted;
end;

{ Chips: a row of big tap targets, one of them selected. }
function TGaugeEditorForm.AddChips(Parent: TLayout; const Captions: array of string;
  OnClick: TNotifyEvent): TArray<TRectangle>;
var
  I: Integer;
  R: TRectangle;
  L: TLabel;
begin
  Result := nil;
  for I := 0 to High(Captions) do
  begin
    R := TRectangle.Create(Self);
    R.Parent := Parent;
    R.Stored := False;
    R.XRadius := 8;
    R.YRadius := 8;
    R.HitTest := True;
    R.Cursor := crHandPoint;
    R.Tag := I;
    R.OnClick := OnClick;
    L := TLabel.Create(Self);
    L.Parent := R;
    L.Stored := False;
    L.Align := TAlignLayout.Client;
    L.HitTest := False;
    L.StyledSettings := L.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Style];
    L.TextSettings.HorzAlign := TTextAlign.Center;
    L.TextSettings.WordWrap := False;
    L.Text := Captions[I];
    Result := Result + [R];
  end;
end;

procedure TGaugeEditorForm.LayoutChips(const Chips: TArray<TRectangle>; Parent: TLayout);
var
  I: Integer;
  W: Single;
begin
  if (Length(Chips) = 0) or (Parent.Width < 20) then
    Exit;
  W := (Parent.Width - ChipGap * (Length(Chips) - 1)) / Length(Chips);
  for I := 0 to High(Chips) do
    Chips[I].SetBounds(I * (W + ChipGap), 0, W, Parent.Height);
end;

procedure TGaugeEditorForm.UpdateChips;

  procedure Paint(const Chips: TArray<TRectangle>; Selected: Integer);
  var
    I: Integer;
    P: TPalette;
    L: TLabel;
  begin
    P := Palette;
    for I := 0 to High(Chips) do
    begin
      L := TLabel(Chips[I].Controls[0]);
      if I = Selected then
      begin
        Chips[I].Fill.Color := P.Accent;
        Chips[I].Stroke.Color := P.Accent;
        L.TextSettings.FontColor := ContrastColor(P.Accent);
        L.TextSettings.Font.Style := [TFontStyle.fsBold];
      end
      else
      begin
        Chips[I].Fill.Color := P.Bar;
        Chips[I].Stroke.Color := P.BarLine;
        L.TextSettings.FontColor := P.Text;
        L.TextSettings.Font.Style := [];
      end;
    end;
  end;

begin
  Paint(FStyleChips, Ord(FStyle));
  Paint(FSizeChips, Ord(FSize));
end;

procedure TGaugeEditorForm.StyleChipClick(Sender: TObject);
begin
  FStyle := TGaugeStyle(TControl(Sender).Tag);
  UpdateChips;
  UpdatePreview;
end;

procedure TGaugeEditorForm.SizeChipClick(Sender: TObject);
begin
  FSize := TGaugeSize(TControl(Sender).Tag);
  UpdateChips;
  UpdatePreview;
end;

procedure TGaugeEditorForm.FormResize(Sender: TObject);
begin
  FitLayout;
end;

{ Sizes that depend on the width: chips, the wrapped PID name and alert
  summary, and the preview (as tall as a medium gauge, or less on a small
  window). }
procedure TGaugeEditorForm.FitLayout;
begin
  if FGaugeView = nil then
    Exit;
  LayoutChips(FStyleChips, lyStyle);
  LayoutChips(FSizeChips, lySize);
  if pnlPid.Width > 50 then
    pnlPid.Height := Max(52, WrappedTextHeight(lblPidName, pnlPid.Width - 50) + 20);
  if lblAlerts.Width > 50 then
    lblAlerts.Height := WrappedTextHeight(lblAlerts, lblAlerts.Width) + 4;
  pnlPreview.Height := EnsureRange(ClientHeight * 0.36, 180, 300);
  UpdatePreview;
end;

function TGaugeEditorForm.SelectedPid: TPidDef;
begin
  if FCatalog <> nil then
    Result := FCatalog.FindById(FPidId)
  else
    Result := nil;
end;

function TGaugeEditorForm.ReadGauge(out G: TGauge): Boolean;
var
  P: TPidDef;
begin
  G := Default(TGauge);
  P := SelectedPid;
  Result := (P <> nil) and TryParseNumber(edtMin.Text, G.MinValue) and TryParseNumber(edtMax.Text, G.MaxValue) and
    (G.MaxValue > G.MinValue);
  if P <> nil then
    G.PidId := P.Id;
  G.Style := FStyle;
  G.Size := FSize;
end;

procedure TGaugeEditorForm.UpdatePid;
var
  P: TPidDef;
begin
  P := SelectedPid;
  if P = nil then
    lblPidName.Text := 'Choose a PID'
  else
    lblPidName.Text := P.LongName + IfThen(P.Units <> '', '   (' + P.Units + ')', '');
  FitLayout;
end;

procedure TGaugeEditorForm.UpdateAlerts;
var
  P: TPidDef;
  D: TPidDisplay;
  L: TDisplayLevel;
  S, Line: string;
begin
  P := SelectedPid;
  if P = nil then
    D := nil
  else
    D := FSettings.Find(P.Id);
  if (D = nil) or (Length(D.Levels) = 0) then
    S := 'None. Alert levels colour the gauge''s scale and card and can flash or sound when a value goes ' +
      'too high or too low.'
  else
  begin
    S := '';
    for L in D.Levels do
    begin
      Line := L.Name + '   ' + L.Describe;
      if L.RowColor <> NoColor then
        Line := Line + '  ' + #$00B7 + '  ' + ColorName(L.RowColor);
      if L.Flash then
        Line := Line + '  ' + #$00B7 + '  flashes';
      if L.Sound <> asNone then
        Line := Line + '  ' + #$00B7 + '  sound';
      S := S + IfThen(S <> '', sLineBreak, '') + Line;
    end;
  end;
  lblAlerts.Text := S;
  btnAlerts.Enabled := P <> nil;
  FitLayout;
end;

procedure TGaugeEditorForm.SuggestForPid;
var
  A, B: Double;
begin
  SuggestScale(SelectedPid, FSettings, A, B);
  FLoading := True;
  try
    edtMin.Text := FormatFloat('0.###', A);
    edtMax.Text := FormatFloat('0.###', B);
  finally
    FLoading := False;
  end;
  UpdatePreview;
end;

procedure TGaugeEditorForm.btnSuggestClick(Sender: TObject);
begin
  SuggestForPid;
end;

procedure TGaugeEditorForm.SettingChange(Sender: TObject);
begin
  if not FLoading then
    UpdatePreview;
end;

procedure TGaugeEditorForm.UpdatePreview;
var
  G: TGauge;
  P: TPidDef;
  Sz: TSizeF;
  V, AvailW, AvailH: Double;
  Ok: Boolean;
  C: TAlphaColor;
begin
  if (FGaugeView = nil) or (FSettings = nil) then
    Exit;
  Ok := ReadGauge(G);
  if Ok or (SelectedPid = nil) then
    C := Palette.Text
  else
    C := Palette.Bad;
  edtMin.StyledSettings := edtMin.StyledSettings - [TStyledSetting.FontColor];
  edtMax.StyledSettings := edtMax.StyledSettings - [TStyledSetting.FontColor];
  edtMin.TextSettings.FontColor := C;
  edtMax.TextSettings.FontColor := C;
  btnOK.Enabled := Ok;
  P := SelectedPid;
  if not Ok or (P = nil) then
  begin
    FGaugeView.Visible := False;
    Exit;
  end;
  Sz := TGaugeView.PreferredSize(G.Style, G.Size);
  // Fit the preview area, keeping the shape.
  AvailW := pnlPreview.Width - 16;
  AvailH := pnlPreview.Height - 16;
  if (AvailW > 20) and (AvailH > 20) and ((Sz.Width > AvailW) or (Sz.Height > AvailH)) then
  begin
    V := Min(AvailW / Sz.Width, AvailH / Sz.Height);
    Sz.Width := Sz.Width * V;
    Sz.Height := Sz.Height * V;
  end;
  FGaugeView.SetBounds(Round((pnlPreview.Width - Sz.Width) / 2), Round((pnlPreview.Height - Sz.Height) / 2),
    Sz.Width, Sz.Height);
  FGaugeView.Setup(G.Style, G.Size, P.LongName, P.Units, G.MinValue, G.MaxValue,
    FSettings.Zones(P.Id, G.MinValue, G.MaxValue));
  V := G.MinValue + (G.MaxValue - G.MinValue) * tbPreview.Value / Max(1, tbPreview.Max);
  ShowGaugeReading(FGaugeView, FSettings.Resolve(P.Id, V), FFlashOn, V, P.FormatValue(V), '');
  FGaugeView.Visible := True;
end;

procedure TGaugeEditorForm.tmrFlashTimer(Sender: TObject);
begin
  FFlashOn := not FFlashOn;
  if (FGaugeView <> nil) and FGaugeView.Visible then
    UpdatePreview;
end;

procedure TGaugeEditorForm.btnAlertsClick(Sender: TObject);
var
  P: TPidDef;
begin
  P := SelectedPid;
  if P = nil then
    Exit;
  TDisplayEditorForm.Execute(P, FSettings,
    procedure(Ok: Boolean)
    begin
      if not Ok then
        Exit;
      UpdateAlerts;
      UpdatePreview;
      if Assigned(FOnAlertsChanged) then
        FOnAlertsChanged();
    end);
end;

procedure TGaugeEditorForm.btnOKClick(Sender: TObject);
var
  G: TGauge;
begin
  if not ReadGauge(G) then
  begin
    ShowWarning('Choose a PID and a scale where "to" is larger than "from".');
    Exit;
  end;
  ModalResult := mrOk;
end;

procedure TGaugeEditorForm.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TGaugeEditorForm.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if (Key = vkHardwareBack) or (Key = vkEscape) then
  begin
    Key := 0;
    if pnlPicker.Visible then
      ShowPicker(False)
    else
      ModalResult := mrCancel;
  end;
end;

{ PID picker }

procedure TGaugeEditorForm.pnlPidClick(Sender: TObject);
begin
  ShowPicker(True);
end;

procedure TGaugeEditorForm.btnPickerBackClick(Sender: TObject);
begin
  ShowPicker(False);
end;

procedure TGaugeEditorForm.ShowPicker(Show: Boolean);
var
  I: Integer;
begin
  if Show then
  begin
    FLoading := True;
    try
      edtPidSearch.Text := '';
    finally
      FLoading := False;
    end;
    pnlPicker.Visible := True;
    pnlPicker.BringToFront;
    FillPicker;
    for I := 0 to High(FPickRows) do
      if FPickRows[I] = FPidId then
        FPickGrid.ScrollIntoView(I);
    if not IsMobile then
      edtPidSearch.SetFocus; // a phone would pop its keyboard over the list
  end
  else
    pnlPicker.Visible := False;
end;

procedure TGaugeEditorForm.FillPicker;
var
  Cat: TPidCategory;
  I: Integer;
  P: TPidDef;
  Filter: string;
  Added: Boolean;
begin
  FPickRows := nil;
  Filter := LowerCase(Trim(edtPidSearch.Text));
  for Cat := Low(TPidCategory) to High(TPidCategory) do
  begin
    Added := False;
    for I := 0 to FCatalog.Count - 1 do
    begin
      P := FCatalog[I];
      if not (P.Enabled or (P.Id = FPidId)) or (P.Category <> Cat) then
        Continue;
      if (Filter <> '') and (Pos(Filter, LowerCase(P.LongName + ' ' + P.ShortName + ' ' + P.PidCode + ' ' +
        P.Units)) = 0) then
        Continue;
      if not Added then
      begin
        FPickRows := FPickRows + [-(Ord(Cat) + 1)];
        Added := True;
      end;
      FPickRows := FPickRows + [P.Id];
    end;
  end;
  FPickGrid.OnSelect := nil;
  try
    FPickGrid.RowCount := Length(FPickRows);
    FPickGrid.ItemIndex := -1;
    FPickGrid.AutoRowHeights;
  finally
    FPickGrid.OnSelect := PickSelect;
  end;
  FPickGrid.Refresh;
end;

procedure TGaugeEditorForm.edtPidSearchChange(Sender: TObject);
begin
  if not FLoading then
    FillPicker;
end;

procedure TGaugeEditorForm.PickGetText(Sender: TObject; Col, Row: Integer; var Text: string);
var
  P: TPidDef;
begin
  if (Row < 0) or (Row > High(FPickRows)) then
    Exit;
  if FPickRows[Row] < 0 then
  begin
    if Col = 0 then
      Text := CategoryNames[TPidCategory(-FPickRows[Row] - 1)];
    Exit;
  end;
  P := FCatalog.FindById(FPickRows[Row]);
  if P = nil then
    Exit;
  if Col = 0 then
    Text := P.LongName
  else
    Text := P.Units;
end;

procedure TGaugeEditorForm.PickIsGroup(Sender: TObject; Row: Integer; var IsGroup: Boolean);
begin
  IsGroup := (Row >= 0) and (Row <= High(FPickRows)) and (FPickRows[Row] < 0);
end;

procedure TGaugeEditorForm.PickSelect(Sender: TObject);
var
  Row: Integer;
begin
  Row := FPickGrid.ItemIndex;
  if (Row < 0) or (Row > High(FPickRows)) or (FPickRows[Row] < 0) then
    Exit;
  FPidId := FPickRows[Row];
  ShowPicker(False);
  SuggestForPid;
  UpdatePid;
  UpdateAlerts;
end;

end.
