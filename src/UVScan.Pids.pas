unit UVScan.Pids;

(* PID definitions.

  pids.json (current format):
    { "version": 1,
      "pids": [
        { "id": 1, "name": "ENGINE SPEED", "shortName": "RPM",
          "kind": "vehicle", "category": "engine",
          "pid": "000C", "bytes": 2,
          "formula": "((N1 << 8) + N2) * 0.25", "units": "RPM",
          "format": "", "mci": "RPM" },
        { "id": 39, "name": "Inj Duty Cycle", "kind": "calculated", ... },
        { "id": 18, "name": "AD1", "kind": "analog", "analogChannel": 1, ... } ] }
    Optional: "description", "enabled": false (entry is skipped).
    kind: vehicle | calculated | analog
    category: other | engine | transmission | indicators | body | accessories | calculated | analog
    format: %f (2 decimals), %d (integer), %o (OFF/ON), %y (NO/YES),
            *c (convert F to C), *f (convert C to F); may be combined, e.g. "*f%d". *)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.JSON, UVScan.Formula;

type
  TPidKind = (pkVehicle, pkCalculated, pkAnalog);

  TPidCategory = (pcOther, pcEngine, pcTransmission, pcIndicators, pcBody,
    pcAccessories, pcCalculated, pcAnalog);

  TPidDef = class
  private
    FFormula: TFormula;
    FFormulaText: string;
    procedure SetFormulaText(const Value: string);
  public
    Id: Integer;
    Enabled: Boolean;      // disabled entries stay in pids.json but are not offered for scanning
    LongName: string;
    Description: string;
    Units: string;
    DataLength: Integer;
    PidCode: string;
    ShortName: string;
    ResultFormat: string;
    Category: TPidCategory;
    Mci: string;           // upper case, without % signs
    Kind: TPidKind;
    PidNumber: Word;       // pkVehicle
    AnalogChannel: Integer; // pkAnalog: 1..3
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPidDef);
    { Compiled formula; raises EFormulaError once if FormulaText is invalid. }
    function Formula: TFormula;
    { Formula problem or ''. }
    function FormulaError: string;
    property FormulaText: string read FFormulaText write SetFormulaText;
    function FormatValue(const Value: Double): string;
    function DisplayName: string;
    function ToJson: TJSONObject;
  end;

  TPidCatalog = class
  private
    FItems: TObjectList<TPidDef>;
    FWarnings: TStringList;
    function GetCount: Integer;
    function GetItem(Index: Integer): TPidDef;
    function Accept(P: TPidDef; const Where: string): Boolean;
    function ParseJsonPid(E: TJSONObject; const Where: string): TPidDef;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromJson(Root: TJSONObject);
    procedure LoadFromJsonText(const Text: string);
    function ToJson: TJSONObject;
    procedure SaveToJsonFile(const FileName: string);
    procedure Assign(Source: TPidCatalog);
    { Editing: no validation here; Validate/LoadFromJson report problems. }
    procedure Add(P: TPidDef);
    procedure Delete(Index: Integer);
    function IndexOf(P: TPidDef): Integer;
    function NextFreeId: Integer;
    { Problems that would be reported when this catalog is saved and reloaded. }
    function Validate: TArray<string>;
    function FindById(Id: Integer): TPidDef;
    function FindByMci(const Mci: string): TPidDef;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TPidDef read GetItem; default;
    property Warnings: TStringList read FWarnings;
  end;

const
  CategoryNames: array[TPidCategory] of string = ('Other', 'Engine', 'Transmission',
    'Indicators', 'Body', 'Accessories', 'Calculated', 'Analog inputs');

  BuiltinRuntime = 'RUNTIME';
  BuiltinLogTime = 'LOGTIME';

  PidFileVersion = 1;
  KindKeys: array[TPidKind] of string = ('vehicle', 'calculated', 'analog');
  CategoryKeys: array[TPidCategory] of string = ('other', 'engine', 'transmission',
    'indicators', 'body', 'accessories', 'calculated', 'analog');

implementation

uses
  System.Math, System.StrUtils, UVScan.JsonFile;

{ TPidDef }

