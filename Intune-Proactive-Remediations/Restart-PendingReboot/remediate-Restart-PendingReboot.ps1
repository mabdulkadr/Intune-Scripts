<#
.TITLE
    Reboot Pending Remediation Script

.SYNOPSIS
    Schedules a restart with a visible user warning on devices that have a pending reboot.

.DESCRIPTION
    Paired remediation for reboot-pending. Runs only when detect-Restart-PendingReboot.ps1
    returns exit 1. Schedules a system restart after a configurable delay (default
    4 hours) using shutdown.exe with a warning message, giving the user time to save
    work. If a restart is already scheduled the script leaves it in place. Performs:
    (1) pre-remediation validation, (2) restart scheduling with failure tracking,
    (3) post-remediation status recording, (4) structured JSON result output for
    Intune diagnostics. Note: no read-only post-verification exists for a scheduled
    restart, so the shutdown exit code is the verification signal.

    Exit contract:
    Exit 0 = success (restart scheduled, or one was already scheduled)
    Exit 1 = failure (shutdown.exe returned an unexpected error)
    Exit 2 = script error

.TAGS
    Remediation,Action

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Restart-PendingReboot.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - schedules a Windows restart via shutdown.exe.

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
    .\remediate-Restart-PendingReboot.ps1
    Schedules a restart in 4 hours with a user-visible warning.

.EXAMPLE
    .\remediate-Restart-PendingReboot.ps1
    Exits 1 if shutdown.exe returns an unexpected error, exit 2 on script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Adjust $DelaySeconds to fit maintenance windows; users see the Windows restart warning immediately
    - A user or admin can cancel the scheduled restart with: shutdown /a
    - Logs: <SystemDrive>\IntuneLogs\reboot-pending\reboot-pending-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Restart-PendingReboot'
$ScriptMode   = 'Remediation'

# Delay before the restart fires (default 4 hours)
$script:DelaySeconds = 14400
$script:RestartMessage = "Your IT department scheduled a restart to finish installing updates. Save your work. The device restarts automatically in 4 hours. "

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

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # shutdown.exe must exist before a restart can be scheduled.
        $shutdownExe = Join-Path $env:SystemRoot "System32\shutdown.exe"
        if (-not (Test-Path -LiteralPath $shutdownExe)) {
            throw "Required executable not found: $shutdownExe"
        }

        Write-RemediationLog "Pre-remediation validation completed successfully" -Level 'Info'
        $script:RemediationResult.PreCheckStatus += "Pre-remediation validation completed successfully"
        return $true
    }
    catch {
        Write-RemediationLog "Pre-remediation validation error: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# POST-REMEDIATION STATUS
# ============================================================================

# Post-action status - no read-only query exists for a scheduled restart, so the
# shutdown.exe exit code recorded during the action is the verification signal.
function Test-FixApplied {
    try {
        $script:RemediationResult.PostCheckStatus += $script:ScheduleOutcome
        return $script:ScheduleVerified
    }
    catch {
        Write-RemediationLog "Verification could not evaluate the schedule result: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> pre-checks -> fix -> post-check -> exit 0 / 1 / 2.

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

    $targetCount      = 0
    $script:FailedCount = 0

    # --- Fix ---
    $mutationApproved = $PSCmdlet.ShouldProcess('this device', "Schedule a Windows restart in $($script:DelaySeconds) seconds")

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    if ($mutationApproved) {
        $targetCount++
        # If a shutdown is already scheduled, shutdown.exe returns error 1190;
        # leave the existing schedule untouched
        $process = Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList "/r /t $($script:DelaySeconds) /c `"$($script:RestartMessage)`"" -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            $script:ScheduleOutcome = "Restart scheduled in $([math]::Round($script:DelaySeconds / 3600, 1)) hours."
            $script:ScheduleVerified = $true
            Write-Output $script:ScheduleOutcome
        }
        elseif ($process.ExitCode -eq 1190) {
            $script:ScheduleOutcome = "A restart is already scheduled on this device - leaving it in place."
            $script:ScheduleVerified = $true
            Write-Output $script:ScheduleOutcome
        }
        else {
            $script:ScheduleOutcome = "shutdown.exe returned exit code $($process.ExitCode)"
            $script:ScheduleVerified = $false
            $script:FailedCount++
            Write-Output $script:ScheduleOutcome
            Write-RemediationLog $script:ScheduleOutcome -Level 'Warning'
        }
    }
    else {
        $script:ScheduleOutcome = "WhatIf mode - restart scheduling skipped"
        $script:ScheduleVerified = $false
        Write-RemediationLog $script:ScheduleOutcome -Level 'Warning'
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation checks..." -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $script:FailedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"

        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Remediation completed successfully" -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        if (-not $mutationApproved) {
            Write-Output "WhatIf mode - changes were not applied (verification skipped)"
        }
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


