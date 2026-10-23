unit UVScan.Smtp;

{ Sending an email with files attached through a mail account's SMTP
  server (UVScan.Tls for the connection): Gmail (smtp.gmail.com, an app
  password), Yahoo, iCloud, an internet provider's... TLS is required:
  from the start (port 465) or by STARTTLS (587); the password never goes
  over a plain connection. Blocking: run it on a thread of its own. }

interface

uses
  System.SysUtils;

type
  TMailSecurity = (msTls, msStartTls);

  TMailAccount = record
    Server: string;
    Port: Integer;
    Security: TMailSecurity;
    User: string;
    Password: string;
    From: string;     // '' = User
  end;

  TMailAttachment = record
    FileName: string;
    MimeType: string;
    Data: TBytes;
  end;

  ESmtpError = class(Exception);

const
  MailSecurityKeys: array[TMailSecurity] of string = ('tls', 'starttls');
  MailSecurityNames: array[TMailSecurity] of string = ('TLS (port 465)', 'STARTTLS (port 587)');
  MailSecurityPorts: array[TMailSecurity] of Integer = (465, 587);

{ Sends it; raises ESmtpError (or ETlsError) with what went wrong. }
procedure SendMail(const Account: TMailAccount; const Recipients: TArray<string>; const Subject, Body: string;
  const Attachments: TArray<TMailAttachment>; TimeoutMs: Integer = 60000);

{ The message as it goes after DATA (dot-stuffed, without the closing dot). }
function BuildMessage(const From: string; const Recipients: TArray<string>; const Subject, Body: string;
  const Attachments: TArray<TMailAttachment>; When: TDateTime): string;

{ 'a@x.com, b@y.org; c@z.net' -> its addresses, trimmed, empty ones left out. }
function SplitAddresses(const Text: string): TArray<string>;
{ Something@something.something, no spaces or brackets. }
function ValidAddress(const Address: string): Boolean;

implementation

uses
  System.NetEncoding, System.DateUtils, System.StrUtils, System.TimeSpan, System.RegularExpressions, UVScan.Tls;

function SplitAddresses(const Text: string): TArray<string>;
var
  S: string;
