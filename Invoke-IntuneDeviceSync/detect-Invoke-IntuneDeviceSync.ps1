<#
.TITLE
    Detection - Recent IME Sync Event

.SYNOPSIS
    Detects an Intune Management Extension sync event or its fallback scheduled task.

.DESCRIPTION
    Evaluates IME sync health by checking the DeviceManagement-Enterprise-Diagnostics
    operational log for Event ID 208 within the configured lookback window. When the
    event is absent, a scheduled fallback task ('Trigger-IME-Sync-Hourly') is accepted
    as compliant while it exists and is enabled. This script NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,IME,Sync,EventLog

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Invoke-IntuneDeviceSync.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads one event log and task metadata.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    1.2
    - Event-log based detection with enabled-task fallback
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Invoke-IntuneDeviceSync.ps1
    Returns exit 0 when compliant; exit 1 when the paired remediation must run.

.EXAMPLE
    .\detect-Invoke-IntuneDeviceSync.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in SYSTEM or user context via Intune Proactive Remediations.
    - Keep detection fast: one XPath-filtered event query plus one task lookup.
    - Idempotent and read-only by definition.
    - Logs: <SystemDrive>\IntuneLogs\Invoke-IntuneDeviceSync\Invoke-IntuneDeviceSync-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Invoke-IntuneDeviceSync'
$ScriptMode   = 'Detection'

$LookbackHours = 1
$LogName       = 'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational'
$EventID       = 208
$TaskName      = 'Trigger-IME-Sync-Hourly'

# ============================================================================
# LOGGING BLOCK (embedded canonical scripts/Write-Log.ps1 - copy VERBATIM)
# Single source of truth: Initialize-Log / Write-Banner / Write-Log / Finish-Script.
# ============================================================================

# --- Logging (CLI Configuration) --------------------------------------------
$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

# Creates the Intune log folder/file and reports readiness.
function Initialize-Log {
    [CmdletBinding()]
    param(
        [string]$SolutionName = 'EnterpriseAdminTool',
        [string]$ScriptMode = 'run',
        [ValidateSet('Intune', 'General')]
        [string]$Type = 'General'
    )

    try {
        if ($Type -eq 'Intune') {
            $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"
        } else {
            $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        }

        if (-not (Test-Path -LiteralPath $script:LogRoot)) {
            $null = [System.IO.Directory]::CreateDirectory($script:LogRoot)
        }
        if (-not (Test-Path -LiteralPath $script:LogFile)) {
            $null = [System.IO.File]::Create($script:LogFile).Dispose()
        }

        $script:LogReady = $true
        return $true
    }
    catch {
        Write-Host "Log initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:LogReady = $false
        return $false
    }
}

# Writes the solution banner to console and log file.
function Write-Banner {
    [CmdletBinding()]
    [Alias('Show-Banner')]
    param()

    $title      = '{0} | {1}' -f $SolutionName, $ScriptMode
    $bannerLine = '=' * 78
    $lines      = @('', $bannerLine, $title, $bannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        } else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady -and $script:LogFile) {
            Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
        }
    }
}

# Writes one timestamped, level-colored line to console and log file.
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers use Write-Log -Message "" to break sections; early-return on empty.
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $logLine -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

# Logs the final message and terminates with the given exit code.
function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoExit
    )

    Write-Log -Message $Message -Level $Level
    if (-not $NoExit) {
        exit $ExitCode
    }
}

# ============================================================================
# DETECTION LOGIC
# Return a list of reason strings so operators see every failure at once.
# Empty list = compliant. Never modify the system here.
# ============================================================================

# Return recent IME sync events using an XPath time filter (empty when none).
function Get-RecentImeSyncEvent {
    $lookbackMilliseconds = $LookbackHours * 60 * 60 * 1000
    $filterXPath = "*[System[EventID=$EventID and TimeCreated[timediff(@SystemTime) <= $lookbackMilliseconds]]]"
    return Get-WinEvent -LogName $LogName -FilterXPath $filterXPath -ErrorAction SilentlyContinue
}

# Return $true when the fallback scheduled task exists and is not disabled.
function Test-FallbackTask {
    $scheduledTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    return ($scheduledTask -and $scheduledTask.State -ne 'Disabled')
}

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    try {
        # Primary signal: an IME sync event inside the lookback window.
        $syncEvent = Get-RecentImeSyncEvent
        if ($syncEvent) {
            Write-Log -Message ("Intune Management Extension sync was detected within the last {0} hour(s)." -f $LookbackHours) -Level 'DEBUG'
            return @($reasons)
        }

        # Fallback signal: the recurring sync task exists and is enabled.
        if (Test-FallbackTask) {
            Write-Log -Message ("No recent IME sync event was found, but scheduled task '{0}' exists and is enabled." -f $TaskName) -Level 'DEBUG'
            return @($reasons)
        }

        $reasons.Add("No Intune Management Extension sync was detected within the last $LookbackHours hour(s), and scheduled task '$TaskName' is missing or disabled")
    }
    catch {
        throw "Failed to evaluate IME sync state: $($_.Exception.Message)"
    }

    return @($reasons)
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> banner -> compliance checks -> exit 0 compliant / 1 non-compliant / 2 error.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Detection started" -Level 'INFO'
    Write-Log -Message ("Checking log name: {0}" -f $LogName) -Level 'DEBUG'
    Write-Log -Message ("Checking event ID: {0}" -f $EventID) -Level 'DEBUG'
    Write-Log -Message ("Lookback window: {0} hour(s)" -f $LookbackHours) -Level 'DEBUG'
    Write-Log -Message ("Fallback task name: {0}" -f $TaskName) -Level 'DEBUG'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message 'Compliant - IME sync activity or fallback schedule present.' -Level 'SUCCESS'
    }

    foreach ($reason in $reasons) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}
