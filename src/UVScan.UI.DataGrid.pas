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
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math, System.Messaging,
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
    Wrap: Boolean;          // word-wrap the text (give the row the height it needs)
    Shrink: Boolean;        // a smaller font rather than cut text (numbers)
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
    FHScrollBar: TScrollBar;      // when the columns are wider than the grid
    FScrollX: Single;             // how far the columns are scrolled left
    FDragHorz: Boolean;
    FDragX: Single;
    FLayout: TTextLayout;
    FUpdatingScroll: Boolean;
    // colours
    FCheckColor: TAlphaColor;
    FAutoHeights: Boolean;
    FReserveScroll: Boolean;
    FMeasure: TTextLayout;        // for WrappedTextHeight
    FLastAutoWidth: Single;
    FThemeSub: TMessageSubscriptionId;
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
    procedure HScrollChange(Sender: TObject);
    procedure SetScrollX(Value: Single);
    function DataWidth: Single;
    function TotalWidth: Single;
    procedure LoadPalette;
    procedure ThemeChanged(const Sender: TObject; const M: TMessage);
    procedure UpdateScrollBar;
    function DataTop: Single;
    function DataBottom: Single;
    function ColumnWidths: TArray<Single>;
    function HeaderBorderAt(X, Y: Single): Integer;
    procedure DrawText(const R: TRectF; const S: string; Align: TGridAlign; Color: TAlphaColor; Size: Single;
      Bold: Boolean; Wrap: Boolean = False; Shrink: Boolean = False);
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
    procedure SetColumnWrap(Index: Integer; Wrap: Boolean);
    { Text too wide for the cell is drawn smaller (down to half size) instead
      of being cut short - for values, where "13..." says nothing. }
    procedure SetColumnShrink(Index: Integer; Shrink: Boolean);
    { Width a column gets now (stretch columns share what is left). }
    function ColumnWidth(Index: Integer): Single;
    { Height Text needs in column Index when wrapped (cell padding included). }
    function WrappedTextHeight(Index: Integer; const Text: string; Size: Single; Bold: Boolean = False): Single;
    { Gives rows FromRow.. the height their wrapped columns need (OnGetText). }
    procedure AutoRowHeights(FromRow: Integer = 0);
    { Redo AutoRowHeights whenever the width changes. }
    property AutoHeights: Boolean read FAutoHeights write FAutoHeights;
    { Columns leave room for the vertical scroll bar even while it is hidden,
      so wrapped row heights measured now still fit once it shows. }
    property ReserveScrollBar: Boolean read FReserveScroll write FReserveScroll;
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

uses
  UVScan.UI.Common, UVScan.UI.Theme;

const
  DragThreshold = 6;
  ResizeGrip = 4;
  MinColumnWidth = 24;
  StretchMin = 100;

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
  LoadPalette;
  FThemeSub := TMessageManager.DefaultManager.SubscribeToMessage(TThemeChangedMessage, ThemeChanged);
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
  FHScrollBar := TScrollBar.Create(Self);
  FHScrollBar.Parent := Self;
  FHScrollBar.Stored := False;
  FHScrollBar.Orientation := TOrientation.Horizontal;
  FHScrollBar.Align := TAlignLayout.Bottom;
  FHScrollBar.Height := 14;
  FHScrollBar.SmallChange := 20;
  FHScrollBar.Visible := False;
  FHScrollBar.OnChange := HScrollChange;
  Width := 300;
  Height := 200;
end;

destructor TDataGrid.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(TThemeChangedMessage, FThemeSub);
  FMeasure.Free;
  FLayout.Free;
  inherited;
end;

{ Colours of the active theme (UVScan.UI.Theme). }
procedure TDataGrid.LoadPalette;
var
  P: TPalette;
