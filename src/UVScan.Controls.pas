unit UVScan.Controls;

(* Real-time controls (controls.json): commands that make a module switch an
   output, hold a value or reset something, e.g. GM mode $AE device control.

  { "version": 1,
    "controls": [
      { "name": "Check engine light", "group": "Outputs", "kind": "toggle",
        "module": "10", "on": "AE 01 80 80 00 00 00 00", "off": "AE 01 00 00 00 00 00 00" },
      { "name": "Reset long-term fuel trims", "group": "Resets", "kind": "action",
        "module": "10", "send": "AE 02 40 00 00 00 00 00",
        "confirm": "Reset the learned fuel trims?" },
      { "name": "Idle speed", "kind": "value", "module": "10",
        "on": "AE 03 01 {V} 00 00 00 00", "off": "AE 03 00 00 00 00 00 00",
        "min": 500, "max": 1600, "step": 25, "scale": 12.5, "units": "rpm" } ] }

  Commands are hex bytes starting with the mode byte; the message header
  (priority, target module, tester address) is added when sending. In a value
  control "{V}" stands for one byte and "{V16}" for two (high byte first):
  raw = round((value - offset) / scale).

  Kinds: action = one command; toggle = on / off; hold = on while the button is
  held down, off when let go; value = on with a value, off to release. *)

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections;

type
  TControlKind = (ckAction, ckToggle, ckHold, ckValue);

  TControlDef = class
  public
    Name: string;
    Group: string;
    Kind: TControlKind;
    Module: Byte;
    OnText: string;     // action: the command; toggle/hold: on; value: template with {V}/{V16}
    OffText: string;    // release command ('' = none)
    MinValue, MaxValue, Step, Scale, Offset: Double;
    Units: string;
    Confirm: string;    // asked before sending (action) or switching on
    Notes: string;
    BuiltIn: Boolean;   // came with UVScan (restorable)
    constructor Create;
    procedure Assign(Source: TControlDef);
    { '' when the control can be used, else what is wrong. }
    function Problem: string;
    { Full Class 2 messages ready to send. }
    function OnMessage(const Value: Double = 0): TBytes;
    function OffMessage: TBytes;
    function RawFor(const Value: Double): Int64;
    function HoldsControl: Boolean;  // stays active after "on" until released
    function ToJson: TJSONObject;
  end;

  TControlList = class
  private
    FItems: TObjectList<TControlDef>;
    FWarnings: TStringList;
    function GetCount: Integer;
    function GetItem(Index: Integer): TControlDef;
  public
    { Version of the built-in set this file last took built-ins from. }
    DefaultsVersion: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Add(C: TControlDef);
    procedure Delete(Index: Integer);
    procedure Move(CurIndex, NewIndex: Integer);
    function IndexOfName(const Name: string): Integer;
    procedure LoadFromJson(Root: TJSONObject);
    procedure LoadFromJsonText(const Text: string);
    procedure LoadFromFile(const FileName: string);
    function ToJson: TJSONObject;
    procedure SaveToFile(const FileName: string);
    { Adds built-in controls from Defaults whose names are missing; returns how many. }
    function RestoreBuiltIns(Defaults: TControlList): Integer;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TControlDef read GetItem; default;
    property Warnings: TStringList read FWarnings;
  end;

  EControlError = class(Exception);

const
  ControlsFileVersion = 1;
  ControlKindKeys: array[TControlKind] of string = ('action', 'toggle', 'hold', 'value');
  ControlKindCaptions: array[TControlKind] of string = ('Action (send once)', 'On / off',
    'Hold to run', 'Value');

(* Hex bytes with optional {V} / {V16} placeholders -> bytes. Raw is the value
  to put in the placeholders. Raises EControlError if the text is not valid. *)
function ExpandCommand(const Text: string; Raw: Int64 = 0): TBytes;
function HasValuePlaceholder(const Text: string): Boolean;

implementation

uses
  System.Math, System.StrUtils, UVScan.Class2, UVScan.Hex, UVScan.JsonFile;

function HasValuePlaceholder(const Text: string): Boolean;
begin
  Result := ContainsText(Text, '{V}') or ContainsText(Text, '{V16}');
end;

function ExpandCommand(const Text: string; Raw: Int64): TBytes;
var
  Token: string;