begin
  Result := nil;
  for S in Text.Split([',', ';', ' ', #13, #10, #9]) do
    if Trim(S) <> '' then
      Result := Result + [Trim(S)];
end;

function ValidAddress(const Address: string): Boolean;
var
  At, Dot: Integer;
begin
  At := Pos('@', Address);
  Dot := LastDelimiter('.', Address);
  Result := (At > 1) and (Dot > At + 1) and (Dot < Length(Address)) and (Pos('@', Address, At + 1) = 0) and
    (Address.IndexOfAny([' ', '<', '>', ',', ';', '"', '(', ')', #13, #10]) < 0);
end;

function Base64Lines(const Data: TBytes): string;
var
  Enc: TBase64Encoding;
begin
  Enc := TBase64Encoding.Create(76, #13#10);
  try
    Result := Enc.EncodeBytesToString(Data);
  finally
    Enc.Free;
  end;
end;

function Base64Plain(const Text: string): string;
var
  Enc: TBase64Encoding;
begin
  Enc := TBase64Encoding.Create(0);
  try
    Result := Enc.EncodeBytesToString(TEncoding.UTF8.GetBytes(Text));
  finally
    Enc.Free;
  end;
end;

{ A header value: as it is in plain ASCII, else RFC 2047 encoded. }
function HeaderText(const S: string): string;
var
  C: Char;
begin
  for C in S do
    if (Ord(C) > 126) or (Ord(C) < 32) then
      Exit('=?UTF-8?B?' + Base64Plain(S) + '?=');
  Result := S;
end;

{ A file name in a header: quoted, without quotes of its own. }
function QuotedName(const S: string): string;
begin
  Result := '"' + HeaderText(StringReplace(S, '"', '''', [rfReplaceAll])) + '"';
end;

function MailDate(When: TDateTime): string;
const
  Days: array[1..7] of string = ('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun');
  Months: array[1..12] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
    'Nov', 'Dec');
var
  Offset: Integer;
begin
  Offset := Round(TTimeZone.Local.GetUtcOffset(When).TotalMinutes);
  Result := Format('%s, %d %s %d %s %s%.2d%.2d', [Days[DayOfTheWeek(When)], DayOf(When), Months[MonthOf(When)],
    YearOf(When), FormatDateTime('hh:nn:ss', When), IfThen(Offset < 0, '-', '+'), Abs(Offset) div 60,
    Abs(Offset) mod 60]);
end;

function BuildMessage(const From: string; const Recipients: TArray<string>; const Subject, Body: string;
  const Attachments: TArray<TMailAttachment>; When: TDateTime): string;
var
  SB: TStringBuilder;
  Boundary, Line: string;
  A: TMailAttachment;
  Lines: TArray<string>;
begin
  Boundary := '=_UVScan_' + IntToHex(Random(MaxInt), 8) + IntToHex(DateTimeToUnix(When), 8);
  SB := TStringBuilder.Create;
  try
    SB.Append('From: ').Append(From).Append(#13#10);
    SB.Append('To: ').Append(string.Join(', ', Recipients)).Append(#13#10);
    SB.Append('Subject: ').Append(HeaderText(Subject)).Append(#13#10);
    SB.Append('Date: ').Append(MailDate(When)).Append(#13#10);
    SB.Append('Message-ID: <').Append(IntToHex(DateTimeToUnix(When), 8)).Append('.')
      .Append(IntToHex(Random(MaxInt), 8)).Append('@uvscan>').Append(#13#10);
    SB.Append('X-Mailer: UVScan').Append(#13#10);
    SB.Append('MIME-Version: 1.0').Append(#13#10);
    SB.Append('Content-Type: multipart/mixed; boundary="').Append(Boundary).Append('"').Append(#13#10);
    SB.Append(#13#10);
    SB.Append('This is a message with files attached.').Append(#13#10);
    SB.Append('--').Append(Boundary).Append(#13#10);
    SB.Append('Content-Type: text/plain; charset=utf-8').Append(#13#10);
    SB.Append('Content-Transfer-Encoding: base64').Append(#13#10);
    SB.Append(#13#10);
    SB.Append(Base64Lines(TEncoding.UTF8.GetBytes(Body))).Append(#13#10);
    for A in Attachments do
    begin
      SB.Append('--').Append(Boundary).Append(#13#10);
      SB.Append('Content-Type: ').Append(A.MimeType).Append('; name=').Append(QuotedName(A.FileName)).Append(#13#10);
      SB.Append('Content-Disposition: attachment; filename=').Append(QuotedName(A.FileName)).Append(#13#10);
      SB.Append('Content-Transfer-Encoding: base64').Append(#13#10);
      SB.Append(#13#10);
      SB.Append(Base64Lines(A.Data)).Append(#13#10);
    end;
    SB.Append('--').Append(Boundary).Append('--').Append(#13#10);
    // dot-stuffing: a line that starts with a dot gets another (base64 never does; the text might)
    Lines := SB.ToString.Split([#13#10]);
    SB.Clear;
    for Line in Lines do
      if Line.StartsWith('.') then
        SB.Append('.').Append(Line).Append(#13#10)
      else
        SB.Append(Line).Append(#13#10);
    Result := SB.ToString;
    // Split leaves an empty last piece after the final CR LF
    if Result.EndsWith(#13#10#13#10) then
      SetLength(Result, Length(Result) - 2);
  finally
    SB.Free;
  end;
end;

type
  TSmtpSession = class
  private
    FConn: ITextConnection;
    FServer: string;
    FLastText: string;
    FCaps: TArray<string>;
  public
    constructor Create(const Server: string; Conn: ITextConnection);
    { Reads a reply (all its lines); returns its code. }
    function Reply: Integer;
    { Sends a command and checks the reply is one of Expected. }
    function Command(const Text: string; const Expected: array of Integer; const Shown: string = ''): Integer;
    procedure Fail(const What: string);
    procedure Ehlo;
    function HasCap(const Name: string): Boolean;
    function AuthMethods: string;
  end;

constructor TSmtpSession.Create(const Server: string; Conn: ITextConnection);
begin
  FServer := Server;
  FConn := Conn;
end;

{ A reply line for people: without the enhanced status code ("5.7.8 ")
  and a server's own session id at the end ("<id> - gsmtp"). }
function Tidy(const Text: string): string;
begin
  Result := Trim(TRegEx.Replace(Text, '^\d\.\d{1,3}\.\d{1,3}\s+', ''));
  Result := Trim(TRegEx.Replace(Result, '\s+\S+\s+-\s+gsmtp$', ''));
  Result := Trim(TRegEx.Replace(Result, '\s\d\.\d{1,3}\.\d{1,3}\s+', ' '));
end;

function TSmtpSession.Reply: Integer;
var
  Line: string;
begin
  FLastText := '';
  FCaps := nil;
  repeat
    Line := FConn.ReadLine;
    if (Length(Line) < 3) or not TryStrToInt(Copy(Line, 1, 3), Result) then
      raise ESmtpError.CreateFmt('%s does not answer like a mail server: "%s"', [FServer, Copy(Line, 1, 80)]);
    FLastText := Trim(FLastText + ' ' + Tidy(Copy(Line, 5, MaxInt)));
    FCaps := FCaps + [UpperCase(Trim(Copy(Line, 5, MaxInt)))];
  until (Length(Line) < 4) or (Line[4] <> '-');
end;

procedure TSmtpSession.Fail(const What: string);
var
  Msg: string;
begin
  Msg := Format('%s: the mail server said "%s"', [What, FLastText]);
  if (ContainsText(FServer, 'gmail') or ContainsText(FLastText, 'google')) and
    (ContainsText(FLastText, 'password') or ContainsText(FLastText, 'BadCredentials')) then
    Msg := Msg + '. Gmail needs an app password (Google account > Security > 2-Step Verification > ' +
      'App passwords), not the account''s own';
  raise ESmtpError.Create(Msg);
end;

function TSmtpSession.Command(const Text: string; const Expected: array of Integer; const Shown: string): Integer;
var
  E: Integer;
begin
  FConn.SendText(Text + #13#10);
  Result := Reply;
  for E in Expected do
    if Result = E then
      Exit;
  Fail(IfThen(Shown <> '', Shown, Text));
end;

procedure TSmtpSession.Ehlo;
begin
  Command('EHLO uvscan', [250], 'Hello');
end;

function TSmtpSession.HasCap(const Name: string): Boolean;
var
  C: string;
begin
  for C in FCaps do
    if (C = Name) or C.StartsWith(Name + ' ') then
      Exit(True);
  Result := False;
end;

function TSmtpSession.AuthMethods: string;
var
  C: string;
begin
  Result := '';
  for C in FCaps do
    if C.StartsWith('AUTH ') or C.StartsWith('AUTH=') then
      Result := Result + ' ' + Copy(C, 6, MaxInt) + ' ';
end;

procedure SendMail(const Account: TMailAccount; const Recipients: TArray<string>; const Subject, Body: string;
  const Attachments: TArray<TMailAttachment>; TimeoutMs: Integer);
var
  Conn: ITextConnection;
  S: TSmtpSession;
  From, R, Methods: string;
begin
  if Trim(Account.Server) = '' then
    raise ESmtpError.Create('No mail server set');
  if Length(Recipients) = 0 then
    raise ESmtpError.Create('No one to send it to');
  From := IfThen(Trim(Account.From) <> '', Trim(Account.From), Trim(Account.User));
  if not ValidAddress(From) then
    raise ESmtpError.CreateFmt('"%s" is not an email address to send from', [From]);
  Conn := OpenConnection(Trim(Account.Server), Account.Port, Account.Security = msTls, TimeoutMs);
  S := TSmtpSession.Create(Trim(Account.Server), Conn);
  try
    if S.Reply <> 220 then
      S.Fail('Connecting');
    S.Ehlo;
    if Account.Security = msStartTls then
    begin
      if not S.HasCap('STARTTLS') then
        raise ESmtpError.CreateFmt('%s does not offer STARTTLS: try TLS on port 465', [Account.Server]);
      S.Command('STARTTLS', [220]);
      Conn.StartTls;
      S.Ehlo; // again, over TLS
    end;
    if Account.User <> '' then
    begin
      Methods := S.AuthMethods;
      if Pos(' PLAIN ', Methods) > 0 then
        S.Command('AUTH PLAIN ' + Base64Plain(#0 + Account.User + #0 + Account.Password), [235], 'Signing in')
      else if Pos(' LOGIN ', Methods) > 0 then
      begin
        S.Command('AUTH LOGIN', [334], 'Signing in');
        S.Command(Base64Plain(Account.User), [334], 'Signing in (user)');
        S.Command(Base64Plain(Account.Password), [235], 'Signing in');
      end
      else
        raise ESmtpError.CreateFmt('%s offers no way to sign in that UVScan knows (PLAIN or LOGIN)',
          [Account.Server]);
    end;
    S.Command('MAIL FROM:<' + From + '>', [250], 'Sending from ' + From);
    for R in Recipients do
      S.Command('RCPT TO:<' + R + '>', [250, 251], 'Sending to ' + R);
    S.Command('DATA', [354]);
    Conn.SendText(BuildMessage(From, Recipients, Subject, Body, Attachments, Now) + '.'#13#10);
    if S.Reply <> 250 then
      S.Fail('Sending the message');
    try
      S.Command('QUIT', [221]);
    except
      // sent already: a server that hangs up at once is fine
    end;
  finally
    S.Free;
    Conn.Close;
  end;
end;

initialization
  Randomize;

end.
