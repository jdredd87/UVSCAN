unit UVScan.Engine;

{ The scan engine: one background thread that owns the serial port.

  Everything that touches the AVT happens on this thread, strictly in
  sequence: request, wait for the matching reply (or timeout), next request.
  The heartbeat (tester present) is sent from the same loop, so it can never
  land in the middle of another exchange. The UI talks to the engine through
  a command queue and receives events via TThread.Queue; live values are read
  with GetSnapshot (cheap, lock-protected copy). }

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Diagnostics, System.Math,
  System.StrUtils, System.Generics.Collections,
  UVScan.Serial, UVScan.Avt, UVScan.Class2, UVScan.Pids, UVScan.Dpid, UVScan.Hex, UVScan.Formula;

type
  TEngineState = (esDisconnected, esConnected, esScanning, esBusy);

  TVehicleInfo = record
    Firmware: string;
    Vin: string;
    Osid: string;
  end;

  TDtcEntry = record
    Module: Byte;
    Code: string;
    Status: Byte;
  end;

  TEngineEventKind = (eeLog, eeWarning, eeError, eeState, eeVehicleInfo, eeScanStarted,
    eePidRejected, eeDtcs, eePidTest, eeLogStarted, eeLogStopped,
    eePidFound, eePidSearchProgress, eePidSearchDone);

  TEngineEvent = record
    Kind: TEngineEventKind;
    Text: string;
    State: TEngineState;
    Vehicle: TVehicleInfo;
    Dtcs: TArray<TDtcEntry>;
    PidIds: TArray<Integer>;   // eeScanStarted: scan order
    PidId: Integer;            // eePidRejected / eePidTest
    Supported: Boolean;        // eePidTest
    Progress, Total: Integer;  // eePidTest, eePidSearchProgress, eePidSearchDone
    DataBytes: Integer;        // eePidFound: size of the PCM's answer (PidId = PID number)
    Raw: string;               // eePidFound: data bytes as hex
  end;

  TEngineEventHandler = reference to procedure(const Event: TEngineEvent);
  TPortFactory = reference to function: ISerialPort;

  TLiveSnapshot = record
    PidIds: TArray<Integer>;
    Values: TArray<Double>;
    Text: TArray<string>;
    Cycles: Int64;
    CyclesPerSecond: Double;
    LogRows: Int64;
    StrayFrames: Int64;  // stream frames for DPIDs that are not part of this scan
    Logging: Boolean;
    LogPaused: Boolean;
  end;

  TEngineCommandKind = (ecConnect, ecDisconnect, ecReadVehicleInfo, ecStartScan, ecStopScan,
    ecStartLog, ecStopLog, ecPauseLog, ecReadDtcs, ecClearDtcs, ecTestPids, ecSendRaw,
    ecWriteVin, ecResetLtft, ecCheckEngineLight,
    ecDiscoverPids);             // Text = PID ranges, e.g. '0000-00FF,1000-1FFF'

  TEngineCommand = record
    Kind: TEngineCommandKind;
    PidIds: TArray<Integer>;
    Text: string;
    Flag: Boolean;
    Factory: TPortFactory;
  end;

  TFrameMatch = reference to function(const F: TAvtFrame): Boolean;

  TScanEngine = class(TThread)
  private
    FCatalog: TPidCatalog;
    FOnEvent: TEngineEventHandler;
    FCommands: TThreadedQueue<TEngineCommand>;
    FCancel: Integer;          // set by Cancel; checked by long operations
    FTrace: Integer;           // log raw traffic when <> 0
    FStreamSpeed: Byte;

    // Owned by the engine thread only
    FPort: ISerialPort;
    FParser: TAvtFrameParser;
    FPending: TQueue<TAvtFrame>;
    FReadBuf: array[0..1023] of Byte;
    FState: TEngineState;
    FVehicle: TVehicleInfo;
    FStreaming: Boolean;
    FAnalogOn: Boolean;
    FLastHeartbeat: TStopwatch;
    FLastData: TStopwatch;
    FNoDataWarned: Boolean;

    // Current scan
    FScanPids: TArray<TPidDef>;
    FPlan: TDpidPlan;
    FWork: TArray<Double>;
    FRejected: TArray<Boolean>; // per scan index: PCM refused the DPID slot
    FReceivedMask: Cardinal;
    FAllMask: Cardinal;
    FCalcSources: TArray<TArray<Integer>>; // per scan index: source per formula variable
    FScanClock: TStopwatch;
    FCycles: Int64;
    FRateClock: TStopwatch;
    FRateCycles: Int64;
    FRate: Double;
    FStray: Int64;

    // Logging
    FLog: TStreamWriter;
    FLogPaused: Boolean;
    FLogRows: Int64;
    FLogClock: TStopwatch;
    FLogFlush: TStopwatch;

    // Snapshot shared with the UI
    FLock: TCriticalSection;
    FSnapshot: TLiveSnapshot;

    procedure Emit(const Ev: TEngineEvent);
    procedure EmitText(Kind: TEngineEventKind; const Text: string);
    procedure Log(const Text: string); overload;
    procedure Log(const Fmt: string; const Args: array of const); overload;
    procedure Warn(const Text: string);
    procedure SetState(S: TEngineState);
    function Cancelled: Boolean;

    // Transport
    procedure SendFrame(const Frame: TBytes);
    procedure SendBus(const Msg: TBytes);
    function NextFrame(TimeoutMs: Cardinal; out F: TAvtFrame): Boolean;
    function WaitFor(const Match: TFrameMatch; TimeoutMs: Cardinal; out Reply: TAvtFrame): Boolean;
    function Exchange(const Msg: TBytes; const Match: TFrameMatch; TimeoutMs: Cardinal;
      out Reply: TClass2Message): Boolean;
    procedure Drain(Ms: Cardinal);
    procedure HandleUnsolicited(const F: TAvtFrame);
    procedure Service;

    // Commands
    procedure Execute_(const Cmd: TEngineCommand);
    procedure DoConnect(const Factory: TPortFactory);
    procedure DoDisconnect;
    procedure DoReadVehicleInfo;
    procedure DoStartScan(const Ids: TArray<Integer>);
    procedure DoStopScan;
    procedure ForgetScan;
    procedure StopStreaming;
    procedure ResetStreamSlots;
    procedure DoStartLog(const FileName: string);
    procedure DoStopLog;
    procedure DoReadDtcs;
    procedure DoClearDtcs;
    procedure DoTestPids(const Ids: TArray<Integer>);
    procedure DoDiscoverPids(const Ranges: string);
    procedure DoSendRaw(const Hex: string);
    procedure DoWriteVin(const Vin: string);
    procedure DoSimpleRequest(const Msg: TBytes; const What: string);
    function RequireConnected: Boolean;

    // Scan data
    procedure HandleDpidData(const Msg: TClass2Message);
    procedure HandleAnalog(const F: TAvtFrame);
    procedure CompleteCycle;
    procedure ComputeCalculated;
    procedure PublishSnapshot;
    procedure WriteLogRow;
  protected
    procedure Execute; override;
  public
    constructor Create(Catalog: TPidCatalog; const OnEvent: TEngineEventHandler);
    destructor Destroy; override;
    procedure Post(const Cmd: TEngineCommand);
    procedure Cancel;
    function GetSnapshot: TLiveSnapshot;
    procedure SetTrace(Enabled: Boolean);
    { $2A speed nibble (StreamSpeedFast/Medium/Slow); applies from the next scan. }
    property StreamSpeed: Byte read FStreamSpeed write FStreamSpeed;
  end;