constructor TPidDef.Create;
begin
  inherited;
  Enabled := True;
end;

destructor TPidDef.Destroy;
begin
  FFormula.Free;
  inherited;
end;

procedure TPidDef.SetFormulaText(const Value: string);
begin
  if Value = FFormulaText then
    Exit;
  FFormulaText := Value;
  FreeAndNil(FFormula); // recompiled on next use
end;

procedure TPidDef.Assign(Source: TPidDef);
begin
  Id := Source.Id;
  Enabled := Source.Enabled;
  LongName := Source.LongName;
  Description := Source.Description;
  FormulaText := Source.FormulaText;
  Units := Source.Units;
  DataLength := Source.DataLength;
  PidCode := Source.PidCode;
  ShortName := Source.ShortName;
  ResultFormat := Source.ResultFormat;
  Category := Source.Category;
  Mci := Source.Mci;
  Kind := Source.Kind;
  PidNumber := Source.PidNumber;
  AnalogChannel := Source.AnalogChannel;
end;

function TPidDef.FormulaError: string;
var
  F: TFormula;
begin
  Result := '';
  try
    F := TFormula.Create(FormulaText);
    F.Free;
  except
    on E: EFormulaError do
      Result := E.Message;
  end;
end;

function TPidDef.Formula: TFormula;
begin
  if FFormula = nil then
    try
      FFormula := TFormula.Create(FormulaText);
    except
      FFormula := TFormula.Create(''); // evaluates to NaN ("--") from now on
      raise;
    end;
  Result := FFormula;
end;

function TPidDef.ToJson: TJSONObject;

  procedure Opt(const Name, Value: string);
  begin
    if Value <> '' then
      Result.AddPair(Name, Value);
  end;

begin
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(Id));
  if not Enabled then
    Result.AddPair('enabled', TJSONBool.Create(False));
  Result.AddPair('name', LongName);
  Opt('shortName', ShortName);
  Opt('description', Description);
  Result.AddPair('kind', KindKeys[Kind]);
  Result.AddPair('category', CategoryKeys[Category]);
  case Kind of
    pkVehicle:
      begin
        Result.AddPair('pid', PidCode);
        Result.AddPair('bytes', TJSONNumber.Create(DataLength));
      end;
    pkAnalog:
      Result.AddPair('analogChannel', TJSONNumber.Create(AnalogChannel));
  end;
  Opt('formula', FormulaText);
  Opt('units', Units);
  Opt('format', ResultFormat);
  Opt('mci', Mci);
end;

function TPidDef.DisplayName: string;
begin
  if ShortName <> '' then
    Result := ShortName
  else
    Result := LongName;
end;

function TPidDef.FormatValue(const Value: Double): string;
var
  V: Double;
  Fmt, Token: string;
  I: Integer;
  AsWord: string;
begin
  if IsNan(Value) or IsInfinite(Value) then
    Exit('--');
  V := Value;
  Fmt := LowerCase(ResultFormat);
  AsWord := '';
  Result := FormatFloat('0.###', V, TFormatSettings.Invariant);
  I := 1;
  while I < Length(Fmt) do
  begin
    Token := Copy(Fmt, I, 2);
    if Token = '*c' then
      V := (V - 32) * 5 / 9
    else if Token = '*f' then
      V := V * 9 / 5 + 32
    else if Token = '%f' then
      Result := FormatFloat('0.00', V, TFormatSettings.Invariant)
    else if Token = '%d' then
      Result := IntToStr(Round(V))
    else if Token = '%o' then
      AsWord := IfThen(Round(V) = 0, 'OFF', IfThen(Round(V) = 1, 'ON', IntToStr(Round(V))))
    else if Token = '%y' then
      AsWord := IfThen(Round(V) = 0, 'NO', IfThen(Round(V) = 1, 'YES', IntToStr(Round(V))))
    else
    begin
      Inc(I);
      Continue;
    end;
    if (Token = '*c') or (Token = '*f') then
      Result := FormatFloat('0.###', V, TFormatSettings.Invariant);
    Inc(I, 2);
  end;
  if AsWord <> '' then
    Result := AsWord;
end;

{ TPidCatalog }

