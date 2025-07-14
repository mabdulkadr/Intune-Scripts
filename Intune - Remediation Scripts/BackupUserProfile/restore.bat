@echo off
::Name - Complete Restore Script
::Description - Restores all user files and settings from the "Backup-%USERNAME%" folder in OneDrive.
::Inputs - None
::Outputs - Logs restore operations and errors to OneDrive.

:: Set Paths
SET OneDrivePath=%OneDrive%
SET BackupDir=%OneDrivePath%\Backup-%USERNAME%
SET RestoreLog=%BackupDir%\restore-log.txt
SET ErrorLog=%BackupDir%\restore-errorlog.txt

:: Initialize Logs
IF NOT EXIST "%BackupDir%" (
    echo ERROR: Backup directory "%BackupDir%" not found. >> "%ErrorLog%"
    echo Restore operation failed. Check "%ErrorLog%".
    exit /b
)
echo Starting Full Restore: %DATE% %TIME% > "%RestoreLog%"
echo Errors will be logged to "%ErrorLog%". > "%ErrorLog%"

:: Function for Folder Restore
:RestoreFolder
SET Source=%1
SET Destination=%2
SET Description=%3
echo Restoring %Description% to "%Destination%" >> "%RestoreLog%"
IF EXIST "%Source%" (
    XCOPY "%Source%\*" "%Destination%\" /E /Y /C /Z /D >> "%RestoreLog%" 2>> "%ErrorLog%"
) ELSE (
    echo WARNING: %Description% source "%Source%" not found. >> "%ErrorLog%"
)
GOTO :EOF

:: Function for Registry Import
:RestoreRegistry
SET RegFile=%1
SET Description=%2
echo Importing %Description% Registry... >> "%RestoreLog%"
IF EXIST "%RegFile%" (
    reg import "%RegFile%" >> "%RestoreLog%" 2>> "%ErrorLog%"
) ELSE (
    echo WARNING: Registry file "%RegFile%" not found. >> "%ErrorLog%"
)
GOTO :EOF

:: Restore Key Folders
CALL :RestoreFolder "%BackupDir%\Desktop" "%USERPROFILE%\Desktop" "Desktop"
CALL :RestoreFolder "%BackupDir%\Documents" "%USERPROFILE%\Documents" "Documents"
CALL :RestoreFolder "%BackupDir%\Music" "%USERPROFILE%\Music" "Music"
CALL :RestoreFolder "%BackupDir%\Favorites" "%USERPROFILE%\Favorites" "Favorites"
CALL :RestoreFolder "%BackupDir%\Links" "%USERPROFILE%\Links" "Links"
CALL :RestoreFolder "%BackupDir%\Signatures" "%APPDATA%\Microsoft\Signatures" "Signatures"
CALL :RestoreFolder "%BackupDir%\OutlookRoamCache" "%LOCALAPPDATA%\Microsoft\Outlook\RoamCache" "Outlook RoamCache"
CALL :RestoreFolder "%BackupDir%\WordStartup" "%APPDATA%\Microsoft\Word\STARTUP" "Word Startup"
CALL :RestoreFolder "%BackupDir%\ExcelXLStart" "%APPDATA%\Microsoft\Excel\XLStart" "Excel XLStart"
CALL :RestoreFolder "%BackupDir%\StickyNotes" "%APPDATA%\Microsoft\Sticky Notes" "Sticky Notes"
CALL :RestoreFolder "%BackupDir%\ChromeBookmarks" "%LOCALAPPDATA%\Google\Chrome\User Data\Default" "Chrome Bookmarks"
CALL :RestoreFolder "%BackupDir%\OfficeUI" "%LOCALAPPDATA%\Microsoft\Office" "Office UI"

:: Restore Registry for Taskbar
CALL :RestoreRegistry "%BackupDir%\TaskbarConfig.reg" "Taskbar Configuration"

:: Finalize
echo Restore Completed Successfully: %DATE% %TIME% >> "%RestoreLog%"
echo All files and settings have been restored from "%BackupDir%".
pause
