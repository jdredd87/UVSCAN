unit UVScan.Update;

{ Is there a newer UVScan? Asks GitHub for the repository's latest release
  (its tag is the version: v2.1.0) and, on Windows, fetches its setup
  program. Releases are made with tools\release.ps1. }

interface

uses
  System.SysUtils, System.Classes;

type
  TUpdateInfo = record
    Version: string;   // '2.1.0' (the tag without its 'v')
    PageUrl: string;   // the release on GitHub
    SetupUrl: string;  // the Windows setup program; '' if the release has none
    SetupName: string; // its file name
    ApkUrl: string;    // the Android package; '' if none
    Notes: string;     // the release's description
  end;

const
  UpdateApiUrl = 'https://api.github.com/repos/jdredd87/UVSCAN/releases/latest';

{ < 0: A is older than B, 0: the same, > 0: newer. Numbers compared one by
  one (2.10.0 is newer than 2.9.0); a leading 'v' and missing parts (2.1 =
  2.1.0) are fine. }
function CompareVersions(const A, B: string): Integer;
{ What to show in UVScan from a release's notes (Markdown): the section under
  the first heading that says "new" or "change" (### What's new, ### Changes
  since v2.0.0), as plain text, at most MaxLines lines; '' if there is none. }
function ReleaseHighlights(const Notes: string; MaxLines: Integer = 12): string;
{ An HTTP error in words a user follows: no internet (a phone on an ELM327's
  own Wi-Fi, say) or no answer in time; anything else as it is. }
