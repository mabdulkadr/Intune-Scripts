<#
.SYNOPSIS
    Detects whether core Windows time settings are configured correctly.

.DESCRIPTION
    This detection script verifies three time-related requirements:
    1. The Windows Time service is running.
    2. Time synchronization is configured.
    3. Automatic time zone detection is enabled.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not compliant
    - Exit 2: Detection error

.RUN AS
    System or User (depending on Intune assignment)

.EXAMPLE
    .\TimeIssues--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'TimeIssues--Detect.ps1'
$ScriptBaseName = 'TimeIssues--Detect'
$SolutionName   = 'Fix Windows Time Issues'

# Time-related settings
$TimeServiceName      = 'w32time'
$TimeZoneRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
$TimeZoneValueName    = 'Start'
$ExpectedTimeZoneMode = 3

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
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
    $Line = "[$TimeStamp] [$Level] $Message"

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

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Time service: $TimeServiceName"
Write-Log -Message "Log file: $LogFile"

try {
    # Check Windows Time service
    $TimeService = Get-Service -Name $TimeServiceName -ErrorAction SilentlyContinue
    if (-not $TimeService) {
        Write-Log -Message 'Windows Time service was not found.' -Level 'WARNING'
        Write-Output 'NonCompliant: Windows Time service was not found.'
        exit 1
    }

    Write-Log -Message "Windows Time service state: $($TimeService.Status)"

    if ($TimeService.Status -ne 'Running') {
        Write-Log -Message 'Windows Time service is not running.' -Level 'WARNING'
        Write-Output 'NonCompliant: Windows Time service is not running.'
        exit 1
    }

    # Check time synchronization configuration
    $TimeConfig = w32tm /query /configuration 2>$null
    $NtpClientConfigured = $TimeConfig | Select-String -Pattern 'NtpClient'

    if (-not $NtpClientConfigured) {
        Write-Log -Message 'Automatic time synchronization is not configured.' -Level 'WARNING'
        Write-Output 'NonCompliant: Automatic time synchronization is not configured.'
        exit 1
    }

    Write-Log -Message 'Time synchronization configuration was detected.'

    # Check automatic time zone detection
    $TimeZoneSetting = Get-ItemProperty -Path $TimeZoneRegistryPath -Name $TimeZoneValueName -ErrorAction SilentlyContinue

    if (-not $TimeZoneSetting -or $TimeZoneSetting.$TimeZoneValueName -ne $ExpectedTimeZoneMode) {
        Write-Log -Message 'Automatic time zone detection is not enabled.' -Level 'WARNING'
        Write-Output 'NonCompliant: Automatic time zone detection is not enabled.'
        exit 1
    }

    Write-Log -Message 'All time-related settings are configured correctly.' -Level 'SUCCESS'
    Write-Output 'Compliant: All time-related settings are correctly configured.'
    exit 0
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Output "Error during detection: $($_.Exception.Message)"
    exit 2
}

#endregion ---------- Detection Logic ----------