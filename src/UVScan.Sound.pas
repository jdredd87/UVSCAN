unit UVScan.Sound;

{ Plays the alert sounds. Windows plays the built-in waves straight from
  memory (PlaySound); other platforms write them to the temp folder once and
  play them with a media player. }

interface

uses
  UVScan.Display;

{ Starts the sound and returns at once. False when a sound file is missing. }
function PlayAlertSound(Sound: TAlertSound; const FileName: string): Boolean;
procedure StopAlertSound;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows, Winapi.MMSystem,
  {$ELSE}
  System.IOUtils, FMX.Media,
  {$ENDIF}
  System.SysUtils, UVScan.Alerts;

{$IFDEF MSWINDOWS}

var
  Waves: array[TAlertSound] of TBytes; // must outlive a sound still playing

function PlayAlertSound(Sound: TAlertSound; const FileName: string): Boolean;
begin
  Result := True;
  case Sound of
    asNone: ;
    asAlert: PlaySound('SystemExclamation', 0, SND_ALIAS or SND_ASYNC);
    asBeep, asAlarm:
      begin
        if Waves[Sound] = nil then
          Waves[Sound] := AlertWave(Sound);
        PlaySound(PChar(@Waves[Sound][0]), 0, SND_MEMORY or SND_ASYNC or SND_NODEFAULT);
      end;
    asFile:
      Result := FileExists(FileName) and
        PlaySound(PChar(FileName), 0, SND_FILENAME or SND_ASYNC or SND_NODEFAULT);
  end;
end;

procedure StopAlertSound;
begin
  PlaySound(nil, 0, 0);
end;

{$ELSE}

var
  Player: TMediaPlayer;

function WaveFile(Sound: TAlertSound): string;
const
  Names: array[TAlertSound] of string = ('', 'uvscan-beep.wav', 'uvscan-beep.wav', 'uvscan-alarm.wav', '');
begin
  Result := TPath.Combine(TPath.GetTempPath, Names[Sound]);
  if not TFile.Exists(Result) then
    TFile.WriteAllBytes(Result, AlertWave(Sound));
end;

function PlayAlertSound(Sound: TAlertSound; const FileName: string): Boolean;
var
  F: string;
begin
  Result := True;
  if Sound = asNone then
    Exit;
  try
    if Sound = asFile then
      F := FileName
    else
      F := WaveFile(Sound);
    if not FileExists(F) then
      Exit(False);
    if Player = nil then
      Player := TMediaPlayer.Create(nil);
    Player.Stop;
    Player.FileName := F;
    Player.Play;
  except
    Result := False;
  end;
end;

procedure StopAlertSound;
begin
  if Player <> nil then
    Player.Stop;
end;

{$ENDIF}

initialization

finalization
  StopAlertSound;
  {$IFNDEF MSWINDOWS}
  FreeAndNil(Player);
  {$ENDIF}

end.
