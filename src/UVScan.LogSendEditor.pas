unit UVScan.LogSendEditor;

{ The Send logs page: where the log goes while it is written (email, and
  on Windows a folder), how often, how much, and how hard it tries; a test
  for each way. Sending itself is turned on on the Connect page ("Send
  while logging"). See UVScan.LogSend. }

interface

uses
  System.SysUtils, UVScan.LogSend;

{ Edits a copy of Settings on a page of its own; Save copies it back.
  OnDone (always called) gets True when saved. }
procedure EditLogSending(Settings: TLogSendSettings; const OnDone: TProc<Boolean>);

implementation

uses
  System.Classes, System.Types, System.UITypes, System.Math, System.IOUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit, FMX.ComboEdit, FMX.ListBox, FMX.Layouts,
  FMX.Dialogs, FMX.Graphics,
  UVScan.Smtp, UVScan.UI.Common, UVScan.UI.Theme;

const
  NarrowWidth = 600;
  RowHeight = 36;

type
  { Whether the page is still there, for the threads that report to it. }
  TAlive = class(TInterfacedObject)
  public
    Alive: Boolean;
  end;

  TLogSendPage = class(TComponent)
  private
    FForm: TForm;
    FBox: TVertScrollBox;
    FY: Single;
    FSettings: TLogSendSettings; // the caller's
    FSaved, FChanged, FDiscardOk, FLoading, FBuilt: Boolean;
    FAlive: IInterface;
    FRows: TArray<TControl>;
    FCaps: TArray<TLabel>;
    FOrder: TArray<TControl>;
    FButtonRows: TArray<TLayout>;   // rows of buttons, flowed at their own width
    FButtonItems: TArray<TArray<TControl>>;
    FButtonWidths: TArray<Single>;  // the width each row was flowed for
    cbEvery, cbMax, cbRetries: TComboEdit;
    chkZip: TCheckBox;
    cbWhen, cbWhat, cbAtStop: TComboBox;
    FEveryParts: TArray<TControl>; // only for a snapshot every few minutes
    chkEmail: TCheckBox;
    cbServer: TComboEdit;
    cbSecurity: TComboBox;
    edtPort, edtUser, edtPassword, edtTo: TEdit;
    btnTestEmail: TButton;
    chkFolder: TCheckBox;
    edtFolder: TEdit;
    btnBrowse, btnTestFolder: TButton;
    function Alive: TAlive;
    function Add(C: TControl; Height: Single): TControl;
    function Caption(const Text: string): TLabel;
    function Note(const Text: string): TLabel;
    function Row(const Text: string; Field: TControl): TLayout;
    function Buttons(const Items: array of TButton): TLayout;
    procedure Build;
    procedure Load;
    procedure ApplyTo(S: TLogSendSettings);
    procedure Relayout;
    procedure FormResized(Sender: TObject);
    procedure ButtonRowResized(Sender: TObject);
    procedure FlowButtons(Row: Integer);
    procedure Changed(Sender: TObject);
    procedure SecurityChanged(Sender: TObject);
    procedure WhenChanged(Sender: TObject);
    procedure ShowWhen;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure CloseDiscarding;
    procedure RunTest(Way: TSendWay; Button: TButton);
    procedure TestEmailClick(Sender: TObject);
    procedure TestFolderClick(Sender: TObject);
    procedure BrowseClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
  public
    destructor Destroy; override;
  end;

function NumText(const S: string; Default, Lo, Hi: Integer): Integer;
begin
  Result := EnsureRange(StrToIntDef(Trim(S), Default), Lo, Hi);
end;

destructor TLogSendPage.Destroy;
begin
  if FAlive <> nil then
    Alive.Alive := False;
  inherited;
end;

function TLogSendPage.Alive: TAlive;
begin
  Result := FAlive as TAlive;
end;

{ Building the page }

function TLogSendPage.Add(C: TControl; Height: Single): TControl;
begin
  C.Parent := FBox;
  C.Align := TAlignLayout.Top;
  C.Position.Y := FY;
  C.Height := Height;
  FY := FY + Height + 100; // the order; the realign closes the gaps
  FOrder := FOrder + [C];
  Result := C;
end;

function TLogSendPage.Caption(const Text: string): TLabel;
begin
  Result := TLabel.Create(FForm);
  Result.Margins.Top := 14;
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Style];
  Result.TextSettings.Font.Style := [TFontStyle.fsBold];
  Result.Text := Text;
  Add(Result, 24);
end;

function TLogSendPage.Note(const Text: string): TLabel;
begin
  Result := TLabel.Create(FForm);
  Result.WordWrap := True;
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.FontColor];
  Result.TextSettings.FontColor := Palette.Muted;
  Result.Text := Text;
  Add(Result, 22);
