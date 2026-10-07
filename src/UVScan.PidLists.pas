unit UVScan.PidLists;

(* Named scan lists (lists.json): saved selections of PID ids, e.g.

  { "version": 1,
    "lists": [
      { "name": "Misfires", "pids": [40, 41, 42] },
      { "name": "Transmission", "pids": [50, 51] } ] }

  Definitions live in pids.json; a list only refers to ids, so fixing a
  formula there fixes it in every list. Ids that no longer exist are ignored
  when a list is applied. *)

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections;

type
  TPidList = record
    Name: string;
    PidIds: TArray<Integer>;
  end;

  TPidLists = class
  private
    FItems: TList<TPidList>;
    FWarnings: TStringList;
    function GetCount: Integer;
    function GetItem(Index: Integer): TPidList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromJson(Root: TJSONObject);
    procedure LoadFromJsonText(const Text: string);
    function ToJson: TJSONObject;
    procedure SaveToFile(const FileName: string);
    function IndexOf(const Name: string): Integer;
    { Adds a new list or replaces the ids of an existing one (names are case-insensitive). }
    procedure Put(const Name: string; const PidIds: TArray<Integer>);
    procedure Delete(const Name: string);
    function Names: TArray<string>;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TPidList read GetItem; default;
    property Warnings: TStringList read FWarnings;
  end;

const
  ListsFileVersion = 1;

implementation

uses
  System.Generics.Defaults, UVScan.JsonFile;

constructor TPidLists.Create;
begin
  inherited;
  FItems := TList<TPidList>.Create;
  FWarnings := TStringList.Create;
end;

destructor TPidLists.Destroy;
begin
  FItems.Free;
  FWarnings.Free;
  inherited;
end;

function TPidLists.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TPidLists.GetItem(Index: Integer): TPidList;
begin
  Result := FItems[Index];
end;

procedure TPidLists.LoadFromFile(const FileName: string);
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

procedure TPidLists.LoadFromJsonText(const Text: string);
var
  Root: TJSONObject;
begin
  Root := ParseJsonObject(Text, 'lists.json');
  try
    LoadFromJson(Root);
  finally
    Root.Free;
  end;
end;

procedure TPidLists.LoadFromJson(Root: TJSONObject);
var
  Arr, Ids: TJSONArray;
  I, J: Integer;
  E: TJSONObject;
  L: TPidList;
begin
  FItems.Clear;
  FWarnings.Clear;
  Arr := JArr(Root, 'lists');
  if Arr = nil then
    Exit;
  for I := 0 to Arr.Count - 1 do
  begin
    if not (Arr.Items[I] is TJSONObject) then
    begin
      FWarnings.Add(Format('lists[%d]: not an object', [I]));
      Continue;
    end;
    E := TJSONObject(Arr.Items[I]);
    L.Name := Trim(JStr(E, 'name'));
    L.PidIds := nil;
    if L.Name = '' then
    begin
      FWarnings.Add(Format('lists[%d]: missing "name"', [I]));
      Continue;
    end;
    if IndexOf(L.Name) >= 0 then
    begin
      FWarnings.Add(Format('lists[%d]: duplicate list name "%s"', [I, L.Name]));
      Continue;
    end;
    Ids := JArr(E, 'pids');
    if Ids <> nil then
      for J := 0 to Ids.Count - 1 do
        if Ids.Items[J] is TJSONNumber then
          L.PidIds := L.PidIds + [TJSONNumber(Ids.Items[J]).AsInt];
    FItems.Add(L);
  end;
end;

function TPidLists.ToJson: TJSONObject;
var
  Arr, Ids: TJSONArray;
  L: TPidList;
  E: TJSONObject;
  Id: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('version', TJSONNumber.Create(ListsFileVersion));
  Arr := TJSONArray.Create;
  Result.AddPair('lists', Arr);
  for L in FItems do
  begin
    E := TJSONObject.Create;
    E.AddPair('name', L.Name);
    Ids := TJSONArray.Create;
    for Id in L.PidIds do
      Ids.Add(Id);
    E.AddPair('pids', Ids);
    Arr.AddElement(E);
  end;
end;

procedure TPidLists.SaveToFile(const FileName: string);
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

function TPidLists.IndexOf(const Name: string): Integer;
begin
  for Result := 0 to FItems.Count - 1 do
    if SameText(FItems[Result].Name, Trim(Name)) then
      Exit;
  Result := -1;
end;

procedure TPidLists.Put(const Name: string; const PidIds: TArray<Integer>);
var
  L: TPidList;
  I: Integer;
begin
  L.Name := Trim(Name);
  if L.Name = '' then
    raise EArgumentException.Create('A list needs a name');
  L.PidIds := Copy(PidIds);
  I := IndexOf(L.Name);
  if I >= 0 then
    FItems[I] := L
  else
  begin
    FItems.Add(L);
    FItems.Sort(TComparer<TPidList>.Construct(
      function(const A, B: TPidList): Integer
      begin
        Result := CompareText(A.Name, B.Name);
      end));
  end;
end;

procedure TPidLists.Delete(const Name: string);
var
  I: Integer;
begin
  I := IndexOf(Name);
  if I >= 0 then
    FItems.Delete(I);
end;

function TPidLists.Names: TArray<string>;
var
  L: TPidList;
begin
  Result := nil;
  for L in FItems do
    Result := Result + [L.Name];
end;

end.