function Command(Kind: TEngineCommandKind): TEngineCommand;

const
  StateNames: array[TEngineState] of string = ('Disconnected', 'Connected', 'Scanning', 'Busy');

implementation

const
  HeartbeatMs = 2000;
  ReplyTimeoutMs = 400;
  NoDataWarningMs = 3000;
  SourceRuntime = -2;
  SourceLogTime = -3;
  SourceMissing = -1;

function Command(Kind: TEngineCommandKind): TEngineCommand;
begin
  Result := Default(TEngineCommand);
  Result.Kind := Kind;
end;

function FromPcm(const F: TAvtFrame; out Msg: TClass2Message): Boolean;
begin
  Result := F.IsBusMessage and TryParseClass2(F.BusMessage, Msg) and (Msg.Source = AddrPcm);
end;

{ TScanEngine }

constructor TScanEngine.Create(Catalog: TPidCatalog; const OnEvent: TEngineEventHandler);
begin
  FCatalog := Catalog;
  FOnEvent := OnEvent;
  FCommands := TThreadedQueue<TEngineCommand>.Create(256, 1000, 0);
  FParser := TAvtFrameParser.Create;
  FPending := TQueue<TAvtFrame>.Create;
  FLock := TCriticalSection.Create;
  FStreamSpeed := StreamSpeedFast;
  inherited Create(False);
  NameThreadForDebugging('UVScan engine');
end;

destructor TScanEngine.Destroy;
begin
  Terminate;
  FCommands.DoShutDown;
  inherited; // waits for Execute to finish
  FCommands.Free;
  FParser.Free;
  FPending.Free;
  FLock.Free;
end;

procedure TScanEngine.Post(const Cmd: TEngineCommand);
begin
  if Cmd.Kind in [ecDisconnect, ecStopScan] then
    Cancel; // abort any long-running operation first
  FCommands.PushItem(Cmd);
end;

procedure TScanEngine.Cancel;
begin
  TInterlocked.Exchange(FCancel, 1);
end;

function TScanEngine.Cancelled: Boolean;
begin
  Result := Terminated or (TInterlocked.CompareExchange(FCancel, 0, 0) <> 0);
end;

procedure TScanEngine.SetTrace(Enabled: Boolean);
begin
  TInterlocked.Exchange(FTrace, Ord(Enabled));
end;

function TScanEngine.GetSnapshot: TLiveSnapshot;
begin
  FLock.Enter;
  try
    Result := FSnapshot;
    Result.Values := Copy(FSnapshot.Values);
    Result.Text := Copy(FSnapshot.Text);
  finally
    FLock.Leave;
  end;
end;

procedure TScanEngine.Emit(const Ev: TEngineEvent);
var
  Handler: TEngineEventHandler;
  Copy_: TEngineEvent;
begin
  Handler := FOnEvent;
  if not Assigned(Handler) then
    Exit;
  Copy_ := Ev;
  Queue(
    procedure
    begin
      Handler(Copy_);
    end);
end;

procedure TScanEngine.EmitText(Kind: TEngineEventKind; const Text: string);
var
  Ev: TEngineEvent;
begin
  Ev := Default(TEngineEvent);
  Ev.Kind := Kind;
  Ev.Text := Text;
  Emit(Ev);
end;

procedure TScanEngine.Log(const Text: string);
begin
  EmitText(eeLog, Text);
end;

procedure TScanEngine.Log(const Fmt: string; const Args: array of const);
begin
  Log(Format(Fmt, Args));
end;

procedure TScanEngine.Warn(const Text: string);
begin
  EmitText(eeWarning, Text);
end;

procedure TScanEngine.SetState(S: TEngineState);
var
  Ev: TEngineEvent;
begin
  if S = FState then
    Exit;
  FState := S;
  Ev := Default(TEngineEvent);
  Ev.Kind := eeState;
  Ev.State := S;
  Emit(Ev);
end;

{ Transport }

procedure TScanEngine.SendFrame(const Frame: TBytes);
begin
  if FTrace <> 0 then
    Log('TX  ' + BytesToHex(Frame));
  FPort.Write(Frame);
end;

procedure TScanEngine.SendBus(const Msg: TBytes);
begin
  SendFrame(EncodeBusMessage(Msg));
end;

function TScanEngine.NextFrame(TimeoutMs: Cardinal; out F: TAvtFrame): Boolean;
var
  N: Integer;
begin
  if FPending.Count > 0 then
  begin
    F := FPending.Dequeue;
    Exit(True);
  end;
  Result := FParser.TryNext(F);
  if not Result then
  begin
    N := FPort.Read(FReadBuf, SizeOf(FReadBuf), TimeoutMs);
    if N > 0 then
      FParser.Push(FReadBuf, N);
    Result := FParser.TryNext(F);
  end;
  // Trace everything except the high-rate stream data.
  if Result and (FTrace <> 0) and not (FStreaming and F.IsBusMessage) then
    Log('RX  ' + F.ToHex);
end;