end;

function TLogSendPage.Row(const Text: string; Field: TControl): TLayout;
var
  L: TLabel;
begin
  Result := TLayout.Create(FForm);
  Result.Margins.Top := 4;
  Add(Result, RowHeight + 6);
  L := TLabel.Create(FForm);
  L.Parent := Result;
  L.Text := Text;
  Field.Parent := Result;
  Field.Align := TAlignLayout.Client;
  Field.Margins.Bottom := 6;
  FRows := FRows + [Result];
  FCaps := FCaps + [L];
end;

function TLogSendPage.Buttons(const Items: array of TButton): TLayout;
var
  B: TButton;
  List: TArray<TControl>;
begin
  Result := TLayout.Create(FForm);
  Result.Margins.Top := 8;
  Add(Result, 48);
  List := nil;
  for B in Items do
  begin
    B.Parent := Result;
    List := List + [B];
  end;
  Result.Tag := Length(FButtonRows);
  FButtonRows := FButtonRows + [Result];
  FButtonItems := FButtonItems + [List];
  FButtonWidths := FButtonWidths + [0];
  Result.OnResized := ButtonRowResized;
end;

{ A row's buttons wrap by the row's own width, known only once the page has
  been laid out (flowed at a made-up width they ran off the side). }
procedure TLogSendPage.ButtonRowResized(Sender: TObject);
var
  I: Integer;
begin
  I := TControl(Sender).Tag;
  if (I >= 0) and (I < Length(FButtonRows)) and not SameValue(FButtonRows[I].Width, FButtonWidths[I], 0.5) then
    FlowButtons(I);
end;

procedure TLogSendPage.FlowButtons(Row: Integer);
begin
  FButtonWidths[Row] := FButtonRows[Row].Width;
  FlowControls(FButtonRows[Row], FButtonItems[Row]);
end;

function NewButton(Owner: TComponent; const Text: string; OnClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Owner);
  Result.Text := Text;
  Result.OnClick := OnClick;
end;

function NewCheck(Owner: TComponent; const Text: string; OnChange: TNotifyEvent): TCheckBox;
begin
  Result := TCheckBox.Create(Owner);
  Result.Text := Text;
  Result.OnChange := OnChange;
end;

function NewEdit(Owner: TComponent; const Prompt: string; OnChange: TNotifyEvent): TEdit;
begin
  Result := TEdit.Create(Owner);
  Result.TextPrompt := Prompt;
  Result.OnChange := OnChange;
  Result.OnChangeTracking := OnChange;
end;

function NewCombo(Owner: TComponent; const Items: string; OnChange: TNotifyEvent): TComboEdit;
begin
  Result := TComboEdit.Create(Owner);
  Result.Items.CommaText := Items;
  Result.OnChange := OnChange;
  Result.OnChangeTracking := OnChange;
end;

procedure TLogSendPage.Build;
var
  Bar: TLayout;
  B, Ok: TButton;
  M: TMailSecurity;