constructor TPidCatalog.Create;
begin
  inherited;
  FItems := TObjectList<TPidDef>.Create(True);
  FWarnings := TStringList.Create;
end;

destructor TPidCatalog.Destroy;
begin
  FItems.Free;
  FWarnings.Free;
  inherited;
end;

function TPidCatalog.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TPidCatalog.GetItem(Index: Integer): TPidDef;
begin
  Result := FItems[Index];
end;

procedure TPidCatalog.LoadFromFile(const FileName: string);
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

{ Final checks for one entry. Takes ownership of P; returns False (and frees
  P) when the entry is rejected. }
function TPidCatalog.Accept(P: TPidDef; const Where: string): Boolean;
begin
  Result := False;
  try
    if P.LongName = '' then
    begin
      FWarnings.Add(Where + ': missing name');
      Exit;
    end;
    if FindById(P.Id) <> nil then
    begin
      FWarnings.Add(Format('%s (%s): duplicate id %d', [Where, P.LongName, P.Id]));
      Exit;
    end;
    if (P.Kind = pkVehicle) and not (P.DataLength in [1..4]) then
    begin
      FWarnings.Add(Format('%s (%s): unsupported data length %d', [Where, P.LongName, P.DataLength]));
      Exit;
    end;
    if (P.Kind = pkAnalog) and not (P.AnalogChannel in [1..3]) then
    begin
      FWarnings.Add(Format('%s (%s): analog channel must be 1-3', [Where, P.LongName]));
      Exit;
    end;
    if (P.Mci <> '') and (FindByMci(P.Mci) <> nil) then
      FWarnings.Add(Format('%s (%s): MCI "%s" is already used by "%s"',
        [Where, P.LongName, P.Mci, FindByMci(P.Mci).LongName]));
    try
      P.Formula;
    except
      on E: EFormulaError do
        FWarnings.Add(Format('%s (%s): %s', [Where, P.LongName, E.Message]));
    end;
    FItems.Add(P);
    Result := True;
  finally
    if not Result then
      P.Free;
  end;
end;

{ JSON }

function KeyIndex(const Keys: array of string; const S: string): Integer;
begin
  for Result := 0 to High(Keys) do
    if SameText(Keys[Result], S) then
      Exit;
  Result := -1;
end;

function TPidCatalog.ParseJsonPid(E: TJSONObject; const Where: string): TPidDef;
var
  K, PidNum: Integer;
  Code: string;
begin
  Result := TPidDef.Create;
  try
    Result.Id := JInt(E, 'id', -1);
    Result.Enabled := JBool(E, 'enabled', True);
    Result.LongName := Trim(JStr(E, 'name'));
    if Result.Id < 0 then
      raise EConvertError.Create('missing or invalid "id"');
    Result.ShortName := Trim(JStr(E, 'shortName'));
    Result.Description := Trim(JStr(E, 'description'));
    Result.FormulaText := Trim(JStr(E, 'formula'));
    Result.Units := JStr(E, 'units');
    Result.ResultFormat := Trim(JStr(E, 'format'));
    Result.Mci := UpperCase(StringReplace(Trim(JStr(E, 'mci')), '%', '', [rfReplaceAll]));

    K := KeyIndex(CategoryKeys, JStr(E, 'category', 'other'));
    if K < 0 then
    begin
      FWarnings.Add(Format('%s (%s): unknown category "%s", using "other"', [Where, Result.LongName, JStr(E, 'category')]));
      K := Ord(pcOther);
    end;
    Result.Category := TPidCategory(K);

    K := KeyIndex(KindKeys, JStr(E, 'kind'));
    if K < 0 then
      raise EConvertError.CreateFmt('unknown kind "%s" (vehicle, calculated or analog)', [JStr(E, 'kind')]);
    Result.Kind := TPidKind(K);
    case Result.Kind of
      pkVehicle:
        begin
          Code := UpperCase(Trim(JStr(E, 'pid')));
          if not TryStrToInt('$' + Code, PidNum) or (PidNum < 0) or (PidNum > $FFFF) then
            raise EConvertError.CreateFmt('invalid "pid" "%s" (hex, e.g. "000C")', [Code]);
          Result.PidNumber := PidNum;
          Result.PidCode := IntToHex(PidNum, 4);
          Result.DataLength := JInt(E, 'bytes', 0);
        end;
      pkCalculated:
        Result.PidCode := 'FPID';
      pkAnalog:
        begin
          Result.AnalogChannel := JInt(E, 'analogChannel', 0);
          Result.PidCode := IntToHex($FFFF - Result.AnalogChannel + 1, 4);
        end;
    end;
  except
    on Ex: EConvertError do
    begin
      FWarnings.Add(Format('%s (%s): %s', [Where, Result.LongName, Ex.Message]));
      FreeAndNil(Result);
    end;
  end;
