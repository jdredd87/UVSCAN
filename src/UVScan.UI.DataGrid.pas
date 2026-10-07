unit UVScan.UI.DataGrid;

{ A light, virtual grid for FMX: the owner supplies cell text and colours
  through events, so thousands of rows cost nothing and a cell can change ten
  times a second without rebuilding anything. Used for the live data, the
  log grid and the lists (PIDs, controls, codes, levels, ...).

  - Columns are set up in code (AddColumn); a Stretch column takes the room
    the others leave. Header borders can be dragged to resize.
  - Optional check box in the first column (OnGetChecked / OnToggleCheck).
  - Optional group rows (OnIsGroupRow): a full-width band, not selectable.
  - Rows can be taller than RowHeight (RowHeights[]).
  - Mouse wheel, scroll bar, keyboard, and dragging with a finger scroll. }

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.StdCtrls, FMX.TextLayout;

type
  TGridAlign = (gaLeft, gaRight, gaCenter);

  TCellStyle = record
    Back: TAlphaColor;      // 0 = the row's normal background
    Fore: TAlphaColor;      // 0 = normal text colour
    Bold: Boolean;
    FontSize: Single;       // 0 = the grid's FontSize
  end;

  TGridTextEvent = procedure(Sender: TObject; Col, Row: Integer; var Text: string) of object;
  TGridStyleEvent = procedure(Sender: TObject; Col, Row: Integer; var Style: TCellStyle) of object;
  TGridRowEvent = procedure(Sender: TObject; Row: Integer) of object;
  TGridCheckedEvent = procedure(Sender: TObject; Row: Integer; var Checked: Boolean) of object;
  TGridGroupEvent = procedure(Sender: TObject; Row: Integer; var IsGroup: Boolean) of object;
  TGridColEvent = procedure(Sender: TObject; Col: Integer) of object;

  TGridColumn = record
    Caption: string;
    Width: Single;
    Align: TGridAlign;
    Stretch: Boolean;
    Visible: Boolean;
  end;

  TDataGrid = class(TControl)
  private
    FColumns: TArray<TGridColumn>;
    FRowCount: Integer;
    FRowHeight: Single;
    FRowHeights: TArray<Single>;
    FHeaderHeight: Single;
    FShowHeader: Boolean;
    FFontSize: Single;
    FFontFamily: string;
    FTopRow: Integer;
    FItemIndex: Integer;
    FCheckboxes: Boolean;
    FStriped: Boolean;
    FGridLines: Boolean;
    FCellPadding: Single;
    FScrollBar: TScrollBar;
    FLayout: TTextLayout;
    FUpdatingScroll: Boolean;
    // colours
    FBackColor, FAltColor, FTextColor, FHeaderColor, FHeaderTextColor, FLineColor,
    FSelColor, FSelTextColor, FSelInactiveColor, FGroupColor, FGroupTextColor, FDimTextColor: TAlphaColor;
    // mouse
    FDownPos: TPointF;
    FDown: Boolean;
    FDragScroll: Boolean;
    FDragTop: Integer;
    FResizeCol: Integer;
    FResizeStartX, FResizeStartW: Single;
    FLastMouse: TPointF;
    // events
    FOnGetText: TGridTextEvent;
    FOnGetStyle: TGridStyleEvent;
    FOnSelect: TNotifyEvent;
    FOnRowDblClick: TGridRowEvent;
    FOnGetChecked: TGridCheckedEvent;
    FOnToggleCheck: TGridRowEvent;
    FOnIsGroupRow: TGridGroupEvent;
    FOnHeaderClick: TGridColEvent;
    FOnTopRowChange: TNotifyEvent;
    procedure SetRowCount(Value: Integer);
    procedure SetRowHeight(Value: Single);
    procedure SetFontSize(Value: Single);
    procedure SetItemIndex(Value: Integer);
    procedure SetTopRow(Value: Integer);
    procedure SetShowHeader(Value: Boolean);
    procedure SetCheckboxes(Value: Boolean);
    function GetRowHeights(Row: Integer): Single;
    procedure SetRowHeights(Row: Integer; Value: Single);
    function GetColumn(Index: Integer): TGridColumn;
    function GetColumnCount: Integer;
    procedure ScrollChange(Sender: TObject);
    procedure UpdateScrollBar;
    function DataTop: Single;
    function DataBottom: Single;
    function ColumnWidths: TArray<Single>;
    function HeaderBorderAt(X, Y: Single): Integer;
    procedure DrawText(const R: TRectF; const S: string; Align: TGridAlign; Color: TAlphaColor; Size: Single;
      Bold: Boolean);
    procedure DrawCheck(const R: TRectF; Checked: Boolean; Color: TAlphaColor);
    function CheckRect(const RowRect: TRectF): TRectF;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure DblClick; override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddColumn(const Caption: string; Width: Single; Align: TGridAlign = gaLeft;
      Stretch: Boolean = False): Integer;
    procedure ClearColumns;
    procedure SetColumnCaption(Index: Integer; const Caption: string);
    procedure SetColumnWidth(Index: Integer; Width: Single);
    procedure SetColumnVisible(Index: Integer; Visible: Boolean);
    { Rows that fit on screen from TopRow on (at least 1). }
    function VisibleRows: Integer;
    function RowAt(Y: Single): Integer;      // -1 = header / below the last row
    function ColAt(X: Single): Integer;
    function RowRect(Row: Integer): TRectF;  // empty when scrolled out of view
    procedure ScrollIntoView(Row: Integer);
    function IsGroupRow(Row: Integer): Boolean;
    { Repaints (the whole grid; FMX draws the control in one go). }
    procedure Refresh;
    procedure ResetRowHeights;
    property Columns[Index: Integer]: TGridColumn read GetColumn;
    property ColumnCount: Integer read GetColumnCount;
    property RowHeights[Row: Integer]: Single read GetRowHeights write SetRowHeights;
    property TopRow: Integer read FTopRow write SetTopRow;
    property ItemIndex: Integer read FItemIndex write SetItemIndex;
    // colours (light theme by default)
    property BackColor: TAlphaColor read FBackColor write FBackColor;
    property AltColor: TAlphaColor read FAltColor write FAltColor;
    property TextColor: TAlphaColor read FTextColor write FTextColor;
    property DimTextColor: TAlphaColor read FDimTextColor write FDimTextColor;
    property HeaderColor: TAlphaColor read FHeaderColor write FHeaderColor;
    property SelColor: TAlphaColor read FSelColor write FSelColor;
    property GroupColor: TAlphaColor read FGroupColor write FGroupColor;
  published
    property Align;
    property Anchors;
    property Margins;
    property Position;
    property Width;
    property Height;
    property Size;
    property Visible;
    property Enabled;
    property PopupMenu;
    property TabOrder;
    property TabStop;
    property CanFocus default True;
    property HitTest default True;
    property RowCount: Integer read FRowCount write SetRowCount default 0;
    property RowHeight: Single read FRowHeight write SetRowHeight;
    property HeaderHeight: Single read FHeaderHeight write FHeaderHeight;
    property ShowHeader: Boolean read FShowHeader write SetShowHeader default True;
    property FontSize: Single read FFontSize write SetFontSize;
    property FontFamily: string read FFontFamily write FFontFamily;
    property Checkboxes: Boolean read FCheckboxes write SetCheckboxes default False;
    property Striped: Boolean read FStriped write FStriped default True;
    property GridLines: Boolean read FGridLines write FGridLines default True;
    property CellPadding: Single read FCellPadding write FCellPadding;
    property OnGetText: TGridTextEvent read FOnGetText write FOnGetText;
    property OnGetStyle: TGridStyleEvent read FOnGetStyle write FOnGetStyle;
    property OnSelect: TNotifyEvent read FOnSelect write FOnSelect;
    property OnRowDblClick: TGridRowEvent read FOnRowDblClick write FOnRowDblClick;
    property OnGetChecked: TGridCheckedEvent read FOnGetChecked write FOnGetChecked;
    property OnToggleCheck: TGridRowEvent read FOnToggleCheck write FOnToggleCheck;
    property OnIsGroupRow: TGridGroupEvent read FOnIsGroupRow write FOnIsGroupRow;
    property OnHeaderClick: TGridColEvent read FOnHeaderClick write FOnHeaderClick;
    property OnTopRowChange: TNotifyEvent read FOnTopRowChange write FOnTopRowChange;
    property OnMouseDown;
    property OnMouseUp;
    property OnKeyDown;
    property OnResize;
    { Runs before the grid scrolls; set Handled to stop it (e.g. Ctrl+wheel zoom). }
    property OnMouseWheel;
    property OnGesture;
    property Touch;
  end;

