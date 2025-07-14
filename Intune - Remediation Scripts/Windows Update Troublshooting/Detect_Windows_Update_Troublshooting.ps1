<#
.SYNOPSIS
    Checks the current Windows OS version and ensures it meets the required build.
    Also validates the time since the last Windows update was installed.

.DESCRIPTION
    This script checks if the current system's Windows version is below the specified Windows 10 or Windows 11 builds.
    It also calculates the days since the last update was installed and alerts if it exceeds a specified threshold (40 days).

.EXAMPLE
    Run the script in PowerShell:
    .\Check-WindowsUpdateStatus.ps1


.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-12-17
#>

# Variables for Windows Versions
$CurrentWin10 = [Version]"10.0.19045"  # Latest Windows 10 build
$CurrentWin11 = [Version]"10.0.22631"  # Latest Windows 11 build
$UpdateThresholdDays = 40             # Days since last update threshold

# Fetch OS Version
try {
    $OSInfo = Get-ComputerInfo -Property OsVersion
    $OSVersion = [Version]$OSInfo.OsVersion
} catch {
    Write-Error "Failed to retrieve OS version. Ensure you have sufficient permissions."
    exit 1
}

# Compare Windows Versions
if ($OSVersion -match "10\.0\.1") {
    if ($OSVersion -lt $CurrentWin10) {
        Write-Host "[ERROR] OS version $OSVersion is below the required Windows 10 version ($CurrentWin10)." -ForegroundColor Red
        exit 1
    }
}
elseif ($OSVersion -match "10\.0\.2") {
    if ($OSVersion -lt $CurrentWin11) {
        Write-Host "[ERROR] OS version $OSVersion is below the required Windows 11 version ($CurrentWin11)." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[WARNING] OS version $OSVersion is not recognized as Windows 10 or Windows 11." -ForegroundColor Yellow
}

# Check Last Windows Update
try {
    $LastUpdate = Get-HotFix | Sort-Object -Property InstalledOn | Select-Object -Last 1 -ExpandProperty InstalledOn
} catch {
    Write-Error "Failed to retrieve the latest installed update. Ensure Windows Update Service is running."
    exit 1
}

if (-not $LastUpdate) {
    Write-Host "[ERROR] No updates found on the system. Please check Windows Update." -ForegroundColor Red
    exit 1
}

# Calculate Days Since Last Update
$CurrentDate = Get-Date
$DaysSinceUpdate = (New-TimeSpan -Start $LastUpdate -End $CurrentDate).Days

if ($DaysSinceUpdate -ge $UpdateThresholdDays) {
    Write-Host "[ALERT] Last update was installed $DaysSinceUpdate days ago. Troubleshoot Windows Updates." -ForegroundColor Red
    exit 1
} else {
    Write-Host "[SUCCESS] Windows Updates were installed $DaysSinceUpdate days ago." -ForegroundColor Green
    exit 0
}
