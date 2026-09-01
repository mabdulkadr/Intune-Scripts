<#
.TITLE
    Reboot Pending Detection Script

.SYNOPSIS
    Detects devices that have a pending reboot older than the configured threshold.

.DESCRIPTION
    Checks the standard Windows pending-reboot signals: Component Based Servicing,
    Windows Update, pending file rename operations, and pending computer rename.
    Returns exit code 1 when a reboot is pending and the device has been up longer
    than the minimum uptime threshold, triggering the paired remediation that
    schedules a restart with user warning. This script NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant (no actionable pending reboot)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Restart-PendingReboot.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads pending-reboot registry keys and last boot time.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.1

.CHANGELOG
    1.0.1 (2026-08-26)
    - Migrated to Enterprise Admin standards
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Restart-PendingReboot.ps1
    Returns exit 1 if a reboot is pending and uptime exceeds the threshold.

.EXAMPLE
    .\detect-Restart-PendingReboot.ps1
    Returns exit 2 when uptime cannot be determined.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - $MinimumUptimeDays avoids flagging devices that rebooted recently but picked up a new pending flag
    - PendingFileRenameOperations alone is noisy (installers set it constantly), so it only counts together with uptime
    - Logs: <SystemDrive>\IntuneLogs\reboot-pending\reboot-pending-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Restart-PendingReboot'
$ScriptMode   = 'Detection'

# Only flag devices that have not rebooted for at least this long
$MinimumUptimeDays = 2

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

# Returns a reason string per pending-reboot signal; empty output = no reboot pending.
function Test-PendingReboot {
    $reasons = [System.Collections.Generic.List[string]]::new()

    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $reasons.Add("Component Based Servicing")
    }

    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $reasons.Add("Windows Update")
    }

    try {
        $pendingRenames = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
        if ($pendingRenames) {
            $reasons.Add("Pending file rename operations")
        }
    }
    catch {
        # Value not present - nothing pending
    }

    try {
        $activeName = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" -Name ComputerName -ErrorAction SilentlyContinue).ComputerName
        $pendingName = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" -Name ComputerName -ErrorAction SilentlyContinue).ComputerName
        if ($activeName -and $pendingName -and $activeName -ne $pendingName) {
            $reasons.Add("Pending computer rename ($activeName -> $pendingName)")
        }
    }
    catch {
        # Ignore - rename detection is best effort
    }

    return @($reasons)
}

# Returns uptime plus every pending-reboot signal; reporting happens in MAIN.
function Test-ComplianceState {
    $lastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    $uptimeDays = [math]::Round(((Get-Date) - $lastBoot).TotalDays, 1)

    $pendingReasons = @(Test-PendingReboot)

    Write-Log -Message "Uptime: $uptimeDays days (threshold: $MinimumUptimeDays days)" -Level 'DEBUG'

    return @{
        UptimeDays     = $uptimeDays
        PendingReasons = $pendingReasons
    }
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

    $state          = Test-ComplianceState
    $uptimeDays     = $state.UptimeDays
    $pendingReasons = @($state.PendingReasons)

    if ($pendingReasons.Count -eq 0) {
        Write-Output "No reboot pending. Uptime: $uptimeDays days."
        Finish-Script -ExitCode 0 -Message "Compliant - no reboot pending" -Level 'SUCCESS'
    }

    if ($uptimeDays -lt $MinimumUptimeDays) {
        Write-Output "Reboot pending ($($pendingReasons -join '; ')) but uptime is only $uptimeDays days - below the $MinimumUptimeDays day threshold."
        Write-Log -Message "Reboot pending but uptime below threshold - treated as compliant" -Level 'INFO'
        Finish-Script -ExitCode 0 -Message "Compliant - pending reboot below the uptime threshold" -Level 'SUCCESS'
    }

    foreach ($reason in $pendingReasons) {
        Write-Output "Reboot pending for $uptimeDays days: $reason"
        Write-Log -Message "Non-compliant: Reboot pending for $uptimeDays days: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($pendingReasons.Count) pending-reboot signal(s) over the uptime threshold" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}


