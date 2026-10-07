unit UVScan.Gauge;

{ A dashboard gauge: dial, bar or big number, drawn with the FMX canvas
  (anti-aliased on every platform). The gauge knows nothing about PIDs or
  alerts; the dashboard feeds it a reading and the colours the display
  levels chose. Not a registered component: create it in code. }

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.TextLayout, UVScan.Display;

type
  TGaugeView = class(TControl)
  private
    FStyle: TGaugeStyle;
    FSize: TGaugeSize;
    FTitle: string;
    FUnits: string;
    FValueText: string;
    FNote: string;
    FValue: Double;
    FMinValue: Double;
    FMaxValue: Double;
    FZones: TArray<TGaugeZone>;
    FCardColor: TAlphaColor;
    FTextColor: TAlphaColor;
    FNormalColor: TAlphaColor;
    FSelected: Boolean;
    FLayout: TTextLayout;
    procedure SetSelected(Value: Boolean);
    procedure DrawStr(const S: string; X, Y, W, H, Px: Single; Bold: Boolean; C: TAlphaColor;
      Align: TTextAlign; Fit: Boolean = False);
    procedure DrawArcLine(CX, CY, R, Start, Sweep, Width: Single; C: TAlphaColor; RoundCaps: Boolean);
    procedure DrawSeg(X1, Y1, X2, Y2, Width: Single; C: TAlphaColor);
    procedure FillRound(X, Y, W, H, R: Single; C: TAlphaColor);
    procedure FillCircle(CX, CY, R: Single; C: TAlphaColor);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Setup(AStyle: TGaugeStyle; ASize: TGaugeSize; const ATitle, AUnits: string;
      AMin, AMax: Double; const AZones: TArray<TGaugeZone>);
    { The live reading. Value may be NaN (no data). CardColor/TextColor
      NoColor = the default dark card; NormalColor (if set) colours the value
      arc when no zone covers the value. Repaints only if something visible
      changed. }
    procedure SetReading(const AValue: Double; const AValueText: string; ACardColor, ATextColor,
      ANormalColor: TAlphaColor; const ANote: string = '');
    { Size in logical units (DIPs). }
    class function PreferredSize(AStyle: TGaugeStyle; ASize: TGaugeSize): TSizeF;
    property Style: TGaugeStyle read FStyle;
    property Selected: Boolean read FSelected write SetSelected;
  published
    property Align;
    property Position;
    property Width;
    property Height;
    property Visible;
    property HitTest;
    property PopupMenu;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseUp;
  end;

{ A "nice" tick step (1, 2 or 5 x 10^n) giving about Target divisions. }
function NiceStep(Range: Double; Target: Integer): Double;
{ Colour of the zone that covers V (the last one listed wins), NoColor if none. }
function ZoneColorAt(const Zones: TArray<TGaugeZone>; const V: Double): TAlphaColor;

implementation

uses
  UVScan.UI.Common;

const
  BaseSizes: array[TGaugeSize] of Integer = (190, 250, 330);
  DefaultCard = TAlphaColor($FF1E242C);
  DefaultText = TAlphaColor($FFEBEEF2);
  DefaultTrack = TAlphaColor($FF404450);
  DefaultAccent = TAlphaColor($FF46AAFF);
  DefaultNeedle = TAlphaColor($FFFF5A3C);
  SelectedFrame = TAlphaColor($FF46AAFF);
  TickTargets: array[Boolean, TGaugeSize] of Integer = ((5, 7, 8), (4, 5, 6)); // [bar?, size]

function NiceStep(Range: Double; Target: Integer): Double;
var
  Raw, Mag, N: Double;
begin
  if (Range <= 0) or (Target < 1) or IsNan(Range) or IsInfinite(Range) then
    Exit(1);
  Raw := Range / Target;
  Mag := Power(10, Floor(Log10(Raw)));
  N := Raw / Mag;
  if N < 1.5 then
    Result := Mag
  else if N < 3 then
    Result := 2 * Mag
  else if N < 7 then
    Result := 5 * Mag
  else
    Result := 10 * Mag;
end;

function ZoneColorAt(const Zones: TArray<TGaugeZone>; const V: Double): TAlphaColor;
var
  Z: TGaugeZone;
begin
  Result := NoColor;
  if IsNan(V) then
    Exit;
  for Z in Zones do
    if (V >= Z.FromValue) and (V <= Z.ToValue) then
      Result := Z.Color;
end;

function TickLabel(const V, Step: Double): string;
begin
  if Abs(V) >= 10000 then
    Result := FormatFloat('0.#', V / 1000) + 'k'
  else if Step >= 1 then
    Result := FormatFloat('0', V)
  else
    Result := FormatFloat('0.##', V);
end;