begin
  P := Palette;
  FBackColor := P.GridBack;
  FAltColor := P.GridAlt;
  FTextColor := P.GridText;
  FDimTextColor := P.GridDimText;
  FHeaderColor := P.GridHeader;
  FHeaderTextColor := P.GridHeaderText;
  FLineColor := P.GridLine;
  FSelColor := P.GridSel;
  FSelTextColor := P.GridSelText;
  FSelInactiveColor := P.GridSelInactive;
  FGroupColor := P.GridGroup;
  FGroupTextColor := P.GridGroupText;
  FCheckColor := P.GridCheck;
end;

procedure TDataGrid.ThemeChanged(const Sender: TObject; const M: TMessage);
begin
  LoadPalette;
  Repaint;
end;

function TDataGrid.AddColumn(const Caption: string; Width: Single; Align: TGridAlign; Stretch: Boolean): Integer;
var
  C: TGridColumn;
begin
  C := Default(TGridColumn); // Wrap, Shrink: off
  C.Caption := Caption;
  C.Width := Width;
  C.Align := Align;
  C.Stretch := Stretch;
  C.Visible := True;
  FColumns := FColumns + [C];
  Result := High(FColumns);
  UpdateScrollBar;
  Repaint;
end;

procedure TDataGrid.ClearColumns;
begin
  FColumns := nil;
  UpdateScrollBar;
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
  UpdateScrollBar;
  Repaint;
end;

procedure TDataGrid.SetColumnVisible(Index: Integer; Visible: Boolean);
begin
  if FColumns[Index].Visible <> Visible then
  begin
    FColumns[Index].Visible := Visible;
    UpdateScrollBar;
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
  if (FHScrollBar <> nil) and FHScrollBar.Visible then
    Result := Result - FHScrollBar.Height;
end;

{ Width of the cell area (without the vertical scroll bar). }
function TDataGrid.DataWidth: Single;
begin
  Result := Width;
  if (FScrollBar <> nil) and FScrollBar.Visible then
    Result := Result - FScrollBar.Width;
end;

function TDataGrid.TotalWidth: Single;
var
  W: Single;
begin
  Result := 0;
  for W in ColumnWidths do
    Result := Result + W;
end;

procedure TDataGrid.SetScrollX(Value: Single);
begin
  Value := EnsureRange(Value, 0, Max(0, TotalWidth - DataWidth));
  if Abs(Value - FScrollX) < 0.5 then
    Exit;
  FScrollX := Value;
  FUpdatingScroll := True;
  try
    if FHScrollBar.Visible then
      FHScrollBar.Value := FScrollX;
  finally
    FUpdatingScroll := False;
  end;
  Repaint;
end;

procedure TDataGrid.HScrollChange(Sender: TObject);
begin
  if not FUpdatingScroll then
    SetScrollX(FHScrollBar.Value);
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

  procedure UpdateHorz;
  var
    Total, Avail: Single;
  begin
    Total := TotalWidth;
    Avail := DataWidth;
    FHScrollBar.Visible := Total > Avail + 0.5;
    if FHScrollBar.Visible then
    begin
      FScrollX := EnsureRange(FScrollX, 0, Total - Avail);
      if FScrollBar.Visible then
        FHScrollBar.Margins.Right := FScrollBar.Width
      else
        FHScrollBar.Margins.Right := 0;
      FHScrollBar.Min := 0;
      FHScrollBar.Max := Total;
      FHScrollBar.ViewportSize := Avail;
      FHScrollBar.Value := FScrollX;
    end
    else
      FScrollX := 0;
  end;

var
  Last: Integer;
begin
  if (FScrollBar = nil) or (FHScrollBar = nil) then
    Exit;
  FUpdatingScroll := True;
  try
    UpdateHorz; // first: it takes room from the rows
  finally
    FUpdatingScroll := False;
  end;
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
    UpdateHorz; // again: the vertical bar may have taken width
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
  if FAutoHeights and (Abs(Width - FLastAutoWidth) > 1) then
  begin
    FLastAutoWidth := Width;
    AutoRowHeights;
  end;
end;

procedure TDataGrid.AutoRowHeights(FromRow: Integer);
var
  R, C: Integer;
  H: Single;
  S: string;
  Group, AnyWrap: Boolean;