function FriendlyNetError(const Msg: string): string;
{ The GitHub API's answer for one release. False if it is not one. }
function ParseRelease(const Json: string; out Info: TUpdateInfo): Boolean;
{ Asks GitHub (waits; not in the main thread). False with Error when it
  cannot: no network, no release yet, ... }
function FetchLatestRelease(const UserAgent: string; out Info: TUpdateInfo; out Error: string): Boolean;
{ FetchLatestRelease in a thread; OnDone runs in the main thread. }
procedure CheckForUpdate(const UserAgent: string; const OnDone: TProc<Boolean, TUpdateInfo, string>);
{ Downloads Url to FileName in a thread; OnDone (main thread) gets '' or the
  error. }
procedure DownloadFile(const Url, FileName, UserAgent: string; const OnDone: TProc<string>);

implementation

uses
  System.Generics.Collections, System.JSON, System.Net.HttpClient, System.Net.URLClient, UVScan.JsonFile;

function CompareVersions(const A, B: string): Integer;

  function Parts(const S: string): TArray<Integer>;
  var
    T: string;
    P: string;
  begin
    T := Trim(S);
    if (T <> '') and CharInSet(T[1], ['v', 'V']) then
      Delete(T, 1, 1);
    Result := nil;
    for P in T.Split(['.']) do
      Result := Result + [StrToIntDef(P, 0)];
  end;

var
  PA, PB: TArray<Integer>;
  I, X, Y: Integer;
begin
  PA := Parts(A);
  PB := Parts(B);
  for I := 0 to Length(PA) + Length(PB) do
  begin
    if I >= Length(PA) then X := 0 else X := PA[I];
    if I >= Length(PB) then Y := 0 else Y := PB[I];
    if X <> Y then
      Exit(Ord(X > Y) * 2 - 1);
  end;
  Result := 0;
end;

function ReleaseHighlights(const Notes: string; MaxLines: Integer): string;
var
  Line, L: string;
  Inside: Boolean;
  Lines: TArray<string>;
begin
  Inside := False;
  Lines := nil;
  for Line in Notes.Replace(#13, '').Split([#10]) do
  begin
    L := Trim(Line);
    if L.StartsWith('#') then
    begin
      if Inside then
        Break; // the next section
      L := LowerCase(L);
      Inside := L.Contains('new') or L.Contains('change');
      Continue;
    end;
    if not Inside or ((L = '') and (Lines = nil)) then
      Continue;
    L := L.Replace('**', '').Replace('`', '').Replace('__', '');
    if L.StartsWith('* ') or L.StartsWith('- ') then
      L := '- ' + Trim(Copy(L, 3, MaxInt));
    if Length(Lines) = MaxLines then
    begin
      Lines := Lines + ['...'];
      Break;
    end;
    Lines := Lines + [L];
  end;
  Result := Trim(string.Join(sLineBreak, Lines));
end;

function ParseRelease(const Json: string; out Info: TUpdateInfo): Boolean;
var
  Root, Asset: TJSONObject;
  Assets: TJSONArray;
  I: Integer;
  Name: string;
begin
  Info := Default(TUpdateInfo);
  Result := False;
  try
    Root := ParseJsonObject(Json, 'GitHub');
  except
    Exit;
  end;
  try
    Info.Version := JStr(Root, 'tag_name');
    if (Info.Version <> '') and CharInSet(Info.Version[1], ['v', 'V']) then
      Delete(Info.Version, 1, 1);
    if (Info.Version = '') or JBool(Root, 'draft') or JBool(Root, 'prerelease') then
      Exit;
    Info.PageUrl := JStr(Root, 'html_url');
    Info.Notes := JStr(Root, 'body');
    Assets := JArr(Root, 'assets');
    if Assets <> nil then
      for I := 0 to Assets.Count - 1 do
        if Assets.Items[I] is TJSONObject then
        begin
          Asset := TJSONObject(Assets.Items[I]);
          Name := JStr(Asset, 'name');
          if Name.EndsWith('-setup.exe', True) then
          begin
            Info.SetupName := Name;
            Info.SetupUrl := JStr(Asset, 'browser_download_url');
          end
          else if Name.EndsWith('.apk', True) then
            Info.ApkUrl := JStr(Asset, 'browser_download_url');
        end;
    Result := True;
  finally
    Root.Free;
  end;
end;

function FriendlyNetError(const Msg: string): string;
const
  // Android (Java) and Windows (WinHTTP 12007 name not resolved, 12029 cannot connect)
  NoNet: array[0..6] of string = ('UnknownHost', 'resolve', 'No address associated', 'unreachable',
    'ConnectException', '12007', '12029');
  Slow: array[0..2] of string = ('timed out', 'timeout', '12002');
var
  S: string;
begin
  for S in NoNet do
    if Msg.Contains(S) or LowerCase(Msg).Contains(LowerCase(S)) then
      Exit('no internet connection');
  for S in Slow do
    if LowerCase(Msg).Contains(LowerCase(S)) then
      Exit('GitHub did not answer in time');
  Result := Msg;
end;

function NewClient(const UserAgent: string): THTTPClient;
begin
  Result := THTTPClient.Create;
  Result.UserAgent := UserAgent; // GitHub turns away requests without one
  Result.ConnectionTimeout := 10000;
  Result.ResponseTimeout := 15000;
end;

function FetchLatestRelease(const UserAgent: string; out Info: TUpdateInfo; out Error: string): Boolean;
var
  Client: THTTPClient;
  Resp: IHTTPResponse;
begin
  Info := Default(TUpdateInfo);
  Error := '';
  Result := False;
  try
    Client := NewClient(UserAgent);
    try
      Resp := Client.Get(UpdateApiUrl, nil, [TNetHeader.Create('Accept', 'application/vnd.github+json')]);
      if Resp.StatusCode = 404 then
        Error := 'no release on GitHub yet'
      else if Resp.StatusCode <> 200 then
        Error := Format('GitHub answered %d %s', [Resp.StatusCode, Resp.StatusText])
      else if not ParseRelease(Resp.ContentAsString(TEncoding.UTF8), Info) then
        Error := 'GitHub''s answer was not a release'
      else
        Result := True;
    finally
      Client.Free;
    end;
  except
    on E: Exception do
      Error := FriendlyNetError(E.Message);
  end;
end;

procedure CheckForUpdate(const UserAgent: string; const OnDone: TProc<Boolean, TUpdateInfo, string>);
begin
  TThread.CreateAnonymousThread(
    procedure
    var
      Ok: Boolean;
      Info: TUpdateInfo;
      Error: string;
    begin
      Ok := FetchLatestRelease(UserAgent, Info, Error);
      TThread.Queue(nil,
        procedure
        begin
          OnDone(Ok, Info, Error);
        end);
    end).Start;
end;

procedure DownloadFile(const Url, FileName, UserAgent: string; const OnDone: TProc<string>);
begin
  TThread.CreateAnonymousThread(
    procedure
    var
      Error: string;
      Client: THTTPClient;
      Resp: IHTTPResponse;
      Part: string;
      F: TFileStream;
    begin
      Error := '';
      Part := FileName + '.part';
      try
        Client := NewClient(UserAgent);
        try
          Client.ResponseTimeout := 120000;
          F := TFileStream.Create(Part, fmCreate);
          try
            Resp := Client.Get(Url, F); // follows GitHub's redirect to the file
          finally
            F.Free;
          end;
          if Resp.StatusCode <> 200 then
            Error := Format('the download answered %d %s', [Resp.StatusCode, Resp.StatusText])
          else
          begin
            if FileExists(FileName) then
              DeleteFile(FileName);
            if not RenameFile(Part, FileName) then
              Error := 'could not save ' + FileName;
          end;
        finally
          Client.Free;
        end;
      except
        on E: Exception do
          Error := FriendlyNetError(E.Message);
      end;
      if (Error <> '') and FileExists(Part) then
        DeleteFile(Part);
      TThread.Queue(nil,
        procedure
        begin
          OnDone(Error);
        end);
    end).Start;
end;

end.