function TScanEngine.WaitFor(const Match: TFrameMatch; TimeoutMs: Cardinal; out Reply: TAvtFrame): Boolean;
var
  Clock: TStopwatch;
  F: TAvtFrame;
  Left: Int64;
begin
  Clock := TStopwatch.StartNew;
  repeat
    Left := Int64(TimeoutMs) - Clock.ElapsedMilliseconds;
    if Left <= 0 then
      Exit(False);
    if NextFrame(Min(Left, 50), F) then
    begin
      if Match(F) then
      begin
        Reply := F;
        Exit(True);
      end;
      HandleUnsolicited(F);
    end;
  until Terminated;
  Result := False;
end;

function TScanEngine.Exchange(const Msg: TBytes; const Match: TFrameMatch; TimeoutMs: Cardinal;
  out Reply: TClass2Message): Boolean;
var
  F: TAvtFrame;
  Found: TClass2Message;
begin
  SendBus(Msg);
  Result := WaitFor(
    function(const Fr: TAvtFrame): Boolean
    var
      M: TClass2Message;
    begin
      Result := Fr.IsBusMessage and TryParseClass2(Fr.BusMessage, M) and Match(Fr);
      if Result then
        Found := M;
    end, TimeoutMs, F);
  if Result then
    Reply := Found;
end;

procedure TScanEngine.Drain(Ms: Cardinal);
var
  F: TAvtFrame;
begin
  WaitFor(
    function(const Fr: TAvtFrame): Boolean
    begin
      Result := False;
    end, Ms, F);
end;

procedure TScanEngine.HandleUnsolicited(const F: TAvtFrame);
var
  Msg: TClass2Message;
begin
  if F.IsBusMessage and (Length(F.Data) = 1) then
    Exit; // AVT transmit status for a message we sent (01 60 = sent OK)
  if F.IsBusMessage and TryParseClass2(F.BusMessage, Msg) and (Msg.Mode = $6A) and
    (Length(Msg.Data) = 1) and (Msg.Data[0] = 0) then
    Exit; // PCM acknowledging "stop streaming" (6A 00)
  if F.IsBusMessage and TryParseClass2(F.BusMessage, Msg) then
  begin
    if FStreaming and (Msg.Mode = $6A) and (Msg.Source = AddrPcm) then
      HandleDpidData(Msg)
    else if Msg.Mode = ModeNegativeResponse then
      Warn(Format('Negative response from %s: %s', [ModuleName(Msg.Source), Msg.ToHex]))
    else if FTrace = 0 then
      Log('RX  ' + F.ToHex);
  end
  else if (F.Kind = $6) and (Length(F.Data) = 4) and (F.Data[0] = $58) then
    HandleAnalog(F)
  else if FTrace = 0 then
    Log('RX  ' + F.ToHex);
end;

{ Called whenever the loop is idle: reads incoming data, keeps the stream alive. }
procedure TScanEngine.Service;
var
  F: TAvtFrame;
begin
  if (FPort = nil) or not FPort.IsOpen then
  begin
    Sleep(20);
    Exit;
  end;
  if NextFrame(20, F) then
    HandleUnsolicited(F);
  if FStreaming then
  begin
    if FLastHeartbeat.ElapsedMilliseconds >= HeartbeatMs then
    begin
      SendBus(TesterPresentRequest);
      FLastHeartbeat := TStopwatch.StartNew;
    end;
    if (FLastData.ElapsedMilliseconds >= NoDataWarningMs) and not FNoDataWarned then
    begin
      Warn('No data from the PCM for 3 seconds. Is the key on?');
      FNoDataWarned := True;
    end;
    if (FLog <> nil) and (FLogFlush.ElapsedMilliseconds >= 1000) then
    begin
      FLog.Flush;
      FLogFlush := TStopwatch.StartNew;
    end;
  end;
end;

procedure TScanEngine.Execute;
var
  Cmd: TEngineCommand;
begin
  FLastHeartbeat := TStopwatch.StartNew;
  FLastData := TStopwatch.StartNew;
  try
    while not Terminated do
    begin
      if FCommands.PopItem(Cmd) = wrSignaled then
      begin
        TInterlocked.Exchange(FCancel, 0);
        try
          Execute_(Cmd);
        except
          on E: Exception do
          begin
            EmitText(eeError, E.Message);
            if (E is ESerialError) and (FPort <> nil) then
              DoDisconnect;
          end;
        end;
      end
      else
        try
          Service;
        except
          on E: Exception do
          begin
            EmitText(eeError, E.Message);
            DoDisconnect;
          end;
        end;
    end;
  finally
    try
      DoDisconnect;
    except
      // shutting down
    end;
  end;
end;

procedure TScanEngine.Execute_(const Cmd: TEngineCommand);
begin
  case Cmd.Kind of
    ecConnect: DoConnect(Cmd.Factory);
    ecDisconnect: DoDisconnect;
    ecReadVehicleInfo: if RequireConnected then DoReadVehicleInfo;
    ecStartScan: if RequireConnected then DoStartScan(Cmd.PidIds);
    ecStopScan: DoStopScan;
    ecStartLog: DoStartLog(Cmd.Text);
    ecStopLog: DoStopLog;
    ecPauseLog:
      begin
        FLogPaused := Cmd.Flag;
        PublishSnapshot;
      end;
    ecReadDtcs: if RequireConnected then DoReadDtcs;
    ecClearDtcs: if RequireConnected then DoClearDtcs;
    ecTestPids: if RequireConnected then DoTestPids(Cmd.PidIds);
    ecDiscoverPids: if RequireConnected then DoDiscoverPids(Cmd.Text);
    ecSendRaw: if RequireConnected then DoSendRaw(Cmd.Text);
    ecWriteVin: if RequireConnected then DoWriteVin(Cmd.Text);
    ecResetLtft: if RequireConnected then DoSimpleRequest(ResetLtftRequest, 'Reset fuel trims');
    ecCheckEngineLight:
      if RequireConnected then
        DoSimpleRequest(CheckEngineLightRequest(Cmd.Flag), IfThen(Cmd.Flag, 'Check engine light ON', 'Check engine light OFF'));
  end;
end;

function TScanEngine.RequireConnected: Boolean;
begin
  Result := (FPort <> nil) and FPort.IsOpen;
  if not Result then
    EmitText(eeError, 'Not connected');
end;

{ Connection }

procedure TScanEngine.DoConnect(const Factory: TPortFactory);
var
  F: TAvtFrame;
