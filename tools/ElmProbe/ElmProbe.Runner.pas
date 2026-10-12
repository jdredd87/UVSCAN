unit ElmProbe.Runner;

{ The ELM327 probe's work, on a thread of its own: connect to the adapter,
  run the test sequence (or single commands typed in), log every byte both
  ways with times, and write it all to a log file.

  The test sequence finds out what the adapter is, whether it talks J1850
  VPW to the PCM, and how fast: mode 22 reads one at a time, and DPID
  streams (the way UVScan scans with the AVT). }

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs,
  UVScan.Serial, UVScan.Elm;

type
  TProbeLog = reference to procedure(const Line: string);

  TProbeRunner = class(TThread)
  private
    FPortName: string;
    FBaud: Cardinal;
    FOnLog: TProbeLog;
    FJobs: TThreadedQueue<string>;
    FPort: ISerialPort;
    FLink: TElmLink;
    FLogFile: TStreamWriter;
    FStart: UInt64;
    FSummary: TStringList;
    FStopRequested: Boolean;
    procedure Log(const Line: string); overload;
    procedure Log(const Fmt: string; const Args: array of const); overload;
    procedure Section(const Title: string);
    procedure Note(const Fmt: string; const Args: array of const);
    procedure Connect;
    procedure Disconnect;
    function Try_(const Cmd: string; TimeoutMs: Cardinal = 2000): string;
    procedure RunTests;
    procedure TestAdapter;
    procedure TestBus;
    procedure TestMode22;
    procedure TestDtcs;
    function DefineDpids: Boolean;
    procedure TestStream(const Title: string; const Requests: array of string; Seconds: Integer;
      const Resume: string; HeartbeatMs: Integer);
    procedure StopStreams;
    function Ask(const Hex: string): string;
    procedure RunCommand(const Cmd: string);
  protected
    procedure Execute; override;
  public
    constructor Create(const PortName: string; Baud: Cardinal; const LogFolder: string; const OnLog: TProbeLog);
    destructor Destroy; override;
    { 'TESTS', 'CMD <text>', 'STREAM <seconds>', 'QUIT' }
    procedure Post(const Job: string);
    { Ends a test sequence or stream soon (between steps). }
    procedure RequestStop;
    function LogFileName: string;
  end;

implementation

uses
  System.Math, System.StrUtils, System.IOUtils,
  {$IFDEF ANDROID}UVScan.Bluetooth.Android,{$ENDIF}
  UVScan.Hex, UVScan.Class2;

type
  TDpidPart = record
    Pos, Size: Byte;
    Pid: Word;
  end;

const
  // DPIDs for the stream tests: SAE PIDs every Class 2 PCM has (mode 22).
  //   FE: RPM(2) VSS ECT TPS MAP     FD: IAT ECT VSS TPS MAP RPM-hi
  //   FC / FB: the same as FE / FD, for the 4-DPID stream.
  DpidDefs: array[0..3, 0..4] of TDpidPart = (
    ((Pos: 1; Size: 2; Pid: $000C), (Pos: 3; Size: 1; Pid: $000D), (Pos: 4; Size: 1; Pid: $0005),
     (Pos: 5; Size: 1; Pid: $0011), (Pos: 6; Size: 1; Pid: $000B)),
    ((Pos: 1; Size: 1; Pid: $000F), (Pos: 2; Size: 1; Pid: $0005), (Pos: 3; Size: 1; Pid: $000D),
     (Pos: 4; Size: 1; Pid: $0011), (Pos: 5; Size: 2; Pid: $000C)),
    ((Pos: 1; Size: 2; Pid: $000C), (Pos: 3; Size: 1; Pid: $000D), (Pos: 4; Size: 1; Pid: $0005),
     (Pos: 5; Size: 1; Pid: $0011), (Pos: 6; Size: 1; Pid: $000B)),
    ((Pos: 1; Size: 1; Pid: $000F), (Pos: 2; Size: 1; Pid: $0005), (Pos: 3; Size: 1; Pid: $000D),
     (Pos: 4; Size: 1; Pid: $0011), (Pos: 5; Size: 2; Pid: $000C)));

{ TProbeRunner }

