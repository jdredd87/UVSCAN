unit UVScan.LogChart;

{ The log viewer's chart: time on the horizontal axis, one line per visible
  channel, drawn with GDI+ into an off-screen bitmap.

  Modes: lanes (a strip per channel, each with its own scale), overlay (all
  lines in one area, each on its own scale, with an axis per channel) and
  shared (one scale for everything).

  Mouse: left click / drag = move the cursor, wheel = zoom time around the
  mouse, right or middle drag = pan, double-click = show the whole log. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, Vcl.Graphics, Vcl.Controls, UVScan.LogData, UVScan.LogViews, UVScan.Display;

type
  TLogChart = class(TCustomControl)
  private type
    TDrag = (dgNone, dgCursor, dgPan, dgSelect);
  private
    FData: TLogData;
    FStyles: TArray<TChannelStyle>;
    FLevels: TArray<TArray<TDisplayLevel>>;
    FMode: TChartMode;
    FT0, FT1: Double;
    FCursor: Double;
    FBuffer: TBitmap;
    FDrag: TDrag;
    FDragX: Integer;
    FDragT0, FDragT1: Double;
    FPlot: TRect;
    FShowBands: Boolean;
    FSel0, FSel1: Double;      // selected time range, NaN = none
    FOnSelectionChange: TNotifyEvent;
    FOnCursorChange: TNotifyEvent;
    FOnWindowChange: TNotifyEvent;
    procedure WMEraseBkgnd(var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMGetDlgCode(var Msg: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure SetMode(Value: TChartMode);
    procedure SetShowBands(Value: Boolean);
    function TimeAtX(X: Integer): Double;
    function Visible_: TArray<Integer>;
    procedure Scale(Ch: Integer; out Lo, Hi: Double);
    procedure SetWindow(T0, T1: Double);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DblClick; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Data is not owned. Styles / Levels: one entry per data channel. }
    procedure SetData(Data: TLogData);
    procedure SetStyles(const Styles: TArray<TChannelStyle>; const Levels: TArray<TArray<TDisplayLevel>>);
    procedure SetCursorTime(const T: Double; Notify: Boolean);
    procedure FitAll;
    procedure Zoom(Factor: Double; const Around: Double);
    { Scrolls the window so T is visible (used while playing back). }
    procedure KeepVisible(const T: Double);
    function WindowStart: Double;
    function WindowEnd: Double;
    function HasSelection: Boolean;
    procedure ClearSelection;
    procedure ZoomToSelection;
    { The chart as it is on screen, for saving as a picture. }
    procedure SaveImage(const FileName: string);
    property SelStart: Double read FSel0;
    property SelEnd: Double read FSel1;
    property OnSelectionChange: TNotifyEvent read FOnSelectionChange write FOnSelectionChange;
    property CursorTime: Double read FCursor;
    property Mode: TChartMode read FMode write SetMode;
    property ShowBands: Boolean read FShowBands write SetShowBands;
    property OnCursorChange: TNotifyEvent read FOnCursorChange write FOnCursorChange;
    property OnWindowChange: TNotifyEvent read FOnWindowChange write FOnWindowChange;
    property PopupMenu;
  end;

{ The scale a channel gets with auto scaling: its range plus a little room. }
procedure AutoRange(const Ch: TLogChannel; out Lo, Hi: Double);

implementation

uses
  System.StrUtils, Vcl.Imaging.pngimage, Winapi.GDIPAPI, Winapi.GDIPOBJ, UVScan.Gauge;

const
  Back = TColor($001E1A16);       // RGB(22, 26, 30)
  PlotBack = TColor($00261F1B);
  GridColor = TColor($003A322C);
  TextColor = TColor($00D2C8BE);
  DimText = TColor($00968C82);
  CursorColor = TColor($00FFFFFF);

procedure AutoRange(const Ch: TLogChannel; out Lo, Hi: Double);
var
  Pad: Double;
begin
  if Ch.IsSwitch then
  begin
    Lo := -0.15;
    Hi := 1.15;
    Exit;
  end;
  Lo := Ch.MinValue;
  Hi := Ch.MaxValue;
  if IsNan(Lo) or IsNan(Hi) then
  begin
    Lo := 0;
    Hi := 1;
    Exit;
  end;
  if Hi - Lo < 1E-9 then
  begin
    Lo := Lo - 1;
    Hi := Hi + 1;
  end;
  Pad := (Hi - Lo) * 0.06;
  Lo := Lo - Pad;
  Hi := Hi + Pad;
end;

function GP(C: TColor; Alpha: Byte = 255): ARGB;
var
  RGB: Cardinal;
begin
  RGB := ColorToRGB(C);
  Result := MakeColor(Alpha, GetRValue(RGB), GetGValue(RGB), GetBValue(RGB));
end;

procedure Txt(G: TGPGraphics; const S: string; X, Y, W, H, Px: Single; C: TColor; Align: TStringAlignment;
  Bold: Boolean = False);
var
  Font: TGPFont;
  Fmt: TGPStringFormat;
  Brush: TGPSolidBrush;
begin
  if (S = '') or (W <= 0) or (H <= 0) then
    Exit;
  Fmt := TGPStringFormat.Create;
  Brush := TGPSolidBrush.Create(GP(C));
  if Bold then
    Font := TGPFont.Create('Segoe UI', Px, FontStyleBold, UnitPixel)
  else
    Font := TGPFont.Create('Segoe UI', Px, FontStyleRegular, UnitPixel);
  try
    Fmt.SetFormatFlags(StringFormatFlagsNoWrap);
    Fmt.SetTrimming(StringTrimmingEllipsisCharacter);
    Fmt.SetAlignment(Align);
    Fmt.SetLineAlignment(StringAlignmentCenter);
    G.DrawString(S, Length(S), Font, MakeRect(X, Y, W, H), Fmt, Brush);
  finally
    Font.Free;
    Brush.Free;
    Fmt.Free;
  end;
end;

function TextWidth(G: TGPGraphics; const S: string; Px: Single; Bold: Boolean = False): Single;
var
  Font: TGPFont;
  Box: TGPRectF;
  Origin: TGPPointF;
begin
  if Bold then
    Font := TGPFont.Create('Segoe UI', Px, FontStyleBold, UnitPixel)
  else
    Font := TGPFont.Create('Segoe UI', Px, FontStyleRegular, UnitPixel);
  try
    Origin.X := 0;
    Origin.Y := 0;
    G.MeasureString(S, Length(S), Font, Origin, Box);
    Result := Box.Width;
  finally
    Font.Free;
  end;
end;

procedure Fill(G: TGPGraphics; X, Y, W, H: Single; C: TColor; Alpha: Byte = 255);
var
  B: TGPSolidBrush;
begin
  if (W <= 0) or (H <= 0) then
    Exit;
  B := TGPSolidBrush.Create(GP(C, Alpha));
  try
    G.FillRectangle(B, X, Y, W, H);
  finally
    B.Free;
  end;
end;

procedure Line(G: TGPGraphics; X1, Y1, X2, Y2, Width: Single; C: TColor; Alpha: Byte = 255; Dashed: Boolean = False);
var
  Pen: TGPPen;
begin
  Pen := TGPPen.Create(GP(C, Alpha), Width);
  try
    if Dashed then
      Pen.SetDashStyle(DashStyleDash);
    G.DrawLine(Pen, X1, Y1, X2, Y2);
  finally
    Pen.Free;
  end;
end;

function FormatAxis(const V, Step: Double): string;
begin
  if Abs(V) >= 10000 then
    Result := FormatFloat('0.#', V / 1000) + 'k'
  else if Step >= 1 then
    Result := FormatFloat('0', V)
  else if Step >= 0.1 then
    Result := FormatFloat('0.0', V)
  else
    Result := FormatFloat('0.##', V);
end;

function FormatValueShort(const V: Double): string;
begin
  if IsNan(V) then
    Result := '--'
  else if Abs(V) >= 1000 then
    Result := FormatFloat('0', V)
  else if Abs(V) >= 100 then
    Result := FormatFloat('0.#', V)
  else
    Result := FormatFloat('0.##', V);
end;

{ TLogChart }

constructor TLogChart.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle + [csOpaque];
  FBuffer := TBitmap.Create;
  FBuffer.PixelFormat := pf32bit;
  FMode := cmLanes;
  FSel0 := NaN;
  FSel1 := NaN;
  FShowBands := True;
  TabStop := True;
  Color := Back;
end;

destructor TLogChart.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

procedure TLogChart.WMEraseBkgnd(var Msg: TWMEraseBkgnd);
begin
  Msg.Result := 1;
end;

procedure TLogChart.WMGetDlgCode(var Msg: TWMGetDlgCode);
begin
  Msg.Result := DLGC_WANTARROWS;
end;

procedure TLogChart.SetData(Data: TLogData);
begin
  FData := Data;
  FStyles := nil;
  FLevels := nil;
  FCursor := 0;
  FSel0 := NaN;
  FSel1 := NaN;
  FitAll;
end;

procedure TLogChart.SetStyles(const Styles: TArray<TChannelStyle>; const Levels: TArray<TArray<TDisplayLevel>>);
begin
  FStyles := Copy(Styles);
  FLevels := Copy(Levels);
  Invalidate;
end;

procedure TLogChart.SetMode(Value: TChartMode);
begin
  if FMode <> Value then
  begin
    FMode := Value;
    Invalidate;
  end;
end;

procedure TLogChart.SetShowBands(Value: Boolean);
begin
  if FShowBands <> Value then
  begin
    FShowBands := Value;
    Invalidate;
  end;
end;

function TLogChart.WindowStart: Double;
begin
  Result := FT0;
end;

function TLogChart.WindowEnd: Double;
begin
  Result := FT1;
end;

procedure TLogChart.SetWindow(T0, T1: Double);
var
  First, Last, Span, MinSpan: Double;
begin
  if (FData = nil) or (FData.Count < 2) then
  begin
    FT0 := 0;
    FT1 := 1;
    Invalidate;
    Exit;
  end;
  First := FData.Times[0];
  Last := FData.Times[FData.Count - 1];
  MinSpan := Min(Last - First, 2);
  Span := Max(MinSpan, T1 - T0);
  Span := Min(Span, Last - First);
  if T0 < First then
    T0 := First;
  if T0 + Span > Last then
    T0 := Last - Span;
  FT0 := T0;
  FT1 := T0 + Span;
  Invalidate;
  if Assigned(FOnWindowChange) then
    FOnWindowChange(Self);
end;

procedure TLogChart.FitAll;
begin
  if (FData = nil) or (FData.Count < 2) then
    SetWindow(0, 1)
  else
    SetWindow(FData.Times[0], FData.Times[FData.Count - 1]);
end;

procedure TLogChart.Zoom(Factor: Double; const Around: Double);
var
  Span, Rel: Double;
begin
  Span := FT1 - FT0;
  if Span <= 0 then
    Exit;
  Rel := EnsureRange((Around - FT0) / Span, 0, 1);
  Span := Span * Factor;
  SetWindow(Around - Rel * Span, Around - Rel * Span + Span);
end;

procedure TLogChart.KeepVisible(const T: Double);
var
  Span: Double;
begin
  Span := FT1 - FT0;
  if (T > FT1 - Span * 0.05) or (T < FT0) then
    SetWindow(T - Span * 0.2, T - Span * 0.2 + Span);
end;

procedure TLogChart.SetCursorTime(const T: Double; Notify: Boolean);
begin
  if (FData = nil) or (FData.Count = 0) then
    Exit;
  FCursor := EnsureRange(T, FData.Times[0], FData.Times[FData.Count - 1]);
  Invalidate;
  if Notify and Assigned(FOnCursorChange) then
    FOnCursorChange(Self);
end;

function TLogChart.TimeAtX(X: Integer): Double;
begin
  if FPlot.Width <= 0 then
    Exit(FT0);
  Result := FT0 + (X - FPlot.Left) / FPlot.Width * (FT1 - FT0);
end;

function TLogChart.Visible_: TArray<Integer>;
var
  I: Integer;
begin
  Result := nil;
  if FData = nil then
    Exit;
  for I := 0 to FData.ChannelCount - 1 do
    if (I <= High(FStyles)) and FStyles[I].Visible then
      Result := Result + [I];
end;

procedure TLogChart.Scale(Ch: Integer; out Lo, Hi: Double);
begin
  if (Ch <= High(FStyles)) and not FStyles[Ch].AutoScale and (FStyles[Ch].MaxValue > FStyles[Ch].MinValue) then
  begin
    Lo := FStyles[Ch].MinValue;
    Hi := FStyles[Ch].MaxValue;
  end
  else
    AutoRange(FData.Channels[Ch], Lo, Hi);
end;

procedure TLogChart.Paint;
var
  G: TGPGraphics;
  K: Single;
  Vis: TArray<Integer>;
  W, H, I, N, Lane: Integer;
  Lo, Hi, SLo, SHi, Step, Tick, Px: Double;
  LaneTop, LaneH, AxisW, X, Y: Single;
  Ch: Integer;
  S: string;
  Box: TArray<string>;
  BoxColors: TArray<TColor>;

  function Y_(const V, Lo_, Hi_: Double; Top, Height: Single): Single;
  begin
    Result := Top + Height - (V - Lo_) / (Hi_ - Lo_) * Height;
  end;

  function X_(const T_: Double): Single;
  begin
    Result := FPlot.Left + (T_ - FT0) / (FT1 - FT0) * FPlot.Width;
  end;

  { Draws one channel's line in [Top, Top+Height] for scale Lo_..Hi_. Long
    logs are reduced to the lowest and highest value per pixel column. Runs
    where an alert level matches are drawn in the level's colour if wanted. }
  procedure DrawSeries(C: Integer; const Lo_, Hi_: Double; Top, Height: Single);
  var
    Style: TChannelStyle;
    Levels: TArray<TDisplayLevel>;
    UseLevels: Boolean;
    I0, I1, J, Bucket, LastBucket, RunLvl: Integer;
    V, BMin, BMax: Double;
    Pts: TArray<TGPPointF>;
    Pen: TGPPen;
    Decimate: Boolean;
    Vals: TArray<Double>;

    procedure Flush;
    var
      Col: TColor;
    begin
      if Length(Pts) >= 2 then
      begin
        Col := Style.Color;
        if UseLevels and (RunLvl >= 0) and (Levels[RunLvl].RowColor <> clNone) then
          Col := Levels[RunLvl].RowColor;
        Pen.SetColor(GP(Col));
        if UseLevels and (RunLvl >= 0) then
          Pen.SetWidth(Style.Width * K + 1.5)
        else
          Pen.SetWidth(Style.Width * K);
        G.DrawLines(Pen, PGPPointF(@Pts[0]), Length(Pts));
      end;
      if Length(Pts) > 0 then
        Pts := [Pts[High(Pts)]] // the next run starts where this one ended
      else
        Pts := nil;
    end;

    procedure Add(const Tm, Val: Double);
    var
      P: TGPPointF;
      L: Integer;
    begin
      if IsNan(Val) then
      begin
        Flush;
        Pts := nil;
        Exit;
      end;
      L := -1;
      if UseLevels then
        L := LevelIndexFor(Levels, Val);
      if (Length(Pts) > 0) and (L <> RunLvl) then
        Flush;
      RunLvl := L;
      P.X := X_(Tm);
      P.Y := EnsureRange(Y_(Val, Lo_, Hi_, Top, Height), Top - 2, Top + Height + 2);
      Pts := Pts + [P];
    end;

  begin
    Style := FStyles[C];
    Levels := nil;
    if C <= High(FLevels) then
      Levels := FLevels[C];
    UseLevels := Style.LevelColors and (Length(Levels) > 0);
    Vals := FData.Channels[C].Values;
    I0 := Max(0, FData.IndexAt(FT0) - 1);
    I1 := Min(FData.Count - 1, FData.IndexAt(FT1) + 1);
    Decimate := (I1 - I0) > FPlot.Width * 2;
    Pen := TGPPen.Create(GP(Style.Color), Style.Width * K);
    try
      Pen.SetLineJoin(LineJoinRound);
      Pts := nil;
      RunLvl := -2;
      if not Decimate then
        for J := I0 to I1 do
          Add(FData.Times[J], Vals[J])
      else
      begin
        LastBucket := -1;
        BMin := NaN;
        BMax := NaN;
        for J := I0 to I1 do
        begin
          Bucket := Trunc(X_(FData.Times[J]));
          if (Bucket <> LastBucket) and (LastBucket >= 0) then
          begin
            if not IsNan(BMin) then
            begin
              Add(TimeAtX(LastBucket), BMin);
              Add(TimeAtX(LastBucket) + (FT1 - FT0) / FPlot.Width * 0.5, BMax);
            end
            else
              Add(TimeAtX(LastBucket), NaN);
            BMin := NaN;
            BMax := NaN;
          end;
          LastBucket := Bucket;
          V := Vals[J];
          if not IsNan(V) then
          begin
            if IsNan(BMin) or (V < BMin) then
              BMin := V;
            if IsNan(BMax) or (V > BMax) then
              BMax := V;
          end;
        end;
        if (LastBucket >= 0) and not IsNan(BMin) then
        begin
          Add(TimeAtX(LastBucket), BMin);
          Add(TimeAtX(LastBucket), BMax);
        end;
      end;
      Flush;
    finally
      Pen.Free;
    end;
  end;

  procedure DrawBands(C: Integer; const Lo_, Hi_: Double; Top, Height: Single);
  var
    Z: TGaugeZone;
    Y1, Y2: Single;
  begin
    if not FShowBands or (C > High(FLevels)) then
      Exit;
    for Z in ZonesFromLevels(FLevels[C], Lo_, Hi_) do
    begin
      Y1 := Y_(Z.ToValue, Lo_, Hi_, Top, Height);
      Y2 := Y_(Z.FromValue, Lo_, Hi_, Top, Height);
      Fill(G, FPlot.Left, Y1, FPlot.Width, Y2 - Y1, Z.Color, 28);
    end;
  end;

  procedure ValueAtCursor(C: Integer; out V: Double; out Text: string);
  var
    Idx: Integer;
  begin
    Idx := FData.IndexAt(FCursor);
    V := NaN;
    if Idx >= 0 then
      V := FData.Channels[C].Values[Idx];
    Text := FormatValueShort(V);
    if FData.Channels[C].IsSwitch and not IsNan(V) then
      Text := IfThen(V >= 0.5, 'ON', 'OFF');
  end;

  procedure Bubble(const S_: string; Xc, Yc: Single; Col: TColor);
  var
    Tw: Single;
  begin
    Tw := TextWidth(G, S_, 12 * K, True) + 10 * K;
    if Xc + Tw + 6 * K > FPlot.Right then
      Xc := Xc - Tw - 12 * K
    else
      Xc := Xc + 6 * K;
    Yc := EnsureRange(Yc - 9 * K, FPlot.Top, FPlot.Bottom - 18 * K);
    Fill(G, Xc, Yc, Tw, 18 * K, Back, 225);
    Fill(G, Xc, Yc, 3 * K, 18 * K, Col);
    Txt(G, S_, Xc + 5 * K, Yc, Tw - 5 * K, 18 * K, 12 * K, Col, StringAlignmentNear, True);
  end;

var
  V: Double;
  VText: string;
  Lvl: Integer;
begin
  W := ClientWidth;
  H := ClientHeight;
  if (W < 10) or (H < 10) then
    Exit;
  if (FBuffer.Width <> W) or (FBuffer.Height <> H) then
    FBuffer.SetSize(W, H);
  K := CurrentPPI / 96;
  Vis := Visible_;
  N := Length(Vis);
  G := TGPGraphics.Create(FBuffer.Canvas.Handle);
  try
    G.SetSmoothingMode(SmoothingModeAntiAlias);
    G.SetTextRenderingHint(TextRenderingHintAntiAliasGridFit);
    G.Clear(GP(Back));
    // margins
    case FMode of
      cmOverlay: AxisW := Max(1, Min(N, 6)) * 46 * K;
    else
      AxisW := 58 * K;
    end;
    FPlot := Rect(Round(AxisW + 6 * K), Round(8 * K), W - Round(10 * K), H - Round(26 * K));
    if (FData = nil) or (FData.Count < 2) or (FPlot.Width < 20) or (FPlot.Height < 20) then
    begin
      if FData = nil then
        S := 'Open a log (or the demo) to see it here'
      else if N = 0 then
        S := 'Tick channels on the left to chart them'
      else
        S := 'This log has no samples';
      Txt(G, S, 0, 0, W, H, 15 * K, DimText, StringAlignmentCenter);
      Exit;
    end;
    Fill(G, FPlot.Left, FPlot.Top, FPlot.Width, FPlot.Height, PlotBack);

    // time grid and labels
    Step := NiceStep(FT1 - FT0, Max(2, FPlot.Width div Round(90 * K)));
    Tick := Ceil(FT0 / Step) * Step;
    while Tick <= FT1 do
    begin
      X := X_(Tick);
      Line(G, X, FPlot.Top, X, FPlot.Bottom, 1, GridColor);
      Txt(G, FormatLogTime(Tick), X - 40 * K, FPlot.Bottom + 3 * K, 80 * K, 18 * K, 11 * K, DimText,
        StringAlignmentCenter);
      Tick := Tick + Step;
    end;

    if N = 0 then
      Txt(G, 'Tick channels on the left to chart them', FPlot.Left, FPlot.Top, FPlot.Width, FPlot.Height,
        15 * K, DimText, StringAlignmentCenter)
    else
      case FMode of
        cmLanes:
          begin
            LaneH := FPlot.Height / N;
            for Lane := 0 to N - 1 do
            begin
              Ch := Vis[Lane];
              Scale(Ch, Lo, Hi);
              LaneTop := FPlot.Top + Lane * LaneH;
              if Lane > 0 then
                Line(G, FPlot.Left, LaneTop, FPlot.Right, LaneTop, 1, GridColor);
              DrawBands(Ch, Lo, Hi, LaneTop + 3 * K, LaneH - 6 * K);
              DrawSeries(Ch, Lo, Hi, LaneTop + 3 * K, LaneH - 6 * K);
              // labels: name, and the scale on the left
              Txt(G, FData.Channels[Ch].Caption, FPlot.Left + FPlot.Width / 2, LaneTop + 2 * K,
                FPlot.Width / 2 - 8 * K, 16 * K, 12 * K, FStyles[Ch].Color, StringAlignmentFar, True);
              Txt(G, FormatAxis(Hi, (Hi - Lo) / 4), 0, LaneTop + 1 * K, AxisW, 14 * K, 10.5 * K,
                FStyles[Ch].Color, StringAlignmentFar);
              Txt(G, FormatAxis(Lo, (Hi - Lo) / 4), 0, LaneTop + LaneH - 15 * K, AxisW, 14 * K, 10.5 * K,
                FStyles[Ch].Color, StringAlignmentFar);
              ValueAtCursor(Ch, V, VText);
              if not IsNan(V) then
                Bubble(VText + ' ' + FData.Channels[Ch].Units, X_(FCursor),
                  Y_(EnsureRange(V, Lo, Hi), Lo, Hi, LaneTop + 3 * K, LaneH - 6 * K), FStyles[Ch].Color);
            end;
          end;

        cmOverlay:
          begin
            for I := 0 to N - 1 do
            begin
              Ch := Vis[I];
              Scale(Ch, Lo, Hi);
              DrawBands(Ch, Lo, Hi, FPlot.Top, FPlot.Height);
            end;
            for I := 0 to N - 1 do
            begin
              Ch := Vis[I];
              Scale(Ch, Lo, Hi);
              DrawSeries(Ch, Lo, Hi, FPlot.Top, FPlot.Height);
              if I < 6 then
              begin
                // one narrow axis per channel, side by side
                X := I * 46 * K;
                Txt(G, FData.Channels[Ch].Name, X, FPlot.Top, 44 * K, 14 * K, 10 * K, FStyles[Ch].Color,
                  StringAlignmentFar, True);
                Txt(G, FormatAxis(Hi, (Hi - Lo) / 4), X, FPlot.Top + 14 * K, 44 * K, 14 * K, 10.5 * K,
                  FStyles[Ch].Color, StringAlignmentFar);
                Txt(G, FormatAxis((Hi + Lo) / 2, (Hi - Lo) / 4), X, FPlot.Top + FPlot.Height / 2 - 7 * K, 44 * K,
                  14 * K, 10.5 * K, FStyles[Ch].Color, StringAlignmentFar);
                Txt(G, FormatAxis(Lo, (Hi - Lo) / 4), X, FPlot.Bottom - 14 * K, 44 * K, 14 * K, 10.5 * K,
                  FStyles[Ch].Color, StringAlignmentFar);
              end;
            end;
          end;

        cmShared:
          begin
            SLo := NaN;
            SHi := NaN;
            for Ch in Vis do
            begin
              Scale(Ch, Lo, Hi);
              if IsNan(SLo) or (Lo < SLo) then
                SLo := Lo;
              if IsNan(SHi) or (Hi > SHi) then
                SHi := Hi;
            end;
            Step := NiceStep(SHi - SLo, Max(2, FPlot.Height div Round(40 * K)));
            Tick := Ceil(SLo / Step) * Step;
            while Tick <= SHi do
            begin
              Y := Y_(Tick, SLo, SHi, FPlot.Top, FPlot.Height);
              Line(G, FPlot.Left, Y, FPlot.Right, Y, 1, GridColor);
              Txt(G, FormatAxis(Tick, Step), 0, Y - 7 * K, AxisW, 14 * K, 10.5 * K, DimText, StringAlignmentFar);
              Tick := Tick + Step;
            end;
            for Ch in Vis do
              DrawSeries(Ch, SLo, SHi, FPlot.Top, FPlot.Height);
          end;
      end;

    // selected range
    if HasSelection then
    begin
      X := Max(FPlot.Left, X_(Min(FSel0, FSel1)));
      Y := Min(FPlot.Right, X_(Max(FSel0, FSel1)));
      if Y > X then
      begin
        Fill(G, X, FPlot.Top, Y - X, FPlot.Height, TColor($00FFAA46), 38);
        Line(G, X, FPlot.Top, X, FPlot.Bottom, 1, TColor($00FFAA46), 160);
        Line(G, Y, FPlot.Top, Y, FPlot.Bottom, 1, TColor($00FFAA46), 160);
        Txt(G, FormatLogTime(Abs(FSel1 - FSel0)), X, FPlot.Top + 2 * K, Y - X, 14 * K, 10.5 * K,
          TColor($00FFAA46), StringAlignmentCenter, True);
      end;
    end;
    // cursor line
    X := X_(FCursor);
    if (X >= FPlot.Left) and (X <= FPlot.Right) then
    begin
      Line(G, X, FPlot.Top, X, FPlot.Bottom, 1.2 * K, CursorColor, 200);
      Txt(G, FormatLogTime(FCursor), X - 40 * K, FPlot.Bottom + 3 * K, 80 * K, 18 * K, 11 * K, CursorColor,
        StringAlignmentCenter, True);
      // overlay / shared: one box with every value at the cursor
      if (FMode <> cmLanes) and (N > 0) then
      begin
        Box := nil;
        BoxColors := nil;
        Px := 0;
        for Ch in Vis do
        begin
          ValueAtCursor(Ch, V, VText);
          S := FData.Channels[Ch].Name + ':  ' + VText + ' ' + FData.Channels[Ch].Units;
          Box := Box + [S];
          Lvl := -1;
          if (Ch <= High(FLevels)) and not IsNan(V) then
            Lvl := LevelIndexFor(FLevels[Ch], V);
          if (Lvl >= 0) and (FLevels[Ch][Lvl].RowColor <> clNone) then
            BoxColors := BoxColors + [FLevels[Ch][Lvl].RowColor]
          else
            BoxColors := BoxColors + [FStyles[Ch].Color];
          Px := Max(Px, TextWidth(G, S, 12 * K, True));
        end;
        Px := Px + 16 * K;
        if X + Px + 10 * K > FPlot.Right then
          X := X - Px - 8 * K
        else
          X := X + 8 * K;
        Fill(G, X, FPlot.Top + 6 * K, Px, Length(Box) * 17 * K + 8 * K, Back, 230);
        for I := 0 to High(Box) do
        begin
          Fill(G, X + 4 * K, FPlot.Top + 10 * K + I * 17 * K + 4 * K, 6 * K, 9 * K, BoxColors[I]);
          Txt(G, Box[I], X + 13 * K, FPlot.Top + 10 * K + I * 17 * K, Px - 14 * K, 17 * K, 12 * K, BoxColors[I],
            StringAlignmentNear, True);
        end;
      end;
    end;
    if Focused then
      Line(G, 0, H - 1, W, H - 1, 2, TColor($00FFAA46));
  finally
    G.Free;
    Canvas.Draw(0, 0, FBuffer);
  end;
end;

procedure TLogChart.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if CanFocus then
    SetFocus;
  if (FData = nil) or (FData.Count < 2) then
    Exit;
  FDragX := X;
  FDragT0 := FT0;
  FDragT1 := FT1;
  if (Button = mbLeft) and (ssShift in Shift) then
  begin
    FDrag := dgSelect;
    FSel0 := EnsureRange(TimeAtX(X), FData.Times[0], FData.Times[FData.Count - 1]);
    FSel1 := FSel0;
    Invalidate;
  end
  else if Button = mbLeft then
  begin
    FDrag := dgCursor;
    SetCursorTime(TimeAtX(X), True);
  end
  else
  begin
    FDrag := dgPan;
    Cursor := crSizeWE;
  end;
end;

procedure TLogChart.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Dt: Double;
begin
  inherited;
  case FDrag of
    dgCursor:
      SetCursorTime(TimeAtX(X), True);
    dgSelect:
      begin
        FSel1 := EnsureRange(TimeAtX(X), FData.Times[0], FData.Times[FData.Count - 1]);
        Invalidate;
      end;
    dgPan:
      if FPlot.Width > 0 then
      begin
        Dt := (X - FDragX) / FPlot.Width * (FDragT1 - FDragT0);
        SetWindow(FDragT0 - Dt, FDragT1 - Dt);
      end;
  end;
end;

procedure TLogChart.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if FDrag = dgSelect then
  begin
    if Abs(FSel1 - FSel0) < 1E-6 then
      ClearSelection
    else if Assigned(FOnSelectionChange) then
      FOnSelectionChange(Self);
  end;
  FDrag := dgNone;
  Cursor := crDefault;
end;

function TLogChart.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  P: TPoint;
begin
  Result := True;
  P := ScreenToClient(MousePos);
  if WheelDelta > 0 then
    Zoom(0.8, TimeAtX(P.X))
  else
    Zoom(1.25, TimeAtX(P.X));
end;

procedure TLogChart.DblClick;
begin
  inherited;
  FDrag := dgNone;
  FitAll;
end;

function TLogChart.HasSelection: Boolean;
begin
  Result := not IsNan(FSel0) and not IsNan(FSel1) and (Abs(FSel1 - FSel0) > 1E-6);
end;

procedure TLogChart.ClearSelection;
begin
  FSel0 := NaN;
  FSel1 := NaN;
  Invalidate;
  if Assigned(FOnSelectionChange) then
    FOnSelectionChange(Self);
end;

procedure TLogChart.ZoomToSelection;
begin
  if HasSelection then
    SetWindow(Min(FSel0, FSel1), Max(FSel0, FSel1));
end;

procedure TLogChart.SaveImage(const FileName: string);
var
  Png: TPngImage;
begin
  Repaint; // make sure the buffer is current
  Png := TPngImage.Create;
  try
    Png.Assign(FBuffer);
    Png.SaveToFile(FileName);
  finally
    Png.Free;
  end;
end;

end.
