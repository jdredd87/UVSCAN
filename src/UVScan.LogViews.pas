unit UVScan.LogViews;

(* Saved log viewer set-ups (logviews.json): which channels to chart, in what
   colour and width, on which scale, and how to colour values.

  { "version": 1, "lastView": "Knock",
    "views": [
      { "name": "Knock", "mode": "lanes", "useDisplayLevels": true,
        "channels": [
          { "name": "RPM", "color": "#2D7FF9", "width": 2 },
          { "name": "KR", "color": "#FF5050", "width": 2, "min": 0, "max": 10,
            "levelColors": true,
            "levels": [ { "name": "Knock", "when": ">=", "value": 2, "rowColor": "#FF5050" } ] } ] } ] }

  Channels are matched to a log by name ("RPM" or "RPM (RPM)"). Channels of
  the log that a view does not list are hidden when the view is applied. *)

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections, System.UITypes,
  UVScan.Display;

type
  TChartMode = (cmLanes, cmOverlay, cmShared);

  TChannelStyle = record
    Name: string;
    Visible: Boolean;
    Color: TAlphaColor;
    Width: Integer;          // 1..4
    AutoScale: Boolean;
    MinValue, MaxValue: Double;
    LevelColors: Boolean;    // colour the line where an alert level matches
    Levels: TArray<TDisplayLevel>; // own levels; empty = use display.json (if enabled)
  end;

  TLogView = class
  public
    Name: string;
    Mode: TChartMode;
    UseDisplayLevels: Boolean;
    Channels: TArray<TChannelStyle>;
    constructor Create;
    procedure Assign(Source: TLogView);
    function IndexOf(const ChannelName: string): Integer;
    function ToJson: TJSONObject;
    procedure FromJson(Obj: TJSONObject);
  end;

  TLogViewList = class
  private
    FItems: TObjectList<TLogView>;
    function GetCount: Integer;
    function GetItem(Index: Integer): TLogView;
  public
    LastView: string;
    constructor Create;
    destructor Destroy; override;
    function IndexOf(const Name: string): Integer;
    { Replaces a view with the same name or adds it; takes a copy. }
    procedure Put(View: TLogView);
    procedure Delete(Index: Integer);
    procedure LoadFromJson(Root: TJSONObject);
    procedure LoadFromFile(const FileName: string);
    function ToJson: TJSONObject;
    procedure SaveToFile(const FileName: string);
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TLogView read GetItem; default;
  end;

const
  LogViewsFileVersion = 1;
  ChartModeKeys: array[TChartMode] of string = ('lanes', 'overlay', 'shared');
  ChartModeCaptions: array[TChartMode] of string = ('Lanes (one strip each)', 'Overlay (own scales)',
    'Overlay (one scale)');
  { Line colours handed out in order to channels without a saved colour. }
  ChannelPalette: array[0..11] of TAlphaColor = (
    $FF2D7FF9, $FFFF4040, $FF51C235, $FFFFA500, $FFB060C0,
    $FF00B4C8, $FFFF8B4B, $FF808080, $FFC06000, $FF4682B4,
    $FFFF007F, $FF909000);

function DefaultChannelStyle(const Name: string; Index: Integer): TChannelStyle;

implementation

uses
  System.Math, UVScan.JsonFile;

function DefaultChannelStyle(const Name: string; Index: Integer): TChannelStyle;
begin
  Result := Default(TChannelStyle);
  Result.Name := Name;
  Result.Visible := True;
  Result.Color := ChannelPalette[Index mod Length(ChannelPalette)];
  Result.Width := 2;
  Result.AutoScale := True;
  Result.MinValue := 0;
  Result.MaxValue := 100;
end;

function JFloatDef(Obj: TJSONObject; const Name: string; out V: Double): Boolean;
var
  J: TJSONValue;
begin
  J := Obj.GetValue(Name);
  Result := J is TJSONNumber;
  if Result then
    V := TJSONNumber(J).AsDouble;
end;

{ TLogView }

constructor TLogView.Create;
begin
  inherited;
  Mode := cmLanes;
  UseDisplayLevels := True;
end;

procedure TLogView.Assign(Source: TLogView);
var
  I: Integer;
begin
  Name := Source.Name;
  Mode := Source.Mode;
  UseDisplayLevels := Source.UseDisplayLevels;
  Channels := Copy(Source.Channels);
  for I := 0 to High(Channels) do
    Channels[I].Levels := Copy(Source.Channels[I].Levels);
end;

function TLogView.IndexOf(const ChannelName: string): Integer;
begin
  for Result := 0 to High(Channels) do
    if SameText(Channels[Result].Name, ChannelName) then
      Exit;
  Result := -1;
end;

