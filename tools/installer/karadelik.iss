; Karadelik IPTV Player: per-user Windows installer (no admin rights).
;
; Built by tools\release.ps1:
;   ISCC /DAppVersion=0.2.0 [/DBuildDir=...] [/DUseSign /Skpsign="..."] karadelik.iss
;
; The in-app updater runs this silently with /LAUNCH=1, which reopens the app
; once the files are replaced. Uninstalling keeps the user's library
; (%APPDATA%\karadelik\Karadelik IPTV Player) and keyring entries.

#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\..\apps\player\build\windows\x64\runner\Release"
#endif
#define AppName "Karadelik IPTV Player"
#define AppExe "karadelik_player.exe"

[Setup]
; Never change AppId: it is how Windows and updates recognise the app.
AppId={{4CBA0252-5EC2-46A4-8837-CA9BF5104C3B}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Karadelik
VersionInfoVersion={#AppVersion}
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
DisableDirPage=auto
OutputDir=..\..\dist
OutputBaseFilename=KaradelikIPTVPlayer-Setup-{#AppVersion}
SetupIconFile=..\..\apps\player\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Updates replace files of a running app: close it (the updater has already
; quit, this covers a second window or a manual install).
CloseApplications=force
RestartApplications=no
#ifdef UseSign
SignTool=kpsign $f
SignedUninstaller=yes
#endif

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
turkish.LaunchApp=Karadelik IPTV Player'ı aç
english.LaunchApp=Open Karadelik IPTV Player

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Excludes: "perf.jsonl,*.pdb"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; Interactive install: offer to open the app.
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchApp}"; Flags: nowait postinstall skipifsilent
; Silent update from the app (/LAUNCH=1): reopen it.
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: LaunchAfterUpdate

[UninstallDelete]
Type: files; Name: "{app}\perf.jsonl"

[Code]
function LaunchAfterUpdate: Boolean;
begin
  Result := WizardSilent and (ExpandConstant('{param:LAUNCH|0}') = '1');
end;
