<#
.SYNOPSIS
    Remediation Script to clean up various temporary and cache files on the system.

.DESCRIPTION
    This script performs the following actions:
    1. Clears the Windows Temp folder.
    2. Clears User Temp folders.
    3. Clears Internet Explorer cache.
    4. Clears Windows Update cache.
    5. Clears Windows Error Reporting files.
    6. Clears the Recycle Bin.
    7. Cleans up other known temporary locations.
    8. Clears cache files specific to browsers (Chrome, Edge, Firefox, Waterfox).
    9. Clears cache files specific to communication platforms (Teams).

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-14
#>

#------------------------------------------------------------------#
#- Initialize Logging                                              #
#------------------------------------------------------------------#

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = "C:\Intune\SystemCleanup_$timestamp.log"

function Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Write-Output $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

#------------------------------------------------------------------#
#- Function to delete files and directories                        #
#------------------------------------------------------------------#

function Remove-ItemSafe {
    param (
        [string]$Path
    )
    try {
        Get-ChildItem -Path $Path -Recurse -Force -ErrorAction Stop | ForEach-Object {
            try {
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction Stop
                Log "Deleted: $($_.FullName)"
            } catch {
                Log "Failed to delete: $($_.FullName) - $_"
            }
        }
    } catch {
        Log "Failed to access path: $Path - $_"
    }
}

#------------------------------------------------------------------#
#- Clear Windows Temp folder                                       #
#------------------------------------------------------------------#

$tempFolder = "$env:windir\Temp\*"
Log "Clearing Windows Temp folder: $tempFolder"
Remove-ItemSafe -Path $tempFolder

#------------------------------------------------------------------#
#- Clear User Temp folders                                         #
#------------------------------------------------------------------#

$userTempFolder = "$env:temp\*"
Log "Clearing User Temp folder: $userTempFolder"
Remove-ItemSafe -Path $userTempFolder

#------------------------------------------------------------------#
#- Clear Internet Explorer cache                                   #
#------------------------------------------------------------------#

$ieCacheFolders = @(
    "$env:userprofile\AppData\Local\Microsoft\Windows\INetCache\*",
    "$env:userprofile\AppData\Local\Microsoft\Windows\Temporary Internet Files\*"
)
foreach ($folder in $ieCacheFolders) {
    Log "Clearing Internet Explorer cache folder: $folder"
    Remove-ItemSafe -Path $folder
}

#------------------------------------------------------------------#
#- Clear Windows Update cache                                      #
#------------------------------------------------------------------#

$windowsUpdateCache = "$env:windir\SoftwareDistribution\Download\*"
Log "Clearing Windows Update cache: $windowsUpdateCache"
Remove-ItemSafe -Path $windowsUpdateCache

#------------------------------------------------------------------#
#- Clear Windows Error Reporting files                             #
#------------------------------------------------------------------#

$werFiles = "$env:localappdata\CrashDumps\*"
Log "Clearing Windows Error Reporting files: $werFiles"
Remove-ItemSafe -Path $werFiles

#------------------------------------------------------------------#
#- Clear Recycle Bin                                               #
#------------------------------------------------------------------#

function Clear-RecycleBin {
    $shell = New-Object -ComObject Shell.Application
    $recycleBin = $shell.NameSpace(0xA)
    $recycleBin.Items() | ForEach-Object { $_.InvokeVerb("delete") }
    Log "Recycle Bin Cleared"
}
Log "Clearing Recycle Bin"
Clear-RecycleBin

#------------------------------------------------------------------#
#- Clean up other known temporary locations                        #
#------------------------------------------------------------------#

$otherTempFolders = @(
    "$env:userprofile\AppData\Local\Temp\*",
    "$env:userprofile\AppData\Local\Microsoft\Windows\Explorer\*",
    "$env:userprofile\AppData\Local\Microsoft\Windows\Caches\*"
)
foreach ($folder in $otherTempFolders) {
    Log "Clearing other temp folder: $folder"
    Remove-ItemSafe -Path $folder
}

Log "System cleanup completed."

#------------------------------------------------------------------#
#- Create a completion file                                        #
#------------------------------------------------------------------#

$completionFilePath = "C:\Intune\SystemCleanup.txt"
if (-not (Test-Path $completionFilePath)) {
    New-Item -Path $completionFilePath -ItemType File -Value "System cleanup completed."
    Log "Created completion file: $completionFilePath"
}

#------------------------------------------------------------------#
#- Clear-GlobalWindowsCache                                        #
#------------------------------------------------------------------#

