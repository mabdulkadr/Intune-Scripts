<#
.TITLE
    Remediation - Trigger Intune Management Extension Activity

.SYNOPSIS
    Restarts or starts the IME service and verifies that new IME log activity appears.

.DESCRIPTION
    Paired remediation for IntuneIMESync. Runs only when
    detect-IntuneSyncTrigger.ps1 returns exit 1. Performs: (1) pre-remediation
    validation (elevation and service existence), (2) service restart/start with
    failure tracking, (3) post-remediation verification of service state plus a
    newer IME log write, (4) structured JSON result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Intune,IME,Sidecar

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-IntuneSyncTrigger.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - restarts the Intune Management Extension service.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    2.0
    - Service restart with log-freshness verification and configurable wait
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-IntuneSyncTrigger.ps1
    Restarts the IME service and verifies new log activity; exits 0 on verified success.

.EXAMPLE
    .\remediate-IntuneSyncTrigger.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Verification semantics: a newer IME log write confirms activity was triggered;
      it does NOT guarantee any specific policy or app finished processing.
    - Logs: <SystemDrive>\IntuneLogs\IntuneIMESync\IntuneIMESync-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'IntuneSyncTrigger'
$ScriptMode   = 'Remediation'

# IME service and log settings
$ServiceName         = 'IntuneManagementExtension'
$ImeLogRoot          = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$ImeMainLog          = Join-Path $ImeLogRoot 'IntuneManagementExtension.log'
$WaitAfterRestartSec = 30

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
        # IME remediation requires elevation; Intune normally provides SYSTEM context.
        $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal       = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Administrative privileges are required.'
        }

        # The IME service must exist before it can be restarted.
        if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
            throw "Required service not found: $ServiceName"
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

# Return the last write time of the IME log if it exists; otherwise $null.
function Get-ImeLogLastWriteTime {
    if (Test-Path -LiteralPath $ImeMainLog) {
        try {
            return (Get-Item -LiteralPath $ImeMainLog -ErrorAction Stop).LastWriteTime
        }
        catch {
            return $null
        }
    }

    return $null
}

# Return a readable time span string.
function Get-AgeText {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$DateTimeValue
    )

    $span = New-TimeSpan -Start $DateTimeValue -End (Get-Date)
    return ('{0} day(s), {1} hour(s), {2} minute(s), {3} second(s)' -f $span.Days, $span.Hours, $span.Minutes, $span.Seconds)
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    try {
        # The service must be running again after the restart.
        $imeService = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($imeService.Status -ne 'Running') {
            Write-RemediationLog 'IME service is not running after remediation.' -Level 'Error'
            return $false
        }

        # Activity guarantee: the main IME log must reflect post-action activity.
        $afterLogWriteTime = Get-ImeLogLastWriteTime
        if (-not $afterLogWriteTime) {
            Write-RemediationLog 'IME main log was not found after remediation.' -Level 'Error'
            return $false
        }
        Write-RemediationLog "IME log last write time after action: $afterLogWriteTime" -Level 'Info'

        if ($script:BeforeLogWriteTime -and $afterLogWriteTime -gt $script:BeforeLogWriteTime) {
            return $true
        }

        if (-not $script:BeforeLogWriteTime) {
            Write-RemediationLog 'IME log is now present after remediation. This is treated as successful activity.' -Level 'Info'
            return $true
        }

        Write-RemediationLog 'IME service changed successfully, but no newer IME log activity was detected.' -Level 'Warning'
        return $false
    }
    catch {
        Write-RemediationLog "Verification failed: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> pre-checks -> per-target fix -> post-verify -> exit 0 / 1 / 2.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-RemediationLog "Starting remediation..." -Level 'Info'
    Write-RemediationLog "Wait after restart: $WaitAfterRestartSec second(s)" -Level 'Info'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 0

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    # Capture current log timestamp before the service action.
    $script:BeforeLogWriteTime = Get-ImeLogLastWriteTime
    if ($script:BeforeLogWriteTime) {
        Write-RemediationLog "IME log last write time before action: $($script:BeforeLogWriteTime)" -Level 'Info'
        Write-RemediationLog "IME log age before action: $(Get-AgeText -DateTimeValue $script:BeforeLogWriteTime)" -Level 'Info'
    }
    else {
        Write-RemediationLog 'IME main log was not found before remediation.' -Level 'Warning'
    }

    $targetCount++
    $imeServiceState = (Get-Service -Name $ServiceName -ErrorAction Stop).Status
    Write-RemediationLog "Current IME service state: $imeServiceState" -Level 'Info'

    Invoke-FixTarget -TargetName $ServiceName -Fix {
        if ($imeServiceState -eq 'Running') {
            Write-RemediationLog 'Restarting Intune Management Extension service...' -Level 'Info'
            Restart-Service -Name $ServiceName -Force -ErrorAction Stop
            Write-RemediationLog 'Intune Management Extension service restarted successfully.' -Level 'Info'
        }
        else {
            Write-RemediationLog 'Starting Intune Management Extension service...' -Level 'Info'
            Start-Service -Name $ServiceName -ErrorAction Stop
            Write-RemediationLog 'Intune Management Extension service started successfully.' -Level 'Info'
        }
    }

    # --- Verify ---
    Write-RemediationLog "Waiting $WaitAfterRestartSec second(s) for IME activity..." -Level 'Info'
    Start-Sleep -Seconds $WaitAfterRestartSec

    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $failedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $failedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Remediation completed successfully" -Level 'SUCCESS'
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


