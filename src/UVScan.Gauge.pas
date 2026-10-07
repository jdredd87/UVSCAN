unit UVScan.Gauge;

{ A dashboard gauge: dial, bar or big number, drawn with GDI+ (anti-aliased)
  into an off-screen bitmap. The gauge knows nothing about PIDs or alerts;
  the dashboard feeds it a reading and the colours the display levels chose. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.UITypes, System.Math,
  Vcl.Graphics, Vcl.Controls, UVScan.Display;

type
  TGaugeView = class(TCustomControl)
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
    FCardColor: TColor;
    FTextColor: TColor;
    FNormalColor: TColor;
    FSelected: Boolean;
    FBuffer: TBitmap;
    procedure WMEraseBkgnd(var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure SetSelected(Value: Boolean);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Setup(AStyle: TGaugeStyle; ASize: TGaugeSize; const ATitle, AUnits: string;
      AMin, AMax: Double; const AZones: TArray<TGaugeZone>);
    { The live reading. Value may be NaN (no data). CardColor/TextColor clNone =
      the default dark card; NormalColor (if set) colours the value arc when no
      zone covers the value. Repaints only if something visible changed. }
    procedure SetReading(const AValue: Double; const AValueText: string; ACardColor, ATextColor,
      ANormalColor: TColor; const ANote: string = '');
    { Size in pixels at the given DPI. }
    class function PreferredSize(AStyle: TGaugeStyle; ASize: TGaugeSize; PPI: Integer): TSize;
    property Style: TGaugeStyle read FStyle;
    property Selected: Boolean read FSelected write SetSelected;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property PopupMenu;
  end;

{ A "nice" tick step (1, 2 or 5 x 10^n) giving about Target divisions. }
function NiceStep(Range: Double; Target: Integer): Double;
{ Colour of the zone that covers V (the last one listed wins), clNone if none. }
function ZoneColorAt(const Zones: TArray<TGaugeZone>; const V: Double): TColor;
{ Black or white, whichever reads better on Back. }
function ContrastColor(Back: TColor): TColor;

implementation

uses
  Winapi.GDIPAPI, Winapi.GDIPOBJ;

const
  BaseSizes: array[TGaugeSize] of Integer = (190, 250, 330);
  DefaultCard = TColor($002C241E);     // RGB(30, 36, 44)
  DefaultText = TColor($00F2EEEB);
  DefaultTrack = TColor($00504440);
  DefaultAccent = TColor($00FFAA46);   // RGB(70, 170, 255)
  DefaultNeedle = TColor($003C5AFF);   // RGB(255, 90, 60)
  SelectedFrame = TColor($00FFAA46);
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

function ZoneColorAt(const Zones: TArray<TGaugeZone>; const V: Double): TColor;
var
  Z: TGaugeZone;
begin
  Result := clNone;
  if IsNan(V) then
    Exit;
  for Z in Zones do
    if (V >= Z.FromValue) and (V <= Z.ToValue) then
      Result := Z.Color;
end;

function Luminance(C: TColor): Double;
var
  RGB: Cardinal;
begin
  RGB := ColorToRGB(C);
  Result := 0.299 * GetRValue(RGB) + 0.587 * GetGValue(RGB) + 0.114 * GetBValue(RGB);
end;

function ContrastColor(Back: TColor): TColor;
begin
  if Luminance(Back) > 150 then
    Result := TColor($00201C1A)
  else
    Result := TColor($00FFFFFF);
end;

function Blend(A, B: TColor; T: Double): TColor;
var
  CA, CB: Cardinal;
begin
  CA := ColorToRGB(A);
  CB := ColorToRGB(B);
  Result := RGB(Round(GetRValue(CA) + (GetRValue(CB) - GetRValue(CA)) * T),
    Round(GetGValue(CA) + (GetGValue(CB) - GetGValue(CA)) * T),
    Round(GetBValue(CA) + (GetBValue(CB) - GetBValue(CA)) * T));
end;

function GP(C: TColor; Alpha: Byte = 255): ARGB;
var
  RGB: Cardinal;
begin
  RGB := ColorToRGB(C);
  Result := MakeColor(Alpha, GetRValue(RGB), GetGValue(RGB), GetBValue(RGB));
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

{ Drawing helpers }

type
  TPalette = record
    Card, Text, Sub, Track, Fill, Needle: TColor;
  end;

procedure RoundRectPath(P: TGPGraphicsPath; X, Y, W, H, R: Single);
begin
  R := Min(R, Min(W, H) / 2);
  P.AddArc(X, Y, 2 * R, 2 * R, 180, 90);
  P.AddArc(X + W - 2 * R, Y, 2 * R, 2 * R, 270, 90);
  P.AddArc(X + W - 2 * R, Y + H - 2 * R, 2 * R, 2 * R, 0, 90);
  P.AddArc(X, Y + H - 2 * R, 2 * R, 2 * R, 90, 90);
  P.CloseFigure;
end;

procedure FillRound(G: TGPGraphics; X, Y, W, H, R: Single; C: TColor; Alpha: Byte = 255);
var
  P: TGPGraphicsPath;
  B: TGPSolidBrush;
begin
  if (W <= 0) or (H <= 0) then
    Exit;
  P := TGPGraphicsPath.Create;
  B := TGPSolidBrush.Create(GP(C, Alpha));
  try
    RoundRectPath(P, X, Y, W, H, R);
    G.FillPath(B, P);
  finally
    B.Free;
    P.Free;
  end;
end;

procedure DrawRoundFrame(G: TGPGraphics; X, Y, W, H, R, Width: Single; C: TColor);
var
  P: TGPGraphicsPath;
  Pen: TGPPen;
begin
  P := TGPGraphicsPath.Create;
  Pen := TGPPen.Create(GP(C), Width);
  try
    RoundRectPath(P, X, Y, W, H, R);
    G.DrawPath(Pen, P);
  finally
    Pen.Free;
    P.Free;
  end;
end;

{ Draws S in the box; Fit shrinks the font until the text fits the width. }
procedure DrawStr(G: TGPGraphics; const S: string; X, Y, W, H, Px: Single; Bold: Boolean; C: TColor;
  Align: TStringAlignment; Fit: Boolean = False);
var
  Font: TGPFont;
  Fmt: TGPStringFormat;
  Brush: TGPSolidBrush;
  Box: TGPRectF;
  Origin: TGPPointF;
  Style: Integer;
begin
  if (S = '') or (W <= 0) or (H <= 0) or (Px < 1) then
    Exit;
  if Bold then
    Style := FontStyleBold
  else
    Style := FontStyleRegular;
  Fmt := TGPStringFormat.Create;
  Brush := TGPSolidBrush.Create(GP(C));
  Font := TGPFont.Create('Segoe UI', Px, Style, UnitPixel);
  try
    Fmt.SetFormatFlags(StringFormatFlagsNoWrap);
    Fmt.SetTrimming(StringTrimmingEllipsisCharacter);
    Fmt.SetAlignment(Align);
    Fmt.SetLineAlignment(StringAlignmentCenter);
    if Fit then
    begin
      Origin.X := 0;
      Origin.Y := 0;
      G.MeasureString(S, Length(S), Font, Origin, Fmt, Box);
      if (Box.Width > W) and (Box.Width > 0) then
      begin
        Font.Free;
        Font := TGPFont.Create('Segoe UI', Max(6, Px * W / Box.Width * 0.97), Style, UnitPixel);
      end;
    end;
    G.DrawString(S, Length(S), Font, MakeRect(X, Y, W, H), Fmt, Brush);
  finally
    Font.Free;
    Brush.Free;
    Fmt.Free;
  end;
end;

procedure DrawArcLine(G: TGPGraphics; CX, CY, R, Start, Sweep, Width: Single; C: TColor; RoundCaps: Boolean);
var
  Pen: TGPPen;
begin
  if (Sweep <= 0.01) or (R <= 0) then
    Exit;
  Pen := TGPPen.Create(GP(C), Width);
  try
    if RoundCaps then
      Pen.SetLineCap(LineCapRound, LineCapRound, DashCapRound);
    G.DrawArc(Pen, CX - R, CY - R, 2 * R, 2 * R, Start, Sweep);
  finally
    Pen.Free;
  end;
end;

procedure DrawSeg(G: TGPGraphics; X1, Y1, X2, Y2, Width: Single; C: TColor);
var
  Pen: TGPPen;
begin
  Pen := TGPPen.Create(GP(C), Width);
  try
    Pen.SetLineCap(LineCapRound, LineCapRound, DashCapRound);
    G.DrawLine(Pen, X1, Y1, X2, Y2);
  finally
    Pen.Free;
  end;
end;

procedure FillCircle(G: TGPGraphics; CX, CY, R: Single; C: TColor);
var
  B: TGPSolidBrush;
begin
  B := TGPSolidBrush.Create(GP(C));
  try
    G.FillEllipse(B, CX - R, CY - R, 2 * R, 2 * R);
  finally
    B.Free;
  end;
end;

{ TGaugeView }

constructor TGaugeView.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle + [csOpaque];
  FBuffer := TBitmap.Create;
  FBuffer.PixelFormat := pf32bit;
  FValue := NaN;
  FMaxValue := 100;
  FCardColor := clNone;
  FTextColor := clNone;
  FNormalColor := clNone;
  FSize := gzMedium;
  ParentColor := True;
end;

destructor TGaugeView.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

class function TGaugeView.PreferredSize(AStyle: TGaugeStyle; ASize: TGaugeSize; PPI: Integer): TSize;
var
  B: Integer;
begin
  B := MulDiv(BaseSizes[ASize], PPI, 96);
  case AStyle of
    gsDial: Result := TSize.Create(B, B);
    gsBar: Result := TSize.Create(2 * B, Round(B * 0.5));
  else
    Result := TSize.Create(B, Round(B * 0.62));
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
  Invalidate;
end;

procedure TGaugeView.SetReading(const AValue: Double; const AValueText: string; ACardColor, ATextColor,
  ANormalColor: TColor; const ANote: string);
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
  Invalidate;
end;

procedure TGaugeView.SetSelected(Value: Boolean);
begin
  if FSelected <> Value then
  begin
    FSelected := Value;
    Invalidate;
  end;
end;

procedure TGaugeView.WMEraseBkgnd(var Msg: TWMEraseBkgnd);
begin
  Msg.Result := 1; // Paint covers every pixel
end;

procedure TGaugeView.Paint;
var
  G: TGPGraphics;
  W, H, Pad, Radius, Frac, Ang, CX, CY, D, R, Thick, ZoneW, ZoneR, T, Step, LabelR, A, X: Single;
  Pal: TPalette;
  Z: TGaugeZone;
  F1, F2, BarX, BarY, BarW, BarH, TitleH: Single;
  Shown, UnitLine: string;
  Fill: TColor;
  HaveValue: Boolean;
  Tick: Double;

  function FracOf(const V: Double): Single;
  begin
    Result := EnsureRange((V - FMinValue) / (FMaxValue - FMinValue), 0, 1);
  end;

begin
  W := ClientWidth;
  H := ClientHeight;
  if (W < 4) or (H < 4) then
    Exit;
  if (FBuffer.Width <> ClientWidth) or (FBuffer.Height <> ClientHeight) then
    FBuffer.SetSize(ClientWidth, ClientHeight);

  // Colours: the default dark card, or the level's colours.
  Pal.Card := DefaultCard;
  if FCardColor <> clNone then
    Pal.Card := FCardColor;
  if FTextColor <> clNone then
    Pal.Text := FTextColor
  else if FCardColor <> clNone then
    Pal.Text := ContrastColor(Pal.Card)
  else
    Pal.Text := DefaultText;
  Pal.Sub := Blend(Pal.Text, Pal.Card, 0.35);
  if FCardColor = clNone then
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
  if FCardColor <> clNone then
    Fill := Pal.Text
  else if Fill = clNone then
  begin
    Fill := FNormalColor;
    if Fill = clNone then
      Fill := DefaultAccent;
  end;
  Shown := FValueText;
  if Shown = '' then
    Shown := '-';
  UnitLine := FUnits;
  if FNote <> '' then
    UnitLine := Trim(FUnits + '   ' + FNote);

  G := TGPGraphics.Create(FBuffer.Canvas.Handle);
  try
    G.SetSmoothingMode(SmoothingModeAntiAlias);
    G.SetTextRenderingHint(TextRenderingHintAntiAliasGridFit);
    G.Clear(GP(Color));
    Radius := Min(W, H) * 0.07;
    FillRound(G, 1, 1, W - 2, H - 2, Radius, Pal.Card);
    if FSelected then
      DrawRoundFrame(G, 2, 2, W - 4, H - 4, Radius, 3, SelectedFrame);

    case FStyle of
      gsDial:
        begin
          Pad := W * 0.06;
          TitleH := H * 0.12;
          DrawStr(G, FTitle, Pad, Pad * 0.5, W - 2 * Pad, TitleH, H * 0.062, True, Pal.Sub, StringAlignmentCenter);
          D := Min(W - 2 * Pad, H - Pad * 0.5 - TitleH - Pad * 0.4);
          CX := W / 2;
          CY := Pad * 0.5 + TitleH + D / 2;
          Thick := D * 0.075;
          ZoneW := D * 0.03;
          R := D / 2 - ZoneW - D * 0.02 - Thick / 2;
          ZoneR := R + Thick / 2 + D * 0.012 + ZoneW / 2;
          // track, zone bands, value arc
          DrawArcLine(G, CX, CY, R, 135, 270, Thick, Pal.Track, True);
          for Z in FZones do
          begin
            F1 := FracOf(Z.FromValue);
            F2 := FracOf(Z.ToValue);
            DrawArcLine(G, CX, CY, ZoneR, 135 + 270 * F1, 270 * (F2 - F1), ZoneW, Z.Color, False);
          end;
          if HaveValue then
            DrawArcLine(G, CX, CY, R, 135, Max(0.5, 270 * FracOf(FValue)), Thick, Fill, True);
          // ticks and labels
          Step := NiceStep(FMaxValue - FMinValue, TickTargets[FStyle = gsBar, FSize]);
          LabelR := R - Thick / 2 - D * 0.115;
          Tick := Ceil(FMinValue / Step - 1E-9) * Step;
          while Tick <= FMaxValue + Step * 1E-6 do
          begin
            A := DegToRad(135 + 270 * FracOf(Tick));
            DrawSeg(G, CX + Cos(A) * (R - Thick / 2 - D * 0.02), CY + Sin(A) * (R - Thick / 2 - D * 0.02),
              CX + Cos(A) * (R - Thick / 2 - D * 0.055), CY + Sin(A) * (R - Thick / 2 - D * 0.055), D * 0.008, Pal.Sub);
            DrawStr(G, TickLabel(Tick, Step), CX + Cos(A) * LabelR - D * 0.09, CY + Sin(A) * LabelR - D * 0.04,
              D * 0.18, D * 0.08, D * 0.048, False, Pal.Sub, StringAlignmentCenter, True);
            Tick := Tick + Step;
          end;
          // needle
          if HaveValue then
          begin
            Ang := DegToRad(135 + 270 * FracOf(FValue));
            DrawSeg(G, CX - Cos(Ang) * R * 0.12, CY - Sin(Ang) * R * 0.12, CX + Cos(Ang) * R * 0.82, CY + Sin(Ang) * R * 0.82,
              D * 0.022, Pal.Needle);
          end;
          FillCircle(G, CX, CY, D * 0.045, Pal.Needle);
          FillCircle(G, CX, CY, D * 0.018, Pal.Card);
          // value and units in the open bottom of the dial
          DrawStr(G, Shown, CX - R * 0.6, CY + R * 0.3, R * 1.2, R * 0.42, D * 0.14, True, Pal.Text,
            StringAlignmentCenter, True);
          DrawStr(G, UnitLine, CX - R * 0.9, CY + R * 0.70, R * 1.8, R * 0.26, D * 0.05, False, Pal.Sub,
            StringAlignmentCenter, True);
        end;

      gsBar:
        begin
          Pad := H * 0.12;
          DrawStr(G, FTitle, Pad, Pad * 0.45, W * 0.55, H * 0.22, H * 0.13, True, Pal.Sub, StringAlignmentNear);
          DrawStr(G, UnitLine, Pad, Pad * 0.45 + H * 0.2, W * 0.5, H * 0.18, H * 0.1, False, Pal.Sub, StringAlignmentNear);
          DrawStr(G, Shown, W * 0.45, Pad * 0.2, W * 0.55 - Pad, H * 0.45, H * 0.3, True, Pal.Text, StringAlignmentFar, True);
          BarX := Pad;
          BarW := W - 2 * Pad;
          BarY := H * 0.56;
          BarH := H * 0.13;
          FillRound(G, BarX, BarY, BarW, BarH, BarH / 2, Pal.Track);
          if HaveValue then
            FillRound(G, BarX, BarY, Max(BarH, BarW * FracOf(FValue)), BarH, BarH / 2, Fill);
          for Z in FZones do
          begin
            F1 := FracOf(Z.FromValue);
            F2 := FracOf(Z.ToValue);
            FillRound(G, BarX + BarW * F1, BarY + BarH + H * 0.035, BarW * (F2 - F1), H * 0.045, 1, Z.Color);
          end;
          Step := NiceStep(FMaxValue - FMinValue, TickTargets[FStyle = gsBar, FSize]);
          Tick := Ceil(FMinValue / Step - 1E-9) * Step;
          while Tick <= FMaxValue + Step * 1E-6 do
          begin
            X := BarX + BarW * FracOf(Tick);
            T := H * 0.5;
            DrawStr(G, TickLabel(Tick, Step), X - T / 2, H * 0.78, T, H * 0.16, H * 0.095, False, Pal.Sub,
              StringAlignmentCenter, True);
            Tick := Tick + Step;
          end;
        end;

    else // gsNumber
      begin
        Pad := W * 0.06;
        DrawStr(G, FTitle, Pad, H * 0.05, W - 2 * Pad, H * 0.2, H * 0.1, True, Pal.Sub, StringAlignmentCenter);
        DrawStr(G, Shown, Pad, H * 0.22, W - 2 * Pad, H * 0.52, H * 0.42, True, Pal.Text, StringAlignmentCenter, True);
        DrawStr(G, UnitLine, Pad, H * 0.74, W - 2 * Pad, H * 0.18, H * 0.1, False, Pal.Sub, StringAlignmentCenter, True);
      end;
    end;
  finally
    G.Free;
  end;
  Canvas.Draw(0, 0, FBuffer);
end;

end.
