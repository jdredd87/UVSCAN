unit UVScan.Pids;

{ PID definitions loaded from pids.csv (same layout as legacy UVSCAN):

  Counter,Long Name,Desc,Formula,Units,Datalength,PID,group,shortname,Results,PidCat,txtMCI

  PID column: a hex PID number, or FPID (calculated), or FFFF/FFFE/FFFD
  (AVT analog inputs 1/2/3). Only rows with group = 1 are loaded.
  Results column: %f (2 decimals), %d (integer), %o (OFF/ON), %y (NO/YES),
  *c (convert F to C), *f (convert C to F). }

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, UVScan.Formula;

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
  end;

  TPidCatalog = class
  private
    FItems: TObjectList<TPidDef>;
    FWarnings: TStringList;
    function GetCount: Integer;
    function GetItem(Index: Integer): TPidDef;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromStrings(Lines: TStrings);
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

function ParseCsvLine(const Line: string): TArray<string>;

implementation

uses
  System.Math, System.StrUtils;

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
begin
  Lines := TStringList.Create;
  try
    // A BOM selects UTF-8/UTF-16; otherwise the legacy ANSI file is read as ANSI.
    Lines.LoadFromFile(FileName);
    LoadFromStrings(Lines);
  finally
    Lines.Free;
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

procedure TPidCatalog.LoadFromStrings(Lines: TStrings);
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
        P.Kind := pkCalculated
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
        if not (P.DataLength in [1..4]) then
        begin
          FWarnings.Add(Format('Line %d (%s): unsupported data length %d', [I + 1, P.LongName, P.DataLength]));
          FreeAndNil(P);
          Continue;
        end;
      end;

      try
        P.Formula;
      except
        on E: EFormulaError do
          FWarnings.Add(Format('Line %d (%s): %s', [I + 1, P.LongName, E.Message]));
      end;
      FItems.Add(P);
    except
      P.Free;
      raise;
    end;
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