implementation

const
  DragThreshold = 6;
  ResizeGrip = 4;
  MinColumnWidth = 24;

{ TDataGrid }

constructor TDataGrid.Create(AOwner: TComponent);
begin
  inherited;
  CanFocus := True;
  TabStop := True;
  HitTest := True;
  ClipChildren := True;
  FRowHeight := 28;
  FHeaderHeight := 28;
  FShowHeader := True;
  FFontSize := 13;
  FFontFamily := '';
  FItemIndex := -1;
  FStriped := True;
  FGridLines := True;
  FCellPadding := 6;
  FResizeCol := -1;
  FBackColor := TAlphaColors.White;
  FAltColor := $FFF0F3F7;
  FTextColor := $FF1E1E1E;
  FDimTextColor := $FF808080;
  FHeaderColor := $FFE9ECF0;
  FHeaderTextColor := $FF202020;
  FLineColor := $FFDADDE2;
  FSelColor := $FF0078D7;
  FSelTextColor := TAlphaColors.White;
  FSelInactiveColor := $FFCCE4F7;
  FGroupColor := $FFDDE6F0;
  FGroupTextColor := $FF1F3F66;
  FLayout := TTextLayoutManager.DefaultTextLayout.Create;
  FScrollBar := TScrollBar.Create(Self);
  FScrollBar.Parent := Self;
  FScrollBar.Stored := False;
  FScrollBar.Orientation := TOrientation.Vertical;
  FScrollBar.Align := TAlignLayout.Right;
  FScrollBar.Width := 14;
  FScrollBar.SmallChange := 1;
  FScrollBar.Visible := False;
  FScrollBar.OnChange := ScrollChange;
  Width := 300;
  Height := 200;
