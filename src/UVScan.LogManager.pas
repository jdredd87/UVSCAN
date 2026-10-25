unit UVScan.LogManager;

{ The Logs page: the logs in the log folder, newest first, with when they
  ended, how long they are and their size. Tap logs to tick them, then open
  one, share them (a phone: the share sheet - email, Drive, a message...) or
  show them in Explorer (Windows), rename one, or delete them. Delete old...
  clears the logs older than a week, a month... at once. The log being
  written is listed but never renamed or deleted. See UVScan.LogFiles. }

interface

uses
  System.SysUtils;

{ Shows the page for the logs in Folder; InUse ('' if none) is the log being
  written. OnOpen gets the log Open was pressed for (the page is closed by
  then); OnDone runs when the page closes either way. Both may be nil. }
procedure ManageLogs(const Folder, InUse: string; const OnOpen: TProc<string>; const OnDone: TProc);

implementation

uses
  System.Classes, System.Types, System.UITypes, System.Math, System.IOUtils, System.StrUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.ListBox, FMX.Layouts,
  UVScan.LogFiles, UVScan.Share, UVScan.UI.Common, UVScan.UI.Theme;

type
  TLogsPage = class(TComponent)
  private
    FForm: TForm;
    FFolder, FInUse, FOpen: string;
    FLogs: TArray<TLogFileInfo>;
    FFilling: Boolean;
    FSummary, FTicked: TLabel;
    FTools, FBar: TLayout;
    FList: TListBox;
    btnAll, btnOld, btnOpen, btnShare, btnCopy, btnRename, btnDelete, btnClose: TButton;
    function NewButton(const Text: string; OnClick: TNotifyEvent; Parent: TFmxObject): TButton;
    procedure Build;
    procedure Fill;
    procedure Relayout;
    procedure UpdateButtons;
    function Ticked: TArray<Integer>;
    function TickedFiles: TArray<string>;
    function TickedSize: Int64;
    function IsInUse(const FileName: string): Boolean;
    procedure DeleteFiles(const Files: TArray<string>; const Question: string);
    procedure DeleteOlder(Days: Integer; const Text: string);
    procedure FormResize(Sender: TObject);
    procedure ItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure CheckChange(Sender: TObject);
    procedure AllClick(Sender: TObject);
    procedure OldClick(Sender: TObject);
    procedure OldWeekClick(Sender: TObject);
    procedure OldMonthClick(Sender: TObject);
    procedure Old3MonthsClick(Sender: TObject);
    procedure OldYearClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure ShareClick(Sender: TObject);
    procedure CopyClick(Sender: TObject);
    procedure RenameClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
  end;

const
  Dot = '  '#$00B7'  '; // between the parts of a log's details

function SizeText(Bytes: Int64): string;
begin
  if Bytes < 1024 * 1024 then
    Result := Format('%d KB', [(Bytes + 1023) div 1024])
  else
    Result := FormatFloat('0.0', Bytes / (1024 * 1024), TFormatSettings.Invariant) + ' MB';
end;

{ 17:42 or 1:05:12 }
function LengthText(Seconds: Double): string;
var
  S: Int64;
begin
  S := Round(Max(0, Seconds));
  if S >= 3600 then
    Result := Format('%d:%.2d:%.2d', [S div 3600, S mod 3600 div 60, S mod 60])
  else
    Result := Format('%d:%.2d', [S div 60, S mod 60]);
end;

function TLogsPage.NewButton(const Text: string; OnClick: TNotifyEvent; Parent: TFmxObject): TButton;
begin
  Result := TButton.Create(FForm);
  Result.Parent := Parent;
  Result.Text := Text;
  Result.OnClick := OnClick;
end;

procedure TLogsPage.Build;
var
  Head: TLayout;
