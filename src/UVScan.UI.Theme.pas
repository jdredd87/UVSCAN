unit UVScan.UI.Theme;

{ Light / dark themes.

  The look of the standard controls comes from Delphi's own FMX styles,
  compiled in as resources (UVScan.StylesWin.rc / UVScan.StylesAndroid.rc):
    Windows  light = Win10Modern,               dark = Win10ModernDark
    Android  light = the platform default style, dark = AndroidDark
  "System" follows the light / dark setting of Windows or the phone.

  UVScan's own painted controls (grid, bars, status strip) take their colours
  from Palette and repaint when TThemeChangedMessage is sent. }

interface

uses
  System.SysUtils, System.UITypes, System.Messaging;

type
  TThemeMode = (tmSystem, tmLight, tmDark);

  TPalette = record
    Dark: Boolean;
    Text: TAlphaColor;          // normal text on Back / Bar
    Muted: TAlphaColor;         // hints, secondary text
    Back: TAlphaColor;          // page background behind painted controls
    Bar: TAlphaColor;           // top bar, tab bar, status strip
    BarLine: TAlphaColor;       // the line between a bar and the page
    Accent: TAlphaColor;        // selected tab, highlights
    Good, Warn, Bad: TAlphaColor; // text colours for ok / warning / error
    NoticeWarn, NoticeError, NoticeText: TAlphaColor;
    Panel: TAlphaColor;         // a tinted panel inside a page
    PanelWarn: TAlphaColor;     // a caution panel
    // data grid
    GridBack, GridAlt, GridText, GridDimText, GridHeader, GridHeaderText, GridLine: TAlphaColor;
    GridSel, GridSelText, GridSelInactive, GridGroup, GridGroupText, GridCheck: TAlphaColor;
  end;

  { Sent (no value) after the theme has changed. }
  TThemeChangedMessage = class(TMessage)
  end;

const
  ThemeKeys: array[TThemeMode] of string = ('system', 'light', 'dark');
  ThemeNames: array[TThemeMode] of string = ('System default', 'Light', 'Dark');

function ThemeModeFromKey(const Key: string): TThemeMode;

{ Applies the style for Mode to every form and sends TThemeChangedMessage. }
procedure ApplyTheme(Mode: TThemeMode);
function CurrentThemeMode: TThemeMode;

{ Colours of the active theme. }
function Palette: TPalette;

implementation

uses
  System.Types, System.Classes, FMX.Types, FMX.Styles, FMX.Platform, FMX.Forms;

var
  GPalette: TPalette;
  GMode: TThemeMode = tmSystem;
  GAppliedDark: Boolean;
  GApplied: Boolean;
  GAppearanceSub: TMessageSubscriptionId;
  GSubscribed: Boolean;

