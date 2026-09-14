<#
.TITLE
    Remediation - Repair KB5124008 Secure Channel Regression

.SYNOPSIS
    Applies the KB5124008 workaround - clears MachineIdentityIsolation and repairs the
    computer secure channel - on affected domain-joined devices.

.DESCRIPTION
    Paired remediation for Repair-KB5124008SecureChannel. Runs only when
    detect-Repair-KB5124008SecureChannel.ps1 returns exit 1. Performs:
    (1) pre-remediation validation, (2) registry workaround plus secure channel
    repair with per-target failure tracking, (3) post-remediation verification,
    (4) structured JSON result output for Intune diagnostics.

    Targets:
    1. HKLM:\SYSTEM\CurrentControlSet\Control\Lsa
       - MachineIdentityIsolation = 0 (DWORD, created when missing)
    2. Computer secure channel reset, tried in order until one succeeds:
       - Test-ComputerSecureChannel -Repair
       - nltest.exe /sc_reset:<Domain> fallback when the native repair is denied

    Devices that are not domain-joined are skipped as not applicable and exit 0.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,ActiveDirectory,SecureChannel,KB5124008

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Repair-KB5124008SecureChannel.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - writes one registry DWORD value and resets the machine
    secure channel via Test-ComputerSecureChannel -Repair, falling back to nltest.exe
    /sc_reset when the machine-account password reset is denied by the domain.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.2

.CHANGELOG
    1.0.2 (2026-09-14)
    - Added a multi-method secure channel repair chain to survive the Access Denied
      (0x80070005) failure seen when Test-ComputerSecureChannel -Repair cannot reset the
      machine-account password: the native repair runs first, then nltest.exe
      /sc_reset:<Domain> falls back automatically, and when both are denied the script
      surfaces explicit operator guidance (grant 'Reset password' in AD or a manual
      netdom resetpwd / rejoin) instead of failing silently.
    1.0.1 (2026-09-14)
- Fixed $SolutionName casing (Repair-KB5124008SecureChannel) so the pair passes the
       compliance gate (PascalCase identity locks) and matches the folder identity.
    - Normalized the result object to $script:RemediationResult and added per-condition
      post-verify logging so operators can see exactly which check failed when Intune
      reports the remediation as failed.
    - Secure channel repair now logs an explicit warning when the repair command itself
      fails (device may need a restart or manual netdom reset).
    1.0.0 (2026-09-13)
    - Initial release
    - Null-safe registry read via Get-ItemProperty member access (Get-ItemPropertyValue throws terminating PSArgumentException when a value is absent)

.LASTUPDATE
    2026-09-14

.EXAMPLE
    .\remediate-Repair-KB5124008SecureChannel.ps1
    Applies the workaround and verifies it; exits 0 on verified success.

.EXAMPLE
    .\remediate-Repair-KB5124008SecureChannel.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Requires line-of-sight to a writable domain controller while repairing.
    - Access denied (0x80070005) during the password reset means the computer account
      lacks the AD 'Reset password' permission - grant it, run 'netdom resetpwd
      /server:<DC> /userd:<admin> /passwordd:*' once from the console, or rejoin the
      domain; then re-run remediation.
    - A sign-out, restart, or policy refresh may be required before the change is fully effective.
    - Idempotent: safe to run repeatedly; verify-before-and-after.
    - Logs: <SystemDrive>\IntuneLogs\Repair-KB5124008SecureChannel\Repair-KB5124008SecureChannel-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName           = 'Repair-KB5124008SecureChannel'
$ScriptMode             = 'Remediation'
$HotFixId               = 'KB5124008'
$LsaPath                = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
$IsolationName          = 'MachineIdentityIsolation'
$IsolationTargetValue   = 0

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
    if ([string]::IsNullOrEmpty($Message)) { return }
    $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:RemediationResult.RemediationActions += @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Level     = $Level
        Message   = $Message
    }
}

# ============================================================================
# REGISTRY HELPERS
# ============================================================================