Function Clear-GlobalWindowsCache {
    Remove-CacheFiles 'C:\Windows\Temp' 
    Remove-CacheFiles "C:\`$Recycle.Bin"
    Remove-CacheFiles "C:\Windows\Prefetch"
    C:\Windows\System32\rundll32.exe InetCpl.cpl, ClearMyTracksByProcess 255
    C:\Windows\System32\rundll32.exe InetCpl.cpl, ClearMyTracksByProcess 4351
    Log "Cleared Global Windows Cache"
}

#------------------------------------------------------------------#
#- Clear-UserCacheFiles                                            #
#------------------------------------------------------------------#

Function Clear-UserCacheFiles {
    # Stop-BrowserSessions
    ForEach($localUser in (Get-ChildItem 'C:\users').Name) {
        Clear-ChromeCache $localUser
        Clear-EdgeCacheFiles $localUser
        Clear-FirefoxCacheFiles $localUser
        Clear-WindowsUserCacheFiles $localUser
        Clear-TeamsCacheFiles $localUser
    }
    Log "Cleared User Cache Files"
}

#------------------------------------------------------------------#
#- Clear-WindowsUserCacheFiles                                     #
#------------------------------------------------------------------#

Function Clear-WindowsUserCacheFiles {
    param([string]$user=$env:USERNAME)
    Remove-CacheFiles "C:\Users\$user\AppData\Local\Temp"
    Remove-CacheFiles "C:\Users\$user\AppData\Local\Microsoft\Windows\WER"
    Remove-CacheFiles "C:\Users\$user\AppData\Local\Microsoft\Windows\INetCache"
    Remove-CacheFiles "C:\Users\$user\AppData\Local\Microsoft\Windows\INetCookies"
    Remove-CacheFiles "C:\Users\$user\AppData\Local\Microsoft\Windows\IECompatCache"
    Remove-CacheFiles "C:\Users\$user\AppData\Local\Microsoft\Windows\IECompatUaCache"
    Remove-CacheFiles "C:\Users\$user\AppData\Local\Microsoft\Windows\IEDownloadHistory"
    Remove-CacheFiles "C:\Users\$user\AppData\Local\Microsoft\Windows\Temporary Internet Files"    
    Log "Cleared Windows User Cache Files for user: $user"
}

#------------------------------------------------------------------#
#- Stop-BrowserSessions                                            #
#------------------------------------------------------------------#

Function Stop-BrowserSessions {
   $activeBrowsers = Get-Process Firefox*,Chrome*,Waterfox*,Edge*
   ForEach($browserProcess in $activeBrowsers) {
       try {
           $browserProcess.CloseMainWindow() | Out-Null 
           Log "Stopped browser process: $($browserProcess.Name)"
       } catch {
           Log "Failed to stop browser process: $($browserProcess.Name)"
       }
   }
}

#------------------------------------------------------------------#
#- Get-StorageSize                                                 #
#------------------------------------------------------------------#

Function Get-StorageSize {
    Get-WmiObject Win32_LogicalDisk | 
    Where-Object { $_.DriveType -eq "3" } | 
    Select-Object SystemName, 
        @{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
        @{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f ( $_.Size / 1gb)}},
        @{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f ( $_.Freespace / 1gb ) } },
        @{ Name = "PercentFree" ; Expression = {"{0:P1}" -f ( $_.FreeSpace / $_.Size ) } } |
    Format-Table -AutoSize | Out-String | Tee-Object -FilePath $logFile -Append
}

#------------------------------------------------------------------#
#- Remove-CacheFiles                                               #
#------------------------------------------------------------------#

Function Remove-CacheFiles {
    param([Parameter(Mandatory=$true)][string]$path)    
    BEGIN {
        $originalVerbosePreference = $VerbosePreference
        $VerbosePreference = 'Continue'
        Log "Removing cache files from: $path"
    }
    PROCESS {
        if((Test-Path $path)) {
            if([System.IO.Directory]::Exists($path)) {
                try {
                    if($path[-1] -eq '\') {
                        [int]$pathSubString = $path.ToCharArray().Count - 1
                        $sanitizedPath = $path.SubString(0, $pathSubString)
                        Remove-Item -Path "$sanitizedPath\*" -Recurse -Force -ErrorAction SilentlyContinue -Verbose
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue -Verbose              
                    }
                    Log "Removed cache files from directory: $path"
                } catch {
                    Log "Failed to remove cache files from directory: $path"
                }
            } else {
                try {
                    Remove-Item -Path $path -Force -ErrorAction SilentlyContinue -Verbose
                    Log "Removed cache file: $path"
                } catch {
                    Log "Failed to remove cache file: $path"
                }
            }
        } else {
            Log "Path does not exist: $path"
        }
    }
    END {
        $VerbosePreference = $originalVerbosePreference
    }
}

#------------------------------------------------------------------#
#- Clear-ChromeCache                                               #
#------------------------------------------------------------------#

