<#
.SYNOPSIS
    Detects when a restart notification should be shown to the user.

.DESCRIPTION
    This detection script marks the device as non-compliant when either:
    1. A Windows update reboot is already pending
    2. The device uptime has reached the configured threshold

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Non-compliant or detection failed

.RUN AS
    User

.EXAMPLE
    .\WinUptimeRestartNotification--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'WinUptimeRestartNotification--Detect.ps1'
$ScriptBaseName = 'WinUptimeRestartNotification--Detect'
$SolutionName   = 'WindowsUptimeRestartNotification'

# Keep this value aligned with the remediation script
$MaxUptimeDays = 14

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

# Detect common reboot-required states related to Windows servicing
function Get-PendingRebootInfo {
    $Reasons = @()

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $Reasons += 'Windows Update'
    }

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $Reasons += 'CBS'
    }

    try {
        $PendingRename = Get-ItemProperty `
            -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
            -Name 'PendingFileRenameOperations' `
            -ErrorAction SilentlyContinue

        if ($PendingRename -and $PendingRename.PendingFileRenameOperations) {
            $Reasons += 'Pending File Rename'
        }
    }
    catch {}

    $UniqueReasons = @($Reasons | Select-Object -Unique)

    return [pscustomobject]@{
        Pending = ($UniqueReasons.Count -gt 0)
        Reasons = $UniqueReasons
    }
}

# Return uptime in full days
function Get-UptimeDays {
    try {
        $OperatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $BootTime = $OperatingSystem.LastBootUpTime
        $Uptime = (Get-Date) - $BootTime
        return [math]::Floor($Uptime.TotalDays)
    }
    catch {
        Write-Log -Message "Failed to read uptime: $($_.Exception.Message)" -Level 'WARNING'
        return $null
    }
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Maximum uptime threshold: $MaxUptimeDays day(s)"
Write-Log -Message "Log file: $LogFile"

try {
    # Collect both signals once
    $PendingInfo = Get-PendingRebootInfo
    $UptimeDays  = Get-UptimeDays

    Write-Log -Message "Pending reboot detected: $($PendingInfo.Pending)"

    if ($PendingInfo.Reasons.Count -gt 0) {
        Write-Log -Message "Pending reboot reasons: $($PendingInfo.Reasons -join ', ')"
    }

    if ($null -ne $UptimeDays) {
        Write-Log -Message "Current uptime: $UptimeDays day(s)"
    }
    else {
        Write-Log -Message 'Current uptime could not be determined.'
    }

    # Priority 1: reboot already pending
    if ($PendingInfo.Pending) {
        Write-Log -Message 'A restart is already pending due to Windows servicing.' -Level 'WARNING'
        Write-Output 'Non-Compliant'
        exit 1
    }

    # Priority 2: uptime threshold reached
    if (($null -ne $UptimeDays) -and ($UptimeDays -ge $MaxUptimeDays)) {
        Write-Log -Message "Device uptime is $UptimeDays day(s), which meets or exceeds the threshold." -Level 'WARNING'
        Write-Output 'Non-Compliant'
        exit 1
    }

    # Avoid false positives when uptime cannot be read
    if ($null -eq $UptimeDays) {
        Write-Log -Message 'No pending reboot was detected and uptime is unavailable. Treating as compliant.' -Level 'SUCCESS'
        Write-Output 'Compliant'
        exit 0
    }

    Write-Log -Message "No pending reboot was detected and uptime is within threshold ($UptimeDays day(s))." -Level 'SUCCESS'
    Write-Output 'Compliant'
    exit 0
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Output 'Non-Compliant'
    exit 1
}

#endregion ---------- Detection Logic ----------