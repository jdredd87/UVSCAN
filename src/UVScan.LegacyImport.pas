unit UVScan.LegacyImport;

{ Import of the 2008 UVSCAN PIDS.csv into a PID catalog, and merging one
  catalog into another. The CSV is only ever read here, by explicit user
  action; UVScan itself stores everything as JSON.

  Legacy layout:
    Counter,Long Name,Desc,Formula,Units,Datalength,PID,group,shortname,Results,PidCat,txtMCI
  PID: hex number, FPID (calculated) or FFFF/FFFE/FFFD (analog input 1/2/3).
  PidCat: 1 engine, 2 transmission, 3 indicators, 4 body, 5 accessories,
          6 calculated, 7 analog, anything else other.
  group: the old app only loaded group 1; other rows import as disabled. }

interface

uses
  System.SysUtils, System.Classes, UVScan.Pids;

type
  TMergeMode = (mmReplace, mmAddNew, mmAddAndUpdate);

  TMergeResult = record
    Added, Updated, Skipped: Integer;
  end;

{ Reads a legacy PIDS.csv into Catalog (replacing its contents). Problems with
  individual rows are listed in Catalog.Warnings. }
procedure ImportLegacyPidsCsv(const FileName: string; Catalog: TPidCatalog);
procedure ImportLegacyPidsCsvLines(Lines: TStrings; Catalog: TPidCatalog);

{ Merges Source into Target, matching PIDs by id. Source is not changed. }
function MergeCatalog(Target, Source: TPidCatalog; Mode: TMergeMode): TMergeResult;

function ParseCsvLine(const Line: string): TArray<string>;

implementation

uses
  System.JSON, System.Generics.Collections;

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
      if Length(F) < 12 then
      begin
        Skipped.Add(Format('Line %d: expected 12 columns, found %d', [I + 1, Length(F)]));
        Continue;
      end;
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

function MergeCatalog(Target, Source: TPidCatalog; Mode: TMergeMode): TMergeResult;
var
  I: Integer;
  S, T, P: TPidDef;
begin
  Result := Default(TMergeResult);
  if Mode = mmReplace then
  begin
    Target.Assign(Source);
    Result.Added := Source.Count;
    Exit;
  end;
  for I := 0 to Source.Count - 1 do
  begin
    S := Source[I];
    T := Target.FindById(S.Id);
    if T = nil then
    begin
      P := TPidDef.Create;
      P.Assign(S);
      Target.Add(P);
      Inc(Result.Added);
    end
    else if Mode = mmAddAndUpdate then
    begin
      T.Assign(S);
      Inc(Result.Updated);
    end
    else
      Inc(Result.Skipped);
  end;
end;

end.
