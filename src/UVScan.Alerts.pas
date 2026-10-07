unit UVScan.Alerts;

{ Alert sounds and the bookkeeping of which PID is in which display level.

  A level's sound plays when a PID enters that level. To keep a value that
  hovers on a threshold from machine-gunning sounds, a PID sounds at most
  once per MinSoundGapMs; a level marked "repeat" sounds again every
  RepeatIntervalMs while it stays active. }

interface

uses
  System.SysUtils, System.Generics.Collections, UVScan.Display;

const
  MinSoundGapMs = 3000;
  RepeatIntervalMs = 3000;

type
  TAlertChange = record
    Entered: Boolean;    // the PID moved into a different level (or back to normal)
    Level: Integer;      // the new level, -1 = normal
    PlaySound: Boolean;  // a sound is due now
    Announce: Boolean;   // worth a line in Messages (entered a level, not too often)
  end;

  { Pure bookkeeping, no UI: feed it the level each PID is in, it says when to beep. }
  TAlertTracker = class
  private type
    TState = record
      Level: Integer;
      LastSound: UInt64;
      Sounded: Boolean;
      LastAnnounce: UInt64;
      Announced: Boolean;
    end;
  private
    FStates: TDictionary<Integer, TState>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    { NowMs is any increasing millisecond clock (GetTickCount64 in the app). }
    function Update(PidId, Level: Integer; HasSound, RepeatSound: Boolean; NowMs: UInt64): TAlertChange;
    function LevelOf(PidId: Integer): Integer;
  end;

{ Plays a level's sound asynchronously (never blocks the UI). Returns False
  if a sound file could not be played. }
function PlayAlertSound(Sound: TAlertSound; const FileName: string): Boolean;
procedure StopAlertSound;

implementation

uses
  Winapi.Windows, Winapi.MMSystem, System.Math, System.Classes;

{ TAlertTracker }

constructor TAlertTracker.Create;
begin
  inherited;
  FStates := TDictionary<Integer, TState>.Create;
end;

destructor TAlertTracker.Destroy;
begin
  FStates.Free;
  inherited;
end;

procedure TAlertTracker.Reset;
begin
  FStates.Clear;
end;

function TAlertTracker.LevelOf(PidId: Integer): Integer;
var
  S: TState;
begin
  if FStates.TryGetValue(PidId, S) then
    Result := S.Level
  else
    Result := -1;
end;

function TAlertTracker.Update(PidId, Level: Integer; HasSound, RepeatSound: Boolean; NowMs: UInt64): TAlertChange;
var
  S: TState;
  Since: UInt64;
begin
  Result := Default(TAlertChange);
  Result.Level := Level;
  if not FStates.TryGetValue(PidId, S) then
  begin
    S := Default(TState);
    S.Level := -1;
  end;
  Result.Entered := S.Level <> Level;
  S.Level := Level;
  if Result.Entered and (Level >= 0) and (not S.Announced or (NowMs - S.LastAnnounce >= MinSoundGapMs)) then
  begin
    Result.Announce := True;
    S.LastAnnounce := NowMs;
    S.Announced := True;
  end;
  if (Level >= 0) and HasSound then
  begin
    if S.Sounded then
      Since := NowMs - S.LastSound
    else
      Since := High(UInt64);
    if Result.Entered then
      Result.PlaySound := Since >= MinSoundGapMs
    else
      Result.PlaySound := RepeatSound and (Since >= RepeatIntervalMs);
    if Result.PlaySound then
    begin
      S.LastSound := NowMs;
      S.Sounded := True;
    end;
  end;
  FStates.AddOrSetValue(PidId, S);
end;

{ Sounds }

var
  BeepWave, AlarmWave: TBytes;

{ A 16-bit mono PCM WAV built in memory, so the alarm sounds the same on
  every PC regardless of the Windows sound scheme (which may be "No sounds"). }
function MakeWave(const Tones: array of Integer; ToneMs, Repeats: Integer): TBytes;
const
  Rate = 22050;
var
  Samples, PerTone, I, T, R, Pos, Fade: Integer;
  S: SmallInt;
  Amp: Double;
  Stream: TBytesStream;

  procedure W32(V: Cardinal);
  begin
    Stream.WriteBuffer(V, 4);
  end;

  procedure W16(V: Word);
  begin
    Stream.WriteBuffer(V, 2);
  end;

begin
  PerTone := Rate * ToneMs div 1000;
  Samples := PerTone * Length(Tones) * Repeats;
  Fade := Rate div 200; // 5 ms ramps, no clicks
  Stream := TBytesStream.Create;
  try
    Stream.WriteBuffer(AnsiString('RIFF')[1], 4);
    W32(36 + Samples * 2);
    Stream.WriteBuffer(AnsiString('WAVEfmt ')[1], 8);
    W32(16);
    W16(1);         // PCM
    W16(1);         // mono
    W32(Rate);
    W32(Rate * 2);  // bytes per second
    W16(2);         // block align
    W16(16);        // bits per sample
    Stream.WriteBuffer(AnsiString('data')[1], 4);
    W32(Samples * 2);
    for R := 1 to Repeats do
      for T := 0 to High(Tones) do
        for I := 0 to PerTone - 1 do
        begin
          Pos := Min(I, PerTone - 1 - I);
          Amp := 0.45 * Min(1.0, Pos / Fade);
          S := Round(32767 * Amp * Sin(2 * Pi * Tones[T] * I / Rate));
          Stream.WriteBuffer(S, 2);
        end;
    Result := Copy(Stream.Bytes, 0, Stream.Size);
  finally
    Stream.Free;
  end;
end;

function PlayAlertSound(Sound: TAlertSound; const FileName: string): Boolean;
begin
  Result := True;
  case Sound of
    asNone: ;
    asBeep: PlaySound(PChar(@BeepWave[0]), 0, SND_MEMORY or SND_ASYNC or SND_NODEFAULT);
    asAlert: PlaySound('SystemExclamation', 0, SND_ALIAS or SND_ASYNC);
    asAlarm: PlaySound(PChar(@AlarmWave[0]), 0, SND_MEMORY or SND_ASYNC or SND_NODEFAULT);
    asFile:
      Result := FileExists(FileName) and
        PlaySound(PChar(FileName), 0, SND_FILENAME or SND_ASYNC or SND_NODEFAULT);
  end;
end;

procedure StopAlertSound;
begin
  PlaySound(nil, 0, 0);
end;

initialization
  BeepWave := MakeWave([1200, 0], 110, 2);
  AlarmWave := MakeWave([880, 660], 180, 3);

finalization
  StopAlertSound; // the memory waves must outlive any sound still playing

end.