begin
  FForm.OnResize := FormResize;
  Head := TLayout.Create(FForm);
  Head.Parent := FForm;
  Head.Align := TAlignLayout.Top;
  Head.Padding.Rect := TRectF.Create(16, 8, 16, 0);
  FSummary := TLabel.Create(FForm);
  FSummary.Parent := Head;
  FSummary.Align := TAlignLayout.Top;
  FSummary.WordWrap := True;
  FSummary.StyledSettings := FSummary.StyledSettings - [TStyledSetting.FontColor];
  FSummary.TextSettings.FontColor := Palette.Muted;
  FTools := TLayout.Create(FForm);
  FTools.Parent := Head;
  FTools.Align := TAlignLayout.Top;
  FTools.Position.Y := 100;
  FTools.Margins.Top := 6;
  btnAll := NewButton('Tick all', AllClick, FTools);
  btnOld := NewButton('Delete old...', OldClick, FTools);
  FTicked := TLabel.Create(FForm);
  FTicked.Parent := Head;
  FTicked.Align := TAlignLayout.Top;
  FTicked.Position.Y := 200;
  FTicked.Margins.Top := 4;
  FTicked.Height := 24;
  FTicked.Text := 'Tap a log to tick it.';

  FBar := TLayout.Create(FForm);
  FBar.Parent := FForm;
  FBar.Align := TAlignLayout.Bottom;
  FBar.Margins.Rect := TRectF.Create(12, 4, 12, 8);
  btnOpen := NewButton('Open', OpenClick, FBar);
  if CanShareFiles then
  begin
    btnShare := NewButton('Share...', ShareClick, FBar);
    btnCopy := NewButton('Save a copy...', CopyClick, FBar);
  end
  else
    btnShare := NewButton('Show in folder', ShareClick, FBar);
  btnRename := NewButton('Rename...', RenameClick, FBar);
  btnDelete := NewButton('Delete', DeleteClick, FBar);
  btnClose := NewButton('Close', CloseClick, FBar);
  btnClose.Cancel := True;

  FList := TListBox.Create(FForm);
  FList.Parent := FForm;
  FList.Align := TAlignLayout.Client;
  FList.Margins.Rect := TRectF.Create(8, 6, 8, 4);
  FList.ShowCheckboxes := True;
  FList.OnItemClick := ItemClick;
  FList.OnChangeCheck := CheckChange;
end;

procedure TLogsPage.Relayout;
var
  W: Single;
  Bar: TArray<TControl>;
  Head: TControl;
begin
  W := InnerWidth(FForm) - 32;
  if W < 100 then
    Exit;
  FSummary.Height := Max(20, WrappedTextHeight(FSummary, W) + 4);
  FlowControls(FTools, [btnAll, btnOld]);
  Bar := [btnOpen, btnShare];
  if btnCopy <> nil then
    Bar := Bar + [btnCopy];
  Bar := Bar + [btnRename, btnDelete, btnClose];
  FlowControls(FBar, Bar);
  Head := FSummary.ParentControl;
  Head.Height := 8 + FSummary.Height + FTools.Margins.Top + FTools.Height + FTicked.Margins.Top + FTicked.Height + 4;
end;

procedure TLogsPage.FormResize(Sender: TObject);
begin
  Relayout;
end;

function TLogsPage.IsInUse(const FileName: string): Boolean;
begin
  Result := (FInUse <> '') and SameText(ExpandFileName(FileName), ExpandFileName(FInUse));
end;

procedure TLogsPage.Fill;
var
  Was: TArray<string>;
  Item: TListBoxItem;
  Total: Int64;
  Detail: string;
begin
  Was := TickedFiles;
  FLogs := ListLogs(FFolder);
  FFilling := True;
  FList.BeginUpdate;
  try
    FList.Clear;
    Total := 0;
    for var L in FLogs do
    begin
      Inc(Total, L.Size);
      Item := TListBoxItem.Create(FList);
      Item.StyleLookup := 'listboxitembottomdetail';
      Item.Height := 60;
      Item.Text := TPath.GetFileNameWithoutExtension(L.FileName);
      Detail := FormatDateTime('ddd mmm d, hh:nn', L.Modified);
      if L.Seconds > 0 then
        Detail := Detail + Dot + LengthText(L.Seconds) + ' long';
      Detail := Detail + Dot + SizeText(L.Size);
      if IsInUse(L.FileName) then
        Detail := Detail + Dot + 'logging now';
      Item.ItemData.Detail := Detail;
      Item.IsChecked := MatchText(L.FileName, Was);
      FList.AddObject(Item);
    end;
  finally
    FList.EndUpdate;
    FFilling := False;
  end;
  if Length(FLogs) = 0 then
    FSummary.Text := 'No logs yet' + IfThen(IsMobile, '', ' in ' + FFolder)
  else
    FSummary.Text := Format('%d log%s, %s', [Length(FLogs), IfThen(Length(FLogs) = 1, '', 's'), SizeText(Total)]) +
      IfThen(IsMobile, '', ', in ' + FFolder); // a phone's folder is the app's own: its path says nothing
  Relayout;
  UpdateButtons;
end;

function TLogsPage.Ticked: TArray<Integer>;
begin
  Result := nil;
  if FList = nil then
    Exit;
  for var I := 0 to Min(FList.Count, Length(FLogs)) - 1 do
    if FList.ListItems[I].IsChecked then
      Result := Result + [I];
end;

function TLogsPage.TickedFiles: TArray<string>;
begin
  Result := nil;
  for var I in Ticked do
    Result := Result + [FLogs[I].FileName];