constructor TProbeRunner.Create(const PortName: string; Baud: Cardinal; const LogFolder: string; const OnLog: TProbeLog);
var
  Name: string;
begin
  FPortName := PortName;
  FBaud := Baud;
  FOnLog := OnLog;
  FJobs := TThreadedQueue<string>.Create(16, INFINITE, 100);
  FSummary := TStringList.Create;
  ForceDirectories(LogFolder);
  Name := TPath.Combine(LogFolder, 'ElmProbe_' + FormatDateTime('yyyy-mm-dd_hhnnss', Now) + '.txt');
  FLogFile := TStreamWriter.Create(Name, False, TEncoding.UTF8);
  FLogFile.AutoFlush := True;
  FStart := TThread.GetTickCount64;
  inherited Create(False);
end;

destructor TProbeRunner.Destroy;
begin
  inherited;
  FLink.Free;
  FJobs.Free;
  FSummary.Free;
  FLogFile.Free;
end;

function TProbeRunner.LogFileName: string;
begin
  Result := (FLogFile.BaseStream as TFileStream).FileName;
end;

procedure TProbeRunner.Post(const Job: string);
begin
  FStopRequested := False;
  FJobs.PushItem(Job);
end;

procedure TProbeRunner.RequestStop;
begin
  FStopRequested := True;
end;

procedure TProbeRunner.Log(const Line: string);
var
  Ms: UInt64;
  S: string;
begin
  Ms := TThread.GetTickCount64 - FStart;
  S := Format('%3d.%.3d  %s', [Ms div 1000, Ms mod 1000, Line]);
  FLogFile.WriteLine(S);
  if Assigned(FOnLog) then
    FOnLog(S);
end;

procedure TProbeRunner.Log(const Fmt: string; const Args: array of const);
begin
  Log(Format(Fmt, Args));
end;

procedure TProbeRunner.Section(const Title: string);
begin
  Log('');
  Log('=== ' + Title + ' ===');
end;

{ A result line: logged now and repeated in the summary at the end. }
procedure TProbeRunner.Note(const Fmt: string; const Args: array of const);
var
  S: string;
begin
  S := Format(Fmt, Args);
  FSummary.Add(S);
  Log('** ' + S);
end;

procedure TProbeRunner.Connect;
var
  T0: UInt64;
begin
  if (FPort <> nil) and FPort.IsOpen then
    Exit;
  Log('Connecting to %s ...', [FPortName]);
  T0 := TThread.GetTickCount64;
  {$IFDEF ANDROID}
  if IsBluetoothPort(FPortName) then
    FPort := CreateBluetoothPort(FPortName)
  else
  {$ENDIF}
    FPort := CreatePort(FPortName, FBaud, fcNone);
  FPort.Open;
  Note('Connected to %s in %d ms', [FPort.Description, TThread.GetTickCount64 - T0]);
  FreeAndNil(FLink);
  FLink := TElmLink.Create(FPort,
    procedure(Line: string)
    begin
      Log(Line);
    end);
end;

procedure TProbeRunner.Disconnect;
begin
  if FPort <> nil then
  begin
    FPort.Close;
    Log('Disconnected');
  end;
  FreeAndNil(FLink);
  FPort := nil;
end;

{ A command whose reply is only logged (and returned): never raises. }
function TProbeRunner.Try_(const Cmd: string; TimeoutMs: Cardinal): string;
begin
  try
    Result := String.Join(' | ', FLink.CommandLines(Cmd, TimeoutMs));
    Log('   %s -> %s  (%d ms)', [Cmd, Result, FLink.LastMs]);
  except
    on E: Exception do
    begin
      Result := '';
      Log('   %s -> FAILED: %s', [Cmd, E.Message]);
      FLink.Flush;
    end;
  end;
end;

procedure TProbeRunner.TestAdapter;
var
  R: string;
