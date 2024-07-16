<#
.SYNOPSIS
    Detection Script to check the completion of the system cleanup process.

.DESCRIPTION
    This script checks for the presence of the completion file created by the system cleanup remediation script.
    It will return a zero exit code if the cleanup has been completed and a non-zero exit code if it has not.

.EXAMPLE
    .\DetectSystemCleanup.ps1

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-14
#>

#------------------------------------------------------------------#
#- Function to check if a directory contains files                 #
#------------------------------------------------------------------#

function Test-PathContainsFiles {
    param (
        [string]$Path
    )
    try {
        $items = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction Stop
        if ($items.Count -gt 0) {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}

#------------------------------------------------------------------#
#- Check Windows Temp folder                                       #
#------------------------------------------------------------------#
$tempFolder = "$env:windir\Temp\*"
$windowsTempCheck = Test-PathContainsFiles -Path $tempFolder

#------------------------------------------------------------------#
#- Check User Temp folders                                         #
#------------------------------------------------------------------#
$userTempFolder = "$env:temp\*"
$userTempCheck = Test-PathContainsFiles -Path $userTempFolder

#------------------------------------------------------------------#
#- Check Internet Explorer cache                                   #
#------------------------------------------------------------------#
$ieCacheFolders = @(
    "$env:userprofile\AppData\Local\Microsoft\Windows\INetCache\*",
    "$env:userprofile\AppData\Local\Microsoft\Windows\Temporary Internet Files\*"
)
$ieCacheCheck = $false
foreach ($folder in $ieCacheFolders) {
    if (Test-PathContainsFiles -Path $folder) {
        $ieCacheCheck = $true
        break
    }
}

#------------------------------------------------------------------#
#- Check Windows Update cache                                      #
#------------------------------------------------------------------#
$windowsUpdateCache = "$env:windir\SoftwareDistribution\Download\*"
$windowsUpdateCacheCheck = Test-PathContainsFiles -Path $windowsUpdateCache

#------------------------------------------------------------------#
#- Check Windows Error Reporting files                             #
#------------------------------------------------------------------#
$werFiles = "$env:localappdata\CrashDumps\*"
$werFilesCheck = Test-PathContainsFiles -Path $werFiles

#------------------------------------------------------------------#
#- Check Recycle Bin                                               #
#------------------------------------------------------------------#
function Test-RecycleBinNotEmpty {
    $shell = New-Object -ComObject Shell.Application
    $recycleBin = $shell.NameSpace(0xA)
    if ($recycleBin.Items().Count -gt 0) {
        return $true
    } else {
        return $false
    }
}
$recycleBinCheck = Test-RecycleBinNotEmpty

#------------------------------------------------------------------#
#- Check other known temporary locations                           #
#------------------------------------------------------------------#
$otherTempFolders = @(
    "$env:userprofile\AppData\Local\Temp\*",
    "$env:userprofile\AppData\Local\Microsoft\Windows\Explorer\*",
    "$env:userprofile\AppData\Local\Microsoft\Windows\Caches\*"
)
$otherTempCheck = $false
foreach ($folder in $otherTempFolders) {
    if (Test-PathContainsFiles -Path $folder) {
        $otherTempCheck = $true
        break
    }
}

#------------------------------------------------------------------#
#- Check cache files specific to browsers (Chrome, Edge, Firefox, Waterfox) #
#------------------------------------------------------------------#
function Test-BrowserCache {
    param ([string]$user = $env:USERNAME)
    $paths = @(
        "C:\Users\$user\AppData\Local\Google\Chrome\User Data\Default\Cache\*",
        "C:\Users\$user\AppData\Local\Google\Chrome\User Data\Default\Cache2\entries\*",
        "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default\Cache\*",
        "C:\Users\$user\AppData\Local\Microsoft\Edge\User Data\Default\Cache2\entries\*",
        "C:\users\$user\AppData\Local\Mozilla\Firefox\Profiles\*\cache\*",
        "C:\users\$user\AppData\Local\Mozilla\Firefox\Profiles\*\cache2\entries\*",
        "C:\users\$user\AppData\Local\Waterfox\Profiles\*\cache\*",
        "C:\users\$user\AppData\Local\Waterfox\Profiles\*\cache2\entries\*"
    )
    foreach ($path in $paths) {
        if (Test-PathContainsFiles -Path $path) {
            return $true
        }
    }
    return $false
}
$browserCacheCheck = Test-BrowserCache

#------------------------------------------------------------------#
#- Check cache files specific to communication platforms (Teams)   #
#------------------------------------------------------------------#
function Test-TeamsCache {
    param ([string]$user = $env:USERNAME)
    $paths = @(
        "C:\users\$user\AppData\Roaming\Microsoft\Teams\cache\*",
        "C:\users\$user\AppData\Roaming\Microsoft\Teams\blob_storage\*",
        "C:\users\$user\AppData\Roaming\Microsoft\Teams\databases\*",
        "C:\users\$user\AppData\Roaming\Microsoft\Teams\gpucache\*",
        "C:\users\$user\AppData\Roaming\Microsoft\Teams\Indexeddb\*",
        "C:\users\$user\AppData\Roaming\Microsoft\Teams\Local Storage\*",
        "C:\users\$user\AppData\Roaming\Microsoft\Teams\application cache\cache\*"
    )
    foreach ($path in $paths) {
        if (Test-PathContainsFiles -Path $path) {
            return $true
        }
    }
    return $false
}
$teamsCacheCheck = Test-TeamsCache

#------------------------------------------------------------------#
#- Determine overall status                                        #
#------------------------------------------------------------------#
if ($windowsTempCheck -or $userTempCheck -or $ieCacheCheck -or $windowsUpdateCacheCheck -or $werFilesCheck -or $recycleBinCheck -or $otherTempCheck -or $browserCacheCheck -or $teamsCacheCheck) {
    Write-Output "Cleanup required"
    exit 1
} else {
    Write-Output "No cleanup required"
    exit 0
}
