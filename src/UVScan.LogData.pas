unit UVScan.LogData;

{ A UVScan CSV log in memory: one time column and one column per PID.

  The logger writes "Time (s),<name> (<units>),..." and one row per update,
  numbers with a '.' decimal point, "--" for no data and ON / OFF, YES / NO
  for switch PIDs (read back as 1 / 0). Rows that cannot be read are skipped
  and counted. A last column "Mark" (UVScan 2.0.6 on) is not a channel: it is
  empty, or a mark's number on the row it was made (the Mark hotkey).

  The live chart fills one sample at a time (StartLive, Append) and keeps only
  the last few minutes. Times and Values hold Count samples; the arrays may be
  longer (room to grow). }

interface

uses
  System.SysUtils, System.Classes, System.Math;

type
  TLogChannel = record
    Name: string;
    Units: string;
    Values: TArray<Double>;   // NaN = no data
    MinValue, MaxValue: Double; // NaN when the column never had data
    IsSwitch: Boolean;        // written as ON / OFF or YES / NO
    function Caption: string; // "Name (units)"
  end;

  TLogMark = record
    Time: Double;
    Number: Integer;
  end;

  TLogData = class
  private
    FFileName: string;
    FTitle: string;
    FTimes: TArray<Double>;
    FChannels: TArray<TLogChannel>;
    FMarks: TArray<TLogMark>; // in time order
    FCount: Integer;
    FSkipped: Integer;
    procedure Finish;
    function GetCount: Integer;
    function GetChannelCount: Integer;
  public
    procedure Clear;
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromStrings(Lines: TStrings; const Title: string);
    { A made-up 10-minute drive (cold start, idle, city, highway, a hard pull
      with knock retard, back to idle) at 10 updates a second. }
    procedure MakeDemo;
    { The rows from T0 to T1 (default: all) as a UVScan log; a part starts at
      time 0. Switches are written ON / OFF, numbers with up to 3 decimals. }
    procedure SaveToFile(const FileName: string; const T0: Double = NegInfinity;
      const T1: Double = Infinity);
    { An empty log with these channels, to be filled by Append. }
    procedure StartLive(const Title: string; const Names, Units: TArray<string>; const Switches: TArray<Boolean>);
    { Adds a sample (one value per channel, NaN = no data; T not before the
      last one) and drops the samples older than KeepSeconds before T. }
    procedure Append(const T: Double; const Values: TArray<Double>; const KeepSeconds: Double);
    { A mark at T (not before the last one). }
    procedure AddMark(const T: Double; Number: Integer);
    { The first mark after T (Forward) or before it; False when there is none. }
    function FindMark(const T: Double; Forward: Boolean; out Mark: TLogMark): Boolean;
    { Index of the last sample at or before T (0 if T is before the start). }
    function IndexAt(const T: Double): Integer;
    function Duration: Double;
    function IndexOfChannel(const Name: string): Integer;
    property FileName: string read FFileName;
    property Title: string read FTitle;
    property Times: TArray<Double> read FTimes;
    property Channels: TArray<TLogChannel> read FChannels;
    property Marks: TArray<TLogMark> read FMarks;
    property Count: Integer read GetCount;
    property ChannelCount: Integer read GetChannelCount;
    property Skipped: Integer read FSkipped;
  end;

  ELogError = class(Exception);

{ Splits one CSV line (quotes allowed). }
function SplitCsvLine(const Line: string): TArray<string>;
{ "RPM (RPM)" -> name "RPM", units "RPM"; "Runtime" -> name only. }
procedure SplitHeader(const Header: string; out Name, Units: string);
{ The rows of a UVScan log file from T0 to T1 (its own times) into Dest, as
  they are written there (every digit kept), times from 0; marks go along.
  Returns the rows copied. }
function TrimLogFile(const Source, Dest: string; const T0, T1: Double): Integer;
{ "1.5" / "ON" / "YES" -> number; "--" / "" / other -> NaN. Switch is set for ON/OFF/YES/NO. }
function ParseLogValue(const S: string; out Switch: Boolean): Double;
{ m:ss.s for a time in seconds. }
function FormatLogTime(const Seconds: Double): string;
{ How many decimals (0-3) the first Count values need, so a channel can be
  shown with the same number every time (its text does not change width). }
