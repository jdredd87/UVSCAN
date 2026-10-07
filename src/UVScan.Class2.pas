unit UVScan.Class2;

{ GM Class 2 (J1850 VPW) messages used by UVSCAN.

  Message layout: <priority> <target> <source> <mode> <data...>
  Requests use priority $6C, the PCM is $10, the tool is $F1 ($F0 is used
  for single-PID reads so their replies can be told apart), $FE = all nodes.
  Positive responses come back as mode + $40; negative as $7F <mode> ... }

interface

uses
  System.SysUtils, UVScan.Hex;

const
  PriorityRequest = $6C;
  AddrPcm = $10;
  AddrTool = $F1;
  AddrToolPidTest = $F0;
  AddrAllNodes = $FE;

  ModeReturnToNormal = $20;  // used broadcast to discover modules
  ModeReadDtcs = $19;
  ModeClearDtcs = $14;
  ModeReadPid = $22;
  ModeRequestDpids = $2A;
  ModeDefineDpid = $2C;
  ModeWriteBlock = $3B;
  ModeReadBlock = $3C;
  ModeTesterPresent = $3F;
  ModeDeviceControl = $AE;
  ModeNegativeResponse = $7F;
  PositiveOffset = $40;

  BlockVin1 = $01;
  BlockVin2 = $02;
  BlockVin3 = $03;
  BlockOsid = $0A;

  // $2A "rate" byte, as measured on a bench PCM (AVT-841):
  //   high nibble = schedule slot. The PCM has two slots ($1x, $2x) of up to
  //     4 DPIDs each; a request replaces that slot's list. That is why legacy
  //     UVSCAN used $14 for DPIDs 1-4 and $24 for 5-8.
  //   low nibble = speed: 4 fast, 3 medium, 2 slow. $34, $0x, $11 are refused.
  // "2A 00" only pauses; the next request resumes the OTHER slot's old list
  // too. A slot is cleared by requesting it with no DPIDs (2A x4 00 00 00 00).
  // Each slot sends each of its DPIDs about 5 times/s at speed 4 (2.7/s at 3).
  // A DPID listed in both slots is sent twice as often, so up to 4 DPIDs can
  // run at ~10/s; 5-8 DPIDs need both slots and run at ~5/s (~40 frames/s).
  StreamSlot1 = $10;
  StreamSlot2 = $20;
  StreamSpeedFast = $04;
  StreamSpeedMedium = $03;
  StreamSpeedSlow = $02;

  // Response code in "7F 2A ..." replies to a stream request.
  NrcStreamAccepted = $23;  // accepted, data follows
  NrcInvalidFormat = $12;   // refused (e.g. fewer than 4 DPIDs, unknown rate)

  FirstDpid = $FE;
  DpidDataBytes = 6;
  MaxDpids = 8;            // $FE..$F7, as supported by UVSCAN
  DpidsPerRequest = 4;

type
  TClass2Message = record
    Priority: Byte;
    Target: Byte;
    Source: Byte;
    Mode: Byte;
    Data: TBytes;
    function IsNegativeFor(RequestMode: Byte): Boolean;
    function IsPositiveFor(RequestMode: Byte): Boolean;
    function ToHex: string;
  end;

function TryParseClass2(const Bus: TBytes; out Msg: TClass2Message): Boolean;

function BuildMessage(Target, Source, Mode: Byte; const Data: array of Byte): TBytes;

function ReadBlockRequest(BlockId: Byte): TBytes;
function DefineDpidRequest(Dpid, Position, Size: Byte; Pid: Word): TBytes;
{ The PCM only accepts exactly 4 DPIDs per request; unused entries are 00. }
function RequestDpidsRequest(Rate: Byte; const Dpids: array of Byte): TBytes;
function StopDpidsRequest: TBytes;
{ Empties one schedule slot so it cannot resume later. }
function ClearStreamSlotRequest(Slot: Byte): TBytes;
function TesterPresentRequest: TBytes;
function ReadPidRequest(Pid: Word): TBytes;
function DiscoverModulesRequest: TBytes;
function ReadDtcCountRequest(Module: Byte): TBytes;
function ReadDtcsRequest(Module: Byte): TBytes;
function ClearDtcRequests: TArray<TBytes>;
function WriteVinRequests(const Vin: string): TArray<TBytes>;

type
  TPidRange = record
    First, Last: Word;
    function Count: Integer;
  end;

{ "0000-00FF, 1000-1FFF, 1234" -> ranges. Raises EConvertError on bad input. }
function ParsePidRanges(const Text: string): TArray<TPidRange>;

