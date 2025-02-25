<#
.SYNOPSIS
    Updates outdated applications using Winget, excluding Java-related applications.

.DESCRIPTION
    This script fetches outdated applications using Winget and updates them, while filtering out Java-related apps (OpenJDK, JDK, JRE).
    It performs updates in **silent mode** (`--silent`) and logs all update operations to `C:\Intune\update_log.txt`.

.EXAMPLE
    Deploy this script as a remediation policy in Microsoft Intune.

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2025-02-25
#>

# Define log path
$LogFolder = "C:\Intune"
$LogPath = "$LogFolder\update_log.txt"

# Ensure logging directory exists
if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

# Function to write logs
function Write-Log {
    param ($Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -Append -Encoding utf8 $LogPath
}

Write-Log "Starting Winget Application Update Process."

# Ensure Winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Log "Winget not found. Exiting."
    exit 1
}

# Get list of outdated applications
$OutdatedApps = winget upgrade --accept-source-agreements | Select-String -Pattern "(\S+)\s+(\S+)\s+(\S+)" | ForEach-Object { $_.ToString() }

# Exclude Java-related applications (JDK, JRE, OpenJDK)
$ExcludedApps = @("jdk", "jre", "openjdk")
$FilteredApps = $OutdatedApps | Where-Object { $ExcludedApps -notcontains ($_ -split '\s+')[0].ToLower() }

# If there are updates available (excluding Java), proceed with silent installation
if ($FilteredApps) {
    Write-Log "Upgrading the following applications silently: $($FilteredApps -join ', ')"
    winget upgrade --all --silent --accept-package-agreements --accept-source-agreements | Out-File -Append -Encoding utf8 $LogPath
    Write-Log "Application upgrade process completed in silent mode."
} else {
    Write-Log "No applicable updates found."
}

exit 0