end;

destructor TDataGrid.Destroy;
begin
  FLayout.Free;
  inherited;
end;

function TDataGrid.AddColumn(const Caption: string; Width: Single; Align: TGridAlign; Stretch: Boolean): Integer;
var
  C: TGridColumn;
begin
  C.Caption := Caption;
  C.Width := Width;
  C.Align := Align;
  C.Stretch := Stretch;
  C.Visible := True;
  FColumns := FColumns + [C];
  Result := High(FColumns);
  Repaint;
end;

procedure TDataGrid.ClearColumns;
begin
  FColumns := nil;
  Repaint;
end;

procedure TDataGrid.SetColumnCaption(Index: Integer; const Caption: string);
begin
  if FColumns[Index].Caption <> Caption then
  begin
    FColumns[Index].Caption := Caption;
    Repaint;
  end;
end;

procedure TDataGrid.SetColumnWidth(Index: Integer; Width: Single);
begin
  FColumns[Index].Width := Width;
  Repaint;
end;

procedure TDataGrid.SetColumnVisible(Index: Integer; Visible: Boolean);
begin
  if FColumns[Index].Visible <> Visible then
  begin
    FColumns[Index].Visible := Visible;
    Repaint;
  end;
end;

function TDataGrid.GetColumn(Index: Integer): TGridColumn;
begin
  Result := FColumns[Index];
end;

function TDataGrid.GetColumnCount: Integer;
begin
  Result := Length(FColumns);
end;

function TDataGrid.GetRowHeights(Row: Integer): Single;
begin
  if (Row >= 0) and (Row <= High(FRowHeights)) and (FRowHeights[Row] > 0) then
    Result := Max(FRowHeights[Row], FRowHeight)
  else
    Result := FRowHeight;
end;

procedure TDataGrid.SetRowHeights(Row: Integer; Value: Single);
begin
  if Row < 0 then
    Exit;
  if Row > High(FRowHeights) then
    SetLength(FRowHeights, Max(Row + 1, FRowCount));
  FRowHeights[Row] := Value;
  UpdateScrollBar;
  Repaint;
end;

procedure TDataGrid.ResetRowHeights;
begin
  FRowHeights := nil;
  UpdateScrollBar;
  Repaint;
end;

