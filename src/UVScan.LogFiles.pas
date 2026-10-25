unit UVScan.LogFiles;

(* The log files in the log folder: the name a new log gets, and what the
  Logs page shows of each.

  A log's name comes from a pattern (Settings > Logging > Log name):
    {date}  2026-10-25
    {time}  191716
    {n}     a number counting up: one more than the highest already in the
            folder with the rest of the name the same, so
            'Camaro_{date}_{n}' is Camaro_2026-10-25_1, _2... and starts
            at 1 again the next day
    {vin}   the car's VIN, when it was read on connecting (else nothing)
  Characters a file name cannot have become '-'. A name that is there
  already gets _2, _3... *)

interface

uses
  System.SysUtils;

const
  DefaultLogNamePattern = 'UVScan_{date}_{time}';

type
  TLogFileInfo = record
    FileName: string;
    Size: Int64;
    Modified: TDateTime;
    Seconds: Double; // how long it is: the last row's time; -1 when unknown
  end;

{ The name (no folder, no .csv) Pattern gives at When; see above. }
function ExpandLogName(const Pattern, Folder: string; When: TDateTime; const Vin: string = ''): string;
{ Name as a file name can have it: none of \ / : * ? " < > |, no spaces or
  dots at the ends, no ".csv" (it is added). }
function CleanLogName(const Name: string): string;
{ Folder\Name.csv, or Name_2.csv, Name_3.csv... when that is there already. }
function UniqueLogFile(const Folder, Name: string): string;
{ The .csv logs in Folder, newest first. }
function ListLogs(const Folder: string): TArray<TLogFileInfo>;
function LogInfo(const FileName: string): TLogFileInfo;

implementation

uses
  System.Classes, System.IOUtils, System.Math, System.StrUtils, System.RegularExpressions,
  System.Generics.Collections, System.Generics.Defaults;

