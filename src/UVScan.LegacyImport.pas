unit UVScan.LegacyImport;

{ Import of the 2008 UVSCAN PIDS.csv into a PID catalog, and merging one
  catalog into another. The CSV is only ever read here, by explicit user
  action; UVScan itself stores everything as JSON.

  Legacy layout:
    Counter,Long Name,Desc,Formula,Units,Datalength,PID,group,shortname,Results,PidCat,txtMCI
  PID: hex number, FPID (calculated) or FFFF/FFFE/FFFD (analog input 1/2/3).
  PidCat: 1 engine, 2 transmission, 3 indicators, 4 body, 5 accessories,
          6 calculated, 7 analog, anything else other.
  group: the old app only loaded group 1; other rows import as disabled.
  Spreadsheet programs drop empty trailing cells, so rows may be short:
  missing trailing columns count as empty (at least 9 are needed).

  Merging: an imported PID matches one you already have when it reads the
  same thing (PID code for vehicle PIDs, channel for analog inputs) and
  either has the same name or the same formula (spaces ignored). Ids are not
  used for matching because other files were numbered independently, and
  names alone are not enough (old files have two different "1-2 Solenoid"
  PIDs, and call ENGINE SPEED "Engine Speed (RPM)"). Only PIDs that were in
  the list before the merge can match.
  An added PID whose MCI is already in use loses its MCI, so formulas keep
  using the PID you already had. Imported PIDs keep their id when it is free and get the next
  free one otherwise; updated PIDs keep their existing id, so scan lists
  that refer to them stay valid. }

interface

uses
  System.SysUtils, System.Classes, UVScan.Pids;

type
  TMergeMode = (mmReplace, mmAddNew, mmAddAndUpdate);

  TMergeResult = record
    Added, Updated, Skipped: Integer;
    Renumbered: Integer;   // added PIDs whose id was taken and got a new one
    MciCleared: TArray<string>; // added PIDs whose MCI was already in use: 'Name (MCI)'
  end;

{ Reads a legacy PIDS.csv into Catalog (replacing its contents). Problems with
  individual rows are listed in Catalog.Warnings. }
procedure ImportLegacyPidsCsv(const FileName: string; Catalog: TPidCatalog);
procedure ImportLegacyPidsCsvLines(Lines: TStrings; Catalog: TPidCatalog);

{ Merges Source into Target (see the matching rules above). Source is not changed. }
function MergeCatalog(Target, Source: TPidCatalog; Mode: TMergeMode): TMergeResult;

function ParseCsvLine(const Line: string): TArray<string>;
{ The PID in Catalog that P would merge with, or nil. }
function FindMatchingPid(Catalog: TPidCatalog; P: TPidDef): TPidDef;

implementation

uses
  System.JSON, System.Character, System.Generics.Collections;

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

const
  MinColumns = 9; // Counter .. shortname

function CategoryKey(const S: string): string;
begin
  case StrToIntDef(Trim(S), 0) of
    1: Result := 'engine';
    2: Result := 'transmission';
    3: Result := 'indicators';
    4: Result := 'body';
    5: Result := 'accessories';
    6: Result := 'calculated';
    7: Result := 'analog';
  else
    Result := 'other';
  end;
end;

procedure ImportLegacyPidsCsv(const FileName: string; Catalog: TPidCatalog);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    // Old files are ANSI; a BOM (UTF-8/UTF-16) is honoured if present.
    Lines.LoadFromFile(FileName);
    ImportLegacyPidsCsvLines(Lines, Catalog);
  finally
    Lines.Free;
  end;
end;

{ Builds the equivalent pids.json document so the normal loader applies
  exactly the same validation as for JSON files. }
procedure ImportLegacyPidsCsvLines(Lines: TStrings; Catalog: TPidCatalog);
var
  Root, E: TJSONObject;
  Arr: TJSONArray;
  I, Id, Bytes: Integer;
  F: TArray<string>;
  Code, Units, Mci: string;
  Skipped: TStringList;

  procedure Opt(const Name, Value: string);
  begin
    if Value <> '' then
      E.AddPair(Name, Value);
  end;

