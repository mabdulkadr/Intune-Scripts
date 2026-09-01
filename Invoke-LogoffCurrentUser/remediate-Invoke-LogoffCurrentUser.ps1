<#
.TITLE
    Remediation - Log Off Current User With Warning

.SYNOPSIS
    Shows a warning, waits for the configured timeout, and then logs off the current user.

.DESCRIPTION
    Paired remediation for Invoke-LogoffCurrentUser. Runs only when
    detect-Invoke-LogoffCurrentUser.ps1 returns exit 1. Performs: (1) pre-remediation
    validation that shutdown.exe is available and records the execution identity,
    (2) an interactive warning dialog plus a countdown with failure tracking,
    (3) post-remediation verification that the sign-out command was accepted,
    (4) structured JSON result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Session,AlwaysTrigger

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Invoke-LogoffCurrentUser.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - displays a warning and signs out the current user.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.3
    - Warning dialog, countdown timeout, and shutdown.exe sign-out flow
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Invoke-LogoffCurrentUser.ps1
    Warns the user, waits 60 seconds, and signs out; exits 0 on verified success.

.EXAMPLE
    .\remediate-Invoke-LogoffCurrentUser.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Intended for an interactive user session via Intune (user context).
    - shutdown.exe /l does not support /t or /f; the delay is handled in-script.
    - Verification semantics: an accepted shutdown.exe request (exit code 0) is the
      guaranteed outcome - the session ends asynchronously after the command returns.
    - Logs: <SystemDrive>\IntuneLogs\Invoke-LogoffCurrentUser\Invoke-LogoffCurrentUser-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Invoke-LogoffCurrentUser'
$ScriptMode   = 'Remediation'

$TimeoutSeconds = 60

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
        # shutdown.exe must exist before any logoff flow starts.
        $shutdownPath = Join-Path $env:SystemRoot 'System32\shutdown.exe'
        if (-not (Test-Path -LiteralPath $shutdownPath)) {
            throw 'shutdown.exe was not found.'
        }

        # Record who runs this so operators can diagnose SYSTEM vs user context.
        Write-RemediationLog "Running as: $(Get-ExecutionIdentity)" -Level 'Info'

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

# Return a readable identity string for the current process.
function Get-ExecutionIdentity {
    try {
        $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

        if ($currentIdentity.IsSystem) {
            return 'NT AUTHORITY\SYSTEM'
        }

        return $currentIdentity.Name
    }
    catch {
        return $env:USERNAME
    }
}

# Display a modal logoff warning; failure to show it aborts the flow.
function Show-LogoffWarning {
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop

        $message = "You will be signed out in $TimeoutSeconds seconds. Please save your work now."
        $caption = 'Logoff Warning'

        [System.Windows.MessageBox]::Show($message, $caption, 'OK', 'Warning') | Out-Null
        Write-RemediationLog 'Displayed logoff warning dialog.' -Level 'Info'
    }
    catch {
        throw "Failed to display warning dialog. $($_.Exception.Message)"
    }
}

# Wait the configured countdown before signing out.
function Start-LogoffCountdown {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Seconds
    )

    Write-RemediationLog "Waiting $Seconds second(s) before sign-out." -Level 'Warning'
    Start-Sleep -Seconds $Seconds
}

# Issue the sign-out command using shutdown.exe /l.
function Start-UserLogoff {
    $shutdownPath = Join-Path $env:SystemRoot 'System32\shutdown.exe'

    if (-not (Test-Path -LiteralPath $shutdownPath)) {
        throw 'shutdown.exe was not found.'
    }

    Write-RemediationLog 'Issuing sign-out command using shutdown.exe /l.' -Level 'Warning'

    $process = Start-Process -FilePath $shutdownPath -ArgumentList '/l' -WindowStyle Hidden -PassThru -Wait -ErrorAction Stop

    if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
        throw ("shutdown.exe returned exit code {0}." -f $process.ExitCode)
    }

    $script:LogoffInitiated = $true
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    # Sign-out initiation is the guaranteed outcome: shutdown.exe /l accepted the
    # request (exit code 0). The session ends asynchronously, so completion of the
    # logoff itself cannot be observed from this process afterwards.
    return ($script:LogoffInitiated -eq $true)
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
    Write-RemediationLog "Starting logoff workflow with a $TimeoutSeconds-second timeout." -Level 'Warning'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount      = 0
    $targetCount             = 0
    $script:LogoffInitiated  = $false

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    $targetCount++
    Invoke-FixTarget -TargetName 'Current interactive user session' -Fix {
        Show-LogoffWarning
        Start-LogoffCountdown -Seconds $TimeoutSeconds
        Start-UserLogoff
    }

    # --- Verify ---
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

        Finish-Script -ExitCode 0 -Message 'Current-user sign-out was initiated successfully.' -Level 'SUCCESS'
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
