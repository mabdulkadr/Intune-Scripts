@echo off
::Name - Consolidated Backup Script
::Description - Backs up files (Desktop, Documents, Outlook, etc.) to a dynamically named folder "Backup-%USERNAME%" on OneDrive.
::Inputs - None
::Outputs - Logs backup results to a log file.

:: Set Dynamic Backup Folder
SET OneDrivePath=%OneDrive%
SET BackupDir=%OneDrivePath%\Backup-%USERNAME%
SET LogFile=%BackupDir%\BackupLog.txt

:: Create Backup Directory and Log File
IF NOT EXIST "%BackupDir%" mkdir "%BackupDir%"
echo Starting Backup: %DATE% %TIME% > "%LogFile%"

:: Function to Backup Folders
:BackupFolder
SET Source=%1
SET Destination=%BackupDir%\%2
echo Backing up "%Source%" to "%Destination%" >> "%LogFile%"
IF EXIST "%Source%" (
    IF NOT EXIST "%Destination%" mkdir "%Destination%"
    XCOPY "%Source%\*" "%Destination%" /E /Y /C /Z /D >> "%LogFile%" 2>&1
) ELSE (
    echo WARNING: Source "%Source%" not found. Skipping. >> "%LogFile%"
)
GOTO :EOF

:: Function to Export Registry Keys
:BackupRegistry
SET RegPath=%1
SET OutputFile=%BackupDir%\%2
echo Exporting Registry "%RegPath%" to "%OutputFile%" >> "%LogFile%"
reg export "%RegPath%" "%OutputFile%" /y >> "%LogFile%" 2>&1
GOTO :EOF

:: Perform Backups
CALL :BackupFolder "%USERPROFILE%\Desktop" "Desktop"
CALL :BackupFolder "%USERPROFILE%\Music" "Music"
CALL :BackupFolder "%USERPROFILE%\Documents" "Documents"
CALL :BackupFolder "%APPDATA%\Microsoft\Signatures" "Signatures"
CALL :BackupFolder "%LOCALAPPDATA%\Microsoft\Outlook\RoamCache" "OutlookRoamCache"
CALL :BackupFolder "%APPDATA%\Microsoft\Word\STARTUP" "WordStartup"
CALL :BackupFolder "%APPDATA%\Microsoft\Excel\XLStart" "ExcelXLStart"
CALL :BackupFolder "%USERPROFILE%\Favorites" "Favorites"
CALL :BackupFolder "%USERPROFILE%\Links" "Links"
CALL :BackupFolder "%APPDATA%\Microsoft\Sticky Notes" "StickyNotes"
CALL :BackupFolder "%LOCALAPPDATA%\Google\Chrome\User Data\Default" "ChromeBookmarks"

:: Export Registry Keys (Taskbar Items)
CALL :BackupRegistry "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" "TaskbarRegistry.reg"

:: Log Mapped Drives
echo Logging Mapped Drives >> "%LogFile%"
net use >> "%LogFile%" 2>&1

:: Finalize Backup
echo Backup Completed Successfully at %DATE% %TIME% >> "%LogFile%"
echo Backup operation finished! Logs saved to "%LogFile%"
pause