function MakePalette(Dark: Boolean): TPalette;
begin
  Result.Dark := Dark;
  if Dark then
  begin
    Result.Text := $FFE8EAED;
    Result.Muted := $FF9AA0A6;
    Result.Back := $FF202124;
    Result.Bar := $FF2B2D30;
    Result.BarLine := $FF3C4043;
    Result.Accent := $FF6AB0FF;
    Result.Good := $FF7BD88F;
    Result.Warn := $FFFFC66D;
    Result.Bad := $FFFF7B72;
    Result.NoticeWarn := $FF4A3F1C;
    Result.NoticeError := $FF5C2B2B;
    Result.NoticeText := $FFF1F3F4;
    Result.Panel := $FF2B2D30;
    Result.PanelWarn := $FF3D3520;
    Result.GridBack := $FF202124;
    Result.GridAlt := $FF26282B;
    Result.GridText := $FFE8EAED;
    Result.GridDimText := $FF9AA0A6;
    Result.GridHeader := $FF303236;
    Result.GridHeaderText := $FFE8EAED;
    Result.GridLine := $FF3C4043;
    Result.GridSel := $FF2F6FD0;
    Result.GridSelText := $FFFFFFFF;
    Result.GridSelInactive := $FF2E3C50;
    Result.GridGroup := $FF2A3442;
    Result.GridGroupText := $FFAECBFA;
    Result.GridCheck := $FF8AB4F8;
  end
  else
  begin
    Result.Text := $FF1E1E1E;
    Result.Muted := $FF707070;
    Result.Back := $FFFFFFFF;
    Result.Bar := $FFF4F5F7;
    Result.BarLine := $FFDADDE2;
    Result.Accent := $FF0B66D0;
    Result.Good := $FF208020;
    Result.Warn := $FFB06000;
    Result.Bad := $FFC03030;
    Result.NoticeWarn := $FFFFF0C0;
    Result.NoticeError := $FFFFC8C8;
    Result.NoticeText := $FF1E1E1E;
    Result.Panel := $FFF4F6F8;
    Result.PanelWarn := $FFFFF4D6;
    Result.GridBack := $FFFFFFFF;
    Result.GridAlt := $FFF0F3F7;
    Result.GridText := $FF1E1E1E;
    Result.GridDimText := $FF808080;
    Result.GridHeader := $FFE9ECF0;
    Result.GridHeaderText := $FF202020;
    Result.GridLine := $FFDADDE2;
    Result.GridSel := $FF0078D7;
    Result.GridSelText := $FFFFFFFF;
    Result.GridSelInactive := $FFCCE4F7;
    Result.GridGroup := $FFDDE6F0;
    Result.GridGroupText := $FF1F3F66;
    Result.GridCheck := $FF0078D7;
  end;
end;

function ThemeModeFromKey(const Key: string): TThemeMode;
var
  M: TThemeMode;
begin
  for M := Low(TThemeMode) to High(TThemeMode) do
    if SameText(Key, ThemeKeys[M]) then
      Exit(M);
  Result := tmSystem;
end;

function SystemIsDark: Boolean;
var
  Svc: IFMXSystemAppearanceService;
begin
  Result := TPlatformServices.Current.SupportsPlatformService(IFMXSystemAppearanceService, Svc) and
    (Svc.ThemeKind = TSystemThemeKind.Dark);
end;

function LoadStyle(const ResName: string): TFmxObject;
begin
  if FindResource(HInstance, PChar(ResName), RT_RCDATA) = 0 then
    Exit(nil);
  Result := TStyleStreaming.LoadFromResource(HInstance, ResName, RT_RCDATA);
end;

procedure SetDark(Dark: Boolean);
var
  Style: TFmxObject;
begin
  if GApplied and (GAppliedDark = Dark) then
    Exit;
  if Dark then
    Style := LoadStyle('UVSCAN_STYLE_DARK')
  else
    Style := LoadStyle('UVSCAN_STYLE_LIGHT'); // Android: none, the platform default is used
  // nil puts the platform default style back.
  TStyleManager.SetStyle(Style);
  GApplied := True;
  GAppliedDark := Dark;
  GPalette := MakePalette(Dark);
  TMessageManager.DefaultManager.SendMessage(nil, TThemeChangedMessage.Create);
end;

procedure SystemAppearanceChanged(const Sender: TObject; const M: TMessage);
begin
  if GMode = tmSystem then
    TThread.ForceQueue(nil,
      procedure
      begin
        SetDark(SystemIsDark);
      end);
end;

procedure ApplyTheme(Mode: TThemeMode);
begin
  GMode := Mode;
  if not GSubscribed then
  begin
    GAppearanceSub := TMessageManager.DefaultManager.SubscribeToMessage(TSystemAppearanceChangedMessage,
      SystemAppearanceChanged);
    GSubscribed := True;
  end;
  case Mode of
    tmLight: SetDark(False);
    tmDark: SetDark(True);
  else
    SetDark(SystemIsDark);
  end;
end;

function CurrentThemeMode: TThemeMode;
begin
  Result := GMode;
end;

function Palette: TPalette;
begin
  Result := GPalette;
end;

initialization
  GPalette := MakePalette(False);

finalization
  if GSubscribed then
    TMessageManager.DefaultManager.Unsubscribe(TSystemAppearanceChangedMessage, GAppearanceSub);

end.
