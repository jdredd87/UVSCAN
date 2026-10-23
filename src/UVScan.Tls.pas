unit UVScan.Tls;

{ A text connection to a server, plain or TLS, for a mail server (SMTP):
  TLS from the start (port 465) or switched on part way (STARTTLS, port
  587). No third-party code and no OpenSSL: on Windows it is Windows' own
  TLS (Schannel) over a socket, on Android Java's SSLSocket. The server's
  certificate is checked against the system's trusted ones and its name.

  Everything blocks (with a timeout), so it runs on a thread of its own. }

interface

uses
  System.SysUtils;

type
  ETlsError = class(Exception);

  ITextConnection = interface
    ['{4F1B2C55-8D0E-4A0B-9D7E-3C6A51E2B9D1}']
    { TLS from here on (STARTTLS once the server said go ahead). }
    procedure StartTls;
    procedure Send(const Data: TBytes);
    procedure SendText(const Text: string); // UTF-8
    { The next line, without its CR LF; raises when nothing comes in time or
      the server has closed the connection. }
    function ReadLine: string;
    function Secure: Boolean;
    procedure Close;
  end;

{ Connects to Host:Port, with TLS from the start when Tls. }
function OpenConnection(const Host: string; Port: Integer; Tls: Boolean;
  TimeoutMs: Integer = 30000): ITextConnection;

var
  { Tests only: a local server with a made-up certificate. }
  TlsSkipCertificateCheck: Boolean = False;

implementation

uses
  System.Classes, System.SyncObjs, System.Math, System.Net.Socket, UVScan.Serial
  {$IFDEF MSWINDOWS}, Winapi.Windows, Winapi.Winsock2{$ENDIF}
  {$IFDEF ANDROID}, Androidapi.JNI.JavaTypes, Androidapi.JNI.Java.Net, Androidapi.JNIBridge, Androidapi.Helpers{$ENDIF};

const
  MaxLine = 64 * 1024;