procedure TDataGrid.SetRowCount(Value: Integer);
begin
  Value := Max(0, Value);
  if Value = FRowCount then
    Exit;
  FRowCount := Value;
  if Length(FRowHeights) > FRowCount then
    SetLength(FRowHeights, FRowCount);
  if FItemIndex >= FRowCount then
    FItemIndex := FRowCount - 1;
  if FTopRow > Max(0, FRowCount - 1) then
    FTopRow := Max(0, FRowCount - 1);
  UpdateScrollBar;
  Repaint;
end;

procedure TDataGrid.SetRowHeight(Value: Single);
begin
  if SameValue(Value, FRowHeight) then
    Exit;
  FRowHeight := Max(8, Value);
  UpdateScrollBar;
  Repaint;
end;

procedure TDataGrid.SetFontSize(Value: Single);
begin
  if SameValue(Value, FFontSize) then
    Exit;
  FFontSize := Max(5, Value);
  Repaint;
end;

procedure TDataGrid.SetShowHeader(Value: Boolean);
begin
  FShowHeader := Value;
  UpdateScrollBar;
  Repaint;
end;

procedure TDataGrid.SetCheckboxes(Value: Boolean);
begin
  FCheckboxes := Value;
  Repaint;
end;

function TDataGrid.IsGroupRow(Row: Integer): Boolean;
begin
  Result := False;
  if Assigned(FOnIsGroupRow) and (Row >= 0) and (Row < FRowCount) then
    FOnIsGroupRow(Self, Row, Result);
end;

procedure TDataGrid.SetItemIndex(Value: Integer);
begin
  Value := EnsureRange(Value, -1, FRowCount - 1);
  if Value = FItemIndex then
    Exit;
  FItemIndex := Value;
  if FItemIndex >= 0 then
    ScrollIntoView(FItemIndex);
  Repaint;
  if Assigned(FOnSelect) then
    FOnSelect(Self);
end;

procedure TDataGrid.SetTopRow(Value: Integer);
begin
  Value := EnsureRange(Value, 0, Max(0, FRowCount - 1));
  if Value = FTopRow then
    Exit;
  FTopRow := Value;
  UpdateScrollBar;
  Repaint;
  if Assigned(FOnTopRowChange) then
    FOnTopRowChange(Self);
end;

function TDataGrid.DataTop: Single;
begin
  if FShowHeader then
    Result := FHeaderHeight
  else
    Result := 0;
end;

function TDataGrid.DataBottom: Single;
begin
  Result := Height;
end;

function TDataGrid.VisibleRows: Integer;
var
  Y: Single;
  R: Integer;
begin
  Result := 0;
  Y := DataTop;
  R := FTopRow;
  while (R < FRowCount) and (Y + GetRowHeights(R) <= DataBottom + 0.5) do
  begin
    Y := Y + GetRowHeights(R);
    Inc(R);
    Inc(Result);
  end;
  if Result = 0 then
    Result := 1;
end;

{ The largest TopRow that still fills the view. }
function LastTopRow(Grid: TDataGrid): Integer;
var
  Y: Single;
begin
  Result := Grid.FRowCount;
  Y := Grid.DataBottom - Grid.DataTop;
  while (Result > 0) and (Y - Grid.GetRowHeights(Result - 1) >= -0.5) do
  begin
    Y := Y - Grid.GetRowHeights(Result - 1);
    Dec(Result);
  end;
  Result := Max(0, Result);
end;

procedure TDataGrid.UpdateScrollBar;
var
  Last: Integer;
begin
  if FScrollBar = nil then
    Exit;
  Last := LastTopRow(Self);
  if FTopRow > Last then
    FTopRow := Last;
  FUpdatingScroll := True;
  try
    FScrollBar.Visible := Last > 0;
    if FScrollBar.Visible then
    begin
      FScrollBar.Margins.Top := DataTop;
      FScrollBar.Min := 0;
      FScrollBar.Max := Last + VisibleRows;
      FScrollBar.ViewportSize := VisibleRows;
      FScrollBar.Value := FTopRow;
    end;
  finally
    FUpdatingScroll := False;
  end;
end;

procedure TDataGrid.ScrollChange(Sender: TObject);
begin
  if not FUpdatingScroll then
    SetTopRow(Round(FScrollBar.Value));
end;

procedure TDataGrid.ScrollIntoView(Row: Integer);
var
  Y: Single;
  R: Integer;