function DecimalsNeeded(const Values: TArray<Double>; Count: Integer): Integer;

implementation

uses
  System.StrUtils;

function SplitCsvLine(const Line: string): TArray<string>;
var
  I: Integer;
  Field: string;
  InQuotes: Boolean;
  C: Char;
begin
  Result := nil;
  Field := '';
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
          Field := Field + '"';
          Inc(I);
        end
        else
          InQuotes := False;
      end
      else
        Field := Field + C;
    end
    else if C = '"' then
      InQuotes := True
    else if C = ',' then
    begin
      Result := Result + [Field];
      Field := '';
    end
    else
      Field := Field + C;
    Inc(I);
  end;
  Result := Result + [Field];
end;

procedure SplitHeader(const Header: string; out Name, Units: string);
var
  H: string;
  P: Integer;
begin
  H := Trim(Header);
  Name := H;
  Units := '';
  if H.EndsWith(')') then
  begin
    P := H.LastIndexOf(' (');
    if P > 0 then
    begin
      Name := Trim(Copy(H, 1, P));
      Units := Copy(H, P + 3, Length(H) - P - 3);
    end;
  end;
end;

function ParseLogValue(const S: string; out Switch: Boolean): Double;
var
  T: string;
begin
  Switch := False;
  T := UpperCase(Trim(S));
  if (T = 'ON') or (T = 'YES') then
  begin
    Switch := True;
    Exit(1);
  end;
  if (T = 'OFF') or (T = 'NO') then
  begin
    Switch := True;
    Exit(0);
  end;
  if not TryStrToFloat(T, Result, TFormatSettings.Invariant) then
    Result := NaN;
end;

function DecimalsNeeded(const Values: TArray<Double>; Count: Integer): Integer;
const
  Scale: array[0..2] of Double = (1, 10, 100);
var
  I: Integer;
  V: Double;
begin
  Result := 0;
  for I := 0 to Min(Count, Length(Values)) - 1 do
  begin
    V := Values[I];
    if IsNan(V) or IsInfinite(V) then
      Continue;
    while (Result < 3) and (Abs(V * Scale[Result] - Round(V * Scale[Result])) > 1E-6 * Scale[Result]) do
      Inc(Result);
    if Result = 3 then
      Exit;
  end;
end;

function FormatLogTime(const Seconds: Double): string;
var
  S: Double;
  M: Integer;
begin
  if IsNan(Seconds) then
    Exit('-');
  S := Max(0, Seconds);
  M := Trunc(S / 60);
  Result := Format('%d:%s', [M, FormatFloat('00.0', S - M * 60, TFormatSettings.Invariant)]);
end;

{ TLogChannel }

function TLogChannel.Caption: string;
begin
  if Units <> '' then
    Result := Name + ' (' + Units + ')'
  else
    Result := Name;
end;

{ TLogData }

procedure TLogData.Clear;
begin
  FFileName := '';
  FTitle := '';
  FTimes := nil;
  FChannels := nil;
  FMarks := nil;
  FCount := 0;
  FSkipped := 0;
end;

function TLogData.GetCount: Integer;
begin
  Result := FCount;
end;

function TLogData.GetChannelCount: Integer;
begin
  Result := Length(FChannels);
end;

procedure TLogData.LoadFromFile(const FileName: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName, TEncoding.UTF8);
    LoadFromStrings(Lines, ExtractFileName(FileName));
    FFileName := FileName;
  finally
    Lines.Free;
  end;
end;

procedure TLogData.LoadFromStrings(Lines: TStrings; const Title: string);
var
  Header, Fields: TArray<string>;
  I, C, N, Row, MarkCol, M: Integer;
  T: Double;
  Switch: Boolean;
  Lists: TArray<TArray<Double>>;
  Switches: TArray<Boolean>;
  First: string;
