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
{ Rate byte as used by legacy UVSCAN: $14 for the first group of 4 DPIDs, $24 for the second. }
function RequestDpidsRequest(Rate: Byte; const Dpids: array of Byte; PadToFour: Boolean): TBytes;
function StopDpidsRequest: TBytes;
function TesterPresentRequest: TBytes;
function ReadPidRequest(Pid: Word): TBytes;
function DiscoverModulesRequest: TBytes;
function ReadDtcCountRequest(Module: Byte): TBytes;
function ReadDtcsRequest(Module: Byte): TBytes;
function ClearDtcRequests: TArray<TBytes>;
function WriteVinRequests(const Vin: string): TArray<TBytes>;
function ResetLtftRequest: TBytes;
function CheckEngineLightRequest(TurnOn: Boolean): TBytes;

function FormatDtc(Hi, Lo: Byte): string;
function ModuleName(Address: Byte): string;
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

function RequestDpidsRequest(Rate: Byte; const Dpids: array of Byte; PadToFour: Boolean): TBytes;
var
  Data: TBytes;
  I: Integer;
begin
  if (Length(Dpids) = 0) or (Length(Dpids) > DpidsPerRequest) then
    raise EArgumentException.Create('A DPID request needs 1 to 4 DPIDs');
  Data := BytesOf([Rate]);
  for I := 0 to High(Dpids) do
    Data := ConcatBytes(Data, BytesOf([Dpids[I]]));
  if PadToFour then
    for I := Length(Dpids) to DpidsPerRequest - 1 do
      Data := ConcatBytes(Data, BytesOf([$00]));
  Result := ConcatBytes(BytesOf([PriorityRequest, AddrPcm, AddrTool, ModeRequestDpids]), Data);
end;

function StopDpidsRequest: TBytes;
begin
  Result := BuildMessage(AddrPcm, AddrTool, ModeRequestDpids, [$00]);
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

function ResetLtftRequest: TBytes;
begin
  Result := BuildMessage(AddrPcm, AddrTool, ModeDeviceControl, [$02, $40, $00, $00, $00, $00, $00]);
end;

function CheckEngineLightRequest(TurnOn: Boolean): TBytes;
begin
  if TurnOn then
    Result := BuildMessage(AddrPcm, AddrTool, ModeDeviceControl, [$01, $00, $00, $00, $00, $00, $00])
  else
    Result := BuildMessage(AddrPcm, AddrTool, ModeDeviceControl, [$01, $80, $80, $00, $00, $00, $00]);
end;

function FormatDtc(Hi, Lo: Byte): string;
const
  Systems: array[0..3] of Char = ('P', 'C', 'B', 'U');
begin
  // SAE J2012: bits 15-14 system, bits 13-12 first digit, rest are hex digits.
  Result := Systems[Hi shr 6] + IntToStr((Hi shr 4) and $03) + IntToHex(Hi and $0F, 1) + IntToHex(Lo, 2);
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