begin
  FForm.OnCloseQuery := FormCloseQuery;
  Bar := TLayout.Create(FForm);
  Bar.Parent := FForm;
  Bar.Align := TAlignLayout.Bottom;
  Bar.Height := 52;
  B := TButton.Create(FForm);
  B.Parent := Bar;
  B.Align := TAlignLayout.Right;
  B.Text := 'Cancel';
  B.Cancel := True;
  B.ModalResult := mrCancel;
  Ok := TButton.Create(FForm);
  Ok.Parent := Bar;
  Ok.Align := TAlignLayout.Right;
  Ok.Text := 'Save';
  Ok.OnClick := SaveClick;
  FBox := TVertScrollBox.Create(FForm);
  FBox.Parent := FForm;
  FBox.Align := TAlignLayout.Client;
  FBox.Padding.Rect := TRectF.Create(16, 4, 16, 16);
  FBox.OnResized := FormResized;
  FY := 0;

  Note('While a log is written UVScan can send it on every few minutes, or the whole log once when it ' +
    'stops: to a crew''s email' +
    {$IFDEF MSWINDOWS}' or a cloud drive''s folder on this PC' + {$ENDIF}'. Turn it on for a ' +
    'drive with Send while logging (Connect page); it is off again each time UVScan starts. It needs the ' +
    'internet (Wi-Fi or mobile data) while it logs.');

  Caption('When');
  cbWhen := TComboBox.Create(FForm);
  cbWhen.Items.Add('Every few minutes while it logs');
  cbWhen.Items.Add('Only when the log stops: the whole log');
  cbWhen.OnChange := WhenChanged;
  Row('Send it', cbWhen);
  cbEvery := NewCombo(FForm, '1,2,5,10,15,30', Changed);
  FEveryParts := [Row('Every (minutes)', cbEvery)];
  cbMax := NewCombo(FForm, '5,10,12,20,30,60', Changed);
  FEveryParts := FEveryParts + [Row('Most snapshots per log', cbMax)];
  FEveryParts := FEveryParts + [Note('Then it stops sending for that log, so a long session does not flood ' +
    'anyone: every 5 minutes and 12 at most is the first hour.')];
  cbAtStop := TComboBox.Create(FForm);
  cbAtStop.Items.Add('Nothing more');
  cbAtStop.Items.Add('One more, like the others');
  cbAtStop.Items.Add('The whole log, in one file');
  cbAtStop.OnChange := Changed;
  FEveryParts := FEveryParts + [Row('When the log stops', cbAtStop)];
  Note('The whole log: everything from start to stop in one file, also when the others are only the new ' +
    'rows or the most was reached. An email over 10 MB is zipped.');
  cbRetries := NewCombo(FForm, '0,1,2,3,5,10', Changed);
  Row('Tries again', cbRetries);
  Note('A snapshot that does not go is tried again that many times (15 s, 30 s, 1 min, then every 2 min ' +
    'apart). After that that way stops for this log, and a note says so; the log goes on.');

  Caption('What');
  cbWhat := TComboBox.Create(FForm);
  cbWhat.Items.Add('The whole log so far, each time');
  cbWhat.Items.Add('Only the rows since the last one');
  cbWhat.OnChange := Changed;
  FEveryParts := FEveryParts + [Row('Sends', cbWhat)];
  chkZip := NewCheck(FForm, 'Zip it (a tenth of the size: less mobile data)', Changed);
  Add(chkZip, 34);
  Note('The whole log: each one opens on its own' + {$IFDEF MSWINDOWS}'; the folder keeps one file per log, ' +
    'brought up to date' + {$ENDIF}'. ' +
    'Only the new rows: smaller, numbered parts (-part01, -part02...) to put together.');

  Caption('Email');
  chkEmail := NewCheck(FForm, 'Send it by email', Changed);
  Add(chkEmail, 34);
  cbServer := NewCombo(FForm, 'smtp.gmail.com,smtp.mail.yahoo.com,smtp.mail.me.com,smtp.zoho.com', Changed);
  Row('Mail server', cbServer);
  cbSecurity := TComboBox.Create(FForm);
  for M := Low(M) to High(M) do
    cbSecurity.Items.Add(MailSecurityNames[M]);
  cbSecurity.OnChange := SecurityChanged;
  Row('Security', cbSecurity);
  edtPort := NewEdit(FForm, '465', Changed);
  Row('Port', edtPort);
  edtUser := NewEdit(FForm, 'you@gmail.com', Changed);
  Row('Account', edtUser);
  edtPassword := NewEdit(FForm, 'an app password', Changed);
  edtPassword.Password := True;
  Row('Password', edtPassword);
  edtTo := NewEdit(FForm, 'crew@example.com, me@example.com', Changed);
  Row('Send to', edtTo);
  Note('Gmail: an app password (Google Account > Security > 2-Step Verification > App passwords), ' +
    'not the account''s own; iCloud and Yahoo have them too. Outlook.com and Hotmail no longer take a ' +
    'password from programs like this one.');
  btnTestEmail := NewButton(FForm, 'Send a test email', TestEmailClick);
  Buttons([btnTestEmail]);

  {$IFDEF MSWINDOWS}
  Caption('Folder');
  chkFolder := NewCheck(FForm, 'Copy it to a folder', Changed);
  Add(chkFolder, 34);
  edtFolder := NewEdit(FForm, 'G:\My Drive\UVScan', Changed);
  Row('Folder', edtFolder);
  Note('A folder Google Drive, OneDrive or Dropbox keeps in step with the cloud (G:\My Drive\..., ' +
    'OneDrive\..., Dropbox\...) uploads it as it changes: nothing to sign in to here. A shared folder on ' +
    'the network or a USB drive works too.');
  btnBrowse := NewButton(FForm, 'Choose...', BrowseClick);
  btnTestFolder := NewButton(FForm, 'Test', TestFolderClick);
  Buttons([btnBrowse, btnTestFolder]);
  {$ENDIF}

  Caption('Kept where');
  {$IFDEF MSWINDOWS}
  Note('The password is kept in settings.json, locked to this Windows user.');
  {$ELSE}
  Note('The password is kept in UVScan''s own storage on this phone.');
  {$ENDIF}

  FBuilt := True;
  MakePage(FForm, 'Send logs', Ok);
