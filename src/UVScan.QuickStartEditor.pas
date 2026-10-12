unit UVScan.QuickStartEditor;

{ The page that edits a quick start (see UVScan.QuickStart), and on Windows
  the desktop shortcut that starts one. }

interface

uses
  System.SysUtils, UVScan.QuickStart;

{ Edits Q on a page of its own. Lists and Dashboards fill the pickers; Taken
  are the names of the other quick starts. OnSave gets the result. }
procedure EditQuickStart(const Q: TQuickStart; const Lists, Dashboards, Taken: TArray<string>;
  const Caption: string; const OnSave: TProc<TQuickStart>);

{$IFDEF MSWINDOWS}
{ A shortcut on the desktop that starts this UVScan like Q (its switches, not
  its name, so it keeps working if the quick start goes). Returns the file. }
function CreateQuickStartShortcut(const Q: TQuickStart): string;
{$ENDIF}

implementation

uses
  System.Classes, System.Types, System.Math, System.UITypes, FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.ListBox, FMX.Layouts, UVScan.UI.Common
  {$IFDEF MSWINDOWS}, Winapi.Windows, Winapi.ShlObj, Winapi.ActiveX, System.Win.ComObj{$ENDIF};

const
  KeepSelection = '(keep the ticked PIDs)';
  ListsDashboard = '(the scan list''s, if it has one)';

type
  TQuickStartPage = class(TComponent)
  private
    FForm: TForm;
    FName: TEdit;
    FList, FDash: TComboBox;
    FConnect, FScan, FLog, FFull, FChart, FRetry: TCheckBox;
    FTaken: TArray<string>;
    FBusy: Boolean;
    procedure OkClick(Sender: TObject);
    procedure StepChange(Sender: TObject);
  public
    function Read: TQuickStart;
  end;

procedure TQuickStartPage.StepChange(Sender: TObject);
begin
  if FBusy then
    Exit;
  FBusy := True;
  try
    // A log needs a scan, a scan needs the connection - and the other way round.
    if (Sender = FLog) and FLog.IsChecked then
      FScan.IsChecked := True;
    if ((Sender = FLog) or (Sender = FScan)) and FScan.IsChecked then
      FConnect.IsChecked := True;
    if (Sender = FConnect) and not FConnect.IsChecked then
    begin
      FScan.IsChecked := False;
      FLog.IsChecked := False;
      FRetry.IsChecked := False;
    end;
    if (Sender = FScan) and not FScan.IsChecked then
      FLog.IsChecked := False;
    if (Sender = FRetry) and FRetry.IsChecked then
      FConnect.IsChecked := True;
  finally
    FBusy := False;
  end;
end;

function TQuickStartPage.Read: TQuickStart;
begin
  Result := Default(TQuickStart);
  Result.Name := Trim(FName.Text);
  if FList.ItemIndex > 0 then
    Result.List := FList.Items[FList.ItemIndex];
  if FDash.ItemIndex > 0 then
    Result.Dashboard := FDash.Items[FDash.ItemIndex];
  Result.Connect := FConnect.IsChecked;
  Result.Scan := FScan.IsChecked;
  Result.Log := FLog.IsChecked;
  Result.FullScreen := FFull.IsChecked;
  Result.Chart := FChart.IsChecked;
  Result.Retry := FRetry.IsChecked;
  Result.Normalize;
end;

procedure TQuickStartPage.OkClick(Sender: TObject);
var
  S: string;
begin
  S := Trim(FName.Text);
  if S = '' then
  begin
    ShowWarning('Give the quick start a name');
    Exit;
  end;
  for var T in FTaken do
    if SameText(T, S) then
    begin
      ShowWarning(Format('There is a quick start "%s" already', [S]));
      Exit;
    end;
  FForm.ModalResult := mrOk;
end;

procedure EditQuickStart(const Q: TQuickStart; const Lists, Dashboards, Taken: TArray<string>;
  const Caption: string; const OnSave: TProc<TQuickStart>);
var
  F: TForm;
  Page: TQuickStartPage;
  Box: TVertScrollBox;
  Bar: TLayout;
  Ok, Cancel: TButton;
  Y: Single;

  function Caption_(const Text: string): TLabel;
  begin
    Result := TLabel.Create(F);
    Result.Parent := Box;
    Result.Position.Y := Y;
    Result.Align := TAlignLayout.Top;
    Result.Margins.Top := 10;
    Result.Height := 22;
    Result.Text := Text;
    Y := Y + 40;
  end;

  function Check(const Text: string; Value: Boolean): TCheckBox;
  begin
    Result := TCheckBox.Create(F);
    Result.Parent := Box;
    Result.Position.Y := Y;
    Result.Align := TAlignLayout.Top;
    Result.Margins.Top := 6;
    Result.Height := 32;
    Result.Text := Text;
    Result.IsChecked := Value;
    Result.OnChange := Page.StepChange;
    Y := Y + 40;
  end;

  function Combo(const First: string; const Items: TArray<string>; const Value: string): TComboBox;
  var
    I: Integer;
  begin
    Result := TComboBox.Create(F);
    Result.Parent := Box;
    Result.Position.Y := Y;
    Result.Align := TAlignLayout.Top;
    Result.Height := 36;
    Result.Items.Add(First);
    for I := 0 to High(Items) do
      Result.Items.Add(Items[I]);
    Result.ItemIndex := Max(0, Result.Items.IndexOf(Value));
    Y := Y + 40;
  end;