begin
  if (Row < 0) or (Row >= FRowCount) then
    Exit;
  if Row < FTopRow then
  begin
    SetTopRow(Row);
    Exit;
  end;
  // Scroll down until Row's bottom edge is inside the view.
  R := FTopRow;
  Y := DataTop;
  while R <= Row do
  begin
    Y := Y + GetRowHeights(R);
    Inc(R);
  end;
  R := FTopRow;
  while (Y > DataBottom + 0.5) and (R < Row) do
  begin
    Y := Y - GetRowHeights(R);
    Inc(R);
  end;
  SetTopRow(R);
end;

procedure TDataGrid.Refresh;
begin
  Repaint;
end;

procedure TDataGrid.Resize;
begin
  inherited;
  UpdateScrollBar;
end;

function TDataGrid.ColumnWidths: TArray<Single>;
var
  I, Stretchers: Integer;
  Fixed, Avail: Single;
begin
  SetLength(Result, Length(FColumns));
  Fixed := 0;
  Stretchers := 0;
  for I := 0 to High(FColumns) do
    if FColumns[I].Visible then
    begin
      if FColumns[I].Stretch then
        Inc(Stretchers)
      else
        Fixed := Fixed + FColumns[I].Width;
    end;
  Avail := Width;
  if FScrollBar.Visible then
    Avail := Avail - FScrollBar.Width;
  for I := 0 to High(FColumns) do
    if not FColumns[I].Visible then
      Result[I] := 0
    else if FColumns[I].Stretch then
      Result[I] := Max(FColumns[I].Width, (Avail - Fixed) / Stretchers)
    else
      Result[I] := FColumns[I].Width;
end;

function TDataGrid.RowAt(Y: Single): Integer;
var
  Top: Single;
begin
  Result := -1;
  if Y < DataTop then
    Exit;
  Top := DataTop;
  Result := FTopRow;
  while Result < FRowCount do
  begin
    Top := Top + GetRowHeights(Result);
    if Y < Top then
      Exit;
    Inc(Result);
  end;
  Result := -1;
end;

function TDataGrid.ColAt(X: Single): Integer;
var
  W: TArray<Single>;
  Left: Single;
begin
  W := ColumnWidths;
  Left := 0;
  for Result := 0 to High(W) do
  begin
    if (W[Result] > 0) and (X >= Left) and (X < Left + W[Result]) then
      Exit;
    Left := Left + W[Result];
  end;
  Result := -1;
end;

function TDataGrid.RowRect(Row: Integer): TRectF;
var
  Y: Single;
  R: Integer;
begin
  Result := TRectF.Empty;
  if (Row < FTopRow) or (Row >= FRowCount) then
    Exit;
  Y := DataTop;
  for R := FTopRow to Row - 1 do
  begin
    Y := Y + GetRowHeights(R);
    if Y > DataBottom then
      Exit;
  end;
  Result := TRectF.Create(0, Y, Width, Y + GetRowHeights(Row));
end;

function TDataGrid.CheckRect(const RowRect: TRectF): TRectF;
var
  S: Single;
begin
  S := Min(18, RowRect.Height - 6);
  Result := TRectF.Create(RowRect.Left + FCellPadding, RowRect.CenterPoint.Y - S / 2,
    RowRect.Left + FCellPadding + S, RowRect.CenterPoint.Y + S / 2);
end;

function TDataGrid.HeaderBorderAt(X, Y: Single): Integer;
var
  W: TArray<Single>;
  Edge: Single;
  I: Integer;
begin
  Result := -1;
  if not FShowHeader or (Y > FHeaderHeight) then
    Exit;
  W := ColumnWidths;
  Edge := 0;
  for I := 0 to High(W) do
  begin
    Edge := Edge + W[I];
    if (W[I] > 0) and not FColumns[I].Stretch and (Abs(X - Edge) <= ResizeGrip) then
      Exit(I);
  end;
end;

procedure TDataGrid.DrawText(const R: TRectF; const S: string; Align: TGridAlign; Color: TAlphaColor;
  Size: Single; Bold: Boolean);
