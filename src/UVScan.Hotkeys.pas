unit UVScan.Hotkeys;

{ Keys for the main actions (Settings > Hotkeys), to press without looking,
  on a drive say.

  Only keys that never type into a text box can be one: F1-F24, Pause,
  Scroll Lock and the media keys (with or without Ctrl, Alt, Shift), and a
  letter or digit with Ctrl or Alt (not both: that is AltGr on many
  keyboards, which types). Not the ones text boxes or UVScan already use:
  Ctrl+A/C/V/X/Y/Z, Ctrl+L, Ctrl+0, Alt+F4.

  Stored as text: "F5", "Ctrl+G", "Shift+F12", "Play/Pause"; '' = none. }

interface

uses
  System.SysUtils, System.Classes, System.UITypes;

type
  THotkeyAction = (haConnect, haScan, haLogViewer, haLog, haPause, haMark, haFullScreen, haLiveChart);

  THotkey = record
    Key: Word;           // 0 = none
    Shift: TShiftState;  // ssShift, ssCtrl, ssAlt only
    class function Make(AKey: Word; AShift: TShiftState): THotkey; static;
    { '' or a key it cannot read: none. }
    class function Parse(const S: string): THotkey; static;
    function IsEmpty: Boolean;
    function Text: string;
    function Matches(AKey: Word; AShift: TShiftState): Boolean;
  end;

  THotkeys = array[THotkeyAction] of THotkey;

const
  HotkeyNames: array[THotkeyAction] of string = ('Connect / Disconnect', 'Start / Stop scan',
    'Open the log viewer', 'Start / Stop log', 'Pause / Resume the log', 'Mark this moment in the log',
    'Full screen', 'Live grid / live chart');
  HotkeyIds: array[THotkeyAction] of string = ('connect', 'scan', 'logViewer', 'log', 'pause', 'mark',
    'fullScreen', 'liveChart'); // settings.json

function DefaultHotkeys: THotkeys;
{ '' when Key with Shift can be a hotkey, else why not. }
function HotkeyProblem(Key: Word; Shift: TShiftState): string;
{ The action that has Key with Shift; False when none has. }
function FindHotkey(const Keys: THotkeys; Key: Word; Shift: TShiftState; out Action: THotkeyAction): Boolean;
{ A modifier on its own (Shift, Ctrl, Alt, Windows): wait for the key. }
function IsModifierKey(Key: Word): Boolean;

implementation

const
  Mods = [ssShift, ssCtrl, ssAlt];
  // (not every Delphi version names these)
  KeyPause = $13;
  KeyScroll = $91;
  KeyMediaNext = $B0;
  KeyMediaPrev = $B1;
  KeyMediaStop = $B2;
  KeyMediaPlay = $B3;
  OtherKeys: array[0..5] of Word = (KeyPause, KeyScroll, KeyMediaPlay, KeyMediaNext, KeyMediaPrev, KeyMediaStop);
  OtherNames: array[0..5] of string = ('Pause', 'Scroll Lock', 'Play/Pause', 'Next track', 'Previous track',
    'Stop media');

function IsFKey(Key: Word): Boolean;
begin
  Result := (Key >= vkF1) and (Key <= vkF24);
end;

function IsLetterOrDigit(Key: Word): Boolean;
begin
  Result := ((Key >= vkA) and (Key <= vkZ)) or ((Key >= vk0) and (Key <= vk9));
end;

function OtherIndex(Key: Word): Integer;
begin
  for Result := 0 to High(OtherKeys) do
    if OtherKeys[Result] = Key then
      Exit;
  Result := -1;
end;

function KeyName(Key: Word): string;
begin
  if IsFKey(Key) then
    Result := 'F' + IntToStr(Key - vkF1 + 1)
  else if IsLetterOrDigit(Key) then
    Result := Char(Key)
  else if OtherIndex(Key) >= 0 then
    Result := OtherNames[OtherIndex(Key)]
  else
    Result := '';
end;

function IsModifierKey(Key: Word): Boolean;
begin
  Result := (Key = vkShift) or (Key = vkControl) or (Key = vkMenu) or (Key = vkLShift) or
    (Key = vkRShift) or (Key = vkLControl) or (Key = vkRControl) or (Key = vkLMenu) or (Key = vkRMenu) or
    (Key = vkLWin) or (Key = vkRWin);
end;

{ THotkey }