type
  TPalette = record
    Card, Text, Sub, Track, Fill, Needle: TAlphaColor;
  end;

{ TGaugeView }

constructor TGaugeView.Create(AOwner: TComponent);
begin
  inherited;
  HitTest := True;
  FLayout := TTextLayoutManager.DefaultTextLayout.Create;
  FValue := NaN;
  FMaxValue := 100;
  FCardColor := NoColor;
  FTextColor := NoColor;
  FNormalColor := NoColor;
  FSize := gzMedium;
end;

destructor TGaugeView.Destroy;
begin
  FLayout.Free;
  inherited;
end;

class function TGaugeView.PreferredSize(AStyle: TGaugeStyle; ASize: TGaugeSize): TSizeF;
var
  B: Single;
begin
  B := BaseSizes[ASize];
  case AStyle of
    gsDial: Result := TSizeF.Create(B, B);
    gsBar: Result := TSizeF.Create(2 * B, Round(B * 0.5));
  else
    Result := TSizeF.Create(B, Round(B * 0.62));
  end;
end;

procedure TGaugeView.Setup(AStyle: TGaugeStyle; ASize: TGaugeSize; const ATitle, AUnits: string;
  AMin, AMax: Double; const AZones: TArray<TGaugeZone>);
begin
  FStyle := AStyle;
  FSize := ASize;
  FTitle := ATitle;
  FUnits := AUnits;
  FMinValue := AMin;
  FMaxValue := Max(AMax, AMin + 1E-6);
  FZones := Copy(AZones);
  Repaint;
end;

procedure TGaugeView.SetReading(const AValue: Double; const AValueText: string; ACardColor, ATextColor,
  ANormalColor: TAlphaColor; const ANote: string);
var
  Same: Boolean;
begin
  Same := (AValueText = FValueText) and (ACardColor = FCardColor) and (ATextColor = FTextColor) and
    (ANormalColor = FNormalColor) and (ANote = FNote) and
    ((IsNan(AValue) and IsNan(FValue)) or (not IsNan(AValue) and not IsNan(FValue) and SameValue(AValue, FValue, 1E-9)));
  if Same then
    Exit;
  FValue := AValue;
  FValueText := AValueText;
  FCardColor := ACardColor;
  FTextColor := ATextColor;
  FNormalColor := ANormalColor;
  FNote := ANote;
  Repaint;
end;

procedure TGaugeView.SetSelected(Value: Boolean);
begin
  if FSelected <> Value then
  begin
    FSelected := Value;
    Repaint;
  end;
end;

{ Drawing helpers }

procedure TGaugeView.FillRound(X, Y, W, H, R: Single; C: TAlphaColor);
begin
  if (W <= 0) or (H <= 0) then
    Exit;
  R := Min(R, Min(W, H) / 2);
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := C;
  Canvas.FillRect(TRectF.Create(X, Y, X + W, Y + H), R, R, AllCorners, 1);
end;

procedure TGaugeView.FillCircle(CX, CY, R: Single; C: TAlphaColor);
begin
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := C;
  Canvas.FillEllipse(TRectF.Create(CX - R, CY - R, CX + R, CY + R), 1);
end;

procedure TGaugeView.DrawArcLine(CX, CY, R, Start, Sweep, Width: Single; C: TAlphaColor; RoundCaps: Boolean);
begin
  if (Sweep <= 0.01) or (R <= 0) then
    Exit;
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Color := C;
  Canvas.Stroke.Thickness := Width;
  if RoundCaps then
    Canvas.Stroke.Cap := TStrokeCap.Round
  else
    Canvas.Stroke.Cap := TStrokeCap.Flat;
  Canvas.DrawArc(TPointF.Create(CX, CY), TPointF.Create(R, R), Start, Sweep, 1);
end;

procedure TGaugeView.DrawSeg(X1, Y1, X2, Y2, Width: Single; C: TAlphaColor);
begin
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Color := C;
  Canvas.Stroke.Thickness := Width;
  Canvas.Stroke.Cap := TStrokeCap.Round;
  Canvas.DrawLine(TPointF.Create(X1, Y1), TPointF.Create(X2, Y2), 1);
end;

{ Draws S in the box; Fit shrinks the font until the text fits the width. }
procedure TGaugeView.DrawStr(const S: string; X, Y, W, H, Px: Single; Bold: Boolean; C: TAlphaColor;
  Align: TTextAlign; Fit: Boolean);
var
  TextW: Single;