begin
  if (S = '') or (R.Width <= 2) then
    Exit;
  FLayout.BeginUpdate;
  try
    FLayout.TopLeft := R.TopLeft;
    FLayout.MaxSize := TPointF.Create(R.Width, R.Height);
    FLayout.Text := S;
    FLayout.WordWrap := False;
    FLayout.Trimming := TTextTrimming.Character;
    FLayout.Font.Size := Size;
    if FFontFamily <> '' then
      FLayout.Font.Family := FFontFamily;
    if Bold then
      FLayout.Font.Style := [TFontStyle.fsBold]
    else
      FLayout.Font.Style := [];
    FLayout.Color := Color;
    case Align of
      gaRight: FLayout.HorizontalAlign := TTextAlign.Trailing;
      gaCenter: FLayout.HorizontalAlign := TTextAlign.Center;
    else
      FLayout.HorizontalAlign := TTextAlign.Leading;
    end;
    FLayout.VerticalAlign := TTextAlign.Center;
  finally
    FLayout.EndUpdate;
  end;
  FLayout.RenderLayout(Canvas);
end;

procedure TDataGrid.DrawCheck(const R: TRectF; Checked: Boolean; Color: TAlphaColor);
var
  P: TPathData;
begin
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := TAlphaColors.White;
  Canvas.FillRect(R, 3, 3, AllCorners, 1);
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Thickness := 1.2;
  if Checked then
  begin
    Canvas.Fill.Color := FSelColor;
    Canvas.FillRect(R, 3, 3, AllCorners, 1);
    P := TPathData.Create;
    try
      P.MoveTo(TPointF.Create(R.Left + R.Width * 0.22, R.Top + R.Height * 0.52));
      P.LineTo(TPointF.Create(R.Left + R.Width * 0.42, R.Top + R.Height * 0.72));
      P.LineTo(TPointF.Create(R.Left + R.Width * 0.78, R.Top + R.Height * 0.30));
      Canvas.Stroke.Color := TAlphaColors.White;
      Canvas.Stroke.Thickness := 2;
      Canvas.DrawPath(P, 1);
    finally
      P.Free;
    end;
  end
  else
  begin
    Canvas.Stroke.Color := Color;
    Canvas.DrawRect(R, 3, 3, AllCorners, 1);
  end;
end;

procedure TDataGrid.Paint;
var
  W: TArray<Single>;
  Y, X, H, RowH: Single;
  Row, Col: Integer;
  R, CellR: TRectF;
  Text: string;
  St: TCellStyle;
  RowBack, Fore: TAlphaColor;
  Sel, Checked, Group: Boolean;
  Avail: Single;
  State: TCanvasSaveState;
