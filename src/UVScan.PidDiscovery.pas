unit UVScan.PidDiscovery;

{ "Search PCM for PIDs": asks the connected PCM which PIDs it answers
  (read-only mode $22), lists them with their size and raw value, and adds
  the ticked ones to pids.json as raw "PID $xxxx" entries to be named and
  defined in the PID editor. The search runs on the scan engine; this form
  only posts commands and receives events (forwarded by the main form). }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.UITypes, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  UVScan.Pids, UVScan.Engine;

type
  TPidDiscoveryForm = class(TForm)
    gbSearch: TGroupBox;
    chkSae: TCheckBox;
    chkGm: TCheckBox;
    lblMore: TLabel;
    edtMore: TEdit;
    btnStart: TButton;
    btnStop: TButton;
    pbProgress: TProgressBar;
    lblStatus: TLabel;
    lvResults: TListView;
    pnlBottom: TPanel;
    btnTickNew: TButton;
    btnUntickAll: TButton;
    lblTicked: TLabel;
    btnAdd: TButton;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnTickNewClick(Sender: TObject);
    procedure btnUntickAllClick(Sender: TObject);
    procedure btnAddClick(Sender: TObject);
    procedure lvResultsItemChecked(Sender: TObject; Item: TListItem);
  private
    FEngine: TScanEngine;
    FCatalog: TPidCatalog;
    FFileName: string;
    FSearching: Boolean;
    FAdded: TArray<Integer>;
    FFound: Integer;
    procedure UpdateControls;
    procedure UpdateTicked;
    function DefinedAs(Pid: Word): string;
  public
    { Called by the main form for every engine event while this form is open. }
    procedure HandleEngineEvent(const Ev: TEngineEvent);
    { Shows the dialog. Returns the ids of PIDs added to FileName (empty if none). }
    class function Execute(Engine: TScanEngine; Catalog: TPidCatalog; const FileName: string;
      var Current: TPidDiscoveryForm): TArray<Integer>;
  end;

implementation

{$R *.dfm}

uses
  System.Math, System.StrUtils, UVScan.Class2;

class function TPidDiscoveryForm.Execute(Engine: TScanEngine; Catalog: TPidCatalog; const FileName: string;
  var Current: TPidDiscoveryForm): TArray<Integer>;
var
  F: TPidDiscoveryForm;
begin
  F := TPidDiscoveryForm.Create(Application);
  try
    F.FEngine := Engine;
    F.FCatalog := Catalog;
    F.FFileName := FileName;
    Current := F;
    F.ShowModal;
    Result := F.FAdded;
  finally
    Current := nil;
    F.Free;
  end;
end;

procedure TPidDiscoveryForm.FormCreate(Sender: TObject);
begin
  UpdateControls;
  UpdateTicked;
end;

procedure TPidDiscoveryForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FSearching then
    FEngine.Post(Command(ecStopScan)); // stops the search; results so far stay
end;

function TPidDiscoveryForm.DefinedAs(Pid: Word): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FCatalog.Count - 1 do
    if (FCatalog[I].Kind = pkVehicle) and (FCatalog[I].PidNumber = Pid) then
    begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + FCatalog[I].LongName;
    end;
end;

procedure TPidDiscoveryForm.UpdateControls;
begin
  btnStart.Enabled := not FSearching;
  btnStop.Enabled := FSearching;
  chkSae.Enabled := not FSearching;
  chkGm.Enabled := not FSearching;
  edtMore.Enabled := not FSearching;
  btnAdd.Enabled := not FSearching;
  btnTickNew.Enabled := not FSearching and (lvResults.Items.Count > 0);
  btnUntickAll.Enabled := btnTickNew.Enabled;
end;

procedure TPidDiscoveryForm.UpdateTicked;
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to lvResults.Items.Count - 1 do
    if lvResults.Items[I].Checked then
      Inc(N);
  lblTicked.Caption := Format('%d ticked to add', [N]);
  btnAdd.Enabled := not FSearching and (N > 0);
end;

procedure TPidDiscoveryForm.btnStartClick(Sender: TObject);
var
  Ranges: string;
  Cmd: TEngineCommand;
begin
  Ranges := '';
  if chkSae.Checked then
    Ranges := PidRangeSae;
  if chkGm.Checked then
    Ranges := Ranges + IfThen(Ranges <> '', ',', '') + PidRangeGmEnhanced;
  if Trim(edtMore.Text) <> '' then
    Ranges := Ranges + IfThen(Ranges <> '', ',', '') + Trim(edtMore.Text);
  if Ranges = '' then
  begin
    MessageDlg('Tick at least one range to search.', mtInformation, [mbOK], 0);
    Exit;
  end;
  try
    ParsePidRanges(Ranges); // validate before starting
  except
    on E: EConvertError do
    begin
      MessageDlg(E.Message, mtWarning, [mbOK], 0);
      Exit;
    end;
  end;
  lvResults.Items.Clear;
  FFound := 0;
  pbProgress.Position := 0;
  lblStatus.Caption := 'Starting...';
  FSearching := True;
  UpdateControls;
  UpdateTicked;
  Cmd := Command(ecDiscoverPids);
  Cmd.Text := Ranges;
  FEngine.Post(Cmd);
end;

