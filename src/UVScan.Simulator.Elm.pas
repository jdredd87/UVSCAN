unit UVScan.Simulator.Elm;

{ A simulated ELM327 on J1850 VPW, in front of the simulated PCM
  (TSimulatedAvt, whose AVT side nobody sees), as an ISerialPort: for the
  tests and for trying the ELM327 adapter without one.

  It behaves as an ELM327 v1.5 does in the ways UVScan depends on: commands
  end with CR and are answered up to the '>' prompt; echo, spaces and line
  feeds on and headers off after ATZ; a request listens for answers until
  none has come for the timeout (ATST, 200 ms), "NO DATA" when none came at
  all; ATMA shows every message until a character is received; any
  character received while listening stops it ("STOPPED") and is dropped;
  with headers on a message is shown with its J1850 CRC; only replies to
  the receive address (the header's source byte, or ATSR) are shown. }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Diagnostics,
  UVScan.Serial, UVScan.Avt, UVScan.Simulator;

type
  TSimulatedElm = class(TInterfacedObject, ISerialPort)
  private type
    TElmState = (stIdle, stListening, stMonitoring);
  private
    FPcm: TSimulatedAvt;
    FPcmRef: ISerialPort;      // keeps FPcm alive
    FOpen: Boolean;
    FClock: TStopwatch;
    FParser: TAvtFrameParser;
    FBuf: array[0..1023] of Byte;
    FOut: TBytes;
    FIn: string;
    FLast: string;
    FState: TElmState;
    FListenUntil: Int64;
    FGotAny: Boolean;
    FEcho, FSpaces, FLineFeeds, FHeaders, FLong: Boolean;
    FHeader: TBytes;
    FReceive: Integer;         // -1: the header's source byte
    FTimeoutMs: Integer;
    FRequests: Integer;
    procedure Defaults;
    procedure Put(const S: string);
    procedure EndLine;
    procedure Prompt;
    procedure Execute(const Cmd: string);
    procedure AtCommand(const Cmd: string);
    procedure Deliver(const Msg: TBytes);
    procedure Pump;
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
    { The simulated PCM behind it (rejected PIDs, resets). }
    property Pcm: TSimulatedAvt read FPcm;
    { Bus requests sent so far (data lines, not AT commands). }
    property Requests: Integer read FRequests;
  end;

{ SAE J1850 CRC-8 of Bytes. }
function J1850Crc(const Bytes: TBytes): Byte;

implementation

uses
  System.StrUtils, UVScan.Hex;

const
  ElmVersion = 'ELM327 v1.5';

function J1850Crc(const Bytes: TBytes): Byte;
var
  B: Byte;
  I: Integer;
  Crc: Byte;
begin
  Crc := $FF;
  for B in Bytes do
  begin
    Crc := Crc xor B;
    for I := 0 to 7 do
      if Crc and $80 <> 0 then
        Crc := Byte((Crc shl 1) xor $1D)
      else
        Crc := Byte(Crc shl 1);
  end;
  Result := not Crc;
end;

{ TSimulatedElm }

constructor TSimulatedElm.Create;
begin
  inherited Create;
  FPcm := TSimulatedAvt.Create;
  FPcmRef := FPcm;
  FParser := TAvtFrameParser.Create;
  FClock := TStopwatch.StartNew;
  Defaults;
end;

destructor TSimulatedElm.Destroy;
begin
  FParser.Free;
  FPcmRef := nil;
  inherited;
end;

function TSimulatedElm.Description: string;
begin
  Result := 'Simulator (ELM327)';
end;

procedure TSimulatedElm.Defaults;
begin
  FEcho := True;
  FSpaces := True;
  FLineFeeds := False;
  FHeaders := False;
  FLong := False;
  FHeader := BytesOf([$68, $6A, $F1]);
  FReceive := -1;
  FTimeoutMs := 200;
  FState := stIdle;
end;

procedure TSimulatedElm.Open;
begin
  FPcmRef.Open;
  FOpen := True;
end;

procedure TSimulatedElm.Close;
begin
  FOpen := False;
  FPcmRef.Close;
end;

function TSimulatedElm.IsOpen: Boolean;
begin
  Result := FOpen;
end;

procedure TSimulatedElm.Purge;
begin
  FOut := nil;
end;

procedure TSimulatedElm.Put(const S: string);
begin
  FOut := FOut + TEncoding.ASCII.GetBytes(S);
end;

procedure TSimulatedElm.EndLine;
begin
  if FLineFeeds then
    Put(#13#10)
  else
    Put(#13);
end;

procedure TSimulatedElm.Prompt;
begin
  EndLine;
  Put('>');
  FState := stIdle;
end;

procedure TSimulatedElm.Write(const Data: TBytes);
var
  B: Byte;
  C: Char;
begin
  if not FOpen then
    raise ESerialError.Create('Simulator is not open');
  for B in Data do
  begin
    C := Char(B);
    if FState <> stIdle then
    begin
      // Anything received while it listens stops it; the character is dropped.
      FState := stIdle;
      Put('STOPPED');
      EndLine;
      Prompt;
      Continue;
    end;
    if FEcho then
      Put(C);
    if C = #13 then
    begin
      if FEcho and FLineFeeds then
        Put(#10);
      if FIn = '' then
        Execute(FLast) // a bare CR repeats the last command
      else
      begin
        FLast := FIn;
        Execute(FIn);
      end;
      FIn := '';
    end
    else if C > ' ' then
      FIn := FIn + UpCase(C);
  end;
end;

procedure TSimulatedElm.Execute(const Cmd: string);
var
  Data, Msg: TBytes;
  I: Integer;
begin
  if Cmd = '' then
  begin
    Put('>');
    Exit;
  end;
  if Cmd.StartsWith('AT') then
  begin
    AtCommand(Cmd.Substring(2));
    Exit;
  end;
  // Data bytes for the bus, after the header.
  if Odd(Length(Cmd)) then
  begin
    Put('?');
    EndLine;
    Prompt;
    Exit;
  end;
  for I := 1 to Length(Cmd) do
    if not CharInSet(Cmd[I], ['0'..'9', 'A'..'F']) then
    begin
      Put('?');
      EndLine;
      Prompt;
      Exit;
    end;
  Data := HexToBytes(Cmd);
  if (Length(Data) > IfThen(FLong, 8, 7)) or (Length(Data) = 0) then
  begin
    Put('?');
    EndLine;
    Prompt;
    Exit;
  end;
  Msg := FHeader + Data;
  Inc(FRequests);
  FPcmRef.Write(EncodeBusMessage(Msg));
  FState := stListening;
  FGotAny := False;
  FListenUntil := FClock.ElapsedMilliseconds + FTimeoutMs;
end;

procedure TSimulatedElm.AtCommand(const Cmd: string);

  procedure Ok;
  begin
    Put('OK');
    EndLine;
    Prompt;
  end;

  function Arg(const Prefix: string): string;
  begin
    Result := Cmd.Substring(Length(Prefix));
  end;

var
  V: Integer;
begin
  if (Cmd = 'Z') or (Cmd = 'WS') then
  begin
    Defaults;
    EndLine;
    EndLine;
    Put(ElmVersion);
    EndLine;
    Prompt;
  end
  else if Cmd = 'I' then
  begin
    Put(ElmVersion);
    EndLine;
    Prompt;
  end
  else if Cmd = '@1' then
  begin
    Put('OBDII to RS232 Interpreter');
    EndLine;
    Prompt;
  end
  else if Cmd = 'RV' then
  begin
    Put('12.4V');
    EndLine;
    Prompt;
  end
  else if Cmd = 'DP' then
  begin
    Put('SAE J1850 VPW');
    EndLine;
    Prompt;
  end
  else if Cmd = 'DPN' then
  begin
    Put('2');
    EndLine;
    Prompt;
  end
  else if (Cmd = 'E0') or (Cmd = 'E1') then
  begin
    FEcho := Cmd = 'E1';
    Ok;
  end
  else if (Cmd = 'L0') or (Cmd = 'L1') then
  begin
    FLineFeeds := Cmd = 'L1';
    Ok;
  end
  else if (Cmd = 'S0') or (Cmd = 'S1') then
  begin
    FSpaces := Cmd = 'S1';
    Ok;
  end
  else if (Cmd = 'H0') or (Cmd = 'H1') then
  begin
    FHeaders := Cmd = 'H1';
    Ok;
  end
  else if (Cmd = 'AL') or (Cmd = 'NL') then
  begin
    FLong := Cmd = 'AL';
    Ok;
  end
  else if (Cmd = 'SP2') or (Cmd = 'SPA2') or (Cmd = 'SP0') or (Cmd = 'D') or (Cmd = 'AT0') or (Cmd = 'AT1') or
    (Cmd = 'AT2') then
    Ok
  else if Cmd.StartsWith('SH') and (Length(Arg('SH')) = 6) then
  begin
    FHeader := HexToBytes(Arg('SH'));
    Ok;
  end
  else if Cmd.StartsWith('SR') and (Length(Arg('SR')) = 2) then
  begin
    FReceive := StrToInt('$' + Arg('SR'));
    Ok;
  end
  else if Cmd = 'AR' then
  begin
    FReceive := -1;
    Ok;
  end
  else if Cmd.StartsWith('ST') and (Length(Arg('ST')) = 2) and TryStrToInt('$' + Arg('ST'), V) then
  begin
    if V = 0 then
      FTimeoutMs := 200
    else
      FTimeoutMs := V * 4;
    Ok;
  end
  else if Cmd = 'MA' then
    FState := stMonitoring // no prompt until stopped
  else
  begin
    Put('?');
    EndLine;
    Prompt;
  end;
end;

procedure TSimulatedElm.Deliver(const Msg: TBytes);
var
  Shown: TBytes;
  Receive: Integer;
begin
  if Length(Msg) < 3 then
    Exit;
  case FState of
    stListening:
      begin
        Receive := FReceive;
        if Receive < 0 then
          Receive := FHeader[2];
        if Msg[1] <> Receive then
          Exit;
        FGotAny := True;
        FListenUntil := FClock.ElapsedMilliseconds + FTimeoutMs;
      end;
    stMonitoring: ;
  else
    Exit; // nobody listening
  end;
  if FHeaders then
    Shown := Msg + [J1850Crc(Msg)]
  else
    Shown := Copy(Msg, 3, MaxInt);
  if FSpaces then
    Put(BytesToHex(Shown, ' ') + ' ')
  else
    Put(BytesToHex(Shown, ''));
  EndLine;
end;

procedure TSimulatedElm.Pump;
var
  N: Integer;
  F: TAvtFrame;
begin
  N := FPcmRef.Read(FBuf, SizeOf(FBuf), 0);
  if N > 0 then
    FParser.Push(FBuf, N);
  while FParser.TryNext(F) do
    if F.IsBusMessage and (Length(F.Data) > 1) then
      Deliver(F.BusMessage);
  if (FState = stListening) and (FClock.ElapsedMilliseconds >= FListenUntil) then
  begin
    if not FGotAny then
    begin
      Put('NO DATA');
      EndLine;
    end;
    Prompt;
  end;
end;

function TSimulatedElm.Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
var
  Deadline: Int64;
begin
  if not FOpen then
    raise ESerialError.Create('Simulator is not open');
  Deadline := FClock.ElapsedMilliseconds + TimeoutMs;
  repeat
    Pump;
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