begin
  if FPort <> nil then
    DoDisconnect;
  FVehicle := Default(TVehicleInfo);
  FPort := Factory();
  Log('Opening %s', [FPort.Description]);
  FPort.Open;
  FParser.Clear;
  FPending.Clear;
  SetState(esBusy);

  // Same initialisation the legacy app used: E1 33 (VPW mode), B0 (version).
  SendFrame(HexToBytes('E1 33'));
  if not WaitFor(
    function(const Fr: TAvtFrame): Boolean
    begin
      Result := (Fr.Header = $91) or (Fr.Kind = $C); // AVT-841 answers 91 07
    end, 500, F) then
    Warn('No reply to AVT mode command (E1 33)');

  SendFrame(HexToBytes('B0'));
  if not WaitFor(
    function(const Fr: TAvtFrame): Boolean
    begin
      Result := (Fr.Header = $92) and (Length(Fr.Data) >= 2);
    end, 1000, F) then
  begin
    EmitText(eeError, 'No response from the AVT interface. Check the port, baud rate and power.');
    DoDisconnect;
    Exit;
  end;
  FVehicle.Firmware := BytesToHex(F.Data); // AVT-841: 92 04 13 -> '04 13'
  Log('AVT firmware %s', [FVehicle.Firmware]);
  SetState(esConnected);
  DoReadVehicleInfo;
end;

procedure TScanEngine.DoDisconnect;
begin
  if FPort = nil then
  begin
    SetState(esDisconnected);
    Exit;
  end;
  try
    if FPort.IsOpen and FStreaming then
      StopStreaming;
  except
    // port may already be gone
  end;
  DoStopLog;
  FStreaming := False;
  ForgetScan;
  FPort.Close;
  FPort := nil;
  Log('Disconnected');
  SetState(esDisconnected);
end;

procedure TScanEngine.DoReadVehicleInfo;
var
  Msg: TClass2Message;
  Ev: TEngineEvent;
  Block: Byte;
  Vin: string;
  I, Skip: Integer;
begin
  if FStreaming then
  begin
    Warn('Stop the scan before reading vehicle info');
    Exit;
  end;
  SetState(esBusy);
  try
    Vin := '';
    for Block := BlockVin1 to BlockVin3 do
    begin
      if not Exchange(ReadBlockRequest(Block),
        function(const Fr: TAvtFrame): Boolean
        var
          M: TClass2Message;
        begin
          Result := FromPcm(Fr, M) and (M.Mode = ModeReadBlock + PositiveOffset) and
            (Length(M.Data) > 0) and (M.Data[0] = Block);
        end, ReplyTimeoutMs, Msg) then
      begin
        Warn('No VIN reply from the PCM. Is the key on?');
        Vin := '';
        Break;
      end;
      Skip := IfThen(Block = BlockVin1, 2, 1); // block 1 is "01 00 c1..c5"
      for I := Skip to High(Msg.Data) do
        Vin := Vin + Chr(Msg.Data[I]);
    end;
    FVehicle.Vin := Vin;

    if Exchange(ReadBlockRequest(BlockOsid),
      function(const Fr: TAvtFrame): Boolean
      var
        M: TClass2Message;
      begin
        Result := FromPcm(Fr, M) and (M.Mode = ModeReadBlock + PositiveOffset) and
          (Length(M.Data) >= 5) and (M.Data[0] = BlockOsid);
      end, ReplyTimeoutMs, Msg) then
      FVehicle.Osid := UIntToStr((Cardinal(Msg.Data[1]) shl 24) or (Msg.Data[2] shl 16) or
        (Msg.Data[3] shl 8) or Msg.Data[4])
    else
      FVehicle.Osid := '';

    if Vin <> '' then
      Log('VIN %s, OSID %s', [FVehicle.Vin, FVehicle.Osid]);
    Ev := Default(TEngineEvent);
    Ev.Kind := eeVehicleInfo;
    Ev.Vehicle := FVehicle;
    Emit(Ev);
  finally
    SetState(esConnected);
  end;
end;

{ Scanning }

procedure TScanEngine.StopStreaming;
begin
  if FAnalogOn then
    SendFrame(EncodeAvtFrame($5, BytesOf([$59, $00])));
  FStreaming := False;
  FAnalogOn := False;
  ResetStreamSlots;
end;

{ Stop streaming and empty both PCM schedule slots. "2A 00" alone only pauses:
  the next request would revive whatever an earlier scan left in the other
  slot, flooding the bus with DPIDs nobody asked for. }
procedure TScanEngine.ResetStreamSlots;
var
  Msg: TClass2Message;
  Slot: Byte;
begin
  SendBus(StopDpidsRequest);
  Drain(100); // let in-flight stream frames arrive and be discarded
  for Slot in [StreamSlot1, StreamSlot2] do
    Exchange(ClearStreamSlotRequest(Slot),
      function(const Fr: TAvtFrame): Boolean
      var
        M: TClass2Message;
      begin
        Result := FromPcm(Fr, M) and M.IsNegativeFor(ModeRequestDpids);
      end, ReplyTimeoutMs, Msg);
  SendBus(StopDpidsRequest);
  Drain(100);
  FPending.Clear;
end;

procedure TScanEngine.DoStartScan(const Ids: TArray<Integer>);
var
  Pids: TList<TPidDef>;
  Reqs: TArray<TDpidRequest>;
  R: TDpidRequest;
  P, Ref: TPidDef;
  I, J, K: Integer;
  D: TDpidDef;
  S: TDpidSlot;
  Msg: TClass2Message;
  Ev: TEngineEvent;
  HasAnalog: Boolean;
  Vars: TArray<string>;
  Sources: TArray<Integer>;
  DpidId: Byte;
  Rejected: TList<Integer>;
  Request: TBytes;