const
  PidRangeSae = '0000-00FF';
  PidRangeGmEnhanced = '1000-1FFF';

function FormatDtc(Hi, Lo: Byte): string;
function ModuleName(Address: Byte): string;
{ Plain-language meaning of a negative response code (last byte of 7F ...). }
function NrcText(Code: Byte): string;
function IsValidVin(const Vin: string): Boolean;

implementation

{ TClass2Message }

function TClass2Message.IsNegativeFor(RequestMode: Byte): Boolean;
begin
  Result := (Mode = ModeNegativeResponse) and (Length(Data) > 0) and (Data[0] = RequestMode);
end;

function TClass2Message.IsPositiveFor(RequestMode: Byte): Boolean;
begin
  Result := Mode = Byte(RequestMode + PositiveOffset);
end;

function TClass2Message.ToHex: string;
begin
  Result := BytesToHex(ConcatBytes(BytesOf([Priority, Target, Source, Mode]), Data));
end;

function TryParseClass2(const Bus: TBytes; out Msg: TClass2Message): Boolean;
begin
  Result := Length(Bus) >= 4;
  if not Result then
    Exit;
  Msg.Priority := Bus[0];
  Msg.Target := Bus[1];
  Msg.Source := Bus[2];
  Msg.Mode := Bus[3];
  Msg.Data := Copy(Bus, 4, Length(Bus) - 4);
end;

function BuildMessage(Target, Source, Mode: Byte; const Data: array of Byte): TBytes;
begin
  Result := ConcatBytes(BytesOf([PriorityRequest, Target, Source, Mode]), BytesOf(Data));
end;

function ReadBlockRequest(BlockId: Byte): TBytes;
begin
  Result := BuildMessage(AddrPcm, AddrTool, ModeReadBlock, [BlockId]);
end;

function DefineDpidRequest(Dpid, Position, Size: Byte; Pid: Word): TBytes;
begin
  // Config byte: bits 7-6 = 01 (define by PID), bits 5-3 = start position, bits 2-0 = size.
  if not (Position in [1..DpidDataBytes]) or not (Size in [1..4]) or (Position + Size - 1 > DpidDataBytes) then
    raise EArgumentException.CreateFmt('Invalid DPID slot: position %d size %d', [Position, Size]);
  Result := BuildMessage(AddrPcm, AddrTool, ModeDefineDpid,
    [Dpid, $40 or (Position shl 3) or Size, Hi(Pid), Lo(Pid), $FF, $FF]);
end;

function RequestDpidsRequest(Rate: Byte; const Dpids: array of Byte): TBytes;
var
  Data: TBytes;
  I: Integer;
begin
  if (Length(Dpids) = 0) or (Length(Dpids) > DpidsPerRequest) then
    raise EArgumentException.Create('A DPID request needs 1 to 4 DPIDs');
  Data := BytesOf([Rate]);
  for I := 0 to High(Dpids) do
    Data := ConcatBytes(Data, BytesOf([Dpids[I]]));
  for I := Length(Dpids) to DpidsPerRequest - 1 do
    Data := ConcatBytes(Data, BytesOf([$00]));
  Result := ConcatBytes(BytesOf([PriorityRequest, AddrPcm, AddrTool, ModeRequestDpids]), Data);
end;

function StopDpidsRequest: TBytes;
begin
  Result := BuildMessage(AddrPcm, AddrTool, ModeRequestDpids, [$00]);
end;

function ClearStreamSlotRequest(Slot: Byte): TBytes;
begin
  Result := BuildMessage(AddrPcm, AddrTool, ModeRequestDpids, [Slot or StreamSpeedFast, 0, 0, 0, 0]);
end;

function TesterPresentRequest: TBytes;
begin
  Result := BuildMessage(AddrAllNodes, AddrTool, ModeTesterPresent, []);
end;

function ReadPidRequest(Pid: Word): TBytes;
begin
  Result := BuildMessage(AddrPcm, AddrToolPidTest, ModeReadPid, [Hi(Pid), Lo(Pid), $01]);
end;

function DiscoverModulesRequest: TBytes;
begin
  Result := BuildMessage(AddrAllNodes, AddrTool, ModeReturnToNormal, []);
end;

function ReadDtcCountRequest(Module: Byte): TBytes;
begin
  Result := BuildMessage(Module, AddrTool, ModeReadDtcs, [$08, $FF, $FF]);
end;

