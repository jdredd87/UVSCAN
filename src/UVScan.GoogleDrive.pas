unit UVScan.GoogleDrive;

{ Putting files in someone's Google Drive (Drive API v3 over HTTPS, the
  platform's own HTTP client).

  Signing in is Google's flow for devices: UVScan shows a short code, the
  person opens google.com/device on any phone or computer, types it and
  allows UVScan to see the files it makes in their Drive (the drive.file
  scope: nothing else of theirs). UVScan keeps the refresh token that
  comes back and gets a fresh access token from it when it needs one.

  It needs a Google Cloud OAuth client of the type "TVs and Limited Input
  devices" with the Google Drive API on (its ID and secret: DriveApp).
  Everything blocks: run it on a thread of its own. }

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.HttpClient, System.Net.URLClient;

type
  EDriveError = class(Exception);

  TDriveApp = record
    ClientId: string;
    ClientSecret: string;
    function IsSet: Boolean;
  end;

  TDeviceSignIn = record
    DeviceCode: string;
    UserCode: string;   // what the person types, 'ABCD-EFGH'
    VerifyUrl: string;  // where: https://www.google.com/device
    ExpiresAt: TDateTime;
    IntervalS: Integer; // how often to ask whether it is done
  end;

  TDriveClient = class
  private
    FApp: TDriveApp;
    FRefreshToken: string;
    FAccessToken: string;
    FExpires: TDateTime;
    FHttp: THTTPClient;
    function Headers(const ContentType: string = ''): TNetHeaders;
    function Call(const Method, Url: string; Body: TStream; const ContentType: string): TJSONObject;
  public
    constructor Create(const App: TDriveApp; const RefreshToken: string);
    destructor Destroy; override;
    { A valid access token (asks Google for a new one when it has run out). }
    function AccessToken: string;
    { The signed-in person's address. }
    function Email: string;
    { The folder of this name UVScan made in My Drive, made now if there is none. }
    function FolderId(const Name: string): string;
    { A new file in the folder; returns its id. }
    function Upload(const FolderId, FileName, MimeType: string; const Data: TBytes): string;
    { Replaces the contents of a file made by Upload. }
    procedure Update(const FileId, MimeType: string; const Data: TBytes);
  end;

{ Step 1 of signing in: the code to show. }
function StartDeviceSignIn(const App: TDriveApp): TDeviceSignIn;
{ Step 2, every IntervalS seconds: True with the refresh token once the
  person has allowed it; False while waiting. Raises when they said no or
  the code ran out. }
function PollDeviceSignIn(const App: TDriveApp; var SignIn: TDeviceSignIn; out RefreshToken: string): Boolean;

const
  DriveScope = 'https://www.googleapis.com/auth/drive.file';
  { UVScan's own Google Cloud client (none yet: set one in the settings). }
  DefaultDriveClientId = '';
  DefaultDriveClientSecret = '';

var
  { Where Google is; tests point them at a local server. }
  DriveOAuthUrl: string = 'https://oauth2.googleapis.com';
  DriveApiUrl: string = 'https://www.googleapis.com';

implementation

uses
  System.DateUtils, System.NetEncoding, System.StrUtils, System.Math, System.Generics.Collections,
  UVScan.JsonFile;

const
  ConnectTimeoutMs = 15000;
  ResponseTimeoutMs = 120000; // an upload over a slow mobile connection

function TDriveApp.IsSet: Boolean;
begin
  Result := (Trim(ClientId) <> '') and (Trim(ClientSecret) <> '');
end;

function NewHttp: THTTPClient;
begin
  Result := THTTPClient.Create;
  Result.UserAgent := 'UVScan';
  Result.ConnectionTimeout := ConnectTimeoutMs;
  Result.ResponseTimeout := ResponseTimeoutMs;
end;

function ParseBody(Resp: IHTTPResponse): TJSONObject;
var
  V: TJSONValue;
begin
  V := TJSONObject.ParseJSONValue(Resp.ContentAsString(TEncoding.UTF8));
  if V is TJSONObject then
    Exit(TJSONObject(V));
  V.Free;
  Result := TJSONObject.Create;
end;

{ Google's own words for an error: OAuth's "error"/"error_description", or
  the API's "error" object with its "message". }
function ErrorText(Body: TJSONObject; Status: Integer): string;
var
  E: TJSONValue;
begin
  E := Body.GetValue('error');
  if E is TJSONObject then
    Result := JStr(TJSONObject(E), 'message')
  else if E <> nil then
    Result := Trim(E.Value + ' ' + JStr(Body, 'error_description'))
  else
    Result := '';
  if Result = '' then
    Result := Format('HTTP %d', [Status]);
end;

function PostForm(const Url: string; const Fields: array of string): TJSONObject;
var
  Http: THTTPClient;
  Form: TStringList;
  Resp: IHTTPResponse;
  I: Integer;
begin
  Http := NewHttp;
  Form := TStringList.Create;
  try
    I := 0;
    while I < High(Fields) do
    begin
      Form.AddPair(Fields[I], Fields[I + 1]);
      Inc(I, 2);
    end;
    try
      Resp := Http.Post(Url, Form);
    except
      on E: Exception do
        raise EDriveError.Create('Could not reach Google: ' + E.Message);
    end;
    Result := ParseBody(Resp);
    Result.AddPair('_status', TJSONNumber.Create(Resp.StatusCode));
  finally
    Form.Free;
    Http.Free;
  end;
end;

function CheckApp(const App: TDriveApp): Boolean;
begin
  if not App.IsSet then
    raise EDriveError.Create('No Google app is set up for UVScan yet (its client ID and secret, in the ' +
      'Google Drive settings)');
  Result := True;
end;

function StartDeviceSignIn(const App: TDriveApp): TDeviceSignIn;
var
  J: TJSONObject;
begin
  CheckApp(App);
  J := PostForm(DriveOAuthUrl + '/device/code', ['client_id', Trim(App.ClientId), 'scope', DriveScope]);
  try
    if JInt(J, '_status') <> 200 then
      raise EDriveError.Create('Google would not start the sign-in: ' + ErrorText(J, JInt(J, '_status')));
    Result.DeviceCode := JStr(J, 'device_code');
    Result.UserCode := JStr(J, 'user_code');
    Result.VerifyUrl := JStr(J, 'verification_url', JStr(J, 'verification_uri', 'https://www.google.com/device'));
    Result.ExpiresAt := IncSecond(Now, JInt(J, 'expires_in', 1800));
    Result.IntervalS := Max(1, JInt(J, 'interval', 5));
    if (Result.DeviceCode = '') or (Result.UserCode = '') then
      raise EDriveError.Create('Google''s answer had no sign-in code');
  finally
    J.Free;
  end;
end;

function PollDeviceSignIn(const App: TDriveApp; var SignIn: TDeviceSignIn; out RefreshToken: string): Boolean;
var
  J: TJSONObject;
  Err: string;
begin
  RefreshToken := '';
  if Now > SignIn.ExpiresAt then
    raise EDriveError.Create('The code ran out before it was used: start the sign-in again');
  J := PostForm(DriveOAuthUrl + '/token', ['client_id', Trim(App.ClientId), 'client_secret',
    Trim(App.ClientSecret), 'device_code', SignIn.DeviceCode, 'grant_type',
    'urn:ietf:params:oauth:grant-type:device_code']);
  try
    if JInt(J, '_status') = 200 then
    begin
      RefreshToken := JStr(J, 'refresh_token');
      if RefreshToken = '' then
        raise EDriveError.Create('Google allowed it but sent no refresh token');
      Exit(True);
    end;
    Err := JStr(J, 'error');
    if Err = 'authorization_pending' then
      Exit(False);
    if Err = 'slow_down' then
    begin
      Inc(SignIn.IntervalS, 5);
      Exit(False);
    end;
    if Err = 'access_denied' then
      raise EDriveError.Create('The sign-in was turned down');
    if Err = 'expired_token' then
      raise EDriveError.Create('The code ran out before it was used: start the sign-in again');
    raise EDriveError.Create('Google: ' + ErrorText(J, JInt(J, '_status')));
  finally
    J.Free;
  end;
end;

{ TDriveClient }

constructor TDriveClient.Create(const App: TDriveApp; const RefreshToken: string);
begin
  inherited Create;
  FApp := App;
  FRefreshToken := RefreshToken;
  FHttp := NewHttp;
end;

destructor TDriveClient.Destroy;
begin
  FHttp.Free;
  inherited;
end;

function TDriveClient.AccessToken: string;
var
  J: TJSONObject;
begin
  if (FAccessToken <> '') and (Now < FExpires) then
    Exit(FAccessToken);
  CheckApp(FApp);
  if FRefreshToken = '' then
    raise EDriveError.Create('Not signed in to Google Drive');
  J := PostForm(DriveOAuthUrl + '/token', ['client_id', Trim(FApp.ClientId), 'client_secret',
    Trim(FApp.ClientSecret), 'refresh_token', FRefreshToken, 'grant_type', 'refresh_token']);
  try
    if JInt(J, '_status') <> 200 then
    begin
      if JStr(J, 'error') = 'invalid_grant' then
        raise EDriveError.Create('The Google Drive sign-in has run out or was taken back: sign in again');
      raise EDriveError.Create('Google Drive sign-in: ' + ErrorText(J, JInt(J, '_status')));
    end;
    FAccessToken := JStr(J, 'access_token');
    // a minute early, so it does not run out half way through an upload
    FExpires := IncSecond(Now, Max(60, JInt(J, 'expires_in', 3600) - 60));
  finally
    J.Free;
  end;
  Result := FAccessToken;
end;

function TDriveClient.Headers(const ContentType: string): TNetHeaders;
begin
  Result := [TNetHeader.Create('Authorization', 'Bearer ' + AccessToken)];
  if ContentType <> '' then
    Result := Result + [TNetHeader.Create('Content-Type', ContentType)];
end;

function TDriveClient.Call(const Method, Url: string; Body: TStream; const ContentType: string): TJSONObject;
var
  Resp: IHTTPResponse;
  H: TNetHeaders;
begin
  H := Headers(ContentType);
  try
    if Method = 'GET' then
      Resp := FHttp.Get(Url, nil, H)
    else if Method = 'PATCH' then
      Resp := FHttp.Patch(Url, Body, nil, H)
    else
      Resp := FHttp.Post(Url, Body, nil, H);
  except
    on E: Exception do
      raise EDriveError.Create('Could not reach Google Drive: ' + E.Message);
  end;
  Result := ParseBody(Resp);
  if (Resp.StatusCode < 200) or (Resp.StatusCode > 299) then
    try
      if Resp.StatusCode = 401 then
        FAccessToken := ''; // the next try asks for a new one
      raise EDriveError.Create('Google Drive: ' + ErrorText(Result, Resp.StatusCode));
    finally
      Result.Free;
    end;
end;

function TDriveClient.Email: string;
var
  J: TJSONObject;
begin
  J := Call('GET', DriveApiUrl + '/drive/v3/about?fields=user(emailAddress)', nil, '');
  try
    Result := JStr(JObj(J, 'user'), 'emailAddress');
  finally
    J.Free;
  end;
end;

function TDriveClient.FolderId(const Name: string): string;
var
  J, F: TJSONObject;
  Files: TJSONArray;
  Q: string;
  Body: TStringStream;
begin
  Q := Format('name = ''%s'' and mimeType = ''application/vnd.google-apps.folder'' and trashed = false',
    [StringReplace(Name, '''', '\''', [rfReplaceAll])]);
  J := Call('GET', DriveApiUrl + '/drive/v3/files?spaces=drive&fields=files(id)&q=' +
    TNetEncoding.URL.Encode(Q), nil, '');
  try
    Files := JArr(J, 'files');
    if (Files <> nil) and (Files.Count > 0) and (Files.Items[0] is TJSONObject) then
      Exit(JStr(TJSONObject(Files.Items[0]), 'id'));
  finally
    J.Free;
  end;
  F := TJSONObject.Create;
  try
    F.AddPair('name', Name);
    F.AddPair('mimeType', 'application/vnd.google-apps.folder');
    Body := TStringStream.Create(F.ToJSON, TEncoding.UTF8);
  finally
    F.Free;
  end;
  try
    J := Call('POST', DriveApiUrl + '/drive/v3/files?fields=id', Body, 'application/json; charset=UTF-8');
  finally
    Body.Free;
  end;
  try
    Result := JStr(J, 'id');
  finally
    J.Free;
  end;
  if Result = '' then
    raise EDriveError.Create('Google Drive made the folder but sent no id');
end;

function TDriveClient.Upload(const FolderId, FileName, MimeType: string; const Data: TBytes): string;
var
  Meta: TJSONObject;
  Parents: TJSONArray;
  Boundary: string;
  Body: TBytesStream;
  J: TJSONObject;

  procedure Put(const S: string);
  var
    B: TBytes;
  begin
    B := TEncoding.UTF8.GetBytes(S);
    Body.WriteBuffer(B, Length(B));
  end;

begin
  Boundary := 'uvscan_' + IntToHex(Random(MaxInt), 8);
  Meta := TJSONObject.Create;
  Body := TBytesStream.Create;
  try
    Meta.AddPair('name', FileName);
    if FolderId <> '' then
    begin
      Parents := TJSONArray.Create;
      Parents.Add(FolderId);
      Meta.AddPair('parents', Parents);
    end;
    Put('--' + Boundary + #13#10'Content-Type: application/json; charset=UTF-8'#13#10#13#10 + Meta.ToJSON +
      #13#10'--' + Boundary + #13#10'Content-Type: ' + MimeType + #13#10#13#10);
    if Length(Data) > 0 then
      Body.WriteBuffer(Data, Length(Data));
    Put(#13#10'--' + Boundary + '--'#13#10);
    Body.Position := 0;
    J := Call('POST', DriveApiUrl + '/upload/drive/v3/files?uploadType=multipart&fields=id', Body,
      'multipart/related; boundary=' + Boundary);
    try
      Result := JStr(J, 'id');
    finally
      J.Free;
    end;
  finally
    Body.Free;
    Meta.Free;
  end;
end;

procedure TDriveClient.Update(const FileId, MimeType: string; const Data: TBytes);
var
  Body: TBytesStream;
begin
  Body := TBytesStream.Create(Data);
  try
    Call('PATCH', DriveApiUrl + '/upload/drive/v3/files/' + FileId + '?uploadType=media&fields=id', Body,
      MimeType).Free;
  finally
    Body.Free;
  end;
end;

end.