begin
  if (S = '') or (W <= 0) or (H <= 0) or (Px < 1) then
    Exit;
  if Fit then
  begin
    Canvas.Font.Size := Px;
    if Bold then
      Canvas.Font.Style := [TFontStyle.fsBold]
    else
      Canvas.Font.Style := [];
    TextW := Canvas.TextWidth(S);
    if (TextW > W) and (TextW > 0) then
      Px := Max(6, Px * W / TextW * 0.97);
  end;
  FLayout.BeginUpdate;
  try
    FLayout.TopLeft := TPointF.Create(X, Y);
    FLayout.MaxSize := TPointF.Create(W, H);
    FLayout.Text := S;
    FLayout.WordWrap := False;
    FLayout.Trimming := TTextTrimming.Character;
    FLayout.Font.Size := Px;
    if Bold then
      FLayout.Font.Style := [TFontStyle.fsBold]
    else
      FLayout.Font.Style := [];
    FLayout.Color := C;
    FLayout.HorizontalAlign := Align;
    FLayout.VerticalAlign := TTextAlign.Center;
  finally
    FLayout.EndUpdate;
  end;
  FLayout.RenderLayout(Canvas);
end;

procedure TGaugeView.Paint;
var
  W, H, Pad, Radius, Ang, CX, CY, D, R, Thick, ZoneW, ZoneR, T, Step, LabelR, A, X: Single;
  Pal: TPalette;
  Z: TGaugeZone;
  F1, F2, BarX, BarY, BarW, BarH, TitleH: Single;
  Shown, UnitLine: string;
  Fill: TAlphaColor;
  HaveValue: Boolean;
  Tick: Double;
  State: TCanvasSaveState;

  function FracOf(const V: Double): Single;
  begin
    Result := EnsureRange((V - FMinValue) / (FMaxValue - FMinValue), 0, 1);
  end;

