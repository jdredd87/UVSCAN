unit UVScan.LogChart;

{ The log viewer's chart: time on the horizontal axis, one line per visible
  channel, drawn with the FMX canvas.

  Modes: lanes (a strip per channel, each with its own scale), overlay (all
  lines in one area, each on its own scale, with an axis per channel) and
  shared (one scale for everything).

  Mouse: left click / drag = move the cursor, Shift+drag = select a range,
  wheel = zoom time around the mouse, right or middle drag = pan,
  double-click = show the whole log.
  Touch: drag = move the cursor, pinch = zoom (and pan with two fingers),
  double tap = whole log, long press then drag = select a range (or turn on
  SelectMode so a drag selects).

  Live data: with Follow on, ShowLatest shows the last LiveSpan seconds with
  the cursor on the newest sample. Moving the cursor, panning, zooming or
  selecting turns Follow off (pause), so what was just seen can be studied. }

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.TextLayout,
  UVScan.LogData, UVScan.LogViews, UVScan.Display;

type
  TLogChart = class(TControl)
  private type
    TDrag = (dgNone, dgCursor, dgPan, dgSelect);
  private
    FData: TLogData;
    FStyles: TArray<TChannelStyle>;
    FLevels: TArray<TArray<TDisplayLevel>>;
    FMode: TChartMode;
    FT0, FT1: Double;
    FCursor: Double;
    FDrag: TDrag;
    FDragX: Single;
    FDragT0, FDragT1: Double;
    FLastX: Single;
    FPlot: TRectF;
    FShowBands: Boolean;
    FSel0, FSel1: Double;      // selected time range, NaN = none
    FSelectMode: Boolean;
    FPinchDist: Double;
    FPinchX: Single;
    FPinchT0, FPinchT1: Double;
    FLayout: TTextLayout;
    FOnSelectionChange: TNotifyEvent;
    FOnCursorChange: TNotifyEvent;
    FOnWindowChange: TNotifyEvent;
    FFollow: Boolean;
    FLive: Boolean;
    FLiveSpan: Double;
    FOnFollowChange: TNotifyEvent;
    FEmptyText: string;
    FNoSamplesText: string;
    procedure SetFollow(Value: Boolean);
    procedure SetMode(Value: TChartMode);
    procedure SetShowBands(Value: Boolean);
    function TimeAtX(X: Single): Double;
    function Visible_: TArray<Integer>;
    procedure Scale(Ch: Integer; out Lo, Hi: Double);
    procedure SetWindow(T0, T1: Double);
    procedure Txt(const S: string; X, Y, W, H, Size: Single; C: TAlphaColor; Align: TTextAlign;
      Bold: Boolean = False);
    function TextWidth(const S: string; Size: Single; Bold: Boolean = False): Single;
    procedure Fill(X, Y, W, H: Single; C: TAlphaColor; Alpha: Byte = 255);
    procedure Line(X1, Y1, X2, Y2, Width: Single; C: TAlphaColor; Alpha: Byte = 255);
    procedure StartSelect(X: Single);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure DblClick; override;
    procedure CMGesture(var EventInfo: TGestureEventInfo); override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Data is not owned. Styles / Levels: one entry per data channel. }
    procedure SetData(Data: TLogData); reintroduce;
    procedure SetStyles(const Styles: TArray<TChannelStyle>; const Levels: TArray<TArray<TDisplayLevel>>);
    procedure SetCursorTime(const T: Double; Notify: Boolean);
    procedure FitAll;
    procedure Zoom(Factor: Double; const Around: Double);
    { Scrolls the window so T is visible (used while playing back). }
    procedure KeepVisible(const T: Double);
    { Follow: the last LiveSpan seconds, the cursor on the newest sample;
      otherwise just repaints (new samples may change the scales). }
    procedure ShowLatest;
    function WindowStart: Double;
    function WindowEnd: Double;
    function HasSelection: Boolean;
    procedure ClearSelection;
    procedure ZoomToSelection;
    { The chart as it is on screen, for saving as a picture (PNG by extension). }
    procedure SaveImage(const FileName: string);
    property SelStart: Double read FSel0;
    property SelEnd: Double read FSel1;
    property OnSelectionChange: TNotifyEvent read FOnSelectionChange write FOnSelectionChange;
    property CursorTime: Double read FCursor;
    property Mode: TChartMode read FMode write SetMode;
    property ShowBands: Boolean read FShowBands write SetShowBands;
    { A left drag (or a finger) selects a range instead of moving the cursor. }
    property SelectMode: Boolean read FSelectMode write FSelectMode;
    property OnCursorChange: TNotifyEvent read FOnCursorChange write FOnCursorChange;
    property OnWindowChange: TNotifyEvent read FOnWindowChange write FOnWindowChange;
    property Follow: Boolean read FFollow write SetFollow;
    property LiveSpan: Double read FLiveSpan write FLiveSpan;
    { The data is a running scan: a window may be LiveSpan wide even while
      the scan is shorter (as Follow shows it), not just as wide as the data. }
    property Live: Boolean read FLive write FLive;
    property OnFollowChange: TNotifyEvent read FOnFollowChange write FOnFollowChange;
    { Shown with no channels / with channels but under two samples. }
    property EmptyText: string read FEmptyText write FEmptyText;
    property NoSamplesText: string read FNoSamplesText write FNoSamplesText;
    property PopupMenu;
  end;