begin
  DoStopLog;
  if FStreaming then
    StopStreaming
  else
    ResetStreamSlots;

  Pids := TList<TPidDef>.Create;
  Rejected := TList<Integer>.Create;
  try
    for I in Ids do
    begin
      P := FCatalog.FindById(I);
      if P <> nil then
        Pids.Add(P);
    end;
    FScanPids := Pids.ToArray;
  finally
    Pids.Free;
  end;

  try
    Reqs := nil;
    HasAnalog := False;
    for I := 0 to High(FScanPids) do
      case FScanPids[I].Kind of
        pkVehicle:
          begin
            R.Item := I;
            R.Pid := FScanPids[I].PidNumber;
            R.Size := FScanPids[I].DataLength;
            Reqs := Reqs + [R];
          end;
        pkAnalog: HasAnalog := True;
      end;
    if (Length(Reqs) = 0) and not HasAnalog then
    begin
      EmitText(eeError, 'Select at least one vehicle or analog PID to scan');
      Exit;
    end;

    try
      FPlan := PlanDpids(Reqs);
    except
      on E: EDpidPlanError do
      begin
        EmitText(eeError, E.Message);
        Exit;
      end;
    end;

    // Calculated PIDs: resolve %MCI% references to scan indexes once.
    SetLength(FCalcSources, Length(FScanPids));
    for I := 0 to High(FScanPids) do
    begin
      if FScanPids[I].Kind <> pkCalculated then
        Continue;
      Vars := FScanPids[I].Formula.Variables;
      if FScanPids[I].Formula.IsEmpty then
        Vars := [FScanPids[I].Mci];  // e.g. RUNTIME / LOGTIME with no formula
      SetLength(Sources, Length(Vars));
      for J := 0 to High(Vars) do
      begin
        Sources[J] := SourceMissing;
        if Vars[J] = BuiltinRuntime then
          Sources[J] := SourceRuntime
        else if Vars[J] = BuiltinLogTime then
          Sources[J] := SourceLogTime
        else
          for K := 0 to High(FScanPids) do
            if (K <> I) and SameText(FScanPids[K].Mci, Vars[J]) then
            begin
              Sources[J] := K;
              Break;
            end;
        if Sources[J] = SourceMissing then
        begin
          Ref := FCatalog.FindByMci(Vars[J]);
          if Ref <> nil then
            Warn(Format('%s needs "%s" - add it to the scan', [FScanPids[I].DisplayName, Ref.DisplayName]))
          else
            Warn(Format('%s uses %%%s%%, which is not available', [FScanPids[I].DisplayName, Vars[J]]));
        end;
      end;
      FCalcSources[I] := Copy(Sources);
    end;

    SetState(esBusy);
    FPending.Clear;
    FParser.Clear;
    FPort.Purge;
    SetLength(FRejected, Length(FScanPids));
    for I := 0 to High(FRejected) do
      FRejected[I] := False;

    // Define each DPID slot and wait for the PCM's answer before the next one.
    for D in FPlan.Dpids do
      for S in D.Slots do
      begin
        if Cancelled then
        begin
          SetState(esConnected);
          Exit;
        end;
        DpidId := D.Id;
        if Exchange(DefineDpidRequest(D.Id, S.Position, S.Size, S.Pid),
          function(const Fr: TAvtFrame): Boolean
          var
            M: TClass2Message;
          begin
            Result := FromPcm(Fr, M) and (M.IsPositiveFor(ModeDefineDpid) or M.IsNegativeFor(ModeDefineDpid));
          end, ReplyTimeoutMs, Msg) then
        begin
          if Msg.Mode = ModeNegativeResponse then
          begin
            Rejected.Add(FScanPids[S.Item].Id);
            FRejected[S.Item] := True;
            Ev := Default(TEngineEvent);
            Ev.Kind := eePidRejected;
            Ev.PidId := FScanPids[S.Item].Id;
            Ev.Text := Format('PCM rejected %s (PID $%.4x)', [FScanPids[S.Item].DisplayName, S.Pid]);
            Emit(Ev);
          end;
        end
        else
          Warn(Format('No reply defining DPID $%.2x for %s; continuing', [DpidId, FScanPids[S.Item].DisplayName]));
      end;

    SetLength(FWork, Length(FScanPids));
    for I := 0 to High(FWork) do
      FWork[I] := NaN;
    FAllMask := (Cardinal(1) shl Length(FPlan.Dpids)) - 1;
    FReceivedMask := 0;
    FCycles := 0;
    FRateCycles := 0;
    FRate := 0;
    FStray := 0;
    FScanClock := TStopwatch.StartNew;
    FRateClock := TStopwatch.StartNew;
    FLastData := TStopwatch.StartNew;
    FLastHeartbeat := TStopwatch.StartNew;
    FNoDataWarned := False;

    if HasAnalog then
    begin
      SendFrame(EncodeAvtFrame($5, BytesOf([$59, $01])));
      FAnalogOn := True;
    end;
    // Streaming must be on before the requests go out so the first data
    // frames, which can arrive before the PCM's status reply, are decoded.
    FStreaming := True;
    for Request in FPlan.StreamRequests(FStreamSpeed) do
    begin
      if Exchange(Request,
        function(const Fr: TAvtFrame): Boolean
        var
          M: TClass2Message;
        begin
          Result := FromPcm(Fr, M) and M.IsNegativeFor(ModeRequestDpids);
        end, ReplyTimeoutMs, Msg) then
      begin
        if Msg.Data[High(Msg.Data)] <> NrcStreamAccepted then
        begin
          EmitText(eeError, Format('The PCM refused the stream request (%s)', [Msg.ToHex]));
          StopStreaming;
          Exit;
        end;
      end
      else
        Warn('No status reply to the stream request; continuing');
    end;

    Log('Scanning %d PIDs in %d DPIDs (%d bytes)', [Length(FScanPids), Length(FPlan.Dpids), FPlan.TotalBytes]);
    Ev := Default(TEngineEvent);
    Ev.Kind := eeScanStarted;
    SetLength(Ev.PidIds, Length(FScanPids));
    for I := 0 to High(FScanPids) do
      Ev.PidIds[I] := FScanPids[I].Id;
    Emit(Ev);
    PublishSnapshot;
    SetState(esScanning);
  finally
    Rejected.Free;
    if not FStreaming then
      ForgetScan; // start failed or was cancelled
    if FState = esBusy then
      SetState(esConnected);
  end;
end;

procedure TScanEngine.DoStopScan;
begin
  DoStopLog;
  if FStreaming then
  begin
    StopStreaming;
    Log('Scan stopped');
  end;
  ForgetScan;
  if (FPort <> nil) and FPort.IsOpen then
    SetState(esConnected);
end;

{ Drop references into the PID catalog once a scan is over, so the UI may
  edit and reload the catalog while no scan is running. }
