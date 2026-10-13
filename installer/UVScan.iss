; UVScan for Windows: the setup program, built with Inno Setup 6 (ISCC).
; Build it with "build installer", which compiles UVScan (Win32 Release) and
; passes the version: /DAppVersion=2.0.0 /DBuildNumber=99 /DBuildCommit=abc1234
; Output: installer\Output\UVScan-<version>-build<n>-setup.exe
;
; Installs for the current user (no admin) or, chosen in the first dialog,
; for all users in Program Files. The data in C:\ProgramData\UVScan and the
; logs in Documents\UVScan Logs are kept when UVScan is uninstalled.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef BuildNumber
  #define BuildNumber "0"
#endif
#ifndef BuildCommit
  #define BuildCommit "unknown"
#endif
#ifndef ExeDir
  #define ExeDir "..\Win32\Release"
#endif

[Setup]
AppId={{045C9E6B-1521-43E0-BD60-FA0E461B7C5B}
AppName=UVScan
AppVersion={#AppVersion} (build {#BuildNumber})
AppVerName=UVScan {#AppVersion} (build {#BuildNumber})
VersionInfoVersion={#AppVersion}.{#BuildNumber}
VersionInfoDescription=UVScan setup
AppPublisher=StevenC
AppPublisherURL=https://github.com/jdredd87/UVSCAN
AppSupportURL=https://github.com/jdredd87/UVSCAN/issues
AppComments=GM Class 2 (J1850 VPW) scan tool, build {#BuildNumber} ({#BuildCommit})
DefaultDirName={autopf}\UVScan
DefaultGroupName=UVScan
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\UVScan.exe
UninstallDisplayName=UVScan {#AppVersion}
OutputDir=Output
OutputBaseFilename=UVScan-{#AppVersion}-build{#BuildNumber}-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#ExeDir}\UVScan.exe"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
; Installed for all users: every user can change the shared data
Name: "{commonappdata}\UVScan"; Permissions: users-modify; Flags: uninsneveruninstall; Check: IsAdminInstallMode

[Icons]
Name: "{autoprograms}\UVScan"; Filename: "{app}\UVScan.exe"
Name: "{autodesktop}\UVScan"; Filename: "{app}\UVScan.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\UVScan.exe"; Description: "{cm:LaunchProgram,UVScan}"; Flags: nowait postinstall skipifsilent
