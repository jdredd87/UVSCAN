unit UVScan.Display;

(* How PIDs look in the live grid and on the dashboard (display.json):

  { "version": 1,
    "pids": [
      { "pid": 14, "fontSize": 12, "textColor": "#000000", "rowColor": "#C8F0C8",
        "levels": [
          { "name": "Alarm", "when": ">=", "value": 4, "rowColor": "#FF5050",
            "textColor": "#FFFFFF", "flash": true, "sound": "alarm", "repeat": true },
          { "name": "Warning", "when": ">=", "value": 1, "rowColor": "#FFE680" } ] } ],
    "gauges": [
      { "pid": 14, "style": "dial", "size": "large", "min": 0, "max": 20 } ] }

  Levels are checked in order; the first that matches the current value
  applies. Colours are "#RRGGBB"; a missing colour means "use the normal
  look". "pid" is the PID id from pids.json. *)

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections, System.UITypes, Vcl.Graphics;

type
  TCompareOp = (coGE, coGT, coLE, coLT, coEQ, coNE);
  TAlertSound = (asNone, asBeep, asAlert, asAlarm, asFile);
  TGaugeStyle = (gsDial, gsBar, gsNumber);
  TGaugeSize = (gzSmall, gzMedium, gzLarge);

  TDisplayLevel = record
    Name: string;
    Op: TCompareOp;
    Value: Double;
    RowColor: TColor;    // clNone = keep the normal row colour
    TextColor: TColor;   // clNone = keep the normal text colour
    Flash: Boolean;
    Sound: TAlertSound;
    SoundFile: string;
    RepeatSound: Boolean;
    function Matches(const V: Double): Boolean;
    function Describe: string;  // e.g. ">= 4"
    function IsAttentionGrabbing: Boolean;
  end;

  TPidDisplay = class
  public
    PidId: Integer;
    FontSize: Integer;   // 0 = default
    TextColor: TColor;   // clNone = default
    RowColor: TColor;    // clNone = default
    Levels: TArray<TDisplayLevel>;
    constructor Create(APidId: Integer);
    procedure Assign(Source: TPidDisplay);
    { Index of the first matching level, -1 if none (or the value is not a number). }
    function LevelFor(const V: Double): Integer;
    function IsDefault: Boolean;
  end;

  TGauge = record
    PidId: Integer;
    Style: TGaugeStyle;
    Size: TGaugeSize;
    MinValue, MaxValue: Double;
  end;

  { What a value should look like right now (normal look + matching level). }
  TResolvedStyle = record
    Level: Integer;      // -1 = normal
    LevelName: string;
    FontSize: Integer;   // 0 = default
    RowColor: TColor;    // clNone = default
    TextColor: TColor;   // clNone = default
    Flash: Boolean;
    NormalRowColor: TColor;   // the PID's own look, shown in the "off" half of a flash
    NormalTextColor: TColor;
    { The colours to paint now; FlashOn alternates while a flashing level is active. }
    procedure Colors(FlashOn: Boolean; out Row, Text: TColor);
  end;

  { A coloured stretch of a gauge scale, derived from the levels. }
  TGaugeZone = record
    FromValue, ToValue: Double;
    Color: TColor;
  end;

  TDisplaySettings = class
  private
    FPids: TObjectDictionary<Integer, TPidDisplay>;
    FGauges: TList<TGauge>;
    FWarnings: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    { nil if the PID has no display settings. }
    function Find(PidId: Integer): TPidDisplay;
    { Replaces (or removes, if Display is nil or all-default) a PID's settings. Takes a copy. }
    procedure Put(PidId: Integer; Display: TPidDisplay);
    function Resolve(PidId: Integer; const Value: Double): TResolvedStyle;
    function Zones(PidId: Integer; const MinValue, MaxValue: Double): TArray<TGaugeZone>;
    procedure LoadFromJson(Root: TJSONObject);
    procedure LoadFromJsonText(const Text: string);
    procedure LoadFromFile(const FileName: string);
    function ToJson: TJSONObject;
    procedure SaveToFile(const FileName: string);
    property Gauges: TList<TGauge> read FGauges;
    property Warnings: TStringList read FWarnings;
  end;

const
  DisplayFileVersion = 1;
  CompareOpKeys: array[TCompareOp] of string = ('>=', '>', '<=', '<', '=', '<>');
  CompareOpCaptions: array[TCompareOp] of string = ('at or above', 'above', 'at or below', 'below', 'equal to', 'not equal to');
  AlertSoundKeys: array[TAlertSound] of string = ('none', 'beep', 'alert', 'alarm', 'file');
  AlertSoundCaptions: array[TAlertSound] of string = ('No sound', 'Beep', 'Windows alert sound', 'Alarm tone', 'Sound file...');
  GaugeStyleKeys: array[TGaugeStyle] of string = ('dial', 'bar', 'number');
  GaugeStyleCaptions: array[TGaugeStyle] of string = ('Dial', 'Bar', 'Big number');
  GaugeSizeKeys: array[TGaugeSize] of string = ('small', 'medium', 'large');
  GaugeSizeCaptions: array[TGaugeSize] of string = ('Small', 'Medium', 'Large');

function ColorToHex(C: TColor): string;
function HexToColor(const S: string; Default: TColor): TColor;
function NewLevel: TDisplayLevel;
{ Coloured stretches of a scale for these levels (lowest priority first). }
function ZonesFromLevels(const Levels: TArray<TDisplayLevel>; const MinValue, MaxValue: Double): TArray<TGaugeZone>;
{ First level that matches V, -1 if none. }
function LevelIndexFor(const Levels: TArray<TDisplayLevel>; const V: Double): Integer;
function LevelsToJson(const Levels: TArray<TDisplayLevel>): TJSONArray;
function LevelsFromJson(Arr: TJSONArray): TArray<TDisplayLevel>;
{ Normal look + the first matching level; D may be nil (all defaults). }
function ResolveDisplay(D: TPidDisplay; const Value: Double): TResolvedStyle;
type
  { Returns the id of the catalog PID with this PID code (preferring one with
    these units), or -1. }
  TPidCodeResolver = reference to function(const PidCode, Units: string): Integer;

{ The built-in examples name PIDs by "pidCode" (and optionally "units"),
  because ids differ between catalogs. Replaces those with "pid" ids, drops
  entries the catalog does not have, and returns how many PID entries remain. }
function ResolveSeedJson(Root: TJSONObject; const Resolver: TPidCodeResolver): Integer;

{ Accepts "4.5" and the local decimal separator ("4,5"). }
function TryParseNumber(const S: string; out V: Double): Boolean;

implementation

uses
  System.Math, UVScan.JsonFile;

{ Colours }

function ColorToHex(C: TColor): string;
var
  RGB: Cardinal;
begin
  RGB := TColorRec.ColorToRGB(C);
  Result := Format('#%.2X%.2X%.2X', [RGB and $FF, (RGB shr 8) and $FF, (RGB shr 16) and $FF]);
end;

function HexToColor(const S: string; Default: TColor): TColor;
var
  T: string;
  V: Integer;
begin
  T := Trim(S);
  if T.StartsWith('#') then
    Delete(T, 1, 1);
  if (Length(T) <> 6) or not TryStrToInt('$' + T, V) then
    Exit(Default);
  // #RRGGBB -> TColor ($00BBGGRR)
  Result := TColor(((V and $FF) shl 16) or (V and $FF00) or ((V shr 16) and $FF));
end;

function NewLevel: TDisplayLevel;
begin
  Result := Default(TDisplayLevel);
  Result.Name := 'Warning';
  Result.Op := coGE;
  Result.RowColor := clNone;
  Result.TextColor := clNone;
end;

{ TDisplayLevel }

function TDisplayLevel.Matches(const V: Double): Boolean;
begin
  if IsNan(V) then
    Exit(False);
  case Op of
    coGE: Result := V >= Value;
    coGT: Result := V > Value;
    coLE: Result := V <= Value;
    coLT: Result := V < Value;
    coEQ: Result := SameValue(V, Value);
  else
    Result := not SameValue(V, Value);
  end;
end;

function TDisplayLevel.Describe: string;
begin
  Result := CompareOpKeys[Op] + ' ' + FormatFloat('0.###', Value);
end;

function TDisplayLevel.IsAttentionGrabbing: Boolean;
begin
  Result := Flash or (Sound <> asNone);
end;

function ResolveSeedJson(Root: TJSONObject; const Resolver: TPidCodeResolver): Integer;

  procedure ResolveArray(const Name: string);
  var
    Arr: TJSONArray;
    I, Id: Integer;
    E: TJSONObject;
  begin
    Arr := JArr(Root, Name);
    if Arr = nil then
      Exit;
    for I := Arr.Count - 1 downto 0 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      E := TJSONObject(Arr.Items[I]);
      if E.GetValue('pidCode') = nil then
        Continue;
      Id := Resolver(JStr(E, 'pidCode'), JStr(E, 'units'));
      if Id < 0 then
      begin
        Arr.Remove(I).Free;
        Continue;
      end;
      E.RemovePair('pidCode').Free;
      E.RemovePair('units').Free;
      E.AddPair('pid', TJSONNumber.Create(Id));
    end;
  end;

var
  Arr: TJSONArray;
begin
  ResolveArray('pids');
  ResolveArray('gauges');
  Arr := JArr(Root, 'pids');
  if Arr = nil then
    Result := 0
  else
    Result := Arr.Count;
end;

function TryParseNumber(const S: string; out V: Double): Boolean;
begin
  Result := TryStrToFloat(Trim(S), V, TFormatSettings.Invariant) or TryStrToFloat(Trim(S), V);
end;

{ TResolvedStyle }

procedure TResolvedStyle.Colors(FlashOn: Boolean; out Row, Text: TColor);
begin
  if Flash and not FlashOn then
  begin
    Row := NormalRowColor;
    Text := NormalTextColor;
  end
  else
  begin
    Row := RowColor;
    Text := TextColor;
  end;
end;

{ TPidDisplay }

constructor TPidDisplay.Create(APidId: Integer);
begin
  inherited Create;
  PidId := APidId;
  TextColor := clNone;
  RowColor := clNone;
end;

procedure TPidDisplay.Assign(Source: TPidDisplay);
begin
  PidId := Source.PidId;
  FontSize := Source.FontSize;
  TextColor := Source.TextColor;
  RowColor := Source.RowColor;
  Levels := Copy(Source.Levels);
end;

function TPidDisplay.LevelFor(const V: Double): Integer;
begin
  for Result := 0 to High(Levels) do
    if Levels[Result].Matches(V) then
      Exit;
  Result := -1;
end;

function TPidDisplay.IsDefault: Boolean;
begin
  Result := (FontSize = 0) and (TextColor = clNone) and (RowColor = clNone) and (Length(Levels) = 0);
end;

{ TDisplaySettings }

constructor TDisplaySettings.Create;
begin
  inherited;
  FPids := TObjectDictionary<Integer, TPidDisplay>.Create([doOwnsValues]);
  FGauges := TList<TGauge>.Create;
  FWarnings := TStringList.Create;
end;

destructor TDisplaySettings.Destroy;
begin
  FPids.Free;
  FGauges.Free;
  FWarnings.Free;
  inherited;
end;

procedure TDisplaySettings.Clear;
begin
  FPids.Clear;
  FGauges.Clear;
  FWarnings.Clear;
end;

function TDisplaySettings.Find(PidId: Integer): TPidDisplay;
begin
  if not FPids.TryGetValue(PidId, Result) then
    Result := nil;
end;

procedure TDisplaySettings.Put(PidId: Integer; Display: TPidDisplay);
var
  D: TPidDisplay;
begin
  if (Display = nil) or Display.IsDefault then
  begin
    FPids.Remove(PidId);
    Exit;
  end;
  D := TPidDisplay.Create(PidId);
  D.Assign(Display);
  D.PidId := PidId;
  FPids.AddOrSetValue(PidId, D);
end;

function TDisplaySettings.Resolve(PidId: Integer; const Value: Double): TResolvedStyle;
begin
  Result := ResolveDisplay(Find(PidId), Value);
end;

function ResolveDisplay(D: TPidDisplay; const Value: Double): TResolvedStyle;
var
  L: TDisplayLevel;
begin
  Result := Default(TResolvedStyle);
  Result.Level := -1;
  Result.RowColor := clNone;
  Result.TextColor := clNone;
  Result.NormalRowColor := clNone;
  Result.NormalTextColor := clNone;
  if D = nil then
    Exit;
  Result.FontSize := D.FontSize;
  Result.RowColor := D.RowColor;
  Result.TextColor := D.TextColor;
  Result.NormalRowColor := D.RowColor;
  Result.NormalTextColor := D.TextColor;
  Result.Level := D.LevelFor(Value);
  if Result.Level < 0 then
    Exit;
  L := D.Levels[Result.Level];
  Result.LevelName := L.Name;
  if L.RowColor <> clNone then
    Result.RowColor := L.RowColor;
  if L.TextColor <> clNone then
    Result.TextColor := L.TextColor;
  Result.Flash := L.Flash;
end;

function TDisplaySettings.Zones(PidId: Integer; const MinValue, MaxValue: Double): TArray<TGaugeZone>;
var
  D: TPidDisplay;
begin
  Result := nil;
  D := Find(PidId);
  if D <> nil then
    Result := ZonesFromLevels(D.Levels, MinValue, MaxValue);
end;

function LevelIndexFor(const Levels: TArray<TDisplayLevel>; const V: Double): Integer;
begin
  for Result := 0 to High(Levels) do
    if Levels[Result].Matches(V) then
      Exit;
  Result := -1;
end;

function ZonesFromLevels(const Levels: TArray<TDisplayLevel>; const MinValue, MaxValue: Double): TArray<TGaugeZone>;
var
  I: Integer;
  L: TDisplayLevel;
  Z: TGaugeZone;
begin
  Result := nil;
  // Lowest priority first so the first (winning) level is drawn on top.
  for I := High(Levels) downto 0 do
  begin
    L := Levels[I];
    if L.RowColor = clNone then
      Continue;
    case L.Op of
      coGE, coGT:
        begin
          Z.FromValue := Max(L.Value, MinValue);
          Z.ToValue := MaxValue;
        end;
      coLE, coLT:
        begin
          Z.FromValue := MinValue;
          Z.ToValue := Min(L.Value, MaxValue);
        end;
    else
      Continue; // = and <> have no stretch to show
    end;
    Z.Color := L.RowColor;
    if Z.ToValue > Z.FromValue then
      Result := Result + [Z];
  end;
end;

function KeyIndexOf(const Keys: array of string; const S: string; Default: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Keys) do
    if SameText(Keys[I], Trim(S)) then
      Exit(I);
  Result := Default;
end;

function JFloat(Obj: TJSONObject; const Name: string; Default: Double): Double;
var
  V: TJSONValue;
begin
  V := Obj.GetValue(Name);
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsDouble
  else if (V is TJSONString) and TryStrToFloat(TJSONString(V).Value, Result, TFormatSettings.Invariant) then
    // parsed
  else
    Result := Default;
end;

function LevelsFromJson(Arr: TJSONArray): TArray<TDisplayLevel>;
var
  J: Integer;
  LE: TJSONObject;
  L: TDisplayLevel;
begin
  Result := nil;
  if Arr = nil then
    Exit;
  for J := 0 to Arr.Count - 1 do
    if Arr.Items[J] is TJSONObject then
    begin
      LE := TJSONObject(Arr.Items[J]);
      L := NewLevel;
      L.Name := JStr(LE, 'name', 'Level ' + IntToStr(J + 1));
      L.Op := TCompareOp(KeyIndexOf(CompareOpKeys, JStr(LE, 'when', '>='), 0));
      L.Value := JFloat(LE, 'value', 0);
      L.RowColor := HexToColor(JStr(LE, 'rowColor'), clNone);
      L.TextColor := HexToColor(JStr(LE, 'textColor'), clNone);
      L.Flash := JBool(LE, 'flash', False);
      L.Sound := TAlertSound(KeyIndexOf(AlertSoundKeys, JStr(LE, 'sound', 'none'), 0));
      L.SoundFile := JStr(LE, 'soundFile');
      L.RepeatSound := JBool(LE, 'repeat', False);
      Result := Result + [L];
    end;
end;

function LevelsToJson(const Levels: TArray<TDisplayLevel>): TJSONArray;
var
  L: TDisplayLevel;
  LE: TJSONObject;
begin
  Result := TJSONArray.Create;
  for L in Levels do
  begin
    LE := TJSONObject.Create;
    LE.AddPair('name', L.Name);
    LE.AddPair('when', CompareOpKeys[L.Op]);
    LE.AddPair('value', TJSONNumber.Create(L.Value));
    if L.RowColor <> clNone then
      LE.AddPair('rowColor', ColorToHex(L.RowColor));
    if L.TextColor <> clNone then
      LE.AddPair('textColor', ColorToHex(L.TextColor));
    if L.Flash then
      LE.AddPair('flash', TJSONBool.Create(True));
    if L.Sound <> asNone then
      LE.AddPair('sound', AlertSoundKeys[L.Sound]);
    if (L.Sound = asFile) and (L.SoundFile <> '') then
      LE.AddPair('soundFile', L.SoundFile);
    if L.RepeatSound then
      LE.AddPair('repeat', TJSONBool.Create(True));
    Result.AddElement(LE);
  end;
end;

procedure TDisplaySettings.LoadFromJson(Root: TJSONObject);
var
  Arr: TJSONArray;
  I: Integer;
  E: TJSONObject;
  D: TPidDisplay;
  G: TGauge;
begin
  Clear;
  Arr := JArr(Root, 'pids');
  if Arr <> nil then
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      E := TJSONObject(Arr.Items[I]);
      D := TPidDisplay.Create(JInt(E, 'pid', -1));
      try
        if D.PidId < 0 then
        begin
          FWarnings.Add(Format('pids[%d]: missing "pid"', [I]));
          Continue;
        end;
        D.FontSize := EnsureRange(JInt(E, 'fontSize', 0), 0, 72);
        D.TextColor := HexToColor(JStr(E, 'textColor'), clNone);
        D.RowColor := HexToColor(JStr(E, 'rowColor'), clNone);
        D.Levels := LevelsFromJson(JArr(E, 'levels'));
        FPids.AddOrSetValue(D.PidId, D);
        D := nil;
      finally
        D.Free;
      end;
    end;

  Arr := JArr(Root, 'gauges');
  if Arr <> nil then
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      E := TJSONObject(Arr.Items[I]);
      G.PidId := JInt(E, 'pid', -1);
      if G.PidId < 0 then
        Continue;
      G.Style := TGaugeStyle(KeyIndexOf(GaugeStyleKeys, JStr(E, 'style', 'dial'), 0));
      G.Size := TGaugeSize(KeyIndexOf(GaugeSizeKeys, JStr(E, 'size', 'medium'), 1));
      G.MinValue := JFloat(E, 'min', 0);
      G.MaxValue := JFloat(E, 'max', 100);
      if G.MaxValue <= G.MinValue then
        G.MaxValue := G.MinValue + 1;
      FGauges.Add(G);
    end;
end;

procedure TDisplaySettings.LoadFromJsonText(const Text: string);
var
  Root: TJSONObject;
begin
  Root := ParseJsonObject(Text, 'display.json');
  try
    LoadFromJson(Root);
  finally
    Root.Free;
  end;
end;

procedure TDisplaySettings.LoadFromFile(const FileName: string);
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

function TDisplaySettings.ToJson: TJSONObject;
var
  Arr: TJSONArray;
  E: TJSONObject;
  Ids: TArray<Integer>;
  Id: Integer;
  D: TPidDisplay;
  G: TGauge;
begin
  Result := TJSONObject.Create;
  Result.AddPair('version', TJSONNumber.Create(DisplayFileVersion));
  Arr := TJSONArray.Create;
  Result.AddPair('pids', Arr);
  Ids := FPids.Keys.ToArray;
  TArray.Sort<Integer>(Ids);
  for Id in Ids do
  begin
    D := FPids[Id];
    E := TJSONObject.Create;
    E.AddPair('pid', TJSONNumber.Create(D.PidId));
    if D.FontSize > 0 then
      E.AddPair('fontSize', TJSONNumber.Create(D.FontSize));
    if D.TextColor <> clNone then
      E.AddPair('textColor', ColorToHex(D.TextColor));
    if D.RowColor <> clNone then
      E.AddPair('rowColor', ColorToHex(D.RowColor));
    if Length(D.Levels) > 0 then
      E.AddPair('levels', LevelsToJson(D.Levels));
    Arr.AddElement(E);
  end;

  Arr := TJSONArray.Create;
  Result.AddPair('gauges', Arr);
  for G in FGauges do
  begin
    E := TJSONObject.Create;
    E.AddPair('pid', TJSONNumber.Create(G.PidId));
    E.AddPair('style', GaugeStyleKeys[G.Style]);
    E.AddPair('size', GaugeSizeKeys[G.Size]);
    E.AddPair('min', TJSONNumber.Create(G.MinValue));
    E.AddPair('max', TJSONNumber.Create(G.MaxValue));
    Arr.AddElement(E);
  end;
end;

procedure TDisplaySettings.SaveToFile(const FileName: string);
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

end.