{ The scale a channel gets with auto scaling: its range plus a little room. }
procedure AutoRange(const Ch: TLogChannel; out Lo, Hi: Double);

implementation

uses
  System.StrUtils;

const
  Back = TAlphaColor($FF161A1E);
  PlotBack = TAlphaColor($FF1B1F26);
  GridColor = TAlphaColor($FF2C323A);
  DimText = TAlphaColor($FF828C96);
  CursorColor = TAlphaColor($FFFFFFFF);
  SelColor = TAlphaColor($FF46AAFF);

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

{ A round step (1, 2, 2.5, 5 x 10^n) giving about Target steps over Range. }
function NiceStep(Range: Double; Target: Integer): Double;
var
  Raw, Mag, F: Double;
begin
  if (Range <= 0) or (Target < 1) then
    Exit(1);
  Raw := Range / Target;
  Mag := Power(10, Floor(Log10(Raw)));
  F := Raw / Mag;
  if F < 1.5 then
    F := 1
  else if F < 2.25 then
    F := 2
  else if F < 3.5 then
    F := 2.5
  else if F < 7.5 then
    F := 5
  else
    F := 10;
  Result := F * Mag;
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
  FMode := cmLanes;
  FSel0 := NaN;
  FSel1 := NaN;
  FShowBands := True;
  FLiveSpan := 60;
  FEmptyText := 'Open a log (or the demo) to see it here';
  FNoSamplesText := 'This log has no samples';
  CanFocus := True;
  TabStop := True;
  HitTest := True;
  ClipChildren := True;
  FLayout := TTextLayoutManager.DefaultTextLayout.Create;
  Touch.InteractiveGestures := [TInteractiveGesture.Zoom, TInteractiveGesture.DoubleTap,
    TInteractiveGesture.LongTap];
end;

destructor TLogChart.Destroy;
begin
  FLayout.Free;
  inherited;
end;

procedure TLogChart.Txt(const S: string; X, Y, W, H, Size: Single; C: TAlphaColor; Align: TTextAlign;
  Bold: Boolean);
begin
  if (S = '') or (W <= 0) or (H <= 0) then
    Exit;
  FLayout.BeginUpdate;
  try
    FLayout.TopLeft := TPointF.Create(X, Y);
    FLayout.MaxSize := TPointF.Create(W, H);
    FLayout.Text := S;
    FLayout.WordWrap := False;
    FLayout.Trimming := TTextTrimming.Character;
    FLayout.Font.Size := Size;
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

function TLogChart.TextWidth(const S: string; Size: Single; Bold: Boolean): Single;
begin
  FLayout.BeginUpdate;
  try
    FLayout.TopLeft := TPointF.Zero;
    FLayout.MaxSize := TPointF.Create(10000, 100);
    FLayout.Text := S;
    FLayout.WordWrap := False;
    FLayout.Trimming := TTextTrimming.None;
    FLayout.Font.Size := Size;
    if Bold then
      FLayout.Font.Style := [TFontStyle.fsBold]
    else
      FLayout.Font.Style := [];
  finally
    FLayout.EndUpdate;
  end;
  Result := FLayout.TextWidth;
end;

procedure TLogChart.Fill(X, Y, W, H: Single; C: TAlphaColor; Alpha: Byte);
begin
  if (W <= 0) or (H <= 0) then
    Exit;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := (C and $00FFFFFF) or (TAlphaColor(Alpha) shl 24);
  Canvas.FillRect(TRectF.Create(X, Y, X + W, Y + H), 0, 0, [], 1);