Function Clear-ChromeCache {
    param([string]$user=$env:USERNAME)
    if((Test-Path "C:\users\$user\AppData\Local\Google\Chrome\User Data\Default")) {
        $chromeAppData = "C:\Users\$user\AppData\Local\Google\Chrome\User Data\Default" 
        $possibleCachePaths = @('Cache','Cache2\entries\','Cookies','History','Top Sites','VisitedLinks','Web Data','Media Cache','Cookies-Journal','ChromeDWriteFontCache')
        ForEach($cachePath in $possibleCachePaths) {
            Remove-CacheFiles "$chromeAppData\$cachePath"
        }
        Log "Cleared Chrome Cache for user: $user"
    } else {
        Log "Chrome cache path does not exist for user: $user"
    }
}

#------------------------------------------------------------------#
#- Clear-EdgeCache                                                 #
#------------------------------------------------------------------#

Function Clear-EdgeCache {
    param([string]$user=$env:USERNAME)
    if((Test-Path "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default")) {
        $EdgeAppData = "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default"
        $possibleCachePaths = @('Cache','Cache2\entries','Cookies','History','Top Sites','Visited Links','Web Data','Media History','Cookies-Journal')
        ForEach($cachePath in $possibleCachePaths) {
            Remove-CacheFiles "$EdgeAppData\$cachePath"
        }
        Log "Cleared Edge Cache for user: $user"
    } else {
        Log "Edge cache path does not exist for user: $user"
    }
}

#------------------------------------------------------------------#
#- Clear-FirefoxCacheFiles                                         #
#------------------------------------------------------------------#

Function Clear-FirefoxCacheFiles {
    param([string]$user=$env:USERNAME)
    if((Test-Path "C:\users\$user\AppData\Local\Mozilla\Firefox\Profiles")) {
        $possibleCachePaths = @('cache','cache2\entries','thumbnails','cookies.sqlite','webappsstore.sqlite','chromeappstore.sqlite')
        $firefoxAppDataPath = (Get-ChildItem "C:\users\$user\AppData\Local\Mozilla\Firefox\Profiles" | Where-Object { $_.Name -match 'Default' }[0]).FullName 
        ForEach($cachePath in $possibleCachePaths) {
            Remove-CacheFiles "$firefoxAppDataPath\$cachePath"
        }
        Log "Cleared Firefox Cache for user: $user"
    } else {
        Log "Firefox cache path does not exist for user: $user"
    }
}

#------------------------------------------------------------------#
#- Clear-WaterfoxCacheFiles                                        #
#------------------------------------------------------------------#

Function Clear-WaterfoxCacheFiles { 
    param([string]$user=$env:USERNAME)
    if((Test-Path "C:\users\$user\AppData\Local\Waterfox\Profiles")) {
        $possibleCachePaths = @('cache','cache2\entries','thumbnails','cookies.sqlite','webappsstore.sqlite','chromeappstore.sqlite')
        $waterfoxAppDataPath = (Get-ChildItem "C:\users\$user\AppData\Local\Waterfox\Profiles" | Where-Object { $_.Name -match 'Default' }[0]).FullName
        ForEach($cachePath in $possibleCachePaths) {
            Remove-CacheFiles "$waterfoxAppDataPath\$cachePath"
        }
        Log "Cleared Waterfox Cache for user: $user"
    } else {
        Log "Waterfox cache path does not exist for user: $user"
    }
}

#------------------------------------------------------------------#
#- Clear-TeamsCacheFiles                                           #
#------------------------------------------------------------------#

Function Clear-TeamsCacheFiles { 
    param([string]$user=$env:USERNAME)
    if((Test-Path "C:\users\$user\AppData\Roaming\Microsoft\Teams")) {
        $possibleCachePaths = @('cache','blob_storage','databases','gpucache','Indexeddb','Local Storage','application cache\cache')
        $teamsAppDataPath = (Get-ChildItem "C:\users\$user\AppData\Roaming\Microsoft\Teams" | Where-Object { $_.Name -match 'Default' }[0]).FullName
        ForEach($cachePath in $possibleCachePaths) {
            Remove-CacheFiles "$teamsAppDataPath\$cachePath"
        }
        Log "Cleared Teams Cache for user: $user"
    } else {
        Log "Teams cache path does not exist for user: $user"
    }
}

#------------------------------------------------------------------#
#- MAIN                                                            #
#------------------------------------------------------------------#

$StartTime = Get-Date
Log "System cleanup started."

Log "Initial Storage Size:"
Get-StorageSize

Stop-BrowserSessions
Clear-UserCacheFiles
Clear-GlobalWindowsCache

Log "Final Storage Size:"
Get-StorageSize

$EndTime = Get-Date
$elapsedTime = ($EndTime - $StartTime).TotalSeconds
Log "System cleanup completed in $elapsedTime seconds."