begin
  W := ColumnWidths;
  Avail := Width;
  if FScrollBar.Visible then
    Avail := Avail - FScrollBar.Width;
  State := Canvas.SaveState;
  try
    Canvas.IntersectClipRect(LocalRect);
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := FBackColor;
    Canvas.FillRect(LocalRect, 0, 0, [], 1);

    // rows
    Y := DataTop;
    Row := FTopRow;
    while (Row < FRowCount) and (Y < Height) do
    begin
      RowH := GetRowHeights(Row);
      R := TRectF.Create(0, Y, Avail, Y + RowH);
      Group := IsGroupRow(Row);
      Sel := (Row = FItemIndex) and not Group;
      if Group then
      begin
        Canvas.Fill.Color := FGroupColor;
        Canvas.FillRect(R, 0, 0, [], 1);
        Text := '';
        if Assigned(FOnGetText) then
          FOnGetText(Self, 0, Row, Text);
        DrawText(TRectF.Create(R.Left + FCellPadding, R.Top, R.Right - FCellPadding, R.Bottom), Text, gaLeft,
          FGroupTextColor, FFontSize, True);
      end
      else
      begin
        if FStriped and Odd(Row) then
          RowBack := FAltColor
        else
          RowBack := FBackColor;
        Canvas.Fill.Color := RowBack;
        Canvas.FillRect(R, 0, 0, [], 1);
        X := 0;
        for Col := 0 to High(FColumns) do
        begin
          if W[Col] <= 0 then
            Continue;
          CellR := TRectF.Create(X, Y, X + W[Col], Y + RowH);
          St := Default(TCellStyle);
          if Assigned(FOnGetStyle) then
            FOnGetStyle(Self, Col, Row, St);
          if Sel then
          begin
            if IsFocused then
              Canvas.Fill.Color := FSelColor
            else
              Canvas.Fill.Color := FSelInactiveColor;
            Canvas.FillRect(CellR, 0, 0, [], 1);
          end
          else if St.Back <> 0 then
          begin
            Canvas.Fill.Color := St.Back;
            Canvas.FillRect(CellR, 0, 0, [], 1);
          end;
          if Sel and IsFocused then
            Fore := FSelTextColor
          else if St.Fore <> 0 then
            Fore := St.Fore
          else
            Fore := FTextColor;
          if (Col = 0) and FCheckboxes then
          begin
            Checked := False;
            if Assigned(FOnGetChecked) then
              FOnGetChecked(Self, Row, Checked);
            DrawCheck(CheckRect(CellR), Checked, FDimTextColor);
            CellR.Left := CheckRect(CellR).Right;
          end;
          Text := '';
          if Assigned(FOnGetText) then
            FOnGetText(Self, Col, Row, Text);
          H := FFontSize;
          if St.FontSize > 0 then
            H := St.FontSize;
          DrawText(TRectF.Create(CellR.Left + FCellPadding, CellR.Top, CellR.Right - FCellPadding, CellR.Bottom),
            Text, FColumns[Col].Align, Fore, H, St.Bold);
          X := X + W[Col];
        end;
      end;
      if FGridLines then
      begin
        Canvas.Stroke.Color := FLineColor;
        Canvas.Stroke.Thickness := 1;
        Canvas.DrawLine(TPointF.Create(0, R.Bottom - 0.5), TPointF.Create(Avail, R.Bottom - 0.5), 1);
      end;
      Y := Y + RowH;
      Inc(Row);
    end;

    // header
    if FShowHeader then
    begin
      R := TRectF.Create(0, 0, Width, FHeaderHeight);
      Canvas.Fill.Color := FHeaderColor;
      Canvas.FillRect(R, 0, 0, [], 1);
      X := 0;
      for Col := 0 to High(FColumns) do
      begin
        if W[Col] <= 0 then
          Continue;
        CellR := TRectF.Create(X, 0, X + W[Col], FHeaderHeight);
        if (Col = 0) and FCheckboxes then
          CellR.Left := CellR.Left + Min(18, FRowHeight - 6) + FCellPadding;
        DrawText(TRectF.Create(CellR.Left + FCellPadding, 0, CellR.Right - FCellPadding, FHeaderHeight),
          FColumns[Col].Caption, FColumns[Col].Align, FHeaderTextColor, FFontSize * 0.92, True);
        X := X + W[Col];
        Canvas.Stroke.Color := FLineColor;
        Canvas.DrawLine(TPointF.Create(X - 0.5, 4), TPointF.Create(X - 0.5, FHeaderHeight - 4), 1);
      end;
      Canvas.Stroke.Color := $FFB8BEC6;
      Canvas.DrawLine(TPointF.Create(0, FHeaderHeight - 0.5), TPointF.Create(Width, FHeaderHeight - 0.5), 1);
    end;

    if IsFocused then
    begin
      Canvas.Stroke.Color := $664D90FE;
      Canvas.Stroke.Thickness := 1;
      Canvas.DrawRect(TRectF.Create(0.5, 0.5, Width - 0.5, Height - 0.5), 0, 0, [], 1);
    end;
  finally
    Canvas.RestoreState(State);
  end;
end;

procedure TDataGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Row, Col: Integer;
  R: TRectF;
begin
  inherited;
  if CanFocus and not IsFocused then
    SetFocus;
  FDownPos := TPointF.Create(X, Y);
  FLastMouse := FDownPos;
  FDragScroll := False;
  FDragTop := FTopRow;
  FDown := Button = TMouseButton.mbLeft;
  if FDown then
  begin
    FResizeCol := HeaderBorderAt(X, Y);
    if FResizeCol >= 0 then
    begin
      FResizeStartX := X;
      FResizeStartW := FColumns[FResizeCol].Width;
      Exit;
    end;
  end;
  if Button = TMouseButton.mbRight then
  begin
    Row := RowAt(Y);
    if (Row >= 0) and not IsGroupRow(Row) then
      SetItemIndex(Row);
  end
  else if FDown and FShowHeader and (Y < FHeaderHeight) then
  begin
    Col := ColAt(X);
    if (Col >= 0) and Assigned(FOnHeaderClick) then
      FOnHeaderClick(Self, Col);
    FDown := False;
  end
  else if FDown and FCheckboxes then
  begin
    // A click on the check box toggles it at once.
    Row := RowAt(Y);
    if (Row >= 0) and not IsGroupRow(Row) then
    begin
      R := RowRect(Row);
      R := CheckRect(TRectF.Create(0, R.Top, ColumnWidths[0], R.Bottom));
      R.Inflate(4, 4);
      if R.Contains(TPointF.Create(X, Y)) then
      begin
        SetItemIndex(Row);
        if Assigned(FOnToggleCheck) then
          FOnToggleCheck(Self, Row);
        Repaint;
        FDown := False;
      end;
    end;
  end;
