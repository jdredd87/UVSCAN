unit UVScan.Avt;

{ AVT 838/841/842 host framing.

  Every frame in both directions starts with a header byte:
    high nibble = frame kind, low nibble = number of bytes that follow.
  Kind 0 is a vehicle-bus (J1850 VPW) message. On receive, the first byte
  after the header is an AVT status byte (00), followed by the bus message.
  Header $11 is the extended form for bus messages longer than 15 bytes:
  the byte after the header holds the length.

  Frames seen in the legacy UVSCAN code:
    host -> AVT  E1 33        (init)             AVT -> host  91 07   (seen on AVT-841)
    host -> AVT  B0           (version request)  AVT -> host  92 xx yy
    host -> AVT  F1 A5        (reset)            AVT -> host  91 07
    host -> AVT  52 59 01/00  (analog inputs on/off)
    AVT -> host  64 58 a1 a2 a3  (analog sample)
    host -> AVT  05 6C 10 F1 3C 01   (bus message, 5 bytes)
    AVT -> host  01 60        (transmit status: message sent; seen on AVT-841)
    AVT -> host  0C 00 6C F1 10 7C 01 00 ...  (status 00 + bus message) }

interface

uses
  System.SysUtils, UVScan.Hex;

const
  AvtKindBus = $0;
  AvtExtendedHeader = $11;