type
  { The line reading and sending both platforms share; RawSend/RawReceive
    are the connection's (decrypted) bytes. }
  TConnectionBase = class(TInterfacedObject, ITextConnection)
  protected
    FHost: string;
    FTimeoutMs: Integer;
    FIn: TBytes; // received, not read as lines yet
    procedure RawSend(const Data: TBytes); virtual; abstract;
    { Waits for more bytes; empty when the other end has closed. }
    function RawReceive: TBytes; virtual; abstract;
  public
    procedure StartTls; virtual; abstract;
    procedure Send(const Data: TBytes);
    procedure SendText(const Text: string);
    function ReadLine: string;
    function Secure: Boolean; virtual; abstract;
    procedure Close; virtual; abstract;
  end;

procedure TConnectionBase.Send(const Data: TBytes);
begin
  if Length(Data) > 0 then
    RawSend(Data);
end;

procedure TConnectionBase.SendText(const Text: string);
begin
  Send(TEncoding.UTF8.GetBytes(Text));
end;

function TConnectionBase.ReadLine: string;
var
  I: Integer;
  More: TBytes;
begin
  repeat
    for I := 0 to Length(FIn) - 1 do
      if FIn[I] = 10 then
      begin
        if (I > 0) and (FIn[I - 1] = 13) then
          Result := TEncoding.UTF8.GetString(FIn, 0, I - 1)
        else
          Result := TEncoding.UTF8.GetString(FIn, 0, I);
        FIn := Copy(FIn, I + 1, MaxInt);
        Exit;
      end;
    if Length(FIn) > MaxLine then
      raise ETlsError.Create('The server sent a line too long');
    More := RawReceive;
    if Length(More) = 0 then
      raise ETlsError.CreateFmt('%s closed the connection', [FHost]);
    FIn := FIn + More;
  until False;
end;

{$IFDEF MSWINDOWS}

{ Schannel (secur32.dll), declared here: just what a TLS client needs. }

type
  SECURITY_STATUS = Longint;
  TSecHandle = record
    dwLower, dwUpper: ULONG_PTR;
  end;
  PSecHandle = ^TSecHandle;
  TSecBuffer = record
    cbBuffer: ULONG;
    BufferType: ULONG;
    pvBuffer: Pointer;
  end;
  PSecBuffer = ^TSecBuffer;
  TSecBufferDesc = record
    ulVersion: ULONG;
    cBuffers: ULONG;
    pBuffers: PSecBuffer;
  end;
  PSecBufferDesc = ^TSecBufferDesc;
  TTimeStamp_ = record
    LowPart, HighPart: ULONG;
  end;
  TSchannelCred = record
    dwVersion: DWORD;
    cCreds: DWORD;
    paCred: Pointer;
    hRootStore: Pointer;
    cMappers: DWORD;
    aphMappers: Pointer;
    cSupportedAlgs: DWORD;
    palgSupportedAlgs: Pointer;
    grbitEnabledProtocols: DWORD;
    dwMinimumCipherStrength: DWORD;
    dwMaximumCipherStrength: DWORD;
    dwSessionLifespan: DWORD;
    dwFlags: DWORD;
    dwCredFormat: DWORD;
  end;
  TStreamSizes = record
    cbHeader, cbTrailer, cbMaximumMessage, cBuffers, cbBlockSize: ULONG;
  end;

const
  Secur32 = 'secur32.dll';
  UNISP_NAME = 'Microsoft Unified Security Protocol Provider';
  SECPKG_CRED_OUTBOUND = 2;
  SCHANNEL_CRED_VERSION = 4;
  SP_PROT_TLS1_2_CLIENT = $00000800;
  SCH_CRED_NO_DEFAULT_CREDS = $00000010;
  SCH_CRED_MANUAL_CRED_VALIDATION = $00000008;
  SCH_CRED_AUTO_CRED_VALIDATION = $00000020;
  SCH_USE_STRONG_CRYPTO = $00400000;
  ISC_REQ_REPLAY_DETECT = $00000004;
  ISC_REQ_SEQUENCE_DETECT = $00000008;
  ISC_REQ_CONFIDENTIALITY = $00000010;
  ISC_REQ_ALLOCATE_MEMORY = $00000100;
  ISC_REQ_EXTENDED_ERROR = $00004000;
  ISC_REQ_STREAM = $00008000;
  SECBUFFER_VERSION = 0;
  SECBUFFER_EMPTY = 0;
  SECBUFFER_DATA = 1;
  SECBUFFER_TOKEN = 2;
  SECBUFFER_EXTRA = 5;
  SECBUFFER_STREAM_TRAILER = 6;
  SECBUFFER_STREAM_HEADER = 7;
  SECPKG_ATTR_STREAM_SIZES = 4;
  SEC_E_OK = 0;
  SEC_I_CONTINUE_NEEDED = $00090312;
  SEC_I_CONTEXT_EXPIRED = $00090317;
  SEC_I_INCOMPLETE_CREDENTIALS = $00090320;
  SEC_I_RENEGOTIATE = $00090321;
  SEC_E_INCOMPLETE_MESSAGE = SECURITY_STATUS($80090318);
  SEC_E_UNTRUSTED_ROOT = SECURITY_STATUS($80090325);
  SEC_E_WRONG_PRINCIPAL = SECURITY_STATUS($80090322);
  SEC_E_CERT_EXPIRED = SECURITY_STATUS($80090328);
  SEC_E_ALGORITHM_MISMATCH = SECURITY_STATUS($80090331);
  ContextFlags = ISC_REQ_SEQUENCE_DETECT or ISC_REQ_REPLAY_DETECT or ISC_REQ_CONFIDENTIALITY or
    ISC_REQ_EXTENDED_ERROR or ISC_REQ_ALLOCATE_MEMORY or ISC_REQ_STREAM;

function AcquireCredentialsHandleW(pszPrincipal, pszPackage: PWideChar; fCredentialUse: ULONG;
  pvLogonId, pAuthData, pGetKeyFn, pvGetKeyArgument: Pointer; phCredential: PSecHandle;
  ptsExpiry: Pointer): SECURITY_STATUS; stdcall; external Secur32;
function FreeCredentialsHandle(phCredential: PSecHandle): SECURITY_STATUS; stdcall; external Secur32;
function InitializeSecurityContextW(phCredential, phContext: PSecHandle; pszTargetName: PWideChar;
  fContextReq, Reserved1, TargetDataRep: ULONG; pInput: PSecBufferDesc; Reserved2: ULONG;
  phNewContext: PSecHandle; pOutput: PSecBufferDesc; out pfContextAttr: ULONG;
  ptsExpiry: Pointer): SECURITY_STATUS; stdcall; external Secur32;
function DeleteSecurityContext(phContext: PSecHandle): SECURITY_STATUS; stdcall; external Secur32;
function FreeContextBuffer(pvContextBuffer: Pointer): SECURITY_STATUS; stdcall; external Secur32;
function QueryContextAttributesW(phContext: PSecHandle; ulAttribute: ULONG; pBuffer: Pointer): SECURITY_STATUS;
  stdcall; external Secur32;
function EncryptMessage(phContext: PSecHandle; fQOP: ULONG; pMessage: PSecBufferDesc;
  MessageSeqNo: ULONG): SECURITY_STATUS; stdcall; external Secur32;
function DecryptMessage(phContext: PSecHandle; pMessage: PSecBufferDesc; MessageSeqNo: ULONG;
  pfQOP: PULONG): SECURITY_STATUS; stdcall; external Secur32;

function StatusText(S: SECURITY_STATUS): string;
begin
  case S of
    SEC_E_UNTRUSTED_ROOT: Result := 'the server''s certificate is not from a trusted authority';
    SEC_E_WRONG_PRINCIPAL: Result := 'the server''s certificate is for another name';
    SEC_E_CERT_EXPIRED: Result := 'the server''s certificate has expired';
    SEC_E_ALGORITHM_MISMATCH: Result := 'the server and Windows have no TLS version or cipher in common';
  else
    Result := SysErrorMessage(DWORD(S));
    if Result = '' then
      Result := Format('error %.8x', [DWORD(S)]);
  end;
end;

type
  TWinConnection = class(TConnectionBase)
  private
    FSocket: System.Net.Socket.TSocket;
    FCred, FCtx: TSecHandle;
    FHasCred, FHasCtx: Boolean;
    FSizes: TStreamSizes;
    FRaw: TBytes;    // encrypted bytes received, not decrypted yet
    procedure SocketSendAll(const Data: TBytes);
    function SocketReceive: TBytes;
    procedure Handshake;
    procedure FreeTls;
  protected
    procedure RawSend(const Data: TBytes); override;
    function RawReceive: TBytes; override;
  public
    constructor Create(const Host: string; Port, TimeoutMs: Integer);
    destructor Destroy; override;
    procedure StartTls; override;
    function Secure: Boolean; override;
    procedure Close; override;
  end;

constructor TWinConnection.Create(const Host: string; Port, TimeoutMs: Integer);
var
  Job: TEvent;
  S: System.Net.Socket.TSocket;
  Err: string;
begin
  inherited Create;
  FHost := Host;
  FTimeoutMs := TimeoutMs;
  // the connect on a thread of its own: an address nobody answers can take minutes
  S := System.Net.Socket.TSocket.Create(TSocketType.TCP);
  Job := TEvent.Create(nil, True, False, '');
  try
    TThread.CreateAnonymousThread(
      procedure
      begin
        try
          S.Connect(Host, '', '', Port);
        except
          on E: Exception do
            Err := E.Message;
        end;
        Job.SetEvent;
      end).Start;
    if Job.WaitFor(TimeoutMs) <> TWaitResult.wrSignaled then
    begin
      // left to the thread (and leaked) rather than freed under it
      raise ETlsError.CreateFmt('No answer from %s:%d within %d seconds', [Host, Port, TimeoutMs div 1000]);
    end;
    if Err <> '' then
    begin
      FreeSocket(S);
      raise ETlsError.CreateFmt('Could not connect to %s:%d: %s', [Host, Port, Err]);
    end;
  finally
    if Job.WaitFor(0) = TWaitResult.wrSignaled then
      Job.Free;
  end;
  FSocket := S;
end;

destructor TWinConnection.Destroy;
begin
  Close;
  inherited;
end;

procedure TWinConnection.Close;
begin
  FreeTls;
  FreeSocket(FSocket);
end;

procedure TWinConnection.FreeTls;
begin
  if FHasCtx then
    DeleteSecurityContext(@FCtx);
  if FHasCred then
    FreeCredentialsHandle(@FCred);
  FHasCtx := False;
  FHasCred := False;
end;

function TWinConnection.Secure: Boolean;
begin
  Result := FHasCtx;
end;

procedure TWinConnection.SocketSendAll(const Data: TBytes);
var
  Done, N: Integer;
begin
  if FSocket = nil then
    raise ETlsError.Create('The connection is closed');
  Done := 0;
  while Done < Length(Data) do
  begin
    N := SocketSend(FSocket, Data[Done], Length(Data) - Done);
    if N <= 0 then
      raise ETlsError.CreateFmt('%s closed the connection', [FHost]);
    Inc(Done, N);
  end;
end;

function TWinConnection.SocketReceive: TBytes;
var
  N: Integer;
begin
  if FSocket = nil then
    raise ETlsError.Create('The connection is closed');
  if not SocketReadable(FSocket, FTimeoutMs) then
    raise ETlsError.CreateFmt('No answer from %s within %d seconds', [FHost, FTimeoutMs div 1000]);
  SetLength(Result, 16384);
  N := UVScan.Serial.SocketReceive(FSocket, Result[0], Length(Result));
  SetLength(Result, Max(0, N));
end;

procedure TWinConnection.StartTls;
var
  Cred: TSchannelCred;
  S: SECURITY_STATUS;
  Name: string;
begin
  if FHasCtx then
    Exit;
  FillChar(Cred, SizeOf(Cred), 0);
  Cred.dwVersion := SCHANNEL_CRED_VERSION;
  Cred.grbitEnabledProtocols := SP_PROT_TLS1_2_CLIENT;
  Cred.dwFlags := SCH_CRED_NO_DEFAULT_CREDS or SCH_USE_STRONG_CRYPTO;
  if TlsSkipCertificateCheck then
    Cred.dwFlags := Cred.dwFlags or SCH_CRED_MANUAL_CRED_VALIDATION
  else
    Cred.dwFlags := Cred.dwFlags or SCH_CRED_AUTO_CRED_VALIDATION;
  Name := UNISP_NAME;
  S := AcquireCredentialsHandleW(nil, PWideChar(Name), SECPKG_CRED_OUTBOUND, nil, @Cred, nil, nil, @FCred, nil);
  if S <> SEC_E_OK then
    raise ETlsError.Create('Windows could not start TLS: ' + StatusText(S));
  FHasCred := True;
  try
    Handshake;
  except
    FreeTls;
    raise;
  end;
  S := QueryContextAttributesW(@FCtx, SECPKG_ATTR_STREAM_SIZES, @FSizes);
  if S <> SEC_E_OK then
    raise ETlsError.Create('TLS: ' + StatusText(S));
  // what came in after the handshake is the first encrypted data
end;

procedure TWinConnection.Handshake;
var
  InBufs: array[0..1] of TSecBuffer;
  OutBuf: TSecBuffer;
  InDesc, OutDesc: TSecBufferDesc;
  S: SECURITY_STATUS;
  Attr: ULONG;
  Target: string;
  Token, More: TBytes;
  First, NeedData: Boolean;
  NoCertAsks: Integer;
begin
  Target := FHost;
  NoCertAsks := 0;
  FillChar(InBufs, SizeOf(InBufs), 0);
  FRaw := nil;
  First := True;
  NeedData := False;
  repeat
    if NeedData then
    begin
      More := SocketReceive;
      if Length(More) = 0 then
        raise ETlsError.CreateFmt('%s closed the connection during the TLS handshake', [FHost]);
      FRaw := FRaw + More;
    end;
    OutBuf.cbBuffer := 0;
    OutBuf.BufferType := SECBUFFER_TOKEN;
    OutBuf.pvBuffer := nil;
    OutDesc.ulVersion := SECBUFFER_VERSION;
    OutDesc.cBuffers := 1;
    OutDesc.pBuffers := @OutBuf;
    if First then
      S := InitializeSecurityContextW(@FCred, nil, PWideChar(Target), ContextFlags, 0, 0, nil, 0, @FCtx,
        @OutDesc, Attr, nil)
    else
    begin
      InBufs[0].cbBuffer := Length(FRaw);
      InBufs[0].BufferType := SECBUFFER_TOKEN;
      InBufs[0].pvBuffer := Pointer(FRaw);
      InBufs[1].cbBuffer := 0;
      InBufs[1].BufferType := SECBUFFER_EMPTY;
      InBufs[1].pvBuffer := nil;
      InDesc.ulVersion := SECBUFFER_VERSION;
      InDesc.cBuffers := 2;
      InDesc.pBuffers := @InBufs[0];
      S := InitializeSecurityContextW(@FCred, @FCtx, PWideChar(Target), ContextFlags, 0, 0, @InDesc, 0, nil,
        @OutDesc, Attr, nil);
    end;
    if First then
      FHasCtx := (S = SEC_E_OK) or (S = SEC_I_CONTINUE_NEEDED);
    First := False;
    if S = SEC_E_INCOMPLETE_MESSAGE then
    begin
      NeedData := True;
      Continue;
    end;
    // The server would take a certificate of ours (Gmail asks): there is
    // none, and asked again with the same bytes Schannel goes on without.
    if (S = SEC_I_INCOMPLETE_CREDENTIALS) and (NoCertAsks < 3) then
    begin
      Inc(NoCertAsks);
      NeedData := False;
      Continue;
    end;
    // a token to send: the next handshake message, or an alert on a failure
    if (OutBuf.cbBuffer > 0) and (OutBuf.pvBuffer <> nil) then
    begin
      SetLength(Token, OutBuf.cbBuffer);
      Move(OutBuf.pvBuffer^, Token[0], OutBuf.cbBuffer);
      FreeContextBuffer(OutBuf.pvBuffer);
      try
        SocketSendAll(Token);
      except
        if S >= 0 then
          raise;
      end;
    end;
    if S < 0 then
      raise ETlsError.CreateFmt('TLS with %s failed: %s', [FHost, StatusText(S)]);
    // what the server sent beyond this handshake message stays for the next round
    if (Length(FRaw) > 0) and (InBufs[1].BufferType = SECBUFFER_EXTRA) and (InBufs[1].cbBuffer > 0) then
      FRaw := Copy(FRaw, Length(FRaw) - Integer(InBufs[1].cbBuffer), InBufs[1].cbBuffer)
    else
      FRaw := nil;
    InBufs[1].BufferType := SECBUFFER_EMPTY;
    InBufs[1].cbBuffer := 0;
    if S = SEC_E_OK then
      Exit;
    if S <> SEC_I_CONTINUE_NEEDED then
      raise ETlsError.CreateFmt('TLS with %s: the server asked for something UVScan cannot do (%s)',
        [FHost, StatusText(S)]);
    NeedData := Length(FRaw) = 0;
  until False;
end;

procedure TWinConnection.RawSend(const Data: TBytes);
var
  Bufs: array[0..3] of TSecBuffer;
  Desc: TSecBufferDesc;
  Packet: TBytes;
  Done, N: Integer;
  S: SECURITY_STATUS;
begin
  if not FHasCtx then
  begin
    SocketSendAll(Data);
    Exit;
  end;
  Done := 0;
  while Done < Length(Data) do
  begin
    N := Min(Length(Data) - Done, Integer(FSizes.cbMaximumMessage));
    SetLength(Packet, Integer(FSizes.cbHeader) + N + Integer(FSizes.cbTrailer));
    Move(Data[Done], Packet[FSizes.cbHeader], N);
    Bufs[0].BufferType := SECBUFFER_STREAM_HEADER;
    Bufs[0].cbBuffer := FSizes.cbHeader;
    Bufs[0].pvBuffer := @Packet[0];
    Bufs[1].BufferType := SECBUFFER_DATA;
    Bufs[1].cbBuffer := N;
    Bufs[1].pvBuffer := @Packet[FSizes.cbHeader];
    Bufs[2].BufferType := SECBUFFER_STREAM_TRAILER;
    Bufs[2].cbBuffer := FSizes.cbTrailer;
    Bufs[2].pvBuffer := @Packet[Integer(FSizes.cbHeader) + N];
    Bufs[3].BufferType := SECBUFFER_EMPTY;
    Bufs[3].cbBuffer := 0;
    Bufs[3].pvBuffer := nil;
    Desc.ulVersion := SECBUFFER_VERSION;
    Desc.cBuffers := 4;
    Desc.pBuffers := @Bufs[0];
    S := EncryptMessage(@FCtx, 0, @Desc, 0);
    if S <> SEC_E_OK then
      raise ETlsError.Create('TLS: ' + StatusText(S));
    SetLength(Packet, Bufs[0].cbBuffer + Bufs[1].cbBuffer + Bufs[2].cbBuffer);
    SocketSendAll(Packet);
    Inc(Done, N);
  end;
end;

function TWinConnection.RawReceive: TBytes;
var
  Bufs: array[0..3] of TSecBuffer;
  Desc: TSecBufferDesc;
  S: SECURITY_STATUS;
  I: Integer;
  More, Extra: TBytes;
begin
  if not FHasCtx then
    Exit(SocketReceive);
  repeat
    if Length(FRaw) > 0 then
    begin
      Bufs[0].BufferType := SECBUFFER_DATA;
      Bufs[0].cbBuffer := Length(FRaw);
      Bufs[0].pvBuffer := Pointer(FRaw);
      for I := 1 to 3 do
      begin
        Bufs[I].BufferType := SECBUFFER_EMPTY;
        Bufs[I].cbBuffer := 0;
        Bufs[I].pvBuffer := nil;
      end;
      Desc.ulVersion := SECBUFFER_VERSION;
      Desc.cBuffers := 4;
      Desc.pBuffers := @Bufs[0];
      S := DecryptMessage(@FCtx, @Desc, 0, nil);
      if S = SEC_I_CONTEXT_EXPIRED then
        Exit(nil); // the server ended TLS: closed
      if (S = SEC_E_OK) or (S = SEC_I_RENEGOTIATE) then
      begin
        Result := nil;
        Extra := nil;
        for I := 0 to 3 do
          if (Bufs[I].BufferType = SECBUFFER_DATA) and (Bufs[I].cbBuffer > 0) then
          begin
            SetLength(Result, Bufs[I].cbBuffer);
            Move(Bufs[I].pvBuffer^, Result[0], Bufs[I].cbBuffer);
          end
          else if (Bufs[I].BufferType = SECBUFFER_EXTRA) and (Bufs[I].cbBuffer > 0) then
            Extra := Copy(FRaw, Length(FRaw) - Integer(Bufs[I].cbBuffer), Bufs[I].cbBuffer);
        FRaw := Extra;
        if S = SEC_I_RENEGOTIATE then
          raise ETlsError.CreateFmt('%s asked to renegotiate TLS, which UVScan does not do', [FHost]);
        if Length(Result) > 0 then
          Exit;
        Continue; // a record with no data (an empty one): the next
      end;
      if S <> SEC_E_INCOMPLETE_MESSAGE then
        raise ETlsError.Create('TLS: ' + StatusText(S));
    end;
    More := SocketReceive;
    if Length(More) = 0 then
      Exit(nil);
    FRaw := FRaw + More;
  until False;
end;

function OpenConnection(const Host: string; Port: Integer; Tls: Boolean; TimeoutMs: Integer): ITextConnection;
var
  C: TWinConnection;
begin
  C := TWinConnection.Create(Host, Port, TimeoutMs);
  Result := C;
  if Tls then
    C.StartTls;
end;

{$ENDIF}

{$IFDEF ANDROID}

type
  TJavaConnection = class(TConnectionBase)
  private
    FPort: Integer;
    FSocket: JSocket;
    FSecure: Boolean;
    FInput: JInputStream;
    FOutput: JOutputStream;
    procedure TakeStreams;
  protected
    procedure RawSend(const Data: TBytes); override;
    function RawReceive: TBytes; override;
  public
    constructor Create(const Host: string; Port, TimeoutMs: Integer);
    destructor Destroy; override;
    procedure StartTls; override;
    function Secure: Boolean; override;
    procedure Close; override;
  end;

function JavaError(E: Exception): string;
begin
  Result := E.Message;
  // "java.net.UnknownHostException: Unable to resolve host ..." -> after the class
  if Pos(': ', Result) > 0 then
    Result := Copy(Result, Pos(': ', Result) + 2, MaxInt);
end;

constructor TJavaConnection.Create(const Host: string; Port, TimeoutMs: Integer);
begin
  inherited Create;
  FHost := Host;
  FPort := Port;
  FTimeoutMs := TimeoutMs;
  try
    FSocket := TJSocket.JavaClass.init;
    FSocket.connect(TJInetSocketAddress.JavaClass.init(StringToJString(Host), Port), TimeoutMs);
    FSocket.setSoTimeout(TimeoutMs);
  except
    on E: Exception do
    begin
      Close;
      raise ETlsError.CreateFmt('Could not connect to %s:%d: %s', [Host, Port, JavaError(E)]);
    end;
  end;
  TakeStreams;
end;

destructor TJavaConnection.Destroy;
begin
  Close;
  inherited;
end;

procedure TJavaConnection.TakeStreams;
begin
  FInput := FSocket.getInputStream;
  FOutput := FSocket.getOutputStream;
end;

procedure TJavaConnection.Close;
begin
  if FSocket <> nil then
    try
      FSocket.close;
    except
      // gone already
    end;
  FSocket := nil;
  FInput := nil;
  FOutput := nil;
end;

function TJavaConnection.Secure: Boolean;
begin
  Result := FSecure;
end;

procedure TJavaConnection.StartTls;
var
  Factory: Jssl_SSLSocketFactory;
  Ssl: JSSLSocket;
begin
  if FSecure then
    Exit;
  if FSocket = nil then
    raise ETlsError.Create('The connection is closed');
  if TlsSkipCertificateCheck then
    raise ETlsError.Create('No test certificates on Android');
  try
    Factory := TJHttpsURLConnection.JavaClass.getDefaultSSLSocketFactory;
    Ssl := TJSSLSocket.Wrap((Factory.createSocket(FSocket, StringToJString(FHost), FPort, True) as ILocalObject).GetObjectID);
    Ssl.startHandshake;
    // SSLSocket checks the certificate, not that it is this server's: the name too
    if not TJHttpsURLConnection.JavaClass.getDefaultHostnameVerifier.verify(StringToJString(FHost),
      Ssl.getSession) then
    begin
      Ssl.close;
      FSocket := nil;
      raise ETlsError.CreateFmt('The certificate of %s is for another name', [FHost]);
    end;
  except
    on E: ETlsError do
      raise;
    on E: Exception do
      raise ETlsError.CreateFmt('TLS with %s failed: %s', [FHost, JavaError(E)]);
  end;
  FSocket := Ssl;
  FSecure := True;
  TakeStreams;
end;

procedure TJavaConnection.RawSend(const Data: TBytes);
var
  Arr: TJavaArray<Byte>;
begin
  if FOutput = nil then
    raise ETlsError.Create('The connection is closed');
  Arr := TJavaArray<Byte>.Create(Length(Data));
  try
    Move(Data[0], Arr.Data^, Length(Data));
    try
      FOutput.write(Arr, 0, Length(Data));
      FOutput.flush;
    except
      on E: Exception do
        raise ETlsError.CreateFmt('Sending to %s failed: %s', [FHost, JavaError(E)]);
    end;
  finally
    Arr.Free;
  end;
end;

function TJavaConnection.RawReceive: TBytes;
var
  Arr: TJavaArray<Byte>;
  N: Integer;
begin
  if FInput = nil then
    raise ETlsError.Create('The connection is closed');
  Arr := TJavaArray<Byte>.Create(16384);
  try
    try
      N := FInput.read(Arr, 0, 16384);
    except
      on E: Exception do
        if Pos('SocketTimeout', E.Message) > 0 then
          raise ETlsError.CreateFmt('No answer from %s within %d seconds', [FHost, FTimeoutMs div 1000])
        else
          raise ETlsError.CreateFmt('Reading from %s failed: %s', [FHost, JavaError(E)]);
    end;
    if N <= 0 then
      Exit(nil);
    SetLength(Result, N);
    Move(Arr.Data^, Result[0], N);
  finally
    Arr.Free;
  end;
end;

function OpenConnection(const Host: string; Port: Integer; Tls: Boolean; TimeoutMs: Integer): ITextConnection;
var
  C: TJavaConnection;
begin
  C := TJavaConnection.Create(Host, Port, TimeoutMs);
  Result := C;
  if Tls then
    C.StartTls;
end;

{$ENDIF}

end.
