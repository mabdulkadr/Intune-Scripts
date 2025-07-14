<#
.SYNOPSIS
    Remediation script to remove Adobe Flash Player.

.DESCRIPTION
    Uninstalls Flash Player using the official Adobe uninstaller and deletes remaining files and registry entries.
    Logs output to C:\Intune.

.NOTES
    Based on Adobe KB: https://helpx.adobe.com/flash-player/kb/uninstall-flash-player-windows.html
    Author  : Mohammad Abdelkader
    Website : momar.tech
    Date    : 2025-06-30
#>

$ErrorActionPreference = 'Stop'

$DownloadUrl      = "https://download.macromedia.com/get/flashplayer/current/support/uninstall_flash_player.exe"
$LocalUninstaller = "$env:TEMP\uninstall_flash_player.exe"
$LogDir           = "C:\Intune"
$LogFile          = "$LogDir\FlashPlayer_Uninstall.txt"

if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force
}

$FilePaths = @(
    'C:\Windows\System32\Macromed\Flash',
    'C:\Windows\SysWOW64\Macromed\Flash',
    "$env:APPDATA\Adobe\Flash Player",
    "$env:APPDATA\Macromedia\Flash Player"
)

$RegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Adobe Flash Player NPAPI',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Adobe Flash Player ActiveX',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Adobe Flash Player Pepper',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Adobe Flash Player NPAPI',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Adobe Flash Player PPAPI',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Adobe Flash Player Pepper'
)

# Kill browsers and Flash
Get-Process -Name "chrome","iexplore","firefox","edge","flashplayerplugin_32_*" -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue | Out-Null
"$((Get-Date)) - Closed browsers and Flash processes" | Tee-Object -FilePath $LogFile -Append

# Download uninstaller if needed
if (-not (Test-Path $LocalUninstaller)) {
    "$((Get-Date)) - Downloading Flash Player uninstaller..." | Tee-Object -FilePath $LogFile -Append
    (New-Object System.Net.WebClient).DownloadFile($DownloadUrl, $LocalUninstaller)
}

# Run uninstaller silently
Start-Process -FilePath $LocalUninstaller -ArgumentList "-silent" -Wait
"$((Get-Date)) - Uninstaller executed" | Tee-Object -FilePath $LogFile -Append

# Remove leftover folders
foreach ($p in $FilePaths) {
    if (Test-Path $p) {
        try {
            Remove-Item -Path $p -Recurse -Force
            "$((Get-Date)) - Removed: $p" | Tee-Object -FilePath $LogFile -Append
        } catch {
            "$((Get-Date)) - Error deleting $p : $_" | Tee-Object -FilePath $LogFile -Append
        }
    }
}

# Remove registry keys
foreach ($r in $RegistryPaths) {
    try {
        if (Test-Path $r) {
            Remove-Item -Path $r -Recurse -Force
            "$((Get-Date)) - Deleted registry key: $r" | Tee-Object -FilePath $LogFile -Append
        }
    } catch {
        "$((Get-Date)) - Error deleting registry $r : $_" | Tee-Object -FilePath $LogFile -Append
    }
}

"$((Get-Date)) - Flash Player fully removed." | Tee-Object -FilePath $LogFile -Append