class function THotkey.Make(AKey: Word; AShift: TShiftState): THotkey;
begin
  Result.Key := AKey;
  Result.Shift := AShift * Mods;
end;

class function THotkey.Parse(const S: string): THotkey;
var
  Parts: TArray<string>;
  P: string;
  K: Word;
  I: Integer;
begin
  Result := Make(0, []);
  Parts := Trim(S).Split(['+']);
  if Length(Parts) = 0 then
    Exit;
  for I := 0 to High(Parts) - 1 do
  begin
    P := Trim(Parts[I]);
    if SameText(P, 'Ctrl') then
      Include(Result.Shift, ssCtrl)
    else if SameText(P, 'Alt') then
      Include(Result.Shift, ssAlt)
    else if SameText(P, 'Shift') then
      Include(Result.Shift, ssShift)
    else
      Exit(Make(0, []));
  end;
  P := Trim(Parts[High(Parts)]);
  for K := vkF1 to vkF24 do
    if SameText(P, KeyName(K)) then
      Result.Key := K;
  if (Length(P) = 1) and CharInSet(UpCase(P[1]), ['A'..'Z', '0'..'9']) then
    Result.Key := Ord(UpCase(P[1]));
  for I := 0 to High(OtherNames) do
    if SameText(P, OtherNames[I]) then
      Result.Key := OtherKeys[I];
  if (Result.Key = 0) or (HotkeyProblem(Result.Key, Result.Shift) <> '') then
    Result := Make(0, []);
end;

function THotkey.IsEmpty: Boolean;
begin
  Result := Key = 0;
end;

function THotkey.Text: string;
begin
  if Key = 0 then
    Exit('');
  Result := '';
  if ssCtrl in Shift then
    Result := Result + 'Ctrl+';
  if ssAlt in Shift then
    Result := Result + 'Alt+';
  if ssShift in Shift then
    Result := Result + 'Shift+';
  Result := Result + KeyName(Key);
end;

function THotkey.Matches(AKey: Word; AShift: TShiftState): Boolean;
begin
  Result := (Key <> 0) and (AKey = Key) and (AShift * Mods = Shift);
end;

function DefaultHotkeys: THotkeys;
begin
  Result[haConnect] := THotkey.Make(vkF5, []);
  Result[haScan] := THotkey.Make(vkF6, []);
  Result[haLogViewer] := THotkey.Make(vkF7, []);
  Result[haLog] := THotkey.Make(vkF8, []);
  Result[haPause] := THotkey.Make(vkF9, []);
  Result[haMark] := THotkey.Make(vkF12, []);
  Result[haFullScreen] := THotkey.Make(vkF11, []);
  Result[haLiveChart] := THotkey.Make(vkG, [ssCtrl]);
end;

function HotkeyProblem(Key: Word; Shift: TShiftState): string;
var
  M: TShiftState;
begin
  Result := '';
  M := Shift * Mods;
  if IsFKey(Key) then
  begin
    if (Key = vkF4) and (M = [ssAlt]) then
      Result := 'Alt+F4 closes the window';
  end
  else if IsLetterOrDigit(Key) then
  begin
    if M * [ssCtrl, ssAlt] = [] then
      Result := 'A letter or digit on its own types: use it with Ctrl or Alt'
    else if M * [ssCtrl, ssAlt] = [ssCtrl, ssAlt] then
      Result := 'Ctrl+Alt types characters on many keyboards (AltGr): use Ctrl or Alt'
    else if (ssCtrl in M) and CharInSet(Char(Key), ['A', 'C', 'V', 'X', 'Y', 'Z']) then
      Result := 'Text boxes use Ctrl+' + Char(Key)
    else if (M = [ssCtrl]) and (Key = vkL) then
      Result := 'Ctrl+L shows and hides the PID list'
    else if (ssCtrl in M) and (Key = vk0) then
      Result := 'Ctrl+0 sets the live grid''s zoom back to 100%';
  end
  else if OtherIndex(Key) < 0 then
    Result := 'Use an F key, or Ctrl or Alt with a letter or digit';
end;

function FindHotkey(const Keys: THotkeys; Key: Word; Shift: TShiftState; out Action: THotkeyAction): Boolean;
var
  A: THotkeyAction;
begin
  for A := Low(THotkeyAction) to High(THotkeyAction) do
    if Keys[A].Matches(Key, Shift) then
    begin
      Action := A;
      Exit(True);
    end;
  Result := False;
end;

end.
