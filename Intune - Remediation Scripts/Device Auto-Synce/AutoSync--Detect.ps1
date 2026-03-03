<#
.SYNOPSIS
    Detect whether Intune device sync is overdue.

.DESCRIPTION
    This detection script checks the last run time of the `PushLaunch`
    scheduled task used by Intune device management.

    If the task has not run within the configured number of days, the device is
    treated as non-compliant so remediation can run.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant or detection failed

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\AutoSync--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'AutoSync--Detect.ps1'
$ScriptBaseName = 'AutoSync--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Scheduled task and allowed sync age used for compliance evaluation.
$TaskName        = 'PushLaunch'
$MaxAllowedDays  = 2
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Device Auto-Synce"
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName

# Detection-specific log file.
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ==================== PATHS AND LOGGING ====================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and file exist before any write attempts.
function Initialize-Logging {
    try {
        if (-not (Test-Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        if (-not (Test-Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        return $true
    }
    catch {
        return $false
    }
}

$LogReady = Initialize-Logging

# Write colored console output and persist the same line to the log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "OK", "WARN", "FAIL")]
        [string]$Level = "INFO"
    )

    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message

    switch ($Level) {
        "OK"   { Write-Host $line -ForegroundColor Green }
        "WARN" { Write-Host $line -ForegroundColor Yellow }
        "FAIL" { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    if ($LogReady) {
        try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch {}
    }
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ===================== FIRST DETECTION BLOCK =====================
Write-Log -Level "INFO" -Message "=== Detection START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level "INFO" -Message ("Scheduled task target: {0}" -f $TaskName)
Write-Log -Level "INFO" -Message ("Maximum allowed sync age: {0} day(s)" -f $MaxAllowedDays)

try {
    # Retrieve all matching scheduled tasks because the same task name can exist in multiple task paths.
    $PushTasks = @(Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop)
    $PushInfo  = @($PushTasks | Get-ScheduledTaskInfo -ErrorAction Stop)

    if (-not $PushInfo) {
        Write-Log -Level "FAIL" -Message ("Scheduled task '{0}' was not found or returned no task info." -f $TaskName)
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
        exit 1
    }

    Write-Log -Level "INFO" -Message ("Matching scheduled task count: {0}" -f $PushTasks.Count)

    # Use the most recent valid run time across all matching tasks.
    $ValidLastRuns = @(
        $PushInfo |
        Where-Object { $null -ne $_.LastRunTime -and $_.LastRunTime -ne [datetime]::MinValue } |
        Select-Object -ExpandProperty LastRunTime
    )

    if (-not $ValidLastRuns) {
        Write-Log -Level "FAIL" -Message ("No valid LastRunTime was found for scheduled task '{0}'." -f $TaskName)
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
        exit 1
    }

    $LastPush = $ValidLastRuns | Sort-Object -Descending | Select-Object -First 1

    $CurrentTime = Get-Date
    $TimeDiff    = New-TimeSpan -Start $LastPush -End $CurrentTime

    Write-Log -Level "INFO" -Message ("Last sync time: {0}" -f $LastPush.ToString('yyyy-MM-dd HH:mm:ss'))
    Write-Log -Level "INFO" -Message ("Current time: {0}" -f $CurrentTime.ToString('yyyy-MM-dd HH:mm:ss'))
    Write-Log -Level "INFO" -Message ("Sync age: {0} day(s), {1} hour(s), {2} minute(s)" -f $TimeDiff.Days, $TimeDiff.Hours, $TimeDiff.Minutes)

    if ($TimeDiff.TotalDays -gt $MaxAllowedDays) {
        Write-Log -Level "WARN" -Message ("Last sync is older than {0} day(s). Remediation required." -f $MaxAllowedDays)
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
        exit 1
    }
    else {
        Write-Log -Level "OK" -Message "Intune sync is within the allowed threshold."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 0) ==="
        exit 0
    }
}
catch {
    Write-Log -Level "FAIL" -Message ("Detection error: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
