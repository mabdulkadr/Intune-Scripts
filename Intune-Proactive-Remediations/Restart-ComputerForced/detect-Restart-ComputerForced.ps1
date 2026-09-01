<#
.TITLE
    Detection - Windows Restart Required

.SYNOPSIS
    Detects whether Windows is waiting for a restart to finalize servicing.

.DESCRIPTION
    Checks common pending-reboot indicators in the registry: Windows Update
    RebootRequired, Component Based Servicing RebootPending,
    PendingFileRenameOperations, and a pending computer rename (ComputerName vs
    ActiveComputerName). The result is written to C:\Intune\RestartStatus.txt
    so the paired remediation can honor it ('Restart required' triggers the
    delayed reboot flow). This script NEVER modifies the system beyond that
    status file.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,Reboot,Servicing

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Restart-ComputerForced.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads pending-reboot registry indicators and writes one status file.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    1.2 (2026-02-15)
    - Legacy maintenance update
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Restart-ComputerForced.ps1
    Returns exit 0 when no restart is required; exit 1 when the paired remediation must run.

.EXAMPLE
    .\detect-Restart-ComputerForced.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Writes C:\Intune\RestartStatus.txt for the remediation scripts to consume.
    - Both remediates (delayed and immediate) pair with this single detector.
    - Logs: <SystemDrive>\IntuneLogs\Restart-ComputerForced\Restart-ComputerForced-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Restart-ComputerForced'
$ScriptMode   = 'Detection'

$StatusRoot = 'C:\Intune'
$StatusFile = Join-Path $StatusRoot 'RestartStatus.txt'

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
        [AllowEmptyString()]
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
        [AllowEmptyString()]
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

# Persists the detection verdict for the paired remediation scripts.
function Set-RestartStatusFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not (Test-Path -LiteralPath $StatusRoot)) {
        $null = New-Item -Path $StatusRoot -ItemType Directory -Force -ErrorAction Stop
    }

    Set-Content -LiteralPath $StatusFile -Value $Message -Encoding UTF8
}

# Checks every common indicator that Windows is waiting for a restart.
function Test-PendingRestart {
    $rebootRequiredWU = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    $componentBasedServicing = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    $pendingFileRenameOperations = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue).PendingFileRenameOperations

    $computerName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -ErrorAction SilentlyContinue).ComputerName
    $activeComputerName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -ErrorAction SilentlyContinue).ComputerName
    $pendingComputerRename = $computerName -and $activeComputerName -and ($computerName -ne $activeComputerName)

    return ($rebootRequiredWU -or $componentBasedServicing -or $pendingFileRenameOperations -or $pendingComputerRename)
}

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    try {
        if (Test-PendingRestart) {
            $reasons.Add("A restart is required - pending reboot indicators were found")
        }
        else {
            Write-Log -Message 'No pending reboot indicators found' -Level 'DEBUG'
        }
    }
    catch {
        throw "Failed to evaluate pending restart state: $($_.Exception.Message)"
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

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Set-RestartStatusFile -Message 'No restart required'
        Finish-Script -ExitCode 0 -Message "Compliant - no restart is required" -Level 'SUCCESS'
    }

    Set-RestartStatusFile -Message 'Restart required'

    foreach ($reason in $reasons) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    # Best-effort status update keeps the remediation pair consistent; any other
    # value than 'Restart required' makes the remediation take no action.
    try {
        Set-RestartStatusFile -Message "Detection error: $($_.Exception.Message)"
    }
    catch {
        # The status file is advisory only - never mask the original detection error.
        Write-Log -Message "Could not update the restart status file: $($_.Exception.Message)" -Level 'DEBUG'
    }

    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}