begin
  Result := nil;
  for Token in Text.Replace(',', ' ').Split([' ', #9], TStringSplitOptions.ExcludeEmpty) do
    if SameText(Token, '{V}') then
    begin
      if (Raw < 0) or (Raw > $FF) then
        raise EControlError.CreateFmt('Value %d does not fit in one byte ({V})', [Raw]);
      Result := Result + [Byte(Raw)];
    end
    else if SameText(Token, '{V16}') then
    begin
      if (Raw < 0) or (Raw > $FFFF) then
        raise EControlError.CreateFmt('Value %d does not fit in two bytes ({V16})', [Raw]);
      Result := Result + [Byte(Raw shr 8), Byte(Raw)];
    end
    else
      try
        if Length(Token) <> 2 then
          raise EConvertError.Create('');
        Result := Result + HexToBytes(Token);
      except
        on EConvertError do
          raise EControlError.CreateFmt('"%s" is not a hex byte', [Token]);
      end;
end;

function JFloat(Obj: TJSONObject; const Name: string; Default: Double): Double;
var
  V: TJSONValue;
begin
  V := Obj.GetValue(Name);
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsDouble
  else
    Result := Default;
end;

{ TControlDef }

constructor TControlDef.Create;
begin
  inherited;
  Module := AddrPcm;
  MaxValue := 255;
  Step := 1;
  Scale := 1;
end;

procedure TControlDef.Assign(Source: TControlDef);
begin
  Name := Source.Name;
  Group := Source.Group;
  Kind := Source.Kind;
  Module := Source.Module;
  OnText := Source.OnText;
  OffText := Source.OffText;
  MinValue := Source.MinValue;
  MaxValue := Source.MaxValue;
  Step := Source.Step;
  Scale := Source.Scale;
  Offset := Source.Offset;
  Units := Source.Units;
  Confirm := Source.Confirm;
  Notes := Source.Notes;
  BuiltIn := Source.BuiltIn;
end;

function TControlDef.HoldsControl: Boolean;
begin
  Result := Kind in [ckToggle, ckHold, ckValue];
end;

function TControlDef.RawFor(const Value: Double): Int64;
begin
  Result := Round((Value - Offset) / Scale);
end;

function TControlDef.Problem: string;
var
  B: TBytes;
begin
  Result := '';
  if Trim(Name) = '' then
    Exit('Give the control a name');
  try
    if Kind = ckValue then
    begin
      if not HasValuePlaceholder(OnText) then
        Exit('A value control needs {V} or {V16} in its command');
      if Scale = 0 then
        Exit('Scale cannot be 0');
      if MaxValue <= MinValue then
        Exit('Max must be larger than min');
      if Step <= 0 then
        Exit('Step must be larger than 0');
      ExpandCommand(OnText, RawFor(MinValue));
      B := ExpandCommand(OnText, RawFor(MaxValue));
    end
    else
    begin
      if HasValuePlaceholder(OnText) then
        Exit('{V} is only for value controls');
      B := ExpandCommand(OnText);
    end;
    if Length(B) = 0 then
      Exit('Enter the command bytes (mode first, e.g. AE 01 ...)');
    if Length(B) > 8 then
      Exit('Too long: a Class 2 request is the mode byte plus at most 7 data bytes');
    if (Kind in [ckToggle, ckHold]) and (Trim(OffText) = '') then
      Exit('An on / off or hold control needs an "off" command');
    if Trim(OffText) <> '' then
    begin
      if HasValuePlaceholder(OffText) then
        Exit('The off command cannot contain {V}');
      if Length(ExpandCommand(OffText)) = 0 then
        Exit('The off command is empty');
    end;
  except
    on E: EControlError do
      Result := E.Message;
  end;
end;

function TControlDef.OnMessage(const Value: Double): TBytes;
var
  B: TBytes;
begin
  if Kind = ckValue then
    B := ExpandCommand(OnText, RawFor(EnsureRange(Value, MinValue, MaxValue)))
  else
    B := ExpandCommand(OnText);
  if Length(B) = 0 then
    raise EControlError.Create('No command');
  Result := BuildMessage(Module, AddrTool, B[0], Copy(B, 1, MaxInt));
end;

function TControlDef.OffMessage: TBytes;
var
  B: TBytes;
begin
  Result := nil;
  if Trim(OffText) = '' then
    Exit;
  B := ExpandCommand(OffText);
  if Length(B) > 0 then
    Result := BuildMessage(Module, AddrTool, B[0], Copy(B, 1, MaxInt));
end;

function TControlDef.ToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', Name);
  if Group <> '' then
    Result.AddPair('group', Group);
  Result.AddPair('kind', ControlKindKeys[Kind]);
  Result.AddPair('module', IntToHex(Module, 2));
  if Kind = ckAction then
    Result.AddPair('send', OnText)
  else
    Result.AddPair('on', OnText);
  if OffText <> '' then
    Result.AddPair('off', OffText);
  if Kind = ckValue then
  begin
    Result.AddPair('min', TJSONNumber.Create(MinValue));
    Result.AddPair('max', TJSONNumber.Create(MaxValue));
    Result.AddPair('step', TJSONNumber.Create(Step));
    Result.AddPair('scale', TJSONNumber.Create(Scale));
    if Offset <> 0 then
      Result.AddPair('offset', TJSONNumber.Create(Offset));
    if Units <> '' then
      Result.AddPair('units', Units);
  end;
  if Confirm <> '' then
    Result.AddPair('confirm', Confirm);
  if Notes <> '' then
    Result.AddPair('notes', Notes);
  if BuiltIn then
    Result.AddPair('builtIn', TJSONBool.Create(True));
end;

{ TControlList }

constructor TControlList.Create;
begin
  inherited;
  FItems := TObjectList<TControlDef>.Create(True);
  FWarnings := TStringList.Create;
end;

destructor TControlList.Destroy;
begin
  FItems.Free;
  FWarnings.Free;
  inherited;
end;

procedure TControlList.Clear;
begin
  FItems.Clear;
  FWarnings.Clear;
end;

function TControlList.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TControlList.GetItem(Index: Integer): TControlDef;
begin
  Result := FItems[Index];
end;

procedure TControlList.Add(C: TControlDef);
begin
  FItems.Add(C);
end;

procedure TControlList.Delete(Index: Integer);
begin
  FItems.Delete(Index);
end;

procedure TControlList.Move(CurIndex, NewIndex: Integer);
begin
  FItems.Move(CurIndex, NewIndex);
end;

function TControlList.IndexOfName(const Name: string): Integer;
begin
  for Result := 0 to FItems.Count - 1 do
    if SameText(FItems[Result].Name, Name) then
      Exit;
  Result := -1;
end;

procedure TControlList.LoadFromJson(Root: TJSONObject);
var
  Arr: TJSONArray;
  I, K: Integer;
  E: TJSONObject;
  C: TControlDef;
  Where, P: string;
begin
  Clear;
  DefaultsVersion := JInt(Root, 'defaults', 0);
  Arr := JArr(Root, 'controls');
  if Arr = nil then
    Exit;
  for I := 0 to Arr.Count - 1 do
  begin
    if not (Arr.Items[I] is TJSONObject) then
      Continue;
    E := TJSONObject(Arr.Items[I]);
    C := TControlDef.Create;
    try
      C.Name := Trim(JStr(E, 'name'));
      Where := Format('controls[%d] "%s"', [I, C.Name]);
      C.Group := Trim(JStr(E, 'group'));
      C.Kind := ckAction;
      for K := 0 to Ord(High(TControlKind)) do
        if SameText(JStr(E, 'kind', 'action'), ControlKindKeys[TControlKind(K)]) then
          C.Kind := TControlKind(K);
      C.Module := Byte(StrToIntDef('$' + JStr(E, 'module', '10'), AddrPcm));
      C.OnText := JStr(E, 'on', JStr(E, 'send'));
      C.OffText := JStr(E, 'off');
      C.MinValue := JFloat(E, 'min', 0);
      C.MaxValue := JFloat(E, 'max', 255);
      C.Step := JFloat(E, 'step', 1);
      C.Scale := JFloat(E, 'scale', 1);
      C.Offset := JFloat(E, 'offset', 0);
      C.Units := JStr(E, 'units');
      C.Confirm := JStr(E, 'confirm');
      C.Notes := JStr(E, 'notes');
      C.BuiltIn := JBool(E, 'builtIn', False);
      P := C.Problem;
      if P <> '' then
        FWarnings.Add(Where + ': ' + P); // kept, so it can be fixed in the editor
      FItems.Add(C);
      C := nil;
    finally
      C.Free;
    end;
  end;
end;

procedure TControlList.LoadFromJsonText(const Text: string);
var
  Root: TJSONObject;
begin
  Root := ParseJsonObject(Text, 'controls.json');
  try
    LoadFromJson(Root);
  finally
    Root.Free;
  end;
end;

procedure TControlList.LoadFromFile(const FileName: string);
var
  Root: TJSONObject;
begin
  Root := ReadJsonObject(FileName);
  try
    LoadFromJson(Root);
  finally
    Root.Free;
  end;
end;

function TControlList.ToJson: TJSONObject;
var
  Arr: TJSONArray;
  C: TControlDef;
begin
  Result := TJSONObject.Create;
  Result.AddPair('version', TJSONNumber.Create(ControlsFileVersion));
  Result.AddPair('defaults', TJSONNumber.Create(DefaultsVersion));
  Arr := TJSONArray.Create;
  for C in FItems do
    Arr.AddElement(C.ToJson);
  Result.AddPair('controls', Arr);
end;

procedure TControlList.SaveToFile(const FileName: string);
var
  Root: TJSONObject;
begin
  Root := ToJson;
  try
    WriteJsonFile(FileName, Root);
  finally
    Root.Free;
  end;
end;

function TControlList.RestoreBuiltIns(Defaults: TControlList): Integer;
var
  I: Integer;
  C: TControlDef;
begin
  Result := 0;
  for I := 0 to Defaults.Count - 1 do
    if Defaults[I].BuiltIn and (IndexOfName(Defaults[I].Name) < 0) then
    begin
      C := TControlDef.Create;
      C.Assign(Defaults[I]);
      FItems.Add(C);
      Inc(Result);
    end;
end;

end.
