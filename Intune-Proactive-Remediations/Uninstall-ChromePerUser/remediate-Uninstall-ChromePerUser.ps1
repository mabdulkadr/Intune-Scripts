<#
.TITLE
    Remediation - Remove Per-User Chrome

.SYNOPSIS
    Attempts to remove the per-user Chrome installation silently.

.DESCRIPTION
    Paired remediation for Uninstall-ChromePerUser. Runs only when
    detect-Uninstall-ChromePerUser.ps1 returns exit 1. Performs:
    (1) pre-remediation validation, (2) silent uninstall per matched entry using
    the original uninstall-string logic (MSI product codes via msiexec, fallback
    via cmd.exe), (3) post-remediation verification, (4) structured JSON result
    output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Chrome,Uninstall

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Uninstall-ChromePerUser.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - runs the uninstaller of the signed-in user's Chrome installation.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.2 (2025)
    - Logging and banner improvements
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Uninstall-ChromePerUser.ps1
    Runs every matched uninstaller silently and verifies removal; exits 0 on success.

.EXAMPLE
    .\remediate-Uninstall-ChromePerUser.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Requires the signed-in user context: HKCU holds the uninstall entries of
      the account running the script, so deploy with "Run this script using
      logged-on credentials: Yes" in Intune.
    - WARNING: the uninstall affects the signed-in user's Chrome profile data.
    - Idempotent: safe to run repeatedly; nothing to do when already removed.
    - Logs: <SystemDrive>\IntuneLogs\Uninstall-ChromePerUser\Uninstall-ChromePerUser-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Uninstall-ChromePerUser'
$ScriptMode   = 'Remediation'

$UninstallRegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
$BlacklistApps    = @('Google Chrome')

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
# REMEDIATION HELPERS (original uninstall-string logic preserved)
# ============================================================================

# Returns matching per-user blacklist uninstall entries.
function Get-PerUserChromeEntries {
    if (-not (Test-Path -LiteralPath $UninstallRegPath)) {
        # Missing Uninstall key means nothing is registered for this user.
        return @()
    }

    return @(
        Get-ChildItem -LiteralPath $UninstallRegPath -ErrorAction Stop |
        ForEach-Object {
            $entry = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
            if (-not $entry) { return }

            $name = if ($entry.DisplayName) { [string]$entry.DisplayName } else { [string]$entry.DisplayName_Localized }
            if (-not $name -or $BlacklistApps -notcontains $name) { return }

            [pscustomobject]@{
                Name            = $name
                UninstallString = [string]$entry.UninstallString
                RegistryPath    = $_.PSPath
            }
        }
    )
}

# Parses an uninstall string into a silent process invocation.
function Get-UninstallCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UninstallString
    )

    $trimmed = $UninstallString.Trim()

    if ($trimmed -match 'MsiExec(\.exe)?') {
        if ($trimmed -match '\{[A-Za-z0-9\-]+\}') {
            $productCode = $Matches[0]
            return [pscustomobject]@{
                FilePath     = 'msiexec.exe'
                ArgumentList = "/x $productCode /qn /norestart"
            }
        }

        return [pscustomobject]@{
            FilePath     = 'cmd.exe'
            ArgumentList = "/c $trimmed /qn /norestart"
        }
    }

    return [pscustomobject]@{
        FilePath     = 'cmd.exe'
        ArgumentList = "/c `"$trimmed --uninstall --force-uninstall --system-level --multi-install --chrome --silent`""
    }
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# ============================================================================

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # The uninstall registry view must exist before entries can be scanned.
        if (-not (Test-Path -LiteralPath $UninstallRegPath)) {
            throw "Required registry key not found: $UninstallRegPath"
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
    try {
        # Trust-but-verify: re-scan the same uninstall entries the detector read.
        # Compliant only when no blacklist entry remains for this user. Note that
        # the registry view can lag a moment behind MSI completion.
        $remainingEntries = @(Get-PerUserChromeEntries)
        if ($remainingEntries.Count -gt 0) {
            Write-RemediationLog "$($remainingEntries.Count) per-user Google Chrome uninstall entry(ies) still present after remediation" -Level 'Warning'
            return $false
        }
        return $true
    }
    catch {
        Write-RemediationLog "Verification could not re-scan uninstall entries: $($_.Exception.Message)" -Level 'Error'
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
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 0

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    $matchedEntries = @(Get-PerUserChromeEntries)

    foreach ($match in $matchedEntries) {
        $targetCount++

        Invoke-FixTarget -TargetName "Silent uninstall $($match.Name)" -Fix {
            if ([string]::IsNullOrWhiteSpace($match.UninstallString)) {
                throw "Uninstall string is missing for '$($match.Name)'."
            }

            $command = Get-UninstallCommand -UninstallString $match.UninstallString
            Write-RemediationLog "Starting silent uninstall for '$($match.Name)'." -Level 'Info'

            $process = Start-Process -FilePath $command.FilePath -ArgumentList $command.ArgumentList -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            if ($process.ExitCode -ne 0) {
                throw "Uninstall failed for '$($match.Name)'. Exit code: $($process.ExitCode)"
            }

            Write-RemediationLog "Uninstall completed for '$($match.Name)'." -Level 'Info'
        }
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

        Finish-Script -ExitCode 0 -Message "Remediation completed successfully for $targetCount uninstall entry(ies)." -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Post-remediation verification failed - remediation completed with $failedCount failure(s)." -Level 'ERROR'
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