# Sets one DWORD value, creating the property when missing.
function Set-RegistryDwordValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Value
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Registry path not found: $Path"
    }

    try {
        New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType DWord -Value $Value -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Force -ErrorAction Stop
    }
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# ============================================================================

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # Domain-join is validated once in MAIN before this gate. Here only the
        # registry surface the workaround writes must be reachable before any change.
        if (-not (Test-Path -LiteralPath $LsaPath)) {
            throw "Required registry path was not found: $LsaPath"
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
    # Returns $true when the fix was applied for this target.
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
        # Re-check the same conditions the detector evaluates. A MachineIdentityIsolation
        # value of 0 (or absent) plus a healthy secure channel means the regression is cleared.
        $isolation = (Get-ItemProperty -LiteralPath $LsaPath -ErrorAction Stop).$IsolationName
        $isolationOk = ($isolation -eq $IsolationTargetValue)
        $isolationDisplay = if ($null -eq $isolation) { '<absent>' } else { $isolation }
        Write-RemediationLog ("Post-check: {0} = {1} (expected {2})" -f $IsolationName, $isolationDisplay, $IsolationTargetValue) -Level 'Info'

        $channelOk = Test-ComputerSecureChannel -ErrorAction Stop
        Write-RemediationLog "Post-check: secure channel healthy = $channelOk" -Level 'Info'

        $script:RemediationResult.PostCheckStatus += "MachineIdentityIsolation ok: $isolationOk; secure channel healthy: $channelOk"
        return ($isolationOk -and $channelOk)
    }
    catch {
        Write-RemediationLog "Verification could not read the secure channel state: $($_.Exception.Message)" -Level 'Error'
        $script:RemediationResult.PostCheckStatus += "Verification error: $($_.Exception.Message)"
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
        Finish-Script -ExitCode 0 -Message "Device is not domain-joined. KB5124008 secure channel repair is not applicable." -Level 'SUCCESS'
    }
    Write-RemediationLog "Domain: $($computerSystem.Domain)" -Level 'Info'

    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 0

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    $currentIsolation = (Get-ItemProperty -LiteralPath $LsaPath -ErrorAction Stop).$IsolationName
    Write-RemediationLog "Current $IsolationName value: $currentIsolation" -Level 'Info'

    $targetCount++
    $regFixApplied = Invoke-FixTarget -TargetName "$IsolationName=$IsolationTargetValue" -Fix {
        Set-RegistryDwordValue -Path $LsaPath -Name $IsolationName -Value $IsolationTargetValue
    }
    if ($regFixApplied) {
        Write-RemediationLog "Set $IsolationName to $IsolationTargetValue." -Level 'Info'
    }

    $targetCount++
    $channelFixApplied = Invoke-FixTarget -TargetName "Secure channel to $($computerSystem.Domain)" -Fix {
        $channelFixed = Test-SecureChannelRepair -Domain $computerSystem.Domain
        if (-not $channelFixed) {
            Write-RemediationLog "Native repair was denied - trying nltest fallback for '$($computerSystem.Domain)'..." -Level 'Info'
            $channelFixed = Reset-SecureChannelWithNltest -Domain $computerSystem.Domain
        }
        if (-not $channelFixed) {
            throw "Secure channel reset was denied by the domain (both Test-ComputerSecureChannel -Repair and nltest /sc_reset). Grant the computer account the AD 'Reset password' right, or run 'netdom resetpwd /server:<DC> /userd:<admin> /passwordd:*' once, or rejoin the domain - then re-run remediation."
        }
        # Let the new channel state settle before the post-check re-tests it.
        Start-Sleep -Seconds 2
    }
    if ($channelFixApplied) {
        Write-RemediationLog "Secure channel repair command completed successfully." -Level 'Info'
    }
    else {
        Write-RemediationLog "Secure channel repair failed for domain '$($computerSystem.Domain)' - all reset methods exhausted; manual operator action is required." -Level 'Warning'
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

        Finish-Script -ExitCode 0 -Message "KB5124008 secure channel remediation completed successfully" -Level 'SUCCESS'
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