unit UVScan.PidDiscovery;

{ "Search PCM for PIDs": asks the connected PCM which PIDs it answers
  (read-only mode $22), lists them with their size and raw value, and adds
  the ticked ones to pids.json as raw "PID $xxxx" entries to be named and
  defined in the PID editor. The search runs on the scan engine; this form
  only posts commands and receives events (forwarded by the main form). }

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Types, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Edit, FMX.Layouts,
  FMX.Controls.Presentation,
  UVScan.Pids, UVScan.Engine, UVScan.UI.DataGrid;

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
    pnlResults: TLayout;
    pnlBottom: TLayout;
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
  private type
    TFound = record
      Pid: Word;
      Bytes: Integer;
      Raw: string;
      Defined: string;  // "Already defined as" column
      Checked: Boolean;
    end;
  private
    lvResults: TDataGrid;
    FResults: TList<TFound>;
    FEngine: TScanEngine;
    FCatalog: TPidCatalog;
    FFileName: string;
    FSearching: Boolean;
    FAdded: TArray<Integer>;
    FFound: Integer;
    procedure ResultsGetText(Sender: TObject; Col, Row: Integer; var Text: string);
    procedure ResultsGetChecked(Sender: TObject; Row: Integer; var Checked: Boolean);
    procedure ResultsToggleCheck(Sender: TObject; Row: Integer);
    procedure SetChecked(Row: Integer; Value: Boolean);
    procedure UpdateControls;
    procedure UpdateTicked;
    function DefinedAs(Pid: Word): string;
  public
    { The window while it is open (nil otherwise): the main form passes it
      every engine event. }
    class var Current: TPidDiscoveryForm;
    destructor Destroy; override;
    { Called by the main form for every engine event while this form is open. }
    procedure HandleEngineEvent(const Ev: TEngineEvent);
    { Shows the dialog. OnDone gets the ids of PIDs added to FileName (empty if
      none) when it closes. The result is the window, valid only while open. }
    class function Execute(Engine: TScanEngine; Catalog: TPidCatalog; const FileName: string;
      const OnDone: TProc<TArray<Integer>>): TPidDiscoveryForm;
  end;

implementation

{$R *.fmx}

uses
  System.Math, System.StrUtils, UVScan.Class2, UVScan.UI.Common;

class function TPidDiscoveryForm.Execute(Engine: TScanEngine; Catalog: TPidCatalog; const FileName: string;
  const OnDone: TProc<TArray<Integer>>): TPidDiscoveryForm;
var
  F: TPidDiscoveryForm;
begin
  F := TPidDiscoveryForm.Create(Application);
  F.FEngine := Engine;
  F.FCatalog := Catalog;
  F.FFileName := FileName;
  Current := F; // before showing: on Windows ShowModal only returns once closed
  Result := F;
  ShowDialog(F,
    procedure(R: TModalResult)
    begin
      if Current = F then
        Current := nil;
      if Assigned(OnDone) then
        OnDone(F.FAdded);
    end);
end;

procedure TPidDiscoveryForm.FormCreate(Sender: TObject);
begin
  FResults := TList<TFound>.Create;
  lvResults := TDataGrid.Create(Self);
  lvResults.Parent := pnlResults;
  lvResults.Align := TAlignLayout.Client;
  lvResults.Checkboxes := True;
  lvResults.AddColumn('PID', 80);
  lvResults.AddColumn('Bytes', 50, gaRight);
  lvResults.AddColumn('Raw value', 110);
  lvResults.AddColumn('Already defined as', 480, gaLeft, True);
  lvResults.OnGetText := ResultsGetText;
  lvResults.OnGetChecked := ResultsGetChecked;
  lvResults.OnToggleCheck := ResultsToggleCheck;
  UpdateControls;
  UpdateTicked;
end;

destructor TPidDiscoveryForm.Destroy;
begin
  if Current = Self then
    Current := nil;
  FResults.Free;
  inherited;
end;

procedure TPidDiscoveryForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FSearching then
    FEngine.Post(Command(ecStopScan)); // stops the search; results so far stay
end;

procedure TPidDiscoveryForm.ResultsGetText(Sender: TObject; Col, Row: Integer; var Text: string);
var
  F: TFound;
begin
  if (Row < 0) or (Row >= FResults.Count) then
    Exit;
  F := FResults[Row];
  case Col of
    0: Text := '$' + IntToHex(F.Pid, 4);
    1: Text := IntToStr(F.Bytes);
    2: Text := F.Raw;
    3: Text := F.Defined;
  end;
end;

procedure TPidDiscoveryForm.ResultsGetChecked(Sender: TObject; Row: Integer; var Checked: Boolean);
begin
  if (Row >= 0) and (Row < FResults.Count) then
    Checked := FResults[Row].Checked;
end;

procedure TPidDiscoveryForm.SetChecked(Row: Integer; Value: Boolean);
var
  F: TFound;
begin
  F := FResults[Row];
  F.Checked := Value;
  FResults[Row] := F;
end;

procedure TPidDiscoveryForm.ResultsToggleCheck(Sender: TObject; Row: Integer);
begin
  if (Row < 0) or (Row >= FResults.Count) then
    Exit;
  SetChecked(Row, not FResults[Row].Checked);
  UpdateTicked;
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
  btnTickNew.Enabled := not FSearching and (FResults.Count > 0);
  btnUntickAll.Enabled := btnTickNew.Enabled;
