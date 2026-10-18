unit UVScan.Share;

{ Getting a file off the phone. Share: Android's share sheet, so a log goes
  by email, to Google Drive, in a message, over Quick Share or Bluetooth -
  whatever the phone has. Save a copy: Android's file picker, where the copy
  goes to Downloads, Google Drive (its own entry in the picker), a USB stick...
  The files are handed over by the app's FileProvider (Secure File Sharing in
  the project), which covers the app's folders, the logs among them. }

interface

uses
  System.SysUtils;

type
  { Done: the copy is saved (Error = '') or failed; not called when the
    picker is cancelled. }
  TSaveCopyDone = reference to procedure(const Error: string);

{ True where there is a share sheet and a file picker (Android). }
function CanShareFiles: Boolean;
{ Offers the file to the apps that take MimeType; Subject and Text for an email. }
procedure ShareFile(const FileName, MimeType, Subject, Text: string);
{ Asks where to put a copy of the file (named as it is), then writes it there. }
procedure SaveFileCopy(const FileName, MimeType: string; const Done: TSaveCopyDone);
{ An empty folder of the app's for a file made just to share (a picture, the
  demo drive): nobody keeps these, so each call clears the last ones. }
function ShareFolder: string;

implementation

uses
  System.Classes, System.IOUtils
  {$IFDEF ANDROID}, System.Messaging, Androidapi.Helpers, Androidapi.JNIBridge, Androidapi.JNI.JavaTypes,
  Androidapi.JNI.GraphicsContentViewText, Androidapi.JNI.Net, Androidapi.JNI.Os,
  Androidapi.JNI.App, Androidapi.JNI.Support{$ENDIF};

function ShareFolder: string;
begin
  Result := TPath.Combine(TPath.GetPublicPath, 'Share');
  if TDirectory.Exists(Result) then
    for var F in TDirectory.GetFiles(Result) do
      try
        TFile.Delete(F);
      except
        // still being read by the app it went to: next time
      end;
  ForceDirectories(Result);
end;

{$IFDEF ANDROID}

const
  SaveCopyRequest = 7301; // startActivityForResult code of the file picker
  ResultOK = -1;          // Activity.RESULT_OK

var
  PendingFile: string;
  PendingDone: TSaveCopyDone;
  Subscribed: Boolean;

function CanShareFiles: Boolean;
begin
  Result := True;
end;

procedure ShareFile(const FileName, MimeType, Subject, Text: string);
var
  Uri: Jnet_Uri;
  Intent: JIntent;
begin
  Uri := TAndroidHelper.JFileToJURI(TJFile.JavaClass.init(StringToJString(FileName)));
  Intent := TJIntent.JavaClass.init(TJIntent.JavaClass.ACTION_SEND);
  Intent.setType(StringToJString(MimeType));
  Intent.putExtra(TJIntent.JavaClass.EXTRA_STREAM, TJParcelable.Wrap(Uri));
  if Subject <> '' then
    Intent.putExtra(TJIntent.JavaClass.EXTRA_SUBJECT, StringToJString(Subject));
  if Text <> '' then
    Intent.putExtra(TJIntent.JavaClass.EXTRA_TEXT, StringToJString(Text));
  Intent.addFlags(TJIntent.JavaClass.FLAG_GRANT_READ_URI_PERMISSION);
  TAndroidHelper.Activity.startActivity(TJIntent.JavaClass.createChooser(Intent,
    StrToJCharSequence('Share ' + ExtractFileName(FileName))));
end;

{ The picked place's stream gets the file in 64 KB pieces. }
procedure WriteCopy(const Uri: Jnet_Uri);
const
  Chunk = 65536;
var
  Src: TFileStream;
  Buf: TBytes;
  JBuf: TJavaArray<Byte>;
  Dest: JOutputStream;
  N: Integer;
begin
  Src := TFileStream.Create(PendingFile, fmOpenRead or fmShareDenyNone);
  try
    Dest := TAndroidHelper.Context.getContentResolver.openOutputStream(Uri);
    if Dest = nil then
      raise Exception.Create('the place picked cannot be written to');
    SetLength(Buf, Chunk);
    JBuf := TJavaArray<Byte>.Create(Chunk);
    try
      repeat
        N := Src.Read(Buf[0], Chunk);
        if N > 0 then
        begin
          Move(Buf[0], JBuf.Data^, N);
          Dest.write(JBuf, 0, N);
        end;
      until N <= 0;
      Dest.flush;
    finally
      Dest.close;
      JBuf.Free;
    end;
  finally
    Src.Free;
  end;
end;

procedure PickerResult(const Sender: TObject; const M: TMessage);
var
  R: TMessageResultNotification;
  Done: TSaveCopyDone;
  Err: string;
begin
  R := TMessageResultNotification(M);
  if (R.RequestCode <> SaveCopyRequest) or (PendingFile = '') then
    Exit;
  Done := PendingDone;
  PendingDone := nil;
  try
    if (R.ResultCode <> ResultOK) or (R.Value = nil) or (R.Value.getData = nil) then
      Exit; // cancelled
    Err := '';
    try
      WriteCopy(R.Value.getData);
    except
      on E: Exception do
        Err := E.Message;
    end;
    if Assigned(Done) then
      TThread.ForceQueue(nil,
        procedure
        begin
          Done(Err);
        end);
  finally
    PendingFile := '';
  end;
end;

procedure SaveFileCopy(const FileName, MimeType: string; const Done: TSaveCopyDone);
var
  Intent: JIntent;
begin
  if not Subscribed then
  begin
    TMessageManager.DefaultManager.SubscribeToMessage(TMessageResultNotification, PickerResult);
    Subscribed := True;
  end;
  PendingFile := FileName;
  PendingDone := Done;
  Intent := TJIntent.JavaClass.init(TJIntent.JavaClass.ACTION_CREATE_DOCUMENT);
  Intent.addCategory(TJIntent.JavaClass.CATEGORY_OPENABLE);
  Intent.setType(StringToJString(MimeType));
  Intent.putExtra(TJIntent.JavaClass.EXTRA_TITLE, StringToJString(ExtractFileName(FileName)));
  TAndroidHelper.Activity.startActivityForResult(Intent, SaveCopyRequest);
end;

{$ELSE}

function CanShareFiles: Boolean;
begin
  Result := False;
end;

procedure ShareFile(const FileName, MimeType, Subject, Text: string);
begin
end;

procedure SaveFileCopy(const FileName, MimeType: string; const Done: TSaveCopyDone);
begin
end;

{$ENDIF}

end.