end;

procedure TLogChart.Line(X1, Y1, X2, Y2, Width: Single; C: TAlphaColor; Alpha: Byte);
begin
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Dash := TStrokeDash.Solid;
  Canvas.Stroke.Thickness := Width;
  Canvas.Stroke.Color := (C and $00FFFFFF) or (TAlphaColor(Alpha) shl 24);
  Canvas.DrawLine(TPointF.Create(X1, Y1), TPointF.Create(X2, Y2), 1);
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
  Repaint;
end;

procedure TLogChart.SetMode(Value: TChartMode);
begin
  if FMode <> Value then
  begin
    FMode := Value;
    Repaint;
  end;
end;

procedure TLogChart.SetShowBands(Value: Boolean);
begin
  if FShowBands <> Value then
  begin
    FShowBands := Value;
    Repaint;
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

procedure TLogChart.SetFollow(Value: Boolean);
begin
  if FFollow = Value then
    Exit;
  FFollow := Value;
  if Value then
    ShowLatest;
  if Assigned(FOnFollowChange) then
    FOnFollowChange(Self);
end;

procedure TLogChart.ShowLatest;
var
  First, Last: Double;
begin
  if FFollow and (FData <> nil) and (FData.Count > 0) then
  begin
    First := FData.Times[0];
    Last := FData.Times[FData.Count - 1];
    // Until there is a full span, the line grows from the left edge.
    FT1 := Max(Last, First + FLiveSpan);
    FT0 := FT1 - FLiveSpan;
    FCursor := Last;
    if Assigned(FOnWindowChange) then
      FOnWindowChange(Self);
  end;
  Repaint;
end;

procedure TLogChart.SetWindow(T0, T1: Double);
var
  First, Last, Span, MinSpan, MaxSpan: Double;
begin
  Follow := False;
  if (FData = nil) or (FData.Count < 2) then
  begin
    FT0 := 0;
    FT1 := 1;
    Repaint;
    Exit;
  end;
  First := FData.Times[0];
  Last := FData.Times[FData.Count - 1];
  MinSpan := Min(Last - First, 2);
  MaxSpan := Last - First;
  if FLive then
    MaxSpan := Max(MaxSpan, FLiveSpan); // pausing a short scan keeps its span
  Span := Max(MinSpan, T1 - T0);
  Span := Min(Span, MaxSpan);
  if T0 + Span > Last then
    T0 := Last - Span;
  if T0 < First then
    T0 := First; // a live span longer than the scan: from its start, as Follow shows it
  FT0 := T0;
  FT1 := T0 + Span;
  Repaint;
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
  Follow := False;
  FCursor := EnsureRange(T, FData.Times[0], FData.Times[FData.Count - 1]);
  Repaint;
  if Notify and Assigned(FOnCursorChange) then
    FOnCursorChange(Self);
end;

