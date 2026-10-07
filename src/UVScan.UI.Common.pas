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
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.ListBox, FMX.StdCtrls;

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

{ True on phones and tablets: windows are full screen, no mouse hover. }
function IsMobile: Boolean;

{ Keeps Form's content clear of the phone's status and navigation bars
  (Android draws apps edge to edge). Does nothing on a desktop. }
procedure KeepInSafeArea(Form: TCommonCustomForm);

implementation

uses
  System.Math, FMX.DialogService, FMX.Dialogs, FMX.Platform;

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
begin
  if not IsMobile then
    Exit;
  Form.OnSafeAreaChanged := TSafeArea.Changed;
  if TPlatformServices.Current.SupportsPlatformService(IFMXWindowSafeAreaService, Svc) then
    TSafeArea.Changed(Form, Svc.GetSafeAreaInsets(Form));
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