begin
  Section('Adapter');
  R := Try_('ATZ', 5000);
  if R = '' then
  begin
    // Some adapters answer a warm start faster / only.
    Sleep(500);
    FLink.Flush;
    R := Try_('ATWS', 3000);
  end;
  Note('Reset reply: %s', [IfThen(R <> '', R, '(none)')]);
  Try_('ATE0');
  Try_('ATL0');
  Try_('ATS0');
  Try_('ATH1');
  FLink.HeadersOn := True;
  Note('ATI: %s', [Try_('ATI')]);
  Note('AT@1: %s', [Try_('AT@1')]);
  Try_('AT@2');
  Note('Voltage (ATRV): %s', [Try_('ATRV')]);
  Note('STI (OBDLink/STN chip): %s', [Try_('STI')]);
  Try_('STDI');
  Note('Protocols the chip names (ATDP before ATSP): %s', [Try_('ATDP')]);
end;

procedure TProbeRunner.TestBus;
var
  Frames: TArray<TElmFrame>;
  F: TElmFrame;
  Errors, Vin: string;
  B: Byte;
  I: Integer;
  Ok: Boolean;
begin
  Section('J1850 VPW');
  Note('ATSP2: %s', [Try_('ATSP2')]);
  Note('ATDP: %s', [Try_('ATDP')]);

  // Generic OBD first (the ELM's own default header 68 6A F1).
  try
    Frames := FLink.Request(BytesOf([$68, $6A, $F1, $01, $00]), Errors, 5000);
    Note('Generic 01 00: %d frame(s) in %d ms %s', [Length(Frames), FLink.LastMs, Errors]);
    for F in Frames do
      Log('     %s', [BytesToHex(F)]);
  except
    on E: Exception do
      Note('Generic 01 00 FAILED: %s', [E.Message]);
  end;

  // Everyone on the bus: tester present / return to normal (discovers modules).
  try
    Frames := FLink.Request(DiscoverModulesRequest, Errors, 2000);
    Errors := Errors + ' modules:';
    for F in Frames do
      if Length(F) >= 3 then
        Errors := Errors + ' ' + ModuleName(F[2]);
    Note('Discover (6C FE F1 20): %d frame(s) in %d ms %s', [Length(Frames), FLink.LastMs, Errors]);
  except
    on E: Exception do
      Note('Discover FAILED: %s', [E.Message]);
  end;

  // VIN from the PCM's blocks 1-3 (mode 3C), as UVScan reads it.
  Vin := '';
  Ok := True;
  for I := BlockVin1 to BlockVin3 do
    try
      Frames := FLink.Request(ReadBlockRequest(I), Errors, 2000);
      Log('   3C %.2x: %d frame(s) in %d ms %s', [I, Length(Frames), FLink.LastMs, Errors]);
      Ok := Ok and (Length(Frames) > 0);
      for F in Frames do
      begin
        Log('     %s', [BytesToHex(F)]);
        if (Length(F) > 5) and (F[3] = ModeReadBlock + PositiveOffset) then
          for B in Copy(F, 5, MaxInt) do
            if B in [$20..$7E] then
              Vin := Vin + Char(B);
      end;
    except
      on E: Exception do
      begin
        Ok := False;
        Log('   3C %.2x FAILED: %s', [I, E.Message]);
      end;
    end;
  Note('VIN (3C 01-03): %s %s', [IfThen(Vin <> '', Vin, '(none)'), IfThen(Ok, '', '- some blocks missing')]);
  try
    Frames := FLink.Request(ReadBlockRequest(BlockOsid), Errors, 2000);
    if Length(Frames) > 0 then
      Note('OSID (3C 0A): %s', [BytesToHex(Frames[0])])
    else
      Note('OSID (3C 0A): none %s', [Errors]);
  except
    on E: Exception do
      Note('OSID FAILED: %s', [E.Message]);
  end;
end;

procedure TProbeRunner.TestMode22;
const
  Pids: array[0..6] of Word = ($000C, $000D, $0005, $0011, $000B, $000F, $1940);
  Count = 30;
var
  Pid: Word;
  Frames: TArray<TElmFrame>;
  Errors: string;
  I, Good: Integer;
  T0, Ms: UInt64;
  Msg: TBytes;
