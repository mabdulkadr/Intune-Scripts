<#
.SYNOPSIS
    Detect whether Intune Management Extension sync occurred recently.

.DESCRIPTION
    This detection script checks the Intune diagnostic event log for the
    Intune Management Extension sync event.

    If the target event is found within the configured lookback window, the
    device is treated as compliant.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant (remediation should run)

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\IntuneIMESync--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'IntuneIMESync--Detect.ps1'
$ScriptBaseName = 'IntuneIMESync--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Event log settings used to detect recent IME sync activity.
$LookbackHours = 1
$LogName       = 'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational'
$EventID       = 208

# Fallback scheduled task used by remediation to enforce recurring sync.
$TaskName      = 'Trigger-IME-Sync-Hourly'
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "IntuneSyncTrigger"
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName

# Detection-specific log file.
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ==================== PATHS AND LOGGING ====================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and file exist before any write attempts.
function Initialize-Logging {
    try {
        if (-not (Test-Path -Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        return $true
    }
    catch {
        # If logging init fails, the script still continues with console output.
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
Write-Log -Level "INFO" -Message ("Log name: {0}" -f $LogName)
Write-Log -Level "INFO" -Message ("Event ID: {0}" -f $EventID)
Write-Log -Level "INFO" -Message ("Lookback window: {0} hour(s)" -f $LookbackHours)
Write-Log -Level "INFO" -Message ("Fallback task name: {0}" -f $TaskName)

try {
    $LookbackMilliseconds = $LookbackHours * 60 * 60 * 1000
    $FilterXPath = "*[System[EventID=$EventID and TimeCreated[timediff(@SystemTime) <= $LookbackMilliseconds]]]"

    # Search for the target IME sync event within the configured lookback window.
    $SyncEvent = Get-WinEvent -LogName $LogName -FilterXPath $FilterXPath -ErrorAction SilentlyContinue

    if ($SyncEvent) {
        Write-Log -Level "OK" -Message ("Intune Management Extension sync was detected within the last {0} hour(s)." -f $LookbackHours)
        Write-Output "Intune Management Extension Sync detected within the last hour."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 0) ==="
        exit 0
    }

    # If the event is not yet present, accept the remediation task as a fallback compliance signal.
    $ScheduledTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($ScheduledTask -and $ScheduledTask.State -ne 'Disabled') {
        Write-Log -Level "OK" -Message ("No recent IME sync event was found, but scheduled task '{0}' exists and is enabled." -f $TaskName)
        Write-Output "Intune IME sync task is configured."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 0) ==="
        exit 0
    }

    Write-Log -Level "WARN" -Message ("No Intune Management Extension sync was detected within the last {0} hour(s), and scheduled task '{1}' is missing or disabled." -f $LookbackHours, $TaskName)
    Write-Output "No Intune Management Extension Sync detected within the last hour."
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
    exit 1
}
catch {
    Write-Log -Level "FAIL" -Message ("Detection error: {0}" -f $_.Exception.Message)
    Write-Output ("Detection error: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