function TLogChart.TimeAtX(X: Single): Double;
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
  Vis: TArray<Integer>;
  W, H: Single;
  I, N, Lane: Integer;
  Lo, Hi, SLo, SHi, Step, Tick, Px: Double;
  LaneTop, LaneH, AxisW, X, Y: Single;
  Ch: Integer;
  S: string;
  Box: TArray<string>;
  BoxColors: TArray<TAlphaColor>;
  State: TCanvasSaveState;

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
    I0, I1, J, Bucket, LastBucket, RunLvl, NPts: Integer;
    V, BMin, BMax: Double;
    Pts: TArray<TPointF>;
    Decimate: Boolean;
    Vals: TArray<Double>;
    Path: TPathData;

    procedure Flush;
    var
      Col: TAlphaColor;
      K: Integer;
    begin
      if NPts >= 2 then
      begin
        Col := Style.Color;
        if UseLevels and (RunLvl >= 0) and (Levels[RunLvl].RowColor <> NoColor) then
          Col := Levels[RunLvl].RowColor;
        Canvas.Stroke.Kind := TBrushKind.Solid;
        Canvas.Stroke.Color := Col;
        Canvas.Stroke.Join := TStrokeJoin.Round;
        Canvas.Stroke.Cap := TStrokeCap.Round;
        Canvas.Stroke.Dash := TStrokeDash.Solid;
        if UseLevels and (RunLvl >= 0) then
          Canvas.Stroke.Thickness := Style.Width + 1.5
        else
          Canvas.Stroke.Thickness := Style.Width;
        Path.Clear;
        Path.MoveTo(Pts[0]);
        for K := 1 to NPts - 1 do
          Path.LineTo(Pts[K]);
        Canvas.DrawPath(Path, 1);
      end;
      if NPts > 0 then
      begin
        Pts[0] := Pts[NPts - 1]; // the next run starts where this one ended
        NPts := 1;
      end;
    end;

    procedure Add(const Tm, Val: Double);
    var
      L: Integer;
    begin
      if IsNan(Val) then
      begin
        Flush;
        NPts := 0;
        Exit;
      end;
      L := -1;
      if UseLevels then
        L := LevelIndexFor(Levels, Val);
      if (NPts > 0) and (L <> RunLvl) then
        Flush;
      RunLvl := L;
      if NPts >= Length(Pts) then
        SetLength(Pts, Max(64, Length(Pts) * 2));
      Pts[NPts] := TPointF.Create(X_(Tm), EnsureRange(Y_(Val, Lo_, Hi_, Top, Height), Top - 2, Top + Height + 2));
      Inc(NPts);
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
    Path := TPathData.Create;
    try
      Pts := nil;
      NPts := 0;
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
      Path.Free;
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
      Fill(FPlot.Left, Y1, FPlot.Width, Y2 - Y1, Z.Color, 28);
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

  procedure Bubble(const S_: string; Xc, Yc: Single; Col: TAlphaColor);
  var
    Tw: Single;
  begin
    Tw := TextWidth(S_, 12, True) + 10;
    if Xc + Tw + 6 > FPlot.Right then
      Xc := Xc - Tw - 12
    else
      Xc := Xc + 6;
    Yc := EnsureRange(Yc - 9, FPlot.Top, FPlot.Bottom - 18);
    Fill(Xc, Yc, Tw, 18, Back, 225);
    Fill(Xc, Yc, 3, 18, Col);
    Txt(S_, Xc + 5, Yc, Tw - 5, 18, 12, Col, TTextAlign.Leading, True);
  end;

var
  V: Double;
  VText: string;
  Lvl: Integer;