begin
  W := Width;
  H := Height;
  if (W < 4) or (H < 4) then
    Exit;

  // Colours: the default dark card, or the level's colours.
  Pal.Card := DefaultCard;
  if FCardColor <> NoColor then
    Pal.Card := FCardColor;
  if FTextColor <> NoColor then
    Pal.Text := FTextColor
  else if FCardColor <> NoColor then
    Pal.Text := ContrastColor(Pal.Card)
  else
    Pal.Text := DefaultText;
  Pal.Sub := Blend(Pal.Text, Pal.Card, 0.35);
  if FCardColor = NoColor then
  begin
    Pal.Track := DefaultTrack;
    Pal.Needle := DefaultNeedle;
  end
  else
  begin
    Pal.Track := Blend(Pal.Card, Pal.Text, 0.25);
    Pal.Needle := Pal.Text;
  end;
  HaveValue := not IsNan(FValue);
  Fill := ZoneColorAt(FZones, FValue);
  if FCardColor <> NoColor then
    Fill := Pal.Text
  else if Fill = NoColor then
  begin
    Fill := FNormalColor;
    if Fill = NoColor then
      Fill := DefaultAccent;
  end;
  Shown := FValueText;
  if Shown = '' then
    Shown := '-';
  UnitLine := FUnits;
  if FNote <> '' then
    UnitLine := Trim(FUnits + '   ' + FNote);

  State := Canvas.SaveState;
  try
    Canvas.IntersectClipRect(LocalRect);
    Radius := Min(W, H) * 0.07;
    FillRound(1, 1, W - 2, H - 2, Radius, Pal.Card);
    if FSelected then
    begin
      Canvas.Stroke.Kind := TBrushKind.Solid;
      Canvas.Stroke.Color := SelectedFrame;
      Canvas.Stroke.Thickness := 3;
      Canvas.DrawRect(TRectF.Create(2.5, 2.5, W - 2.5, H - 2.5), Radius, Radius, AllCorners, 1);
    end;

    case FStyle of
      gsDial:
        begin
          Pad := W * 0.06;
          TitleH := H * 0.12;
          DrawStr(FTitle, Pad, Pad * 0.5, W - 2 * Pad, TitleH, H * 0.062, True, Pal.Sub, TTextAlign.Center);
          D := Min(W - 2 * Pad, H - Pad * 0.5 - TitleH - Pad * 0.4);
          CX := W / 2;
          CY := Pad * 0.5 + TitleH + D / 2;
          Thick := D * 0.075;
          ZoneW := D * 0.03;
          R := D / 2 - ZoneW - D * 0.02 - Thick / 2;
          ZoneR := R + Thick / 2 + D * 0.012 + ZoneW / 2;
          // track, zone bands, value arc
          DrawArcLine(CX, CY, R, 135, 270, Thick, Pal.Track, True);
          for Z in FZones do
          begin
            F1 := FracOf(Z.FromValue);
            F2 := FracOf(Z.ToValue);
            DrawArcLine(CX, CY, ZoneR, 135 + 270 * F1, 270 * (F2 - F1), ZoneW, Z.Color, False);
          end;
          if HaveValue then
            DrawArcLine(CX, CY, R, 135, Max(0.5, 270 * FracOf(FValue)), Thick, Fill, True);
          // ticks and labels
          Step := NiceStep(FMaxValue - FMinValue, TickTargets[FStyle = gsBar, FSize]);
          LabelR := R - Thick / 2 - D * 0.115;
          Tick := Ceil(FMinValue / Step - 1E-9) * Step;
          while Tick <= FMaxValue + Step * 1E-6 do
          begin
            A := DegToRad(135 + 270 * FracOf(Tick));
            DrawSeg(CX + Cos(A) * (R - Thick / 2 - D * 0.02), CY + Sin(A) * (R - Thick / 2 - D * 0.02),
              CX + Cos(A) * (R - Thick / 2 - D * 0.055), CY + Sin(A) * (R - Thick / 2 - D * 0.055), D * 0.008, Pal.Sub);
            DrawStr(TickLabel(Tick, Step), CX + Cos(A) * LabelR - D * 0.09, CY + Sin(A) * LabelR - D * 0.04,
              D * 0.18, D * 0.08, D * 0.048, False, Pal.Sub, TTextAlign.Center, True);
            Tick := Tick + Step;
          end;
          // needle
          if HaveValue then
          begin
            Ang := DegToRad(135 + 270 * FracOf(FValue));
            DrawSeg(CX - Cos(Ang) * R * 0.12, CY - Sin(Ang) * R * 0.12, CX + Cos(Ang) * R * 0.82,
              CY + Sin(Ang) * R * 0.82, D * 0.022, Pal.Needle);
          end;
          FillCircle(CX, CY, D * 0.045, Pal.Needle);
          FillCircle(CX, CY, D * 0.018, Pal.Card);
          // value and units in the open bottom of the dial
          DrawStr(Shown, CX - R * 0.6, CY + R * 0.3, R * 1.2, R * 0.42, D * 0.14, True, Pal.Text,
            TTextAlign.Center, True);
          DrawStr(UnitLine, CX - R * 0.9, CY + R * 0.70, R * 1.8, R * 0.26, D * 0.05, False, Pal.Sub,
            TTextAlign.Center, True);
        end;

      gsBar:
        begin
          Pad := H * 0.12;
          DrawStr(FTitle, Pad, Pad * 0.45, W * 0.55, H * 0.22, H * 0.13, True, Pal.Sub, TTextAlign.Leading);
          DrawStr(UnitLine, Pad, Pad * 0.45 + H * 0.2, W * 0.5, H * 0.18, H * 0.1, False, Pal.Sub, TTextAlign.Leading);
          DrawStr(Shown, W * 0.45, Pad * 0.2, W * 0.55 - Pad, H * 0.45, H * 0.3, True, Pal.Text, TTextAlign.Trailing,
            True);
          BarX := Pad;
          BarW := W - 2 * Pad;
          BarY := H * 0.56;
          BarH := H * 0.13;
          FillRound(BarX, BarY, BarW, BarH, BarH / 2, Pal.Track);
          if HaveValue then
            FillRound(BarX, BarY, Max(BarH, BarW * FracOf(FValue)), BarH, BarH / 2, Fill);
          for Z in FZones do
          begin
            F1 := FracOf(Z.FromValue);
            F2 := FracOf(Z.ToValue);
            FillRound(BarX + BarW * F1, BarY + BarH + H * 0.035, BarW * (F2 - F1), H * 0.045, 1, Z.Color);
          end;
          Step := NiceStep(FMaxValue - FMinValue, TickTargets[FStyle = gsBar, FSize]);
          Tick := Ceil(FMinValue / Step - 1E-9) * Step;
          while Tick <= FMaxValue + Step * 1E-6 do
          begin
            X := BarX + BarW * FracOf(Tick);
            T := H * 0.5;
            DrawStr(TickLabel(Tick, Step), X - T / 2, H * 0.78, T, H * 0.16, H * 0.095, False, Pal.Sub,
              TTextAlign.Center, True);
            Tick := Tick + Step;
          end;
        end;

    else // gsNumber
      begin
        Pad := W * 0.06;
        DrawStr(FTitle, Pad, H * 0.05, W - 2 * Pad, H * 0.2, H * 0.1, True, Pal.Sub, TTextAlign.Center);
        DrawStr(Shown, Pad, H * 0.22, W - 2 * Pad, H * 0.52, H * 0.42, True, Pal.Text, TTextAlign.Center, True);
        DrawStr(UnitLine, Pad, H * 0.74, W - 2 * Pad, H * 0.18, H * 0.1, False, Pal.Sub, TTextAlign.Center, True);
      end;
    end;
  finally
    Canvas.RestoreState(State);
  end;
end;

end.