begin
  Section('Mode 22 (one PID per request)');
  for Pid in Pids do
    try
      // UVScan reads with source F0 (PID test); the ELM only shows replies
      // addressed to F1 unless told otherwise, so F1 here.
      Msg := BuildMessage(AddrPcm, AddrTool, ModeReadPid, [Hi(Pid), Lo(Pid), $01]);
      Frames := FLink.Request(Msg, Errors, 2000);
      if Length(Frames) > 0 then
        Log('   PID %.4x: %s  (%d ms) %s', [Pid, BytesToHex(Frames[0]), FLink.LastMs, Errors])
      else
        Log('   PID %.4x: no reply  (%d ms) %s', [Pid, FLink.LastMs, Errors]);
    except
      on E: Exception do
        Log('   PID %.4x FAILED: %s', [Pid, E.Message]);
    end;

  // Speed: the same PID over and over.
  Good := 0;
  Msg := BuildMessage(AddrPcm, AddrTool, ModeReadPid, [$00, $0C, $01]);
  T0 := TThread.GetTickCount64;
  for I := 1 to Count do
  begin
    if FStopRequested or Terminated then
      Break;
    try
      Frames := FLink.Request(Msg, Errors, 2000);
      if (Length(Frames) > 0) and (Length(Frames[0]) > 3) and (Frames[0][3] = ModeReadPid + PositiveOffset) then
        Inc(Good);
    except
      FLink.Flush;
    end;
  end;
  Ms := Max(1, TThread.GetTickCount64 - T0);
  Note('Mode 22 speed: %d of %d good, %d ms each, %.1f reads/s', [Good, Count, Ms div Count, Good * 1000 / Ms]);
end;

procedure TProbeRunner.TestDtcs;
var
  Frames: TArray<TElmFrame>;
  F: TElmFrame;
  Errors, Codes: string;
begin
  Section('DTCs (mode 19, PCM)');
  try
    Frames := FLink.Request(ReadDtcsRequest(AddrPcm), Errors, 3000);
    Codes := '';
    for F in Frames do
    begin
      Log('     %s', [BytesToHex(F)]);
      if (Length(F) >= 6) and (F[3] = ModeReadDtcs + PositiveOffset) and ((F[4] <> 0) or (F[5] <> 0)) then
        Codes := Codes + ' ' + FormatDtc(F[4], F[5]);
    end;
    Note('DTCs: %d frame(s) in %d ms, codes:%s %s', [Length(Frames), FLink.LastMs, IfThen(Codes <> '', Codes, ' none'), Errors]);
  except
    on E: Exception do
      Note('DTCs FAILED: %s', [E.Message]);
  end;
end;

function TProbeRunner.DefineDpids: Boolean;
var
  D, J: Integer;
  Frames: TArray<TElmFrame>;
  Errors: string;
  Ok: Boolean;
begin
  Section('Define DPIDs FE-FB (mode 2C)');
  Result := True;
  for D := 0 to High(DpidDefs) do
    for J := 0 to 4 do
      try
        Frames := FLink.Request(DefineDpidRequest(FirstDpid - D, DpidDefs[D, J].Pos, DpidDefs[D, J].Size,
          DpidDefs[D, J].Pid), Errors, 2000);
        Ok := (Length(Frames) > 0) and (Length(Frames[0]) > 3) and (Frames[0][3] = ModeDefineDpid + PositiveOffset);
        Result := Result and Ok;
        Log('   %.2x pos %d: %s  (%d ms) %s', [FirstDpid - D, DpidDefs[D, J].Pos,
          IfThen(Length(Frames) > 0, BytesToHex(Frames[0]), 'no reply'), FLink.LastMs, Errors]);
      except
        on E: Exception do
        begin
          Result := False;
          Log('   %.2x pos %d FAILED: %s', [FirstDpid - D, DpidDefs[D, J].Pos, E.Message]);
        end;
      end;
  Note('DPID definitions: %s', [IfThen(Result, 'all accepted', 'NOT all accepted')]);
end;

{ Sends the stream requests and counts the DPID frames that come for
  Seconds. When the ELM stops listening (the prompt comes back) Resume is
  sent to listen again ('' = the test ends there; 'ATMA' = monitor the bus;
  '3F' = tester present, whose listening the frames keep going). Every
  HeartbeatMs (0 = never) a tester present (3F to the PCM) keeps the PCM
  in diagnostic mode, as the AVT engine does; the ELM has to stop
  listening for that. }
