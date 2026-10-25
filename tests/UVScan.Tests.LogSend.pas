unit UVScan.Tests.LogSend;

{ Sending logs while they are written: snapshots (whole, new rows, zipped),
  when they are due, the settings (secrets kept locked), the email as it is
  built, and the sender's tries and giving up (a folder as the way). }

interface

uses
  System.SysUtils, System.Classes, System.Math, System.JSON, System.IOUtils, System.Zip,
  System.NetEncoding, System.Generics.Collections, DUnitX.TestFramework,
  UVScan.LogSend, UVScan.Smtp, UVScan.JsonFile;

type
  [TestFixture]
  TLogSendTests = class
  private
    FDir: string;
    FLog: string;
    procedure WriteLog(const Text: string; Append: Boolean = False);
    function Wait(const Done: TFunc<Boolean>; Ms: Integer): Boolean;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure WholeSnapshotStopsAtTheLastWholeLine;
    [Test] procedure NewRowsSnapshotsGoOnFromTheLastOne;
    [Test] procedure ZipsTheSnapshot;
    [Test] procedure SnapshotsComeEveryIntervalUpToTheMost;
    [Test] procedure OneMoreWhenTheLogStops;
    [Test] procedure SettingsRoundTripWithSecretsLocked;
    [Test] procedure SaysWhatIsMissing;
    [Test] procedure BuildsTheEmail;
    [Test] procedure SplitsAddresses;
    [Test] procedure CopiesToAFolder;
    [Test] procedure SenderReportsSent;
    [Test] procedure SenderGivesUpAfterTheRetries;
  end;

implementation

const
  Bom = #$FEFF;

procedure TLogSendTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'UVScanLogSend' + IntToStr(Random(MaxInt)));
  ForceDirectories(FDir);
  FLog := TPath.Combine(FDir, 'Log 2026-10-23 12.00.00.csv');
end;

procedure TLogSendTests.TearDown;
begin
  try
    TDirectory.Delete(FDir, True);
  except
    // a sender thread may still hold a file: left in Temp
  end;
end;

procedure TLogSendTests.WriteLog(const Text: string; Append: Boolean);
var
  B: TBytes;
  F: TFileStream;
begin
  B := TEncoding.UTF8.GetBytes(Text);
  if Append then
  begin
    F := TFileStream.Create(FLog, fmOpenReadWrite);
    F.Seek(0, soEnd);
  end
  else
    F := TFileStream.Create(FLog, fmCreate);
  try
    if Length(B) > 0 then
      F.WriteBuffer(B, Length(B));
  finally
    F.Free;
  end;
end;

function TLogSendTests.Wait(const Done: TFunc<Boolean>; Ms: Integer): Boolean;
var
  Start: UInt64;
begin
  Start := TThread.GetTickCount64;
  repeat
    CheckSynchronize(50); // the sender reports through the main thread's queue
    if Done then
      Exit(True);
  until TThread.GetTickCount64 - Start > UInt64(Ms);
  Result := False;
end;

function Text(const B: TBytes): string;
begin
  Result := TEncoding.UTF8.GetString(B);
end;

procedure TLogSendTests.WholeSnapshotStopsAtTheLastWholeLine;
var
  Snap: TLogSnapshot;
  Offset: Int64;