begin
  W := Width;
  H := Height;
  if (W < 10) or (H < 10) then
    Exit;
  Vis := Visible_;
  N := Length(Vis);
  State := Canvas.SaveState;
  try
    Canvas.IntersectClipRect(LocalRect);
    Fill(0, 0, W, H, Back);
    // margins
    case FMode of
      cmOverlay: AxisW := Max(1, Min(N, 6)) * 46;
    else
      AxisW := 58;
    end;
    FPlot := TRectF.Create(Round(AxisW + 6), 8, Round(W - 10), Round(H - 26));
    if (FData = nil) or (FData.Count < 2) or (FPlot.Width < 20) or (FPlot.Height < 20) then
    begin
      if (FData = nil) or (FData.ChannelCount = 0) then
        S := FEmptyText
      else if N = 0 then
        S := 'Tick channels on the left to chart them'
      else if FData.Count < 2 then
        S := FNoSamplesText
      else
        S := '';
      Txt(S, 0, 0, W, H, 15, DimText, TTextAlign.Center);
      Exit;
    end;
    Fill(FPlot.Left, FPlot.Top, FPlot.Width, FPlot.Height, PlotBack);

    // time grid and labels (not under the cursor's time)
    Step := NiceStep(FT1 - FT0, Max(2, Trunc(FPlot.Width / 90)));
    Tick := Ceil(FT0 / Step) * Step;
    while Tick <= FT1 do
    begin
      X := X_(Tick);
      Line(X, FPlot.Top, X, FPlot.Bottom, 1, GridColor);
      if Abs(X - X_(FCursor)) > 50 then
        Txt(FormatLogTime(Tick), X - 40, FPlot.Bottom + 3, 80, 18, 11, DimText, TTextAlign.Center);
      Tick := Tick + Step;
    end;

    if N = 0 then
      Txt('Tick channels on the left to chart them', FPlot.Left, FPlot.Top, FPlot.Width, FPlot.Height,
        15, DimText, TTextAlign.Center)
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
                Line(FPlot.Left, LaneTop, FPlot.Right, LaneTop, 1, GridColor);
              DrawBands(Ch, Lo, Hi, LaneTop + 3, LaneH - 6);
              DrawSeries(Ch, Lo, Hi, LaneTop + 3, LaneH - 6);
              // labels: name, and the scale on the left
              Txt(FData.Channels[Ch].Caption, FPlot.Left + FPlot.Width / 2, LaneTop + 2,
                FPlot.Width / 2 - 8, 16, 12, FStyles[Ch].Color, TTextAlign.Trailing, True);
              Txt(FormatAxis(Hi, (Hi - Lo) / 4), 0, LaneTop + 1, AxisW, 14, 10.5, FStyles[Ch].Color,
                TTextAlign.Trailing);
              Txt(FormatAxis(Lo, (Hi - Lo) / 4), 0, LaneTop + LaneH - 15, AxisW, 14, 10.5, FStyles[Ch].Color,
                TTextAlign.Trailing);
              ValueAtCursor(Ch, V, VText);
              if not IsNan(V) then
                Bubble(VText + ' ' + FData.Channels[Ch].Units, X_(FCursor),
                  Y_(EnsureRange(V, Lo, Hi), Lo, Hi, LaneTop + 3, LaneH - 6), FStyles[Ch].Color);
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
                X := I * 46;
                Txt(FData.Channels[Ch].Name, X, FPlot.Top, 44, 14, 10, FStyles[Ch].Color, TTextAlign.Trailing, True);
                Txt(FormatAxis(Hi, (Hi - Lo) / 4), X, FPlot.Top + 14, 44, 14, 10.5, FStyles[Ch].Color,
                  TTextAlign.Trailing);
                Txt(FormatAxis((Hi + Lo) / 2, (Hi - Lo) / 4), X, FPlot.Top + FPlot.Height / 2 - 7, 44, 14, 10.5,
                  FStyles[Ch].Color, TTextAlign.Trailing);
                Txt(FormatAxis(Lo, (Hi - Lo) / 4), X, FPlot.Bottom - 14, 44, 14, 10.5, FStyles[Ch].Color,
                  TTextAlign.Trailing);
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
            Step := NiceStep(SHi - SLo, Max(2, Trunc(FPlot.Height / 40)));
            Tick := Ceil(SLo / Step) * Step;
            while Tick <= SHi do
            begin
              Y := Y_(Tick, SLo, SHi, FPlot.Top, FPlot.Height);
              Line(FPlot.Left, Y, FPlot.Right, Y, 1, GridColor);
              Txt(FormatAxis(Tick, Step), 0, Y - 7, AxisW, 14, 10.5, DimText, TTextAlign.Trailing);
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
        Fill(X, FPlot.Top, Y - X, FPlot.Height, SelColor, 38);
        Line(X, FPlot.Top, X, FPlot.Bottom, 1, SelColor, 160);
        Line(Y, FPlot.Top, Y, FPlot.Bottom, 1, SelColor, 160);
        Txt(FormatLogTime(Abs(FSel1 - FSel0)), X, FPlot.Top + 2, Y - X, 14, 10.5, SelColor, TTextAlign.Center, True);
      end;
    end;
    // cursor line
    X := X_(FCursor);
    if (X >= FPlot.Left) and (X <= FPlot.Right) then
    begin
      Line(X, FPlot.Top, X, FPlot.Bottom, 1.2, CursorColor, 200);
      Txt(FormatLogTime(FCursor), X - 40, FPlot.Bottom + 3, 80, 18, 11, CursorColor, TTextAlign.Center, True);
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
          if (Lvl >= 0) and (FLevels[Ch][Lvl].RowColor <> NoColor) then
            BoxColors := BoxColors + [FLevels[Ch][Lvl].RowColor]
          else
            BoxColors := BoxColors + [FStyles[Ch].Color];
          Px := Max(Px, TextWidth(S, 12, True));
        end;
        Px := Px + 16;
        if X + Px + 10 > FPlot.Right then
          X := X - Px - 8
        else
          X := X + 8;
        Fill(X, FPlot.Top + 6, Px, Length(Box) * 17 + 8, Back, 230);
        for I := 0 to High(Box) do
        begin
          Fill(X + 4, FPlot.Top + 10 + I * 17 + 4, 6, 9, BoxColors[I]);
          Txt(Box[I], X + 13, FPlot.Top + 10 + I * 17, Px - 14, 17, 12, BoxColors[I], TTextAlign.Leading, True);
        end;
      end;
    end;
    if IsFocused then
      Line(0, H - 1, W, H - 1, 2, SelColor);
  finally
    Canvas.RestoreState(State);
  end;