procedure TScanEngine.ForgetScan;
begin
  FScanPids := nil;
  FCalcSources := nil;
  FRejected := nil;
  FWork := nil;
  FPlan := Default(TDpidPlan);
end;

procedure TScanEngine.HandleDpidData(const Msg: TClass2Message);
var
  Idx, I, B: Integer;
  S: TDpidSlot;
  P: TPidDef;
  Bytes: array[0..3] of Double;
begin
  if Length(Msg.Data) < 1 + DpidDataBytes then
    Exit;
  Idx := FPlan.IndexOfDpid(Msg.Data[0]);
  if Idx < 0 then
  begin
    Inc(FStray);
    Exit;
  end;
  FLastData := TStopwatch.StartNew;
  FNoDataWarned := False;
  for S in FPlan.Dpids[Idx].Slots do
  begin
    if FRejected[S.Item] then
      Continue;
    P := FScanPids[S.Item];
    for I := 0 to 3 do
      Bytes[I] := 0;
    for I := 0 to S.Size - 1 do
    begin
      B := Msg.Data[S.Position + I]; // Data[0] is the DPID number
      Bytes[I] := B;
    end;
    FWork[S.Item] := P.Formula.Evaluate(Bytes, []);
  end;
  FReceivedMask := FReceivedMask or (Cardinal(1) shl Idx);
  if FReceivedMask = FAllMask then
  begin
    FReceivedMask := 0;
    CompleteCycle;
  end;
end;

procedure TScanEngine.HandleAnalog(const F: TAvtFrame);
var
  I: Integer;
  Inputs: array[0..0] of Double;
begin
  for I := 0 to High(FScanPids) do
    if FScanPids[I].Kind = pkAnalog then
    begin
      Inputs[0] := F.Data[FScanPids[I].AnalogChannel]; // Data[0] = $58, then channels 1..3
      FWork[I] := FScanPids[I].Formula.Evaluate(Inputs, []);
    end;
  FLastData := TStopwatch.StartNew;
  if Length(FPlan.Dpids) = 0 then
    CompleteCycle; // analog-only scan: each sample is a cycle
end;

procedure TScanEngine.ComputeCalculated;
var
  Pass, I, J: Integer;
  Src: TArray<Integer>;
  Values: TArray<Double>;
  F: TFormula;
begin
  // Two passes so a calculated PID may use another calculated PID listed after it.
  for Pass := 1 to 2 do
    for I := 0 to High(FScanPids) do
    begin
      if FScanPids[I].Kind <> pkCalculated then
        Continue;
      Src := FCalcSources[I];
      SetLength(Values, Length(Src));
      for J := 0 to High(Src) do
        case Src[J] of
          SourceRuntime: Values[J] := FScanClock.Elapsed.TotalSeconds;
          SourceLogTime:
            if FLog <> nil then
              Values[J] := FLogClock.Elapsed.TotalSeconds
            else
              Values[J] := NaN;
          SourceMissing: Values[J] := NaN;
        else
          Values[J] := FWork[Src[J]];
        end;
      F := FScanPids[I].Formula;
      if F.IsEmpty then
      begin
        if Length(Values) = 1 then
          FWork[I] := Values[0]
        else
          FWork[I] := NaN;
      end
      else
        FWork[I] := F.Evaluate([], Values);
    end;
end;

procedure TScanEngine.CompleteCycle;
begin
  ComputeCalculated;
  Inc(FCycles);
  Inc(FRateCycles);
  if FRateClock.ElapsedMilliseconds >= 1000 then
  begin
    FRate := FRateCycles * 1000 / FRateClock.ElapsedMilliseconds;
    FRateCycles := 0;
    FRateClock := TStopwatch.StartNew;
  end;
  if (FLog <> nil) and not FLogPaused then
    WriteLogRow;
  PublishSnapshot;
end;

procedure TScanEngine.PublishSnapshot;
var
  I: Integer;
  S: TLiveSnapshot;
begin
  SetLength(S.PidIds, Length(FScanPids));
  SetLength(S.Values, Length(FScanPids));
  SetLength(S.Text, Length(FScanPids));
  for I := 0 to High(FScanPids) do
  begin
    S.PidIds[I] := FScanPids[I].Id;
    if I <= High(FWork) then
      S.Values[I] := FWork[I]
    else
      S.Values[I] := NaN;
    S.Text[I] := FScanPids[I].FormatValue(S.Values[I]);
  end;
  S.Cycles := FCycles;
  S.CyclesPerSecond := FRate;
  S.LogRows := FLogRows;
  S.StrayFrames := FStray;
  S.Logging := FLog <> nil;
  S.LogPaused := FLogPaused;
  FLock.Enter;
  try
    FSnapshot := S;
  finally
    FLock.Leave;
  end;
end;

{ Logging }

function CsvField(const S: string): string;
begin
  if (Pos(',', S) > 0) or (Pos('"', S) > 0) then
    Result := '"' + StringReplace(S, '"', '""', [rfReplaceAll]) + '"'
  else
    Result := S;
end;

procedure TScanEngine.DoStartLog(const FileName: string);
var
  Header: string;
  P: TPidDef;
  Ev: TEngineEvent;
begin
  if not FStreaming then
  begin
    EmitText(eeError, 'Start a scan before logging');
    Exit;
  end;
  DoStopLog;
  FLog := TStreamWriter.Create(FileName, False, TEncoding.UTF8);
  Header := 'Time (s)';
  for P in FScanPids do
    if P.Units <> '' then
      Header := Header + ',' + CsvField(P.DisplayName + ' (' + P.Units + ')')
    else
      Header := Header + ',' + CsvField(P.DisplayName);
  FLog.WriteLine(Header);
  FLogRows := 0;
  FLogPaused := False;
  FLogClock := TStopwatch.StartNew;
  FLogFlush := TStopwatch.StartNew;
  Log('Logging to %s', [FileName]);
  Ev := Default(TEngineEvent);
  Ev.Kind := eeLogStarted;
  Ev.Text := FileName;
  Emit(Ev);
  PublishSnapshot;
end;

