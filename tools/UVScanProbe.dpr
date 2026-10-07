program UVScanProbe;

{ Console bench tool: talks to a real AVT + PCM and prints everything.

  UVScanProbe <port> raw [baud] [rtscts|none]
      Sends the AVT init frames and dumps raw bytes.
  UVScanProbe <port> run <seconds> <pidIds,...> [-notest] [-nodtc] [-speed 4|3|2]
      Connect, vehicle info, PID test, scan for <seconds>, read DTCs.
      Read-only: never writes VIN, clears codes, or sends device control. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Diagnostics, System.Math,
  UVScan.Hex in '..\src\UVScan.Hex.pas',
  UVScan.Serial in '..\src\UVScan.Serial.pas',
  UVScan.Avt in '..\src\UVScan.Avt.pas',
  UVScan.Class2 in '..\src\UVScan.Class2.pas',
  UVScan.Formula in '..\src\UVScan.Formula.pas',
  UVScan.Pids in '..\src\UVScan.Pids.pas',
  UVScan.Dpid in '..\src\UVScan.Dpid.pas',
  UVScan.Engine in '..\src\UVScan.Engine.pas',
  UVScan.Paths in '..\src\UVScan.Paths.pas';

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
      Writeln('UVScanProbe <port> rawscan | rates');
      Halt(1);
    end;
    if SameText(ParamStr(2), 'multi') then
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
