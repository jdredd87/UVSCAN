unit UVScan.Dtc;

{ Trouble code descriptions from dtcs.csv: "P0300,Random Misfire Detected".
  Descriptions may contain unquoted commas, so everything after the first
  comma is the description. }

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  TDtcCatalog = class
  private
    FItems: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const FileName: string);
    function Describe(const Code: string): string;
    function Count: Integer;
  end;

implementation

constructor TDtcCatalog.Create;
begin
  inherited;
  FItems := TDictionary<string, string>.Create;
end;

destructor TDtcCatalog.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TDtcCatalog.LoadFromFile(const FileName: string);
var
  Lines: TStringList;
  Line, Code: string;
  P: Integer;
begin
  FItems.Clear;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    for Line in Lines do
    begin
      P := Pos(',', Line);
      if P < 2 then
        Continue;
      Code := UpperCase(Trim(Copy(Line, 1, P - 1)));
      FItems.AddOrSetValue(Code, Trim(Copy(Line, P + 1, MaxInt)).DeQuotedString('"'));
    end;
  finally
    Lines.Free;
  end;
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
