@echo off
::Name - Enhanced Backup Script
::Description - Backs up all user data (favorites, music, signatures, Outlook settings, etc.) to OneDrive with dynamic folder naming.
::Inputs - None
::Outputs - Logs backup operations and errors to OneDrive.

:: Set Paths
SET OneDrivePath=%OneDrive%
SET BackupDir=%OneDrivePath%\Backup-%USERNAME%
SET BackupLog=%BackupDir%\backup-log.txt
SET ErrorLog=%BackupDir%\backup-errorlog.txt

:: Initialize Logs
IF NOT EXIST "%BackupDir%" mkdir "%BackupDir%"
echo Starting Backup: %DATE% %TIME% > "%BackupLog%"
echo Errors will be logged to "%ErrorLog%". > "%ErrorLog%"

:: Function for Folder Backup
:BackupFolder
SET Source=%1
SET Destination=%2
SET Description=%3
echo Backing up %Description%... >> "%BackupLog%"
IF EXIST "%Source%" (
    IF NOT EXIST "%Destination%" mkdir "%Destination%"
    XCOPY "%Source%\*" "%Destination%" /E /Y /C /Z /D >> "%BackupLog%" 2>> "%ErrorLog%"
) ELSE (
    echo WARNING: %Description% source "%Source%" not found. >> "%ErrorLog%"
)
GOTO :EOF

:: Function for Registry Export
:BackupRegistry
SET RegPath=%1
SET RegFile=%2
SET Description=%3
echo Exporting %Description% Registry... >> "%BackupLog%"
reg export "%RegPath%" "%RegFile%" /y >> "%BackupLog%" 2>> "%ErrorLog%"
GOTO :EOF

:: Perform Backups
CALL :BackupFolder "%USERPROFILE%\Desktop" "%BackupDir%\Desktop" "Desktop"
CALL :BackupFolder "%USERPROFILE%\Music" "%BackupDir%\Music" "Music"
CALL :BackupFolder "%USERPROFILE%\Documents" "%BackupDir%\Documents" "Documents"
CALL :BackupFolder "%APPDATA%\Microsoft\Signatures" "%BackupDir%\Signatures" "Signatures"
CALL :BackupFolder "%LOCALAPPDATA%\Microsoft\Outlook\RoamCache" "%BackupDir%\OutlookRoam" "Outlook RoamCache"
CALL :BackupFolder "%USERPROFILE%\Favorites" "%BackupDir%\Favorites" "Favorites"
CALL :BackupFolder "%USERPROFILE%\Links" "%BackupDir%\Links" "Links"
CALL :BackupFolder "%APPDATA%\Microsoft\Excel\XLStart" "%BackupDir%\ExcelXLStart" "Excel XLStart"
CALL :BackupFolder "%APPDATA%\Microsoft\Word\STARTUP" "%BackupDir%\WordStartup" "Word Startup"
CALL :BackupFolder "%LOCALAPPDATA%\Microsoft\Office" "%BackupDir%\OfficeUI" "Office UI Settings"
CALL :BackupFolder "%APPDATA%\Microsoft\Sticky Notes" "%BackupDir%\StickyNotes" "Sticky Notes"
CALL :BackupFolder "%LOCALAPPDATA%\Google\Chrome\User Data\Default" "%BackupDir%\ChromeBookmarks" "Chrome Bookmarks"

:: Export Registry for Taskbar
CALL :BackupRegistry "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" "%BackupDir%\TaskbarRegistry.reg" "Taskbar Configuration"

:: Log Mapped Drives
echo Logging Mapped Drives... >> "%BackupLog%"
net use >> "%BackupLog%" 2>> "%ErrorLog%"

:: Finalize Backup
echo Backup Completed Successfully: %DATE% %TIME% >> "%BackupLog%"
echo Backup operation completed! Logs saved to "%BackupLog%" and "%ErrorLog%".
pause