function TLogView.ToJson: TJSONObject;
var
  Arr: TJSONArray;
  C: TChannelStyle;
  E: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', Name);
  Result.AddPair('mode', ChartModeKeys[Mode]);
  Result.AddPair('useDisplayLevels', TJSONBool.Create(UseDisplayLevels));
  Arr := TJSONArray.Create;
  for C in Channels do
  begin
    E := TJSONObject.Create;
    E.AddPair('name', C.Name);
    if not C.Visible then
      E.AddPair('visible', TJSONBool.Create(False));
    E.AddPair('color', ColorToHex(C.Color));
    E.AddPair('width', TJSONNumber.Create(C.Width));
    if not C.AutoScale then
    begin
      E.AddPair('min', TJSONNumber.Create(C.MinValue));
      E.AddPair('max', TJSONNumber.Create(C.MaxValue));
    end;
    if C.LevelColors then
      E.AddPair('levelColors', TJSONBool.Create(True));
    if Length(C.Levels) > 0 then
      E.AddPair('levels', LevelsToJson(C.Levels));
    Arr.AddElement(E);
  end;
  Result.AddPair('channels', Arr);
end;

procedure TLogView.FromJson(Obj: TJSONObject);
var
  Arr: TJSONArray;
  I: Integer;
  E: TJSONObject;
  C: TChannelStyle;
  M: TChartMode;
  A, B: Double;
begin
  Name := JStr(Obj, 'name');
  Mode := cmLanes;
  for M := Low(TChartMode) to High(TChartMode) do
    if SameText(JStr(Obj, 'mode'), ChartModeKeys[M]) then
      Mode := M;
  UseDisplayLevels := JBool(Obj, 'useDisplayLevels', True);
  Channels := nil;
  Arr := JArr(Obj, 'channels');
  if Arr = nil then
    Exit;
  for I := 0 to Arr.Count - 1 do
    if Arr.Items[I] is TJSONObject then
    begin
      E := TJSONObject(Arr.Items[I]);
      C := DefaultChannelStyle(JStr(E, 'name'), I);
      if C.Name = '' then
        Continue;
      C.Visible := JBool(E, 'visible', True);
      C.Color := HexToColor(JStr(E, 'color'), C.Color);
      C.Width := EnsureRange(JInt(E, 'width', 2), 1, 4);
      if JFloatDef(E, 'min', A) and JFloatDef(E, 'max', B) and (B > A) then
      begin
        C.AutoScale := False;
        C.MinValue := A;
        C.MaxValue := B;
      end;
      C.LevelColors := JBool(E, 'levelColors', False);
      C.Levels := LevelsFromJson(JArr(E, 'levels'));
      Channels := Channels + [C];
    end;
end;

{ TLogViewList }

constructor TLogViewList.Create;
begin
  inherited;
  FItems := TObjectList<TLogView>.Create(True);
end;

destructor TLogViewList.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TLogViewList.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TLogViewList.GetItem(Index: Integer): TLogView;
begin
  Result := FItems[Index];
end;

function TLogViewList.IndexOf(const Name: string): Integer;
begin
  for Result := 0 to FItems.Count - 1 do
    if SameText(FItems[Result].Name, Name) then
      Exit;
  Result := -1;
end;

procedure TLogViewList.Put(View: TLogView);
var
  V: TLogView;
  I: Integer;
begin
  V := TLogView.Create;
  V.Assign(View);
  I := IndexOf(View.Name);
  if I >= 0 then
    FItems[I] := V
  else
    FItems.Add(V);
end;

procedure TLogViewList.Delete(Index: Integer);
begin
  FItems.Delete(Index);
end;

procedure TLogViewList.LoadFromJson(Root: TJSONObject);
var
  Arr: TJSONArray;
  I: Integer;
  V: TLogView;
begin
  FItems.Clear;
  LastView := JStr(Root, 'lastView');
  Arr := JArr(Root, 'views');
  if Arr = nil then
    Exit;
  for I := 0 to Arr.Count - 1 do
    if Arr.Items[I] is TJSONObject then
    begin
      V := TLogView.Create;
      V.FromJson(TJSONObject(Arr.Items[I]));
      if (V.Name = '') or (IndexOf(V.Name) >= 0) then
        V.Free
      else
        FItems.Add(V);
    end;
end;

procedure TLogViewList.LoadFromFile(const FileName: string);
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

function TLogViewList.ToJson: TJSONObject;
var
  Arr: TJSONArray;
  V: TLogView;
begin
  Result := TJSONObject.Create;
  Result.AddPair('version', TJSONNumber.Create(LogViewsFileVersion));
  if LastView <> '' then
    Result.AddPair('lastView', LastView);
  Arr := TJSONArray.Create;
  for V in FItems do
    Arr.AddElement(V.ToJson);
  Result.AddPair('views', Arr);
end;

procedure TLogViewList.SaveToFile(const FileName: string);
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

end.