end;

function TLogsPage.TickedSize: Int64;
begin
  Result := 0;
  for var I in Ticked do
    Inc(Result, FLogs[I].Size);
end;

procedure TLogsPage.UpdateButtons;
var
  N: Integer;
begin
  N := Length(Ticked);
  btnOpen.Enabled := N = 1;
  btnShare.Enabled := N >= 1;
  if btnCopy <> nil then
    btnCopy.Enabled := N = 1;
  btnRename.Enabled := N = 1;
  btnDelete.Enabled := N >= 1;
  btnOld.Enabled := Length(FLogs) > 0;
  btnAll.Enabled := Length(FLogs) > 0;
  if (N > 0) and (N = Length(FLogs)) then
    btnAll.Text := 'Tick none'
  else
    btnAll.Text := 'Tick all';
  if N = 0 then
    FTicked.Text := IfThen(Length(FLogs) > 0, 'Tap a log to tick it.', '')
  else
    FTicked.Text := Format('%d ticked, %s', [N, SizeText(TickedSize)]);
end;

procedure TLogsPage.ItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
  if Item <> nil then
    Item.IsChecked := not Item.IsChecked;
  UpdateButtons;
end;

procedure TLogsPage.CheckChange(Sender: TObject);
begin
  if not FFilling then
    UpdateButtons;
end;

procedure TLogsPage.AllClick(Sender: TObject);
var
  On: Boolean;
begin
  On := Length(Ticked) < Length(FLogs);
  FFilling := True;
  try
    for var I := 0 to FList.Count - 1 do
      FList.ListItems[I].IsChecked := On;
  finally
    FFilling := False;
  end;
  UpdateButtons;
end;

procedure TLogsPage.OldClick(Sender: TObject);

  function Item(const Text: string; OnClick: TNotifyEvent): TActionItem;
  begin
    Result.Text := Text;
    Result.OnClick := OnClick;
    Result.Sender := nil;
    Result.Enabled := True;
    Result.Checked := False;
  end;

begin
  ShowActionMenu(FForm, [Item('Older than a week', OldWeekClick), Item('Older than a month', OldMonthClick),
    Item('Older than 3 months', Old3MonthsClick), Item('Older than a year', OldYearClick)],
    btnOld.LocalToAbsolute(TPointF.Create(0, btnOld.Height)));
end;

procedure TLogsPage.OldWeekClick(Sender: TObject);
begin
  DeleteOlder(7, 'a week');
end;

procedure TLogsPage.OldMonthClick(Sender: TObject);
begin
  DeleteOlder(31, 'a month');
end;

procedure TLogsPage.Old3MonthsClick(Sender: TObject);
begin
  DeleteOlder(92, '3 months');
end;

procedure TLogsPage.OldYearClick(Sender: TObject);
begin
  DeleteOlder(365, 'a year');
end;

procedure TLogsPage.DeleteOlder(Days: Integer; const Text: string);
var
  Files: TArray<string>;
  Size: Int64;
begin
  Files := nil;
  Size := 0;
  for var L in FLogs do
    if (L.Modified < Now - Days) and not IsInUse(L.FileName) then
    begin
      Files := Files + [L.FileName];
      Inc(Size, L.Size);
    end;
  if Files = nil then
    ShowInfo('No logs older than ' + Text + '.')
  else
    DeleteFiles(Files, Format('Delete the %d log%s older than %s (%s)? They cannot be brought back.',
      [Length(Files), IfThen(Length(Files) = 1, '', 's'), Text, SizeText(Size)]));
end;

procedure TLogsPage.DeleteFiles(const Files: TArray<string>; const Question: string);
begin
  Confirm(Question,
    procedure
    var
      Failed: string;
    begin
      Failed := '';
      for var F in Files do
        try
          TFile.Delete(F);
        except
          on E: Exception do
            Failed := Failed + sLineBreak + ExtractFileName(F) + ': ' + E.Message;
        end;
      Fill;
      if Failed <> '' then
        ShowWarning('Could not delete:' + Failed);
    end);
end;

procedure TLogsPage.DeleteClick(Sender: TObject);
var
  Files: TArray<string>;
  Size: Int64;
  Busy: Boolean;
