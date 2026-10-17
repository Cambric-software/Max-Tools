; Max Tools - Windows installer.
;
; Installs into a versioned layout so the app can update itself later without
; ever overwriting files that Windows has open:
;
;   %LOCALAPPDATA%\Programs\MaxTools\
;     current.txt                  -> "0.1.0"
;     versions\0.1.0\max_tools.exe, flutter_windows.dll, data\
;
; The shortcut deliberately points at the version this installer shipped, not
; at "whatever is newest". When an update lands, that older copy starts first,
; notices current.txt names a newer version, hands over and exits. That is the
; mechanism that keeps a stale shortcut from trapping the user on an old build.
;
; Per-user install (PrivilegesRequired=lowest) so updating never needs admin.

#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef AppExeName
  #define AppExeName "max_tools.exe"
#endif

#define AppPublisher "Cambric Software"
#define AppName "Max Tools"
#define AppId "{{6F2B1C48-9D3E-4A17-8C55-2B7E4D9A1F30}"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
; Must be strictly numeric. The release workflow normalises the tag
; (v0.2.0-beta1 -> 0.2.0) before passing /DAppVersion, because Inno
; rejects a pre-release suffix here and dpkg rejects one in a version too.
VersionInfoVersion={#AppVersion}.0
DefaultDirName={localappdata}\Programs\MaxTools
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=no
OutputDir=..\release-out
OutputBaseFilename=MaxTools-Setup-{#AppVersion}
SetupIconFile=..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\versions\{#AppVersion}\{#AppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Per-user: no elevation prompt, and the app can write its own install
; directory when staging an update.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
UninstallDisplayName={#AppName} {#AppVersion}
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"
Name: "startmenuicon"; Description: "Create a Start menu shortcut"; GroupDescription: "Additional shortcuts:"; Flags: checkedonce

[Files]
; The payload is staged by CI as ..\staging, already shaped as the version dir.
Source: "..\staging\*"; DestDir: "{app}\versions\{#AppVersion}"; Flags: ignoreversion recursesubdirs createallsubdirs
; The pointer that decides which version runs.
Source: "..\staging-current.txt"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
; versions\ is created by the file copy, but ensure it exists first so the
; layout is right even for an empty payload.
Name: "{app}\versions"

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\versions\{#AppVersion}\{#AppExeName}"; WorkingDir: "{app}\versions\{#AppVersion}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\versions\{#AppVersion}\{#AppExeName}"; WorkingDir: "{app}\versions\{#AppVersion}"; Tasks: desktopicon

[Run]
Filename: "{app}\versions\{#AppVersion}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[Code]
{ Remove version folders left behind by updates, keeping the active one. }
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ActiveVersion: String;
  VersionsDir: String;
  Found: TFindRec;
begin
  if CurUninstallStep = usUninstall then
  begin
    VersionsDir := ExpandConstant('{app}\versions');
    ActiveVersion := '';
    if FileExists(ExpandConstant('{app}\current.txt')) then
      ActiveVersion := TrimString(LoadStringFromFile(ExpandConstant('{app}\current.txt')));

    if DirExists(VersionsDir) then
    begin
      if FindFirst(VersionsDir + '\*', Found) then
      try
        repeat
          if (Found.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
          begin
            // Never delete the version we are about to run.
            if (Found.Name <> ActiveVersion) and
               (CompareText(Found.Name, '..') <> 0) and
               (Found.Name <> '.') then
              DelTree(VersionsDir + '\' + Found.Name, True, True, True);
          end;
        until not FindNext(Found);
      finally
        FindClose(Found);
      end;
    end;
  end;
end;