procedure TScanEngine.WriteLogRow;
var
  SB: TStringBuilder;
  I: Integer;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append(FormatFloat('0.000', FLogClock.Elapsed.TotalSeconds, TFormatSettings.Invariant));
    for I := 0 to High(FScanPids) do
    begin
      SB.Append(',');
      SB.Append(CsvField(FScanPids[I].FormatValue(FWork[I])));
    end;
    FLog.WriteLine(SB.ToString);
    Inc(FLogRows);
  finally
    SB.Free;
  end;
end;

procedure TScanEngine.DoStopLog;
var
  Ev: TEngineEvent;
begin
  if FLog = nil then
    Exit;
  FLog.Flush;
  FreeAndNil(FLog);
  Log('Log closed (%d rows)', [FLogRows]);
  Ev := Default(TEngineEvent);
  Ev.Kind := eeLogStopped;
  Emit(Ev);
  PublishSnapshot;
end;

{ Diagnostics }

procedure TScanEngine.DoReadDtcs;
var
  Modules: TList<Byte>;
  Dtcs: TList<TDtcEntry>;
  F: TAvtFrame;
  Msg: TClass2Message;
  Module: Byte;
  E: TDtcEntry;
  Ev: TEngineEvent;
  Clock: TStopwatch;
  Done: Boolean;
begin
  if FStreaming then
  begin
    Warn('Stop the scan before reading trouble codes');
    Exit;
  end;
  SetState(esBusy);
  Modules := TList<Byte>.Create;
  Dtcs := TList<TDtcEntry>.Create;
  try
    Log('Looking for modules...');
    SendBus(DiscoverModulesRequest);
    Clock := TStopwatch.StartNew;
    while (Clock.ElapsedMilliseconds < 800) and not Cancelled do
      if NextFrame(50, F) then
      begin
        if F.IsBusMessage and TryParseClass2(F.BusMessage, Msg) and (Msg.Mode = ModeReturnToNormal + PositiveOffset) then
        begin
          if not Modules.Contains(Msg.Source) then
          begin
            Modules.Add(Msg.Source);
            Log('  found %s ($%.2x)', [ModuleName(Msg.Source), Msg.Source]);
          end;
        end
        else
          HandleUnsolicited(F);
      end;
    if Modules.Count = 0 then
    begin
      Warn('No modules answered; trying the PCM only');
      Modules.Add(AddrPcm);
    end;

    for Module in Modules do
    begin
      if Cancelled then
        Break;
      if Exchange(ReadDtcCountRequest(Module),
        function(const Fr: TAvtFrame): Boolean
        var
          M: TClass2Message;
        begin
          Result := TryParseClass2(Fr.BusMessage, M) and (M.Source = Module) and
            ((M.Mode = ModeReadDtcs + PositiveOffset) or M.IsNegativeFor(ModeReadDtcs));
        end, 600, Msg) and (Msg.Mode <> ModeNegativeResponse) and (Length(Msg.Data) >= 2) then
        Log('%s reports %d code(s)', [ModuleName(Module), Msg.Data[1]]);

      SendBus(ReadDtcsRequest(Module));
      Clock := TStopwatch.StartNew;
      Done := False;
      while not Done and (Clock.ElapsedMilliseconds < 2000) and not Cancelled do
        if NextFrame(50, F) then
        begin
          if F.IsBusMessage and TryParseClass2(F.BusMessage, Msg) and (Msg.Source = Module) and
            (Msg.Mode = ModeReadDtcs + PositiveOffset) and (Length(Msg.Data) = 3) then
          begin
            if (Msg.Data[0] = 0) and (Msg.Data[1] = 0) then
              Done := True
            else
            begin
              E.Module := Module;
              E.Code := FormatDtc(Msg.Data[0], Msg.Data[1]);
              E.Status := Msg.Data[2];
              Dtcs.Add(E);
            end;
          end
          else
            HandleUnsolicited(F);
        end;
    end;

    Log('Trouble code read finished: %d code(s)', [Dtcs.Count]);
    Ev := Default(TEngineEvent);
    Ev.Kind := eeDtcs;
    Ev.Dtcs := Dtcs.ToArray;
    Emit(Ev);
  finally
    Modules.Free;
    Dtcs.Free;
    SetState(esConnected);
  end;
end;

procedure TScanEngine.DoClearDtcs;
var
  Msg: TBytes;
begin
  if FStreaming then
  begin
    Warn('Stop the scan before clearing trouble codes');
    Exit;
  end;
  SetState(esBusy);
  try
    for Msg in ClearDtcRequests do
    begin
      SendBus(Msg);
      Drain(150);
    end;
    Log('Clear trouble codes sent. Cycle the key and read codes again to confirm.');
  finally
    SetState(esConnected);
  end;
end;

procedure TScanEngine.DoTestPids(const Ids: TArray<Integer>);
var
  List: TList<TPidDef>;
  P: TPidDef;
  I, Timeouts, Passed, Failed: Integer;
  Msg: TClass2Message;
  Ev: TEngineEvent;
  Pid: Word;
begin
  if FStreaming then
  begin
    Warn('Stop the scan before testing PIDs');
    Exit;
  end;
  List := TList<TPidDef>.Create;
  try
    if Length(Ids) = 0 then
    begin
      for I := 0 to FCatalog.Count - 1 do
        if (FCatalog[I].Kind = pkVehicle) and FCatalog[I].Enabled then
          List.Add(FCatalog[I]);
    end
    else
      for I in Ids do
      begin
        P := FCatalog.FindById(I);
        if (P <> nil) and (P.Kind = pkVehicle) then
          List.Add(P);
      end;

    SetState(esBusy);
    Log('Testing %d PIDs...', [List.Count]);
    Timeouts := 0;
    Passed := 0;
    Failed := 0;
    for I := 0 to List.Count - 1 do
    begin
      if Cancelled then
      begin
        Warn('PID test cancelled');
        Break;
      end;
      P := List[I];
      Pid := P.PidNumber;
      Ev := Default(TEngineEvent);
      Ev.Kind := eePidTest;
      Ev.PidId := P.Id;
      Ev.Progress := I + 1;
      Ev.Total := List.Count;
      if Exchange(ReadPidRequest(Pid),
        function(const Fr: TAvtFrame): Boolean
        var
          M: TClass2Message;
        begin
          Result := FromPcm(Fr, M) and (M.Target = AddrToolPidTest) and (Length(M.Data) >= 2) and
            (((M.Mode = ModeReadPid + PositiveOffset) and (M.Data[0] = Hi(Pid)) and (M.Data[1] = Lo(Pid))) or
             M.IsNegativeFor(ModeReadPid));
        end, ReplyTimeoutMs, Msg) then
      begin
        Timeouts := 0;
        Ev.Supported := Msg.Mode <> ModeNegativeResponse;
        if Ev.Supported then
          Inc(Passed)
        else
          Inc(Failed);
        Emit(Ev);
      end
      else
      begin
        Inc(Timeouts);
        Warn(Format('No reply for %s', [P.DisplayName]));
        if Timeouts >= 3 then
        begin
          EmitText(eeError, 'The PCM stopped answering; PID test aborted');
          Break;
        end;
      end;
    end;
    Log('PID test: %d supported, %d not supported', [Passed, Failed]);
  finally
    List.Free;
    SetState(esConnected);
  end;
