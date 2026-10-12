unit UVScan.Elm;

{ An ELM327 type adapter (Bluetooth, Wi-Fi or USB) on GM Class 2 (SAE
  J1850 VPW), over any ISerialPort.

  The ELM is a text device: a command is a line ending in CR ("ATSP2",
  "2A14FE000000"), the reply is lines of text ending in the '>' prompt. Bus
  messages go out as hex data bytes behind the header set with ATSH (the
  first three bytes: priority, target, source); with headers on (ATH1) each
  received message comes back as one hex line: header, data and the J1850
  CRC byte last. ATE0 / ATL0 / ATS0 keep the replies short: no echo, no line
  feeds, no spaces.

  After sending a request the ELM listens for answers until none has come
  for the response timeout (ATST); a stream of DPID frames therefore keeps
  it listening for as long as they keep coming. Any character sent to it
  then ends that ("STOPPED") and it shows the prompt again. }

interface

uses
  System.SysUtils, System.Classes, UVScan.Serial;

type
  EElmError = class(Exception);

  { One message received on the bus: header + data, without the CRC. }
  TElmFrame = TBytes;

  TElmLink = class
  private
    FPort: ISerialPort;
    FOnTraffic: TProc<string>;
    FRx: string;               // received text not yet taken as lines
    FHeader: TBytes;           // what ATSH last set
    FHeadersOn: Boolean;
    FLastMs: Cardinal;
    FListening: Boolean;       // sent something, the prompt has not come back yet
    procedure Trace(const Dir, Text: string);
    function Fill(TimeoutMs: Cardinal): Boolean;
  public
    constructor Create(const Port: ISerialPort; const OnTraffic: TProc<string> = nil);
    { Sends Cmd and returns the reply up to the prompt (the prompt left out,
      lines separated by CR). Raises EElmError when no prompt comes in time. }
    function Command(const Cmd: string; TimeoutMs: Cardinal = 2000): string;
    { Command, and the reply as lines (empty lines and an echo left out). }
    function CommandLines(const Cmd: string; TimeoutMs: Cardinal = 2000): TArray<string>;
    { Sets the 3-byte header (ATSH) unless it already is. }
    procedure SetHeader(const Header: TBytes);
    { Sends a whole Class 2 message (header + data: the header via ATSH) and
      returns the frames that came back before the prompt. Error words
      ("NO DATA", "BUS ERROR"...) go to Errors. }
    function Request(const Msg: TBytes; out Errors: string; TimeoutMs: Cardinal = 2000): TArray<TElmFrame>;
    { Sends Cmd without waiting for the prompt: the listening that follows is
      read with ReadLine. }
    procedure Send(const Cmd: string);
    { The next line received within TimeoutMs. Prompt is True when the ELM
      has stopped listening (the prompt came; Line is then ''). }
    function ReadLine(TimeoutMs: Cardinal; out Line: string; out Prompt: Boolean): Boolean;
    { Ends a listening (a request still receiving, ATMA): sends a character
      and waits for the prompt. Nothing when at the prompt already (a CR
      there would repeat the last command). }
    procedure Interrupt(TimeoutMs: Cardinal = 1000);
    { Sent something and the prompt has not come back yet. }
    property Listening: Boolean read FListening;
    { Drops anything received and not taken yet. }
    procedure Flush;
    property HeadersOn: Boolean read FHeadersOn write FHeadersOn;
    { How long the last Command / Request took to reach its prompt. }
    property LastMs: Cardinal read FLastMs;
    property Port: ISerialPort read FPort;
  end;

{ The frame on a reply line ("6CF1106A FE0C1A..."), CRC removed when
  HasCrc. False for a line that is not hex (an error word, "SEARCHING..."). }
