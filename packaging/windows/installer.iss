; Inno Setup script for the Windows installer. CI passes the version and paths:
;   iscc /DAppVersion=1.2.3 /DSourceDir=<Release folder> /DOutputDir=<dir>
;        /DOutputName=<file name without .exe> packaging\windows\installer.iss
;
; Installs per user (no admin prompt) into %LOCALAPPDATA%\Programs\WorkNexus:
; the in-app updater replaces the files in place, which a Program Files
; install would not allow without elevation.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Fixed GUID — must never change, or Windows treats a new version as a
; different app instead of an upgrade.
AppId={{6F4C2A71-8D0E-4B3A-9E57-3C1D2B9A7F10}
AppName=WorkNexus
AppVersion={#AppVersion}
AppPublisher=WorkNexus
DefaultDirName={localappdata}\Programs\WorkNexus
DefaultGroupName=WorkNexus
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\WorkNexus.exe
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Close a running WorkNexus before replacing its files.
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\WorkNexus"; Filename: "{app}\WorkNexus.exe"
Name: "{autodesktop}\WorkNexus"; Filename: "{app}\WorkNexus.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\WorkNexus.exe"; Description: "{cm:LaunchProgram,WorkNexus}"; Flags: nowait postinstall skipifsilent