end;

{ Asks the PCM for every PID in Ranges (read-only mode $22) and reports each
  one it answers. Can be stopped with Cancel. }
procedure TScanEngine.DoDiscoverPids(const Ranges: string);
var
  List: TArray<TPidRange>;
  R: TPidRange;
  Pid, Done, Total, Found, Timeouts: Integer;
  P: Word;
  Msg: TClass2Message;
  Ev: TEngineEvent;
  Clock: TStopwatch;
begin
  if FStreaming then
  begin
    Warn('Stop the scan before searching for PIDs');
    Exit;
  end;
  try
    List := ParsePidRanges(Ranges);
  except
    on E: EConvertError do
    begin
      EmitText(eeError, E.Message);
      Exit;
    end;
  end;
  Total := 0;
  for R in List do
    Inc(Total, R.Count);

  SetState(esBusy);
  Clock := TStopwatch.StartNew;
  Done := 0;
  Found := 0;
  Timeouts := 0;
  try
    Log('Searching %d PIDs (%s)...', [Total, Ranges]);
    for R in List do
      for Pid := R.First to R.Last do
      begin
        if Cancelled then
        begin
          Warn('PID search stopped');
          Exit;
        end;
        P := Pid;
        if Exchange(ReadPidRequest(P),
          function(const Fr: TAvtFrame): Boolean
          var
            M: TClass2Message;
          begin
            Result := FromPcm(Fr, M) and (M.Target = AddrToolPidTest) and (Length(M.Data) >= 2) and
              (((M.Mode = ModeReadPid + PositiveOffset) and (M.Data[0] = Hi(P)) and (M.Data[1] = Lo(P))) or
               M.IsNegativeFor(ModeReadPid));
          end, 300, Msg) then
        begin
          Timeouts := 0;
          if Msg.Mode <> ModeNegativeResponse then
          begin
            Inc(Found);
            Ev := Default(TEngineEvent);
            Ev.Kind := eePidFound;
            Ev.PidId := P;
            Ev.DataBytes := Length(Msg.Data) - 2;
            Ev.Raw := BytesToHex(Copy(Msg.Data, 2, MaxInt));
            Emit(Ev);
          end;
        end
        else
        begin
          Inc(Timeouts);
          if Timeouts >= 5 then
          begin
            EmitText(eeError, Format('The PCM stopped answering at PID $%.4x; search aborted', [P]));
            Exit;
          end;
        end;
        Inc(Done);
        if (Done mod 32 = 0) or (Done = Total) then
        begin
          Ev := Default(TEngineEvent);
          Ev.Kind := eePidSearchProgress;
          Ev.Progress := Done;
          Ev.Total := Total;
          Ev.PidId := P;
          Emit(Ev);
        end;
      end;
    Log('PID search done: %d of %d answered (%.0f s)', [Found, Total, Clock.Elapsed.TotalSeconds]);
  finally
    Ev := Default(TEngineEvent);
    Ev.Kind := eePidSearchDone;
    Ev.Progress := Done;
    Ev.Total := Total;
    Emit(Ev);
    SetState(esConnected);
  end;
end;

procedure TScanEngine.DoSendRaw(const Hex: string);
var
  Frame: TBytes;
  TraceWas: Integer;
begin
  if FStreaming then
  begin
    Warn('Stop the scan before sending raw frames');
    Exit;
  end;
  Frame := HexToBytes(Hex);
  if Length(Frame) = 0 then
    Exit;
  SetState(esBusy);
  TraceWas := TInterlocked.Exchange(FTrace, 1);
  try
    SendFrame(Frame);
    Drain(1000);
  finally
    TInterlocked.Exchange(FTrace, TraceWas);
    SetState(esConnected);
  end;
end;

procedure TScanEngine.DoWriteVin(const Vin: string);
var
  Msg: TBytes;
  Reply: TClass2Message;
begin
  if FStreaming then
  begin
    Warn('Stop the scan before writing the VIN');
    Exit;
  end;
  SetState(esBusy);
  try
    for Msg in WriteVinRequests(Vin) do
      if not Exchange(Msg,
        function(const Fr: TAvtFrame): Boolean
        var
          M: TClass2Message;
        begin
          Result := FromPcm(Fr, M) and (M.IsPositiveFor(ModeWriteBlock) or M.IsNegativeFor(ModeWriteBlock));
        end, 1000, Reply) or (Reply.Mode = ModeNegativeResponse) then
      begin
        EmitText(eeError, 'The PCM did not accept the VIN write');
        Exit;
      end;
    Log('VIN written. Turn the key off for 15 seconds, then read vehicle info to confirm.');
  finally
    SetState(esConnected);
  end;
end;

procedure TScanEngine.DoSimpleRequest(const Msg: TBytes; const What: string);
var
  Reply: TClass2Message;
  Mode: Byte;
begin
  if FStreaming then
  begin
    Warn('Stop the scan first');
    Exit;
  end;
  Mode := Msg[3];
  SetState(esBusy);
  try
    if Exchange(Msg,
      function(const Fr: TAvtFrame): Boolean
      var
        M: TClass2Message;
      begin
        Result := FromPcm(Fr, M) and (M.IsPositiveFor(Mode) or M.IsNegativeFor(Mode));
      end, 1000, Reply) then
    begin
      if Reply.Mode = ModeNegativeResponse then
        Warn(What + ': rejected by the PCM')
      else
        Log(What + ': OK');
    end
    else
      Warn(What + ': no reply');
  finally
    SetState(esConnected);
  end;
end;

end.