type
  TAvtFrame = record
    Header: Byte;
    Kind: Byte;      // high nibble of Header; 0 for bus messages (incl. extended)
    Data: TBytes;    // bytes after the header (after the length byte if extended)
    function IsBusMessage: Boolean;
    { Bus message without the AVT status byte, e.g. 6C F1 10 6A FE ... }
    function BusMessage: TBytes;
    function ToBytes: TBytes;
    function ToHex: string;
  end;

  TAvtFrameParser = class
  private
    FBuffer: TBytes;
    FCount: Integer;
    FResyncs: Integer;
    FHostSide: Boolean;
    procedure Consume(N: Integer);
  public
    procedure Push(const Data; Count: Integer); overload;
    procedure Push(const Data: TBytes); overload;
    function TryNext(out Frame: TAvtFrame): Boolean;
    procedure Clear;
    property Pending: Integer read FCount;
    { Number of stray bytes dropped to regain framing. }
    property Resyncs: Integer read FResyncs;
    { True when parsing what the host sends to the AVT (the simulator): those
      bus frames have no status byte and B0 has no data, so the checks that
      resync the AVT's output are off. }
    property HostSide: Boolean read FHostSide write FHostSide;
  end;

function EncodeAvtFrame(Kind: Byte; const Payload: TBytes): TBytes;
{ Host -> AVT bus message: header + message bytes (no status byte). }
function EncodeBusMessage(const Msg: TBytes): TBytes;

implementation

function EncodeAvtFrame(Kind: Byte; const Payload: TBytes): TBytes;
begin
  if Length(Payload) > 15 then
    raise EArgumentException.Create('AVT frame payload too long for a short header');
  Result := ConcatBytes(BytesOf([(Kind shl 4) or Length(Payload)]), Payload);
end;

function EncodeBusMessage(const Msg: TBytes): TBytes;
begin
  if Length(Msg) <= 15 then
    Result := EncodeAvtFrame(AvtKindBus, Msg)
  else if Length(Msg) <= 255 then
    Result := ConcatBytes(BytesOf([AvtExtendedHeader, Length(Msg)]), Msg)
  else
    raise EArgumentException.Create('Bus message too long');
end;

{ TAvtFrame }

function TAvtFrame.IsBusMessage: Boolean;
begin
  Result := (Kind = AvtKindBus) or (Header = AvtExtendedHeader);
end;

function TAvtFrame.BusMessage: TBytes;
begin
  if IsBusMessage and (Length(Data) > 1) then
    Result := Copy(Data, 1, Length(Data) - 1)
  else
    Result := nil;
end;

function TAvtFrame.ToBytes: TBytes;
begin
  if Header = AvtExtendedHeader then
    Result := ConcatBytes(BytesOf([Header, Length(Data)]), Data)
  else
    Result := ConcatBytes(BytesOf([Header]), Data);
end;

function TAvtFrame.ToHex: string;
begin
  Result := BytesToHex(ToBytes);
end;

{ TAvtFrameParser }

procedure TAvtFrameParser.Push(const Data; Count: Integer);
begin
  if Count <= 0 then
    Exit;
  if FCount + Count > Length(FBuffer) then
    SetLength(FBuffer, (FCount + Count) * 2);
  Move(Data, FBuffer[FCount], Count);
  Inc(FCount, Count);
end;

procedure TAvtFrameParser.Push(const Data: TBytes);
begin
  if Length(Data) > 0 then
    Push(Data[0], Length(Data));
end;

procedure TAvtFrameParser.Consume(N: Integer);
begin
  if N >= FCount then
    FCount := 0
  else
  begin
    Move(FBuffer[N], FBuffer[0], FCount - N);
    Dec(FCount, N);
  end;
end;

function TAvtFrameParser.TryNext(out Frame: TAvtFrame): Boolean;
var
  Header: Byte;
  HeaderLen, DataLen: Integer;
begin
  Result := False;
  if FCount = 0 then
    Exit;
  Header := FBuffer[0];
  if Header = AvtExtendedHeader then
  begin
    if FCount < 2 then
      Exit;
    HeaderLen := 2;
    DataLen := FBuffer[1];
  end
  else
  begin
    HeaderLen := 1;
    DataLen := Header and $0F;
  end;
  if FCount < HeaderLen + DataLen then
    Exit;

  // Resync: a received bus frame starts with status 00. If this one does not,
  // but the next byte is a bus header followed by 00, the first byte was a
  // stray duplicate (seen once on an AVT-841 at 115200). Drop it.
  if (Header shr 4 = AvtKindBus) and (DataLen >= 2) and (FBuffer[1] <> 0) and
    (FBuffer[1] shr 4 = AvtKindBus) and (FBuffer[1] and $0F >= 2) and (FBuffer[2] = 0) then
  begin
    Consume(1);
    Inc(FResyncs);
    Exit(TryNext(Frame));
  end;

  // A received bus message always starts with status 00 (only the AVT's
  // one-byte transmit status, 01 60, is shorter). Anything else means a
  // header whose bytes never came: seen on a 1999 Grand Prix through a
  // Keyspan, "0C" then straight "01 60", which put every later frame two
  // bytes off. Skip it.
  if not FHostSide and ((Header shr 4 = AvtKindBus) or (Header = AvtExtendedHeader)) and (DataLen >= 2) and
    (FBuffer[HeaderLen] <> 0) then
  begin
    Consume(1);
    Inc(FResyncs);
    Exit(TryNext(Frame));
  end;

  // A frame with no data, or a bus message whose first byte is no Class 2
  // header (Class 2 always uses the 3-byte header form: bit 4 clear), means
  // the framing is off: a stray byte, or the AVT cut a frame short (it does
  // when it is reset while the PCM is streaming, e.g. "0C 00" then "91 07").
  // Skip one byte and look again.
  if not FHostSide and (((Header <> AvtExtendedHeader) and (DataLen = 0)) or
    (((Header shr 4 = AvtKindBus) or (Header = AvtExtendedHeader)) and (DataLen >= 4) and
    (FBuffer[HeaderLen + 1] and $10 <> 0))) then
  begin
    Consume(1);
    Inc(FResyncs);
    Exit(TryNext(Frame));
  end;

  Frame.Header := Header;
  if Header = AvtExtendedHeader then
    Frame.Kind := AvtKindBus
  else
    Frame.Kind := Header shr 4;
  Frame.Data := Copy(FBuffer, HeaderLen, DataLen);
  Consume(HeaderLen + DataLen);
  Result := True;
end;

procedure TAvtFrameParser.Clear;
begin
  FCount := 0;
end;

end.
