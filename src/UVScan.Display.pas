unit UVScan.Display;

(* How PIDs look in the live grid and on the dashboard (display.json):

  { "version": 1,
    "pids": [
      { "pid": 14, "fontSize": 12, "textColor": "#000000", "rowColor": "#C8F0C8",
        "levels": [
          { "name": "Alarm", "when": ">=", "value": 4, "rowColor": "#FF5050",
            "textColor": "#FFFFFF", "flash": true, "sound": "alarm", "repeat": true },
          { "name": "Warning", "when": ">=", "value": 1, "rowColor": "#FFE680" } ] } ],
    "dashboard": "Knock check",
    "dashboards": [
      { "name": "Knock check",
        "gauges": [ { "pid": 14, "style": "dial", "size": "large", "min": 0, "max": 20 } ] } ],
    "builtIns": ["Knock check"] }

  Levels are checked in order; the first that matches the current value
  applies. Colours are "#RRGGBB"; a missing colour means "use the normal
  look". "pid" is the PID id from pids.json. "dashboard" is the one shown;
  "builtIns" names the built-in dashboards this file has been given (see
  UVScan.Defaults.AddNewBuiltIns). A file from before there were several
  dashboards has one "gauges" list: that becomes the dashboard "Main". *)

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections, System.UITypes;

const
  { "Not set": use the normal colour. Real colours are always opaque. }
  NoColor = TAlphaColor(0);

type
  TCompareOp = (coGE, coGT, coLE, coLT, coEQ, coNE);
  TAlertSound = (asNone, asBeep, asAlert, asAlarm, asFile);
  TGaugeStyle = (gsDial, gsBar, gsNumber);
  TGaugeSize = (gzSmall, gzMedium, gzLarge);

  TDisplayLevel = record
    Name: string;
    Op: TCompareOp;
    Value: Double;
    RowColor: TAlphaColor;    // NoColor = keep the normal row colour
    TextColor: TAlphaColor;   // NoColor = keep the normal text colour
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
    TextColor: TAlphaColor;   // NoColor = default
    RowColor: TAlphaColor;    // NoColor = default
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

  { A named set of gauges (one page of the Gauges tab). }
  TDashboard = class
  public
    Name: string;
    Gauges: TList<TGauge>;
    constructor Create(const AName: string);
    destructor Destroy; override;
  end;

  { What a value should look like right now (normal look + matching level). }
  TResolvedStyle = record
    Level: Integer;      // -1 = normal
    LevelName: string;
    FontSize: Integer;   // 0 = default
    RowColor: TAlphaColor;    // NoColor = default
    TextColor: TAlphaColor;   // NoColor = default
    Flash: Boolean;
    NormalRowColor: TAlphaColor;   // the PID's own look, shown in the "off" half of a flash
    NormalTextColor: TAlphaColor;
    { The colours to paint now; FlashOn alternates while a flashing level is active. }
    procedure Colors(FlashOn: Boolean; out Row, Text: TAlphaColor);
  end;

  { A coloured stretch of a gauge scale, derived from the levels. }
  TGaugeZone = record
    FromValue, ToValue: Double;
    Color: TAlphaColor;
  end;

  TDisplaySettings = class
  private
    FPids: TObjectDictionary<Integer, TPidDisplay>;
    FDashboards: TObjectList<TDashboard>;
    FCurrent: Integer;
    FWarnings: TStringList;
    function GetGauges: TList<TGauge>;
    function GetDashboard(Index: Integer): TDashboard;
    function GetDashboardCount: Integer;
    procedure SetCurrent(Value: Integer);
  public
    BuiltIns: TArray<string>;
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
    function IndexOfDashboard(const Name: string): Integer;
    { Adds an empty dashboard (or finds the one of that name); returns its index. }
    function AddDashboard(const Name: string): Integer;
    { Removes a dashboard; the last one is only emptied. }
    procedure DeleteDashboard(Index: Integer);
    function DashboardNames: TArray<string>;
    { The gauges of the dashboard shown. }
    property Gauges: TList<TGauge> read GetGauges;
    property Dashboards[Index: Integer]: TDashboard read GetDashboard;
    property DashboardCount: Integer read GetDashboardCount;
    { Index of the dashboard shown (there is always at least one). }
    property Current: Integer read FCurrent write SetCurrent;
    property Warnings: TStringList read FWarnings;
  end;