end;

procedure TLogChart.DoEnter;
begin
  inherited;
  Repaint;
end;

procedure TLogChart.DoExit;
begin
  inherited;
  Repaint;
end;

procedure TLogChart.StartSelect(X: Single);
begin
  Follow := False;
  FDrag := dgSelect;
  FSel0 := EnsureRange(TimeAtX(X), FData.Times[0], FData.Times[FData.Count - 1]);
  FSel1 := FSel0;
  Repaint;
end;

procedure TLogChart.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if CanFocus and not IsFocused then
    SetFocus;
  FLastX := X;
  if (FData = nil) or (FData.Count < 2) then
    Exit;
  FDragX := X;
  FDragT0 := FT0;
  FDragT1 := FT1;
  if (Button = TMouseButton.mbLeft) and ((ssShift in Shift) or FSelectMode) then
    StartSelect(X)
  else if Button = TMouseButton.mbLeft then
  begin
    FDrag := dgCursor;
    SetCursorTime(TimeAtX(X), True);
  end
  else
  begin
    Follow := False;
    FDrag := dgPan;
    Cursor := crSizeWE;
  end;
end;

procedure TLogChart.MouseMove(Shift: TShiftState; X, Y: Single);
var
  Dt: Double;
begin
  inherited;
  FLastX := X;
  case FDrag of
    dgCursor:
      SetCursorTime(TimeAtX(X), True);
    dgSelect:
      begin
        FSel1 := EnsureRange(TimeAtX(X), FData.Times[0], FData.Times[FData.Count - 1]);
        Repaint;
      end;
    dgPan:
      if FPlot.Width > 0 then
      begin
        Dt := (X - FDragX) / FPlot.Width * (FDragT1 - FDragT0);
        SetWindow(FDragT0 - Dt, FDragT1 - Dt);
      end;
  end;
end;

procedure TLogChart.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
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

procedure TLogChart.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited;
  if Handled then
    Exit;
  Handled := True;
  if WheelDelta > 0 then
    Zoom(0.8, TimeAtX(FLastX))
  else
    Zoom(1.25, TimeAtX(FLastX));
end;

procedure TLogChart.DblClick;
begin
  inherited;
  FDrag := dgNone;
  FitAll;
end;

{ Touch: pinch zooms around the fingers and pans as they move; double tap
  shows everything; a long press starts a range selection there. }
procedure TLogChart.CMGesture(var EventInfo: TGestureEventInfo);
var
  P: TPointF;
  Span, Center, Rel: Double;
begin
  if (FData = nil) or (FData.Count < 2) then
  begin
    inherited;
    Exit;
  end;
  P := AbsoluteToLocal(EventInfo.Location);
  case EventInfo.GestureID of
    igiZoom:
      begin
        FDrag := dgNone;
        if (TInteractiveGestureFlag.gfBegin in EventInfo.Flags) or (FPinchDist <= 0) then
        begin
          FPinchDist := Max(1, EventInfo.Distance);
          FPinchX := P.X;
          FPinchT0 := FT0;
          FPinchT1 := FT1;
        end
        else if EventInfo.Distance > 0 then
        begin
          // The time under the first pinch centre stays under the fingers.
          Span := (FPinchT1 - FPinchT0) * FPinchDist / EventInfo.Distance;
          Center := FPinchT0 + (FPinchX - FPlot.Left) / Max(1, FPlot.Width) * (FPinchT1 - FPinchT0);
          Rel := (P.X - FPlot.Left) / Max(1, FPlot.Width);
          SetWindow(Center - Rel * Span, Center - Rel * Span + Span);
        end;
        if TInteractiveGestureFlag.gfEnd in EventInfo.Flags then
          FPinchDist := 0;
      end;
    igiDoubleTap:
      FitAll;
    igiLongTap:
        StartSelect(P.X); // the finger is still down: dragging extends the range
  else
    inherited;
  end;
end;

function TLogChart.HasSelection: Boolean;
begin
  Result := not IsNan(FSel0) and not IsNan(FSel1) and (Abs(FSel1 - FSel0) > 1E-6);
end;

procedure TLogChart.ClearSelection;
begin
  FSel0 := NaN;
  FSel1 := NaN;
  Repaint;
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
  Bmp: TBitmap;
begin
  Bmp := MakeScreenshot;
  try
    Bmp.SaveToFile(FileName);
  finally
    Bmp.Free;
  end;
end;

end.
