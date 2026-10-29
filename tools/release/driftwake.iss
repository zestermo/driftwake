; Driftwake's Windows installer (Inno Setup 6; CI builds it: build-windows.yml). Installs the exported game
; (build/windows: Driftwake.exe, Driftwake.pck, the native library, READ ME FIRST) for the current user, no admin:
; %LOCALAPPDATA%\Programs\Driftwake, with Start menu and (optional) desktop shortcuts and an uninstaller. Saves and
; downloaded updates live in the user folder (%APPDATA%\Godot\app_userdata\Driftwake), so they survive reinstalls.
; A newer installer installs over an older one (same AppId). Usage: ISCC /DVersion=1.26 /DSrc=build\windows driftwake.iss

#ifndef Version
  #define Version "0.0"
#endif
#ifndef Src
  #define Src "..\..\build\windows"
#endif

[Setup]
AppId={{6E2B7C3A-4D1F-4B8E-9C2D-5A1F7E0D2C01}
AppName=Driftwake
AppVersion={#Version}
AppPublisher=Zilk
AppPublisherURL=https://driftwake.fun
AppSupportURL=https://driftwake.fun
DefaultDirName={localappdata}\Programs\Driftwake
DefaultGroupName=Driftwake
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\build
OutputBaseFilename=Driftwake-Setup
SetupIconFile=..\..\assets\branding\icon.ico
UninstallDisplayIcon={app}\Driftwake.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "{#Src}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{autoprograms}\Driftwake"; Filename: "{app}\Driftwake.exe"
Name: "{autodesktop}\Driftwake"; Filename: "{app}\Driftwake.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Driftwake.exe"; Description: "Play Driftwake"; Flags: nowait postinstall skipifsilent