function ReadDtcsRequest(Module: Byte): TBytes;
begin
  Result := BuildMessage(Module, AddrTool, ModeReadDtcs, [$08, $FF, $00]);
end;

function ClearDtcRequests: TArray<TBytes>;
begin
  // Same sequence the legacy app sent to the PCM.
  Result := [
    BuildMessage(AddrPcm, AddrTool, ModeReturnToNormal, []),
    BuildMessage(AddrPcm, AddrTool, $10, [$00]),
    BuildMessage(AddrPcm, AddrTool, ModeClearDtcs, [])];
end;

function AsciiBytes(const S: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I - 1] := Ord(S[I]);
end;

function IsValidVin(const Vin: string): Boolean;
var
  C: Char;
begin
  Result := Length(Vin) = 17;
  if Result then
    for C in Vin do
      if not CharInSet(C, ['0'..'9', 'A'..'Z']) then
        Exit(False);
end;

function WriteVinRequests(const Vin: string): TArray<TBytes>;
begin
  if not IsValidVin(Vin) then
    raise EArgumentException.Create('A VIN must be 17 characters, A-Z and 0-9');
  Result := [
    ConcatBytes(BuildMessage(AddrPcm, AddrTool, ModeWriteBlock, [BlockVin1, $00]), AsciiBytes(Copy(Vin, 1, 5))),
    ConcatBytes(BuildMessage(AddrPcm, AddrTool, ModeWriteBlock, [BlockVin2]), AsciiBytes(Copy(Vin, 6, 6))),
    ConcatBytes(BuildMessage(AddrPcm, AddrTool, ModeWriteBlock, [BlockVin3]), AsciiBytes(Copy(Vin, 12, 6)))];
end;

function TPidRange.Count: Integer;
begin
  Result := Integer(Last) - Integer(First) + 1;
end;

function ParsePidRanges(const Text: string): TArray<TPidRange>;
var
  Part, A, B: string;
  Dash, V1, V2: Integer;
  R: TPidRange;
begin
  Result := nil;
  for Part in Text.Split([',', ';', ' '], TStringSplitOptions.ExcludeEmpty) do
  begin
    Dash := Pos('-', Part);
    if Dash > 0 then
    begin
      A := Trim(Copy(Part, 1, Dash - 1));
      B := Trim(Copy(Part, Dash + 1, MaxInt));
    end
    else
    begin
      A := Trim(Part);
      B := A;
    end;
    A := StringReplace(A, '$', '', [rfReplaceAll]);
    B := StringReplace(B, '$', '', [rfReplaceAll]);
    if not TryStrToInt('$' + A, V1) or not TryStrToInt('$' + B, V2) or (V1 < 0) or (V2 > $FFFF) or (V1 > V2) then
      raise EConvertError.CreateFmt('"%s" is not a PID range like 1000-1FFF', [Part]);
    R.First := V1;
    R.Last := V2;
    Result := Result + [R];
  end;
  if Length(Result) = 0 then
    raise EConvertError.Create('No PID range given (e.g. 1000-1FFF)');
end;

function FormatDtc(Hi, Lo: Byte): string;
const
  Systems: array[0..3] of Char = ('P', 'C', 'B', 'U');
begin
  // SAE J2012: bits 15-14 system, bits 13-12 first digit, rest are hex digits.
  Result := Systems[Hi shr 6] + IntToStr((Hi shr 4) and $03) + IntToHex(Hi and $0F, 1) + IntToHex(Lo, 2);
end;

function NrcText(Code: Byte): string;
begin
  case Code of
    $10: Result := 'general reject';
    $11: Result := 'mode not supported';
    $12: Result := 'not supported / wrong length';
    $22: Result := 'conditions not correct (engine running? vehicle moving?)';
    $31: Result := 'request out of range (not supported by this module)';
    $33: Result := 'security access required';
    $78: Result := 'busy, answer pending';
  else
    Result := 'code $' + IntToHex(Code, 2);
  end;
end;

function ModuleName(Address: Byte): string;
begin
  case Address of
    $10: Result := 'PCM/ECM';
    $18: Result := 'TCM';
    $20: Result := 'ABS';
    $40: Result := 'BCM';
    $50: Result := 'Network';
    $58: Result := 'Airbag';
    $60: Result := 'Instrument cluster';
    $62: Result := 'HUD';
    $80: Result := 'Radio';
    $C0: Result := 'Immobilizer';
  else
    Result := 'Module $' + IntToHex(Address, 2);
  end;
end;

end.