begin
  AnyWrap := False;
  for C := 0 to High(FColumns) do
    AnyWrap := AnyWrap or (FColumns[C].Visible and FColumns[C].Wrap);
  if not AnyWrap or not Assigned(FOnGetText) then
    Exit;
  if FromRow <= 0 then
  begin
    FRowHeights := nil;
    FromRow := 0;
  end;
  SetLength(FRowHeights, FRowCount);
  for R := FromRow to FRowCount - 1 do
  begin
    Group := False;
    if Assigned(FOnIsGroupRow) then
      FOnIsGroupRow(Self, R, Group);
    H := 0;
    if not Group then
      for C := 0 to High(FColumns) do
        if FColumns[C].Visible and FColumns[C].Wrap then
        begin
          S := '';
          FOnGetText(Self, C, R, S);
          if S <> '' then
            H := Max(H, WrappedTextHeight(C, S, FFontSize));
        end;
    if H > FRowHeight then
      FRowHeights[R] := H
    else
      FRowHeights[R] := 0;
  end;
  UpdateScrollBar;
  Repaint;
end;

procedure TDataGrid.SetColumnWrap(Index: Integer; Wrap: Boolean);
begin
  FColumns[Index].Wrap := Wrap;
  Repaint;
end;

procedure TDataGrid.SetColumnShrink(Index: Integer; Shrink: Boolean);
begin
  FColumns[Index].Shrink := Shrink;
  Repaint;
end;

function TDataGrid.ColumnWidth(Index: Integer): Single;
begin
  Result := ColumnWidths[Index];
end;

function TDataGrid.WrappedTextHeight(Index: Integer; const Text: string; Size: Single; Bold: Boolean): Single;
var
  L: TTextLayout;
  W: Single;
begin
  W := ColumnWidth(Index) - 2 * FCellPadding;
  if (Index = 0) and FCheckboxes then
    W := W - Min(18, FRowHeight - 6) - FCellPadding;
  if FMeasure = nil then
    FMeasure := TTextLayoutManager.DefaultTextLayout.Create;
  L := FMeasure;
  L.BeginUpdate;
  try
    L.MaxSize := TPointF.Create(Max(10, W), 100000);
    L.WordWrap := True;
    L.Font.Size := Size;
    if FFontFamily <> '' then
      L.Font.Family := FFontFamily;
    if Bold then
      L.Font.Style := [TFontStyle.fsBold]
    else
      L.Font.Style := [];
    L.Text := Text;
  finally
    L.EndUpdate;
  end;
  Result := Ceil(L.TextHeight) + 2 * FCellPadding;
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
  // Auto row heights: measured once, so keep the width the same whether
  // the scroll bar shows or not.
  if FScrollBar.Visible or FReserveScroll or FAutoHeights then
    Avail := Avail - FScrollBar.Width;
  for I := 0 to High(FColumns) do
    if not FColumns[I].Visible then
      Result[I] := 0
    else if FColumns[I].Stretch then
      // fills what is left; on a narrow grid it gives up width (down to
      // StretchMin) before the grid has to scroll sideways
      Result[I] := Max(Min(FColumns[I].Width, StretchMin), (Avail - Fixed) / Stretchers)
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
  Left := -FScrollX;
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
  Edge := -FScrollX;
  for I := 0 to High(W) do
  begin
    Edge := Edge + W[I];
    if (W[I] > 0) and not FColumns[I].Stretch and (Abs(X - Edge) <= ResizeGrip) then
      Exit(I);
  end;
end;

function LongestWord(const S: string): string;
var
  W: string;
begin
  Result := '';
  for W in S.Split([' ']) do
    if Length(W) > Length(Result) then
      Result := W;
end;

procedure TDataGrid.DrawText(const R: TRectF; const S: string; Align: TGridAlign; Color: TAlphaColor;
  Size: Single; Bold: Boolean; Wrap: Boolean; Shrink: Boolean);
