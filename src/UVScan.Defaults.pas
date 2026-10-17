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

{ Brings the data files up to date with this UVScan's built-in data, so an
  update brings what is new and never brings back what the user deleted:
  the PIDs (UpdateBuiltInPids, first, so the rest can use new ones), then the
  scan lists, log views and dashboards that lists.json, logviews.json and
  display.json have not been given yet (each file names those it has in
  "builtIns"; their PIDs are matched to this install's pids.json by kind, PID
  code and name), and the trouble code descriptions (UpdateBuiltInDtcs).
  Returns what changed, as sentences for Messages. }
function AddNewBuiltIns: TArray<string>;
{ The same for these files (tests), without the trouble codes. }
function AddNewBuiltInsTo(const PidsName, ListsName, ViewsName, DisplayName: string): TArray<string>;

{ pids.json remembers the built-in PIDs it has been given and how each was
  then (TPidCatalog.BuiltIns). A built-in PID it has not been given is added
  (unless it has one that matches); one that has been corrected since is
  given the correction only where the file's copy is still exactly as it was
  given, so a PID the user changed or deleted stays as they left it. A file
  from before has its "builtIns" filled in with these defaults and nothing
  else changes. A file with entries UVScan cannot read is left alone (saving
  it would lose them). DefaultsJson: the built-in pids.json ('' = this
  UVScan's). }
function UpdateBuiltInPids(const PidsName: string; const DefaultsJson: string = ''): TArray<string>;

{ dtcs.json has no editor in UVScan: when the built-in descriptions are not
  the ones it was last updated from (its "defaults" hash), new and corrected
  codes go in and codes only the file has stay. }
function UpdateBuiltInDtcs(const DtcsName: string; const DefaultsJson: string = ''): TArray<string>;

{ The catalog's PID for a built-in example: an enabled vehicle PID with this
  code (and this short name, if given), preferring these units; -1 if none. }
function ResolvePid(Catalog: TPidCatalog; const PidCode, Units, Name: string): Integer;

implementation

uses
  System.Types, System.Classes, System.JSON, System.Hash, UVScan.Paths, UVScan.JsonFile,
  UVScan.PidLists, UVScan.LogViews, UVScan.Display, UVScan.Dtc, UVScan.LegacyImport;

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
        Result := Result + [Format('Added the built-in scan list "%s"', [Name])];
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
        Result := Result + [Format('Fixed the built-in chart view "%s" for live scans', [Name])];
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
        Result := Result + [Format('Added the built-in chart view "%s"', [Name])];
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
      Result := Result + [Format('Added the built-in dashboard "%s"', [Name])];
    end;
    if Changed then
      Mine.SaveToFile(DisplayName);
  finally
    Builtin.Free;
    Mine.Free;
    Catalog.Free;
  end;
end;

function UpdateBuiltInPids(const PidsName, DefaultsJson: string): TArray<string>;
var
  Root: TJSONObject;
  Arr: TJSONArray;
  Mine, Builtin, Added: TPidCatalog;
  D, P: TPidDef;
  I, J, KeepId: Integer;
  Key, Given, Current: string;
  Changed: Boolean;
begin
  Result := nil;
  if not FileExists(PidsName) then
    Exit;
  Mine := TPidCatalog.Create;
  Builtin := TPidCatalog.Create;
  Added := TPidCatalog.Create;
  try
    Root := ReadJsonObject(PidsName);
    try
      Mine.LoadFromJson(Root);
      Arr := JArr(Root, 'pids');
      if (Arr = nil) or (Arr.Count <> Mine.Count) then
        Exit;
    finally
      Root.Free;
    end;
    if DefaultsJson = '' then
      Builtin.LoadFromJsonText(DefaultPidsJson)
    else
      Builtin.LoadFromJsonText(DefaultsJson);

    if Mine.BuiltIns.Count = 0 then
    begin
      // Made from these defaults (they did not change while files had no
      // "builtIns"); any it lacks were deleted.
      for I := 0 to Builtin.Count - 1 do
        Mine.BuiltIns.AddOrSetValue(IntToStr(Builtin[I].Id), Builtin[I].Fingerprint);
      Mine.SaveToJsonFile(PidsName);
      Exit;
    end;

    Changed := False;
    for I := 0 to Builtin.Count - 1 do
    begin
      D := Builtin[I];
      Key := IntToStr(D.Id);
      Current := D.Fingerprint;
      if not Mine.BuiltIns.TryGetValue(Key, Given) then
      begin
        if FindMatchingPid(Mine, D) = nil then
        begin
          P := TPidDef.Create;
          P.Assign(D);
          Added.Add(P);
        end;
      end
      else if Given <> Current then
      begin
        for J := 0 to Mine.Count - 1 do
          if Mine[J].Fingerprint = Given then
          begin
            KeepId := Mine[J].Id;
            Mine[J].Assign(D);
            Mine[J].Id := KeepId;
            Result := Result + [Format('Corrected the built-in PID "%s"', [D.LongName])];
            Break;
          end;
      end
      else
        Continue;
      Mine.BuiltIns.AddOrSetValue(Key, Current);
      Changed := True;
    end;
    if Added.Count > 0 then
    begin
      MergeCatalog(Mine, Added, mmAddNew);
      for I := 0 to Added.Count - 1 do
        Result := Result + [Format('Added the built-in PID "%s"', [Added[I].LongName])];
    end;
    if Changed then
      Mine.SaveToJsonFile(PidsName);
  finally
    Added.Free;
    Builtin.Free;
    Mine.Free;
  end;
end;

function UpdateBuiltInDtcs(const DtcsName, DefaultsJson: string): TArray<string>;
var
  Mine, Builtin: TDtcCatalog;
  Json, Hash, Code, Text: string;
  Added, Fixed: Integer;
begin
  Result := nil;
  if not FileExists(DtcsName) then
    Exit;
  Json := DefaultsJson;
  if Json = '' then
    Json := DefaultDtcsJson;
  Hash := THashMD5.GetHashString(Json);
  Mine := TDtcCatalog.Create;
  Builtin := TDtcCatalog.Create;
  try
    Mine.LoadFromFile(DtcsName);
    // Warnings: entries it could not read, which saving would lose.
    if (Mine.DefaultsHash = Hash) or (Mine.Warnings.Count > 0) then
      Exit;
    Builtin.LoadFromJsonText(Json);
    Added := 0;
    Fixed := 0;
    for Code in Builtin.Codes do
    begin
      Text := Mine.Describe(Code);
      if Text = Builtin.Describe(Code) then
        Continue;
      if Text = '' then
        Inc(Added)
      else
        Inc(Fixed);
      Mine.AddOrSet(Code, Builtin.Describe(Code));
    end;
    Mine.DefaultsHash := Hash;
    Mine.SaveToJsonFile(DtcsName);
    if Added > 0 then
      Result := Result + [Format('Added %d built-in trouble code description(s)', [Added])];
    if Fixed > 0 then
      Result := Result + [Format('Corrected %d built-in trouble code description(s)', [Fixed])];
  finally
    Builtin.Free;
    Mine.Free;
  end;
end;

function AddNewBuiltInsTo(const PidsName, ListsName, ViewsName, DisplayName: string): TArray<string>;
begin
  Result := UpdateBuiltInPids(PidsName);
  if FileExists(ListsName) and FileExists(PidsName) then
    Result := Result + AddNewLists(PidsName, ListsName);
  if FileExists(ViewsName) then
    Result := Result + AddNewViews(ViewsName);
  if FileExists(DisplayName) and FileExists(PidsName) then
    Result := Result + AddNewDashboards(PidsName, DisplayName);
end;

function AddNewBuiltIns: TArray<string>;
begin
  Result := AddNewBuiltInsTo(PidsFile, ListsFile, LogViewsFile, DisplayFile) +
    UpdateBuiltInDtcs(DtcsFile);
end;

end.
