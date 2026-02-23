; Finance Tracker Windows Installer
; Generated for NSIS 3.x

!include "MUI2.nsh"
!include "x64.nsh"

; === BASIC SETTINGS ===
Name "Finance Tracker"
OutFile "Finance_Tracker_Installer_v1.0.0.exe"
InstallDir "$PROGRAMFILES\Finance Tracker"

; Request admin privileges
RequestExecutionLevel admin

; Default installation folder
InstallDirRegKey HKCU "Software\Finance Tracker" ""

; === MUI SETTINGS ===
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

; === INSTALLER SECTIONS ===
Section "Install"
  SetOutPath "$INSTDIR"
  
  ; Copy main executable
  File "build\windows\x64\runner\Release\finance_tracking.exe"
  
  ; Copy runtime files
  File /r "build\windows\x64\runner\Release\*"
  
  ; Create shortcuts
  CreateShortcut "$SMPROGRAMS\Finance Tracker.lnk" "$INSTDIR\finance_tracking.exe"
  CreateShortcut "$DESKTOP\Finance Tracker.lnk" "$INSTDIR\finance_tracking.exe"
  
  ; Store installation folder in registry
  WriteRegStr HKCU "Software\Finance Tracker" "" $INSTDIR
  
  ; Create uninstaller
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FinanceTracker" \
    "DisplayName" "Finance Tracker - Personal Finance Management"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FinanceTracker" \
    "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FinanceTracker" \
    "DisplayVersion" "1.0.0"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FinanceTracker" \
    "Publisher" "Your Company Name"
  
  WriteUninstaller "$INSTDIR\uninstall.exe"
  
  ; Show completion message
  MessageBox MB_OK "Finance Tracker has been installed successfully!"
SectionEnd

; === UNINSTALLER ===
Section "Uninstall"
  ; Delete shortcuts
  Delete "$SMPROGRAMS\Finance Tracker.lnk"
  Delete "$DESKTOP\Finance Tracker.lnk"
  
  ; Delete app files
  RMDir /r "$INSTDIR"
  
  ; Delete registry entries
  DeleteRegKey HKCU "Software\Finance Tracker"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FinanceTracker"
  
  MessageBox MB_OK "Finance Tracker has been uninstalled."
SectionEnd
