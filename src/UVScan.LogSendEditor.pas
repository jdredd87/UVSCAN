unit UVScan.LogSendEditor;

{ The Send logs page: where the log goes while it is written (email, a
  folder, Google Drive), how often, how much, and how hard it tries; a test
  for each way, and signing in to Google Drive. Sending itself is turned on
  on the Connect page ("Send while logging"). See UVScan.LogSend. }

interface

uses
  System.SysUtils, UVScan.LogSend;

{ Edits a copy of Settings on a page of its own; Save copies it back.
  OnDone (always called) gets True when saved. }
procedure EditLogSending(Settings: TLogSendSettings; const OnDone: TProc<Boolean>);

implementation

uses
  System.Classes, System.Types, System.UITypes, System.Math, System.StrUtils, System.IOUtils,
  System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit, FMX.ComboEdit, FMX.ListBox, FMX.Layouts,
  FMX.Dialogs, FMX.Graphics, FMX.Platform,
  UVScan.Smtp, UVScan.GoogleDrive, UVScan.UI.Common, UVScan.UI.Theme;

const
  NarrowWidth = 600;
  RowHeight = 36;

type
  { Whether the page is still there, for the threads that report to it. }
  TAlive = class(TInterfacedObject)
  public
    Alive: Boolean;
    StopSignIn: Boolean;
  end;

  TLogSendPage = class(TComponent)
  private
    FForm: TForm;
    FBox: TVertScrollBox;
    FY: Single;
    FSettings: TLogSendSettings; // the caller's
    FDriveToken, FDriveAccount: string;
    FSaved, FChanged, FDiscardOk, FLoading: Boolean;
    FAlive: IInterface;
    FRows: TArray<TControl>;
    FCaps: TArray<TLabel>;
    FOrder: TArray<TControl>;
    FFolderParts: TArray<TControl>; // Windows only
    FCodeParts: TArray<TControl>;   // while signing in
    cbEvery, cbMax, cbRetries: TComboEdit;
    chkAtStop, chkZip: TCheckBox;
    cbWhat: TComboBox;
    chkEmail: TCheckBox;
    cbServer: TComboEdit;
    cbSecurity: TComboBox;
    edtPort, edtUser, edtPassword, edtTo: TEdit;
    btnTestEmail: TButton;
    chkFolder: TCheckBox;
    edtFolder: TEdit;
    btnBrowse, btnTestFolder: TButton;
    chkDrive: TCheckBox;
    lblDrive: TLabel;
    pnlDriveButtons: TLayout;
    btnSignIn, btnSignOut, btnTestDrive: TButton;
    lblCode: TLabel;
    lblCodeHow: TLabel;
    pnlCodeButtons: TLayout;
    btnOpenPage, btnCopyCode, btnCancelSignIn: TButton;
    edtDriveFolder, edtClientId, edtClientSecret: TEdit;
    FCodeUrl, FCode: string;
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
    procedure KeepOrder;
    procedure ShowDrive;
    procedure FormResized(Sender: TObject);
    procedure Changed(Sender: TObject);
    procedure SecurityChanged(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure CloseDiscarding;
    procedure RunTest(Way: TSendWay; Button: TButton);
    procedure TestEmailClick(Sender: TObject);
    procedure TestFolderClick(Sender: TObject);
    procedure TestDriveClick(Sender: TObject);
    procedure BrowseClick(Sender: TObject);
    procedure SignInClick(Sender: TObject);
    procedure SignOutClick(Sender: TObject);
    procedure OpenPageClick(Sender: TObject);
    procedure CopyCodeClick(Sender: TObject);
    procedure CancelSignInClick(Sender: TObject);
    procedure ShowCode(Showing: Boolean);
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
  begin
    Alive.Alive := False;
    Alive.StopSignIn := True;
  end;
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
begin
  Result := TLayout.Create(FForm);
  Result.Margins.Top := 8;
  Add(Result, 48);
  for B in Items do
    B.Parent := Result;
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
  C: TControl;
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

  Note('While a log is written UVScan can send it on every few minutes: to a crew''s email, ' +
    {$IFDEF MSWINDOWS}'a cloud drive''s folder on this PC ' + {$ENDIF}'or Google Drive. Turn it on for a ' +
    'drive with Send while logging (Connect page); it is off again each time UVScan starts. It needs the ' +
    'internet (Wi-Fi or mobile data) while it logs.');

  Caption('When');
  cbEvery := NewCombo(FForm, '1,2,5,10,15,30', Changed);
  Row('Every (minutes)', cbEvery);
  cbMax := NewCombo(FForm, '5,10,12,20,30,60', Changed);
  Row('At most per log', cbMax);
  chkAtStop := NewCheck(FForm, 'And one more when the log stops', Changed);
  Add(chkAtStop, 34);
  cbRetries := NewCombo(FForm, '0,1,2,3,5,10', Changed);
  Row('Tries again', cbRetries);
  Note('A snapshot that does not go is tried again that many times (15 s, 30 s, 1 min, then every 2 min ' +
    'apart). After that that way stops for this log, and a note says so; the log goes on.');

  Caption('What');
  cbWhat := TComboBox.Create(FForm);
  cbWhat.Items.Add('The whole log so far, each time');
  cbWhat.Items.Add('Only the rows since the last one');
  cbWhat.OnChange := Changed;
  Row('Sends', cbWhat);
  chkZip := NewCheck(FForm, 'Zip it (a tenth of the size: less mobile data)', Changed);
  Add(chkZip, 34);
  Note('The whole log: each one opens on its own; Google Drive keeps one file per log, brought up to date. ' +
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
  FFolderParts := FFolderParts + [Caption('Folder')];
  chkFolder := NewCheck(FForm, 'Copy it to a folder', Changed);
  FFolderParts := FFolderParts + [Add(chkFolder, 34)];
  edtFolder := NewEdit(FForm, 'G:\My Drive\UVScan', Changed);
  FFolderParts := FFolderParts + [Row('Folder', edtFolder)];
  FFolderParts := FFolderParts + [Note('A folder Google Drive, OneDrive or Dropbox keeps in step with the ' +
    'cloud (G:\My Drive\..., OneDrive\..., Dropbox\...) uploads it as it changes: nothing to sign in to ' +
    'here. A shared folder on the network works too.')];
  btnBrowse := NewButton(FForm, 'Choose...', BrowseClick);
  btnTestFolder := NewButton(FForm, 'Test', TestFolderClick);
  FFolderParts := FFolderParts + [Buttons([btnBrowse, btnTestFolder])];
  {$ENDIF}

  Caption('Google Drive');
  chkDrive := NewCheck(FForm, 'Upload it to Google Drive', Changed);
  Add(chkDrive, 34);
  lblDrive := Note('');
  btnSignIn := NewButton(FForm, 'Sign in...', SignInClick);
  btnSignOut := NewButton(FForm, 'Sign out', SignOutClick);
  btnTestDrive := NewButton(FForm, 'Test', TestDriveClick);
  pnlDriveButtons := Buttons([btnSignIn, btnSignOut, btnTestDrive]);
  lblCode := TLabel.Create(FForm);
  lblCode.StyledSettings := lblCode.StyledSettings - [TStyledSetting.Size, TStyledSetting.Style];
  lblCode.TextSettings.Font.Size := 30;
  lblCode.TextSettings.Font.Style := [TFontStyle.fsBold];
  lblCode.TextSettings.HorzAlign := TTextAlign.Center;
  lblCode.Margins.Top := 8;
  Add(lblCode, 48);
  lblCodeHow := Note('');
  btnOpenPage := NewButton(FForm, 'Open the page', OpenPageClick);
  btnCopyCode := NewButton(FForm, 'Copy the code', CopyCodeClick);
  btnCancelSignIn := NewButton(FForm, 'Cancel', CancelSignInClick);
  pnlCodeButtons := Buttons([btnOpenPage, btnCopyCode, btnCancelSignIn]);
  FCodeParts := [lblCode, lblCodeHow, pnlCodeButtons];
  edtDriveFolder := NewEdit(FForm, 'UVScan logs', Changed);
  Row('Folder in Drive', edtDriveFolder);
  Note('UVScan only sees the files it puts there, nothing else in the Drive. Share the folder with the ' +
    'crew in Google Drive to let them open it.');
  edtClientId := NewEdit(FForm, IfThen(DefaultDriveClientId <> '', 'UVScan''s own', 'xxxx.apps.googleusercontent.com'),
    Changed);
  Row('Google app ID', edtClientId);
  edtClientSecret := NewEdit(FForm, IfThen(DefaultDriveClientSecret <> '', 'UVScan''s own', ''), Changed);
  edtClientSecret.Password := True;
  Row('App secret', edtClientSecret);
  Note('A Google Cloud OAuth client of the type "TVs and Limited Input devices", with the Google Drive API ' +
    'turned on (see the user guide). ' + IfThen(DefaultDriveClientId <> '', 'Empty: UVScan''s own.',
    'UVScan has none of its own yet.'));

  Caption('Kept where');
  {$IFDEF MSWINDOWS}
  Note('The password and the Google sign-in are kept in settings.json, locked to this Windows user.');
  {$ELSE}
  Note('The password and the Google sign-in are kept in UVScan''s own storage on this phone.');
  {$ENDIF}

  for C in FCodeParts do
    C.Visible := False;
  MakePage(FForm, 'Send logs', Ok);
end;

{ Keeps the page's top to bottom order after controls were shown again. }
procedure TLogSendPage.KeepOrder;
var
  I: Integer;
begin
  FBox.BeginUpdate;
  try
    for I := 0 to High(FOrder) do
      FOrder[I].Position.Y := I * 1000;
  finally
    FBox.EndUpdate;
  end;
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
  if pnlCodeButtons = nil then
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
  FlowControls(pnlDriveButtons, [btnSignIn, btnSignOut, btnTestDrive]);
  FlowControls(pnlCodeButtons, [btnOpenPage, btnCopyCode, btnCancelSignIn]);
  FlowControls(btnTestEmail.ParentControl, [btnTestEmail]);
  if btnBrowse <> nil then
    FlowControls(btnBrowse.ParentControl, [btnBrowse, btnTestFolder]);
end;

procedure TLogSendPage.Load;
begin
  FLoading := True;
  try
    cbEvery.Text := IntToStr(FSettings.IntervalMin);
    cbMax.Text := IntToStr(FSettings.MaxSends);
    cbRetries.Text := IntToStr(FSettings.Retries);
    chkAtStop.IsChecked := FSettings.AtStop;
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
    chkDrive.IsChecked := FSettings.DriveOn;
    FDriveToken := FSettings.DriveToken;
    FDriveAccount := FSettings.DriveAccount;
    edtDriveFolder.Text := FSettings.DriveFolder;
    edtClientId.Text := FSettings.DriveClientId;
    edtClientSecret.Text := FSettings.DriveClientSecret;
    ShowDrive;
  finally
    FLoading := False;
  end;
end;

procedure TLogSendPage.ApplyTo(S: TLogSendSettings);
begin
  S.IntervalMin := NumText(cbEvery.Text, 5, 1, 240);
  S.MaxSends := NumText(cbMax.Text, 12, 1, 1000);
  S.Retries := NumText(cbRetries.Text, 3, 0, 20);
  S.AtStop := chkAtStop.IsChecked;
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
  S.DriveOn := chkDrive.IsChecked;
  S.DriveToken := FDriveToken;
  S.DriveAccount := FDriveAccount;
  S.DriveFolder := Trim(edtDriveFolder.Text);
  if S.DriveFolder = '' then
    S.DriveFolder := 'UVScan logs';
  S.DriveClientId := Trim(edtClientId.Text);
  S.DriveClientSecret := Trim(edtClientSecret.Text);
end;

procedure TLogSendPage.ShowDrive;
begin
  if FDriveToken <> '' then
    lblDrive.Text := 'Signed in' + IfThen(FDriveAccount <> '', ' as ' + FDriveAccount, '') + '.'
  else
    lblDrive.Text := 'Not signed in: Sign in shows a code to type at google.com/device on any phone or ' +
      'computer, with the Google account whose Drive gets the logs.';
  btnSignOut.Enabled := FDriveToken <> '';
  btnTestDrive.Enabled := FDriveToken <> '';
  Relayout;
end;

procedure TLogSendPage.Changed(Sender: TObject);
begin
  if not FLoading then
    FChanged := True;
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
      Client: TDriveClient;
      FolderId, Error, Where: string;
      Ids: TDictionary<string, string>;
    begin
      Client := nil;
      FolderId := '';
      Error := '';
      Ids := TDictionary<string, string>.Create;
      try
        try
          DeliverSnapshot(Way, S, Snap, Client, FolderId, Ids);
        except
          on E: Exception do
            Error := E.Message;
        end;
        case Way of
          swEmail: Where := 'An email went to ' + S.MailTo + '.';
          swFolder: Where := TPath.Combine(S.Folder, Snap.FileName) + ' is there.';
        else
          Where := Snap.FileName + ' is in "' + S.DriveFolder + '" in the Drive.';
        end;
      finally
        Client.Free;
        Ids.Free;
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

procedure TLogSendPage.TestDriveClick(Sender: TObject);
begin
  RunTest(swDrive, btnTestDrive);
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

{ Signing in to Google Drive }

procedure TLogSendPage.ShowCode(Showing: Boolean);
var
  C: TControl;
begin
  for C in FCodeParts do
    C.Visible := Showing;
  pnlDriveButtons.Visible := not Showing;
  KeepOrder;
  Relayout;
end;

procedure TLogSendPage.SignInClick(Sender: TObject);
var
  S: TLogSendSettings;
  App: TDriveApp;
  Token: IInterface;
begin
  S := TLogSendSettings.Create;
  try
    ApplyTo(S);
    App := S.DriveApp;
  finally
    S.Free;
  end;
  if not App.IsSet then
  begin
    ShowWarning('Google Drive needs a Google app for UVScan first: its client ID and secret, below (see ' +
      'the user guide for making one).');
    Exit;
  end;
  Token := FAlive;
  Alive.StopSignIn := False;
  btnSignIn.Enabled := False;
  lblCode.Text := '...';
  lblCodeHow.Text := 'Asking Google for a code...';
  ShowCode(True);
  TThread.CreateAnonymousThread(
    procedure
    var
      SignIn: TDeviceSignIn;
      Refresh, Account, Error: string;
      Client: TDriveClient;
      Done: Boolean;
      I: Integer;
    begin
      Error := '';
      Refresh := '';
      Account := '';
      try
        SignIn := StartDeviceSignIn(App);
        TThread.Queue(nil,
          procedure
          begin
            if not (Token as TAlive).Alive then
              Exit;
            FCode := SignIn.UserCode;
            FCodeUrl := SignIn.VerifyUrl;
            lblCode.Text := SignIn.UserCode;
            lblCodeHow.Text := Format('On any phone or computer open %s, sign in with the Google account ' +
              'for the logs, type this code and allow UVScan. This page waits for it.', [SignIn.VerifyUrl]);
            Relayout;
          end);
        Done := False;
        while not Done do
        begin
          for I := 1 to SignIn.IntervalS * 10 do
          begin
            Sleep(100);
            if (Token as TAlive).StopSignIn then
              Exit;
          end;
          Done := PollDeviceSignIn(App, SignIn, Refresh);
        end;
        Client := TDriveClient.Create(App, Refresh);
        try
          try
            Account := Client.Email;
          except
            Account := ''; // signed in all the same
          end;
        finally
          Client.Free;
        end;
      except
        on E: Exception do
          Error := E.Message;
      end;
      TThread.Queue(nil,
        procedure
        begin
          if not (Token as TAlive).Alive or (Token as TAlive).StopSignIn then
            Exit;
          btnSignIn.Enabled := True;
          ShowCode(False);
          if Error <> '' then
          begin
            ShowError('Could not sign in to Google Drive: ' + Error);
            Exit;
          end;
          FDriveToken := Refresh;
          FDriveAccount := Account;
          FChanged := True;
          chkDrive.IsChecked := True;
          ShowDrive;
          ShowInfo('Signed in to Google Drive' + IfThen(Account <> '', ' as ' + Account, '') +
            '. Save keeps it.');
        end);
    end).Start;
end;

procedure TLogSendPage.CancelSignInClick(Sender: TObject);
begin
  Alive.StopSignIn := True;
  btnSignIn.Enabled := True;
  ShowCode(False);
end;

procedure TLogSendPage.OpenPageClick(Sender: TObject);
begin
  if FCodeUrl <> '' then
    OpenUrl(FCodeUrl);
end;

procedure TLogSendPage.CopyCodeClick(Sender: TObject);
var
  Clip: IFMXClipboardService;
begin
  if (FCode <> '') and TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clip) then
    Clip.SetClipboard(FCode);
end;

procedure TLogSendPage.SignOutClick(Sender: TObject);
begin
  Confirm('Sign out of Google Drive? Sending there stops until someone signs in again. (To take UVScan''s ' +
    'access away altogether: Google Account > Security > Third-party connections.)',
    procedure
    begin
      FDriveToken := '';
      FDriveAccount := '';
      FChanged := True;
      chkDrive.IsChecked := False;
      ShowDrive;
    end);
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
      (Page.FAlive as TAlive).StopSignIn := True;
      if Assigned(OnDone) then
        OnDone(Page.FSaved);
    end);
end;

end.
