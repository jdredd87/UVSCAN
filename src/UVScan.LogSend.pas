unit UVScan.LogSend;

(* Sending the log while it is written, for a crew away from the car (a
  road course: the pits get the data each few laps). Turned on for the
  time UVScan is open ("Send while logging"), never on by itself.

  Every IntervalMin minutes of logging a snapshot of the log goes out (up
  to MaxSends per log, and one more when the log stops): the whole log so
  far, or only the rows since the last one (with the header line), zipped
  or as the .csv. Each way it goes is tried Retries more times when it
  fails, a while apart; after that that way stops for this log and the
  page says so. The ways:
    email   through a mail account (UVScan.Smtp): the snapshot attached
    folder  (Windows) a copy in a folder: one that Google Drive, OneDrive
            or Dropbox keeps in step with the cloud uploads it

  Settings, in settings.json "logSend":
    { "everyMinutes": 5, "maxPerLog": 12, "retries": 3, "what": "whole", "zip": false, "atStop": true,
      "email": { "on": true, "server": "smtp.gmail.com", "port": 465, "security": "tls",
                 "user": "me@gmail.com", "password": "...", "from": "", "to": "crew@x.com, me@y.com" },
      "folder": { "on": false, "path": "G:\\My Drive\\UVScan" } }
  The password is kept for this Windows user only ("dpapi:...", Windows'
  data protection); a phone keeps it in the app's own storage. *)

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.JSON, System.Generics.Collections,
  UVScan.Smtp;

type
  TLogSendWhat = (lwWhole, lwNew);
  TSendWay = (swEmail, swFolder);
  TSendWays = set of TSendWay;

  TLogSendSettings = class
  public
    IntervalMin: Integer; // a snapshot every so many minutes of logging
    MaxSends: Integer;    // at most so many per log (the one at the stop besides)
    Retries: Integer;     // tries after the first, per snapshot and way
    What: TLogSendWhat;
    Zip: Boolean;
    AtStop: Boolean;      // one more when the log stops
    EmailOn: Boolean;
    Mail: TMailAccount;
    MailTo: string;       // addresses, comma separated
    FolderOn: Boolean;
    Folder: string;
    constructor Create;
    procedure ResetToDefaults;
    procedure Assign(Source: TLogSendSettings);
    function ToJson: TJSONObject;
    procedure FromJson(Root: TJSONObject);
    { The ways turned on that work here (folder: Windows). }
    function Ways: TSendWays;
    { What is missing for Way, '' when it is ready. }
    function Problem(Way: TSendWay): string;
  end;

  TLogSnapshot = record
    LogFile: string;
    Number: Integer;     // 1, 2... in this log
    Final: Boolean;      // the one when the log stopped
    What: TLogSendWhat;
    FileName: string;    // as it is sent: 'Log 2026-10-23.csv', '...-part03.zip'
    MimeType: string;
    Data: TBytes;
    Rows: Integer;       // data rows in it
    When: TDateTime;
    function Summary: string;
  end;

  TSendEventKind = (seSent, seRetrying, seGaveUp);

  TSendEvent = record
    Kind: TSendEventKind;
    Way: TSendWay;
    Number: Integer;
    Final: Boolean;
    Attempt: Integer;    // the try that failed (seRetrying, seGaveUp)
    Text: string;        // what went wrong, or where it went
  end;

  TSendEventProc = reference to procedure(const Ev: TSendEvent);

  { Hands snapshots to a thread per way and reports back on the main
    thread. Freeing it stops sending (one already going finishes on its
    own thread, unreported). }
  TLogSender = class
  private
    FWorkers: array[TSendWay] of TThread;
    FSink: IInterface;
  public
    constructor Create(Settings: TLogSendSettings; const OnEvent: TSendEventProc);
    destructor Destroy; override;
    procedure Add(const Snap: TLogSnapshot);
    { Ways still sending (not given up). }
    function Working: TSendWays;
    { Snapshots waiting or being sent. }
    function Pending: Integer;
  end;

  { When the snapshots of a log are due. Times are milliseconds from any
    steady clock (TThread.GetTickCount64). }
  TLogSendSchedule = class
  private
    FSettings: TLogSendSettings;
    FLogFile: string;
    FOffset: Int64;    // lwNew: where the rows not sent yet start
    FCount: Integer;
    FNextAt: Int64;
    function Take(Final: Boolean; out Snap: TLogSnapshot): Boolean;
  public
    constructor Create(Settings: TLogSendSettings);
    { A log starts (or sending is turned on during one): its first snapshot
      IntervalMin from now. FromOffset: where its rows start in the file (a
      log carried on), for lwNew. }
    procedure Start(const LogFile: string; FromOffset: Int64; NowMs: Int64);
    procedure Stop;
    { The snapshot due now, when one is. }
    function Due(NowMs: Int64; out Snap: TLogSnapshot): Boolean;
    { The last one, when the log stops (AtStop; not counted); then stopped. }
    function Finish(out Snap: TLogSnapshot): Boolean;
    function Active: Boolean;
    function LimitReached: Boolean;
    function NextInMs(NowMs: Int64): Int64;
    property LogFile: string read FLogFile;
    property Count: Integer read FCount;
  end;

const
  SendWayNames: array[TSendWay] of string = ('email', 'folder');
  LogSendWhatKeys: array[TLogSendWhat] of string = ('whole', 'new');

{ The snapshot of LogFile now: the whole of it, or (lwNew) its header and
  the rows from Offset on, cut at the last whole line. lwNew moves Offset
  on and gives False when there are no new rows. Raises when the file
  cannot be read. }
function MakeSnapshot(const LogFile: string; What: TLogSendWhat; Zip: Boolean; var Offset: Int64;
  Number: Integer; Final: Boolean; out Snap: TLogSnapshot): Boolean;

{ Sends Snap one way, once (raises with what went wrong). }
procedure DeliverSnapshot(Way: TSendWay; Settings: TLogSendSettings; const Snap: TLogSnapshot);

{ The wait before try number Attempt + 1: 15 s, 30 s, 60 s, then 2 minutes. }
function RetryDelayMs(Attempt: Integer): Integer;

{ A secret as stored: on Windows for this user only. }
function ProtectSecret(const S: string): string;
function UnprotectSecret(const S: string): string;

implementation

uses
  {$IFDEF MSWINDOWS}Winapi.Windows,{$ENDIF}
  System.IOUtils, System.Math, System.Zip, System.NetEncoding, System.StrUtils, System.DateUtils,
  UVScan.JsonFile, UVScan.Version;

const
  SecretPrefix = 'dpapi:';

{ Secrets }

{$IFDEF MSWINDOWS}
type
  TDataBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;
  PDataBlob = ^TDataBlob;

const
  CRYPTPROTECT_UI_FORBIDDEN = 1;

function CryptProtectData(pDataIn: PDataBlob; szDataDescr: PWideChar; pOptionalEntropy: PDataBlob;
  pvReserved, pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall; external 'crypt32.dll';
function CryptUnprotectData(pDataIn: PDataBlob; ppszDataDescr: Pointer; pOptionalEntropy: PDataBlob;
  pvReserved, pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall; external 'crypt32.dll';
{$ENDIF}

function ProtectSecret(const S: string): string;
{$IFDEF MSWINDOWS}
var
  Plain: TBytes;
  InBlob, OutBlob: TDataBlob;
  Sealed: TBytes;
begin
  if S = '' then
    Exit('');
  Plain := TEncoding.UTF8.GetBytes(S);
  InBlob.cbData := Length(Plain);
  InBlob.pbData := @Plain[0];
  if not CryptProtectData(@InBlob, nil, nil, nil, nil, CRYPTPROTECT_UI_FORBIDDEN, @OutBlob) then
    Exit(S); // kept as it is rather than lost
  try
    SetLength(Sealed, OutBlob.cbData);
    Move(OutBlob.pbData^, Sealed[0], OutBlob.cbData);
  finally
    LocalFree(HLOCAL(OutBlob.pbData));
  end;
  Result := SecretPrefix + TNetEncoding.Base64String.EncodeBytesToString(Sealed);
end;
{$ELSE}
begin
  Result := S;
end;
{$ENDIF}

function UnprotectSecret(const S: string): string;
{$IFDEF MSWINDOWS}
var
  Sealed: TBytes;
  InBlob, OutBlob: TDataBlob;
  Plain: TBytes;
begin
  if not S.StartsWith(SecretPrefix) then
    Exit(S);
  try
    Sealed := TNetEncoding.Base64String.DecodeStringToBytes(Copy(S, Length(SecretPrefix) + 1, MaxInt));
  except
    Exit('');
  end;
  if Length(Sealed) = 0 then
    Exit('');
  InBlob.cbData := Length(Sealed);
  InBlob.pbData := @Sealed[0];
  if not CryptUnprotectData(@InBlob, nil, nil, nil, nil, CRYPTPROTECT_UI_FORBIDDEN, @OutBlob) then
    Exit(''); // another Windows user's: set it again
  try
    SetLength(Plain, OutBlob.cbData);
    if OutBlob.cbData > 0 then
      Move(OutBlob.pbData^, Plain[0], OutBlob.cbData);
  finally
    LocalFree(HLOCAL(OutBlob.pbData));
  end;
  Result := TEncoding.UTF8.GetString(Plain);
end;
{$ELSE}
begin
  if S.StartsWith(SecretPrefix) then
    Result := '' // made on Windows
  else
    Result := S;
end;
{$ENDIF}

{ TLogSendSettings }

constructor TLogSendSettings.Create;
begin
  inherited;
  ResetToDefaults;
end;

procedure TLogSendSettings.ResetToDefaults;
begin
  IntervalMin := 5;
  MaxSends := 12;
  Retries := 3;
  What := lwWhole;
  Zip := False;
  AtStop := True;
  EmailOn := False;
  Mail := Default(TMailAccount);
  Mail.Server := 'smtp.gmail.com';
  Mail.Port := 465;
  Mail.Security := msTls;
  MailTo := '';
  FolderOn := False;
  Folder := '';
end;

procedure TLogSendSettings.Assign(Source: TLogSendSettings);
var
  J: TJSONObject;
begin
  J := Source.ToJson;
  try
    FromJson(J);
  finally
    J.Free;
  end;
end;

function TLogSendSettings.ToJson: TJSONObject;
var
  Sec: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('everyMinutes', TJSONNumber.Create(IntervalMin));
  Result.AddPair('maxPerLog', TJSONNumber.Create(MaxSends));
  Result.AddPair('retries', TJSONNumber.Create(Retries));
  Result.AddPair('what', LogSendWhatKeys[What]);
  Result.AddPair('zip', TJSONBool.Create(Zip));
  Result.AddPair('atStop', TJSONBool.Create(AtStop));
  Sec := TJSONObject.Create;
  Sec.AddPair('on', TJSONBool.Create(EmailOn));
  Sec.AddPair('server', Mail.Server);
  Sec.AddPair('port', TJSONNumber.Create(Mail.Port));
  Sec.AddPair('security', MailSecurityKeys[Mail.Security]);
  Sec.AddPair('user', Mail.User);
  Sec.AddPair('password', ProtectSecret(Mail.Password));
  Sec.AddPair('from', Mail.From);
  Sec.AddPair('to', MailTo);
  Result.AddPair('email', Sec);
  Sec := TJSONObject.Create;
  Sec.AddPair('on', TJSONBool.Create(FolderOn));
  Sec.AddPair('path', Folder);
  Result.AddPair('folder', Sec);
end;

procedure TLogSendSettings.FromJson(Root: TJSONObject);
var
  Sec: TJSONObject;
  M: TMailSecurity;
  W: TLogSendWhat;
begin
  ResetToDefaults;
  if Root = nil then
    Exit;
  IntervalMin := EnsureRange(JInt(Root, 'everyMinutes', IntervalMin), 1, 240);
  MaxSends := EnsureRange(JInt(Root, 'maxPerLog', MaxSends), 1, 1000);
  Retries := EnsureRange(JInt(Root, 'retries', Retries), 0, 20);
  for W := Low(W) to High(W) do
    if SameText(JStr(Root, 'what'), LogSendWhatKeys[W]) then
      What := W;
  Zip := JBool(Root, 'zip', Zip);
  AtStop := JBool(Root, 'atStop', AtStop);
  Sec := JObj(Root, 'email');
  if Sec <> nil then
  begin
    EmailOn := JBool(Sec, 'on');
    Mail.Server := JStr(Sec, 'server', Mail.Server);
    for M := Low(M) to High(M) do
      if SameText(JStr(Sec, 'security'), MailSecurityKeys[M]) then
        Mail.Security := M;
    Mail.Port := EnsureRange(JInt(Sec, 'port', MailSecurityPorts[Mail.Security]), 1, 65535);
    Mail.User := JStr(Sec, 'user');
    Mail.Password := UnprotectSecret(JStr(Sec, 'password'));
    Mail.From := JStr(Sec, 'from');
    MailTo := JStr(Sec, 'to');
  end;
  Sec := JObj(Root, 'folder');
  if Sec <> nil then
  begin
    FolderOn := JBool(Sec, 'on');
    Folder := JStr(Sec, 'path');
  end;
end;

function TLogSendSettings.Ways: TSendWays;
begin
  Result := [];
  if EmailOn then
    Include(Result, swEmail);
  {$IFDEF MSWINDOWS}
  if FolderOn then
    Include(Result, swFolder);
  {$ENDIF}
end;

function TLogSendSettings.Problem(Way: TSendWay): string;
var
  A: string;
begin
  Result := '';
  case Way of
    swEmail:
      begin
        if Trim(Mail.Server) = '' then
          Exit('Email: no mail server');
        if Trim(Mail.User) = '' then
          Exit('Email: no account (the address it signs in with)');
        if Mail.Password = '' then
          Exit('Email: no password');
        if Length(SplitAddresses(MailTo)) = 0 then
          Exit('Email: no one to send it to');
        for A in SplitAddresses(MailTo) do
          if not ValidAddress(A) then
            Exit(Format('Email: "%s" is not an email address', [A]));
      end;
    swFolder:
      if Trim(Folder) = '' then
        Exit('Folder: no folder chosen');
  end;
end;

{ Snapshots }

function TLogSnapshot.Summary: string;
var
  Kind: string;
begin
  if What = lwWhole then
    Kind := 'the whole log so far'
  else
    Kind := 'the rows since the last one';
  if Final then
    Result := Format('The last snapshot, as the log stopped (%s): %d rows', [Kind, Rows])
  else
    Result := Format('Snapshot %d (%s): %d rows', [Number, Kind, Rows]);
end;

function ReadShared(const FileName: string): TBytes;
var
  F: TFileStream;
begin
  // the log is being written: read beside the writer
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, F.Size);
    if Length(Result) > 0 then
      F.ReadBuffer(Result, Length(Result));
  finally
    F.Free;
  end;
end;

function CountLines(const B: TBytes; From, Count: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := From to From + Count - 1 do
    if B[I] = 10 then
      Inc(Result);
end;

function ZipOne(const Name: string; const Data: TBytes): TBytes;
var
  Z: TZipFile;
  S: TBytesStream;
begin
  S := TBytesStream.Create;
  try
    Z := TZipFile.Create;
    try
      Z.Open(S, zmWrite);
      Z.Add(Data, Name);
      Z.Close;
    finally
      Z.Free;
    end;
    Result := Copy(S.Bytes, 0, S.Size);
  finally
    S.Free;
  end;
end;

function MakeSnapshot(const LogFile: string; What: TLogSendWhat; Zip: Boolean; var Offset: Int64;
  Number: Integer; Final: Boolean; out Snap: TLogSnapshot): Boolean;
var
  All, Body: TBytes;
  LastLf, HeaderEnd, I: Integer;
  From: Int64;
  Base, CsvName: string;
begin
  Snap := Default(TLogSnapshot);
  All := ReadShared(LogFile);
  // only whole lines: the writer may be half way through one
  LastLf := -1;
  for I := Length(All) - 1 downto 0 do
    if All[I] = 10 then
    begin
      LastLf := I;
      Break;
    end;
  HeaderEnd := -1;
  for I := 0 to LastLf do
    if All[I] = 10 then
    begin
      HeaderEnd := I;
      Break;
    end;
  if HeaderEnd < 0 then
    Exit(False); // not even the header yet
  Base := TPath.GetFileNameWithoutExtension(LogFile);
  if What = lwWhole then
  begin
    Body := Copy(All, 0, LastLf + 1);
    Snap.Rows := CountLines(All, 0, LastLf + 1) - 1;
    CsvName := Base + '.csv';
  end
  else
  begin
    From := Max(Int64(HeaderEnd + 1), Min(Offset, Int64(LastLf + 1)));
    if From > LastLf then
      Exit(False); // nothing new
    Body := Copy(All, 0, HeaderEnd + 1) + Copy(All, Integer(From), LastLf + 1 - Integer(From));
    Snap.Rows := CountLines(All, Integer(From), LastLf + 1 - Integer(From));
    Offset := LastLf + 1;
    if Final then
      CsvName := Format('%s-part%.2d-last.csv', [Base, Number])
    else
      CsvName := Format('%s-part%.2d.csv', [Base, Number]);
  end;
  Snap.LogFile := LogFile;
  Snap.Number := Number;
  Snap.Final := Final;
  Snap.What := What;
  Snap.When := Now;
  if Zip then
  begin
    Snap.Data := ZipOne(CsvName, Body);
    Snap.FileName := ChangeFileExt(CsvName, '.zip');
    Snap.MimeType := 'application/zip';
  end
  else
  begin
    Snap.Data := Body;
    Snap.FileName := CsvName;
    Snap.MimeType := 'text/csv';
  end;
  Result := True;
end;

function RetryDelayMs(Attempt: Integer): Integer;
begin
  case Attempt of
    1: Result := 15000;
    2: Result := 30000;
    3: Result := 60000;
  else
    Result := 120000;
  end;
end;

procedure CopyToFolder(const Folder: string; const Snap: TLogSnapshot);
var
  Target, Temp: string;
begin
  if not TDirectory.Exists(Folder) then
    ForceDirectories(Folder);
  Target := TPath.Combine(Folder, Snap.FileName);
  Temp := Target + '.part';
  // written whole, then put in place: a sync program never takes half a file
  TFile.WriteAllBytes(Temp, Snap.Data);
  if TFile.Exists(Target) then
    TFile.Delete(Target);
  TFile.Move(Temp, Target);
end;

function MailBody(const Snap: TLogSnapshot): string;
begin
  Result := Format('UVScan log %s' + sLineBreak + sLineBreak + '%s, %s.' + sLineBreak + sLineBreak +
    'The file attached is %s. Sent by UVScan %s while logging.',
    [ExtractFileName(Snap.LogFile), Snap.Summary, FormatDateTime('yyyy-mm-dd hh:nn:ss', Snap.When),
    IfThen(Snap.MimeType = 'application/zip', 'zipped (the .csv inside opens in a spreadsheet)',
    'a .csv (it opens in a spreadsheet)'), AppVersion]);
end;

function MailSubject(const Snap: TLogSnapshot): string;
begin
  if Snap.Final then
    Result := Format('UVScan log %s - last (%s)', [TPath.GetFileNameWithoutExtension(Snap.LogFile),
      FormatDateTime('hh:nn', Snap.When)])
  else
    Result := Format('UVScan log %s - %d (%s)', [TPath.GetFileNameWithoutExtension(Snap.LogFile), Snap.Number,
      FormatDateTime('hh:nn', Snap.When)]);
end;

procedure DeliverSnapshot(Way: TSendWay; Settings: TLogSendSettings; const Snap: TLogSnapshot);
var
  Att: TMailAttachment;
begin
  case Way of
    swEmail:
      begin
        Att.FileName := Snap.FileName;
        Att.MimeType := Snap.MimeType;
        Att.Data := Snap.Data;
        SendMail(Settings.Mail, SplitAddresses(Settings.MailTo), MailSubject(Snap), MailBody(Snap), [Att]);
      end;
    swFolder:
      CopyToFolder(Settings.Folder, Snap);
  end;
end;

{ TLogSender }

type
  { Where the threads report: the main thread's handler, until the sender
    is freed (a thread may outlive it). Only touched on the main thread. }
  TSendSink = class(TInterfacedObject)
  public
    Proc: TSendEventProc;
  end;

  TSendWorker = class(TThread)
  private
    FWay: TSendWay;
    FSettings: TLogSendSettings;
    FSink: IInterface;
    FLock: TCriticalSection;
    FQueue: TList<TLogSnapshot>;
    FWake: TEvent;
    FBusy: Boolean;
    FGaveUp: Boolean;
    procedure Report(Kind: TSendEventKind; const Snap: TLogSnapshot; Attempt: Integer; const Text: string);
    function Take(out Snap: TLogSnapshot): Boolean;
    function Pause(Ms: Integer): Boolean;
  protected
    procedure Execute; override;
    procedure TerminatedSet; override;
  public
    constructor Create(Way: TSendWay; Settings: TLogSendSettings; const Sink: IInterface);
    destructor Destroy; override;
    procedure Add(const Snap: TLogSnapshot);
    function Pending: Integer;
    function GaveUp: Boolean;
  end;

constructor TSendWorker.Create(Way: TSendWay; Settings: TLogSendSettings; const Sink: IInterface);
begin
  FWay := Way;
  FSettings := TLogSendSettings.Create;
  FSettings.Assign(Settings);
  FSink := Sink;
  FLock := TCriticalSection.Create;
  FQueue := TList<TLogSnapshot>.Create;
  FWake := TEvent.Create(nil, False, False, '');
  inherited Create(False); // runs once constructed (AfterConstruction)
  FreeOnTerminate := True;
end;

destructor TSendWorker.Destroy;
begin
  FWake.Free;
  FQueue.Free;
  FLock.Free;
  FSettings.Free;
  inherited;
end;

procedure TSendWorker.TerminatedSet;
begin
  inherited;
  FWake.SetEvent;
end;

procedure TSendWorker.Add(const Snap: TLogSnapshot);
var
  I: Integer;
begin
  FLock.Enter;
  try
    if FGaveUp then
      Exit;
    // the whole log: a newer one makes those still waiting for the same log needless
    if Snap.What = lwWhole then
      for I := FQueue.Count - 1 downto 0 do
        if SameText(FQueue[I].LogFile, Snap.LogFile) then
          FQueue.Delete(I);
    FQueue.Add(Snap);
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

function TSendWorker.Pending: Integer;
begin
  FLock.Enter;
  try
    Result := FQueue.Count + Ord(FBusy);
  finally
    FLock.Leave;
  end;
end;

function TSendWorker.GaveUp: Boolean;
begin
  FLock.Enter;
  try
    Result := FGaveUp;
  finally
    FLock.Leave;
  end;
end;

function TSendWorker.Take(out Snap: TLogSnapshot): Boolean;
begin
  FLock.Enter;
  try
    Result := FQueue.Count > 0;
    if Result then
    begin
      Snap := FQueue[0];
      FQueue.Delete(0);
      FBusy := True;
    end;
  finally
    FLock.Leave;
  end;
end;

{ False when the sender went away meanwhile. }
function TSendWorker.Pause(Ms: Integer): Boolean;
begin
  if not Terminated then
    FWake.WaitFor(Ms);
  Result := not Terminated;
end;

procedure TSendWorker.Report(Kind: TSendEventKind; const Snap: TLogSnapshot; Attempt: Integer; const Text: string);
var
  Ev: TSendEvent;
  Sink: IInterface;
begin
  Ev.Kind := Kind;
  Ev.Way := FWay;
  Ev.Number := Snap.Number;
  Ev.Final := Snap.Final;
  Ev.Attempt := Attempt;
  Ev.Text := Text;
  Sink := FSink;
  TThread.Queue(nil,
    procedure
    begin
      if Assigned((Sink as TSendSink).Proc) then
        (Sink as TSendSink).Proc(Ev);
    end);
end;

procedure TSendWorker.Execute;
var
  Snap: TLogSnapshot;
  Attempt: Integer;
  Where: string;
begin
  while not Terminated do
  begin
    if not Take(Snap) then
    begin
      FWake.WaitFor(1000);
      Continue;
    end;
    Attempt := 0;
    repeat
      Inc(Attempt);
      try
        DeliverSnapshot(FWay, FSettings, Snap);
        if FWay = swEmail then
          Where := FSettings.MailTo
        else
          Where := FSettings.Folder;
        Report(seSent, Snap, Attempt, Where);
        Break;
      except
        on E: Exception do
          if Attempt > FSettings.Retries then
          begin
            FLock.Enter;
            try
              FGaveUp := True;
              FQueue.Clear;
            finally
              FLock.Leave;
            end;
            Report(seGaveUp, Snap, Attempt, E.Message);
          end
          else
          begin
            Report(seRetrying, Snap, Attempt, E.Message);
            if not Pause(RetryDelayMs(Attempt)) then
              Break;
            Continue;
          end;
      end;
      Break;
    until False;
    FLock.Enter;
    try
      FBusy := False;
    finally
      FLock.Leave;
    end;
    // given up: it idles (taking nothing more) until the sender goes
  end;
end;

constructor TLogSender.Create(Settings: TLogSendSettings; const OnEvent: TSendEventProc);
var
  W: TSendWay;
  Sink: TSendSink;
begin
  inherited Create;
  Sink := TSendSink.Create;
  Sink.Proc := OnEvent;
  FSink := Sink;
  for W in Settings.Ways do
    if Settings.Problem(W) = '' then
      FWorkers[W] := TSendWorker.Create(W, Settings, FSink);
end;

destructor TLogSender.Destroy;
var
  W: TSendWay;
begin
  (FSink as TSendSink).Proc := nil;
  for W := Low(W) to High(W) do
    if FWorkers[W] <> nil then
      FWorkers[W].Terminate; // frees itself once out of what it is doing
  inherited;
end;

procedure TLogSender.Add(const Snap: TLogSnapshot);
var
  W: TSendWay;
begin
  for W := Low(W) to High(W) do
    if FWorkers[W] <> nil then
      TSendWorker(FWorkers[W]).Add(Snap);
end;

function TLogSender.Working: TSendWays;
var
  W: TSendWay;
begin
  Result := [];
  for W := Low(W) to High(W) do
    if (FWorkers[W] <> nil) and not TSendWorker(FWorkers[W]).GaveUp then
      Include(Result, W);
end;

function TLogSender.Pending: Integer;
var
  W: TSendWay;
begin
  Result := 0;
  for W := Low(W) to High(W) do
    if FWorkers[W] <> nil then
      Inc(Result, TSendWorker(FWorkers[W]).Pending);
end;

{ TLogSendSchedule }

constructor TLogSendSchedule.Create(Settings: TLogSendSettings);
begin
  inherited Create;
  FSettings := Settings;
end;

procedure TLogSendSchedule.Start(const LogFile: string; FromOffset: Int64; NowMs: Int64);
begin
  FLogFile := LogFile;
  FOffset := FromOffset;
  FCount := 0;
  FNextAt := NowMs + Int64(FSettings.IntervalMin) * 60000;
end;

procedure TLogSendSchedule.Stop;
begin
  FLogFile := '';
end;

function TLogSendSchedule.Active: Boolean;
begin
  Result := FLogFile <> '';
end;

function TLogSendSchedule.LimitReached: Boolean;
begin
  Result := FCount >= FSettings.MaxSends;
end;

function TLogSendSchedule.NextInMs(NowMs: Int64): Int64;
begin
  Result := Max(0, FNextAt - NowMs);
end;

function TLogSendSchedule.Take(Final: Boolean; out Snap: TLogSnapshot): Boolean;
begin
  Result := MakeSnapshot(FLogFile, FSettings.What, FSettings.Zip, FOffset, FCount + 1, Final, Snap);
  if Result and not Final then
    Inc(FCount);
end;

function TLogSendSchedule.Due(NowMs: Int64; out Snap: TLogSnapshot): Boolean;
begin
  Result := False;
  if not Active or LimitReached or (NowMs < FNextAt) then
    Exit;
  FNextAt := NowMs + Int64(FSettings.IntervalMin) * 60000;
  Result := Take(False, Snap);
end;

function TLogSendSchedule.Finish(out Snap: TLogSnapshot): Boolean;
begin
  Result := False;
  if Active and FSettings.AtStop then
    Result := Take(True, Snap);
  Stop;
end;

end.