const
  DisplayFileVersion = 1;
  { The dashboard an older display.json's gauges go on. }
  MainDashboard = 'Main';
  CompareOpKeys: array[TCompareOp] of string = ('>=', '>', '<=', '<', '=', '<>');
  CompareOpCaptions: array[TCompareOp] of string = ('at or above', 'above', 'at or below', 'below', 'equal to', 'not equal to');
  AlertSoundKeys: array[TAlertSound] of string = ('none', 'beep', 'alert', 'alarm', 'file');
  AlertSoundCaptions: array[TAlertSound] of string = ('No sound', 'Beep', 'Windows alert sound', 'Alarm tone', 'Sound file...');
  GaugeStyleKeys: array[TGaugeStyle] of string = ('dial', 'bar', 'number');
  GaugeStyleCaptions: array[TGaugeStyle] of string = ('Dial', 'Bar', 'Big number');
  GaugeSizeKeys: array[TGaugeSize] of string = ('small', 'medium', 'large');
  GaugeSizeCaptions: array[TGaugeSize] of string = ('Small', 'Medium', 'Large');

function ColorToHex(C: TAlphaColor): string;
function HexToColor(const S: string; Default: TAlphaColor): TAlphaColor;
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
  TPidCodeResolver = reference to function(const PidCode, Units, Name: string): Integer;

{ The built-in examples name PIDs by "pidCode" (and optionally "units", and
  "pidName" for PIDs that share a code, like the bits of a status PID),
  because ids differ between catalogs. Replaces those with "pid" ids (in
  "pids", "gauges" and each of "dashboards"), drops entries the catalog does
  not have, and returns how many PID entries remain. }
function ResolveSeedJson(Root: TJSONObject; const Resolver: TPidCodeResolver): Integer;

{ Accepts "4.5" and the local decimal separator ("4,5"). }
function TryParseNumber(const S: string; out V: Double): Boolean;

implementation

uses
  System.Math, UVScan.JsonFile;

{ Colours }

function ColorToHex(C: TAlphaColor): string;
begin
  Result := '#' + IntToHex(C and $FFFFFF, 6);
end;

function HexToColor(const S: string; Default: TAlphaColor): TAlphaColor;
var
  T: string;
  V: Integer;
begin
  T := Trim(S);
  if T.StartsWith('#') then
    Delete(T, 1, 1);
  if (Length(T) <> 6) or not TryStrToInt('$' + T, V) then
    Exit(Default);
  Result := TAlphaColor($FF000000) or TAlphaColor(V and $FFFFFF);
end;

function NewLevel: TDisplayLevel;
begin
  Result := Default(TDisplayLevel);
  Result.Name := 'Warning';
  Result.Op := coGE;
  Result.RowColor := NoColor;
  Result.TextColor := NoColor;
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

  procedure ResolveArray(Parent: TJSONObject; const Name: string);
  var
    Arr: TJSONArray;
    I, Id: Integer;
    E: TJSONObject;
  begin
    Arr := JArr(Parent, Name);
    if Arr = nil then
      Exit;
    for I := Arr.Count - 1 downto 0 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      E := TJSONObject(Arr.Items[I]);
      if E.GetValue('pidCode') = nil then
        Continue;
      Id := Resolver(JStr(E, 'pidCode'), JStr(E, 'units'), JStr(E, 'pidName'));
      if Id < 0 then
      begin
        Arr.Remove(I).Free;
        Continue;
      end;
      E.RemovePair('pidCode').Free;
      E.RemovePair('units').Free;
      E.RemovePair('pidName').Free;
      E.AddPair('pid', TJSONNumber.Create(Id));
    end;
  end;

var
  Arr: TJSONArray;
  I: Integer;
begin
  ResolveArray(Root, 'pids');
  ResolveArray(Root, 'gauges');
  Arr := JArr(Root, 'dashboards');
  if Arr <> nil then
    for I := 0 to Arr.Count - 1 do
      if Arr.Items[I] is TJSONObject then
        ResolveArray(TJSONObject(Arr.Items[I]), 'gauges');
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

procedure TResolvedStyle.Colors(FlashOn: Boolean; out Row, Text: TAlphaColor);
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
  TextColor := NoColor;
  RowColor := NoColor;
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
  Result := (FontSize = 0) and (TextColor = NoColor) and (RowColor = NoColor) and (Length(Levels) = 0);
end;

{ TDashboard }

constructor TDashboard.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
  Gauges := TList<TGauge>.Create;
end;

destructor TDashboard.Destroy;
begin
  Gauges.Free;
  inherited;
end;

{ TDisplaySettings }

constructor TDisplaySettings.Create;
begin
  inherited;
  FPids := TObjectDictionary<Integer, TPidDisplay>.Create([doOwnsValues]);
  FDashboards := TObjectList<TDashboard>.Create(True);
  FDashboards.Add(TDashboard.Create(MainDashboard));
  FWarnings := TStringList.Create;
end;

destructor TDisplaySettings.Destroy;
begin
  FPids.Free;
  FDashboards.Free;
  FWarnings.Free;
  inherited;
end;

procedure TDisplaySettings.Clear;
begin
  FPids.Clear;
  FDashboards.Clear;
  FDashboards.Add(TDashboard.Create(MainDashboard));
  FCurrent := 0;
  BuiltIns := nil;
  FWarnings.Clear;
end;

function TDisplaySettings.GetGauges: TList<TGauge>;
begin
  Result := FDashboards[FCurrent].Gauges;
end;

function TDisplaySettings.GetDashboard(Index: Integer): TDashboard;
begin
  Result := FDashboards[Index];
end;

function TDisplaySettings.GetDashboardCount: Integer;
begin
  Result := FDashboards.Count;
end;

procedure TDisplaySettings.SetCurrent(Value: Integer);
begin
  FCurrent := EnsureRange(Value, 0, FDashboards.Count - 1);
end;

function TDisplaySettings.IndexOfDashboard(const Name: string): Integer;
begin
  for Result := 0 to FDashboards.Count - 1 do
    if SameText(FDashboards[Result].Name, Trim(Name)) then
      Exit;
  Result := -1;
end;

function TDisplaySettings.AddDashboard(const Name: string): Integer;
begin
  Result := IndexOfDashboard(Name);
  if Result < 0 then
    Result := FDashboards.Add(TDashboard.Create(Trim(Name)));
end;

procedure TDisplaySettings.DeleteDashboard(Index: Integer);
begin
  if (Index < 0) or (Index >= FDashboards.Count) then
    Exit;
  if FDashboards.Count = 1 then
    FDashboards[0].Gauges.Clear
  else
  begin
    FDashboards.Delete(Index);
    if FCurrent >= Index then
      FCurrent := Max(0, FCurrent - 1);
  end;
end;

function TDisplaySettings.DashboardNames: TArray<string>;
var
  D: TDashboard;
begin
  Result := nil;
  for D in FDashboards do
    Result := Result + [D.Name];
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
  Result.RowColor := NoColor;
  Result.TextColor := NoColor;
  Result.NormalRowColor := NoColor;
  Result.NormalTextColor := NoColor;
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
  if L.RowColor <> NoColor then
    Result.RowColor := L.RowColor;
  if L.TextColor <> NoColor then
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
    if L.RowColor = NoColor then
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
      L.RowColor := HexToColor(JStr(LE, 'rowColor'), NoColor);
      L.TextColor := HexToColor(JStr(LE, 'textColor'), NoColor);
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
    if L.RowColor <> NoColor then
      LE.AddPair('rowColor', ColorToHex(L.RowColor));
    if L.TextColor <> NoColor then
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

procedure LoadGauges(Arr: TJSONArray; List: TList<TGauge>);
var
  I: Integer;
  E: TJSONObject;
  G: TGauge;
begin
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
      List.Add(G);
    end;
end;

procedure TDisplaySettings.LoadFromJson(Root: TJSONObject);
var
  Arr: TJSONArray;
  I: Integer;
  E: TJSONObject;
  D: TPidDisplay;
  Name: string;
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
        D.TextColor := HexToColor(JStr(E, 'textColor'), NoColor);
        D.RowColor := HexToColor(JStr(E, 'rowColor'), NoColor);
        D.Levels := LevelsFromJson(JArr(E, 'levels'));
        FPids.AddOrSetValue(D.PidId, D);
        D := nil;
      finally
        D.Free;
      end;
    end;

  BuiltIns := JStrings(Root, 'builtIns');
  Arr := JArr(Root, 'dashboards');
  if Arr = nil then
    LoadGauges(JArr(Root, 'gauges'), FDashboards[0].Gauges) // a file from before
  else
  begin
    FDashboards.Clear;
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      E := TJSONObject(Arr.Items[I]);
      Name := Trim(JStr(E, 'name'));
      if (Name = '') or (IndexOfDashboard(Name) >= 0) then
      begin
        FWarnings.Add(Format('dashboards[%d]: missing or repeated "name"', [I]));
        Continue;
      end;
      LoadGauges(JArr(E, 'gauges'), FDashboards[AddDashboard(Name)].Gauges);
    end;
    if FDashboards.Count = 0 then
      FDashboards.Add(TDashboard.Create(MainDashboard));
  end;
  FCurrent := Max(0, IndexOfDashboard(JStr(Root, 'dashboard')));
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
  Arr, Dashes: TJSONArray;
  E, DE: TJSONObject;
  Dash: TDashboard;
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
    if D.TextColor <> NoColor then
      E.AddPair('textColor', ColorToHex(D.TextColor));
    if D.RowColor <> NoColor then
      E.AddPair('rowColor', ColorToHex(D.RowColor));
    if Length(D.Levels) > 0 then
      E.AddPair('levels', LevelsToJson(D.Levels));
    Arr.AddElement(E);
  end;

  Result.AddPair('dashboard', FDashboards[FCurrent].Name);
  Dashes := TJSONArray.Create;
  Result.AddPair('dashboards', Dashes);
  for Dash in FDashboards do
  begin
    DE := TJSONObject.Create;
    DE.AddPair('name', Dash.Name);
    Arr := TJSONArray.Create;
    DE.AddPair('gauges', Arr);
    for G in Dash.Gauges do
    begin
      E := TJSONObject.Create;
      E.AddPair('pid', TJSONNumber.Create(G.PidId));
      E.AddPair('style', GaugeStyleKeys[G.Style]);
      E.AddPair('size', GaugeSizeKeys[G.Size]);
      E.AddPair('min', TJSONNumber.Create(G.MinValue));
      E.AddPair('max', TJSONNumber.Create(G.MaxValue));
      Arr.AddElement(E);
    end;
    Dashes.AddElement(DE);
  end;
  if Length(BuiltIns) > 0 then
    Result.AddPair('builtIns', StringsToJson(BuiltIns));
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
