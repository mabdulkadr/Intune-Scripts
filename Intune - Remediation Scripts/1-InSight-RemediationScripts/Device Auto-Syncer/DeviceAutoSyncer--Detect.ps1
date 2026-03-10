<#
.SYNOPSIS
    Detect whether the device has synced recently through the Intune PushLaunch scheduled task.

.DESCRIPTION
    This detection script reads the `LastRunTime` value for the `PushLaunch`
    scheduled task and compares it with the current date and time.

    If the last sync is more than 2 days old, the device is treated as
    non-compliant so the paired remediation script can start the task again.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\DeviceAutoSyncer--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Scheduled task used by Intune device sync.
$TaskName = 'PushLaunch'

# Maximum allowed age for the last sync before remediation is required.
$MaximumSyncAgeDays = 2

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DeviceAutoSyncer--Detect.ps1'
$ScriptBaseName = 'DeviceAutoSyncer--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Script-specific logging location shared by the Detect and Remediate scripts.
$SolutionName = 'DeviceAutoSyncer'
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ====================== CONFIGURATION ======================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory exists before writing entries.
function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }
}

function Start-LogRun {
    # Add a visual separator so each run is easier to scan in the same log file.
    Initialize-LogFile

    if (Test-Path -LiteralPath $LogFile) {
        $existingLog = Get-Item -LiteralPath $LogFile -ErrorAction SilentlyContinue
        if ($existingLog -and $existingLog.Length -gt 0) {
            Add-Content -Path $LogFile -Value '' -Encoding UTF8
        }
    }

    Add-Content -Path $LogFile -Value ('=' * 78) -Encoding UTF8
}

# Write a colorized console message and persist it to the log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL')]
        [string]$Level = 'INFO'
    )

    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message

    switch ($Level) {
        'OK'   { Write-Host $line -ForegroundColor Green }
        'WARN' { Write-Host $line -ForegroundColor Yellow }
        'FAIL' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ===================== FIRST DETECTION BLOCK =====================
Start-LogRun
Write-Log -Level 'INFO' -Message '=== Detection START ==='
Write-Log -Level 'INFO' -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level 'INFO' -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level 'INFO' -Message ("Scheduled task target: {0}" -f $TaskName)

# Create variable for the time of the last Intune sync.
$PushInfo    = Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo
$LastPush    = $PushInfo.LastRunTime
$CurrentTime = Get-Date

Write-Log -Level 'INFO' -Message ("Last run time: {0}" -f $LastPush)
Write-Log -Level 'INFO' -Message ("Current time: {0}" -f $CurrentTime)

# Calculate the time difference between the current date/time and the date stored in the variable.
$TimeDiff = New-TimeSpan -Start $LastPush -End $CurrentTime
Write-Log -Level 'INFO' -Message ("Sync age: {0} day(s), {1} hour(s)" -f $TimeDiff.Days, $TimeDiff.Hours)

# If/Else statement checking whether the Time Difference between the Last Sync and the current time is less or greater than 2 days.
if ($TimeDiff.Days -gt $MaximumSyncAgeDays) {
    # The time difference is more than 2 days.
    Write-Host 'Last Sync was more than 2 days ago'
    Write-Log -Level 'WARN' -Message 'Last sync was more than 2 days ago.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
    exit 1
}
else {
    # The time difference is less than or equal to 2 days.
    Write-Host 'Sync Complete'
    Write-Log -Level 'OK' -Message 'The device synced within the accepted window.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 0) ==='
    exit 0
}
#endregion ================== FIRST DETECTION BLOCK ==================
