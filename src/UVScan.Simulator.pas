unit UVScan.Simulator;

{ Simulated AVT interface + GM PCM, exposed as an ISerialPort.
  Lets the app and the tests run the full protocol without hardware.
  Used only from the engine thread, like a real port. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Diagnostics,
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
  end;

const
  SimulatedVin = '1GCSIMULATOR00001';
  SimulatedOsid = 12596629;

implementation

constructor TSimulatedAvt.Create;
begin
  inherited;
  FParser := TAvtFrameParser.Create;
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
            Msg.Data[0], Msg.Data[1]]), PidValue(Pid, 1)));
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
      Reply($10, ModeDeviceControl + PositiveOffset, [Msg.Data[0]]);
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
      S.NextMs := FClock.ElapsedMilliseconds + 10 * (I + 1) + 5 * Slot;
      FStreaming.Add(S);
    end;
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
var
  T, Raw: Double;
  N: Int64;
  I: Integer;
begin
  T := Seconds;
  case Pid of
    $000C: Raw := (800 + 2600 * (0.5 + 0.5 * Sin(T * 0.6))) * 4;  // engine speed, rpm * 4
    $0005: Raw := 88 + 4 * Sin(T * 0.05) + 40;                      // coolant, C + 40
    $000F: Raw := 30 + 3 * Sin(T * 0.03) + 40;                      // intake air, C + 40
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
    A := 0.5 + 0.4 * Sin(Seconds * 0.8);
    Emit(BytesOf([$64, $58, Byte(Round(A * 255)), Byte(Round((1 - A) * 255)), 128]));
    FNextAnalogMs := NowMs + 100;
  end;
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
