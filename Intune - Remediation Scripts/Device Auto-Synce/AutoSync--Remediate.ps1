<#
.SYNOPSIS
    Remediates Intune device sync by starting the required scheduled task.

.DESCRIPTION
    This remediation script starts all matching PushLaunch scheduled tasks used by
    Intune device management.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed to start the scheduled task

.RUN AS
    System or User (depending on Intune assignment)

.EXAMPLE
    .\AutoSync--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'AutoSync--Remediate.ps1'
$ScriptBaseName = 'AutoSync--Remediate'
$SolutionName   = 'Device Auto-Sync'

# Scheduled task used to trigger Intune sync
$TaskName = 'PushLaunch'

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


#region ---------- Remediation Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting remediation for $ScriptName"
Write-Log -Message "Scheduled task: $TaskName"
Write-Log -Message "Log file: $LogFile"

try {
    # Get all matching tasks
    $Tasks = @(Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop)

    if (-not $Tasks) {
        Write-Log -Message "Scheduled task '$TaskName' was not found." -Level 'ERROR'
        exit 1
    }

    Write-Log -Message "Found $($Tasks.Count) matching task(s)."

    foreach ($Task in $Tasks) {
        $Task | Start-ScheduledTask -ErrorAction Stop
        Write-Log -Message "Started task: $($Task.TaskPath)$($Task.TaskName)" -Level 'SUCCESS'
    }

    exit 0
}
catch {
    Write-Log -Message "Failed to start scheduled task '$TaskName': $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}

#endregion ---------- Remediation Logic ----------