function ParseElmFrame(const Line: string; HasCrc: Boolean; out Frame: TElmFrame): Boolean;
{ True for the ELM's error and status words. }
function IsElmMessage(const Line: string): Boolean;

implementation

uses
  System.Math, System.StrUtils, UVScan.Hex;

function IsHexLine(const S: string): Boolean;
var
  C: Char;
begin
  Result := (S <> '') and not Odd(Length(S));
  if Result then
    for C in S do
      if not CharInSet(C, ['0'..'9', 'A'..'F', 'a'..'f']) then
        Exit(False);
end;

function ParseElmFrame(const Line: string; HasCrc: Boolean; out Frame: TElmFrame): Boolean;
var
  S: string;
begin
  S := Line.Replace(' ', '');
  Result := IsHexLine(S);
  if not Result then
    Exit;
  Frame := HexToBytes(S);
  if HasCrc and (Length(Frame) > 0) then
    SetLength(Frame, Length(Frame) - 1);
  Result := Length(Frame) > 0;
end;

function IsElmMessage(const Line: string): Boolean;
var
  S: string;
begin
  S := Line.Trim.ToUpper;
  Result := (S = '?') or (S = 'OK') or S.Contains('NO DATA') or S.Contains('ERROR') or
    S.Contains('STOPPED') or S.Contains('BUFFER FULL') or S.Contains('UNABLE TO CONNECT') or
    S.StartsWith('SEARCHING') or S.StartsWith('BUS INIT') or S.StartsWith('ERR') or
    S.Contains('LV RESET') or S.Contains('OUT OF MEMORY') or S.StartsWith('ACT ALERT');
end;

{ TElmLink }

constructor TElmLink.Create(const Port: ISerialPort; const OnTraffic: TProc<string>);
begin
  inherited Create;
  FPort := Port;
  FOnTraffic := OnTraffic;
end;

procedure TElmLink.Trace(const Dir, Text: string);
begin
  if Assigned(FOnTraffic) then
    FOnTraffic(Dir + ' ' + Text.Replace(#13, '\r').Replace(#10, '\n'));
end;

{ Reads what has arrived (waiting up to TimeoutMs for something) into FRx. }
function TElmLink.Fill(TimeoutMs: Cardinal): Boolean;
var
  Buf: array[0..511] of Byte;
  N, I: Integer;
  S: string;
begin
  N := FPort.Read(Buf, SizeOf(Buf), TimeoutMs);
  Result := N > 0;
  if not Result then
    Exit;
  SetLength(S, N);
  for I := 0 to N - 1 do
    if Buf[I] = 0 then
      S[I + 1] := #13 // some clones send NULs
    else
      S[I + 1] := Char(Buf[I]);
  Trace('<', S);
  FRx := FRx + S;
end;

procedure TElmLink.Flush;
begin
  FRx := '';
  FPort.Purge;
end;

procedure TElmLink.Send(const Cmd: string);
begin
  Trace('>', Cmd);
  FListening := True;
  FPort.Write(TEncoding.ASCII.GetBytes(Cmd + #13));
end;

function TElmLink.Command(const Cmd: string; TimeoutMs: Cardinal): string;
var
  Start, Deadline, Now_: UInt64;
  P: Integer;
begin
  FRx := '';
  Start := TThread.GetTickCount64;
  Deadline := Start + TimeoutMs;
  Send(Cmd);
  repeat
    P := FRx.IndexOf('>');
    if P >= 0 then
    begin
      Result := FRx.Substring(0, P);
      FRx := FRx.Substring(P + 1);
      FListening := False;
      FLastMs := TThread.GetTickCount64 - Start;
      Exit;
    end;
    Now_ := TThread.GetTickCount64;
    if Now_ >= Deadline then
    begin
      FLastMs := Now_ - Start;
      raise EElmError.CreateFmt('No reply to %s in %d ms (got "%s")', [Cmd, TimeoutMs, FRx.Trim]);
    end;
    Fill(Cardinal(Deadline - Now_));
  until False;
end;

function TElmLink.CommandLines(const Cmd: string; TimeoutMs: Cardinal): TArray<string>;
var
  S: string;
begin
  Result := nil;
  for S in Command(Cmd, TimeoutMs).Split([#13, #10]) do
    if (S.Trim <> '') and not SameText(S.Trim, Cmd) then
      Result := Result + [S.Trim];
end;

procedure TElmLink.SetHeader(const Header: TBytes);
var
  R: string;
begin
  if SameBytes(Header, FHeader) then
    Exit;
  R := Command('ATSH' + BytesToHex(Header, ''));
  if not R.ToUpper.Contains('OK') then
    raise EElmError.CreateFmt('ATSH refused: %s', [R.Trim]);
  FHeader := Copy(Header);
end;

function TElmLink.Request(const Msg: TBytes; out Errors: string; TimeoutMs: Cardinal): TArray<TElmFrame>;
var
  Line: string;
  F: TElmFrame;
begin
  if Length(Msg) < 4 then
    raise EElmError.Create('A Class 2 message needs a header and a mode');
  SetHeader(Copy(Msg, 0, 3));
  Result := nil;
  Errors := '';
  for Line in CommandLines(BytesToHex(Copy(Msg, 3, MaxInt), ''), TimeoutMs) do
    if ParseElmFrame(Line, FHeadersOn, F) then
      Result := Result + [F]
    else
      Errors := Errors + IfThen(Errors <> '', ', ') + Line;
end;

function TElmLink.ReadLine(TimeoutMs: Cardinal; out Line: string; out Prompt: Boolean): Boolean;
var
  Deadline, Now_: UInt64;
  I: Integer;
begin
  Line := '';
  Prompt := False;
  Deadline := TThread.GetTickCount64 + TimeoutMs;
  repeat
    // A whole line, or the prompt, in what has arrived?
    while FRx <> '' do
    begin
      I := 1;
      while (I <= Length(FRx)) and not CharInSet(FRx[I], [#13, #10, '>']) do
        Inc(I);
      if I > Length(FRx) then
        Break; // only part of a line so far
      Line := Copy(FRx, 1, I - 1).Trim;
      if FRx[I] = '>' then
      begin
        Prompt := Line = '';
        FListening := FListening and not Prompt;
      end;
      if (FRx[I] = '>') and (Line <> '') then
        FRx := Copy(FRx, I, MaxInt) // the prompt again next time
      else
        FRx := Copy(FRx, I + 1, MaxInt);
      if Prompt or (Line <> '') then
        Exit(True);
    end;
    Now_ := TThread.GetTickCount64;
    if Now_ >= Deadline then
      Exit(False);
    Fill(Cardinal(Deadline - Now_));
  until False;
end;

procedure TElmLink.Interrupt(TimeoutMs: Cardinal);
var
  Deadline: UInt64;
begin
  if not FListening and not FRx.Contains('>') then
    Exit;
  if not FRx.Contains('>') then
  begin
    Trace('>', '(stop)');
    FPort.Write(TBytes.Create(Ord(' ')));
  end;
  Deadline := TThread.GetTickCount64 + TimeoutMs;
  while not FRx.Contains('>') and (TThread.GetTickCount64 < Deadline) do
    Fill(Max(1, Integer(Deadline - TThread.GetTickCount64)));
  FRx := '';
  FListening := False;
end;

end.
