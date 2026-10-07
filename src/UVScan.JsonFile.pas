unit UVScan.JsonFile;

{ Reading and writing JSON documents on disk (System.JSON).
  Files are UTF-8 without BOM, indented for hand editing, and written via a
  temporary file + rename so a crash never leaves a half-written file. }

interface

uses
  System.SysUtils, System.JSON;

type
  EJsonFileError = class(Exception);

{ Parses FileName; the result must be a JSON object. Caller frees it. }
function ReadJsonObject(const FileName: string): TJSONObject;
function ParseJsonObject(const Text, Source: string): TJSONObject;
procedure WriteJsonFile(const FileName: string; Obj: TJSONObject);
function JsonText(Obj: TJSONObject): string;

{ Typed getters with defaults; a value of the wrong type also gives the default. }
function JStr(Obj: TJSONObject; const Name: string; const Default: string = ''): string;
function JInt(Obj: TJSONObject; const Name: string; Default: Integer = 0): Integer;
function JBool(Obj: TJSONObject; const Name: string; Default: Boolean = False): Boolean;
function JObj(Obj: TJSONObject; const Name: string): TJSONObject;
function JArr(Obj: TJSONObject; const Name: string): TJSONArray;

implementation

uses
  {$IFDEF MSWINDOWS}Winapi.Windows,{$ELSE}Posix.Stdio,{$ENDIF} System.IOUtils;

function ParseJsonObject(const Text, Source: string): TJSONObject;
var
  V: TJSONValue;
begin
  V := TJSONObject.ParseJSONValue(Text, False, True); // raises EJSONParseException with position
  if not (V is TJSONObject) then
  begin
    V.Free;
    raise EJsonFileError.CreateFmt('%s: expected a JSON object at the top level', [Source]);
  end;
  Result := TJSONObject(V);
end;

function ReadJsonObject(const FileName: string): TJSONObject;
begin
  try
    Result := ParseJsonObject(TFile.ReadAllText(FileName, TEncoding.UTF8), ExtractFileName(FileName));
  except
    on E: EJsonFileError do
      raise;
    on E: Exception do
      raise EJsonFileError.CreateFmt('%s: %s', [ExtractFileName(FileName), E.Message]);
  end;
end;

function JsonText(Obj: TJSONObject): string;
begin
  Result := Obj.Format(2);
end;

procedure WriteJsonFile(const FileName: string; Obj: TJSONObject);
var
  FullName, Temp: string;
  Utf8: TEncoding;
begin
  FullName := TPath.GetFullPath(FileName);
  ForceDirectories(ExtractFileDir(FullName));
  Temp := FullName + '.tmp';
  Utf8 := TUTF8Encoding.Create(False);
  try
    TFile.WriteAllText(Temp, JsonText(Obj) + sLineBreak, Utf8);
  finally
    Utf8.Free;
  end;
  {$IFDEF MSWINDOWS}
  if not MoveFileEx(PChar(Temp), PChar(FullName), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
    RaiseLastOSError(GetLastError, ' (saving ' + FullName + ')');
  {$ELSE}
  // RenameFile is rename(), which replaces the target in one step on POSIX
  if not RenameFile(Temp, FullName) then
    RaiseLastOSError(GetLastError, ' (saving ' + FullName + ')');
  {$ENDIF}
end;

function JStr(Obj: TJSONObject; const Name: string; const Default: string): string;
var
  V: TJSONValue;
begin
  V := Obj.GetValue(Name);
  if (V is TJSONString) then
    Result := TJSONString(V).Value
  else if (V is TJSONNumber) then
    Result := V.Value
  else
    Result := Default;
end;

function JInt(Obj: TJSONObject; const Name: string; Default: Integer): Integer;
var
  V: TJSONValue;
begin
  V := Obj.GetValue(Name);
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsInt
  else if V is TJSONString then
    Result := StrToIntDef(TJSONString(V).Value, Default)
  else
    Result := Default;
end;

function JBool(Obj: TJSONObject; const Name: string; Default: Boolean): Boolean;
var
  V: TJSONValue;
begin
  V := Obj.GetValue(Name);
  if V is TJSONBool then
    Result := TJSONBool(V).AsBoolean
  else
    Result := Default;
end;

function JObj(Obj: TJSONObject; const Name: string): TJSONObject;
var
  V: TJSONValue;
begin
  V := Obj.GetValue(Name);
  if V is TJSONObject then
    Result := TJSONObject(V)
  else
    Result := nil;
end;

function JArr(Obj: TJSONObject; const Name: string): TJSONArray;
var
  V: TJSONValue;
begin
  V := Obj.GetValue(Name);
  if V is TJSONArray then
    Result := TJSONArray(V)
  else
    Result := nil;
end;

end.