begin
  F := TForm.CreateNew(nil);
  F.Caption := Caption;
  F.Position := TFormPosition.MainFormCenter;
  F.ClientWidth := 520;
  F.ClientHeight := 620;
  Page := TQuickStartPage.Create(F);
  Page.FForm := F;
  Page.FTaken := Taken;
  Bar := TLayout.Create(F);
  Bar.Parent := F;
  Bar.Align := TAlignLayout.Bottom;
  Bar.Height := 52;
  Cancel := TButton.Create(F);
  Cancel.Parent := Bar;
  Cancel.Align := TAlignLayout.Right;
  Cancel.Margins.Rect := TRectF.Create(0, 10, 12, 10);
  Cancel.Width := 95;
  Cancel.Text := 'Cancel';
  Cancel.Cancel := True;
  Cancel.ModalResult := mrCancel;
  Ok := TButton.Create(F);
  Ok.Parent := Bar;
  Ok.Align := TAlignLayout.Right;
  Ok.Margins.Rect := TRectF.Create(0, 10, 8, 10);
  Ok.Width := 95;
  Ok.Text := 'Save';
  Ok.Default := True;
  Ok.OnClick := Page.OkClick;
  Box := TVertScrollBox.Create(F);
  Box.Parent := F;
  Box.Align := TAlignLayout.Client;
  Box.Padding.Rect := TRectF.Create(16, 4, 16, 8);
  Y := 0;

  Caption_('Name (on the Quick start menu and the shortcut)');
  Page.FName := TEdit.Create(F);
  Page.FName.Parent := Box;
  Page.FName.Position.Y := Y;
  Page.FName.Align := TAlignLayout.Top;
  Page.FName.Height := 36;
  Page.FName.Text := Q.Name;
  Y := Y + 40;
  Caption_('Scan list');
  Page.FList := Combo(KeepSelection, Lists, Q.List);
  Caption_('Dashboard');
  Page.FDash := Combo(ListsDashboard, Dashboards, Q.Dashboard);
  Caption_('Then');
  Page.FConnect := Check('Connect', Q.Connect);
  Page.FScan := Check('Start scanning', Q.Scan);
  Page.FLog := Check('Start a log', Q.Log);
  Page.FFull := Check('Dashboard on the whole screen', Q.FullScreen);
  Page.FChart := Check('Open the live chart', Q.Chart);
  Page.FRetry := Check('Keep trying to connect until the car answers', Q.Retry);

  MakePage(F, Caption, Ok);
  ShowDialog(F,
    procedure(R: TModalResult)
    begin
      if (R = mrOk) and Assigned(OnSave) then
        OnSave(Page.Read);
    end);
end;

{$IFDEF MSWINDOWS}
function CreateQuickStartShortcut(const Q: TQuickStart): string;
var
  Obj: IUnknown;
  Link: IShellLink;
  Desk: array[0..MAX_PATH] of Char;
  Name: string;
  C: Char;
begin
  Obj := CreateComObject(CLSID_ShellLink);
  Link := Obj as IShellLink;
  OleCheck(Link.SetPath(PChar(ParamStr(0))));
  OleCheck(Link.SetArguments(PChar(Q.Arguments)));
  OleCheck(Link.SetWorkingDirectory(PChar(ExtractFileDir(ParamStr(0)))));
  OleCheck(Link.SetDescription(PChar(Copy('UVScan: ' + Q.Describe, 1, 250))));
  OleCheck(Link.SetIconLocation(PChar(ParamStr(0)), 0));
  if SHGetFolderPath(0, CSIDL_DESKTOPDIRECTORY, 0, 0, Desk) <> S_OK then
    raise Exception.Create('Could not find the desktop folder');
  Name := 'UVScan - ' + Q.Name;
  for C in '\/:*?"<>|' do
    Name := StringReplace(Name, C, ' ', [rfReplaceAll]);
  Result := IncludeTrailingPathDelimiter(Desk) + Trim(Name) + '.lnk';
  OleCheck((Obj as IPersistFile).Save(PWideChar(Result), True));
end;
{$ENDIF}

end.
