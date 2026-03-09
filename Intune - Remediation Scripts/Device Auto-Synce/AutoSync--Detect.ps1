<#
.SYNOPSIS
    Detects whether Intune device sync is overdue.

.DESCRIPTION
    This detection script checks the last run time of the PushLaunch scheduled task.
    If the task has not run within the allowed number of days, the device is marked
    as non-compliant so remediation can run.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not compliant or detection failed

.RUN AS
    System or User (depending on Intune assignment)

.EXAMPLE
    .\AutoSync--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'AutoSync--Detect.ps1'
$ScriptBaseName = 'AutoSync--Detect'
$SolutionName   = 'Device Auto-Sync'

# Allowed age for the last sync
$TaskName       = 'PushLaunch'
$MaxAllowedDays = 2

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

# Return the newest valid LastRunTime from matching scheduled tasks
function Get-LatestTaskRunTime {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskName
    )

    $Tasks = @(Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop)
    if (-not $Tasks) {
        return $null
    }

    $TaskInfo = @($Tasks | Get-ScheduledTaskInfo -ErrorAction Stop)

    $ValidTimes = @(
        $TaskInfo |
        Where-Object {
            $null -ne $_.LastRunTime -and $_.LastRunTime -ne [datetime]::MinValue
        } |
        Select-Object -ExpandProperty LastRunTime
    )

    if (-not $ValidTimes) {
        return $null
    }

    return ($ValidTimes | Sort-Object -Descending | Select-Object -First 1)
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "Scheduled task: $TaskName"
Write-Log -Message "Allowed sync age: $MaxAllowedDays day(s)"
Write-Log -Message "Log file: $LogFile"

try {
    # Get the most recent valid run time
    $LastRunTime = Get-LatestTaskRunTime -TaskName $TaskName

    if (-not $LastRunTime) {
        Write-Log -Message "No valid LastRunTime found for task '$TaskName'." -Level 'ERROR'
        exit 1
    }

    $CurrentTime = Get-Date
    $TimeDiff    = New-TimeSpan -Start $LastRunTime -End $CurrentTime

    Write-Log -Message "Last sync time: $($LastRunTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Log -Message "Current time: $($CurrentTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Log -Message "Sync age: $($TimeDiff.Days) day(s), $($TimeDiff.Hours) hour(s), $($TimeDiff.Minutes) minute(s)"

    # Mark device non-compliant if sync age is too old
    if ($TimeDiff.TotalDays -gt $MaxAllowedDays) {
        Write-Log -Message "Last sync is older than $MaxAllowedDays day(s)." -Level 'WARNING'
        exit 1
    }
    else {
        Write-Log -Message 'Intune sync is within the allowed threshold.' -Level 'SUCCESS'
        exit 0
    }
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Detection Logic ----------