procedure TPidDiscoveryForm.btnStopClick(Sender: TObject);
begin
  FEngine.Post(Command(ecStopScan));
  lblStatus.Caption := 'Stopping...';
end;

procedure TPidDiscoveryForm.HandleEngineEvent(const Ev: TEngineEvent);
var
  Item: TListItem;
  Def: string;
begin
  case Ev.Kind of
    eePidFound:
      begin
        Inc(FFound);
        Def := DefinedAs(Ev.PidId);
        Item := lvResults.Items.Add;
        Item.Caption := '$' + IntToHex(Ev.PidId, 4);
        Item.SubItems.Add(IntToStr(Ev.DataBytes));
        Item.SubItems.Add(Ev.Raw);
        if Def <> '' then
          Item.SubItems.Add(Def)
        else if not (Ev.DataBytes in [1..4]) then
          Item.SubItems.Add('(cannot be streamed: answer is not 1-4 bytes)')
        else
          Item.SubItems.Add('new');
        Item.Data := Pointer(NativeInt(Ev.PidId or (Ev.DataBytes shl 16)));
        Item.MakeVisible(False);
      end;
    eePidSearchProgress:
      begin
        pbProgress.Max := Max(1, Ev.Total);
        pbProgress.Position := Ev.Progress;
        lblStatus.Caption := Format('Checked %d of %d PIDs (now at $%.4x) - %d answered',
          [Ev.Progress, Ev.Total, Ev.PidId, FFound]);
      end;
    eePidSearchDone:
      begin
        FSearching := False;
        pbProgress.Position := pbProgress.Max;
        lblStatus.Caption := Format('Done: %d of %d PIDs checked, %d answered. Tick the ones to add.',
          [Ev.Progress, Ev.Total, FFound]);
        UpdateControls;
        UpdateTicked;
      end;
    eeError:
      lblStatus.Caption := Ev.Text;
  end;
end;

procedure TPidDiscoveryForm.btnTickNewClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to lvResults.Items.Count - 1 do
    lvResults.Items[I].Checked := lvResults.Items[I].SubItems[2] = 'new';
  UpdateTicked;
end;

procedure TPidDiscoveryForm.btnUntickAllClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to lvResults.Items.Count - 1 do
    lvResults.Items[I].Checked := False;
  UpdateTicked;
end;

procedure TPidDiscoveryForm.lvResultsItemChecked(Sender: TObject; Item: TListItem);
begin
  UpdateTicked;
end;

procedure TPidDiscoveryForm.btnAddClick(Sender: TObject);
var
  Work: TPidCatalog;
  I, Key, Bytes: Integer;
  Pid: Word;
  P: TPidDef;
  Problems: TArray<TPidProblem>;
  Added: TArray<Integer>;
begin
  Work := TPidCatalog.Create;
  try
    Work.Assign(FCatalog);
    Added := nil;
    for I := 0 to lvResults.Items.Count - 1 do
    begin
      if not lvResults.Items[I].Checked then
        Continue;
      Key := NativeInt(lvResults.Items[I].Data);
      Pid := Key and $FFFF;
      Bytes := Key shr 16;
      if not (Bytes in [1..4]) then
        Continue;
      P := TPidDef.Create;
      P.Id := Work.NextFreeId;
      P.LongName := Format('PID $%.4x', [Pid]);
      P.ShortName := Format('$%.4x', [Pid]);
      P.Description := Format('Found by PID search on %s (raw value then: %s). Rename and define it.',
        [FormatDateTime('yyyy-mm-dd', Now), lvResults.Items[I].SubItems[1]]);
      P.Kind := pkVehicle;
      P.Category := pcOther;
      P.PidNumber := Pid;
      P.PidCode := IntToHex(Pid, 4);
      P.DataLength := Bytes;
      case Bytes of
        1: P.FormulaText := 'N0';
        2: P.FormulaText := '((N1 << 8) + N2)';
        3: P.FormulaText := '((N1 << 16) + (N2 << 8) + N3)';
      else
        P.FormulaText := '((N1 << 24) + (N2 << 16) + (N3 << 8) + N4)';
      end;
      Work.Add(P);
      Added := Added + [P.Id];
    end;
    if Length(Added) = 0 then
      Exit;
    Problems := Work.Validate;
    if Length(Problems) > 0 then
    begin
      MessageDlg('The PID definitions have problems; fix them in the PID editor first.' + sLineBreak +
        Problems[0].Text, mtWarning, [mbOK], 0);
      Exit;
    end;
    try
      Work.SaveToJsonFile(FFileName);
    except
      on E: Exception do
      begin
        MessageDlg('Could not save ' + FFileName + ': ' + E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
    FAdded := FAdded + Added;
    FCatalog.Assign(Work); // keeps "defined as" up to date if more are added
    for I := 0 to lvResults.Items.Count - 1 do
      if lvResults.Items[I].Checked then
      begin
        lvResults.Items[I].Checked := False;
        Pid := NativeInt(lvResults.Items[I].Data) and $FFFF;
        lvResults.Items[I].SubItems[2] := DefinedAs(Pid);
      end;
    UpdateTicked;
    lblStatus.Caption := Format('Added %d PIDs to %s. Close this window to name and define them.',
      [Length(FAdded), ExtractFileName(FFileName)]);
  finally
    Work.Free;
  end;
end;

end.