var
  W: Single;
begin
  if (S = '') or (R.Width <= 2) then
    Exit;
  if Shrink then
  begin
    // measure at full size; too wide = draw it smaller to fit (wrapped text:
    // its longest word, which cannot wrap)
    FLayout.BeginUpdate;
    try
      FLayout.MaxSize := TPointF.Create(100000, R.Height * 4);
      FLayout.Text := S;
      if Wrap then
        FLayout.Text := LongestWord(S);
      FLayout.WordWrap := False;
      FLayout.Font.Size := Size;
      if FFontFamily <> '' then
        FLayout.Font.Family := FFontFamily;
      if Bold then
        FLayout.Font.Style := [TFontStyle.fsBold]
      else
        FLayout.Font.Style := [];
    finally
      FLayout.EndUpdate;
    end;
    W := FLayout.TextWidth;
    if W > R.Width then
      Size := Max(Size / 2, Size * R.Width / W * 0.97);
  end;
  FLayout.BeginUpdate;
  try
    FLayout.TopLeft := R.TopLeft;
    FLayout.MaxSize := TPointF.Create(R.Width, R.Height);
    FLayout.Text := S;
    FLayout.WordWrap := Wrap;
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
  Canvas.Fill.Color := FBackColor;
  Canvas.FillRect(R, 3, 3, AllCorners, 1);
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Thickness := 1.2;
  if Checked then
  begin
    Canvas.Fill.Color := FCheckColor;
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
  Avail := DataWidth;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := FBackColor;
  Canvas.FillRect(LocalRect, 0, 0, [], 1);
  State := Canvas.SaveState;
  try
    // Cells stay off the scroll bars. One clip only: a second one is not
    // undone by RestoreState and would hide every control painted after this.
    Canvas.IntersectClipRect(TRectF.Create(0, 0, Avail, DataBottom));

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
        X := -FScrollX;
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
          else if St.Back <> 0 then
            Fore := ContrastColor(St.Back) // a coloured cell keeps readable text in either theme
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
            Text, FColumns[Col].Align, Fore, H, St.Bold, FColumns[Col].Wrap,
            FColumns[Col].Shrink or FColumns[Col].Wrap); // a word too long to wrap: smaller, not broken
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
      X := -FScrollX;
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
      Canvas.Stroke.Color := FLineColor;
      Canvas.DrawLine(TPointF.Create(0, FHeaderHeight - 0.5), TPointF.Create(Width, FHeaderHeight - 0.5), 1);
    end;

  finally
    Canvas.RestoreState(State);
  end;
  if IsFocused then
  begin
    Canvas.Stroke.Color := $664D90FE;
    Canvas.Stroke.Thickness := 1;
    Canvas.DrawRect(TRectF.Create(0.5, 0.5, Width - 0.5, Height - 0.5), 0, 0, [], 1);
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
      R := CheckRect(TRectF.Create(-FScrollX, R.Top, ColumnWidths[0] - FScrollX, R.Bottom));
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
    UpdateScrollBar;
    Repaint;
    Exit;
  end;
  if FDown and not FDragScroll and not FDragHorz and FHScrollBar.Visible and
    (Abs(X - FDownPos.X) > DragThreshold) and (Abs(X - FDownPos.X) > Abs(Y - FDownPos.Y)) then
  begin
    FDragHorz := True;
    FDragX := FScrollX;
  end;
  if FDragHorz then
  begin
    SetScrollX(FDragX + FDownPos.X - X);
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
  if FDown and (FResizeCol < 0) and not FDragScroll and not FDragHorz and (Button = TMouseButton.mbLeft) then
  begin
    Row := RowAt(Y);
    if (Row >= 0) and not IsGroupRow(Row) then
      SetItemIndex(Row);
  end;
  FDown := False;
  FDragScroll := False;
  FDragHorz := False;
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
  if (ssShift in Shift) and FHScrollBar.Visible then
    SetScrollX(FScrollX - Sign(WheelDelta) * 60)
  else
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
