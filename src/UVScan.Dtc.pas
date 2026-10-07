unit UVScan.Dtc;

(* Trouble code descriptions, stored as dtcs.json:

  { "version": 1,
    "dtcs": [
      { "code": "P0300", "description": "Random Misfire Detected" },
      ... ] } *)

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections;

type
  TDtcCatalog = class
  private
    FItems: TDictionary<string, string>;
    FWarnings: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromJson(Root: TJSONObject);
    procedure LoadFromJsonText(const Text: string);
    function ToJson: TJSONObject;
    procedure SaveToJsonFile(const FileName: string);
    procedure AddOrSet(const Code, Description: string);
    function Describe(const Code: string): string;
    function Count: Integer;
    property Warnings: TStringList read FWarnings;
  end;

const
  DtcFileVersion = 1;

implementation

uses
  System.Generics.Defaults, UVScan.JsonFile;

constructor TDtcCatalog.Create;
begin
  inherited;
  FItems := TDictionary<string, string>.Create;
  FWarnings := TStringList.Create;
end;

destructor TDtcCatalog.Destroy;
begin
  FItems.Free;
  FWarnings.Free;
  inherited;
end;

procedure TDtcCatalog.LoadFromFile(const FileName: string);
var
  Root: TJSONObject;
begin
  Root := ReadJsonObject(FileName);
  try
    LoadFromJson(Root);
  finally
    Root.Free;
  end;
end;

procedure TDtcCatalog.LoadFromJsonText(const Text: string);
var
  Root: TJSONObject;
begin
  Root := ParseJsonObject(Text, 'dtcs.json');
  try
    LoadFromJson(Root);
  finally
    Root.Free;
  end;
end;

procedure TDtcCatalog.LoadFromJson(Root: TJSONObject);
var
  Arr: TJSONArray;
  I: Integer;
  E: TJSONObject;
  Code: string;
begin
  FItems.Clear;
  FWarnings.Clear;
  if JInt(Root, 'version', DtcFileVersion) > DtcFileVersion then
    FWarnings.Add('dtcs.json was written by a newer UVScan; unknown fields are ignored');
  Arr := JArr(Root, 'dtcs');
  if Arr = nil then
  begin
    FWarnings.Add('dtcs.json has no "dtcs" array');
    Exit;
  end;
  for I := 0 to Arr.Count - 1 do
  begin
    if not (Arr.Items[I] is TJSONObject) then
    begin
      FWarnings.Add(Format('dtcs[%d]: not an object', [I]));
      Continue;
    end;
    E := TJSONObject(Arr.Items[I]);
    Code := UpperCase(Trim(JStr(E, 'code')));
    if Code = '' then
    begin
      FWarnings.Add(Format('dtcs[%d]: missing "code"', [I]));
      Continue;
    end;
    AddOrSet(Code, Trim(JStr(E, 'description')));
  end;
end;

function TDtcCatalog.ToJson: TJSONObject;
var
  Arr: TJSONArray;
  Codes: TArray<string>;
  Code: string;
  E: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('version', TJSONNumber.Create(DtcFileVersion));
  Arr := TJSONArray.Create;
  Result.AddPair('dtcs', Arr);
  Codes := FItems.Keys.ToArray;
  TArray.Sort<string>(Codes);
  for Code in Codes do
  begin
    E := TJSONObject.Create;
    E.AddPair('code', Code);
    E.AddPair('description', FItems[Code]);
    Arr.AddElement(E);
  end;
end;

procedure TDtcCatalog.SaveToJsonFile(const FileName: string);
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

procedure TDtcCatalog.AddOrSet(const Code, Description: string);
begin
  FItems.AddOrSetValue(UpperCase(Trim(Code)), Description);
end;

function TDtcCatalog.Describe(const Code: string): string;
begin
  if not FItems.TryGetValue(UpperCase(Code), Result) then
    Result := '';
end;

function TDtcCatalog.Count: Integer;
begin
  Result := FItems.Count;
end;

end.