end;

procedure TLogSendPage.FormResized(Sender: TObject);
begin
  Relayout;
end;

procedure TLogSendPage.Relayout;
var
  W: Single;
  L: TLabel;
begin
  if not FBuilt then
    Exit;
  W := FBox.Width - FBox.Padding.Left - FBox.Padding.Right - 4;
  if W < 100 then
    Exit;
  ArrangeCaptionRows(FRows, FCaps, InnerWidth(FForm) < NarrowWidth, RowHeight);
  for var C in FBox.Content.Controls do
    if (C is TLabel) and TLabel(C).WordWrap then
    begin
      L := TLabel(C);
      L.Height := Max(20, WrappedTextHeight(L, W) + 4);
    end;
  for var I := 0 to High(FButtonRows) do
    FlowButtons(I);
end;

procedure TLogSendPage.Load;
begin
  FLoading := True;
  try
    cbEvery.Text := IntToStr(FSettings.IntervalMin);
    cbMax.Text := IntToStr(FSettings.MaxSends);
    cbRetries.Text := IntToStr(FSettings.Retries);
    cbAtStop.ItemIndex := Ord(FSettings.AtStop);
    cbWhen.ItemIndex := Ord(FSettings.OnlyAtStop);
    ShowWhen;
    cbWhat.ItemIndex := Ord(FSettings.What);
    chkZip.IsChecked := FSettings.Zip;
    chkEmail.IsChecked := FSettings.EmailOn;
    cbServer.Text := FSettings.Mail.Server;
    cbSecurity.ItemIndex := Ord(FSettings.Mail.Security);
    edtPort.Text := IntToStr(FSettings.Mail.Port);
    edtUser.Text := FSettings.Mail.User;
    edtPassword.Text := FSettings.Mail.Password;
    edtTo.Text := FSettings.MailTo;
    if chkFolder <> nil then
    begin
      chkFolder.IsChecked := FSettings.FolderOn;
      edtFolder.Text := FSettings.Folder;
    end;
  finally
    FLoading := False;
  end;
end;

procedure TLogSendPage.ApplyTo(S: TLogSendSettings);
begin
  S.IntervalMin := NumText(cbEvery.Text, 5, 1, 240);
  S.MaxSends := NumText(cbMax.Text, 12, 1, 1000);
  S.Retries := NumText(cbRetries.Text, 3, 0, 20);
  S.AtStop := TLogSendAtStop(Max(0, cbAtStop.ItemIndex));
  S.OnlyAtStop := cbWhen.ItemIndex = 1;
  S.What := TLogSendWhat(Max(0, cbWhat.ItemIndex));
  S.Zip := chkZip.IsChecked;
  S.EmailOn := chkEmail.IsChecked;
  S.Mail.Server := Trim(cbServer.Text);
  S.Mail.Security := TMailSecurity(Max(0, cbSecurity.ItemIndex));
  S.Mail.Port := NumText(edtPort.Text, MailSecurityPorts[S.Mail.Security], 1, 65535);
  S.Mail.User := Trim(edtUser.Text);
  S.Mail.Password := edtPassword.Text;
  S.Mail.From := '';
  S.MailTo := Trim(edtTo.Text);
  if chkFolder <> nil then
  begin
    S.FolderOn := chkFolder.IsChecked;
    S.Folder := Trim(edtFolder.Text);
  end;
end;

procedure TLogSendPage.Changed(Sender: TObject);
begin
  if not FLoading then
    FChanged := True;
end;

procedure TLogSendPage.WhenChanged(Sender: TObject);
begin
  Changed(Sender);
  ShowWhen;
end;

{ Only when the log stops: the settings for the ones every few minutes do
  nothing, so they are greyed. }
procedure TLogSendPage.ShowWhen;
begin
  for var C in FEveryParts do
    C.Enabled := cbWhen.ItemIndex <> 1;
end;

procedure TLogSendPage.SecurityChanged(Sender: TObject);
var
  M: TMailSecurity;
begin
  Changed(Sender);
  if FLoading or (cbSecurity.ItemIndex < 0) then
    Exit;
  // the port that goes with it, unless one of its own was typed
  for M := Low(M) to High(M) do
    if Trim(edtPort.Text) = IntToStr(MailSecurityPorts[M]) then
    begin
      edtPort.Text := IntToStr(MailSecurityPorts[TMailSecurity(cbSecurity.ItemIndex)]);
      Break;
    end;
