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
            *c (convert F to C), *f (convert C to F); may be combined, e.g. "*f%d".

  Legacy UVSCAN pids.csv is still read (imported), same validation:
    Counter,Long Name,Desc,Formula,Units,Datalength,PID,group,shortname,Results,PidCat,txtMCI
    PID: hex number, FPID (calculated) or FFFF/FFFE/FFFD (analog 1/2/3);
    only rows with group = 1 are loaded. *)

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
  public
    Id: Integer;
    LongName: string;
    Description: string;
    FormulaText: string;
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
    destructor Destroy; override;
    function Formula: TFormula;
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
    { .json -> LoadFromJson, anything else -> legacy CSV import. }
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromCsvLines(Lines: TStrings);
    procedure LoadFromJson(Root: TJSONObject);
    procedure LoadFromJsonText(const Text: string);
    function ToJson: TJSONObject;
    procedure SaveToJsonFile(const FileName: string);
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

function ParseCsvLine(const Line: string): TArray<string>;

implementation

uses
  System.Math, System.StrUtils, UVScan.JsonFile;

function ParseCsvLine(const Line: string): TArray<string>;
var
  Fields: TList<string>;
  Field: TStringBuilder;
  I: Integer;
  InQuotes: Boolean;
  C: Char;
begin
  Fields := TList<string>.Create;
  Field := TStringBuilder.Create;
  try
    InQuotes := False;
    I := 1;
    while I <= Length(Line) do
    begin
      C := Line[I];
      if InQuotes then
      begin
        if C = '"' then
        begin
          if (I < Length(Line)) and (Line[I + 1] = '"') then
          begin
            Field.Append('"');
            Inc(I);
          end
          else
            InQuotes := False;
        end
        else
          Field.Append(C);
      end
      else if C = '"' then
        InQuotes := True
      else if C = ',' then
      begin
        Fields.Add(Field.ToString);
        Field.Clear;
      end
      else
        Field.Append(C);
      Inc(I);
    end;
    Fields.Add(Field.ToString);
    Result := Fields.ToArray;
  finally
    Field.Free;
    Fields.Free;
  end;
end;

{ TPidDef }

destructor TPidDef.Destroy;
begin
  FFormula.Free;
  inherited;
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
  Result.AddPair('name', LongName);
  Opt('shortName', ShortName);
  Opt('description', Description);
  Result.AddPair('kind', KindKeys[Kind]);
  Result.AddPair('category', CategoryKeys[Category]);
  case Kind of
    pkVehicle:
      begin
        Result.AddPair('pid', IntToHex(PidNumber, 4));
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
  Lines: TStringList;
  Root: TJSONObject;
begin
  if SameText(ExtractFileExt(FileName), '.json') then
  begin
    Root := ReadJsonObject(FileName);
    try
      LoadFromJson(Root);
    finally
      Root.Free;
    end;
    Exit;
  end;
  Lines := TStringList.Create;
  try
    // A BOM selects UTF-8/UTF-16; otherwise the legacy ANSI file is read as ANSI.
    Lines.LoadFromFile(FileName);
    LoadFromCsvLines(Lines);
  finally
    Lines.Free;
  end;
end;

{ Common checks for both formats. Takes ownership of P; returns False (and
  frees P) when the entry is rejected. }
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

function ToCategory(const S: string): TPidCategory;
begin
  case StrToIntDef(Trim(S), 0) of
    1: Result := pcEngine;
    2: Result := pcTransmission;
    3: Result := pcIndicators;
    4: Result := pcBody;
    5: Result := pcAccessories;
    6: Result := pcCalculated;
    7: Result := pcAnalog;
  else
    Result := pcOther;
  end;
end;

procedure TPidCatalog.LoadFromCsvLines(Lines: TStrings);
var
  I, PidNum: Integer;
  F: TArray<string>;
  P: TPidDef;
  Code: string;
begin
  FItems.Clear;
  FWarnings.Clear;
  for I := 1 to Lines.Count - 1 do // line 0 is the header
  begin
    if Trim(Lines[I]) = '' then
      Continue;
    F := ParseCsvLine(Lines[I]);
    if Length(F) < 12 then
    begin
      FWarnings.Add(Format('Line %d: expected 12 columns, found %d', [I + 1, Length(F)]));
      Continue;
    end;
    if Trim(F[7]) <> '1' then
      Continue;

    P := TPidDef.Create;
    try
      P.Id := StrToIntDef(Trim(F[0]), I);
      P.LongName := Trim(F[1]);
      P.Description := Trim(F[2]);
      P.FormulaText := Trim(F[3]);
      P.Units := Trim(F[4]);
      P.DataLength := StrToIntDef(Trim(F[5]), 0);
      P.PidCode := UpperCase(Trim(F[6]));
      P.ShortName := Trim(F[8]);
      P.ResultFormat := Trim(F[9]);
      P.Category := ToCategory(F[10]);
      P.Mci := UpperCase(StringReplace(Trim(F[11]), '%', '', [rfReplaceAll]));

      Code := P.PidCode;
      if (Code = 'FFFF') or (Code = 'FFFE') or (Code = 'FFFD') then
      begin
        P.Kind := pkAnalog;
        P.AnalogChannel := $FFFF - StrToInt('$' + Code) + 1;
      end
      else if (Code = 'FPID') or (P.DataLength = 0) then
      begin
        P.Kind := pkCalculated;
        P.PidCode := 'FPID';
      end
      else
      begin
        P.Kind := pkVehicle;
        if not TryStrToInt('$' + Code, PidNum) or (PidNum < 0) or (PidNum > $FFFF) then
        begin
          FWarnings.Add(Format('Line %d (%s): invalid PID "%s"', [I + 1, P.LongName, Code]));
          FreeAndNil(P);
          Continue;
        end;
        P.PidNumber := PidNum;
        P.PidCode := IntToHex(PidNum, 4);
      end;
    except
      P.Free;
      raise;
    end;
    Accept(P, Format('Line %d', [I + 1]));
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
    if not JBool(TJSONObject(Arr.Items[I]), 'enabled', True) then
      Continue;
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
