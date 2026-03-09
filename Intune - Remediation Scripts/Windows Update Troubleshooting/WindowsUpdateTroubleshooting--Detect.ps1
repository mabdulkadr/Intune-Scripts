<#
.SYNOPSIS
    Detects whether the last installed Windows update is recent enough.

.DESCRIPTION
    This detection script checks the date of the most recent installed Windows
    update and marks the device as non-compliant when that update is older than
    the configured threshold.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Non-compliant or detection failed

.RUN AS
    System

.EXAMPLE
    .\WindowsUpdateTroubleshooting--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'WindowsUpdateTroubleshooting--Detect.ps1'
$ScriptBaseName = 'WindowsUpdateTroubleshooting--Detect'
$SolutionName   = 'Windows Update Troubleshooting'

# Maximum acceptable age for the last installed update
$UpdateThresholdDays = 30

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    'C:'
}

# Logging path
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

#endregion ---------- Configuration ----------


#region ---------- Functions ----------

# Create log folder and file if needed
function Initialize-Logging {
    try {
        if (-not (Test-Path -Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }

        return $true
    }
    catch {
        return $false
    }
}

# Write a message to console and log file
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line      = "[$TimeStamp] [$Level] $Message"

    switch ($Level) {
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        'WARNING' { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        default   { Write-Host $Line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        }
        catch {}
    }
}

# Return the most recent installed update date
function Get-LatestInstalledUpdateDate {
    try {
        $LatestHotFix = Get-HotFix -ErrorAction Stop |
            Where-Object { $_.InstalledOn } |
            Sort-Object -Property InstalledOn -Descending |
            Select-Object -First 1

        if ($LatestHotFix) {
            return [datetime]$LatestHotFix.InstalledOn
        }

        return $null
    }
    catch {
        return $null
    }
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Update age threshold: $UpdateThresholdDays day(s)"
Write-Log -Message "Log file: $LogFile"

try {
    # Get the latest installed Windows update date
    $LastUpdate = Get-LatestInstalledUpdateDate

    if (-not $LastUpdate) {
        Write-Log -Message 'No installed Windows updates were found on the system.' -Level 'ERROR'
        exit 1
    }

    Write-Log -Message "Last installed update date: $($LastUpdate.ToString('yyyy-MM-dd'))"

    # Calculate the number of days since the last update
    $CurrentDate     = Get-Date
    $DaysSinceUpdate = (New-TimeSpan -Start $LastUpdate -End $CurrentDate).Days

    Write-Log -Message "Days since last update: $DaysSinceUpdate"

    if ($DaysSinceUpdate -ge $UpdateThresholdDays) {
        Write-Log -Message "The last installed update is older than the allowed threshold." -Level 'WARNING'
        exit 1
    }

    Write-Log -Message "Windows update age is within the allowed threshold." -Level 'SUCCESS'
    exit 0
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Detection Logic ----------