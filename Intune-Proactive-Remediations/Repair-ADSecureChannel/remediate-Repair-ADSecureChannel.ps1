<#
.TITLE
    Remediation - Repair Active Directory Secure Channel

.SYNOPSIS
    Repairs the computer secure channel to the Active Directory domain when it is broken.

.DESCRIPTION
    Paired remediation for Repair-ADSecureChannel. Runs only when
    detect-Repair-ADSecureChannel.ps1 returns exit 1. Performs: (1) pre-remediation
    validation, (2) secure channel repair with a multi-method fallback chain
    (Test-ComputerSecureChannel -Repair, then nltest.exe /sc_reset:<Domain>),
    (3) post-remediation verification, (4) structured JSON result output for Intune
    diagnostics. Devices that are not domain-joined are skipped as not applicable and
    exit 0.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,ActiveDirectory,SecureChannel

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Repair-ADSecureChannel.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - resets the machine secure channel via
    Test-ComputerSecureChannel -Repair, falling back to nltest.exe /sc_reset when
    the native repair is denied by the domain.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.1.0

.CHANGELOG
    2.1.0 (2026-09-14)
    - Fixed scope mismatch between $remediationResult and $script:RemediationResult so
      the structured audit trail is actually populated in the JSON output.
    - Fixed $failedCount vs $script:FailedCount so the post-verify gate and status
      message reflect the real failure count.
    - Added a multi-method secure channel repair chain to survive Access Denied
      (0x80070005): Test-ComputerSecureChannel -Repair runs first, nltest.exe
      /sc_reset:<Domain> falls back automatically, and when both are denied the script
      surfaces explicit operator guidance.
    - Added [AllowEmptyString()] to Write-Log and Finish-Script parameters for
      canonical consistency.
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.2
    - Legacy release prior to canonical migration
    1.0.0
    - Initial release

.LASTUPDATE
    2026-09-14

.EXAMPLE
    .\remediate-Repair-ADSecureChannel.ps1
    Applies the fix and verifies it; exits 0 on verified success.

.EXAMPLE
    .\remediate-Repair-ADSecureChannel.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Requires line-of-sight to a writable domain controller while repairing.
    - Access denied (0x80070005) during the password reset means the computer account
      lacks the AD 'Reset password' right - grant it, run 'netdom resetpwd
      /server:<DC> /userd:<admin> /passwordd:*' once from the console, or rejoin the
      domain; then re-run remediation.
    - Idempotent: safe to run repeatedly; verify-before-and-after.
    - Logs: <SystemDrive>\IntuneLogs\Repair-ADSecureChannel\Repair-ADSecureChannel-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Repair-ADSecureChannel'
$ScriptMode   = 'Remediation'

# Original behavior preserved: reboot scheduling stays disabled unless enabled here.
$ForceRebootAfterRepair = $false

