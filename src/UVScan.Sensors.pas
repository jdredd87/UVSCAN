unit UVScan.Sensors;

(* Sensors: devices UVScan reads beside the vehicle while it scans - a
  wideband controller, an EGT box, an Arduino with an oil pressure sender.
  Each has a port of its own (serial, Bluetooth or a network address, as
  the adapter's can be) and a protocol:

    mts   Innovate's MTS serial protocol 2 (LC-1, LC-2, LM-1, LM-2, MTX-L,
          and the TC-4 / SSI-4 aux boxes chained to them): 19200 baud, a
          packet every 81.92 ms. Each wideband in the chain gives lambdaN,
          afrN (lambda x the AFR multiplier it is set to, 14.7 for petrol),
          statusN (0 = reading, 1 = O2 %, 2 = calibrating, 3 = needs free-air
          calibration, 4 = warming up, 5 = heater calibration, 6 = error) and
          while warming up warmupN (%); each aux input gives auxN
          (0..1023 for 0-5 V). Numbered in the chain's order from 1.
    text  Lines of text. Every number in a line is a field by its place (1,
          2, ...), and one written after a name ("egt=812", "AFR: 14.7") is
          also a field of that name (egt, afr; not case sensitive). For
          plain-text widebands (AEM X-Series) and anything an Arduino can
          print.

  What a sensor measures is shown by sensor PIDs (kind "sensor" in
  pids.json): the sensor's name, a field and a formula over the field's
  value (N0, as an analog PID's sample; no formula = the value as it is), so
  they scan, log, chart and set off alerts as any PID does.

  sensors.json:
    { "version": 1,
      "sensors": [
        { "name": "LC-1", "protocol": "mts", "port": "COM5", "baud": 19200 },
        { "name": "EGT", "protocol": "text", "port": "COM7", "baud": 9600,
          "send": "R\r", "sendEveryMs": 100, "enabled": false } ] }
    Optional: "description"; "send" is text sent every "sendEveryMs" to a
    device that answers when asked (\r, \n, \t and \\ as in C).
    The port "Simulator" is a made-up device of that protocol (a demo).

  A sensor shared as a file (*.uvsensor, JSON): the sensor and its PIDs.
    { "uvscanSensor": 1, "sensor": { ... }, "pids": [ { ... no "id" } ] } *)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs, System.Diagnostics,
  System.JSON, UVScan.Serial, UVScan.Pids;

type
  TSensorProtocol = (spMts, spText);

  TSensorDef = class
  public
    Name: string;
    Description: string;
    Protocol: TSensorProtocol;
    Port: string;
    Baud: Integer;
    Send: string;          // as written in the file: \r etc. not turned into characters yet
    SendEveryMs: Integer;
    Enabled: Boolean;
    constructor Create;
    procedure Assign(Source: TSensorDef);
    function Clone: TSensorDef;
    function ToJson: TJSONObject;
    { Raises EConvertError for an entry that cannot be used. }
    class function FromJson(E: TJSONObject): TSensorDef;
  end;

  TSensorCatalog = class
  private
    FItems: TObjectList<TSensorDef>;
    FWarnings: TStringList;
    function GetCount: Integer;
    function GetItem(Index: Integer): TSensorDef;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Assign(Source: TSensorCatalog);
    procedure LoadFromJson(Root: TJSONObject);
    { A missing file is an empty catalog. }
    procedure LoadFromFile(const FileName: string);
    function ToJson: TJSONObject;
    procedure SaveToFile(const FileName: string);
    procedure Add(D: TSensorDef);
    procedure Delete(Index: Integer);
    function IndexOf(const Name: string): Integer;
    function Find(const Name: string): TSensorDef;
    { Name, or Name 2, Name 3 ... whichever is free. }
    function FreeName(const Name: string): string;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TSensorDef read GetItem; default;
    property Warnings: TStringList read FWarnings;
  end;

  TSensorEmit = reference to procedure(const Field: string; Value: Double);

  { Turns a sensor's bytes into field values. }
  TSensorParser = class
  protected
    FLast: string;
    FNote: string;
    FCount: Int64;
  public
    procedure Push(const Data: TBytes; Count: Integer; const Emit: TSensorEmit); virtual; abstract;
    { The last packet (hex) or line, for a test view. }
    property Last: string read FLast;
    { What the device says about itself when it is not just reading
      (warming up, needs calibration); '' while all is well. }
    property Note: string read FNote;
    { Packets or lines decoded so far. }
    property Count: Int64 read FCount;
  end;

  TMtsParser = class(TSensorParser)
  private
    FBuf: TBytes;
    FLen: Integer;
    procedure Decode(Start, Words: Integer; const Emit: TSensorEmit);
    procedure Drop(N: Integer);
  public
    procedure Push(const Data: TBytes; Count: Integer; const Emit: TSensorEmit); override;
  end;

  TTextParser = class(TSensorParser)
  private
    FLine: TStringBuilder;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Push(const Data: TBytes; Count: Integer; const Emit: TSensorEmit); override;
    class procedure ParseLine(const Line: string; const Emit: TSensorEmit);
  end;

  TSensorField = record
    Name: string;
    Value: Double;
    AgeMs: Int64;
  end;

  TSensorPortFactory = reference to function(Def: TSensorDef): ISerialPort;

  { Reads one sensor on a thread of its own, from Create to Free, opening
    its port again when it is lost. The latest value of each field is kept
    for whoever asks (the scan engine, the test view). }
  TSensorReader = class(TThread)
  private
    FDef: TSensorDef;
    FFactory: TSensorPortFactory;
    FLock: TCriticalSection;
    FValues: TDictionary<string, TSensorField>;
    FClock: TStopwatch;
    FStatus: string;
    FStatusChanged: Boolean;
    FLast: string;
    FPackets: Int64;
    procedure SetStatus(const S: string);
    procedure Pause(Ms: Integer);
  protected
    procedure Execute; override;
  public
    { Starts reading a copy of Def. Factory: the port (nil: CreateSensorPort). }
    constructor Create(Def: TSensorDef; const Factory: TSensorPortFactory = nil);
    destructor Destroy; override;
    { The field's value if one came within MaxAgeMs. }
    function TryGet(const Field: string; MaxAgeMs: Int64; out Value: Double): Boolean;
    function Fields: TArray<TSensorField>;
    function Status: string;
    { The status, once each time it changes. }
    function TakeStatusChange(out S: string): Boolean;
    function LastData: string;
    function Packets: Int64;
    property Def: TSensorDef read FDef;
  end;

  { A sensor template: a sensor file built in. }
  TSensorTemplate = record
    Title: string;
    Hint: string;
    Json: string;
  end;

const
  SensorFileVersion = 1;
  SensorPackageVersion = 1;
  SensorProtocolKeys: array[TSensorProtocol] of string = ('mts', 'text');
  SensorProtocolNames: array[TSensorProtocol] of string = ('Innovate MTS (LC-1, LC-2, LM-2...)',
    'Text lines (AEM, Arduino...)');
  SensorProtocolBaud: array[TSensorProtocol] of Integer = (19200, 9600);
  SensorSimulatorPort = 'Simulator';
  SensorFileExt = '.uvsensor';
  { A value older than this is no reading (the sensor stopped sending). }
  SensorMaxAgeMs = 3000;

function SensorProtocolFromKey(const Key: string; out P: TSensorProtocol): Boolean;
function CreateSensorParser(P: TSensorProtocol): TSensorParser;
{ The port Def names (or the simulator), not opened yet. }
function CreateSensorPort(Def: TSensorDef): ISerialPort;
{ "R\r" -> R and a carriage return. }
function UnescapeSensorText(const S: string): string;

{ One MTS packet: per wideband its status, AFR multiplier (147 = 14.7) and
  lambda (as sent: lambda x 1000 - 500), then the aux inputs (0..1023). }
type
  TMtsLambda = record
    Status: Integer;
    Multiplier: Integer;
    Raw: Integer;
  end;
function MtsLambda(Status, Multiplier, Raw: Integer): TMtsLambda;
function BuildMtsPacket(const Lambdas: array of TMtsLambda; const Aux: array of Integer): TBytes;
function MtsStatusText(Status: Integer): string;

{ Shared sensor files. }
function SensorPackage(Def: TSensorDef; const Pids: array of TPidDef): TJSONObject;
{ Adds the sensor in Root (a sensor file) to Sensors and its PIDs to
  Catalog: the sensor renamed if its name is taken (and its PIDs with it),
  the PIDs given new ids, a taken MCI made free with a number. Returns the
  sensor's name as added; AddedPids = their ids. Raises EConvertError for a
  file that is no sensor file. }
function ImportSensorPackage(Root: TJSONObject; Sensors: TSensorCatalog; Catalog: TPidCatalog;
  out AddedPids: TArray<Integer>): string;
function SensorTemplates: TArray<TSensorTemplate>;

implementation

uses
  System.Math, System.StrUtils, System.Character, System.Generics.Defaults, UVScan.JsonFile, UVScan.Hex;

function SensorProtocolFromKey(const Key: string; out P: TSensorProtocol): Boolean;
var
  K: TSensorProtocol;
begin
  for K := Low(TSensorProtocol) to High(TSensorProtocol) do
    if SameText(Key, SensorProtocolKeys[K]) then
    begin
      P := K;
      Exit(True);
    end;
  Result := False;
end;

function UnescapeSensorText(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '\') and (I < Length(S)) then
    begin
      Inc(I);
      case S[I] of
        'r': Result := Result + #13;
        'n': Result := Result + #10;
        't': Result := Result + #9;
      else
        Result := Result + S[I];
      end;
    end
    else
      Result := Result + S[I];
    Inc(I);
  end;
end;

{ TSensorDef }

constructor TSensorDef.Create;
begin
  inherited;
  Protocol := spMts;
  Baud := SensorProtocolBaud[spMts];
  Enabled := True;
end;

procedure TSensorDef.Assign(Source: TSensorDef);
begin
  Name := Source.Name;
  Description := Source.Description;
  Protocol := Source.Protocol;
  Port := Source.Port;
  Baud := Source.Baud;
  Send := Source.Send;
  SendEveryMs := Source.SendEveryMs;
  Enabled := Source.Enabled;
end;

function TSensorDef.Clone: TSensorDef;
begin
  Result := TSensorDef.Create;
  Result.Assign(Self);
end;

function TSensorDef.ToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', Name);
  if Description <> '' then
    Result.AddPair('description', Description);
  Result.AddPair('protocol', SensorProtocolKeys[Protocol]);
  Result.AddPair('port', Port);
  Result.AddPair('baud', TJSONNumber.Create(Baud));
  if Send <> '' then
  begin
    Result.AddPair('send', Send);
    Result.AddPair('sendEveryMs', TJSONNumber.Create(SendEveryMs));
  end;
  if not Enabled then
    Result.AddPair('enabled', TJSONBool.Create(False));
end;

class function TSensorDef.FromJson(E: TJSONObject): TSensorDef;
var
  P: TSensorProtocol;
begin
  Result := TSensorDef.Create;
  try
    Result.Name := Trim(JStr(E, 'name'));
    if Result.Name = '' then
      raise EConvertError.Create('a sensor without a "name"');
    if not SensorProtocolFromKey(JStr(E, 'protocol'), P) then
      raise EConvertError.CreateFmt('sensor "%s": unknown protocol "%s" (mts or text)',
        [Result.Name, JStr(E, 'protocol')]);
    Result.Protocol := P;
    Result.Description := Trim(JStr(E, 'description'));
    Result.Port := Trim(JStr(E, 'port'));
    Result.Baud := JInt(E, 'baud', SensorProtocolBaud[P]);
    if Result.Baud <= 0 then
      Result.Baud := SensorProtocolBaud[P];
    Result.Send := JStr(E, 'send');
    Result.SendEveryMs := Max(0, JInt(E, 'sendEveryMs', 0));
    if (Result.Send <> '') and (Result.SendEveryMs = 0) then
      Result.SendEveryMs := 1000;
    Result.Enabled := JBool(E, 'enabled', True);
  except
    Result.Free;
    raise;
  end;
end;

{ TSensorCatalog }

constructor TSensorCatalog.Create;
begin
  inherited;
  FItems := TObjectList<TSensorDef>.Create(True);
  FWarnings := TStringList.Create;
end;

destructor TSensorCatalog.Destroy;
begin
  FItems.Free;
  FWarnings.Free;
  inherited;
end;

function TSensorCatalog.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TSensorCatalog.GetItem(Index: Integer): TSensorDef;
begin
  Result := FItems[Index];
end;

procedure TSensorCatalog.Clear;
begin
  FItems.Clear;
  FWarnings.Clear;
end;

procedure TSensorCatalog.Assign(Source: TSensorCatalog);
var
  D: TSensorDef;
begin
  FItems.Clear;
  for D in Source.FItems do
    FItems.Add(D.Clone);
end;

procedure TSensorCatalog.LoadFromJson(Root: TJSONObject);
var
  Arr: TJSONArray;
  V: TJSONValue;
  D: TSensorDef;
begin
  Clear;
  if JInt(Root, 'version', SensorFileVersion) > SensorFileVersion then
    FWarnings.Add('sensors.json was written by a newer UVScan; unknown fields are ignored');
  Arr := JArr(Root, 'sensors');
  if Arr = nil then
    Exit;
  for V in Arr do
  begin
    if not (V is TJSONObject) then
      Continue;
    try
      D := TSensorDef.FromJson(TJSONObject(V));
    except
      on E: EConvertError do
      begin
        FWarnings.Add(E.Message);
        Continue;
      end;
    end;
    if IndexOf(D.Name) >= 0 then
    begin
      FWarnings.Add(Format('a second sensor called "%s" is left out', [D.Name]));
      D.Free;
      Continue;
    end;
    FItems.Add(D);
  end;
end;

procedure TSensorCatalog.LoadFromFile(const FileName: string);
var
  Root: TJSONObject;
begin
  Clear;
  if not FileExists(FileName) then
    Exit;
  Root := ReadJsonObject(FileName);
  try
    LoadFromJson(Root);
  finally
    Root.Free;
  end;
end;

function TSensorCatalog.ToJson: TJSONObject;
var
  Arr: TJSONArray;
  D: TSensorDef;
begin
  Result := TJSONObject.Create;
  Result.AddPair('version', TJSONNumber.Create(SensorFileVersion));
  Arr := TJSONArray.Create;
  for D in FItems do
    Arr.AddElement(D.ToJson);
  Result.AddPair('sensors', Arr);
end;

procedure TSensorCatalog.SaveToFile(const FileName: string);
var
  Root: TJSONObject;
begin
  Root := ToJson;
  try
    WriteJsonFile(FileName, Root);
  finally
    Root.Free;
  end;
end;

procedure TSensorCatalog.Add(D: TSensorDef);
begin
  FItems.Add(D);
end;

procedure TSensorCatalog.Delete(Index: Integer);
begin
  FItems.Delete(Index);
end;

function TSensorCatalog.IndexOf(const Name: string): Integer;
begin
  for Result := 0 to FItems.Count - 1 do
    if SameText(FItems[Result].Name, Trim(Name)) then
      Exit;
  Result := -1;
end;

function TSensorCatalog.Find(const Name: string): TSensorDef;
var
  I: Integer;
begin
  I := IndexOf(Name);
  if I >= 0 then
    Result := FItems[I]
  else
    Result := nil;
end;

function TSensorCatalog.FreeName(const Name: string): string;
var
  N: Integer;
begin
  Result := Name;
  N := 1;
  while IndexOf(Result) >= 0 do
  begin
    Inc(N);
    Result := Format('%s %d', [Name, N]);
  end;
end;

{ MTS }

function MtsLambda(Status, Multiplier, Raw: Integer): TMtsLambda;
begin
  Result.Status := Status;
  Result.Multiplier := Multiplier;
  Result.Raw := Raw;
end;

{ Words are big-endian; only a packet's header has bit 7 set in its bytes.
    header   1 R 1 S C x 1 L7 | 1 L6..L0   (bits 15, 13, 9, 7 set; L = words that follow;
             R = recording, S = sensor data, C = can log)
    lambda   0 1 0 F2 F1 F0 1 M7 | 0 M6..M0, then 0 0 L12..L7 | 0 L6..L0
    aux      0 0 0 0 0 A9 A8 A7 | 0 A6..A0 }
function BuildMtsPacket(const Lambdas: array of TMtsLambda; const Aux: array of Integer): TBytes;
var
  Words, I, P: Integer;
  L: TMtsLambda;
begin
  Words := Length(Lambdas) * 2 + Length(Aux);
  SetLength(Result, 2 + Words * 2);
  Result[0] := $A2 or $10 or ((Words shr 7) and 1);
  Result[1] := $80 or (Words and $7F);
  P := 2;
  for L in Lambdas do
  begin
    Result[P] := $42 or ((L.Status and 7) shl 2) or ((L.Multiplier shr 7) and 1);
    Result[P + 1] := L.Multiplier and $7F;
    Result[P + 2] := (L.Raw shr 7) and $3F;
    Result[P + 3] := L.Raw and $7F;
    Inc(P, 4);
  end;
  for I in Aux do
  begin
    Result[P] := (I shr 7) and $07;
    Result[P + 1] := I and $7F;
    Inc(P, 2);
  end;
end;

function MtsStatusText(Status: Integer): string;
begin
  case Status of
    0: Result := 'reading';
    1: Result := 'showing O2 %';
    2: Result := 'free-air calibration';
    3: Result := 'needs a free-air calibration';
    4: Result := 'warming up';
    5: Result := 'heater calibration';
    6: Result := 'sensor error';
  else
    Result := 'status ' + IntToStr(Status);
  end;
end;

procedure TMtsParser.Decode(Start, Words: Integer; const Emit: TSensorEmit);
var
  I, NLambda, NAux, Status, Mult, Raw: Integer;
  B0, B1: Byte;
  Lambda: Double;
  Notes: string;
begin
  NLambda := 0;
  NAux := 0;
  Notes := '';
  I := 0;
  while I < Words do
  begin
    B0 := FBuf[Start + I * 2];
    B1 := FBuf[Start + I * 2 + 1];
    if ((B0 and $E2) = $42) and (I + 1 < Words) then
    begin
      Inc(NLambda);
      Status := (B0 shr 2) and 7;
      Mult := ((B0 and 1) shl 7) or (B1 and $7F);
      Raw := ((FBuf[Start + I * 2 + 2] and $3F) shl 7) or (FBuf[Start + I * 2 + 3] and $7F);
      Emit('status' + IntToStr(NLambda), Status);
      if Status = 0 then
      begin
        Lambda := (Raw + 500) / 1000;
        Emit('lambda' + IntToStr(NLambda), Lambda);
        Emit('afr' + IntToStr(NLambda), Lambda * Mult / 10);
      end
      else
      begin
        Emit('lambda' + IntToStr(NLambda), NaN);
        Emit('afr' + IntToStr(NLambda), NaN);
        if Status = 4 then
          Emit('warmup' + IntToStr(NLambda), Raw / 10);
        Notes := Notes + IfThen(Notes <> '', ', ') +
          IfThen(NLambda > 1, Format('wideband %d ', [NLambda])) + MtsStatusText(Status) +
          IfThen(Status = 6, ' ' + IntToStr(Raw));
      end;
      Inc(I, 2);
    end
    else
    begin
      if (B0 and $C0) = 0 then
      begin
        Inc(NAux);
        Emit('aux' + IntToStr(NAux), ((B0 and $07) shl 7) or (B1 and $7F));
      end;
      Inc(I);
    end;
  end;
  FNote := Notes;
end;

procedure TMtsParser.Drop(N: Integer);
begin
  if N <= 0 then
    Exit;
  if N < FLen then
    Move(PByte(FBuf)[N], PByte(FBuf)[0], FLen - N);
  Dec(FLen, Min(N, FLen));
end;

procedure TMtsParser.Push(const Data: TBytes; Count: Integer; const Emit: TSensorEmit);
var
  I, Words, Need, Skip: Integer;
  Bad: Boolean;
begin
  if Count <= 0 then
    Exit;
  if FLen + Count > Length(FBuf) then
    SetLength(FBuf, Max(1024, FLen + Count));
  Move(Data[0], FBuf[FLen], Count);
  Inc(FLen, Count);
  repeat
    // A header: both bytes with bit 7 set, the first 1x1xxx1x.
    Skip := 0;
    while (Skip + 1 < FLen) and not (((FBuf[Skip] and $A2) = $A2) and ((FBuf[Skip + 1] and $80) <> 0)) do
      Inc(Skip);
    Drop(Skip);
    if FLen < 2 then
      Break;
    Words := ((FBuf[0] and 1) shl 7) or (FBuf[1] and $7F);
    Need := 2 + Words * 2;
    // A byte with bit 7 set inside is the next packet's header: this one
    // was cut short (the stream started in the middle, bytes were lost).
    Bad := False;
    for I := 2 to Min(Need, FLen) - 1 do
      if (FBuf[I] and $80) <> 0 then
      begin
        Bad := True;
        Break;
      end;
    if Bad then
    begin
      Drop(1);
      Continue;
    end;
    if FLen < Need then
      Break;
    FLast := BytesToHex(Copy(FBuf, 0, Need));
    Inc(FCount);
    Decode(2, Words, Emit);
    Drop(Need);
  until False;
  if FLen > 4096 then
    FLen := 0; // no header in all that: not MTS
end;

{ Text }

constructor TTextParser.Create;
begin
  inherited;
  FLine := TStringBuilder.Create;
end;

destructor TTextParser.Destroy;
begin
  FLine.Free;
  inherited;
end;

procedure TTextParser.Push(const Data: TBytes; Count: Integer; const Emit: TSensorEmit);
var
  I: Integer;
  C: Char;
begin
  for I := 0 to Count - 1 do
  begin
    C := Char(Data[I]);
    if (C = #13) or (C = #10) then
    begin
      if FLine.Length > 0 then
      begin
        FLast := FLine.ToString;
        FLine.Clear;
        Inc(FCount);
        ParseLine(FLast, Emit);
      end;
    end
    else if FLine.Length < 1024 then
      FLine.Append(C);
  end;
end;

class procedure TTextParser.ParseLine(const Line: string; const Emit: TSensorEmit);
var
  I, J, K, N, Len: Integer;
  Value: Double;
  Key: string;

  function IsDigit(P: Integer): Boolean;
  begin
    Result := (P >= 1) and (P <= Len) and CharInSet(Line[P], ['0'..'9']);
  end;

  function IsWordChar(P: Integer): Boolean;
  begin
    Result := (P >= 1) and (P <= Len) and (Line[P].IsLetterOrDigit or (Line[P] = '_'));
  end;

begin
  Len := Length(Line);
  N := 0;
  I := 1;
  while I <= Len do
  begin
    // A number: digits with a point, maybe a sign in front; not the digits
    // of a word (T1, EGT2).
    if (IsDigit(I) or ((Line[I] = '.') and IsDigit(I + 1)) or
      (CharInSet(Line[I], ['-', '+']) and (IsDigit(I + 1) or ((I + 1 <= Len) and (Line[I + 1] = '.') and IsDigit(I + 2)))))
      and not IsWordChar(I - 1) and not ((I > 1) and (Line[I - 1] = '.')) then
    begin
      J := I;
      if CharInSet(Line[J], ['-', '+']) then
        Inc(J);
      while IsDigit(J) do
        Inc(J);
      if (J <= Len) and (Line[J] = '.') then
      begin
        Inc(J);
        while IsDigit(J) do
          Inc(J);
      end;
      if TryStrToFloat(Copy(Line, I, J - I), Value, TFormatSettings.Invariant) then
      begin
        Inc(N);
        Emit(IntToStr(N), Value);
        // name=12 / name: 12
        K := I - 1;
        while (K >= 1) and (Line[K] = ' ') do
          Dec(K);
        if (K >= 1) and CharInSet(Line[K], ['=', ':']) then
        begin
          Dec(K);
          while (K >= 1) and (Line[K] = ' ') do
            Dec(K);
          Key := '';
          while IsWordChar(K) do
          begin
            Key := Line[K] + Key;
            Dec(K);
          end;
          if (Key <> '') and Key[1].IsLetter then
            Emit(LowerCase(Key), Value);
        end;
      end;
      I := J;
    end
    else
      Inc(I);
  end;
end;

function CreateSensorParser(P: TSensorProtocol): TSensorParser;
begin
  case P of
    spText: Result := TTextParser.Create;
  else
    Result := TMtsParser.Create;
  end;
end;

{ Simulator }

type
  { A made-up sensor: an LC-1 with an aux box behind it (mts) or a box
    printing afr, egt and oil pressure lines (text). Warms up for 2 s. }
  TSimulatedSensor = class(TInterfacedObject, ISerialPort)
  private
    FProtocol: TSensorProtocol;
    FOpen: Boolean;
    FClock: TStopwatch;
    FNextMs: Int64;
  public
    constructor Create(Protocol: TSensorProtocol);
    procedure Open;
    procedure Close;
    function IsOpen: Boolean;
    function Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
    procedure Write(const Data: TBytes);
    procedure Purge;
    function Description: string;
  end;

constructor TSimulatedSensor.Create(Protocol: TSensorProtocol);
begin
  inherited Create;
  FProtocol := Protocol;
end;

procedure TSimulatedSensor.Open;
begin
  FOpen := True;
  FClock := TStopwatch.StartNew;
  FNextMs := 0;
end;

procedure TSimulatedSensor.Close;
begin
  FOpen := False;
end;

function TSimulatedSensor.IsOpen: Boolean;
begin
  Result := FOpen;
end;

function TSimulatedSensor.Read(var Buffer; Count: Integer; TimeoutMs: Cardinal): Integer;
var
  T, Lambda: Double;
  Now_: Int64;
  Data: TBytes;
  Wait: Int64;
begin
  if not FOpen then
    raise ESerialError.Create('The simulated sensor is not open');
  Now_ := FClock.ElapsedMilliseconds;
  Wait := FNextMs - Now_;
  if Wait > 0 then
  begin
    if Wait > TimeoutMs then
    begin
      Sleep(TimeoutMs);
      Exit(0);
    end;
    Sleep(Wait);
  end;
  T := FClock.Elapsed.TotalSeconds;
  // Rich under load, lean on overrun, about stoichiometric between.
  Lambda := 0.98 + 0.1 * Sin(T / 2.3) - 0.07 * Max(0, Sin(T / 5.1)) + (Random - 0.5) * 0.01;
  case FProtocol of
    spText:
      begin
        Data := TEncoding.ASCII.GetBytes(Format('afr=%.2f egt=%d oilp=%.1f'#13#10,
          [Lambda * 14.7, Round(650 + 120 * Sin(T / 4)), 40 + 8 * Sin(T / 3)], TFormatSettings.Invariant));
        FNextMs := FClock.ElapsedMilliseconds + 100;
      end;
  else
    if T < 2 then
      Data := BuildMtsPacket([MtsLambda(4, 147, Round(T * 500))], [512, 300])
    else
      Data := BuildMtsPacket([MtsLambda(0, 147, Round(Lambda * 1000) - 500)],
        [Round(512 + 300 * Sin(T / 4)), Round(300 + 50 * Sin(T / 3))]);
    FNextMs := FClock.ElapsedMilliseconds + 82;
  end;
  Result := Min(Count, Length(Data));
  Move(Data[0], Buffer, Result);
end;

procedure TSimulatedSensor.Write(const Data: TBytes);
begin
end;

procedure TSimulatedSensor.Purge;
begin
end;

function TSimulatedSensor.Description: string;
begin
  Result := SensorSimulatorPort;
end;

function CreateSensorPort(Def: TSensorDef): ISerialPort;
begin
  if SameText(Def.Port, SensorSimulatorPort) then
    Result := TSimulatedSensor.Create(Def.Protocol)
  else if Trim(Def.Port) = '' then
    raise ESerialError.CreateFmt('No port chosen for the sensor "%s"', [Def.Name])
  else
    Result := CreatePort(Def.Port, Def.Baud, fcNone);
end;

{ TSensorReader }

constructor TSensorReader.Create(Def: TSensorDef; const Factory: TSensorPortFactory);
begin
  FDef := Def.Clone;
  FFactory := Factory;
  FLock := TCriticalSection.Create;
  FValues := TDictionary<string, TSensorField>.Create;
  FClock := TStopwatch.StartNew;
  FStatus := 'Opening ' + FDef.Port;
  inherited Create(False);
end;

destructor TSensorReader.Destroy;
begin
  Terminate;
  inherited; // waits for Execute
  FValues.Free;
  FLock.Free;
  FDef.Free;
end;

procedure TSensorReader.SetStatus(const S: string);
begin
  FLock.Enter;
  try
    if S <> FStatus then
    begin
      FStatus := S;
      FStatusChanged := True;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSensorReader.Pause(Ms: Integer);
var
  Clock: TStopwatch;
begin
  Clock := TStopwatch.StartNew;
  while not Terminated and (Clock.ElapsedMilliseconds < Ms) do
    Sleep(50);
end;

procedure TSensorReader.Execute;
var
  Port: ISerialPort;
  Parser: TSensorParser;
  Buf: TBytes;
  N: Integer;
  Before: Int64;
  Got: Boolean;
  LastData, LastSend: TStopwatch;
  ToSend: TBytes;
  Where: string;
  Emit: TSensorEmit;
begin
  SetLength(Buf, 512);
  ToSend := nil;
  if FDef.Send <> '' then
    ToSend := TEncoding.ASCII.GetBytes(UnescapeSensorText(FDef.Send));
  Emit :=
    procedure(const Field: string; Value: Double)
    var
      F: TSensorField;
    begin
      F.Name := Field;
      F.Value := Value;
      F.AgeMs := FClock.ElapsedMilliseconds; // when it came; TryGet works out the age
      FLock.Enter;
      try
        FValues.AddOrSetValue(Field, F);
      finally
        FLock.Leave;
      end;
    end;
  Where := FDef.Port;
  while not Terminated do
  begin
    Parser := CreateSensorParser(FDef.Protocol);
    try
      try
        if Assigned(FFactory) then
          Port := FFactory(FDef)
        else
          Port := CreateSensorPort(FDef);
        Where := Port.Description;
        Port.Open;
        SetStatus('Waiting for data on ' + Where);
        Got := False;
        LastData := TStopwatch.StartNew;
        LastSend := TStopwatch.StartNew;
        if ToSend <> nil then
          Port.Write(ToSend);
        while not Terminated do
        begin
          if (ToSend <> nil) and (LastSend.ElapsedMilliseconds >= FDef.SendEveryMs) then
          begin
            Port.Write(ToSend);
            LastSend := TStopwatch.StartNew;
          end;
          N := Port.Read(Buf[0], Length(Buf), 100);
          if N > 0 then
          begin
            Before := Parser.Count;
            Parser.Push(Buf, N, Emit);
            if Parser.Count <> Before then
            begin
              FLock.Enter;
              try
                Inc(FPackets, Parser.Count - Before);
                FLast := Parser.Last;
              finally
                FLock.Leave;
              end;
              Got := True;
              LastData := TStopwatch.StartNew;
              SetStatus('Reading ' + Where + IfThen(Parser.Note <> '', ': ' + Parser.Note));
            end;
          end;
          if LastData.ElapsedMilliseconds >= SensorMaxAgeMs then
            if Got then
              SetStatus('No data from ' + Where + ' for 3 seconds')
            else if FDef.Protocol = spMts then
              SetStatus(Format('Nothing it understands from %s yet. MTS is %d baud; check the cable and that the sensor has power.',
                [Where, SensorProtocolBaud[spMts]]))
            else
              SetStatus(Format('No lines of text from %s yet: check the cable, power and baud rate (%d)', [Where, FDef.Baud]));
        end;
      except
        on E: Exception do
        begin
          SetStatus(Format('%s: %s. Trying again.', [Where, E.Message]));
          Port := nil;
          Pause(3000);
        end;
      end;
    finally
      Parser.Free;
      if Port <> nil then
        try
          Port.Close;
        except
          // gone already
        end;
      Port := nil;
    end;
  end;
end;

function TSensorReader.TryGet(const Field: string; MaxAgeMs: Int64; out Value: Double): Boolean;
var
  F: TSensorField;
begin
  FLock.Enter;
  try
    Result := FValues.TryGetValue(LowerCase(Field), F) and (FClock.ElapsedMilliseconds - F.AgeMs <= MaxAgeMs);
  finally
    FLock.Leave;
  end;
  if Result then
    Value := F.Value
  else
    Value := NaN;
end;

function TSensorReader.Fields: TArray<TSensorField>;
var
  Now_: Int64;
  I: Integer;
begin
  FLock.Enter;
  try
    Result := FValues.Values.ToArray;
    Now_ := FClock.ElapsedMilliseconds;
  finally
    FLock.Leave;
  end;
  for I := 0 to High(Result) do
    Result[I].AgeMs := Now_ - Result[I].AgeMs;
  TArray.Sort<TSensorField>(Result, TComparer<TSensorField>.Construct(
    function(const A, B: TSensorField): Integer
    var
      NA, NB: Integer;
    begin
      // 1, 2, 10 in that order; names after the numbers
      if TryStrToInt(A.Name, NA) and TryStrToInt(B.Name, NB) then
        Result := NA - NB
      else if TryStrToInt(A.Name, NA) then
        Result := -1
      else if TryStrToInt(B.Name, NB) then
        Result := 1
      else
        Result := CompareText(A.Name, B.Name);
    end));
end;

function TSensorReader.Status: string;
begin
  FLock.Enter;
  try
    Result := FStatus;
  finally
    FLock.Leave;
  end;
end;

function TSensorReader.TakeStatusChange(out S: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FStatusChanged;
    FStatusChanged := False;
    S := FStatus;
  finally
    FLock.Leave;
  end;
end;

function TSensorReader.LastData: string;
begin
  FLock.Enter;
  try
    Result := FLast;
  finally
    FLock.Leave;
  end;
end;

function TSensorReader.Packets: Int64;
begin
  FLock.Enter;
  try
    Result := FPackets;
  finally
    FLock.Leave;
  end;
end;

{ Sensor files }

function SensorPackage(Def: TSensorDef; const Pids: array of TPidDef): TJSONObject;
var
  Arr: TJSONArray;
  P: TPidDef;
  J: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('uvscanSensor', TJSONNumber.Create(SensorPackageVersion));
  J := Def.ToJson;
  J.RemovePair('port').Free;  // the other person's port is theirs to pick
  J.RemovePair('enabled').Free;
  Result.AddPair('sensor', J);
  Arr := TJSONArray.Create;
  for P in Pids do
  begin
    J := P.ToJson;
    J.RemovePair('id').Free;
    J.RemovePair('sensor').Free; // the sensor in this file
    Arr.AddElement(J);
  end;
  Result.AddPair('pids', Arr);
end;

function ImportSensorPackage(Root: TJSONObject; Sensors: TSensorCatalog; Catalog: TPidCatalog;
  out AddedPids: TArray<Integer>): string;
var
  SJ, Copy_: TJSONObject;
  Arr, Fixed: TJSONArray;
  Def: TSensorDef;
  Tmp: TPidCatalog;
  Wrapper: TJSONObject;
  I, N: Integer;
  P: TPidDef;
  Mci: string;
begin
  AddedPids := nil;
  if JInt(Root, 'uvscanSensor', 0) < 1 then
    raise EConvertError.Create('This is not a UVScan sensor file');
  SJ := JObj(Root, 'sensor');
  if SJ = nil then
    raise EConvertError.Create('The sensor file has no "sensor"');
  Def := TSensorDef.FromJson(SJ);
  try
    Def.Name := Sensors.FreeName(Def.Name);
    // The PIDs, read as a pids.json of their own (the same checks).
    Fixed := TJSONArray.Create;
    Wrapper := TJSONObject.Create;
    Tmp := TPidCatalog.Create;
    try
      Wrapper.AddPair('pids', Fixed);
      Arr := JArr(Root, 'pids');
      N := 0;
      if Arr <> nil then
        for I := 0 to Arr.Count - 1 do
          if Arr.Items[I] is TJSONObject then
          begin
            Copy_ := TJSONObject(TJSONObject(Arr.Items[I]).Clone);
            Copy_.RemovePair('id').Free;
            Copy_.RemovePair('sensor').Free;
            Inc(N);
            Copy_.AddPair('id', TJSONNumber.Create(N));
            Copy_.AddPair('sensor', Def.Name);
            Fixed.AddElement(Copy_);
          end;
      Tmp.LoadFromJson(Wrapper);
      if Tmp.Warnings.Count > 0 then
        raise EConvertError.Create('The sensor file''s PIDs: ' + Tmp.Warnings[0]);
      Sensors.Add(Def);
      Result := Def.Name;
      Def := nil;
      for I := 0 to Tmp.Count - 1 do
      begin
        P := TPidDef.Create;
        P.Assign(Tmp[I]);
        P.Id := Catalog.NextFreeId;
        if P.Mci <> '' then
        begin
          Mci := P.Mci;
          N := 1;
          while Catalog.FindByMci(Mci) <> nil do
          begin
            Inc(N);
            Mci := P.Mci + IntToStr(N);
          end;
          P.Mci := Mci;
        end;
        Catalog.Add(P);
        AddedPids := AddedPids + [P.Id];
      end;
    finally
      Tmp.Free;
      Wrapper.Free;
    end;
  finally
    Def.Free;
  end;
end;

function SensorTemplates: TArray<TSensorTemplate>;

  function T(const Title, Hint, Json: string): TSensorTemplate;
  begin
    Result.Title := Title;
    Result.Hint := Hint;
    Result.Json := Json;
  end;

const
  WidebandPids =
    '"pids": [' +
    '{ "name": "Wideband AFR", "shortName": "WB AFR", "kind": "sensor", "category": "sensors", "field": "afr1", ' +
    '"units": "AFR", "mci": "WBAFR", "description": "Air/fuel ratio from the wideband (lambda x its AFR multiplier)" },' +
    '{ "name": "Wideband lambda", "shortName": "WB Lambda", "kind": "sensor", "category": "sensors", "field": "lambda1", ' +
    '"units": "lambda", "mci": "WBLAMBDA" } ]';
begin
  Result := [
    T('Innovate LC-1, LC-2, LM-2, MTX-L',
      'MTS serial out, 19200 baud: AFR and lambda (aux inputs as aux1, aux2...)',
      '{ "uvscanSensor": 1, "sensor": { "name": "Wideband", "protocol": "mts", "baud": 19200, ' +
      '"description": "Innovate wideband on its serial out (MTS)" }, ' + WidebandPids + ' }'),
    T('AEM X-Series / UEGO (serial out)',
      'Text lines of AFR, 9600 baud',
      '{ "uvscanSensor": 1, "sensor": { "name": "AEM wideband", "protocol": "text", "baud": 9600, ' +
      '"description": "AEM wideband on its RS-232 out: one AFR per line" }, "pids": [' +
      '{ "name": "Wideband AFR", "shortName": "WB AFR", "kind": "sensor", "category": "sensors", "field": "1", ' +
      '"units": "AFR", "mci": "WBAFR" } ] }'),
    T('Text sensor (Arduino and others)',
      'Any device that prints numbers in lines of text; add a PID for each one',
      '{ "uvscanSensor": 1, "sensor": { "name": "Text sensor", "protocol": "text", "baud": 9600 }, "pids": [' +
      '{ "name": "Sensor value 1", "kind": "sensor", "category": "sensors", "field": "1" } ] }'),
    T('Demo wideband (simulated)',
      'A made-up LC-1 to try sensors without one',
      '{ "uvscanSensor": 1, "sensor": { "name": "Demo wideband", "protocol": "mts", "baud": 19200, ' +
      '"port": "Simulator", "description": "Simulated: no hardware" }, ' + WidebandPids + ' }')];
end;

end.