begin
  Skipped := TStringList.Create;
  Root := TJSONObject.Create;
  try
    Root.AddPair('version', TJSONNumber.Create(PidFileVersion));
    Arr := TJSONArray.Create;
    Root.AddPair('pids', Arr);
    for I := 1 to Lines.Count - 1 do // line 0 is the header
    begin
      if Trim(Lines[I]) = '' then
        Continue;
      F := ParseCsvLine(Lines[I]);
      if Length(F) < MinColumns then
      begin
        Skipped.Add(Format('Line %d: only %d columns, at least %d are needed - skipped',
          [I + 1, Length(F), MinColumns]));
        Continue;
      end;
      while Length(F) < 12 do
        F := F + [''];
      Id := StrToIntDef(Trim(F[0]), -1);
      if Id < 0 then
      begin
        Skipped.Add(Format('Line %d: invalid Counter "%s"', [I + 1, F[0]]));
        Continue;
      end;
      Code := UpperCase(Trim(F[6]));
      Bytes := StrToIntDef(Trim(F[5]), 0);
      // The old files used the masculine ordinal sign as a degree sign.
      Units := StringReplace(Trim(F[4]), #$00BA, #$00B0, [rfReplaceAll]);
      Mci := StringReplace(Trim(F[11]), '%', '', [rfReplaceAll]);

      E := TJSONObject.Create;
      Arr.AddElement(E);
      E.AddPair('id', TJSONNumber.Create(Id));
      if Trim(F[7]) <> '1' then
        E.AddPair('enabled', TJSONBool.Create(False));
      E.AddPair('name', Trim(F[1]));
      Opt('shortName', Trim(F[8]));
      Opt('description', Trim(F[2]));
      E.AddPair('category', CategoryKey(F[10]));
      if (Code = 'FFFF') or (Code = 'FFFE') or (Code = 'FFFD') then
      begin
        E.AddPair('kind', 'analog');
        E.AddPair('analogChannel', TJSONNumber.Create($FFFF - StrToInt('$' + Code) + 1));
      end
      else if (Code = 'FPID') or (Bytes = 0) then
        E.AddPair('kind', 'calculated')
      else
      begin
        E.AddPair('kind', 'vehicle');
        E.AddPair('pid', Code);
        E.AddPair('bytes', TJSONNumber.Create(Bytes));
      end;
      Opt('formula', Trim(F[3]));
      Opt('units', Units);
      Opt('format', Trim(F[9]));
      Opt('mci', Mci);
    end;
    Catalog.LoadFromJson(Root);
    for I := Skipped.Count - 1 downto 0 do
      Catalog.Warnings.Insert(0, Skipped[I]);
  finally
    Root.Free;
    Skipped.Free;
  end;
end;

function SourceKey(P: TPidDef): string;
begin
  Result := KindKeys[P.Kind];
  case P.Kind of
    pkVehicle: Result := Result + '|' + IntToHex(P.PidNumber, 4) + '|' + IntToStr(P.DataLength);
    pkAnalog: Result := Result + '|' + IntToStr(P.AnalogChannel);
  end;
end;

function NameKey(P: TPidDef): string;
begin
  Result := SourceKey(P) + '|n|' + LowerCase(Trim(P.LongName));
end;

{ '' when there is no formula to compare. }
function FormulaKey(P: TPidDef): string;
var
  C: Char;
  F: string;
begin
  F := '';
  for C in UpperCase(P.FormulaText) do
    if not C.IsWhiteSpace then
      F := F + C;
  if F = '' then
    Result := ''
  else
    Result := SourceKey(P) + '|f|' + F;
end;

function FindMatchingPid(Catalog: TPidCatalog; P: TPidDef): TPidDef;
var
  I: Integer;
begin
  for I := 0 to Catalog.Count - 1 do
    if (NameKey(Catalog[I]) = NameKey(P)) or
      ((FormulaKey(P) <> '') and (FormulaKey(Catalog[I]) = FormulaKey(P))) then
      Exit(Catalog[I]);
  Result := nil;
end;

function MergeCatalog(Target, Source: TPidCatalog; Mode: TMergeMode): TMergeResult;
var
  I, KeepId: Integer;
  S, T: TPidDef;
  Clashing: TArray<TPidDef>;
  Existing: TDictionary<string, TPidDef>;

  procedure AddNew(S: TPidDef; Renumber: Boolean);
  var
    P: TPidDef;
  begin
    P := TPidDef.Create;
    P.Assign(S);
    if Renumber then
    begin
      P.Id := Target.NextFreeId;
      Inc(Result.Renumbered);
    end;
    if (P.Mci <> '') and (Target.FindByMci(P.Mci) <> nil) then
    begin
      Result.MciCleared := Result.MciCleared + [Format('%s (%%%s%%)', [P.LongName, P.Mci])];
      P.Mci := '';
    end;
    Target.Add(P);
    Inc(Result.Added);
  end;

begin
  Result := Default(TMergeResult);
  if Mode = mmReplace then
  begin
    Target.Assign(Source);
    Result.Added := Source.Count;
    Exit;
  end;
  Clashing := nil;
  // Match only against what was there before, so rows of the same file never match each other.
  Existing := TDictionary<string, TPidDef>.Create;
  try
  for I := 0 to Target.Count - 1 do
  begin
    Existing.TryAdd(NameKey(Target[I]), Target[I]);
    if FormulaKey(Target[I]) <> '' then
      Existing.TryAdd(FormulaKey(Target[I]), Target[I]);
  end;
  for I := 0 to Source.Count - 1 do
  begin
    S := Source[I];
    if not Existing.TryGetValue(NameKey(S), T) then
      if (FormulaKey(S) = '') or not Existing.TryGetValue(FormulaKey(S), T) then
        T := nil;
    if T = nil then
    begin
      // New PIDs whose id is free go in first; clashing ones are numbered
      // afterwards so they cannot take an id a later import still needs.
      if Target.FindById(S.Id) <> nil then
      begin
        Clashing := Clashing + [S];
        Continue;
      end;
      AddNew(S, False);
    end
    else if Mode = mmAddAndUpdate then
    begin
      KeepId := T.Id;
      T.Assign(S);
      T.Id := KeepId;
      Inc(Result.Updated);
    end
    else
      Inc(Result.Skipped);
  end;
  finally
    Existing.Free;
  end;
  for S in Clashing do
    AddNew(S, True);
end;

end.