end;

procedure TPidDiscoveryForm.UpdateTicked;
var
  F: TFound;
  N: Integer;
begin
  N := 0;
  for F in FResults do
    if F.Checked then
      Inc(N);
  lblTicked.Text := Format('%d ticked to add', [N]);
  btnAdd.Enabled := not FSearching and (N > 0);
  lvResults.Refresh;
end;

procedure TPidDiscoveryForm.btnStartClick(Sender: TObject);
var
  Ranges: string;
  Cmd: TEngineCommand;
begin
  Ranges := '';
  if chkSae.IsChecked then
    Ranges := PidRangeSae;
  if chkGm.IsChecked then
    Ranges := Ranges + IfThen(Ranges <> '', ',', '') + PidRangeGmEnhanced;
  if Trim(edtMore.Text) <> '' then
    Ranges := Ranges + IfThen(Ranges <> '', ',', '') + Trim(edtMore.Text);
  if Ranges = '' then
  begin
    ShowInfo('Tick at least one range to search.');
    Exit;
  end;
  try
    ParsePidRanges(Ranges); // validate before starting
  except
    on E: EConvertError do
    begin
      ShowWarning(E.Message);
      Exit;
    end;
  end;
  FResults.Clear;
  lvResults.RowCount := 0;
  FFound := 0;
  pbProgress.Value := 0;
  lblStatus.Text := 'Starting...';
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
  lblStatus.Text := 'Stopping...';
end;

procedure TPidDiscoveryForm.HandleEngineEvent(const Ev: TEngineEvent);
var
  F: TFound;
  Def: string;
begin
  case Ev.Kind of
    eePidFound:
      begin
        Inc(FFound);
        Def := DefinedAs(Ev.PidId);
        F := Default(TFound);
        F.Pid := Ev.PidId;
        F.Bytes := Ev.DataBytes;
        F.Raw := Ev.Raw;
        if Def <> '' then
          F.Defined := Def
        else if not (Ev.DataBytes in [1..4]) then
          F.Defined := '(cannot be streamed: answer is not 1-4 bytes)'
        else
          F.Defined := 'new';
        FResults.Add(F);
        lvResults.RowCount := FResults.Count;
        lvResults.ScrollIntoView(FResults.Count - 1);
        lvResults.Refresh;
      end;
    eePidSearchProgress:
      begin
        pbProgress.Max := Max(1, Ev.Total);
        pbProgress.Value := Ev.Progress;
        lblStatus.Text := Format('Checked %d of %d PIDs (now at $%.4x) - %d answered',
          [Ev.Progress, Ev.Total, Ev.PidId, FFound]);
      end;
    eePidSearchDone:
      begin
        FSearching := False;
        pbProgress.Value := pbProgress.Max;
        lblStatus.Text := Format('Done: %d of %d PIDs checked, %d answered. Tick the ones to add.',
          [Ev.Progress, Ev.Total, FFound]);
        UpdateControls;
        UpdateTicked;
      end;
    eeError:
      lblStatus.Text := Ev.Text;
  end;
end;

procedure TPidDiscoveryForm.btnTickNewClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FResults.Count - 1 do
    SetChecked(I, FResults[I].Defined = 'new');
  UpdateTicked;
end;

procedure TPidDiscoveryForm.btnUntickAllClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FResults.Count - 1 do
    SetChecked(I, False);
  UpdateTicked;
end;

procedure TPidDiscoveryForm.btnAddClick(Sender: TObject);
var
  Work: TPidCatalog;
  I: Integer;
  F: TFound;
  P: TPidDef;
  Problems: TArray<TPidProblem>;
  Added: TArray<Integer>;
begin
  Work := TPidCatalog.Create;
  try
    Work.Assign(FCatalog);
    Added := nil;
    for F in FResults do
    begin
      if not F.Checked or not (F.Bytes in [1..4]) then
        Continue;
      P := TPidDef.Create;
      P.Id := Work.NextFreeId;
      P.LongName := Format('PID $%.4x', [F.Pid]);
      P.ShortName := Format('$%.4x', [F.Pid]);
      P.Description := Format('Found by PID search on %s (raw value then: %s). Rename and define it.',
        [FormatDateTime('yyyy-mm-dd', Now), F.Raw]);
      P.Kind := pkVehicle;
      P.Category := pcOther;
      P.PidNumber := F.Pid;
      P.PidCode := IntToHex(F.Pid, 4);
      P.DataLength := F.Bytes;
      case F.Bytes of
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
      ShowWarning('The PID definitions have problems; fix them in the PID editor first.' + sLineBreak +
        Problems[0].Text);
      Exit;
    end;
    try
      Work.SaveToJsonFile(FFileName);
    except
      on E: Exception do
      begin
        ShowError('Could not save ' + FFileName + ': ' + E.Message);
        Exit;
      end;
    end;
    FAdded := FAdded + Added;
    FCatalog.Assign(Work); // keeps "defined as" up to date if more are added
    for I := 0 to FResults.Count - 1 do
      if FResults[I].Checked then
      begin
        F := FResults[I];
        F.Checked := False;
        F.Defined := DefinedAs(F.Pid);
        FResults[I] := F;
      end;
    UpdateTicked;
    lblStatus.Text := Format('Added %d PIDs to %s. Close this window to name and define them.',
      [Length(FAdded), ExtractFileName(FFileName)]);
  finally
    Work.Free;
  end;
end;

end.