procedure TProbeRunner.TestStream(const Title: string; const Requests: array of string; Seconds: Integer;
  const Resume: string; HeartbeatMs: Integer);
var
  Beat: UInt64;
  Beats, Resumes: Integer;
  R: string;
  Line: string;
  Prompt: Boolean;
  F: TElmFrame;
  Counts: TDictionary<Byte, Integer>;
  T0, Last, Now_, Deadline: UInt64;
  Frames, Prompts, Errors, Other: Integer;
  MaxGap: UInt64;
  Key: Byte;
  S: string;
begin
  Section(Title);
  Counts := TDictionary<Byte, Integer>.Create;
  try
    FLink.SetHeader(BytesOf([PriorityRequest, AddrPcm, AddrTool]));
    Frames := 0;
    Prompts := 0;
    Errors := 0;
    Other := 0;
    MaxGap := 0;
    Beats := 0;
    Resumes := 0;
    for R in Requests do
      if R <> Requests[High(Requests)] then
        Ask(R);
    T0 := TThread.GetTickCount64;
    Last := T0;
    Beat := T0;
    Deadline := T0 + Cardinal(Seconds) * 1000;
    FLink.Send(Requests[High(Requests)]);
    while (TThread.GetTickCount64 < Deadline) and not FStopRequested and not Terminated do
    begin
      if (HeartbeatMs > 0) and (TThread.GetTickCount64 - Beat >= UInt64(HeartbeatMs)) then
      begin
        Beat := TThread.GetTickCount64;
        Inc(Beats);
        FLink.Interrupt;
        FLink.Send('3F');
      end;
      if not FLink.ReadLine(200, Line, Prompt) then
        Continue;
      if Prompt then
      begin
        // The ELM stopped listening (no frame within its timeout).
        Inc(Prompts);
        Log('   (prompt: the ELM stopped listening after %d ms)', [TThread.GetTickCount64 - T0]);
        if Resume = '' then
          Break;
        Inc(Resumes);
        FLink.Send(Resume);
        Continue;
      end;
      if Line.ToUpper.Contains('STOPPED') then
        Continue;
      if ParseElmFrame(Line, True, F) then
      begin
        if (Length(F) >= 5) and (F[3] = $6A) then
        begin
          Inc(Frames);
          if Counts.ContainsKey(F[4]) then
            Counts[F[4]] := Counts[F[4]] + 1
          else
            Counts.Add(F[4], 1);
          Now_ := TThread.GetTickCount64;
          if (Frames > 1) and (Now_ - Last > MaxGap) then
            MaxGap := Now_ - Last;
          Last := Now_;
        end
        else
          Inc(Other);
      end
      else
      begin
        Inc(Errors);
        Log('   (message: %s)', [Line]);
      end;
    end;
    Now_ := Max(T0 + 1, TThread.GetTickCount64);
    FLink.Interrupt;
    S := '';
    for Key in Counts.Keys do
      S := S + Format(' %.2x=%d (%.1f/s)', [Key, Counts[Key], Counts[Key] * 1000 / (Now_ - T0)]);
    Note('%s: %d DPID frames in %.1f s = %.1f frames/s; longest gap %d ms; other frames %d, messages %d, ' +
      'prompts %d, resumed %d, heartbeats %d;%s',
      [Title, Frames, (Now_ - T0) / 1000, Frames * 1000 / (Now_ - T0), MaxGap, Other, Errors, Prompts, Resumes,
       Beats, S]);
  finally
    Counts.Free;
  end;
end;

{ Sends a request to the PCM (header already set) while a stream may be
  running, and returns its answer: the first line that is not a DPID frame.
  The frames would keep the ELM listening, so it is stopped after that. }
function TProbeRunner.Ask(const Hex: string): string;
var
  Deadline: UInt64;
  Line: string;
  Prompt: Boolean;
  F: TElmFrame;
