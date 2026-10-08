unit UVScan.UI.Common;

{ Small FMX helpers shared by every window:
  - message boxes and questions that also work on Android, where nothing may
    block: the answer arrives in a callback (on Windows the box is still modal
    and the callback runs before the call returns);
  - ShowDialog: shows a form modally and frees it afterwards;
  - colour combo boxes with swatches and a "Default" entry;
  - colour arithmetic. }

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Types,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.ListBox, FMX.StdCtrls, FMX.Menus, FMX.Objects, FMX.Controls.Presentation,
  FMX.Layouts;

type
  TNamedColor = record
    Name: string;
    Color: TAlphaColor;
  end;

const
  { The colours offered in colour boxes (the alert presets first). }
  NamedColors: array[0..23] of TNamedColor = (
    (Name: 'Alarm red'; Color: $FFFF5050),
    (Name: 'Warning amber'; Color: $FFFFE680),
    (Name: 'Good green'; Color: $FFC8F0C8),
    (Name: 'Black'; Color: $FF000000),
    (Name: 'White'; Color: $FFFFFFFF),
    (Name: 'Dark grey'; Color: $FF505050),
    (Name: 'Grey'; Color: $FF808080),
    (Name: 'Light grey'; Color: $FFD8D8D8),
    (Name: 'Red'; Color: $FFE00000),
    (Name: 'Dark red'; Color: $FF900000),
    (Name: 'Orange'; Color: $FFFF8C00),
    (Name: 'Yellow'; Color: $FFFFE000),
    (Name: 'Light yellow'; Color: $FFFFF8B0),
    (Name: 'Green'; Color: $FF20A020),
    (Name: 'Dark green'; Color: $FF006400),
    (Name: 'Lime'; Color: $FF80E000),
    (Name: 'Teal'; Color: $FF008080),
    (Name: 'Cyan'; Color: $FF00C8E0),
    (Name: 'Light blue'; Color: $FFB0D8FF),
    (Name: 'Blue'; Color: $FF2D7FF9),
    (Name: 'Navy'; Color: $FF000080),
    (Name: 'Purple'; Color: $FF8040C0),
    (Name: 'Magenta'; Color: $FFFF00C0),
    (Name: 'Brown'; Color: $FF8B5A2B));

{ Message boxes. OnClose / OnYes may be nil. }
procedure ShowInfo(const Msg: string; const OnClose: TProc = nil);
procedure ShowWarning(const Msg: string; const OnClose: TProc = nil);
procedure ShowError(const Msg: string; const OnClose: TProc = nil);
{ Yes / No question; OnYes runs only on Yes. }
procedure Confirm(const Msg: string; const OnYes: TProc; const OnNo: TProc = nil);
{ One line of text; OnOK gets the trimmed text (only when OK is pressed). }
procedure AskText(const Title, Prompt, Default: string; const OnOK: TProc<string>);

