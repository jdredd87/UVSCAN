unit UVScan.GaugeEditor;

{ Add or edit one dashboard gauge: which PID, dial / bar / big number, size
  and scale, with a live preview that uses the PID's alert levels. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.UITypes, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  UVScan.Pids, UVScan.Display, UVScan.Gauge;

type
  TGaugeEditorForm = class(TForm)
    lblPid: TLabel;
    cbPid: TComboBox;
    rgStyle: TRadioGroup;
    rgSize: TRadioGroup;
    lblScale: TLabel;
    edtMin: TEdit;
    lblTo: TLabel;
    edtMax: TEdit;
    btnSuggest: TButton;
    lblHelp: TLabel;
    pnlPreview: TPanel;
    lblPreview: TLabel;
    tbPreview: TTrackBar;
    btnOK: TButton;
    btnCancel: TButton;
    tmrFlash: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure cbPidChange(Sender: TObject);
    procedure SettingChange(Sender: TObject);
    procedure btnSuggestClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure tmrFlashTimer(Sender: TObject);
  private
    FCatalog: TPidCatalog;
    FSettings: TDisplaySettings;
    FGaugeView: TGaugeView;
    FIds: TArray<Integer>;
    FLoading: Boolean;
    FFlashOn: Boolean;
    function SelectedPid: TPidDef;
    function ReadGauge(out G: TGauge): Boolean;
    procedure UpdatePreview;
  public
    { G: in = gauge to edit (or the PID to start from), out = the result. }
    class function Execute(var G: TGauge; Catalog: TPidCatalog; Settings: TDisplaySettings;
      const Caption: string): Boolean;
  end;

{ A starting scale for a PID: from its formula's output range (raw 00 / FF),
  or a sensible fixed range for a few units. }
procedure SuggestScale(P: TPidDef; Settings: TDisplaySettings; out MinValue, MaxValue: Double);

{ Feeds a gauge one reading in the colours the PID's display levels choose.
  Shared by the dashboard and the preview so both look the same. }
procedure ShowGaugeReading(Gauge: TGaugeView; const Style: TResolvedStyle; FlashOn: Boolean;
  const Value: Double; const Text, Note: string);

implementation

{$R *.dfm}

uses
  System.StrUtils;

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
  Card, Txt: TColor;
  N: string;
begin
  Card := clNone;
  Txt := clNone;
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

class function TGaugeEditorForm.Execute(var G: TGauge; Catalog: TPidCatalog; Settings: TDisplaySettings;
  const Caption: string): Boolean;
var
  F: TGaugeEditorForm;
  I: Integer;
begin
  F := TGaugeEditorForm.Create(Application);
  try
    F.Caption := Caption;
    F.FCatalog := Catalog;
    F.FSettings := Settings;
    F.FLoading := True;
    for I := 0 to Catalog.Count - 1 do
      if Catalog[I].Enabled or (Catalog[I].Id = G.PidId) then
      begin
        F.cbPid.Items.Add(Catalog[I].LongName + IfThen(Catalog[I].Units <> '', '  (' + Catalog[I].Units + ')', ''));
        F.FIds := F.FIds + [Catalog[I].Id];
      end;
    F.cbPid.ItemIndex := -1;
    for I := 0 to High(F.FIds) do
      if F.FIds[I] = G.PidId then
        F.cbPid.ItemIndex := I;
    F.rgStyle.ItemIndex := Ord(G.Style);
    F.rgSize.ItemIndex := Ord(G.Size);
    F.edtMin.Text := FormatFloat('0.###', G.MinValue);
    F.edtMax.Text := FormatFloat('0.###', G.MaxValue);
    F.FLoading := False;
    F.UpdatePreview;
    Result := F.ShowModal = mrOk;
    if Result then
      F.ReadGauge(G);
  finally
    F.Free;
  end;
end;

procedure TGaugeEditorForm.FormCreate(Sender: TObject);
var
  S: TGaugeStyle;
  Z: TGaugeSize;
begin
  for S := Low(TGaugeStyle) to High(TGaugeStyle) do
    rgStyle.Items.Add(GaugeStyleCaptions[S]);
  for Z := Low(TGaugeSize) to High(TGaugeSize) do
    rgSize.Items.Add(GaugeSizeCaptions[Z]);
  pnlPreview.DoubleBuffered := True;
  FGaugeView := TGaugeView.Create(Self);
  FGaugeView.Parent := pnlPreview;
  tbPreview.Position := 50;
end;

function TGaugeEditorForm.SelectedPid: TPidDef;
begin
  if (cbPid.ItemIndex >= 0) and (cbPid.ItemIndex <= High(FIds)) then
    Result := FCatalog.FindById(FIds[cbPid.ItemIndex])
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
  G.Style := TGaugeStyle(Max(0, rgStyle.ItemIndex));
  G.Size := TGaugeSize(Max(0, rgSize.ItemIndex));
end;

procedure TGaugeEditorForm.cbPidChange(Sender: TObject);
var
  A, B: Double;
begin
  if FLoading then
    Exit;
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
  cbPidChange(nil);
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
  Sz: TSize;
  V: Double;
  Ok: Boolean;
begin
  Ok := ReadGauge(G);
  edtMin.Color := IfThen(Ok or (SelectedPid = nil), clWindow, $00C8C8FF);
  edtMax.Color := edtMin.Color;
  btnOK.Enabled := Ok;
  P := SelectedPid;
  if not Ok or (P = nil) then
  begin
    FGaugeView.Visible := False;
    Exit;
  end;
  Sz := TGaugeView.PreferredSize(G.Style, G.Size, CurrentPPI);
  // Shrink to fit the preview area, keeping the shape.
  if (Sz.cx > pnlPreview.ClientWidth - 8) or (Sz.cy > pnlPreview.ClientHeight - 8) then
  begin
    V := Min((pnlPreview.ClientWidth - 8) / Sz.cx, (pnlPreview.ClientHeight - 8) / Sz.cy);
    Sz.cx := Round(Sz.cx * V);
    Sz.cy := Round(Sz.cy * V);
  end;
  FGaugeView.SetBounds((pnlPreview.ClientWidth - Sz.cx) div 2, (pnlPreview.ClientHeight - Sz.cy) div 2, Sz.cx, Sz.cy);
  FGaugeView.Setup(G.Style, G.Size, P.LongName, P.Units, G.MinValue, G.MaxValue,
    FSettings.Zones(P.Id, G.MinValue, G.MaxValue));
  V := G.MinValue + (G.MaxValue - G.MinValue) * tbPreview.Position / tbPreview.Max;
  ShowGaugeReading(FGaugeView, FSettings.Resolve(P.Id, V), FFlashOn, V, P.FormatValue(V), '');
  FGaugeView.Visible := True;
end;

procedure TGaugeEditorForm.tmrFlashTimer(Sender: TObject);
begin
  FFlashOn := not FFlashOn;
  if FGaugeView.Visible then
    UpdatePreview;
end;

procedure TGaugeEditorForm.btnOKClick(Sender: TObject);
var
  G: TGauge;
begin
  if not ReadGauge(G) then
  begin
    MessageDlg('Choose a PID and a scale where "to" is larger than "from".', mtWarning, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOk;
end;

end.
