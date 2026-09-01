<#
.TITLE
    Remediation - Forced Restart After Warning Delay

.SYNOPSIS
    Warns the user, waits for the configured delay, and then forces a restart.

.DESCRIPTION
    Delayed-flavor remediation paired with detect-Restart-ComputerForced.ps1.
    Runs only when the detector returns exit 1 and its status file contains
    'Restart required'. Displays two balloon-tip warnings (an initial warning
    quoting the configured delay in minutes, then a final one-minute warning),
    waits between them, and finally issues Restart-Computer -Force. The
    immediate/aggressive flavor is remediate-Restart-ComputerForcedNow.ps1,
    which skips every warning, delay, and status-file dependency.

    Exit contract:
    Exit 0 = success (restart command issued or nothing to do)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Reboot,Servicing

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Restart-ComputerForced.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - displays user notifications and forces an operating system restart.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / fix / post-verify flow with JSON result output
    1.2 (2026-02-15)
    - Legacy maintenance update
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Restart-ComputerForced.ps1
    Warns the user, waits 30 minutes by default plus a final minute, then forces the restart.

.EXAMPLE
    .\remediate-Restart-ComputerForced.ps1
    Exits 0 without action when the detection status does not say 'Restart required'.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - $DelaySeconds controls the warning period; balloon tips require an interactive session.
    - A forced restart discards unsaved work - schedule assignments carefully.
    - Logs: <SystemDrive>\IntuneLogs\Restart-ComputerForced\Restart-ComputerForced-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Restart-ComputerForced'
$ScriptMode   = 'Remediation'

# Warning delay before the forced restart (legacy default preserved).
$DelaySeconds = 1800

$StatusRoot = 'C:\Intune'
$StatusFile = Join-Path $StatusRoot 'RestartStatus.txt'

$remediationResult = @{
    Status             = "Unknown"
    PreCheckStatus     = @()
    RemediationActions = @()
    PostCheckStatus    = @()
    Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName       = $env:COMPUTERNAME
}

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

# Appends structured per-target remediation entries to the audit trail.
function Write-RemediationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",
        [ValidateSet('Info', 'Warning', 'Error')][string]$Level = 'Info'
    )
    # Console/file via canonical Write-Log + structured record for JSON output.
    $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:RemediationResult.RemediationActions += @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Level     = $Level
        Message   = $Message
    }
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# ============================================================================

# Shows a Windows balloon tip notification; requires an interactive session.
function Show-BalloonTip {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $balloon = New-Object System.Windows.Forms.NotifyIcon
        $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
        $balloon.BalloonTipText = $Text
        $balloon.BalloonTipTitle = $Title
        $balloon.Icon = [System.Drawing.SystemIcons]::Information
        $balloon.Visible = $true
        $balloon.ShowBalloonTip(10000)
        Start-Sleep -Seconds 10
        $balloon.Dispose()
    }
    catch {
        # Balloon tips are best-effort user warnings in non-interactive sessions.
        Write-RemediationLog "Unable to display balloon tip: $($_.Exception.Message)" -Level 'Warning'
    }
}

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # The detection script must have written its verdict first.
        if (-not (Test-Path -LiteralPath $StatusFile)) {
            throw "Status file not found: $StatusFile. Ensure detect-Restart-ComputerForced.ps1 has been run."
        }

        $restartStatus = (Get-Content -LiteralPath $StatusFile -Raw -ErrorAction Stop).Trim()
        Write-RemediationLog "Read restart status: $restartStatus" -Level 'Info'

        if ($restartStatus -ne 'Restart required') {
            Write-RemediationLog "No restart is required. No action taken." -Level 'Info'
            $script:RestartRequired = $false
        }
        else {
            $script:RestartRequired = $true
        }

        # Restart-Computer must be available before a restart can be forced.
        if (-not (Get-Command -Name 'Restart-Computer' -ErrorAction SilentlyContinue)) {
            throw "Required cmdlet not found: Restart-Computer"
        }

        $script:RemediationResult.PreCheckStatus += "Pre-remediation validation completed successfully"
        return $true
    }
    catch {
        Write-RemediationLog "Pre-remediation validation error: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# REMEDIATION ACTION (per-target pattern)
# ============================================================================

# Applies the fix to ONE target and returns a structured success/failure object.
function Invoke-FixTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TargetName,
        [Parameter(Mandatory = $true)][scriptblock]$Fix
    )
    # Returns $true when the fix was applied AND verified for this target.
    try {
        & $Fix
        return $true
    }
    catch {
        $script:FailedCount++
        Write-RemediationLog "Target FAILED: $TargetName - $($_.Exception.Message)" -Level 'Warning'
        return $false
    }
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    # Verification confirms the forced restart command was issued without error;
    # the device powers cycles immediately afterwards, which ends this process.
    return $script:RestartCommandIssued
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> pre-checks -> fix -> post-verify -> exit 0 / 1 / 2.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-RemediationLog "Starting remediation..." -Level 'Info'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount          = 0
    $targetCount                 = $(if ($script:RestartRequired) { 1 } else { 0 })
    $script:RestartCommandIssued = $false

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    if (-not $script:RestartRequired) {
        # Detection verdict says no restart is needed - nothing to do.
        Write-RemediationLog "No target action required - skipping restart" -Level 'Info'
    }
    else {
        Invoke-FixTarget -TargetName 'ForcedRestartWithDelay' -Fix {
            $minutesUntilRestart = [math]::Round($DelaySeconds / 60, 0)

            Show-BalloonTip -Title 'Restart Warning' -Text "Your system will restart in $minutesUntilRestart minutes. Please save your work."
            Write-RemediationLog "Waiting $DelaySeconds seconds before the forced restart" -Level 'Warning'
            Start-Sleep -Seconds $DelaySeconds

            Show-BalloonTip -Title 'Final Restart Warning' -Text 'Your system will restart in 1 minute. Please save your work now.'
            Start-Sleep -Seconds 60

            Write-RemediationLog "Forcing system restart now" -Level 'Warning'
            Restart-Computer -Force -Confirm:$false

            $script:RestartCommandIssued = $true
        }
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $failedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    if ($targetCount -eq 0) {
        # Nothing was targeted - treat as verified success so Intune sees a healthy run.
        $verificationPassed = $true
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $failedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Forced restart command issued successfully" -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Post-remediation verification failed" -Level 'ERROR'
    }
}
catch {
    $script:RemediationResult.Status = "Error"
    $script:RemediationResult.Error = @{
        Message    = $_.Exception.Message
        Type       = $_.Exception.GetType().FullName
        StackTrace = $_.ScriptStackTrace
    }
    Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
    Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}
finally {
    Write-Log -Message "Cleanup complete." -Level 'DEBUG'
}
