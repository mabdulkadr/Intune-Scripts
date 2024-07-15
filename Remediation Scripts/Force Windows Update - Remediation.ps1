<#
.SYNOPSIS
    Remediation Script to download and install pending Windows updates using PSWindowsUpdate module, excluding firmware updates.

.DESCRIPTION
    This script uses the PSWindowsUpdate module to search for, download, and install any pending updates on the system, excluding firmware updates.
    It requires administrative privileges to run and will output the progress of the update process.

.EXAMPLE
    .\RemediatePendingUpdates.ps1

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-14
#>

# Remediation script
$logPath = "C:\Intune\Updates\RemediatePendingWindowsUpdates.log"
if (!(Test-Path "C:\Intune\Updates")) {
    New-Item -ItemType Directory -Path "C:\Intune\Updates" -Force
}

$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
$UpdateDownloader = $UpdateSession.CreateUpdateDownloader()
$UpdateInstaller = $UpdateSession.CreateUpdateInstaller()

$SearchResult = $UpdateSearcher.Search("IsInstalled=0 AND Type='Software' AND IsHidden=0")
if ($SearchResult.Updates.Count -gt 0) {
    $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($Update in $SearchResult.Updates) {
        if ($Update.Type -ne 'Driver') { # Exclude firmware updates
            $UpdatesToInstall.Add($Update) | Out-Null
            $Update.Title | Out-File -FilePath $logPath -Append
        }
    }
    
    if ($UpdatesToInstall.Count -gt 0) {
        $UpdateDownloader.Updates = $UpdatesToInstall
        $DownloadResult = $UpdateDownloader.Download()
        
        if ($DownloadResult.ResultCode -eq 2) { # 2 means some updates failed to download
            Write-Output "Some updates failed to download." | Out-File -FilePath $logPath -Append
            exit 1
        }
        
        $UpdateInstaller.Updates = $UpdatesToInstall
        $InstallResult = $UpdateInstaller.Install()
        
        if ($InstallResult.ResultCode -eq 2) { # 2 means some updates failed to install
            Write-Output "Some updates failed to install." | Out-File -FilePath $logPath -Append
            exit 1
        }
    } else {
        Write-Output "No applicable updates to install." | Out-File -FilePath $logPath -Append
        exit 0
    }
} else {
    Write-Output "No updates pending." | Out-File -FilePath $logPath -Append
    exit 0
}