begin
  Clear;
  FTitle := Title;
  if Lines.Count = 0 then
    raise ELogError.Create('The file is empty');
  First := Lines[0];
  if (First <> '') and (First[1] = #$FEFF) then
    Delete(First, 1, 1);
  Header := SplitCsvLine(First);
  if (Length(Header) < 2) or not SameText(Trim(Header[0]).Split([' '])[0], 'Time') then
    raise ELogError.Create('Not a UVScan log: the first column must be "Time (s)"');
  MarkCol := -1;
  if SameText(Trim(Header[High(Header)]), 'Mark') then
    MarkCol := High(Header);
  N := Length(Header) - 1;
  if MarkCol > 0 then
    Dec(N);
  SetLength(FChannels, N);
  SetLength(Lists, N);
  SetLength(Switches, N);
  for C := 0 to N - 1 do
  begin
    SplitHeader(Header[C + 1], FChannels[C].Name, FChannels[C].Units);
    SetLength(Lists[C], Lines.Count);
    Switches[C] := False;
  end;
  SetLength(FTimes, Lines.Count);
  Row := 0;
  for I := 1 to Lines.Count - 1 do
  begin
    if Trim(Lines[I]) = '' then
      Continue;
    Fields := SplitCsvLine(Lines[I]);
    if (Length(Fields) < 1) or not TryStrToFloat(Trim(Fields[0]), T, TFormatSettings.Invariant) or
      ((Row > 0) and (T < FTimes[Row - 1])) then
    begin
      Inc(FSkipped);
      Continue;
    end;
    FTimes[Row] := T;
    for C := 0 to N - 1 do
      if C + 1 < Length(Fields) then
      begin
        Lists[C][Row] := ParseLogValue(Fields[C + 1], Switch);
        Switches[C] := Switches[C] or Switch;
      end
      else
        Lists[C][Row] := NaN;
    if (MarkCol > 0) and (MarkCol < Length(Fields)) and TryStrToInt(Trim(Fields[MarkCol]), M) and (M > 0) then
      AddMark(T, M);
    Inc(Row);
  end;
  SetLength(FTimes, Row);
  FCount := Row;
  for C := 0 to N - 1 do
  begin
    SetLength(Lists[C], Row);
    FChannels[C].Values := Lists[C];
    FChannels[C].IsSwitch := Switches[C];
  end;
  Finish;
end;

procedure TLogData.Finish;
var
  C, I: Integer;
  V: Double;
begin
  for C := 0 to High(FChannels) do
  begin
    FChannels[C].MinValue := NaN;
    FChannels[C].MaxValue := NaN;
    for I := 0 to FCount - 1 do
    begin
      V := FChannels[C].Values[I];
      if IsNan(V) then
        Continue;
      if IsNan(FChannels[C].MinValue) or (V < FChannels[C].MinValue) then
        FChannels[C].MinValue := V;
      if IsNan(FChannels[C].MaxValue) or (V > FChannels[C].MaxValue) then
        FChannels[C].MaxValue := V;
    end;
  end;
end;

procedure TLogData.SaveToFile(const FileName: string; const T0, T1: Double);
var
  W: TStreamWriter;
  SB: TStringBuilder;
  I, C, Mk, First, Last: Integer;
  Base, V: Double;
begin
  // the rows in the range, and what a part's time counts from
  First := 0;
  while (First < FCount) and (FTimes[First] < T0) do
    Inc(First);
  Last := FCount - 1;
  while (Last >= First) and (FTimes[Last] > T1) do
    Dec(Last);
  Base := 0;
  if not IsInfinite(T0) and (First <= Last) then
    Base := FTimes[First];
  W := TStreamWriter.Create(FileName, False, TEncoding.UTF8);
  SB := TStringBuilder.Create;
  try
    SB.Append('Time (s)');
    for C := 0 to High(FChannels) do
      SB.Append(',').Append(FChannels[C].Caption);
    if FMarks <> nil then
      SB.Append(',Mark');
    W.WriteLine(SB.ToString);
    Mk := 0;
    if First <= Last then
      while (Mk <= High(FMarks)) and (FMarks[Mk].Time < FTimes[First]) do
        Inc(Mk); // before the part
    for I := First to Last do
    begin
      SB.Clear;
      SB.Append(FormatFloat('0.000', FTimes[I] - Base, TFormatSettings.Invariant));
      for C := 0 to High(FChannels) do
      begin
        SB.Append(',');
        V := FChannels[C].Values[I];
        if IsNan(V) then
          SB.Append('--')
        else if FChannels[C].IsSwitch then
          SB.Append(IfThen(V >= 0.5, 'ON', 'OFF'))
        else
          SB.Append(FormatFloat('0.###', V, TFormatSettings.Invariant));
      end;
      if FMarks <> nil then
      begin
        // a mark goes on the last row at or before its time
        SB.Append(',');
        if (Mk <= High(FMarks)) and ((I = Last) and (FMarks[Mk].Time <= T1) or
          (I < Last) and (FMarks[Mk].Time < FTimes[I + 1])) then
        begin
          SB.Append(FMarks[Mk].Number);
          Inc(Mk);
        end;
      end;
      W.WriteLine(SB.ToString);
    end;
  finally
    SB.Free;
    W.Free;
  end;
end;

function TrimLogFile(const Source, Dest: string; const T0, T1: Double): Integer;
var
  R: TStreamReader;
  W: TStreamWriter;
  Line, Header: string;
  Comma: Integer;
  T, Base: Double;
begin
  Result := 0;
  // (a log still being written - One log - may be trimmed too)
  R := TStreamReader.Create(TFileStream.Create(Source, fmOpenRead or fmShareDenyNone), TEncoding.UTF8, True);
  R.OwnStream;
  try
    Header := R.ReadLine;
    if (Header <> '') and (Header[1] = #$FEFF) then
      Delete(Header, 1, 1);
    if not SameText(Trim(SplitCsvLine(Header)[0]).Split([' '])[0], 'Time') then
      raise ELogError.Create('Not a UVScan log: the first column must be "Time (s)"');
    W := TStreamWriter.Create(Dest, False, TEncoding.UTF8);
    try
      W.WriteLine(Header);
      Base := NaN;
      while not R.EndOfStream do
      begin
        Line := R.ReadLine;
        Comma := Pos(',', Line);
        if (Comma = 0) or not TryStrToFloat(Trim(Copy(Line, 1, Comma - 1)), T, TFormatSettings.Invariant) then
          Continue;
        if T < T0 then
          Continue;
        if T > T1 then
          Break;
        if IsNan(Base) then
          Base := T;
        W.WriteLine(FormatFloat('0.000', T - Base, TFormatSettings.Invariant) + Copy(Line, Comma, MaxInt));
        Inc(Result);
      end;
    finally
      W.Free;
    end;
  finally
    R.Free;
  end;
end;

function TLogData.IndexAt(const T: Double): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  if FCount = 0 then
    Exit(-1);
  if T <= FTimes[0] then
    Exit(0);
  Lo := 0;
  Hi := FCount - 1;
  while Lo < Hi do
  begin
    Mid := (Lo + Hi + 1) div 2;
    if FTimes[Mid] <= T then
      Lo := Mid
    else
      Hi := Mid - 1;
  end;
  Result := Lo;
end;

function TLogData.Duration: Double;
begin
  if FCount < 2 then
    Result := 0
  else
    Result := FTimes[FCount - 1] - FTimes[0];
end;

procedure TLogData.StartLive(const Title: string; const Names, Units: TArray<string>;
  const Switches: TArray<Boolean>);
var
  C: Integer;
begin
  Clear;
  FTitle := Title;
  SetLength(FChannels, Length(Names));
  for C := 0 to High(Names) do
  begin
    FChannels[C].Name := Names[C];
    if C <= High(Units) then
      FChannels[C].Units := Units[C];
    FChannels[C].IsSwitch := (C <= High(Switches)) and Switches[C];
    FChannels[C].MinValue := NaN;
    FChannels[C].MaxValue := NaN;
  end;
end;

procedure TLogData.Append(const T: Double; const Values: TArray<Double>; const KeepSeconds: Double);
var
  C, Drop, Cap: Integer;
  V: Double;
begin
  if (FCount > 0) and (T < FTimes[FCount - 1]) then
    Exit;
  // Old samples go in chunks (a quarter of what is kept), not one by one.
  Drop := IndexAt(T - KeepSeconds);
  if (FCount > 0) and (FTimes[Drop] < T - KeepSeconds) and (Drop >= Max(16, FCount div 4)) then
  begin
    Move(FTimes[Drop], FTimes[0], (FCount - Drop) * SizeOf(Double));
    for C := 0 to High(FChannels) do
      Move(FChannels[C].Values[Drop], FChannels[C].Values[0], (FCount - Drop) * SizeOf(Double));
    Dec(FCount, Drop);
    Finish; // the lowest / highest may have gone
    while (FMarks <> nil) and (FMarks[0].Time < FTimes[0]) do
      Delete(FMarks, 0, 1);
  end;
  if FCount >= Length(FTimes) then
  begin
    Cap := Max(256, Length(FTimes) * 2);
    SetLength(FTimes, Cap);
    for C := 0 to High(FChannels) do
      SetLength(FChannels[C].Values, Cap);
  end;
  FTimes[FCount] := T;
  for C := 0 to High(FChannels) do
  begin
    V := NaN;
    if C <= High(Values) then
      V := Values[C];
    FChannels[C].Values[FCount] := V;
    if IsNan(V) then
      Continue;
    if IsNan(FChannels[C].MinValue) or (V < FChannels[C].MinValue) then
      FChannels[C].MinValue := V;
    if IsNan(FChannels[C].MaxValue) or (V > FChannels[C].MaxValue) then
      FChannels[C].MaxValue := V;
  end;
  Inc(FCount);
end;

procedure TLogData.AddMark(const T: Double; Number: Integer);
var
  M: TLogMark;
begin
  M.Time := T;
  M.Number := Number;
  FMarks := FMarks + [M];
end;

function TLogData.FindMark(const T: Double; Forward: Boolean; out Mark: TLogMark): Boolean;
const
  Near = 1E-6;
var
  I: Integer;
begin
  if Forward then
  begin
    for I := 0 to High(FMarks) do
      if FMarks[I].Time > T + Near then
      begin
        Mark := FMarks[I];
        Exit(True);
      end;
  end
  else
    for I := High(FMarks) downto 0 do
      if FMarks[I].Time < T - Near then
      begin
        Mark := FMarks[I];
        Exit(True);
      end;
  Result := False;
end;

function TLogData.IndexOfChannel(const Name: string): Integer;
begin
  for Result := 0 to High(FChannels) do
    if SameText(FChannels[Result].Name, Name) or SameText(FChannels[Result].Caption, Name) then
      Exit;
  Result := -1;
end;

procedure TLogData.MakeDemo;
const
  Rate = 10;
  Seconds = 600;
  Names: array[0..9] of string = ('RPM', 'MPH', 'ECT', 'IAT', 'TP %', 'MAP(kPa)', 'KR', 'O2', 'STFT', 'IGN V');
  Units: array[0..9] of string = ('RPM', 'MPH', 'Deg F', 'Deg F', '%', 'kPa', 'Degrees', 'mV', '%', 'V');
var
  N, I, C: Integer;
  T, Speed, TargetSpeed, Rpm, Tps, Ecu, Iat, Map, Kr, O2, Stft, Volts, Gear, Ratio, Prev: Double;
  Seed: Cardinal;

  function Noise(Amp: Double): Double;
  begin
    // small repeatable pseudo-random jitter
    Seed := Cardinal((UInt64(Seed) * 1103515245 + 12345) and $FFFFFFFF);
    Result := Amp * (((Seed shr 16) and $7FFF) / 32767 - 0.5) * 2;
  end;

begin
  Clear;
  FTitle := 'Demo drive (made-up data)';
  N := Seconds * Rate;
  SetLength(FTimes, N);
  FCount := N;
  SetLength(FChannels, Length(Names));
  for C := 0 to High(Names) do
  begin
    FChannels[C].Name := Names[C];
    FChannels[C].Units := Units[C];
    SetLength(FChannels[C].Values, N);
  end;
  Seed := 20011234;
  Speed := 0;
  Ecu := 55;
  Kr := 0;
  for I := 0 to N - 1 do
  begin
    T := I / Rate;
    // drive plan: idle, city stop-and-go, highway cruise, a hard pull, slow down, idle
    if T < 40 then
      TargetSpeed := 0
    else if T < 220 then
      TargetSpeed := Max(0, 32 + 18 * Sin((T - 40) / 14)) * Ord(Frac((T - 40) / 60) < 0.8)
    else if T < 400 then
      TargetSpeed := 68 + 3 * Sin(T / 23)
    else if T < 412 then
      TargetSpeed := 68 + (T - 400) * 4.5
    else if T < 540 then
      TargetSpeed := Max(0, 110 - (T - 412) * 0.9)
    else
      TargetSpeed := 0;
    Prev := Speed;
    Speed := Max(0, Speed + EnsureRange(TargetSpeed - Speed, -1.2, IfThen(T > 400, 1.6, 0.7)));
    // gear from speed, then rpm
    if Speed < 1 then
      Gear := 0
    else if Speed < 18 then
      Gear := 1
    else if Speed < 34 then
      Gear := 2
    else if Speed < 52 then
      Gear := 3
    else
      Gear := 4;
    case Round(Gear) of
      1: Ratio := 2.92;
      2: Ratio := 1.57;
      3: Ratio := 1.0;
      4: Ratio := 0.71;
    else
      Ratio := 0;
    end;
    if Gear = 0 then
      Rpm := 650 + 250 * Max(0, 1 - T / 60) + Noise(15)
    else
      Rpm := Max(750, Speed * Ratio * 3.05 * 336 / 26) + Noise(20); // mph x gear x axle x 336 / tyre diameter
    Tps := EnsureRange(4 + Max(0, (Speed - Prev) * Rate) * 9 + Speed * 0.12 + Noise(0.6), 0, 100);
    if (T >= 400) and (T < 412) then
      Tps := 92 + Noise(2);
    Map := EnsureRange(28 + Tps * 0.72 + Noise(1), 20, 101);
    Ecu := Min(196, Ecu + IfThen(Ecu < 196, 0.06 + Rpm / 60000, 0)) + Noise(0.1);
    Iat := 70 + 25 * Exp(-Speed / 25) * Min(1, T / 120) + Noise(0.3);
    if (T >= 404) and (T < 411) then
      Kr := Max(0, Min(7, Kr + Noise(1.5) + 0.6))
    else
      Kr := Max(0, Kr - 0.4);
    O2 := IfThen(Ecu < 120, 450, IfThen(Tps > 80, 880 + Noise(20), 450 + 380 * Sin(T * 7.3) + Noise(40)));
    Stft := IfThen(Ecu < 120, 0, Noise(4) + IfThen(Tps > 80, -6, 0));
    Volts := IfThen(T < 2, 11.6, 14.1 + Noise(0.08) - IfThen((T > 300) and (T < 330), 1.9, 0));
    FTimes[I] := T;
    FChannels[0].Values[I] := Round(Rpm * 4) / 4;
    FChannels[1].Values[I] := Round(Speed * 10) / 10;
    FChannels[2].Values[I] := Round(Ecu);
    FChannels[3].Values[I] := Round(Iat);
    FChannels[4].Values[I] := Round(Tps * 10) / 10;
    FChannels[5].Values[I] := Round(Map);
    FChannels[6].Values[I] := Round(Kr * 10) / 10;
    FChannels[7].Values[I] := Round(EnsureRange(O2, 50, 950));
    FChannels[8].Values[I] := Round(Stft * 10) / 10;
    FChannels[9].Values[I] := Round(Volts * 10) / 10;
  end;
  // as if Mark was pressed at the voltage dip and at the knock
  AddMark(301, 1);
  AddMark(405, 2);
  Finish;
end;

end.