end;

procedure TDataGrid.MouseMove(Shift: TShiftState; X, Y: Single);
var
  Delta: Integer;
  Avg: Single;
begin
  inherited;
  FLastMouse := TPointF.Create(X, Y);
  if FDown and (FResizeCol >= 0) then
  begin
    FColumns[FResizeCol].Width := Max(MinColumnWidth, FResizeStartW + X - FResizeStartX);
    Repaint;
    Exit;
  end;
  if FDown and not FDragScroll and (Abs(Y - FDownPos.Y) > DragThreshold) and (FRowCount > VisibleRows) then
    FDragScroll := True;
  if FDragScroll then
  begin
    Avg := Max(8, FRowHeight);
    Delta := Round((FDownPos.Y - Y) / Avg);
    SetTopRow(Min(FDragTop + Delta, LastTopRow(Self)));
    Exit;
  end;
  if HeaderBorderAt(X, Y) >= 0 then
    Cursor := crSizeWE
  else
    Cursor := crDefault;
end;

procedure TDataGrid.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Row: Integer;
begin
  inherited;
  if FDown and (FResizeCol < 0) and not FDragScroll and (Button = TMouseButton.mbLeft) then
  begin
    Row := RowAt(Y);
    if (Row >= 0) and not IsGroupRow(Row) then
      SetItemIndex(Row);
  end;
  FDown := False;
  FDragScroll := False;
  FResizeCol := -1;
end;

procedure TDataGrid.DblClick;
var
  Row: Integer;
begin
  inherited;
  Row := RowAt(FLastMouse.Y);
  if (Row >= 0) and not IsGroupRow(Row) and Assigned(FOnRowDblClick) then
    FOnRowDblClick(Self, Row);
end;

procedure TDataGrid.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited;
  if Handled then
    Exit;
  SetTopRow(Min(FTopRow - Sign(WheelDelta) * 3, LastTopRow(Self)));
  Handled := True;
end;

procedure TDataGrid.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);

  function NextRow(From, Step: Integer): Integer;
  begin
    Result := EnsureRange(From + Step, 0, FRowCount - 1);
    while (Result > 0) and (Result < FRowCount - 1) and IsGroupRow(Result) do
      Inc(Result, Sign(Step));
    if IsGroupRow(Result) then
      Result := From;
  end;

begin
  inherited;
  if FRowCount = 0 then
    Exit;
  case Key of
    vkUp: SetItemIndex(NextRow(Max(FItemIndex, 0), -1));
    vkDown: SetItemIndex(NextRow(FItemIndex, 1));
    vkPrior: SetItemIndex(NextRow(Max(FItemIndex, 0), -VisibleRows));
    vkNext: SetItemIndex(NextRow(Max(FItemIndex, 0), VisibleRows));
    vkHome: SetItemIndex(NextRow(-1, 1));
    vkEnd: SetItemIndex(NextRow(FRowCount, -1));
    vkReturn:
      if (FItemIndex >= 0) and Assigned(FOnRowDblClick) then
        FOnRowDblClick(Self, FItemIndex)
      else
        Exit;
  else
    if (KeyChar = ' ') and FCheckboxes and (FItemIndex >= 0) and Assigned(FOnToggleCheck) then
    begin
      FOnToggleCheck(Self, FItemIndex);
      Repaint;
      KeyChar := #0;
    end;
    Exit;
  end;
  Key := 0;
end;

procedure TDataGrid.DoEnter;
begin
  inherited;
  Repaint;
end;

procedure TDataGrid.DoExit;
begin
  inherited;
  Repaint;
end;

end.