end;

procedure TPidCatalog.LoadFromJson(Root: TJSONObject);
var
  Arr: TJSONArray;
  I: Integer;
  P: TPidDef;
  Where: string;
begin
  FItems.Clear;
  FWarnings.Clear;
  if JInt(Root, 'version', PidFileVersion) > PidFileVersion then
    FWarnings.Add('pids.json was written by a newer UVScan; unknown fields are ignored');
  Arr := JArr(Root, 'pids');
  if Arr = nil then
  begin
    FWarnings.Add('pids.json has no "pids" array');
    Exit;
  end;
  for I := 0 to Arr.Count - 1 do
  begin
    Where := Format('pids[%d]', [I]);
    if not (Arr.Items[I] is TJSONObject) then
    begin
      FWarnings.Add(Where + ': not an object');
      Continue;
    end;
    P := ParseJsonPid(TJSONObject(Arr.Items[I]), Where);
    if P <> nil then
      Accept(P, Where);
  end;
end;

procedure TPidCatalog.LoadFromJsonText(const Text: string);
var
  Root: TJSONObject;
begin
  Root := ParseJsonObject(Text, 'pids.json');
  try
    LoadFromJson(Root);
  finally
    Root.Free;
  end;
end;

function TPidCatalog.ToJson: TJSONObject;
var
  Arr: TJSONArray;
  P: TPidDef;
begin
  Result := TJSONObject.Create;
  Result.AddPair('version', TJSONNumber.Create(PidFileVersion));
  Arr := TJSONArray.Create;
  Result.AddPair('pids', Arr);
  for P in FItems do
    Arr.AddElement(P.ToJson);
end;

procedure TPidCatalog.SaveToJsonFile(const FileName: string);
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

procedure TPidCatalog.Assign(Source: TPidCatalog);
var
  P: TPidDef;
  Copy_: TPidDef;
begin
  FItems.Clear;
  FWarnings.Clear;
  for P in Source.FItems do
  begin
    Copy_ := TPidDef.Create;
    Copy_.Assign(P);
    FItems.Add(Copy_);
  end;
end;

procedure TPidCatalog.Add(P: TPidDef);
begin
  FItems.Add(P);
end;

procedure TPidCatalog.Delete(Index: Integer);
begin
  FItems.Delete(Index);
end;

function TPidCatalog.IndexOf(P: TPidDef): Integer;
begin
  Result := FItems.IndexOf(P);
end;

function TPidCatalog.NextFreeId: Integer;
var
  P: TPidDef;
begin
  Result := 1;
  for P in FItems do
    if P.Id >= Result then
      Result := P.Id + 1;
end;

function TPidCatalog.Validate: TArray<string>;
var
  Root: TJSONObject;
  Check: TPidCatalog;
begin
  Root := ToJson;
  Check := TPidCatalog.Create;
  try
    Check.LoadFromJson(Root);
    Result := Check.Warnings.ToStringArray;
  finally
    Check.Free;
    Root.Free;
  end;
end;

function TPidCatalog.FindById(Id: Integer): TPidDef;
var
  P: TPidDef;
begin
  for P in FItems do
    if P.Id = Id then
      Exit(P);
  Result := nil;
end;

function TPidCatalog.FindByMci(const Mci: string): TPidDef;
var
  P: TPidDef;
begin
  for P in FItems do
    if (P.Mci <> '') and SameText(P.Mci, Mci) then
      Exit(P);
  Result := nil;
end;

end.