begin
  Files := nil;
  Size := 0;
  Busy := False;
  for var I in Ticked do
    if IsInUse(FLogs[I].FileName) then
      Busy := True
    else
    begin
      Files := Files + [FLogs[I].FileName];
      Inc(Size, FLogs[I].Size);
    end;
  if Files = nil then
  begin
    ShowInfo('That log is being written now: stop the log first.');
    Exit;
  end;
  if Length(Files) = 1 then
    DeleteFiles(Files, Format('Delete %s (%s)? It cannot be brought back.%s', [ExtractFileName(Files[0]),
      SizeText(Size), IfThen(Busy, ' (The log being written now stays.)', '')]))
  else
    DeleteFiles(Files, Format('Delete these %d logs (%s)? They cannot be brought back.%s', [Length(Files),
      SizeText(Size), IfThen(Busy, ' (The log being written now stays.)', '')]));
end;

procedure TLogsPage.OpenClick(Sender: TObject);
var
  Files: TArray<string>;
begin
  Files := TickedFiles;
  if Length(Files) <> 1 then
    Exit;
  FOpen := Files[0];
  FForm.ModalResult := mrOk;
end;

procedure TLogsPage.ShareClick(Sender: TObject);
var
  Files: TArray<string>;
begin
  Files := TickedFiles;
  if Files = nil then
    Exit;
  if not CanShareFiles then
  begin
    // Windows: Explorer with the (first) log selected
    RunProgram('explorer.exe', '/select,"' + Files[0] + '"');
    Exit;
  end;
  try
    if Length(Files) = 1 then
      ShareFiles(Files, 'text/csv', 'UVScan log ' + ExtractFileName(Files[0]),
        'A UVScan log. It opens in UVScan''s log viewer, or as a spreadsheet.')
    else
      ShareFiles(Files, 'text/csv', Format('UVScan logs (%d)', [Length(Files)]),
        'UVScan logs. They open in UVScan''s log viewer, or as spreadsheets.');
  except
    on E: Exception do
      ShowWarning('Could not share: ' + E.Message);
  end;
end;

procedure TLogsPage.CopyClick(Sender: TObject);
var
  Files: TArray<string>;
  F: string;
begin
  Files := TickedFiles;
  if Length(Files) <> 1 then
    Exit;
  F := Files[0];
  SaveFileCopy(F, 'text/csv',
    procedure(const Error: string)
    begin
      if Error = '' then
        ShowInfo('Copy of ' + ExtractFileName(F) + ' saved')
      else
        ShowWarning('Could not save the copy: ' + Error);
    end);
end;

procedure TLogsPage.RenameClick(Sender: TObject);
var
  Files: TArray<string>;
  Old: string;
begin
  Files := TickedFiles;
  if Length(Files) <> 1 then
    Exit;
  Old := Files[0];
  if IsInUse(Old) then
  begin
    ShowInfo('That log is being written now: stop the log first.');
    Exit;
  end;
  AskText('Rename the log', 'New name', TPath.GetFileNameWithoutExtension(Old),
    procedure(S: string)
    var
      Name, New: string;
    begin
      Name := CleanLogName(S);
      if Name = '' then
        Exit;
      New := TPath.Combine(ExtractFileDir(Old), Name + '.csv');
      if SameText(New, Old) and (ExtractFileName(New) = ExtractFileName(Old)) then
        Exit;
      if FileExists(New) and not SameText(New, Old) then
      begin
        ShowWarning('There is a log called ' + Name + ' already.');
        Exit;
      end;
      if not RenameFile(Old, New) then
      begin
        ShowWarning('Could not rename ' + ExtractFileName(Old) + '.');
        Exit;
      end;
      for var I := 0 to FList.Count - 1 do
        FList.ListItems[I].IsChecked := False;
      Fill;
      // the renamed one stays ticked
      for var I := 0 to High(FLogs) do
        if SameText(FLogs[I].FileName, New) then
          FList.ListItems[I].IsChecked := True;
      UpdateButtons;
    end);
end;

procedure TLogsPage.CloseClick(Sender: TObject);
begin
  FForm.ModalResult := mrCancel;
end;

procedure ManageLogs(const Folder, InUse: string; const OnOpen: TProc<string>; const OnDone: TProc);
var
  F: TForm;
  Page: TLogsPage;
begin
  F := TForm.CreateNew(nil);
  F.Caption := 'Logs';
  F.Position := TFormPosition.MainFormCenter;
  F.ClientWidth := 640;
  F.ClientHeight := 720;
  Page := TLogsPage.Create(F);
  Page.FForm := F;
  Page.FFolder := Folder;
  Page.FInUse := InUse;
  Page.Build;
  Page.Fill;
  ShowDialog(F,
    procedure(R: TModalResult)
    var
      Open: string;
    begin
      Open := Page.FOpen;
      if Assigned(OnDone) then
        OnDone();
      if (R = mrOk) and (Open <> '') and Assigned(OnOpen) then
        TThread.ForceQueue(nil,
          procedure
          begin
            OnOpen(Open);
          end);
    end);
end;

end.