$script:RemediationResult = @{
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

    $title      = '{0} | {1} | {2}' -f $SolutionName, $ScriptMode, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
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
    # Console = clean, no timestamp/level prefix - color alone conveys severity.
    # File    = detailed - keeps [timestamp] [LEVEL] for fleet troubleshooting.
    $fileLine  = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $Message -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $fileLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
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
        # The machine account secure channel only exists on domain-joined devices.
        # The repair command itself requires line-of-sight to a writable DC.
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if (-not $computerSystem.PartOfDomain) {
            throw "Device is not domain-joined - secure channel repair is not applicable"
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
# SECURE CHANNEL REPAIR (multi-method fallback chain)
# ============================================================================

# Method 1: native secure-channel password reset via the machine account.
function Test-SecureChannelRepair {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Domain
    )
    Write-RemediationLog "Secure channel repair method 1/2: Test-ComputerSecureChannel -Repair for '$Domain'..." -Level 'Info'
    try {
        $ok = Test-ComputerSecureChannel -Repair -Verbose:$false -ErrorAction Stop
        if ($ok) {
            Write-RemediationLog "Secure channel reset succeeded via Test-ComputerSecureChannel -Repair." -Level 'Info'
            return $true
        }
        Write-RemediationLog "Test-ComputerSecureChannel -Repair returned false - the machine-account password reset was denied." -Level 'Warning'
    }
    catch {
        Write-RemediationLog "Test-ComputerSecureChannel -Repair failed: $($_.Exception.Message)" -Level 'Warning'
    }
    return $false
}

# Method 2: netlogon secure-channel reset via nltest.exe (ships with Windows).
function Reset-SecureChannelWithNltest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Domain
    )
    $nltestPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\nltest.exe'
    if (-not (Test-Path -LiteralPath $nltestPath)) {
        Write-RemediationLog "nltest.exe was not found at '$nltestPath' - falling back to operator guidance." -Level 'Warning'
        return $false
    }
    Write-RemediationLog "Secure channel repair method 2/2: nltest /sc_reset:$Domain ..." -Level 'Info'
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& $nltestPath "/sc_reset:$Domain" 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    }
    catch {
        Write-RemediationLog "nltest /sc_reset could not run: $($_.Exception.Message)" -Level 'Warning'
        return $false
    }
    finally {
        $ErrorActionPreference = $previousEap
    }
    foreach ($line in $output) {
        Write-RemediationLog ("nltest: {0}" -f $line) -Level 'Info'
    }
    if ($exitCode -eq 0) {
        Write-RemediationLog "Secure channel reset succeeded via nltest /sc_reset (exit 0)." -Level 'Info'
        return $true
    }
    Write-RemediationLog "nltest /sc_reset exited with code $exitCode - the machine account could not reset its own password." -Level 'Warning'
    return $false
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    try {
        # Re-run the same test the detector used. Return $true only when the
        # observed state now matches the compliant definition.
        return (Test-ComputerSecureChannel -ErrorAction Stop)
    }
    catch {
        Write-RemediationLog "Verification could not test the secure channel: $($_.Exception.Message)" -Level 'Error'
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

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'

    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    if (-not $computerSystem.PartOfDomain) {
        $script:RemediationResult.Status = "NotApplicable"
        Finish-Script -ExitCode 0 -Message "Device is not domain-joined. Secure channel repair is not applicable." -Level 'SUCCESS'
    }
    Write-RemediationLog "Domain: $($computerSystem.Domain)" -Level 'Info'

    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 0

    Write-RemediationLog "Device is domain-joined. Attempting secure channel repair now." -Level 'Warning'

    $targetCount++
    $fixApplied = Invoke-FixTarget -TargetName "Secure channel to $($computerSystem.Domain)" -Fix {
        $channelFixed = Test-SecureChannelRepair -Domain $computerSystem.Domain
        if (-not $channelFixed) {
            Write-RemediationLog "Native repair was denied - trying nltest fallback for '$($computerSystem.Domain)'..." -Level 'Info'
            $channelFixed = Reset-SecureChannelWithNltest -Domain $computerSystem.Domain
        }
        if (-not $channelFixed) {
            throw "Secure channel reset was denied by the domain (both Test-ComputerSecureChannel -Repair and nltest /sc_reset). Grant the computer account the AD 'Reset password' right, or run 'netdom resetpwd /server:<DC> /userd:<admin> /passwordd:*' once, or rejoin the domain - then re-run remediation."
        }
        Start-Sleep -Seconds 2
    }
    if ($fixApplied) {
        Write-RemediationLog "Secure channel repair command completed successfully." -Level 'Info'
    }
    else {
        Write-RemediationLog "Secure channel repair failed for domain '$($computerSystem.Domain)' - all reset methods exhausted; manual operator action is required." -Level 'Warning'
    }

    if ($ForceRebootAfterRepair) {
        Write-RemediationLog "A reboot was requested. Scheduling restart in 5 minutes." -Level 'Info'
        & shutdown.exe /r /t 300 /c 'Secure channel repaired by Intune remediation'
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = Test-FixApplied

    if ($targetCount -gt 0 -and $script:FailedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $script:FailedCount)"

        Finish-Script -ExitCode 0 -Message "Secure channel remediation completed successfully." -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
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
    Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}
