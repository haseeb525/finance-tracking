@echo off
title Finance Tracker Installer
color 0A

echo.
echo ========================================
echo Finance Tracker - Installation Wizard
echo ========================================
echo.

REM Check if running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Administrator privileges required!
    echo Please run this installer as Administrator.
    pause
    exit /b 1
)

REM Create installation directory
set INSTALL_DIR=%ProgramFiles%\Finance Tracker
echo Creating installation directory...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM Copy application files
echo Copying application files...
xcopy /E /I /Y "build\windows\x64\runner\Release\*" "%INSTALL_DIR%\" >nul

REM Create Desktop Shortcut
echo Creating shortcuts...
powershell -Command ^
  "$WshShell = New-Object -ComObject WScript.Shell; " ^
  "$Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\Finance Tracker.lnk'); " ^
  "$Shortcut.TargetPath = '%INSTALL_DIR%\finance_tracking.exe'; " ^
  "$Shortcut.WorkingDirectory = '%INSTALL_DIR%'; " ^
  "$Shortcut.Save()"

REM Create Start Menu Shortcut
powershell -Command ^
  "$WshShell = New-Object -ComObject WScript.Shell; " ^
  "$Shortcut = $WshShell.CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Finance Tracker.lnk'); " ^
  "$Shortcut.TargetPath = '%INSTALL_DIR%\finance_tracking.exe'; " ^
  "$Shortcut.WorkingDirectory = '%INSTALL_DIR%'; " ^
  "$Shortcut.Save()"

REM Add to Registry for uninstall
echo Registering application...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\FinanceTracker" /v DisplayName /d "Finance Tracker" /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\FinanceTracker" /v InstallLocation /d "%INSTALL_DIR%" /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\FinanceTracker" /v DisplayVersion /d "1.0.0" /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\FinanceTracker" /v UninstallString /d "%INSTALL_DIR%\uninstall.bat" /f >nul

REM Create uninstaller script
echo Creating uninstaller...
(
  echo @echo off
  echo echo Uninstalling Finance Tracker...
  echo rmdir /s /q "%INSTALL_DIR%"
  echo del /f /q "%%USERPROFILE%%\Desktop\Finance Tracker.lnk"
  echo del /f /q "%%APPDATA%%\Microsoft\Windows\Start Menu\Programs\Finance Tracker.lnk"
  echo reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\FinanceTracker" /f
  echo echo Finance Tracker has been uninstalled.
  echo pause
) > "%INSTALL_DIR%\uninstall.bat"

echo.
echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo Finance Tracker has been installed to:
echo %INSTALL_DIR%
echo.
echo Shortcuts created:
echo - Desktop shortcut
echo - Start Menu shortcut
echo.
pause
