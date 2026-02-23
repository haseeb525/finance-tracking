[Setup]
AppName=Finance Tracker
AppVersion=1.0.0
AppPublisher=Your Company
AppPublisherURL=
AppSupportURL=
AppUpdatesURL=
DefaultDirName={pf}\Finance Tracker
DefaultGroupName=Finance Tracker
AllowNoIcons=yes
LicenseFile=
OutputDir=installer_output
OutputBaseFilename=Finance_Tracker_Installer_v1.0.0
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 0,6.1

[Files]
Source: "build\windows\x64\runner\Release\finance_tracking.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Finance Tracker"; Filename: "{app}\finance_tracking.exe"
Name: "{group}\{cm:UninstallProgram,Finance Tracker}"; Filename: "{uninstallexe}"
Name: "{desktop}\Finance Tracker"; Filename: "{app}\finance_tracking.exe"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\Finance Tracker"; Filename: "{app}\finance_tracking.exe"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\finance_tracking.exe"; Description: "{cm:LaunchProgram,Finance Tracker}"; Flags: nowait postinstall skipifsilent
