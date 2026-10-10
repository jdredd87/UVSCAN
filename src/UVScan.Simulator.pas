unit UVScan.Simulator;

{ Simulated AVT interface + GM PCM, exposed as an ISerialPort.
  Lets the app and the tests run the full protocol without hardware.
  Used only from the engine thread, like a real port. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Diagnostics, System.Net.Socket,
  System.Generics.Collections, UVScan.Serial, UVScan.Avt, UVScan.Class2, UVScan.Hex;

type
  TSimSlot = record
    Pid: Word;
    Position: Byte;
    Size: Byte;
  end;

  TSimStream = record
    Id: Byte;
    IntervalMs: Integer;
    NextMs: Int64;
  end;

  TSimulatedAvt = class(TInterfacedObject, ISerialPort)
  private
    FOpen: Boolean;
    FParser: TAvtFrameParser;
    FOut: TBytes;
    FClock: TStopwatch;
    FVin: string;
    FDpids: TDictionary<Byte, TList<TSimSlot>>;
    FStreaming: TList<TSimStream>;   // active DPIDs (both slots)
    FSlots: array[1..2] of TArray<Byte>;
    FSlotSpeed: array[1..2] of Integer;
    FPaused: Boolean;
    FAnalogOn: Boolean;
    FNextAnalogMs: Int64;
    FRejectedPids: TList<Word>;
    FResetPending: Boolean;
    procedure RebuildStreams;
    procedure Emit(const Frame: TBytes);
    procedure EmitBus(const Msg: TBytes);
    procedure Reply(Source, Mode: Byte; const Data: array of Byte);
    procedure HandleHostFrame(const F: TAvtFrame);
    procedure HandleBusMessage(const Msg: TClass2Message);
    procedure GenerateDue;
    function Seconds: Double;
    function PidValue(Pid: Word; Size: Byte): TBytes;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Open;
    procedure Close;
    function IsOpen: Boolean;
    function Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
    procedure Write(const Data: TBytes);
    procedure Purge;
    function Description: string;
    { PIDs the simulated PCM refuses (negative response to $22 and $2C). }
    property RejectedPids: TList<Word> read FRejectedPids;
    { DPIDs currently being streamed. }
    function ActiveDpids: TArray<Byte>;
    { The PCM resets, as when the engine is cranked: it forgets its DPIDs and
      stops streaming. Any thread (it happens on the next read). }
    procedure ResetPcm;
    { What the simulated PCM answers for Pid (Size bytes) T seconds into its
      drive: believable values, the inverse of the default catalog's formula,
      for the PIDs it knows; a slow sweep of the whole range for the rest. }
    class function RawValue(Pid: Word; Size: Byte; T: Double): TBytes; static;
  end;

  { The simulator on the network, as an AVT with an Ethernet port: each
    connection to Port gets a simulated AVT and PCM of its own. For trying
    the network connection without the hardware (tools\UVScanSimServer, the
    tests). }
  TSimulatorServer = class
  private
    FListener: System.Net.Socket.TSocket;
    FPort: Word;
    FStop: Boolean;
    FThreads: TList<TThread>;
    FOnLog: TProc<string>;
    procedure Log(const S: string);
    procedure Serve(Client: System.Net.Socket.TSocket);
  public
    { Listens on Address (default all of this machine's) and Port (0: one
      the system picks; see Port). OnLog (any thread) gets connections and
      disconnections. }
    constructor Create(Port: Word; const Address: string = '0.0.0.0'; const OnLog: TProc<string> = nil);
    destructor Destroy; override;
    property Port: Word read FPort;
  end;

const
  SimulatedVin = '1GCSIMULATOR00001';
  SimulatedOsid = 12596629;

implementation

constructor TSimulatedAvt.Create;
begin
  inherited;
  FParser := TAvtFrameParser.Create;
  FParser.HostSide := True; // it reads what the host sends
  FDpids := TObjectDictionary<Byte, TList<TSimSlot>>.Create([doOwnsValues]);
  FStreaming := TList<TSimStream>.Create;
  FRejectedPids := TList<Word>.Create;
  FRejectedPids.Add($1108); // Boost Solenoid PWM: shows how rejections are handled
  FVin := SimulatedVin;
  FClock := TStopwatch.StartNew;
end;

destructor TSimulatedAvt.Destroy;
begin
  FParser.Free;
  FDpids.Free;
  FStreaming.Free;
  FRejectedPids.Free;
  inherited;
end;

function TSimulatedAvt.Description: string;
begin
  Result := 'Simulator';
end;

procedure TSimulatedAvt.Open;
begin
  FOpen := True;
end;

procedure TSimulatedAvt.Close;
begin
  FOpen := False;
end;

function TSimulatedAvt.IsOpen: Boolean;
begin
  Result := FOpen;
end;

procedure TSimulatedAvt.Purge;
begin
  FOut := nil;
  FParser.Clear;
end;

function TSimulatedAvt.Seconds: Double;
begin
  Result := FClock.ElapsedMilliseconds / 1000;
end;

procedure TSimulatedAvt.Emit(const Frame: TBytes);
begin
  FOut := ConcatBytes(FOut, Frame);
end;

procedure TSimulatedAvt.EmitBus(const Msg: TBytes);
var
  WithStatus: TBytes;
begin
  WithStatus := ConcatBytes(BytesOf([$00]), Msg);
  if Length(WithStatus) <= 15 then
    Emit(EncodeAvtFrame(AvtKindBus, WithStatus))
  else
    Emit(ConcatBytes(BytesOf([AvtExtendedHeader, Length(WithStatus)]), WithStatus));
end;

procedure TSimulatedAvt.Reply(Source, Mode: Byte; const Data: array of Byte);
begin
  EmitBus(ConcatBytes(BytesOf([PriorityRequest, AddrTool, Source, Mode]), BytesOf(Data)));
end;

procedure TSimulatedAvt.Write(const Data: TBytes);
var
  F: TAvtFrame;
begin
  if not FOpen then
    raise ESerialError.Create('Simulator is not open');
  FParser.Push(Data);
  while FParser.TryNext(F) do
    HandleHostFrame(F);
end;

procedure TSimulatedAvt.HandleHostFrame(const F: TAvtFrame);
var
  Msg: TClass2Message;
begin
  case F.Header of
    $E1: Emit(HexToBytes('91 07'));
    $B0: Emit(HexToBytes('92 04 0E'));
    $F1: Emit(HexToBytes('91 07'));
    $52:
      if (Length(F.Data) = 2) and (F.Data[0] = $59) then
      begin
        FAnalogOn := F.Data[1] = $01;
        FNextAnalogMs := FClock.ElapsedMilliseconds;
      end;
  else
    // Host bus messages carry no status byte. The AVT confirms each one with 01 60.
    if F.IsBusMessage and TryParseClass2(F.Data, Msg) then
    begin
      Emit(HexToBytes('01 60'));
      HandleBusMessage(Msg);
    end;
  end;
end;

function AsciiOf(const S: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I - 1] := Ord(S[I]);
end;

function AsciiToString(const B: TBytes; Start, Count: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := Start to Start + Count - 1 do
    if I < Length(B) then
      Result := Result + Chr(B[I]);
end;

{ How many data bytes a mode $22 read of Pid answers with: the SAE sizes
  (engine speed and air flow are 2 bytes), and a mix for the GM PIDs, as a
  real PCM's PID search shows. }
function ReadSize(Pid: Word): Byte;
begin
  case Pid of
    $000C, $0010:
      Result := 2;
    $1100..$13FF:
      if Pid and $0F in [$0, $4] then
        Result := 2
      else
        Result := 1;
  else
    Result := 1;
  end;
end;

procedure TSimulatedAvt.HandleBusMessage(const Msg: TClass2Message);
var
  Pid: Word;
  Slot: TSimSlot;
  Slots: TList<TSimSlot>;
  I: Integer;
  Id: Byte;
  Vin: TBytes;
  SlotNo: Byte;
begin
  if Msg.Mode = ModeTesterPresent then
    Exit;

  if Msg.Target = AddrAllNodes then
  begin
    if Msg.Mode = ModeReturnToNormal then
    begin
      Reply($10, $60, []);
      Reply($40, $60, []);
      Reply($60, $60, []);
    end;
    Exit;
  end;

  // Modules other than the PCM: only DTC reads.
  if Msg.Target <> AddrPcm then
  begin
    if Msg.Mode = ModeReadDtcs then
    begin
      if Msg.Data[2] = $FF then // 19 08 FF FF = count, 19 08 FF 00 = list
        Reply(Msg.Target, $59, [$08, $00])
      else
        Reply(Msg.Target, $59, [$00, $00, $FF]);
    end;
    Exit;
  end;

  case Msg.Mode of
    ModeReadBlock:
      begin
        Vin := AsciiOf(FVin);
        case Msg.Data[0] of
          BlockVin1: EmitBus(ConcatBytes(HexToBytes('6C F1 10 7C 01 00'), Copy(Vin, 0, 5)));
          BlockVin2: EmitBus(ConcatBytes(HexToBytes('6C F1 10 7C 02'), Copy(Vin, 5, 6)));
          BlockVin3: EmitBus(ConcatBytes(HexToBytes('6C F1 10 7C 03'), Copy(Vin, 11, 6)));
          BlockOsid: Reply($10, $7C, [$0A, Byte(SimulatedOsid shr 24), Byte(SimulatedOsid shr 16),
            Byte(SimulatedOsid shr 8), Byte(SimulatedOsid)]);
        else
          Reply($10, ModeNegativeResponse, [ModeReadBlock, Msg.Data[0], $12]);
        end;
      end;

    ModeWriteBlock:
      begin
        case Msg.Data[0] of
          BlockVin1: FVin := AsciiToString(Msg.Data, 2, 5) + Copy(FVin, 6, 12);
          BlockVin2: FVin := Copy(FVin, 1, 5) + AsciiToString(Msg.Data, 1, 6) + Copy(FVin, 12, 6);
          BlockVin3: FVin := Copy(FVin, 1, 11) + AsciiToString(Msg.Data, 1, 6);
        end;
        Reply($10, ModeWriteBlock + PositiveOffset, [Msg.Data[0]]);
      end;

    ModeReadPid:
      begin
        Pid := (Msg.Data[0] shl 8) or Msg.Data[1];
        // Answers SAE $0004-$0011 and GM $1100-$13FF except every 8th, like a real PCM answers some.
        if FRejectedPids.Contains(Pid) or
          not ((Pid in [$04..$11]) or ((Pid >= $1100) and (Pid <= $13FF) and (Pid mod 8 <> 7))) then
          EmitBus(BytesOf([PriorityRequest, Msg.Source, $10, ModeNegativeResponse, ModeReadPid, Msg.Data[0], Msg.Data[1], $31]))
        else
          EmitBus(ConcatBytes(BytesOf([PriorityRequest, Msg.Source, $10, ModeReadPid + PositiveOffset,
            Msg.Data[0], Msg.Data[1]]), PidValue(Pid, ReadSize(Pid))));
      end;

    ModeDefineDpid:
      begin
        Id := Msg.Data[0];
        Slot.Position := (Msg.Data[1] shr 3) and $07;
        Slot.Size := Msg.Data[1] and $07;
        Slot.Pid := (Msg.Data[2] shl 8) or Msg.Data[3];
        if FRejectedPids.Contains(Slot.Pid) then
        begin
          Reply($10, ModeNegativeResponse, [ModeDefineDpid, Id, $31]);
          Exit;
        end;
        if not FDpids.TryGetValue(Id, Slots) then
        begin
          Slots := TList<TSimSlot>.Create;
          FDpids.Add(Id, Slots);
        end;
        for I := Slots.Count - 1 downto 0 do
          if Slots[I].Position = Slot.Position then
            Slots.Delete(I);
        Slots.Add(Slot);
        Reply($10, ModeDefineDpid + PositiveOffset, [Id]);
      end;

    ModeRequestDpids:
      begin
        // Behaves like the bench PCM: 2A 00 pauses (6A 00). Otherwise exactly
        // 4 DPID entries, slot $1x/$2x and speed 2..4 are required, answered
        // with 7F ... 23. A request replaces its slot's list and resumes the
        // other slot's list, which is how stale DPIDs come back to life.
        if Msg.Data[0] = $00 then
        begin
          FPaused := True;
          RebuildStreams;
          Reply($10, ModeRequestDpids + PositiveOffset, [$00]);
          Exit;
        end;
        SlotNo := Msg.Data[0] shr 4;
        if (Length(Msg.Data) <> 1 + DpidsPerRequest) or not (SlotNo in [1, 2]) or
          not ((Msg.Data[0] and $0F) in [2..4]) then
        begin
          EmitBus(ConcatBytes(BytesOf([PriorityRequest, AddrTool, $10, ModeNegativeResponse, ModeRequestDpids]),
            ConcatBytes(Msg.Data, BytesOf([NrcInvalidFormat]))));
          Exit;
        end;
        EmitBus(ConcatBytes(BytesOf([PriorityRequest, AddrTool, $10, ModeNegativeResponse, ModeRequestDpids]),
          ConcatBytes(Msg.Data, BytesOf([NrcStreamAccepted]))));
        FSlots[SlotNo] := nil;
        for I := 1 to High(Msg.Data) do
          if (Msg.Data[I] <> $00) and FDpids.ContainsKey(Msg.Data[I]) then
            FSlots[SlotNo] := FSlots[SlotNo] + [Msg.Data[I]];
        case Msg.Data[0] and $0F of
          4: FSlotSpeed[SlotNo] := 200;  // measured on a bench PCM
          3: FSlotSpeed[SlotNo] := 375;
        else
          FSlotSpeed[SlotNo] := 667;
        end;
        FPaused := False;
        RebuildStreams;
      end;

    ModeReadDtcs:
      if Msg.Data[2] = $FF then
        Reply($10, $59, [$08, $02])
      else
      begin
        Reply($10, $59, [$03, $00, $AF]);  // P0300
        Reply($10, $59, [$01, $71, $AF]);  // P0171
        Reply($10, $59, [$00, $00, $FF]);  // end of list
      end;

    ModeClearDtcs, ModeReturnToNormal, $10:
      Reply($10, Msg.Mode + PositiveOffset, []);

    ModeDeviceControl:
      // As the bench PCM (OS 9389759): CPIDs $01-$04, exactly 6 control bytes.
      if Length(Msg.Data) <> 7 then
        Reply($10, ModeNegativeResponse, ConcatBytes(ConcatBytes(BytesOf([ModeDeviceControl]), Copy(Msg.Data, 0, 5)), BytesOf([$12])))
      else if not (Msg.Data[0] in [$01..$04]) then
        Reply($10, ModeNegativeResponse, ConcatBytes(ConcatBytes(BytesOf([ModeDeviceControl]), Copy(Msg.Data, 0, 5)), BytesOf([$31])))
      else
        Reply($10, ModeDeviceControl + PositiveOffset, [Msg.Data[0], $E1]);
  else
    Reply($10, ModeNegativeResponse, [Msg.Mode, $11]);
  end;
end;

procedure TSimulatedAvt.RebuildStreams;
var
  Slot, I: Integer;
  S: TSimStream;
begin
  FStreaming.Clear;
  if FPaused then
    Exit;
  for Slot := 1 to 2 do
    for I := 0 to High(FSlots[Slot]) do
    begin
      S.Id := FSlots[Slot][I];
      S.IntervalMs := FSlotSpeed[Slot];
      // Slot 2 half an interval after slot 1, as the PCM spreads them: with
      // the same DPIDs in both, updates come evenly (not in pairs 5 ms apart).
      S.NextMs := FClock.ElapsedMilliseconds + 10 * (I + 1) + 5 + (Slot - 1) * (S.IntervalMs div 2);
      FStreaming.Add(S);
    end;
end;

procedure TSimulatedAvt.ResetPcm;
begin
  FResetPending := True;
end;

function TSimulatedAvt.ActiveDpids: TArray<Byte>;
var
  S: TSimStream;
begin
  Result := nil;
  for S in FStreaming do
    Result := Result + [S.Id];
end;

function TSimulatedAvt.PidValue(Pid: Word; Size: Byte): TBytes;
begin
  Result := RawValue(Pid, Size, Seconds);
end;

{ The drive behind the values: the pedal (0..1) goes down now and then,
  sometimes hard, and comes back up. }
function SimThrottle(T: Double): Double;
begin
  Result := EnsureRange(0.04 + 0.7 * Power(Max(0, Sin(T * 0.31)), 3) + 0.2 * Power(Max(0, Sin(T * 1.13 + 1)), 6), 0, 1);
end;

class function TSimulatedAvt.RawValue(Pid: Word; Size: Byte; T: Double): TBytes;
const
  Ratios: array[1..4] of Double = (3.06, 1.63, 1.0, 0.7); // a 4L60-E
var
  Thr, Mph, Rpm, Maf, Map, Knock, O2, Oss, Raw: Double;
  Gear: Integer;
  N: Int64;
  I: Integer;
begin
  Thr := SimThrottle(T - 0.4); // the engine follows the pedal a moment later
  Mph := 35 + 25 * Sin(T * 0.045) + 12 * SimThrottle(T - 3);
  if Mph < 14 then
    Gear := 1
  else if Mph < 28 then
    Gear := 2
  else if Mph < 42 then
    Gear := 3
  else
    Gear := 4;
  Oss := Mph * 41; // 3.42 axle, 28 in tyres
  Rpm := 700 + Oss * Ratios[Gear] * 0.68 + 1500 * Thr;
  Maf := 2.5 + Rpm / 1000 * (1.5 + 30 * Thr);
  Map := 28 + 70 * Thr;
  if Thr > 0.65 then
    Knock := 4 * (Thr - 0.65) / 0.35 * (0.5 + 0.5 * Sin(T * 3))
  else
    Knock := 0;
  if Thr > 0.7 then
    O2 := 880 // power enrichment: rich
  else
    O2 := 450 + 380 * Sin(T * 7.5); // closed loop: switching
  case Pid of
    $000C: Raw := Rpm * 4;
    $0005: Raw := 88 + 4 * Sin(T * 0.05) + 40;           // coolant, C + 40
    $000F: Raw := 30 + 3 * Sin(T * 0.03) + 40;           // intake air
    $1940: Raw := 82 + 3 * Sin(T * 0.02) + 40;           // transmission fluid
    $0004: Raw := (18 + 75 * Thr) * 2.55;                // calculated load %
    $0011: Raw := Thr * 100 * 2.55;                      // throttle %
    $1143: Raw := (0.6 + 3.8 * Thr) * 51;                // throttle sensor V
    $0006: Raw := 128 + 4 * Sin(T * 1.9) * 1.28;         // short term trim %
    $0007: Raw := 128 + (2.3 + 0.5 * Sin(T * 0.02)) * 1.28;
    $000B: Raw := Map;
    $000D: Raw := Mph * 1.609;
    $000E: Raw := (14 + 22 * (1 - Thr) - Knock + 64) * 2; // spark advance
    $0010: Raw := Maf * 100;                             // g/s
    $1250: Raw := (1500 + 75 * Maf) * 2.048;             // MAF frequency, Hz
    $1141: Raw := (14.2 + 0.15 * Sin(T * 0.5)) * 10;     // ignition volts
    $1145: Raw := O2 / 4.34;                             // mV
    $1146: Raw := (640 + 40 * Sin(T * 0.7)) / 4.34;
    $0014, $0015:                                        // SAE O2: volts in the first byte
      begin
        if Pid = $0014 then
          Raw := O2 / 1000 / 0.005
        else
          Raw := (640 + 40 * Sin(T * 0.7)) / 1000 / 0.005;
        if Size = 2 then
          Raw := Round(Raw) * 256 + 255;
      end;
    $0003: if Size = 2 then Raw := 2 * 256 else Raw := 2; // closed loop
    $11A6: Raw := Knock * 256 / 22.5;
    $1193: Raw := (1.8 + 9 * Thr) * 65.535;              // injector ms
    $119E: Raw := IfThen(Thr > 0.7, 12.6, 14.7) * 10;    // commanded AFR
    $199A: Raw := Gear;
    $19A1: Raw := Ratios[Gear] / 0.01563;
    $1192: Raw := 700 / 12.5;                            // desired idle
    $1172: Raw := 38 + 6 * Sin(T * 0.4);                 // IAC counts
    $1190: Raw := Min(20, Rpm / 400 + Map / 20);         // fuel trim cell
    $1941: Raw := (Oss * Ratios[Gear] + IfThen(Gear = 4, 30, 120)) / 0.125; // input speed
    $1942: Raw := Oss / 0.125;
    $1991: Raw := IfThen(Gear = 4, 25 + 30 * Thr, 150) / 0.125; // TCC slip
    $1970: Raw := IfThen(Gear = 4, 100, 0) * 2.55;       // TCC duty
    $1972: Raw := (30 + 20 * Thr) * 2.55;                // pressure control duty
    $199E, $199F: Raw := (0.6 + 0.3 * Thr) / 0.0195;     // pressure control amps
    $1992..$1995: Raw := 0.45 * 40;                      // shift times, s
    $1997..$1999: Raw := 0.05 * 40;
    $12C5: Raw := 62 / 0.01953125;                       // fuel level %
    $19DE: Raw := (30 + 330 * Thr) / 0.33895;            // torque Nm
    $11A1: Raw := T;                                     // run time s
    $119F: Raw := 72 * 2.55;                             // oil life %
    $002C: Raw := 10 * (1 - Thr) * 2.55;                 // commanded EGR %
    $002D: Raw := 100 / 0.78125;                         // EGR error 0 %
    $11C1: Raw := 128;
    $160C: Raw := 100 * 256 / 5;                         // traction: all the torque
    $1175: Raw := 0;
    // nothing wrong: no misfires, injector or pump faults
    $1200..$1208, $11EA, $11EB, $11F8, $11F9, $1227, $1228, $1114, $1115, $111C..$1121, $112B..$1131:
      Raw := 0;
    // switches and lamps
    $1100: Raw := 4;                                     // range: drive
    $1101:
      begin
        Raw := 0;
        if (Thr < 0.05) and (Sin(T * 0.31) < -0.5) then
          Raw := Raw + 1;                                // brake
        if Gear in [1, 4] then
          Raw := Raw + $20;                              // shift solenoid A
        if Gear in [1, 2] then
          Raw := Raw + $40;                              // shift solenoid B
      end;
    $1102: Raw := $20;                                   // cruise enabled
    $1103: Raw := IfThen(Sin(T * 0.05) > 0.5, $40, 0);   // low speed fans when hot
    $1104: Raw := $20;                                   // fuel pump relay on
    $1105: Raw := IfThen(Thr > 0.7, 0, 8);               // closed loop
    $1106: Raw := IfThen(Thr > 0.7, 4, IfThen((Thr < 0.05) and (Mph > 25), 8, 0)); // enrichment, decel
    $1107: Raw := 2;                                     // cam signal present
    $110C: Raw := 0;
  else
    Raw := (0.5 + 0.45 * Sin(T * (0.2 + (Pid mod 7) * 0.1) + Pid)) * (Power(256, Size) - 1);
  end;
  N := Max(0, Min(Round(Raw), Round(Power(256, Size)) - 1));
  SetLength(Result, Size);
  for I := Size - 1 downto 0 do
  begin
    Result[I] := N and $FF;
    N := N shr 8;
  end;
end;

procedure TSimulatedAvt.GenerateDue;
var
  NowMs: Int64;
  Id: Byte;
  Data: TBytes;
  Slot: TSimSlot;
  V: TBytes;
  A: Double;
  I: Integer;
  Stream: TSimStream;
begin
  if FResetPending then
  begin
    FResetPending := False;
    FDpids.Clear;
    FSlots[1] := nil;
    FSlots[2] := nil;
    FPaused := False;
    FStreaming.Clear;
  end;
  NowMs := FClock.ElapsedMilliseconds;
  for I := 0 to FStreaming.Count - 1 do
  begin
    Stream := FStreaming[I];
    if NowMs < Stream.NextMs then
      Continue;
    Id := Stream.Id;
    Stream.NextMs := NowMs + Stream.IntervalMs;
    FStreaming[I] := Stream;
    SetLength(Data, DpidDataBytes);
    FillChar(Data[0], Length(Data), 0);
    for Slot in FDpids[Id] do
    begin
      V := PidValue(Slot.Pid, Slot.Size);
      if Slot.Position + Slot.Size - 1 <= DpidDataBytes then
        Move(V[0], Data[Slot.Position - 1], Slot.Size);
    end;
    EmitBus(ConcatBytes(BytesOf([PriorityRequest, AddrTool, AddrPcm, $6A, Id]), Data));
  end;
  if FAnalogOn and (NowMs >= FNextAnalogMs) then
  begin
    // A wideband (AFR about 14.6) and a pressure sender (fuel, about 43 PSI)
    // on the first two inputs, as the default catalog's AFR and pressure PIDs read them.
    A := Seconds;
    Emit(BytesOf([$64, $58, Byte(Round((2.4 + 0.25 * Sin(A * 1.1)) * 51)),
      Byte(Round((1.65 + 0.1 * Sin(A * 0.4)) * 51)), 128]));
    FNextAnalogMs := NowMs + 100;
  end;
end;

{ TSimulatorServer }

constructor TSimulatorServer.Create(Port: Word; const Address: string; const OnLog: TProc<string>);
var
  T: TThread;
begin
  inherited Create;
  FOnLog := OnLog;
  FThreads := TList<TThread>.Create;
  FListener := System.Net.Socket.TSocket.Create(TSocketType.TCP);
  FListener.Listen(Address, '', Port);
  FPort := FListener.LocalPort;
  T := TThread.CreateAnonymousThread(
    procedure
    var
      Client: System.Net.Socket.TSocket;
    begin
      while not FStop do
      begin
        try
          Client := FListener.Accept(200);
        except
          Client := nil;
          if not FStop then
            Sleep(200);
        end;
        if Client <> nil then
          Serve(Client);
      end;
    end);
  T.FreeOnTerminate := False;
  FThreads.Add(T);
  T.Start;
end;

destructor TSimulatorServer.Destroy;
var
  T: TThread;
begin
  FStop := True;
  // the accept thread first (it adds the others), then the connections
  for T in FThreads.ToArray do
    T.WaitFor;
  for T in FThreads do
  begin
    T.WaitFor;
    T.Free;
  end;
  FThreads.Free;
  FreeSocket(FListener);
  inherited;
end;

procedure TSimulatorServer.Log(const S: string);
begin
  if Assigned(FOnLog) then
    FOnLog(S);
end;

{ One connection: the bytes from the client go to its own simulated AVT,
  the AVT's go back, until either end stops. }
procedure TSimulatorServer.Serve(Client: System.Net.Socket.TSocket);
var
  T: TThread;
begin
  T := TThread.CreateAnonymousThread(
    procedure
    var
      Avt: ISerialPort;
      Buf: array[0..4095] of Byte;
      N: Integer;
      Who: string;
      Data: TBytes;
    begin
      Who := Client.RemoteAddress;
      Log('Connected: ' + Who);
      Avt := TSimulatedAvt.Create;
      Avt.Open;
      try
        try
          while not FStop do
          begin
            if SocketReadable(Client, 2) then
            begin
              N := SocketReceive(Client, Buf, SizeOf(Buf));
              if N <= 0 then
                Break; // the client closed
              SetLength(Data, N);
              Move(Buf[0], Data[0], N);
              Avt.Write(Data);
            end;
            N := Avt.Read(Buf, SizeOf(Buf), 0);
            if (N > 0) and (SocketSend(Client, Buf, N) <= 0) then
              Break;
          end;
        except
          // the client went away mid-send
        end;
      finally
        FreeSocket(Client);
        Log('Disconnected: ' + Who);
      end;
    end);
  T.FreeOnTerminate := False;
  FThreads.Add(T);
  T.Start;
end;

function TSimulatedAvt.Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
var
  Deadline: Int64;
begin
  if not FOpen then
    raise ESerialError.Create('Simulator is not open');
  Deadline := FClock.ElapsedMilliseconds + TimeoutMs;
  repeat
    GenerateDue;
    if Length(FOut) > 0 then
    begin
      Result := Min(Count, Length(FOut));
      Move(FOut[0], Buffer, Result);
      FOut := Copy(FOut, Result, MaxInt);
      Exit;
    end;
    if FClock.ElapsedMilliseconds >= Deadline then
      Exit(0);
    Sleep(1);
  until False;
end;

end.