begin
  Result := '';
  FLink.Interrupt;
  FLink.Send(Hex);
  Deadline := TThread.GetTickCount64 + 1000;
  while TThread.GetTickCount64 < Deadline do
    if FLink.ReadLine(200, Line, Prompt) then
    begin
      if Prompt then
        Break;
      if ParseElmFrame(Line, True, F) and (Length(F) > 3) and (F[3] = $6A) then
        Continue;
      Result := Line;
      Break;
    end;
  FLink.Interrupt;
  Log('   %s -> %s', [Hex, IfThen(Result <> '', Result, '(no answer)')]);
end;

procedure TProbeRunner.StopStreams;
begin
  try
    FLink.SetHeader(BytesOf([PriorityRequest, AddrPcm, AddrTool]));
    Ask(BytesToHex(Copy(StopDpidsRequest, 3, MaxInt), ''));
    Ask(BytesToHex(Copy(ClearStreamSlotRequest(StreamSlot1), 3, MaxInt), ''));
    Ask(BytesToHex(Copy(ClearStreamSlotRequest(StreamSlot2), 3, MaxInt), ''));
    FLink.Flush;
  except
    on E: Exception do
      Log('Stopping the streams: %s', [E.Message]);
  end;
end;

procedure TProbeRunner.RunTests;
var
  S: string;
begin
  FSummary.Clear;
  try
    Connect;
    TestAdapter;
    if FStopRequested then Exit;
    TestBus;
    if FStopRequested then Exit;
    TestMode22;
    if FStopRequested then Exit;
    TestDtcs;
    if FStopRequested then Exit;
    if DefineDpids and not FStopRequested then
    begin
      // One slot (4 DPIDs, ~5 rows/s), listening kept up by ATMA.
      TestStream('A: 4 DPIDs, ATMA, 3F every 2 s', ['2A14FEFDFCFB'], 20, 'ATMA', 2000);
      StopStreams;
      // Both slots (each DPID ~10 rows/s, as UVScan does for up to 4 DPIDs).
      if not FStopRequested then
        TestStream('B: 4 DPIDs in both slots, listen, 3F every 2 s', ['2A14FEFDFCFB', '2A24FEFDFCFB'], 20, '3F', 2000);
      StopStreams;
      if not FStopRequested then
        TestStream('C: 4 DPIDs in both slots, ATMA, 3F every 2 s', ['2A14FEFDFCFB', '2A24FEFDFCFB'], 20, 'ATMA', 2000);
      StopStreams;
      // One slot with a fixed (not adaptive) 1 s timeout: does listening last?
      if not FStopRequested then
      begin
        Try_('ATAT0');
        Try_('ATSTFF');
        TestStream('D: 4 DPIDs, ATAT0 ATSTFF, listen, 3F every 2 s', ['2A14FEFDFCFB'], 20, '3F', 2000);
        StopStreams;
        Try_('ATAT1');
        Try_('ATST32');
      end;
    end;
  finally
    Section('Summary');
    for S in FSummary do
      Log(S);
    Log('Log file: %s', [LogFileName]);
  end;
end;

procedure TProbeRunner.RunCommand(const Cmd: string);
begin
  Connect;
  Try_(Cmd, 5000);
end;

procedure TProbeRunner.Execute;
var
  Job: string;
begin
  Log('ElmProbe - port %s, baud %d', [FPortName, FBaud]);
  while not Terminated do
  begin
    if FJobs.PopItem(Job) <> TWaitResult.wrSignaled then
      Continue;
    if Job = 'QUIT' then
      Break;
    try
      if Job = 'TESTS' then
        RunTests
      else if Job.StartsWith('CMD ') then
        RunCommand(Job.Substring(4))
      else if Job.StartsWith('STREAM ') then
      begin
        Connect;
        FLink.Flush;
        DefineDpids;
        TestStream('Stream 4 DPIDs in both slots', ['2A14FEFDFCFB', '2A24FEFDFCFB'],
          StrToIntDef(Job.Substring(7), 10), 'ATMA', 2000);
        StopStreams;
      end
      else if Job = 'DISCONNECT' then
        Disconnect;
    except
      on E: Exception do
        Log('ERROR: %s: %s', [E.ClassName, E.Message]);
    end;
    Log('(done: %s)', [Job]);
  end;
  try
    if (FPort <> nil) and FPort.IsOpen and (FLink <> nil) then
      StopStreams;
  except
  end;
  Disconnect;
end;

end.