end;

procedure TLogSendPage.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if (FForm.ModalResult = mrOk) or not FChanged or FDiscardOk then
    Exit;
  CanClose := False;
  Confirm('Discard your changes to sending logs?',
    procedure
    begin
      FDiscardOk := True;
      TThread.ForceQueue(nil, CloseDiscarding);
    end);
end;

procedure TLogSendPage.CloseDiscarding;
begin
  FForm.ModalResult := mrCancel;
end;

{ Tests }

procedure TLogSendPage.RunTest(Way: TSendWay; Button: TButton);
var
  S: TLogSendSettings;
  Problem, Was: string;
  Snap: TLogSnapshot;
  Token: IInterface;
begin
  S := TLogSendSettings.Create;
  ApplyTo(S);
  Problem := S.Problem(Way);
  if Problem <> '' then
  begin
    S.Free;
    ShowWarning(Problem);
    Exit;
  end;
  Snap := Default(TLogSnapshot);
  Snap.LogFile := 'UVScan test.csv';
  Snap.Number := 1;
  Snap.What := lwNew; // a file of its own each time
  Snap.FileName := 'UVScan test.csv';
  Snap.MimeType := 'text/csv';
  Snap.Data := TEncoding.UTF8.GetBytes('Time (s),Test' + sLineBreak + '0.0,1' + sLineBreak + '0.1,2' + sLineBreak);
  Snap.Rows := 2;
  Snap.When := Now;
  Was := Button.Text;
  Button.Text := 'Sending...';
  Button.Enabled := False;
  Token := FAlive;
  TThread.CreateAnonymousThread(
    procedure
    var
      Error, Where: string;
    begin
      Error := '';
      try
        try
          DeliverSnapshot(Way, S, Snap);
        except
          on E: Exception do
            Error := E.Message;
        end;
        if Way = swEmail then
          Where := 'An email went to ' + S.MailTo + '.'
        else
          Where := TPath.Combine(S.Folder, Snap.FileName) + ' is there.';
      finally
        S.Free;
      end;
      TThread.Queue(nil,
        procedure
        begin
          if not (Token as TAlive).Alive then
            Exit;
          Button.Text := Was;
          Button.Enabled := True;
          if Error = '' then
            ShowInfo('It works. ' + Where)
          else
            ShowError('Could not send it by ' + SendWayNames[Way] + ': ' + Error);
        end);
    end).Start;
end;

procedure TLogSendPage.TestEmailClick(Sender: TObject);
begin
  RunTest(swEmail, btnTestEmail);
end;

procedure TLogSendPage.TestFolderClick(Sender: TObject);
begin
  RunTest(swFolder, btnTestFolder);
end;

procedure TLogSendPage.BrowseClick(Sender: TObject);
var
  Dir: string;
begin
  {$IFDEF MSWINDOWS}
  Dir := Trim(edtFolder.Text);
  if SelectDirectory('Folder to copy the logs to', '', Dir) then
    edtFolder.Text := Dir;
  {$ENDIF}
end;

procedure TLogSendPage.SaveClick(Sender: TObject);
var
  S: TLogSendSettings;
  W: TSendWay;
  Problems: string;
begin
  S := TLogSendSettings.Create;
  try
    ApplyTo(S);
    Problems := '';
    for W in S.Ways do
      if S.Problem(W) <> '' then
        Problems := Problems + sLineBreak + S.Problem(W);
    if Problems <> '' then
    begin
      ShowWarning('Not ready yet:' + Problems);
      Exit;
    end;
    FSettings.Assign(S);
  finally
    S.Free;
  end;
  FSaved := True;
  FForm.ModalResult := mrOk;
end;

procedure EditLogSending(Settings: TLogSendSettings; const OnDone: TProc<Boolean>);
var
  F: TForm;
  Page: TLogSendPage;
  A: TAlive;
begin
  F := TForm.CreateNew(nil);
  F.Caption := 'Send logs';
  F.Position := TFormPosition.MainFormCenter;
  F.ClientWidth := 640;
  F.ClientHeight := 720;
  Page := TLogSendPage.Create(F);
  Page.FForm := F;
  Page.FSettings := Settings;
  A := TAlive.Create;
  A.Alive := True;
  Page.FAlive := A;
  Page.Build;
  Page.Load;
  FitToScreen(F);
  ShowDialog(F,
    procedure(R: TModalResult)
    begin
      if Assigned(OnDone) then
        OnDone(Page.FSaved);
    end);
end;

end.