function CleanLogName(const Name: string): string;
const
  Bad: array[0..8] of Char = ('\', '/', ':', '*', '?', '"', '<', '>', '|');
var
  C: Char;
begin
  Result := Trim(Name);
  if EndsText('.csv', Result) then
    SetLength(Result, Length(Result) - 4);
  for C in Bad do
    Result := StringReplace(Result, C, '-', [rfReplaceAll]);
  for var I := 1 to Length(Result) do
    if Result[I] < ' ' then
      Result[I] := '-';
  // an empty {vin} leaves its separators behind
  while Pos('__', Result) > 0 do
    Result := StringReplace(Result, '__', '_', [rfReplaceAll]);
  while (Result <> '') and CharInSet(Result[1], [' ', '.', '_', '-']) do
    Delete(Result, 1, 1);
  while (Result <> '') and CharInSet(Result[Length(Result)], [' ', '.', '_', '-']) do
    SetLength(Result, Length(Result) - 1);
  if Length(Result) > 120 then
    SetLength(Result, 120);
end;

function ExpandLogName(const Pattern, Folder: string; When: TDateTime; const Vin: string): string;
const
  NumberMark = #$E000; // a character no name has
var
  P, Expr: string;
  N, Highest: Integer;
  M: TMatch;
begin
  P := Trim(Pattern);
  if P = '' then
    P := DefaultLogNamePattern;
  P := StringReplace(P, '{date}', FormatDateTime('yyyy-mm-dd', When), [rfReplaceAll, rfIgnoreCase]);
  P := StringReplace(P, '{time}', FormatDateTime('hhnnss', When), [rfReplaceAll, rfIgnoreCase]);
  P := StringReplace(P, '{vin}', Trim(Vin), [rfReplaceAll, rfIgnoreCase]);
  if not ContainsText(P, '{n}') then
  begin
    Result := CleanLogName(P);
    if Result = '' then
      Result := CleanLogName(ExpandLogName(DefaultLogNamePattern, Folder, When));
    Exit;
  end;
  // {n}: one more than the highest number of the names like this one (the
  // name cleaned with a stand-in for the number, which the cleaning keeps)
  P := StringReplace(P, '{n}', NumberMark, [rfReplaceAll, rfIgnoreCase]);
  // (words added after it count too: Camaro_..._2 - hot lap is number 2)
  Expr := '^' + StringReplace(TRegEx.Escape(CleanLogName(P)), NumberMark, '(\d+)', [rfReplaceAll]) + '(\D|$)';
  Highest := 0;
  if (Folder <> '') and TDirectory.Exists(Folder) then
    for var F in TDirectory.GetFiles(Folder, '*.csv') do
    begin
      M := TRegEx.Match(TPath.GetFileNameWithoutExtension(F), Expr, [roIgnoreCase]);
      if M.Success and TryStrToInt(M.Groups[1].Value, N) then
        Highest := Max(Highest, N);
    end;
  Result := CleanLogName(StringReplace(P, NumberMark, IntToStr(Highest + 1), [rfReplaceAll]));
  if Result = '' then
    Result := CleanLogName(ExpandLogName(DefaultLogNamePattern, Folder, When));
end;

function UniqueLogFile(const Folder, Name: string): string;
var
  Base: string;
  I: Integer;
begin
  Base := CleanLogName(Name);
  if Base = '' then
    Base := 'Log';
  Result := TPath.Combine(Folder, Base + '.csv');
  I := 1;
  while FileExists(Result) do
  begin
    Inc(I);
    Result := TPath.Combine(Folder, Format('%s_%d.csv', [Base, I]));
  end;
end;

{ The time on the last row: the first field, in seconds. }
function LastRowSeconds(const FileName: string): Double;
const
  Tail = 4096;
var
  F: TFileStream;
  B: TBytes;
  Lines: TArray<string>;
  S: string;
  Fs: TFormatSettings;
begin
  Result := -1;
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(B, Min(Tail, F.Size));
    if Length(B) = 0 then
      Exit;
    F.Seek(-Length(B), soEnd);
    F.ReadBuffer(B[0], Length(B));
  finally
    F.Free;
  end;
  // a cut UTF-8 character at the start is lost with the line it is in
  Lines := TEncoding.UTF8.GetString(B).Split([#13, #10], TStringSplitOptions.ExcludeEmpty);
  Fs := TFormatSettings.Invariant;
  for var I := High(Lines) downto 0 do
  begin
    S := Lines[I];
    if Pos(',', S) > 0 then
      S := Copy(S, 1, Pos(',', S) - 1);
    if TryStrToFloat(Trim(S), Result, Fs) then
      Exit;
    if StartsText('Time', Trim(Lines[I])) or StartsText(#$FEFF'Time', Lines[I]) then
      Exit(0); // the header only: nothing logged
  end;
  Result := -1;
end;

function LogInfo(const FileName: string): TLogFileInfo;
begin
  Result.FileName := FileName;
  Result.Size := 0;
  Result.Modified := 0;
  Result.Seconds := -1;
  try
    Result.Size := TFile.GetSize(FileName);
    Result.Modified := TFile.GetLastWriteTime(FileName);
    Result.Seconds := LastRowSeconds(FileName);
  except
    // gone or locked: shown with what is known
  end;
end;

function ListLogs(const Folder: string): TArray<TLogFileInfo>;
var
  L: TList<TLogFileInfo>;
begin
  Result := nil;
  if (Folder = '') or not TDirectory.Exists(Folder) then
    Exit;
  L := TList<TLogFileInfo>.Create;
  try
    for var F in TDirectory.GetFiles(Folder, '*.csv') do
      L.Add(LogInfo(F));
    L.Sort(TComparer<TLogFileInfo>.Construct(
      function(const A, B: TLogFileInfo): Integer
      begin
        Result := CompareValue(B.Modified, A.Modified);
        if Result = 0 then
          Result := CompareText(A.FileName, B.FileName);
      end));
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

end.
