program UVScanProbe;

{ Console bench tool: talks to a real AVT + PCM and prints everything.

  UVScanProbe <port> raw [baud] [rtscts|none]
      Sends the AVT init frames and dumps raw bytes.
  UVScanProbe <port> run <seconds> <pidIds,...> [-notest] [-nodtc] [-speed 4|3|2]
      Connect, vehicle info, PID test, scan for <seconds>, read DTCs.
      Read-only: never writes VIN, clears codes, or sends device control. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Diagnostics, System.Math, System.StrUtils,
  UVScan.Hex in '..\src\UVScan.Hex.pas',
  UVScan.Serial in '..\src\UVScan.Serial.pas',
  UVScan.Avt in '..\src\UVScan.Avt.pas',
  UVScan.Class2 in '..\src\UVScan.Class2.pas',
  UVScan.Formula in '..\src\UVScan.Formula.pas',
  UVScan.Pids in '..\src\UVScan.Pids.pas',
  UVScan.Dpid in '..\src\UVScan.Dpid.pas',
  UVScan.Engine in '..\src\UVScan.Engine.pas',
  UVScan.Paths in '..\src\UVScan.Paths.pas',
  UVScan.JsonFile in '..\src\UVScan.JsonFile.pas';

var
  Clock: TStopwatch;

procedure Say(const S: string);
begin
  Writeln(Format('%8.3f  %s', [Clock.Elapsed.TotalSeconds, S]));
end;

procedure RawListen(const Port: ISerialPort; Ms: Integer);
var
  Buf: array[0..255] of Byte;
  N: Integer;
  W: TStopwatch;
  B: TBytes;
begin
  W := TStopwatch.StartNew;
  while W.ElapsedMilliseconds < Ms do
  begin
    N := Port.Read(Buf, SizeOf(Buf), 50);
    if N > 0 then
    begin
      SetLength(B, N);
      Move(Buf, B[0], N);
      Say('RX  ' + BytesToHex(B));
    end;
  end;
end;

procedure RawProbe(const PortName: string; Baud: Cardinal; Flow: TFlowControl);
var
  Port: ISerialPort;
  F: string;
begin
  Port := TWin32SerialPort.Create(PortName, Baud, Flow);
  Port.Open;
  Say(Format('Opened %s', [Port.Description]));
  Say('Listening 500 ms for unsolicited data...');
  RawListen(Port, 500);
  for F in ['E1 33', 'B0', '05 6C 10 F1 3C 01'] do
  begin
    Say('TX  ' + F);
    Port.Write(HexToBytes(F));
    RawListen(Port, 1000);
  end;
  Port.Close;
end;

{ Byte-level view of a short stream: define DPID $FE with RPM + ECT + IGN V,
  request it (unpadded), dump everything, stop. No parser involved. }
procedure RawScan(const PortName: string);
var
  Port: ISerialPort;
  F: string;
begin
  Port := TWin32SerialPort.Create(PortName, 115200, fcRtsCts);
  Port.Open;
  Say(Format('Opened %s', [Port.Description]));
  for F in ['E1 33', 'B0',
    '0A 6C 10 F1 2C FE 4A 00 0C FF FF',
    '0A 6C 10 F1 2C FE 59 00 05 FF FF',
    '0A 6C 10 F1 2C FE 61 11 41 FF FF'] do
  begin
    Say('TX  ' + F);
    Port.Write(HexToBytes(F));
    RawListen(Port, 300);
  end;
  Say('TX  06 6C 10 F1 2A 14 FE   (unpadded)');
  Port.Write(HexToBytes('06 6C 10 F1 2A 14 FE'));
  RawListen(Port, 1500);
  Say('TX  05 6C 10 F1 2A 00   (stop)');
  Port.Write(HexToBytes('05 6C 10 F1 2A 00'));
  RawListen(Port, 1000);
  Say('TX  09 6C 10 F1 2A 14 FE 00 00 00   (padded, legacy)');
  Port.Write(HexToBytes('09 6C 10 F1 2A 14 FE 00 00 00'));
  RawListen(Port, 1500);
  Say('TX  05 6C 10 F1 2A 00   (stop)');
  Port.Write(HexToBytes('05 6C 10 F1 2A 00'));
  RawListen(Port, 1000);
  Port.Close;
end;

{ Try different $2A rate bytes with DPID $FE (padded) and count frames. }
procedure RateTest(const PortName: string);
var
  Port: ISerialPort;
  Parser: TAvtFrameParser;
  Rate: Byte;
  Buf: array[0..255] of Byte;
  N, Frames: Integer;
  W: TStopwatch;
  Fr: TAvtFrame;
  Notes: string;
begin
  Port := TWin32SerialPort.Create(PortName, 115200, fcRtsCts);
  Parser := TAvtFrameParser.Create;
  try
    Port.Open;
    Port.Write(HexToBytes('E1 33'));
    RawListen(Port, 200);
    Port.Write(HexToBytes('0A 6C 10 F1 2C FE 4A 00 0C FF FF'));
    RawListen(Port, 300);
    for Rate in [$01, $02, $03, $04, $05, $11, $12, $13, $14, $24, $34, $44] do
    begin
      Parser.Clear;
      Port.Write(BytesOf([$09, $6C, $10, $F1, $2A, Rate, $FE, 0, 0, 0]));
      Frames := 0;
      Notes := '';
      W := TStopwatch.StartNew;
      while W.ElapsedMilliseconds < 2000 do
      begin
        N := Port.Read(Buf, SizeOf(Buf), 50);
        if N > 0 then
          Parser.Push(Buf, N);
        while Parser.TryNext(Fr) do
          if (Length(Fr.Data) >= 6) and (Fr.Data[4] = $6A) and (Fr.Data[5] = $FE) then
            Inc(Frames)
          else if Length(Fr.Data) > 1 then
            Notes := Notes + ' [' + Fr.ToHex + ']';
      end;
      Say(Format('rate $%.2x: %d FE frames in 2 s (%.1f/s)%s', [Rate, Frames, Frames / 2, Notes]));
      Port.Write(HexToBytes('05 6C 10 F1 2A 00'));
      RawListen(Port, 400);
    end;
    Port.Close;
  finally
    Parser.Free;
  end;
end;

{ Multi-DPID behaviour: define $FE..$F9 (RPM in each), try request patterns,
  count frames per DPID. }
procedure MultiTest(const PortName: string);
var
  Port: ISerialPort;
  Parser: TAvtFrameParser;
  Id: Byte;

  // Count DPID frames for Ms milliseconds; returns e.g. " FE:15 FD:15 ..." and notes.
  function CountFor(Ms: Integer; out Notes: string): string;
  var
    Buf: array[0..255] of Byte;
    N, I: Integer;
    W: TStopwatch;
    Fr: TAvtFrame;
    Counts: array[Byte] of Integer;
  begin
    FillChar(Counts, SizeOf(Counts), 0);
    Notes := '';
    W := TStopwatch.StartNew;
    while W.ElapsedMilliseconds < Ms do
    begin
      N := Port.Read(Buf, SizeOf(Buf), 50);
      if N > 0 then
        Parser.Push(Buf, N);
      while Parser.TryNext(Fr) do
        if (Length(Fr.Data) > 6) and (Fr.Data[4] = $6A) then
          Inc(Counts[Fr.Data[5]])
        else if (Length(Fr.Data) > 1) and not ((Length(Fr.Data) >= 5) and (Fr.Data[4] = $7F)) then
          Notes := Notes + ' [' + Fr.ToHex + ']';
    end;
    Result := '';
    for I := $FE downto $F7 do
      if Counts[I] > 0 then
        Result := Result + Format(' %.2x:%d', [I, Counts[I]]);
    if Result = '' then
      Result := ' (none)';
  end;

  procedure Send(const Hex: string);
  begin
    Port.Write(HexToBytes(Hex));
  end;

var
  Pattern, Line, Notes, Leftover, Counted: string;
begin
  Port := TWin32SerialPort.Create(PortName, 115200, fcRtsCts);
  Parser := TAvtFrameParser.Create;
  try
    Port.Open;
    Send('E1 33');
    RawListen(Port, 200);
    for Id := $F7 to $FE do
    begin
      Port.Write(BytesOf([$0A, $6C, $10, $F1, $2C, Id, $4A, $00, $0C, $FF, $FF]));
      RawListen(Port, 120);
    end;
    for Pattern in [
      '2A 14 00 00 00 00|2A 24 00 00 00 00|2A 24 FE 00 00 00',
      '2A 14 00 00 00 00|2A 24 00 00 00 00|2A 14 FE 00 00 00|2A 24 FE 00 00 00',
      '2A 14 00 00 00 00|2A 24 00 00 00 00|2A 24 FE FD FC FB',
      '2A 14 00 00 00 00|2A 24 00 00 00 00|2A 14 FE FD FC FB|2A 24 FE FD FC FB',
      '2A 14 00 00 00 00|2A 24 00 00 00 00|2A 14 FE FD FC FB|2A 24 FA F9 F8 F7'] do
    begin
      // Stop and make sure nothing is still streaming.
      Send('05 6C 10 F1 2A 00');
      Leftover := CountFor(1200, Notes);
      for Line in Pattern.Split(['|']) do
      begin
        Send('09 6C 10 F1 ' + Line);
        Sleep(60);
      end;
      Counted := CountFor(3000, Notes);
      Say(Format('%-36s -> 3s:%s   | leftover before:%s%s', [Pattern, Counted, Leftover, Notes]));
    end;
    Send('05 6C 10 F1 2A 00');
    Say('after final stop, 2 s:' + CountFor(2000, Notes) + Notes);
    Send('05 6C 10 F1 2A 00');
    Say('after second stop, 2 s:' + CountFor(2000, Notes) + Notes);
    Port.Close;
  finally
    Parser.Free;
  end;
end;

{ Read-only survey: asks the PCM for every PID in the given ranges with mode
  $22 (the same request "Test PIDs" uses) and prints the ones it answers,
  with the number of data bytes and the raw value. Ranges: "0000-00FF,1100-13FF". }
procedure Sweep(const PortName, Ranges: string);
var
  Port: ISerialPort;
  Parser: TAvtFrameParser;
  Buf: array[0..255] of Byte;
  N, RangeLo, RangeHi, Pid, Supported, Refused, Silent: Integer;
  W: TStopwatch;
  Fr: TAvtFrame;
  Msg: TClass2Message;
  R: string;
  Parts: TArray<string>;
  Done: Boolean;
begin
  Port := TWin32SerialPort.Create(PortName, 115200, fcRtsCts);
  Parser := TAvtFrameParser.Create;
  try
    Port.Open;
    Port.Write(HexToBytes('E1 33'));
    RawListen(Port, 200);
    Supported := 0;
    Refused := 0;
    Silent := 0;
    for R in Ranges.Split([',']) do
    begin
      Parts := R.Split(['-']);
      RangeLo := StrToInt('$' + Parts[0]);
      RangeHi := StrToInt('$' + Parts[High(Parts)]);
      for Pid := RangeLo to RangeHi do
      begin
        Parser.Clear;
        Port.Write(EncodeBusMessage(ReadPidRequest(Pid)));
        Done := False;
        W := TStopwatch.StartNew;
        while not Done and (W.ElapsedMilliseconds < 300) do
        begin
          N := Port.Read(Buf, SizeOf(Buf), 30);
          if N > 0 then
            Parser.Push(Buf, N);
          while Parser.TryNext(Fr) do
            if Fr.IsBusMessage and TryParseClass2(Fr.BusMessage, Msg) and (Msg.Source = AddrPcm) and
              (Msg.Target = AddrToolPidTest) and (Length(Msg.Data) >= 2) then
            begin
              if (Msg.Mode = ModeReadPid + PositiveOffset) and (Msg.Data[0] = Hi(Word(Pid))) and (Msg.Data[1] = Lo(Word(Pid))) then
              begin
                Writeln(Format('PID %.4x bytes=%d data=%s', [Pid, Length(Msg.Data) - 2,
                  BytesToHex(Copy(Msg.Data, 2, MaxInt))]));
                Inc(Supported);
                Done := True;
              end
              else if Msg.IsNegativeFor(ModeReadPid) then
              begin
                Inc(Refused);
                Done := True;
              end;
            end;
        end;
        if not Done then
          Inc(Silent);
      end;
    end;
    Say(Format('Supported %d, refused %d, no answer %d', [Supported, Refused, Silent]));
    Port.Close;
  finally
    Parser.Free;
  end;
end;

{ Sends one Class 2 request to the PCM and returns the PCM's answer for that
  mode (positive or 7F negative) as hex, '' if none within TimeoutMs. }
function Ask(const Port: ISerialPort; Parser: TAvtFrameParser; const Msg: TBytes; TimeoutMs: Integer): string;
var
  Buf: array[0..255] of Byte;
  N: Integer;
  W: TStopwatch;
  Fr: TAvtFrame;
  M: TClass2Message;
  Mode: Byte;
begin
  Result := '';
  Mode := Msg[3];
  Parser.Clear;
  Port.Write(EncodeBusMessage(Msg));
  W := TStopwatch.StartNew;
  while W.ElapsedMilliseconds < TimeoutMs do
  begin
    N := Port.Read(Buf, SizeOf(Buf), 30);
    if N > 0 then
      Parser.Push(Buf, N);
    while Parser.TryNext(Fr) do
      if Fr.IsBusMessage and TryParseClass2(Fr.BusMessage, M) and (M.Source = AddrPcm) and
        (M.IsPositiveFor(Mode) or M.IsNegativeFor(Mode)) then
        Exit(M.ToHex);
  end;
end;

{ Device control survey: sends mode $AE for each CPID with all six control
  bytes zero (= control nothing / reset nothing) and prints the PCM's answer,
  then returns the PCM to normal mode ($20). }
procedure CpidSurvey(const PortName: string; Lo, Hi: Integer);
var
  Port: ISerialPort;
  Parser: TAvtFrameParser;
  Cpid: Integer;
  Reply: string;
  Counts: TStringList;
begin
  Port := TWin32SerialPort.Create(PortName, 115200, fcRtsCts);
  Parser := TAvtFrameParser.Create;
  Counts := TStringList.Create;
  try
    Port.Open;
    Port.Write(HexToBytes('E1 33'));
    RawListen(Port, 200);
    for Cpid := Lo to Hi do
    begin
      Reply := Ask(Port, Parser, BuildMessage(AddrPcm, AddrTool, ModeDeviceControl,
        [Byte(Cpid), 0, 0, 0, 0, 0, 0]), 400);
      if Reply = '' then
        Reply := '(no answer)';
      Say(Format('CPID %.2x -> %s', [Cpid, Reply]));
      Sleep(30);
    end;
    Say('Return to normal ($20) -> ' + Ask(Port, Parser, BuildMessage(AddrPcm, AddrTool, $20, []), 500));
    Port.Close;
  finally
    Counts.Free;
    Parser.Free;
  end;
end;

{ For each CPID, tries 0..8 zero control bytes: shows which lengths the PCM accepts. }
procedure CpidLengths(const PortName: string; const Cpids: string);
var
  Port: ISerialPort;
  Parser: TAvtFrameParser;
  S: string;
  Cpid, N: Integer;
  Data: TArray<Byte>;
begin
  Port := TWin32SerialPort.Create(PortName, 115200, fcRtsCts);
  Parser := TAvtFrameParser.Create;
  try
    Port.Open;
    Port.Write(HexToBytes('E1 33'));
    RawListen(Port, 200);
    for S in Cpids.Split([',']) do
    begin
      Cpid := StrToInt('$' + S);
      for N := 0 to 8 do
      begin
        SetLength(Data, N + 1);
        FillChar(Data[0], Length(Data), 0);
        Data[0] := Cpid;
        Say(Format('CPID %.2x + %d bytes -> %s', [Cpid, N, Ask(Port, Parser,
          BuildMessage(AddrPcm, AddrTool, ModeDeviceControl, Data), 400)]));
      end;
    end;
    Say('Return to normal ($20) -> ' + Ask(Port, Parser, BuildMessage(AddrPcm, AddrTool, $20, []), 500));
    Port.Close;
  finally
    Parser.Free;
  end;
end;

{ Maps device-control bits to PIDs. Reads every PID listed in PidFile (lines
  "PID xxxx ..." as printed by sweep) twice for a baseline, then for each CPID
  and each bit sets the bit in both bytes of a mask/value pair - pairs (1,2)
  (3,4) (5,6) and split (1,4) (2,5) (3,6) - reads all PIDs again, prints what
  changed, and releases the CPID (all zero) before the next test. Finishes
  with mode $20 (return to normal). }
procedure CpidMap(const PortName, PidFile, Cpids: string);
type
  TSnap = TArray<string>;
var
  Port: ISerialPort;
  Parser: TAvtFrameParser;
  Pids: TArray<Word>;
  Base, Base2, Now_: TSnap;
  Noisy: TArray<Boolean>;
  Line, S, Reply, Changes: string;
  I, Cpid, Layout, Pair, Bit, A, B: Integer;
  Data: TArray<Byte>;
  Lines: TStringList;

  function Snap: TSnap;
  var
    K: Integer;
    R: string;
  begin
    SetLength(Result, Length(Pids));
    for K := 0 to High(Pids) do
    begin
      R := Ask(Port, Parser, ReadPidRequest(Pids[K]), 300);
      // "6C F0 10 62 hi lo data..." -> data
      if (Length(R) > 18) and (Copy(R, 10, 2) = '62') then
        Result[K] := Copy(R, 19, MaxInt)
      else
        Result[K] := '?';
    end;
  end;

  procedure Release(C: Integer);
  begin
    Ask(Port, Parser, BuildMessage(AddrPcm, AddrTool, ModeDeviceControl, [Byte(C), 0, 0, 0, 0, 0, 0]), 300);
  end;

begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(PidFile);
    for Line in Lines do
      if Line.StartsWith('PID ') then
        Pids := Pids + [Word(StrToInt('$' + Copy(Line, 5, 4)))];
  finally
    Lines.Free;
  end;
  Say(Format('%d PIDs to watch', [Length(Pids)]));
  Port := TWin32SerialPort.Create(PortName, 115200, fcRtsCts);
  Parser := TAvtFrameParser.Create;
  try
    Port.Open;
    Port.Write(HexToBytes('E1 33'));
    RawListen(Port, 200);
    Base := Snap;
    Base2 := Snap;
    SetLength(Noisy, Length(Pids));
    for I := 0 to High(Pids) do
    begin
      Noisy[I] := Base[I] <> Base2[I];
      if Noisy[I] then
        Say(Format('  PID %.4x changes on its own (%s -> %s), ignored', [Pids[I], Base[I], Base2[I]]));
    end;
    for S in Cpids.Split([',']) do
    begin
      Cpid := StrToInt('$' + S);
      for Layout := 0 to 1 do
        for Pair := 0 to 2 do
          for Bit := 7 downto 0 do
          begin
            if Layout = 0 then
            begin
              A := 1 + 2 * Pair;
              B := A + 1;
            end
            else
            begin
              A := 1 + Pair;
              B := A + 3;
            end;
            SetLength(Data, 7);
            FillChar(Data[0], 7, 0);
            Data[0] := Cpid;
            Data[A] := 1 shl Bit;
            Data[B] := 1 shl Bit;
            Reply := Ask(Port, Parser, BuildMessage(AddrPcm, AddrTool, ModeDeviceControl, Data), 400);
            if (Reply = '') or (Pos(' 7F ', Reply) > 0) then
            begin
              Say(Format('CPID %.2x %s : %s', [Cpid, BytesToHex(Copy(Data, 1, 6)), IfThen(Reply = '', 'no answer', Reply)]));
              Release(Cpid);
              Continue;
            end;
            Sleep(400);
            Now_ := Snap;
            Changes := '';
            for I := 0 to High(Pids) do
              if not Noisy[I] and (Now_[I] <> Base[I]) then
                Changes := Changes + Format('  %.4x:%s->%s', [Pids[I], Base[I], Now_[I]]);
            Say(Format('CPID %.2x %s : OK%s', [Cpid, BytesToHex(Copy(Data, 1, 6)),
              IfThen(Changes = '', '  (no PID changed)', Changes)]));
            Release(Cpid);
            Sleep(300);
          end;
    end;
    Say('Return to normal ($20) -> ' + Ask(Port, Parser, BuildMessage(AddrPcm, AddrTool, $20, []), 500));
    Now_ := Snap;
    Changes := '';
    for I := 0 to High(Pids) do
      if not Noisy[I] and (Now_[I] <> Base[I]) then
        Changes := Changes + Format('  %.4x:%s->%s', [Pids[I], Base[I], Now_[I]]);
    Say('After the run, still different from the start:' + IfThen(Changes = '', ' nothing', Changes));
    Port.Close;
  finally
    Parser.Free;
  end;
end;

{ Confirms device-control effects on a few PIDs. For the CPID, tries every
  single bit of the 6 control bytes and every split pair (byte n and n+3), each
  Reps times: set, read the PIDs, release, read again. Prints only effects
  seen on every repeat that also go away on release. }
procedure CpidConfirm(const PortName, Cpids, PidList: string; Reps, FirstTest: Integer);
var
  Port: ISerialPort;
  Parser: TAvtFrameParser;
  Pids: TArray<Word>;
  S: string;
  Cpid, Test, Bit, A, B, R, I: Integer;
  Data: TArray<Byte>;
  Base, OnV, OffV: TArray<string>;
  Consistent: TArray<Boolean>;
  Seen: TArray<string>;
  Line, Reply: string;

  function Read: TArray<string>;
  var
    K: Integer;
    X: string;
  begin
    SetLength(Result, Length(Pids));
    for K := 0 to High(Pids) do
    begin
      X := Ask(Port, Parser, ReadPidRequest(Pids[K]), 300);
      if (Length(X) > 18) and (Copy(X, 10, 2) = '62') then
        Result[K] := Copy(X, 19, MaxInt)
      else
        Result[K] := '?';
    end;
  end;

  function Send(const D: TArray<Byte>): string;
  begin
    Result := Ask(Port, Parser, BuildMessage(AddrPcm, AddrTool, ModeDeviceControl, D), 400);
  end;

begin
  for S in PidList.Split([',']) do
    Pids := Pids + [Word(StrToInt('$' + S))];
  Port := TWin32SerialPort.Create(PortName, 115200, fcRtsCts);
  Parser := TAvtFrameParser.Create;
  try
    Port.Open;
    Port.Write(HexToBytes('E1 33'));
    RawListen(Port, 200);
    for S in Cpids.Split([',']) do
    begin
      Cpid := StrToInt('$' + S);
      Send([Byte(Cpid), 0, 0, 0, 0, 0, 0]);
      Sleep(300);
      Base := Read;
      Line := '';
      for I := 0 to High(Pids) do
        Line := Line + Format('  %.4x=%s', [Pids[I], Base[I]]);
      Say(Format('CPID %.2x released:%s', [Cpid, Line]));
      // tests 0..47: single bit (byte Test div 8 + 1); 48..71: split pair (n, n+3);
      // 72..95: mask / value pair (1,2) (3,4) (5,6). FirstTest skips ahead.
      for Test := FirstTest to 95 do
      begin
        SetLength(Data, 7);
        FillChar(Data[0], 7, 0);
        Data[0] := Cpid;
        if Test < 48 then
        begin
          A := Test div 8 + 1;
          Bit := 7 - Test mod 8;
          Data[A] := 1 shl Bit;
        end
        else if Test >= 72 then
        begin
          A := 2 * ((Test - 72) div 8) + 1;
          Bit := 7 - (Test - 72) mod 8;
          Data[A] := 1 shl Bit;
          Data[A + 1] := 1 shl Bit;
        end
        else
        begin
          A := (Test - 48) div 8 + 1;
          B := A + 3;
          Bit := 7 - (Test - 48) mod 8;
          Data[A] := 1 shl Bit;
          Data[B] := 1 shl Bit;
        end;
        SetLength(Consistent, Length(Pids));
        SetLength(Seen, Length(Pids));
        for I := 0 to High(Pids) do
        begin
          Consistent[I] := True;
          Seen[I] := '';
        end;
        Reply := '';
        for R := 1 to Reps do
        begin
          Reply := Send(Data);
          if (Reply = '') or (Pos(' 7F ', Reply) > 0) then
            Break;
          Sleep(300);
          OnV := Read;
          Send([Byte(Cpid), 0, 0, 0, 0, 0, 0]);
          Sleep(300);
          OffV := Read;
          for I := 0 to High(Pids) do
          begin
            if (OnV[I] = Base[I]) or (OffV[I] <> Base[I]) or ((Seen[I] <> '') and (Seen[I] <> OnV[I])) then
              Consistent[I] := False;
            Seen[I] := OnV[I];
          end;
        end;
        if (Reply = '') or (Pos(' 7F ', Reply) > 0) then
        begin
          Say(Format('CPID %.2x %s : %s', [Cpid, BytesToHex(Copy(Data, 1, 6)), IfThen(Reply = '', 'no answer', Reply)]));
          Continue;
        end;
        Line := '';
        for I := 0 to High(Pids) do
          if Consistent[I] then
            Line := Line + Format('  %.4x:%s->%s', [Pids[I], Base[I], Seen[I]]);
        if Line <> '' then
          Say(Format('CPID %.2x %s :%s', [Cpid, BytesToHex(Copy(Data, 1, 6)), Line]));
      end;
    end;
    Say('Return to normal ($20) -> ' + Ask(Port, Parser, BuildMessage(AddrPcm, AddrTool, $20, []), 500));
    Port.Close;
  finally
    Parser.Free;
  end;
end;

procedure Pump(Ms: Integer);
var
  W: TStopwatch;
begin
  W := TStopwatch.StartNew;
  while W.ElapsedMilliseconds < Ms do
    CheckSynchronize(10);
end;

var
  State: TEngineState = esDisconnected;
  Busy: Boolean;

function WaitState(S: TEngineState; Ms: Integer): Boolean;
var
  W: TStopwatch;
begin
  W := TStopwatch.StartNew;
  repeat
    CheckSynchronize(10);
    if (State = S) and not Busy then
      Exit(True);
  until W.ElapsedMilliseconds > Ms;
  Result := False;
end;

procedure EngineRun(const PortName: string; Seconds: Integer; const Ids: TArray<Integer>; DoTest, DoDtc: Boolean);
var
  Catalog: TPidCatalog;
  Engine: TScanEngine;
  Cmd: TEngineCommand;
  W: TStopwatch;
  S: TLiveSnapshot;
  I: Integer;
  Line, RateText: string;
  P: TPidDef;
begin
  Catalog := TPidCatalog.Create;
  try
    Catalog.LoadFromFile(PidsFile);
    Engine := TScanEngine.Create(Catalog,
      procedure(const Ev: TEngineEvent)
      var
        D: TDtcEntry;
      begin
        case Ev.Kind of
          eeLog: Say(Ev.Text);
          eeWarning: Say('WARN  ' + Ev.Text);
          eeError: Say('ERROR ' + Ev.Text);
          eeState:
            begin
              State := Ev.State;
              Busy := Ev.State = esBusy;
              Say('STATE ' + StateNames[Ev.State]);
            end;
          eeVehicleInfo: Say(Format('VEHICLE firmware=%s vin=%s osid=%s', [Ev.Vehicle.Firmware, Ev.Vehicle.Vin, Ev.Vehicle.Osid]));
          eePidRejected: Say('REJECTED ' + Ev.Text);
          eePidTest: Say(Format('PIDTEST %d/%d id=%d %s supported=%s', [Ev.Progress, Ev.Total, Ev.PidId,
            Catalog.FindById(Ev.PidId).LongName, BoolToStr(Ev.Supported, True)]));
          eeDtcs:
            begin
              Say(Format('DTCS %d', [Length(Ev.Dtcs)]));
              for D in Ev.Dtcs do
                Say(Format('  %s module=$%.2x status=$%.2x', [D.Code, D.Module, D.Status]));
            end;
          eeScanStarted: Say('SCAN STARTED');
        end;
      end);
    try
      Engine.SetTrace(True);
      if FindCmdLineSwitch('speed', RateText, True, [clstValueNextParam]) then
        Engine.StreamSpeed := StrToInt(RateText);
      Say(Format('Stream speed %d', [Engine.StreamSpeed]));
      Cmd := Command(ecConnect);
      Cmd.Factory :=
        function: ISerialPort
        begin
          Result := TWin32SerialPort.Create(PortName, 115200, fcRtsCts);
        end;
      Engine.Post(Cmd);
      Pump(500);
      if not WaitState(esConnected, 10000) then
      begin
        Say('Did not reach Connected state');
        Exit;
      end;

      if DoTest then
      begin
        Cmd := Command(ecTestPids);
        Cmd.PidIds := Ids;
        Engine.Post(Cmd);
        Pump(300);
        WaitState(esConnected, 60000);
      end;

      if Seconds > 0 then
      begin
        Cmd := Command(ecStartScan);
        Cmd.PidIds := Ids;
        Engine.Post(Cmd);
        WaitState(esScanning, 20000);
        Engine.SetTrace(False); // don't flood the console with stream frames
        W := TStopwatch.StartNew;
        while W.Elapsed.TotalSeconds < Seconds do
        begin
          Pump(1000);
          S := Engine.GetSnapshot;
          Line := Format('cycles=%d rate=%.1f/s stray=%d |', [S.Cycles, S.CyclesPerSecond, S.StrayFrames]);
          for I := 0 to High(S.PidIds) do
          begin
            P := Catalog.FindById(S.PidIds[I]);
            Line := Line + Format(' %s=%s', [P.DisplayName, S.Text[I]]);
          end;
          Say(Line);
        end;
        Engine.SetTrace(True);
        Engine.Post(Command(ecStopScan));
        Pump(300);
        WaitState(esConnected, 5000);
        Say('Listening 1.5 s after stop (stream should be quiet)...');
        Pump(1500);
      end;

      if DoDtc then
      begin
        Engine.Post(Command(ecReadDtcs));
        Pump(300);
        WaitState(esConnected, 20000);
      end;

      Engine.Post(Command(ecDisconnect));
      Pump(500);
    finally
      Engine.Free;
      CheckSynchronize(0);
    end;
  finally
    Catalog.Free;
  end;
end;

var
  Ids: TArray<Integer>;
  S: string;
  Flow: TFlowControl;
begin
  Clock := TStopwatch.StartNew;
  try
    if ParamCount < 2 then
    begin
      Writeln('UVScanProbe <port> raw [baud] [rtscts|none]');
      Writeln('UVScanProbe <port> run <seconds> <pidIds,...> [-notest] [-nodtc] [-speed 4|3|2]');
      Writeln('UVScanProbe <port> rawscan | rates | multi');
      Halt(1);
    end;
    if SameText(ParamStr(2), 'cpidconfirm') then
      CpidConfirm(ParamStr(1), ParamStr(3), ParamStr(4), StrToIntDef(ParamStr(5), 3), StrToIntDef(ParamStr(6), 0))
    else if SameText(ParamStr(2), 'cpidmap') then
      CpidMap(ParamStr(1), ParamStr(3), ParamStr(4))
    else if SameText(ParamStr(2), 'cpidlen') then
      CpidLengths(ParamStr(1), ParamStr(3))
    else if SameText(ParamStr(2), 'cpids') then
      CpidSurvey(ParamStr(1), StrToIntDef('$' + ParamStr(3), 0), StrToIntDef('$' + ParamStr(4), $FF))
    else if SameText(ParamStr(2), 'sweep') then
      Sweep(ParamStr(1), ParamStr(3))
    else if SameText(ParamStr(2), 'multi') then
      MultiTest(ParamStr(1))
    else if SameText(ParamStr(2), 'rates') then
      RateTest(ParamStr(1))
    else if SameText(ParamStr(2), 'rawscan') then
      RawScan(ParamStr(1))
    else if SameText(ParamStr(2), 'raw') then
    begin
      Flow := fcRtsCts;
      if SameText(ParamStr(4), 'none') then
        Flow := fcNone;
      RawProbe(ParamStr(1), StrToIntDef(ParamStr(3), 115200), Flow);
    end
    else
    begin
      for S in ParamStr(4).Split([',']) do
        if S <> '' then
          Ids := Ids + [StrToInt(S)];
      EngineRun(ParamStr(1), StrToIntDef(ParamStr(3), 5), Ids,
        not FindCmdLineSwitch('notest'), not FindCmdLineSwitch('nodtc'));
    end;
  except
    on E: Exception do
      Say('EXCEPTION ' + E.ClassName + ': ' + E.Message);
  end;
end.
