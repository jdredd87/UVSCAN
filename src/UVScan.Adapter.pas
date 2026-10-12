unit UVScan.Adapter;

{ The interface between the scan engine and the vehicle bus: an AVT-841, or
  an ELM327 type adapter (Bluetooth, Wi-Fi, USB). The engine speaks Class 2
  messages; the adapter turns them into what its hardware wants and turns
  what comes back into frames.

  Frames are TAvtFrame, the AVT's own: a received bus message is a frame of
  kind 0 whose data is a status byte (00) and the message, as the AVT sends
  it. The ELM adapter makes the same frames out of the ELM's text lines, so
  everything above (matching replies, DPID data, logs) is the same for both.

  ELM327 support is the standard command set only (any ELM327, clone, STN or
  OBDLink chip): ATZ, ATE0, ATL0, ATS0, ATH1, ATAL, ATSP2, ATSH, ATSR / ATAR,
  ATMA. See TElmAdapter for how it keeps a DPID stream coming. }

interface

uses
  System.SysUtils, System.Classes, System.Diagnostics, System.Math,
  UVScan.Serial, UVScan.Avt, UVScan.Elm, UVScan.Hex;

type
  TAdapterKind = (akAvt, akElm327);

  TAdapterLog = reference to procedure(const Text: string);

  TBusAdapter = class
  protected
    FPort: ISerialPort;
    FOnLog: TAdapterLog;
    FOnTrace: TAdapterLog;
    FStreaming: Boolean;
    procedure Log(const Text: string);
    procedure Trace(const Text: string);
  public
    constructor Create(const Port: ISerialPort; const OnLog, OnTrace: TAdapterLog);
    { The port is open: wakes the adapter and sets it up for Class 2.
      Firmware = what it says it is. False when it does not answer (Problem
      says what to check). }
    function Initialize(out Firmware, Problem: string): Boolean; virtual; abstract;
    { Sends one Class 2 message (header included). }
    procedure SendBus(const Msg: TBytes); virtual; abstract;
    { The next frame received within TimeoutMs. }
    function NextFrame(TimeoutMs: Cardinal; out F: TAvtFrame): Boolean; virtual; abstract;
    { Drops what has arrived and not been taken yet. }
    procedure Flush; virtual; abstract;
    { Reads and drops everything that arrives for Ms milliseconds. }
    procedure Discard(Ms: Cardinal); virtual;
    { The Raw frame command: AVT: an AVT frame as typed; ELM: a bus message. }
    procedure SendRaw(const Bytes: TBytes); virtual; abstract;
    { The AVT's analog inputs on / off. False where there are none. }
    function SetAnalog(On: Boolean): Boolean; virtual;
    function HasAnalog: Boolean; virtual;
    { A frame as the traffic view shows it. }
    function FrameText(const F: TAvtFrame): string; virtual;
    { Called before the port closes: leaves the adapter idle. }
    procedure Finish; virtual;
    function Name: string; virtual; abstract;
    { True while a DPID stream is wanted: the ELM keeps listening for it. }
    property Streaming: Boolean read FStreaming write FStreaming;
    property Port: ISerialPort read FPort;
  end;

  TAvtAdapter = class(TBusAdapter)
  private
    FParser: TAvtFrameParser;
    FReadBuf: array[0..1023] of Byte;
    procedure SendFrame(const Frame: TBytes);
    function WaitFrame(const Match: TFunc<TAvtFrame, Boolean>; TimeoutMs: Cardinal; out F: TAvtFrame): Boolean;
  public
    constructor Create(const Port: ISerialPort; const OnLog, OnTrace: TAdapterLog);
    destructor Destroy; override;
    function Initialize(out Firmware, Problem: string): Boolean; override;
    procedure SendBus(const Msg: TBytes); override;
    function NextFrame(TimeoutMs: Cardinal; out F: TAvtFrame): Boolean; override;
    procedure Flush; override;
    procedure SendRaw(const Bytes: TBytes); override;
    function SetAnalog(On: Boolean): Boolean; override;
    function HasAnalog: Boolean; override;
    function Name: string; override;
  end;

  { An ELM327 on J1850 VPW.

    A request goes out as its data bytes behind the header (ATSH, set only
    when it changes); replies come back as lines while the ELM listens,
    which it does until the bus has been quiet for its timeout, then shows
    its prompt. Anything sent to it while it listens stops that ("STOPPED"),
    so before each request a listening ELM is stopped first (a space: at
    the prompt already, a space is simply ignored).

    The PCM's replies to a request from F0 (the PID test) are addressed to
    F0, which an ELM does not show unless told: ATSR F0, and ATAR (back to
    the header's own address) for F1.

    A DPID stream: the PCM sends its frames in bursts, with gaps the ELM
    takes as the end. While Streaming, when its prompt comes it is set to
    monitor the bus (ATMA) instead, which shows every frame until it is
    stopped. Each request (the engine's tester present every 2 s) stops
    that, and the request's own listening takes over. }
  TElmAdapter = class(TBusAdapter)
  private
    FLink: TElmLink;
    FHeader: TBytes;
    FReceive: Byte;          // the address replies are shown for (ATSR), $F1 = automatic
    FMonitoring: Boolean;    // ATMA running
    FClock: TStopwatch;      // since the adapter was made: times in the traffic trace
    function Setup(const Cmd: string; Required: Boolean; out Reply: string): Boolean;
    procedure Idle;
    function MakeFrame(const Msg: TBytes): TAvtFrame;
  public
    constructor Create(const Port: ISerialPort; const OnLog, OnTrace: TAdapterLog);
    destructor Destroy; override;
    function Initialize(out Firmware, Problem: string): Boolean; override;
    procedure SendBus(const Msg: TBytes); override;
    function NextFrame(TimeoutMs: Cardinal; out F: TAvtFrame): Boolean; override;
    procedure Flush; override;
    procedure Discard(Ms: Cardinal); override;
    procedure SendRaw(const Bytes: TBytes); override;
    function FrameText(const F: TAvtFrame): string; override;
    procedure Finish; override;
    function Name: string; override;
  end;

const
  // An AVT-838, 841 or 842: the same host protocol (the old UVSCAN did not
  // tell them apart either).
  AdapterNames: array[TAdapterKind] of string = ('AVT', 'ELM327');
  AdapterKeys: array[TAdapterKind] of string = ('avt', 'elm327');

function CreateAdapter(Kind: TAdapterKind; const Port: ISerialPort; const OnLog, OnTrace: TAdapterLog): TBusAdapter;
function AdapterKindFromKey(const Key: string): TAdapterKind;

implementation

uses
  System.StrUtils;

function CreateAdapter(Kind: TAdapterKind; const Port: ISerialPort; const OnLog, OnTrace: TAdapterLog): TBusAdapter;
begin
  case Kind of
    akElm327: Result := TElmAdapter.Create(Port, OnLog, OnTrace);
  else
    Result := TAvtAdapter.Create(Port, OnLog, OnTrace);
  end;
end;

function AdapterKindFromKey(const Key: string): TAdapterKind;
var
  K: TAdapterKind;
begin
  for K := Low(TAdapterKind) to High(TAdapterKind) do
    if SameText(Key, AdapterKeys[K]) then
      Exit(K);
  Result := akAvt;
end;

{ TBusAdapter }

constructor TBusAdapter.Create(const Port: ISerialPort; const OnLog, OnTrace: TAdapterLog);
begin
  inherited Create;
  FPort := Port;
  FOnLog := OnLog;
  FOnTrace := OnTrace;
end;

procedure TBusAdapter.Log(const Text: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Text);
end;

procedure TBusAdapter.Trace(const Text: string);
begin
  if Assigned(FOnTrace) then
    FOnTrace(Text);
end;

procedure TBusAdapter.Discard(Ms: Cardinal);
var
  Clock: TStopwatch;
  F: TAvtFrame;
  Left: Int64;
begin
  Clock := TStopwatch.StartNew;
  repeat
    Left := Int64(Ms) - Clock.ElapsedMilliseconds;
    if Left <= 0 then
      Break;
    NextFrame(Min(Left, 50), F);
  until False;
  Flush;
end;

function TBusAdapter.SetAnalog(On: Boolean): Boolean;
begin
  Result := False;
end;

function TBusAdapter.HasAnalog: Boolean;
begin
  Result := False;
end;

function TBusAdapter.FrameText(const F: TAvtFrame): string;
begin
  Result := F.ToHex;
end;

procedure TBusAdapter.Finish;
begin
end;

{ TAvtAdapter }

constructor TAvtAdapter.Create(const Port: ISerialPort; const OnLog, OnTrace: TAdapterLog);
begin
  inherited;
  FParser := TAvtFrameParser.Create;
end;

destructor TAvtAdapter.Destroy;
begin
  FParser.Free;
  inherited;
end;

function TAvtAdapter.Name: string;
begin
  Result := 'AVT';
end;

function TAvtAdapter.HasAnalog: Boolean;
begin
  Result := True;
end;

procedure TAvtAdapter.SendFrame(const Frame: TBytes);
begin
  Trace('TX  ' + BytesToHex(Frame));
  FPort.Write(Frame);
end;

procedure TAvtAdapter.SendBus(const Msg: TBytes);
begin
  SendFrame(EncodeBusMessage(Msg));
end;

procedure TAvtAdapter.SendRaw(const Bytes: TBytes);
begin
  SendFrame(Bytes);
end;

function TAvtAdapter.SetAnalog(On: Boolean): Boolean;
begin
  SendFrame(EncodeAvtFrame($5, BytesOf([$59, Ord(On)])));
  Result := True;
end;

function TAvtAdapter.NextFrame(TimeoutMs: Cardinal; out F: TAvtFrame): Boolean;
var
  N: Integer;
begin
  Result := FParser.TryNext(F);
  if not Result then
  begin
    N := FPort.Read(FReadBuf, SizeOf(FReadBuf), TimeoutMs);
    if N > 0 then
      FParser.Push(FReadBuf, N);
    Result := FParser.TryNext(F);
  end;
end;

procedure TAvtAdapter.Flush;
begin
  FParser.Clear;
  FPort.Purge;
end;

function TAvtAdapter.WaitFrame(const Match: TFunc<TAvtFrame, Boolean>; TimeoutMs: Cardinal;
  out F: TAvtFrame): Boolean;
var
  Clock: TStopwatch;
  Left: Int64;
begin
  Clock := TStopwatch.StartNew;
  repeat
    Left := Int64(TimeoutMs) - Clock.ElapsedMilliseconds;
    if Left <= 0 then
      Exit(False);
    if NextFrame(Min(Left, 50), F) and Match(F) then
      Exit(True);
  until False;
end;

function TAvtAdapter.Initialize(out Firmware, Problem: string): Boolean;
var
  F: TAvtFrame;
  Attempt: Integer;
begin
  // Same initialisation the legacy app used: E1 33 (VPW mode), B0 (version).
  // Tried three times: if a program was stopped halfway through sending a
  // frame, the AVT takes the first bytes we send as the rest of that frame.
  for Attempt := 1 to 3 do
  begin
    SendFrame(HexToBytes('E1 33'));
    if not WaitFrame(
      function(Fr: TAvtFrame): Boolean
      begin
        Result := (Fr.Header = $91) or (Fr.Kind = $C); // AVT-841 answers 91 07
      end, 500, F) then
      Log('No reply to the AVT mode command (E1 33)');
    SendFrame(HexToBytes('B0'));
    Result := WaitFrame(
      function(Fr: TAvtFrame): Boolean
      begin
        Result := (Fr.Header = $92) and (Length(Fr.Data) >= 2);
      end, 1000, F);
    if Result then
      Break;
    Log(Format('No answer from the AVT (attempt %d of 3)', [Attempt]));
    Discard(200);
  end;
  if Result then
    Firmware := BytesToHex(F.Data) // AVT-841: 92 04 13 -> '04 13'
  else if (FPort as TObject) is TTcpSerialPort then
    // The connection opened, so something is at that address: the AVT is
    // off, or the address is another device's.
    Problem := Format('%s accepted the connection but no AVT answered. ' +
      'Check the AVT has power and that this is its address and port.', [FPort.Description])
  else
    Problem := 'No response from the AVT interface. Check the port, baud rate and power.';
end;

{ TElmAdapter }

constructor TElmAdapter.Create(const Port: ISerialPort; const OnLog, OnTrace: TAdapterLog);
begin
  inherited;
  FClock := TStopwatch.StartNew;
  // The ELM's traffic with the time it happened (the traffic view shows a
  // line when it gets to it).
  FLink := TElmLink.Create(Port,
    procedure(Line: string)
    begin
      Trace(Format('%7.3f %s', [FClock.Elapsed.TotalSeconds, Line]));
    end);
  FLink.HeadersOn := True;
  FReceive := $F1;
end;

destructor TElmAdapter.Destroy;
begin
  FLink.Free;
  inherited;
end;

function TElmAdapter.Name: string;
begin
  Result := 'ELM327';
end;

{ One set-up command. Required: its answer must be OK. }
function TElmAdapter.Setup(const Cmd: string; Required: Boolean; out Reply: string): Boolean;
begin
  try
    Reply := String.Join(' ', FLink.CommandLines(Cmd, 2000));
  except
    on E: EElmError do
      Reply := '';
  end;
  Result := ContainsText(Reply, 'OK');
  if not Result and Required then
    Log(Format('The adapter refused %s (%s)', [Cmd, IfThen(Reply <> '', Reply, 'no answer')]));
end;

function TElmAdapter.Initialize(out Firmware, Problem: string): Boolean;
var
  Reply, Line: string;
  Lines: TArray<string>;
  Cmd: string;
begin
  Result := False;
  Firmware := '';
  // It may still be listening or monitoring for an earlier connection: a
  // space stops that (and is ignored at the prompt).
  FPort.Write(TBytes.Create(Ord(' ')));
  FLink.Discard(300);
  Lines := nil;
  for Cmd in ['ATZ', 'ATI'] do
  begin
    try
      Lines := FLink.CommandLines(Cmd, IfThen(Cmd = 'ATZ', 5000, 2000));
    except
      on E: EElmError do
        Lines := nil;
    end;
    for Line in Lines do
      if ContainsText(Line, 'ELM') or ContainsText(Line, 'STN') or ContainsText(Line, 'OBD') then
        Firmware := Line.Trim;
    if Firmware <> '' then
      Break;
    FLink.Discard(200);
  end;
  if Firmware = '' then
  begin
    if (FPort as TObject) is TTcpSerialPort then
      Problem := Format('%s accepted the connection but no ELM327 answered. ' +
        'Check it has power and that this is its address and port.', [FPort.Description])
    else
      Problem := 'No answer from an ELM327 adapter. Check it is plugged in and powered, ' +
        'the port (a Bluetooth one must be paired first) and, for a USB one, the baud rate.';
    Exit;
  end;
  Log('Adapter: ' + Firmware);
  // No echo, no line feeds, no spaces, headers on, long messages (device
  // control is 8 data bytes). Spaces and line feeds only cost time, so an
  // adapter that does not know ATS0 is fine.
  if not Setup('ATE0', True, Reply) or not Setup('ATL0', False, Reply) then
  begin
    Problem := 'The ELM327 adapter does not accept its set-up commands.';
    Exit;
  end;
  Setup('ATS0', False, Reply);
  if not Setup('ATH1', True, Reply) then
  begin
    Problem := 'The ELM327 adapter cannot show message headers (ATH1), which UVScan needs.';
    Exit;
  end;
  Setup('ATAL', False, Reply);
  if not Setup('ATSP2', True, Reply) then
  begin
    Problem := 'This ELM327 adapter does not support J1850 VPW (GM Class 2): ATSP2 was refused.';
    Exit;
  end;
  try
    Log('Protocol: ' + String.Join(' ', FLink.CommandLines('ATDP')));
    Reply := String.Join(' ', FLink.CommandLines('ATRV'));
    if Reply <> '' then
      Log('Voltage at the plug: ' + Reply);
  except
    on E: EElmError do
      ; // only for the log
  end;
  FHeader := nil;
  FReceive := $F1;
  FMonitoring := False;
  Result := True;
end;

{ Stops a listening or monitoring ELM, so it takes the next command. }
procedure TElmAdapter.Idle;
begin
  FLink.Interrupt(500);
  FMonitoring := False;
end;

procedure TElmAdapter.SendBus(const Msg: TBytes);
var
  Header: TBytes;
  Reply: string;
begin
  if Length(Msg) < 4 then
    raise EArgumentException.Create('A Class 2 message needs a header and data');
  Idle;
  Header := Copy(Msg, 0, 3);
  if not SameBytes(Header, FHeader) then
  begin
    if not Setup('ATSH' + BytesToHex(Header, ''), True, Reply) then
      raise ESerialError.CreateFmt('The ELM327 adapter refused the header %s', [BytesToHex(Header)]);
    FHeader := Header;
  end;
  // Replies to the source address in the header: F1 is the ELM's own.
  if Msg[2] <> FReceive then
  begin
    if Msg[2] = $F1 then
      Setup('ATAR', False, Reply)
    else
      Setup('ATSR' + IntToHex(Msg[2], 2), False, Reply);
    FReceive := Msg[2];
  end;
  FLink.Send(BytesToHex(Copy(Msg, 3, MaxInt), ''));
end;

procedure TElmAdapter.SendRaw(const Bytes: TBytes);
begin
  SendBus(Bytes);
end;

function TElmAdapter.MakeFrame(const Msg: TBytes): TAvtFrame;
var
  N: Integer;
begin
  // As the AVT would send it: status byte 00, then the message.
  N := Length(Msg) + 1;
  if N <= 15 then
    Result.Header := N
  else
    Result.Header := AvtExtendedHeader;
  Result.Kind := AvtKindBus;
  Result.Data := ConcatBytes(BytesOf([$00]), Msg);
end;

function TElmAdapter.NextFrame(TimeoutMs: Cardinal; out F: TAvtFrame): Boolean;
var
  Deadline: UInt64;
  Line, Up: string;
  Prompt: Boolean;
  Msg: TBytes;
  Left: Int64;
begin
  Result := False;
  Deadline := TThread.GetTickCount64 + TimeoutMs;
  repeat
    // Streaming and the ELM stopped listening: watch the bus instead.
    if FStreaming and not FLink.Listening then
    begin
      FLink.Send('ATMA');
      FMonitoring := True;
    end;
    Left := Int64(Deadline) - Int64(TThread.GetTickCount64);
    if not FLink.ReadLine(Max(0, Left), Line, Prompt) then
      Exit;
    if Prompt then
    begin
      FMonitoring := False;
      Continue;
    end;
    if ParseElmFrame(Line, True, Msg) and (Length(Msg) >= 4) then
    begin
      F := MakeFrame(Msg);
      Exit(True);
    end;
    Up := Line.ToUpper;
    if Up.Contains('BUFFER FULL') then
      Log('The ELM327 adapter''s buffer filled up: some data was lost')
    else if not (Up.Contains('NO DATA') or Up.Contains('STOPPED') or Up.StartsWith('SEARCHING') or (Up = 'OK')) then
      Trace('ELM: ' + Line);
  until TThread.GetTickCount64 >= Deadline;
end;

procedure TElmAdapter.Flush;
begin
  // Not the port's purge: a prompt among what is dropped has to be seen.
  FLink.Flush;
end;

procedure TElmAdapter.Discard(Ms: Cardinal);
var
  Was: Boolean;
begin
  // No monitoring started just to throw the frames away.
  Was := FStreaming;
  FStreaming := False;
  try
    inherited;
  finally
    FStreaming := Was;
  end;
end;

function TElmAdapter.FrameText(const F: TAvtFrame): string;
begin
  Result := BytesToHex(F.BusMessage);
end;

procedure TElmAdapter.Finish;
begin
  FStreaming := False;
  try
    Idle;
  except
    // the connection is gone already
  end;
end;

end.