begin
  WriteLog(Bom + 'Time (s),RPM,Mark'#13#10'0.0,800,'#13#10'0.1,810,'#13#10'0.2,8');
  Offset := 0;
  Assert.IsTrue(MakeSnapshot(FLog, lwWhole, False, Offset, 1, False, Snap));
  Assert.AreEqual(2, Snap.Rows);
  Assert.AreEqual('Log 2026-10-23 12.00.00.csv', Snap.FileName);
  Assert.AreEqual('text/csv', Snap.MimeType);
  Assert.IsTrue(Text(Snap.Data).EndsWith('0.1,810,'#13#10), 'the half written row is left out');
  Assert.IsTrue(Text(Snap.Data).Contains('Time (s),RPM,Mark'));
end;

procedure TLogSendTests.NewRowsSnapshotsGoOnFromTheLastOne;
var
  Snap: TLogSnapshot;
  Offset: Int64;
  S: string;
begin
  WriteLog(Bom + 'Time (s),RPM,Mark'#13#10'0.0,800,'#13#10'0.1,810,'#13#10);
  Offset := 0;
  Assert.IsTrue(MakeSnapshot(FLog, lwNew, False, Offset, 1, False, Snap));
  Assert.AreEqual(2, Snap.Rows);
  Assert.AreEqual('Log 2026-10-23 12.00.00-part01.csv', Snap.FileName);
  Assert.IsFalse(MakeSnapshot(FLog, lwNew, False, Offset, 2, False, Snap), 'no new rows: nothing');
  WriteLog('0.2,820,'#13#10'0.3,830,1'#13#10'0.4,8', True);
  Assert.IsTrue(MakeSnapshot(FLog, lwNew, False, Offset, 2, False, Snap));
  Assert.AreEqual(2, Snap.Rows);
  Assert.AreEqual('Log 2026-10-23 12.00.00-part02.csv', Snap.FileName);
  S := Text(Snap.Data);
  Assert.IsTrue(S.StartsWith(Bom + 'Time (s),RPM,Mark'#13#10'0.2,820,'), 'the header, then the new rows: ' + S);
  Assert.IsFalse(S.Contains('0.1,810'), 'not the rows sent before');
  Assert.IsFalse(S.Contains('0.4'), 'not the half written row');
  WriteLog('10,'#13#10, True);
  Assert.IsTrue(MakeSnapshot(FLog, lwNew, False, Offset, 3, True, Snap));
  Assert.AreEqual(1, Snap.Rows);
  Assert.AreEqual('Log 2026-10-23 12.00.00-part03-last.csv', Snap.FileName);
  Assert.IsTrue(Text(Snap.Data).EndsWith(#10'0.4,810,'#13#10));
end;

procedure TLogSendTests.ZipsTheSnapshot;
var
  Snap: TLogSnapshot;
  Offset: Int64;
  Z: TZipFile;
  S: TBytesStream;
  Csv: TBytes;
begin
  WriteLog(Bom + 'Time (s),RPM,Mark'#13#10'0.0,800,'#13#10);
  Offset := 0;
  Assert.IsTrue(MakeSnapshot(FLog, lwWhole, True, Offset, 1, False, Snap));
  Assert.AreEqual('Log 2026-10-23 12.00.00.zip', Snap.FileName);
  Assert.AreEqual('application/zip', Snap.MimeType);
  S := TBytesStream.Create(Snap.Data);
  Z := TZipFile.Create;
  try
    Z.Open(S, zmRead);
    Assert.AreEqual(1, Z.FileCount);
    Assert.AreEqual('Log 2026-10-23 12.00.00.csv', Z.FileNames[0]);
    Z.Read(0, Csv);
  finally
    Z.Free;
    S.Free;
  end;
  Assert.AreEqual(Bom + 'Time (s),RPM,Mark'#13#10'0.0,800,'#13#10, Text(Csv));
end;

procedure TLogSendTests.SnapshotsComeEveryIntervalUpToTheMost;
var
  Opts: TLogSendSettings;
  Sched: TLogSendSchedule;
  Snap: TLogSnapshot;
  T: Int64;
begin
  WriteLog(Bom + 'Time (s),RPM,Mark'#13#10'0.0,800,'#13#10);
  Opts := TLogSendSettings.Create;
  Sched := TLogSendSchedule.Create(Opts);
  try
    Opts.IntervalMin := 5;
    Opts.MaxSends := 2;
    Opts.Zip := False;
    T := 1000000;
    Assert.IsFalse(Sched.Due(T, Snap), 'not started');
    Sched.Start(FLog, 0, T);
    Assert.IsTrue(Sched.Active);
    Assert.IsFalse(Sched.Due(T + 4 * 60000, Snap), 'not before 5 minutes');
    Assert.AreEqual(Int64(60000), Sched.NextInMs(T + 4 * 60000));
    Assert.IsTrue(Sched.Due(T + 5 * 60000, Snap));
    Assert.AreEqual(1, Snap.Number);
    Assert.IsFalse(Sched.Due(T + 5 * 60000 + 1000, Snap), 'the next one 5 minutes on');
    Assert.IsTrue(Sched.Due(T + 10 * 60000, Snap));
    Assert.AreEqual(2, Snap.Number);
    Assert.IsTrue(Sched.LimitReached);
    Assert.IsFalse(Sched.Due(T + 60 * 60000, Snap), 'at most 2');
    Assert.AreEqual(2, Sched.Count);
  finally
    Sched.Free;
    Opts.Free;
  end;
end;

procedure TLogSendTests.OneMoreWhenTheLogStops;
var
  Opts: TLogSendSettings;
  Sched: TLogSendSchedule;
  Snap: TLogSnapshot;
begin
  WriteLog(Bom + 'Time (s),RPM,Mark'#13#10'0.0,800,'#13#10);
  Opts := TLogSendSettings.Create;
  Sched := TLogSendSchedule.Create(Opts);
  try
    Opts.MaxSends := 1;
    Opts.AtStop := lsSnapshot;
    Sched.Start(FLog, 0, 0);
    Assert.IsTrue(Sched.Due(Int64(Opts.IntervalMin) * 60000, Snap));
    Assert.IsTrue(Sched.Finish(Snap), 'the last one, the most reached or not');
    Assert.IsTrue(Snap.Final);
    Assert.IsFalse(Sched.Active);
    // only the new rows each time, the whole log at the end
    Opts.What := lwNew;
    Opts.AtStop := lsWhole;
    Sched.Start(FLog, 0, 0);
    WriteLog('0.1,810,'#13#10, True);
    Assert.IsTrue(Sched.Due(Int64(Opts.IntervalMin) * 60000, Snap));
    Assert.AreEqual(2, Snap.Rows);
    WriteLog('0.2,820,'#13#10, True);
    Assert.IsTrue(Sched.Finish(Snap));
    Assert.IsTrue(Snap.What = lwWhole);
    Assert.AreEqual(3, Snap.Rows, 'every row');
    Assert.AreEqual('Log 2026-10-23 12.00.00.csv', Snap.FileName);
    Assert.Contains(Snap.Summary, 'The whole log');
    Opts.AtStop := lsNone;
    Sched.Start(FLog, 0, 0);
    Assert.IsFalse(Sched.Finish(Snap), 'not wanted');
    Assert.IsFalse(Sched.Active);
    // only when it stops: nothing on the way, the whole log at the end
    Opts.OnlyAtStop := True;
    Sched.Start(FLog, 0, 0);
    Assert.IsFalse(Sched.Due(Int64(Opts.IntervalMin) * 60000 * 10, Snap), 'none while it logs');
    Assert.AreEqual(0, Sched.Count);
    Assert.IsTrue(Sched.Finish(Snap), 'whatever When the log stops says');
    Assert.IsTrue(Snap.What = lwWhole);
    Assert.AreEqual(3, Snap.Rows);
    Assert.IsFalse(Sched.Active);
  finally
    Sched.Free;
    Opts.Free;
  end;
end;

procedure TLogSendTests.SettingsRoundTripWithSecretsLocked;
var
  A, B: TLogSendSettings;
  J: TJSONObject;
begin
  A := TLogSendSettings.Create;
  B := TLogSendSettings.Create;
  try
    A.IntervalMin := 3;
    A.MaxSends := 20;
    A.Retries := 5;
    A.What := lwNew;
    A.Zip := True;
    A.AtStop := lsNone;
    A.OnlyAtStop := True;
    A.EmailOn := True;
    A.Mail.Server := 'smtp.example.com';
    A.Mail.Security := msStartTls;
    A.Mail.Port := 587;
    A.Mail.User := 'me@example.com';
    A.Mail.Password := 'abcd efgh ijkl mnop';
    A.MailTo := 'crew@example.com, pits@example.com';
    A.FolderOn := True;
    A.Folder := 'G:\My Drive\UVScan';
    J := A.ToJson;
    try
      {$IFDEF MSWINDOWS}
      Assert.IsTrue(JStr(JObj(J, 'email'), 'password').StartsWith('dpapi:'), 'the password locked');
      Assert.IsFalse(J.ToJSON.Contains('abcd efgh'));
      {$ENDIF}
      B.FromJson(J);
    finally
      J.Free;
    end;
    Assert.AreEqual(3, B.IntervalMin);
    Assert.AreEqual(20, B.MaxSends);
    Assert.AreEqual(5, B.Retries);
    Assert.IsTrue(B.What = lwNew);
    Assert.IsTrue(B.Zip);
    Assert.IsTrue(B.AtStop = lsNone);
    Assert.IsTrue(B.OnlyAtStop);
    Assert.IsTrue(B.EmailOn);
    Assert.AreEqual('smtp.example.com', B.Mail.Server);
    Assert.IsTrue(B.Mail.Security = msStartTls);
    Assert.AreEqual(587, B.Mail.Port);
    Assert.AreEqual('me@example.com', B.Mail.User);
    Assert.AreEqual('abcd efgh ijkl mnop', B.Mail.Password);
    Assert.AreEqual('crew@example.com, pits@example.com', B.MailTo);
    Assert.IsTrue(B.FolderOn);
    Assert.AreEqual('G:\My Drive\UVScan', B.Folder);
    J := TJSONObject.ParseJSONValue('{"atStop": true}') as TJSONObject;
    try
      B.FromJson(J);
      Assert.IsTrue(B.AtStop = lsSnapshot, 'true from before: one more like the others');
    finally
      J.Free;
    end;
    B.FromJson(nil);
    Assert.AreEqual(5, B.IntervalMin, 'defaults without the section');
    Assert.IsTrue(B.AtStop = lsWhole, 'the whole log at the end');
    Assert.IsFalse(B.OnlyAtStop, 'snapshots on the way');
    Assert.IsFalse(B.EmailOn);
    Assert.AreEqual('', UnprotectSecret('dpapi:bm90IHJlYWxseSBsb2NrZWQ='), 'one that does not unlock: none');
  finally
    B.Free;
    A.Free;
  end;
end;

procedure TLogSendTests.SaysWhatIsMissing;
var
  S: TLogSendSettings;
begin
  S := TLogSendSettings.Create;
  try
    Assert.IsTrue(S.Ways = [], 'nothing on at first');
    Assert.IsFalse(S.Zip, 'not zipped unless asked');
    S.EmailOn := True;
    Assert.Contains(S.Problem(swEmail), 'account');
    S.Mail.User := 'me@gmail.com';
    Assert.Contains(S.Problem(swEmail), 'password');
    S.Mail.Password := 'x';
    Assert.Contains(S.Problem(swEmail), 'no one');
    S.MailTo := 'crew@example.com, not an address';
    Assert.Contains(S.Problem(swEmail), 'not an email address');
    S.MailTo := 'crew@example.com; pits@example.org';
    Assert.AreEqual('', S.Problem(swEmail));
    Assert.Contains(S.Problem(swFolder), 'no folder');
  finally
    S.Free;
  end;
end;

procedure TLogSendTests.BuildsTheEmail;
var
  Att: TMailAttachment;
  M, Part: string;
  I, J: Integer;
  Decoded: TBytes;
begin
  Att.FileName := 'Log 1.zip';
  Att.MimeType := 'application/zip';
  SetLength(Att.Data, 3000);
  for I := 0 to High(Att.Data) do
    Att.Data[I] := Byte(I * 7);
  M := BuildMessage('me@gmail.com', ['crew@example.com', 'pits@example.com'], 'UVScan log 1 - 2 (12:05)',
    'Line one' + sLineBreak + '.a line with a dot', [Att], EncodeDate(2026, 10, 23) + EncodeTime(12, 5, 0, 0));
  Assert.IsTrue(M.StartsWith('From: me@gmail.com'#13#10'To: crew@example.com, pits@example.com'#13#10 +
    'Subject: UVScan log 1 - 2 (12:05)'#13#10'Date: Fri, 23 Oct 2026 12:05:00 '), M.Substring(0, 200));
  Assert.Contains(M, 'Content-Type: multipart/mixed; boundary=');
  Assert.Contains(M, 'Content-Disposition: attachment; filename="Log 1.zip"');
  Assert.IsTrue(M.EndsWith('--'#13#10), 'ends with the closing boundary');
  for Part in M.Split([#13#10]) do
  begin
    Assert.IsTrue(Length(Part) <= 998, 'no line over the limit');
    Assert.IsFalse(Part = '.', 'no line that would end the message');
  end;
  // the attachment comes back as it was
  I := Pos('filename="Log 1.zip"', M);
  I := Pos(#13#10#13#10, M, I) + 4;
  J := Pos(#13#10'--', M, I);
  Decoded := TNetEncoding.Base64.DecodeStringToBytes(Copy(M, I, J - I));
  Assert.AreEqual(Length(Att.Data), Length(Decoded));
  Assert.IsTrue(CompareMem(@Att.Data[0], @Decoded[0], Length(Decoded)));
  // a subject with more than ASCII is encoded
  M := BuildMessage('me@gmail.com', ['crew@example.com'], 'EGT 1600 °F', '', [], Now);
  Assert.Contains(M, 'Subject: =?UTF-8?B?');
end;

procedure TLogSendTests.SplitsAddresses;
var
  A: TArray<string>;
begin
  A := SplitAddresses(' crew@example.com,pits@example.org;  me@x.net '#13#10);
  Assert.AreEqual(3, Length(A));
  Assert.AreEqual('pits@example.org', A[1]);
  Assert.IsTrue(ValidAddress('a.b@c.d'));
  Assert.IsFalse(ValidAddress('a@b'));
  Assert.IsFalse(ValidAddress('@b.com'));
  Assert.IsFalse(ValidAddress('a b@c.com'));
  Assert.IsFalse(ValidAddress('a@@c.com'));
end;

procedure TLogSendTests.CopiesToAFolder;
var
  S: TLogSendSettings;
  Snap: TLogSnapshot;
  Offset: Int64;
  Target: string;
begin
  S := TLogSendSettings.Create;
  try
    S.Folder := TPath.Combine(FDir, 'cloud\UVScan');
    S.Zip := False;
    WriteLog(Bom + 'Time (s),RPM,Mark'#13#10'0.0,800,'#13#10);
    Offset := 0;
    MakeSnapshot(FLog, lwWhole, False, Offset, 1, False, Snap);
    DeliverSnapshot(swFolder, S, Snap);
    Target := TPath.Combine(S.Folder, Snap.FileName);
    Assert.IsTrue(TFile.Exists(Target), 'the folder made and the file in it');
    WriteLog('0.1,900,'#13#10, True);
    MakeSnapshot(FLog, lwWhole, False, Offset, 2, False, Snap);
    DeliverSnapshot(swFolder, S, Snap);
    Assert.Contains(TFile.ReadAllText(Target, TEncoding.UTF8), '0.1,900', 'brought up to date');
    Assert.AreEqual(1, Length(TDirectory.GetFiles(S.Folder)), 'one file, no leftovers');
  finally
    S.Free;
  end;
end;

procedure TLogSendTests.SenderReportsSent;
var
  S: TLogSendSettings;
  Sender: TLogSender;
  Snap: TLogSnapshot;
  Offset: Int64;
  Events: TList<TSendEvent>;
begin
  S := TLogSendSettings.Create;
  Events := TList<TSendEvent>.Create;
  try
    S.FolderOn := True;
    S.Folder := TPath.Combine(FDir, 'out');
    WriteLog(Bom + 'Time (s),RPM,Mark'#13#10'0.0,800,'#13#10);
    Offset := 0;
    MakeSnapshot(FLog, lwWhole, True, Offset, 1, False, Snap);
    Sender := TLogSender.Create(S,
      procedure(const Ev: TSendEvent)
      begin
        Events.Add(Ev);
      end);
    try
      Assert.IsTrue(Sender.Working = [swFolder]);
      Sender.Add(Snap);
      Assert.IsTrue(Wait(function: Boolean begin Result := Events.Count > 0 end, 5000), 'no report');
      Assert.IsTrue(Events[0].Kind = seSent, Events[0].Text);
      Assert.IsTrue(Events[0].Way = swFolder);
      Assert.AreEqual(1, Events[0].Number);
      Assert.IsTrue(TFile.Exists(TPath.Combine(S.Folder, 'Log 2026-10-23 12.00.00.zip')));
      Assert.IsTrue(Wait(function: Boolean begin Result := Sender.Pending = 0 end, 2000));
    finally
      Sender.Free;
    end;
  finally
    Events.Free;
    S.Free;
  end;
end;

procedure TLogSendTests.SenderGivesUpAfterTheRetries;
var
  S: TLogSendSettings;
  Sender: TLogSender;
  Snap: TLogSnapshot;
  Offset: Int64;
  Events: TList<TSendEvent>;
  Blocker: string;
begin
  S := TLogSendSettings.Create;
  Events := TList<TSendEvent>.Create;
  try
    // a file where the folder would be: it cannot be made
    Blocker := TPath.Combine(FDir, 'blocker');
    TFile.WriteAllText(Blocker, 'x');
    S.FolderOn := True;
    S.Folder := TPath.Combine(Blocker, 'out');
    S.Retries := 0;
    WriteLog(Bom + 'Time (s),RPM,Mark'#13#10'0.0,800,'#13#10);
    Offset := 0;
    MakeSnapshot(FLog, lwWhole, False, Offset, 1, False, Snap);
    Sender := TLogSender.Create(S,
      procedure(const Ev: TSendEvent)
      begin
        Events.Add(Ev);
      end);
    try
      Sender.Add(Snap);
      Assert.IsTrue(Wait(function: Boolean begin Result := Events.Count > 0 end, 5000), 'no report');
      Assert.IsTrue(Events[0].Kind = seGaveUp, 'given up at once with no retries');
      Assert.AreEqual(1, Events[0].Attempt);
      Assert.IsTrue(Events[0].Text <> '', 'says why');
      Assert.IsTrue(Sender.Working = [], 'that way stopped');
      Sender.Add(Snap);
      Assert.IsFalse(Wait(function: Boolean begin Result := Events.Count > 1 end, 500), 'takes no more');
    finally
      Sender.Free;
    end;
  finally
    Events.Free;
    S.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLogSendTests);

end.
