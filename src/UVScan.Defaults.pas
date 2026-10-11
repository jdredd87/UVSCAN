unit UVScan.Defaults;

{ Factory default data compiled into the exe (UVScan.Defaults.rc embeds the
  repo's data\pids.json, dtcs.json, lists.json and display.json). Used to restore the PID
  definitions and to create any data file that is missing at startup, so a
  fresh install needs nothing but the exe. }

interface

uses
  System.SysUtils, UVScan.Pids;

function DefaultPidsJson: string;
function DefaultDtcsJson: string;
function DefaultListsJson: string;
{ Examples for display.json. PIDs are named by "pidCode" because ids differ
  between catalogs; ResolveSeedJson (UVScan.Display) turns them into ids. }
function DefaultDisplayJson: string;
function DefaultControlsJson: string;
function DefaultLogViewsJson: string;

{ Writes the default for each data file that does not exist yet. Returns the
  files that were created. }
function CreateMissingDataFiles: TArray<string>;

{ Adds the built-in scan lists, log views and dashboards that lists.json,
  logviews.json and display.json have not been given yet (each file names
  those it has in "builtIns"), so an update brings the new ones and never
  brings back one the user deleted. PIDs are matched to this install's
  pids.json by kind, PID code and name. Returns what was added, for Messages. }
function AddNewBuiltIns: TArray<string>;
{ The same for these files (tests). }
function AddNewBuiltInsTo(const PidsName, ListsName, ViewsName, DisplayName: string): TArray<string>;

{ The catalog's PID for a built-in example: an enabled vehicle PID with this
  code (and this short name, if given), preferring these units; -1 if none. }
function ResolvePid(Catalog: TPidCatalog; const PidCode, Units, Name: string): Integer;

implementation

uses
  System.Types, System.Classes, System.JSON, UVScan.Paths, UVScan.JsonFile, UVScan.PidLists,
  UVScan.LogViews, UVScan.Display;

const
  // What the first releases had, whose files don't say.
  FirstBuiltInLists: array[0..2] of string = ('Basic engine', 'Misfires', 'Transmission');
  FirstBuiltInViews: array[0..1] of string = ('MPH vs RPM vs IAT', 'Knock check');

function ResourceText(const Name: string): string;
var
  Stream: TResourceStream;
  Bytes: TBytes;
begin
  Stream := TResourceStream.Create(HInstance, Name, RT_RCDATA);
  try
    SetLength(Bytes, Stream.Size);
    if Length(Bytes) > 0 then
      Stream.ReadBuffer(Bytes[0], Length(Bytes));
  finally
    Stream.Free;
  end;
  Result := TEncoding.UTF8.GetString(Bytes);
  if (Result <> '') and (Result[1] = #$FEFF) then
    Delete(Result, 1, 1);
end;

function DefaultPidsJson: string;
begin
  Result := ResourceText('DEFAULT_PIDS');
end;

function DefaultDtcsJson: string;
begin
  Result := ResourceText('DEFAULT_DTCS');
end;

function DefaultListsJson: string;
begin
  Result := ResourceText('DEFAULT_LISTS');
end;

function DefaultDisplayJson: string;
begin
  Result := ResourceText('DEFAULT_DISPLAY');
end;

function DefaultControlsJson: string;
begin
  Result := ResourceText('DEFAULT_CONTROLS');
end;

function DefaultLogViewsJson: string;
begin
  Result := ResourceText('DEFAULT_LOGVIEWS');
end;

function CreateMissingDataFiles: TArray<string>;

  procedure Ensure(const FileName, Json, Source: string);
  var
    Root: TJSONObject;
  begin
    if FileExists(FileName) then
      Exit;
    Root := ParseJsonObject(Json, Source);
    try
      WriteJsonFile(FileName, Root);
    finally
      Root.Free;
    end;
    Result := Result + [FileName];
  end;

begin
  Result := nil;
  Ensure(PidsFile, DefaultPidsJson, 'default pids.json');
  Ensure(DtcsFile, DefaultDtcsJson, 'default dtcs.json');
  Ensure(ListsFile, DefaultListsJson, 'default lists.json');
  Ensure(ControlsFile, DefaultControlsJson, 'default controls.json');
  Ensure(LogViewsFile, DefaultLogViewsJson, 'default logviews.json');
end;

function Has(const Items: TArray<string>; const S: string): Boolean;
var
  Item: string;
begin
  for Item in Items do
    if SameText(Item, S) then
      Exit(True);
  Result := False;
end;

function AddNewLists(const PidsName, ListsName: string): TArray<string>;
var
  Mine, Builtin: TPidCatalog;
  Lists, Defaults: TPidLists;
  I, J, Id: Integer;
  Ids: TArray<Integer>;
  P, Q: TPidDef;
  Name: string;
  Changed: Boolean;
begin
  Result := nil;
  Mine := TPidCatalog.Create;
  Builtin := TPidCatalog.Create;
  Lists := TPidLists.Create;
  Defaults := TPidLists.Create;
  try
    Mine.LoadFromFile(PidsName);
    Builtin.LoadFromJsonText(DefaultPidsJson);
    Lists.LoadFromFile(ListsName);
    Defaults.LoadFromJsonText(DefaultListsJson);
    if Lists.BuiltIns = nil then
      for Name in FirstBuiltInLists do
        Lists.BuiltIns := Lists.BuiltIns + [Name];
    Changed := False;
    for I := 0 to Defaults.Count - 1 do
    begin
      Name := Defaults[I].Name;
      if Has(Lists.BuiltIns, Name) then
        Continue;
      Lists.BuiltIns := Lists.BuiltIns + [Name];
      Changed := True;
      if Lists.IndexOf(Name) >= 0 then
        Continue; // the user has one of that name: theirs stays
      Ids := nil;
      for Id in Defaults[I].PidIds do
      begin
        P := Builtin.FindById(Id);
        if P = nil then
          Continue;
        for J := 0 to Mine.Count - 1 do
        begin
          Q := Mine[J];
          if Q.Enabled and (Q.Kind = P.Kind) and SameText(Q.PidCode, P.PidCode) and
            SameText(Q.DisplayName, P.DisplayName) then
          begin
            Ids := Ids + [Q.Id];
            Break;
          end;
        end;
      end;
      if Ids <> nil then
      begin
        Lists.Put(Name, Ids);
        Result := Result + [Format('scan list "%s"', [Name])];
      end;
    end;
    if Changed then
      Lists.SaveToFile(ListsName);
  finally
    Defaults.Free;
    Lists.Free;
    Builtin.Free;
    Mine.Free;
  end;
end;

{ The first "Knock check" named its channels after the demo drive (TPS, MAP),
  so a real scan only charted RPM and KR. }
function IsFirstKnockCheck(V: TLogView): Boolean;
begin
  Result := SameText(V.Name, 'Knock check') and (Length(V.Channels) = 4) and
    SameText(V.Channels[1].Name, 'TPS') and SameText(V.Channels[2].Name, 'MAP');
end;

function AddNewViews(const ViewsName: string): TArray<string>;
var
  Views, Defaults: TLogViewList;
  Root: TJSONObject;
  I, Mine: Integer;
  Name: string;
  Changed: Boolean;
begin
  Result := nil;
  Views := TLogViewList.Create;
  Defaults := TLogViewList.Create;
  try
    Views.LoadFromFile(ViewsName);
    Root := ParseJsonObject(DefaultLogViewsJson, 'default logviews.json');
    try
      Defaults.LoadFromJson(Root);
    finally
      Root.Free;
    end;
    if Views.BuiltIns = nil then
      for Name in FirstBuiltInViews do
        Views.BuiltIns := Views.BuiltIns + [Name];
    Changed := False;
    for I := 0 to Defaults.Count - 1 do
    begin
      Name := Defaults[I].Name;
      Mine := Views.IndexOf(Name);
      if (Mine >= 0) and IsFirstKnockCheck(Views[Mine]) then
      begin
        Views.Put(Defaults[I]);
        Result := Result + [Format('chart view "%s" (fixed for live scans)', [Name])];
        Changed := True;
        Continue;
      end;
      if Has(Views.BuiltIns, Name) then
        Continue;
      Views.BuiltIns := Views.BuiltIns + [Name];
      Changed := True;
      if Mine < 0 then
      begin
        Views.Put(Defaults[I]);
        Result := Result + [Format('chart view "%s"', [Name])];
      end;
    end;
    if Changed then
      Views.SaveToFile(ViewsName);
  finally
    Defaults.Free;
    Views.Free;
  end;
end;

function ResolvePid(Catalog: TPidCatalog; const PidCode, Units, Name: string): Integer;
var
  I: Integer;
  P: TPidDef;
begin
  Result := -1;
  for I := 0 to Catalog.Count - 1 do
  begin
    P := Catalog[I];
    if not P.Enabled or (P.Kind <> pkVehicle) or not SameText(P.PidCode, PidCode) then
      Continue;
    if (Name <> '') and not SameText(P.DisplayName, Name) then
      Continue;
    if (Units = '') or SameText(P.Units, Units) then
      Exit(P.Id);
    if Result < 0 then
      Result := P.Id;
  end;
end;

function AddNewDashboards(const PidsName, DisplayName: string): TArray<string>;
var
  Catalog: TPidCatalog;
  Mine, Builtin: TDisplaySettings;
  Root: TJSONObject;
  I, J, K: Integer;
  Name: string;
  Changed: Boolean;
begin
  Result := nil;
  Catalog := TPidCatalog.Create;
  Mine := TDisplaySettings.Create;
  Builtin := TDisplaySettings.Create;
  try
    Catalog.LoadFromFile(PidsName);
    Mine.LoadFromFile(DisplayName);
    Root := ParseJsonObject(DefaultDisplayJson, 'default display.json');
    try
      ResolveSeedJson(Root,
        function(const PidCode, Units, PidName: string): Integer
        begin
          Result := ResolvePid(Catalog, PidCode, Units, PidName);
        end);
      Builtin.LoadFromJson(Root);
    finally
      Root.Free;
    end;
    if Mine.BuiltIns = nil then
      Mine.BuiltIns := [MainDashboard]; // the first releases had that one
    Changed := False;
    for I := 0 to Builtin.DashboardCount - 1 do
    begin
      Name := Builtin.Dashboards[I].Name;
      if Has(Mine.BuiltIns, Name) then
        Continue;
      Mine.BuiltIns := Mine.BuiltIns + [Name];
      Changed := True;
      if (Mine.IndexOfDashboard(Name) >= 0) or (Builtin.Dashboards[I].Gauges.Count = 0) then
        Continue;
      K := Mine.AddDashboard(Name);
      for J := 0 to Builtin.Dashboards[I].Gauges.Count - 1 do
        Mine.Dashboards[K].Gauges.Add(Builtin.Dashboards[I].Gauges[J]);
      Result := Result + [Format('dashboard "%s"', [Name])];
    end;
    if Changed then
      Mine.SaveToFile(DisplayName);
  finally
    Builtin.Free;
    Mine.Free;
    Catalog.Free;
  end;
end;

function AddNewBuiltInsTo(const PidsName, ListsName, ViewsName, DisplayName: string): TArray<string>;
begin
  Result := nil;
  if FileExists(ListsName) and FileExists(PidsName) then
    Result := Result + AddNewLists(PidsName, ListsName);
  if FileExists(ViewsName) then
    Result := Result + AddNewViews(ViewsName);
  if FileExists(DisplayName) and FileExists(PidsName) then
    Result := Result + AddNewDashboards(PidsName, DisplayName);
end;

function AddNewBuiltIns: TArray<string>;
begin
  Result := AddNewBuiltInsTo(PidsFile, ListsFile, LogViewsFile, DisplayFile);
end;

end.