{ Shows Form modally (full screen on a phone) and frees it once closed.
  OnClose (may be nil) gets the modal result while the form still exists, so
  it can read the form's fields. }
procedure ShowDialog(Form: TCommonCustomForm; const OnClose: TProc<TModalResult>);

{ Fills Combo with NamedColors (and "Default" = 0 first when AllowDefault). }
procedure SetupColorCombo(Combo: TComboBox; AllowDefault: Boolean; const DefaultCaption: string = 'Default');
{ Selects C, adding a "#RRGGBB" entry when it is not a named colour. }
procedure SetComboColor(Combo: TComboBox; C: TAlphaColor);
function GetComboColor(Combo: TComboBox): TAlphaColor;
{ Name of a colour ("Alarm red") or "#RRGGBB". }
function ColorName(C: TAlphaColor): string;

{ Black or white, whichever reads better on Back. }
function ContrastColor(Back: TAlphaColor): TAlphaColor;
function Luminance(C: TAlphaColor): Single;
{ A blended T of the way from A to B (0..1). }
function Blend(A, B: TAlphaColor; T: Single): TAlphaColor;
function WithAlpha(C: TAlphaColor; Alpha: Byte): TAlphaColor;

type
  TActionItem = record
    Text: string;           // '-' = separator
    Enabled: Boolean;
    Checked: Boolean;
    OnClick: TNotifyEvent;
    Sender: TObject;        // passed to OnClick
  end;

{ A touch-friendly menu at At (form coordinates), kept on the form. FMX popup
  menus do not show on Android; this looks and works the same everywhere.
  Tapping outside closes it. }
procedure ShowActionMenu(Form: TCustomForm; const Items: TArray<TActionItem>; const At: TPointF);
{ ShowActionMenu with the visible items of a TPopupMenu. }
procedure ShowMenuAsActions(Form: TCustomForm; Menu: TPopupMenu; const At: TPointF);

const
  IconBack = 'M15 4 L7 12 L15 20';
  IconChevron = 'M9 5 L16 12 L9 19';

{ A line icon (24 x 24 path data, e.g. IconBack) centred on Button, drawn in
  the theme's text colour. }
function AddLineIcon(Button: TControl; const PathData: string; Size: Single = 22): TPath;
{ A "more" chevron at the right end of a tappable row (any height). }
function AddChevron(Row: TControl): TLayout;

{ Turns a dialog form into a page like the main window's: a top bar with a
  back arrow (= Cancel), Title, and OkButton moved into the bar as OkText.
  The Cancel button and the then empty button row are hidden. The back key
  and Escape cancel. }
procedure MakePage(Form: TCustomForm; const Title: string; OkButton: TButton; const OkText: string = 'Save');

{ Caption + field rows. Narrow: each caption above its field; otherwise left
  of it, all captions as wide as the widest. A row's field is the control
  aligned Client in it. FieldHeight = the field's height. }
procedure ArrangeCaptionRows(const Rows: array of TControl; const Captions: array of TLabel; Narrow: Boolean;
  FieldHeight: Single = 36);

{ Places Items left to right in Container, wrapping to more lines as the
  width needs (buttons as wide as their text, at least MinWidth), and makes
  Container as tall as the lines. }
procedure FlowControls(Container: TControl; const Items: array of TControl; MinWidth: Single = 90;
  ItemHeight: Single = 40; Gap: Single = 8);

{ Widens a button, check box or label so its text fits in the active style's
  font (styles differ: Win10Modern's text is bigger than the default's). }
procedure FitTextWidth(C: TControl; MinWidth: Single = 0);
{ Height a word-wrapped label needs at Width (in the active style's font). }
function WrappedTextHeight(L: TPresentedTextControl; Width: Single): Single;

{ Keeps the screen on and the device awake while UVScan is open (On), or lets
  it sleep again. Android: the window's keep-screen-on flag (no permission,
  and it only applies while UVScan is on screen). Windows: tells the system
  the display and the PC are in use. }
procedure KeepAwake(On: Boolean);

{ True on phones and tablets: windows are full screen, no mouse hover. }
function IsMobile: Boolean;

{ Keeps Form's content clear of the phone's status and navigation bars
  (Android draws apps edge to edge). Does nothing on a desktop. }
procedure KeepInSafeArea(Form: TCommonCustomForm);

implementation

uses
  System.Math, FMX.DialogService, FMX.Dialogs, FMX.Platform, FMX.TextLayout,
  FMX.Effects, UVScan.UI.Theme
  {$IFDEF ANDROID}, Androidapi.Helpers, Androidapi.JNI.App, Androidapi.JNI.GraphicsContentViewText,
  FMX.Helpers.Android{$ENDIF};

{$IFDEF MSWINDOWS}
// Declared here: Winapi.Windows in the uses would hide FMX's TBitmap.
const
  ES_SYSTEM_REQUIRED = $00000001;
  ES_DISPLAY_REQUIRED = $00000002;
  ES_CONTINUOUS = $80000000;

function SetThreadExecutionState(esFlags: Cardinal): Cardinal; stdcall; external 'kernel32.dll';
{$ENDIF}

procedure KeepAwake(On: Boolean);
begin
  {$IFDEF ANDROID}
  CallInUIThread(
    procedure
    begin
      if On then
        TAndroidHelper.Activity.getWindow.addFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_KEEP_SCREEN_ON)
      else
        TAndroidHelper.Activity.getWindow.clearFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_KEEP_SCREEN_ON);
    end);
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  if On then
    SetThreadExecutionState(ES_CONTINUOUS or ES_DISPLAY_REQUIRED or ES_SYSTEM_REQUIRED)
  else
    SetThreadExecutionState(ES_CONTINUOUS);
  {$ENDIF}
end;

function IsMobile: Boolean;
begin
  {$IF DEFINED(ANDROID) or DEFINED(IOS)}
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

type
  TSafeArea = class
    class procedure Changed(Sender: TObject; const AInsets: TRectF);
  end;

class procedure TSafeArea.Changed(Sender: TObject; const AInsets: TRectF);
begin
  if Sender is TCustomForm then
    TCustomForm(Sender).Padding.Rect := AInsets;
end;

procedure KeepInSafeArea(Form: TCommonCustomForm);
var
  Svc: IFMXWindowSafeAreaService;
  Insets: TRectF;
begin
  if not IsMobile then
    Exit;
  Form.OnSafeAreaChanged := TSafeArea.Changed;
  Insets := TRectF.Empty;
  if TPlatformServices.Current.SupportsPlatformService(IFMXWindowSafeAreaService, Svc) then
    Insets := Svc.GetSafeAreaInsets(Form);
  // A second form asked before it is on screen gets no insets (seen on a
  // Galaxy S23), and no change event follows: the main form's are the same.
  if (Insets.Top = 0) and (Insets.Bottom = 0) and (Application.MainForm is TCustomForm) and
    (Application.MainForm <> Form) then
    Insets := TCustomForm(Application.MainForm).Padding.Rect;
  TSafeArea.Changed(Form, Insets);
end;

{ Action menu }

type
  TActionMenu = class(TComponent)
  private
    FOverlay: TRectangle;
    FItems: TArray<TActionItem>;
    procedure OverlayClick(Sender: TObject);
    procedure ItemClick(Sender: TObject);
    procedure Close;
  end;

procedure TActionMenu.Close;
begin
  FOverlay.Visible := False;
  TThread.ForceQueue(nil,
    procedure
    begin
      Free;
    end);
end;

procedure TActionMenu.OverlayClick(Sender: TObject);
begin
  Close;
end;

procedure TActionMenu.ItemClick(Sender: TObject);
var
  Item: TActionItem;
begin
  Item := FItems[TControl(Sender).Tag];
  Close;
  if Assigned(Item.OnClick) then
    TThread.ForceQueue(nil,
      procedure
      begin
        Item.OnClick(Item.Sender);
      end);
end;

procedure ShowActionMenu(Form: TCustomForm; const Items: TArray<TActionItem>; const At: TPointF);
const
  MenuWidth = 270;
var
  M: TActionMenu;
  P: TPalette;
  Panel, Row, Line: TRectangle;
  L: TLabel;
  Check: TPath;
  Shadow: TShadowEffect;
  I: Integer;
  RowH, Y: Single;
begin
  if Length(Items) = 0 then
    Exit;
  P := Palette;
  M := TActionMenu.Create(Form);
  M.FItems := Items;
  M.FOverlay := TRectangle.Create(M);
  M.FOverlay.Parent := Form;
  M.FOverlay.Align := TAlignLayout.Contents;
  M.FOverlay.Fill.Color := $30000000;
  M.FOverlay.Stroke.Kind := TBrushKind.None;
  M.FOverlay.HitTest := True;
  M.FOverlay.OnClick := M.OverlayClick;
  M.FOverlay.BringToFront;

  Panel := TRectangle.Create(M);
  Panel.Parent := M.FOverlay;
  Panel.HitTest := True; // taps between rows do not close the menu
  Panel.Fill.Color := P.Bar;
  Panel.Stroke.Color := P.BarLine;
  Panel.XRadius := 8;
  Panel.YRadius := 8;
  Shadow := TShadowEffect.Create(M);
  Shadow.Parent := Panel;
  Shadow.Opacity := 0.4;
  Shadow.Distance := 2;
  Shadow.Softness := 0.3;

  if IsMobile then
    RowH := 52
  else
    RowH := 36;
  Y := 6;
  for I := 0 to High(Items) do
  begin
    if Items[I].Text = '-' then
    begin
      Line := TRectangle.Create(M);
      Line.Parent := Panel;
      Line.HitTest := False;
      Line.Stroke.Kind := TBrushKind.None;
      Line.Fill.Color := P.BarLine;
      Line.SetBounds(12, Y + 4, MenuWidth - 24, 1);
      Y := Y + 9;
      Continue;
    end;
    Row := TRectangle.Create(M);
    Row.Parent := Panel;
    Row.SetBounds(4, Y, MenuWidth - 8, RowH);
    Row.Fill.Color := TAlphaColors.Null;
    Row.Stroke.Kind := TBrushKind.None;
    Row.XRadius := 6;
    Row.YRadius := 6;
    Row.HitTest := Items[I].Enabled;
    Row.Cursor := crHandPoint;
    Row.Tag := I;
    Row.OnClick := M.ItemClick;
    L := TLabel.Create(M);
    L.Parent := Row;
    L.Align := TAlignLayout.Client;
    L.Margins.Left := 14;
    L.HitTest := False;
    L.StyledSettings := L.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
    if Items[I].Enabled then
      L.TextSettings.FontColor := P.Text
    else
      L.TextSettings.FontColor := P.Muted;
    if IsMobile then
      L.TextSettings.Font.Size := 16
    else
      L.TextSettings.Font.Size := 13;
    L.TextSettings.WordWrap := False;
    L.Text := Items[I].Text;
    if Items[I].Checked then
    begin
      Check := TPath.Create(M);
      Check.Parent := Row;
      Check.Align := TAlignLayout.Right;
      Check.Width := 20;
      Check.Margins.Right := 14;
      Check.Margins.Top := (RowH - 20) / 2;
      Check.Margins.Bottom := (RowH - 20) / 2;
      Check.HitTest := False;
      Check.WrapMode := TPathWrapMode.Fit;
      Check.Data.Data := 'M4 12 L9 17 L20 6';
      Check.Fill.Kind := TBrushKind.None;
      Check.Stroke.Color := P.Accent;
      Check.Stroke.Thickness := 2.2;
    end;
    Y := Y + RowH;
  end;
  Panel.Width := MenuWidth;
  Panel.Height := Y + 6;
  Panel.Position.X := EnsureRange(At.X, 8, Max(8, Form.ClientWidth - MenuWidth - 8));
  Panel.Position.Y := EnsureRange(At.Y, 8, Max(8, Form.ClientHeight - Panel.Height - 8));
end;

procedure ShowMenuAsActions(Form: TCustomForm; Menu: TPopupMenu; const At: TPointF);
var
  Items: TArray<TActionItem>;
  It: TActionItem;
  I: Integer;
  M: TMenuItem;
begin
  Items := nil;
  for I := 0 to Menu.ItemsCount - 1 do
  begin
    M := Menu.Items[I];
    if not M.Visible then
      Continue;
    It.Text := M.Text.Replace('&&', '&');
    It.Enabled := M.Enabled;
    It.Checked := M.IsChecked;
    It.OnClick := M.OnClick;
    It.Sender := M;
    Items := Items + [It];
  end;
  ShowActionMenu(Form, Items, At);
end;

type
  TPageChrome = class(TComponent)
  private
    FForm: TCustomForm;
    FOldKeyUp: TKeyEvent;
    procedure BackClick(Sender: TObject);
    procedure KeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
  end;

procedure TPageChrome.BackClick(Sender: TObject);
begin
  FForm.ModalResult := mrCancel;
end;

procedure TPageChrome.KeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  // The form first (it may use the back key itself, e.g. to leave a sub-page).
  if Assigned(FOldKeyUp) then
    FOldKeyUp(Sender, Key, KeyChar, Shift);
  if Key = vkHardwareBack then
  begin
    Key := 0;
    FForm.ModalResult := mrCancel;
  end;
end;

procedure MakePage(Form: TCustomForm; const Title: string; OkButton: TButton; const OkText: string);
var
  Chrome: TPageChrome;
  Bar: TRectangle;
  Back: TSpeedButton;
  L: TLabel;
  Row: TFmxObject;
  I: Integer;
  AnyLeft: Boolean;
  P: TPalette;
begin
  P := Palette;
  Chrome := TPageChrome.Create(Form);
  Chrome.FForm := Form;
  Chrome.FOldKeyUp := Form.OnKeyUp;
  Form.OnKeyUp := Chrome.KeyUp;
  Bar := TRectangle.Create(Form);
  Bar.Parent := Form;
  Bar.Stored := False;
  Bar.Align := TAlignLayout.Top;
  Bar.Position.Y := -100; // above every other top-aligned control
  Bar.Height := 52;
  Bar.Sides := [TSide.Bottom];
  Bar.Fill.Color := P.Bar;
  Bar.Stroke.Color := P.BarLine;
  Back := TSpeedButton.Create(Form);
  Back.Parent := Bar;
  Back.Stored := False;
  Back.Align := TAlignLayout.Left;
  Back.Width := 48;
  Back.Text := '';
  Back.Hint := 'Back';
  Back.OnClick := Chrome.BackClick;
  AddLineIcon(Back, IconBack);
  Row := OkButton.Parent;
  OkButton.Parent := Bar;
  OkButton.Align := TAlignLayout.Right;
  OkButton.Margins.Rect := TRectF.Create(6, 8, 8, 8);
  OkButton.Width := 96;
  OkButton.Text := OkText;
  L := TLabel.Create(Form);
  L.Parent := Bar;
  L.Stored := False;
  L.Align := TAlignLayout.Client;
  L.Margins.Left := 6;
  L.StyledSettings := L.StyledSettings - [TStyledSetting.Size];
  L.TextSettings.Font.Size := 19;
  L.TextSettings.WordWrap := False;
  L.TextSettings.Trimming := TTextTrimming.Character;
  L.Text := Title;
  // The old button row: hide its Cancel button, and the row if nothing is left.
  if Row is TControl then
  begin
    AnyLeft := False;
    for I := 0 to TControl(Row).ControlsCount - 1 do
      if (TControl(Row).Controls[I] is TButton) and
        ((TButton(TControl(Row).Controls[I]).ModalResult = mrCancel) or TButton(TControl(Row).Controls[I]).Cancel) then
        TControl(Row).Controls[I].Visible := False
      else if TControl(Row).Controls[I].Visible then
        AnyLeft := True;
    if not AnyLeft then
      TControl(Row).Visible := False;
  end;
end;

procedure FlowControls(Container: TControl; const Items: array of TControl; MinWidth: Single;
  ItemHeight: Single; Gap: Single);
var
  I: Integer;
  X, Y, W: Single;
begin
  W := Container.Width - Container.Padding.Left - Container.Padding.Right;
  if W < 50 then
    Exit;
  X := 0;
  Y := 0;
  for I := 0 to High(Items) do
  begin
    if not Items[I].Visible then
      Continue;
    Items[I].Align := TAlignLayout.None;
    FitTextWidth(Items[I], MinWidth);
    if (X > 0) and (X + Items[I].Width > W) then
    begin
      X := 0;
      Y := Y + ItemHeight + Gap;
    end;
    Items[I].SetBounds(Container.Padding.Left + X, Container.Padding.Top + Y, Min(Items[I].Width, W), ItemHeight);
    X := X + Items[I].Width + Gap;
  end;
  Container.Height := Container.Padding.Top + Y + ItemHeight + Container.Padding.Bottom + 4;
end;

procedure ArrangeCaptionRows(const Rows: array of TControl; const Captions: array of TLabel; Narrow: Boolean;
  FieldHeight: Single);
var
  I: Integer;
  W: Single;
begin
  W := 0;
  for I := 0 to High(Captions) do
  begin
    Captions[I].WordWrap := False;
    FitTextWidth(Captions[I]);
    W := Max(W, Captions[I].Width);
  end;
  for I := 0 to High(Captions) do
    if Narrow then
    begin
      Captions[I].Align := TAlignLayout.Top;
      Captions[I].Height := 26;
      Captions[I].TextSettings.VertAlign := TTextAlign.Trailing;
      if I <= High(Rows) then
        Rows[I].Height := 26 + FieldHeight + 6;
    end
    else
    begin
      Captions[I].Align := TAlignLayout.Left;
      Captions[I].Width := W + 10;
      Captions[I].TextSettings.VertAlign := TTextAlign.Center;
      if I <= High(Rows) then
        Rows[I].Height := FieldHeight + 6;
    end;
end;

function AddChevron(Row: TControl): TLayout;
begin
  Result := TLayout.Create(Row);
  Result.Parent := Row;
  Result.Stored := False;
  Result.Align := TAlignLayout.Right;
  Result.Width := 36;
  Result.HitTest := False;
  AddLineIcon(Result, IconChevron, 18);
end;

function AddLineIcon(Button: TControl; const PathData: string; Size: Single): TPath;
begin
  Result := TPath.Create(Button);
  Result.Parent := Button;
  Result.Stored := False;
  Result.Align := TAlignLayout.Center;
  Result.Width := Size;
  Result.Height := Size;
  Result.HitTest := False;
  Result.WrapMode := TPathWrapMode.Fit;
  Result.Data.Data := PathData;
  Result.Fill.Kind := TBrushKind.None;
  Result.Stroke.Color := Palette.Text;
  Result.Stroke.Thickness := 2.2;
  Result.Stroke.Cap := TStrokeCap.Round;
  Result.Stroke.Join := TStrokeJoin.Round;
end;

procedure FitTextWidth(C: TControl; MinWidth: Single);
var
  T: TPresentedTextControl;
  Layout: TTextLayout;
  W, Extra: Single;
begin
  if not (C is TPresentedTextControl) then
    Exit;
  T := TPresentedTextControl(C);
  T.ApplyStyleLookup;
  Layout := TTextLayoutManager.DefaultTextLayout.Create;
  try
    Layout.BeginUpdate;
    try
      Layout.Font := T.ResultingTextSettings.Font;
      Layout.WordWrap := False;
      Layout.MaxSize := TPointF.Create(10000, 1000);
      Layout.Text := T.Text;
    finally
      Layout.EndUpdate;
    end;
    W := Layout.TextWidth;
  finally
    Layout.Free;
  end;
  if (C is TCheckBox) or (C is TRadioButton) then
    Extra := 34 // the box (or circle) and the gap
  else if C is TButton then
    Extra := 28
  else
    Extra := 6;
  C.Width := Max(MinWidth, Ceil(W + Extra));
end;

function WrappedTextHeight(L: TPresentedTextControl; Width: Single): Single;
var
  Layout: TTextLayout;
begin
  L.ApplyStyleLookup;
  Layout := TTextLayoutManager.DefaultTextLayout.Create;
  try
    Layout.BeginUpdate;
    try
      Layout.Font := L.ResultingTextSettings.Font;
      Layout.WordWrap := True;
      Layout.MaxSize := TPointF.Create(Max(20, Width), 100000);
      Layout.Text := L.Text;
    finally
      Layout.EndUpdate;
    end;
    Result := Ceil(Layout.TextHeight) + 2;
  finally
    Layout.Free;
  end;
end;

procedure MessageBox(const Msg: string; DlgType: TMsgDlgType; const OnClose: TProc);
begin
  TDialogService.MessageDialog(Msg, DlgType, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0,
    procedure(const AResult: TModalResult)
    begin
      if Assigned(OnClose) then
        OnClose();
    end);
end;

procedure ShowInfo(const Msg: string; const OnClose: TProc);
begin
  MessageBox(Msg, TMsgDlgType.mtInformation, OnClose);
end;

procedure ShowWarning(const Msg: string; const OnClose: TProc);
begin
  MessageBox(Msg, TMsgDlgType.mtWarning, OnClose);
end;

procedure ShowError(const Msg: string; const OnClose: TProc);
begin
  MessageBox(Msg, TMsgDlgType.mtError, OnClose);
end;

procedure Confirm(const Msg: string; const OnYes: TProc; const OnNo: TProc);
begin
  TDialogService.MessageDialog(Msg, TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
    TMsgDlgBtn.mbNo, 0,
    procedure(const AResult: TModalResult)
    begin
      if AResult = mrYes then
      begin
        if Assigned(OnYes) then
          OnYes();
      end
      else if Assigned(OnNo) then
        OnNo();
    end);
end;

procedure AskText(const Title, Prompt, Default: string; const OnOK: TProc<string>);
begin
  TDialogService.InputQuery(Title, [Prompt], [Default],
    procedure(const AResult: TModalResult; const AValues: array of string)
    begin
      if (AResult = mrOk) and (Length(AValues) > 0) and Assigned(OnOK) then
        OnOK(Trim(AValues[0]));
    end);
end;

procedure ShowDialog(Form: TCommonCustomForm; const OnClose: TProc<TModalResult>);
begin
  if IsMobile then
  begin
    Form.WindowState := TWindowState.wsMaximized;
    KeepInSafeArea(Form);
  end;
  Form.ShowModal(
    procedure(R: TModalResult)
    begin
      try
        if Assigned(OnClose) then
          OnClose(R);
      finally
        // Not inside the form's own close handling.
        TThread.ForceQueue(nil,
          procedure
          begin
            Form.Free;
          end);
      end;
    end);
end;

{ Colour boxes }

function Swatch(C: TAlphaColor): TBitmap;
begin
  Result := TBitmap.Create(16, 16);
  if Result.Canvas.BeginScene then
  try
    Result.Canvas.Clear(TAlphaColors.Null);
    Result.Canvas.Fill.Kind := TBrushKind.Solid;
    Result.Canvas.Stroke.Kind := TBrushKind.Solid;
    Result.Canvas.Stroke.Color := $FF707070;
    Result.Canvas.Stroke.Thickness := 1;
    if C = 0 then
    begin
      Result.Canvas.Fill.Color := TAlphaColors.White;
      Result.Canvas.FillRect(TRectF.Create(1, 1, 15, 15), 0, 0, [], 1);
      Result.Canvas.DrawLine(TPointF.Create(2, 14), TPointF.Create(14, 2), 1);
    end
    else
    begin
      Result.Canvas.Fill.Color := C;
      Result.Canvas.FillRect(TRectF.Create(1, 1, 15, 15), 0, 0, [], 1);
    end;
    Result.Canvas.DrawRect(TRectF.Create(1.5, 1.5, 14.5, 14.5), 0, 0, [], 1);
  finally
    Result.Canvas.EndScene;
  end;
end;

procedure AddColorItem(Combo: TComboBox; const Text: string; C: TAlphaColor);
var
  Item: TListBoxItem;
  Bmp: TBitmap;
begin
  Item := TListBoxItem.Create(Combo);
  Item.Text := Text;
  Item.Tag := Integer(C);
  Bmp := Swatch(C);
  try
    Item.ItemData.Bitmap.Assign(Bmp);
  finally
    Bmp.Free;
  end;
  Combo.AddObject(Item);
end;

procedure SetupColorCombo(Combo: TComboBox; AllowDefault: Boolean; const DefaultCaption: string);
var
  N: TNamedColor;
begin
  Combo.BeginUpdate;
  try
    Combo.Clear;
    if AllowDefault then
      AddColorItem(Combo, DefaultCaption, 0);
    for N in NamedColors do
      AddColorItem(Combo, N.Name, N.Color);
  finally
    Combo.EndUpdate;
  end;
  Combo.ItemIndex := 0;
end;

procedure SetComboColor(Combo: TComboBox; C: TAlphaColor);
var
  I: Integer;
begin
  for I := 0 to Combo.Count - 1 do
    if TAlphaColor(Combo.ListItems[I].Tag) = C then
    begin
      Combo.ItemIndex := I;
      Exit;
    end;
  if (C = 0) and (Combo.Count > 0) then
  begin
    Combo.ItemIndex := 0;
    Exit;
  end;
  AddColorItem(Combo, ColorName(C), C);
  Combo.ItemIndex := Combo.Count - 1;
end;

function GetComboColor(Combo: TComboBox): TAlphaColor;
begin
  if Combo.ItemIndex < 0 then
    Result := 0
  else
    Result := TAlphaColor(Combo.ListItems[Combo.ItemIndex].Tag);
end;

function ColorName(C: TAlphaColor): string;
var
  N: TNamedColor;
begin
  for N in NamedColors do
    if N.Color = C then
      Exit(N.Name);
  Result := '#' + IntToHex(C and $FFFFFF, 6);
end;

{ Colour arithmetic }

function Luminance(C: TAlphaColor): Single;
var
  R: TAlphaColorRec;
begin
  R := TAlphaColorRec(C);
  Result := (0.299 * R.R + 0.587 * R.G + 0.114 * R.B) / 255;
end;

function ContrastColor(Back: TAlphaColor): TAlphaColor;
begin
  if Luminance(Back) > 0.55 then
    Result := $FF141414
  else
    Result := TAlphaColors.White;
end;

function Blend(A, B: TAlphaColor; T: Single): TAlphaColor;
var
  X, Y, Z: TAlphaColorRec;
begin
  T := EnsureRange(T, 0, 1);
  X := TAlphaColorRec(A);
  Y := TAlphaColorRec(B);
  Z.A := Round(X.A + (Y.A - X.A) * T);
  Z.R := Round(X.R + (Y.R - X.R) * T);
  Z.G := Round(X.G + (Y.G - X.G) * T);
  Z.B := Round(X.B + (Y.B - X.B) * T);
  Result := Z.Color;
end;

function WithAlpha(C: TAlphaColor; Alpha: Byte): TAlphaColor;
begin
  Result := (C and $00FFFFFF) or (TAlphaColor(Alpha) shl 24);
end;

end.
