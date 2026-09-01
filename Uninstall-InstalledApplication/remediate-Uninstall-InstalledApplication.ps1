<#
.TITLE
    Remediation - Uninstall Blacklisted Applications

.SYNOPSIS
    Attempts to silently uninstall every configured blacklisted application found on the device.

.DESCRIPTION
    Paired remediation for Uninstall-InstalledApplication. Runs only when
    detect-Uninstall-InstalledApplication.ps1 returns exit 1. Searches the
    standard 64-bit and 32-bit HKLM uninstall registry locations, matches
    entries against the configurable blacklist array, reads each uninstall
    string, and launches the matching silent uninstall: msiexec.exe /x ... /qn
    for MSI-based entries, or the vendor command via cmd.exe with /S appended.
    Performs: (1) pre-remediation validation, (2) per-application uninstall with
    failure tracking, (3) post-remediation verification, (4) structured JSON
    result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Uninstall,Blacklist

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Uninstall-InstalledApplication.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - launches silent uninstallers for blacklisted products.

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
    .\remediate-Uninstall-InstalledApplication.ps1
    Uninstalls every detected blacklisted application and verifies; exits 0 on verified success.

.EXAMPLE
    .\remediate-Uninstall-InstalledApplication.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Edit $BlacklistApps to control which display names are targeted.
    - Idempotent: safe to run repeatedly; verify-before-and-after.
    - Logs: <SystemDrive>\IntuneLogs\Uninstall-InstalledApplication\Uninstall-InstalledApplication-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Uninstall-InstalledApplication'
$ScriptMode   = 'Remediation'

$BlacklistApps = @(
    'APP 1'
    'APP 2'
)

$UninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

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
        # The parent uninstall keys must exist before entries can be queried or removed.
        foreach ($path in $UninstallPaths) {
            $parentKey = $path -replace '\\\*$', ''
            if (-not (Test-Path -LiteralPath $parentKey)) {
                throw "Required registry key not found: $parentKey"
            }
        }

        # Resolve blacklist matches once so the fix phase works against known state.
        $script:TargetApps = @(Get-ItemProperty -Path $UninstallPaths -ErrorAction SilentlyContinue |
            ForEach-Object {
                $name = if ($_.DisplayName) { [string]$_.DisplayName } else { [string]$_.DisplayName_Localized }
                if (-not $name -or $BlacklistApps -notcontains $name) { return }

                [pscustomobject]@{
                    Name            = $name
                    UninstallString = [string]$_.UninstallString
                    RegistryPath    = $_.PSPath
                }
            })

        if ($script:TargetApps.Count -eq 0) {
            Write-RemediationLog "No blacklisted applications were detected. Nothing to remediate." -Level 'Info'
        }
        else {
            Write-RemediationLog "Found $($script:TargetApps.Count) blacklisted application(s): $(($script:TargetApps | Select-Object -ExpandProperty Name -Unique) -join ', ')" -Level 'Info'
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

# Resolves the silent uninstall command from an uninstall string: msiexec for
# MSI products, otherwise the vendor command wrapped in cmd.exe with /S appended.
function Get-UninstallCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UninstallString
    )

    $trimmed = $UninstallString.Trim()

    if ($trimmed -match 'msiexec(\.exe)?' -and $trimmed -match '\{[A-Za-z0-9\-]+\}') {
        $productCode = $matches[0]
        return [pscustomobject]@{
            FilePath     = 'msiexec.exe'
            ArgumentList = "/x $productCode /qn /norestart"
        }
    }

    return [pscustomobject]@{
        FilePath     = 'cmd.exe'
        ArgumentList = "/c `"$trimmed /S`""
    }
}

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
        # Re-run the same query the detector used. Return $true only when no
        # blacklisted application remains registered.
        $remaining = @(Get-ItemProperty -Path $UninstallPaths -ErrorAction SilentlyContinue |
            ForEach-Object {
                $name = if ($_.DisplayName) { [string]$_.DisplayName } else { [string]$_.DisplayName_Localized }
                if (-not $name -or $BlacklistApps -notcontains $name) { return }
                $name
            })
        return ($remaining.Count -eq 0)
    }
    catch {
        Write-RemediationLog "Verification could not query the uninstall registry: $($_.Exception.Message)" -Level 'Error'
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
    $targetCount        = $script:TargetApps.Count

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    foreach ($app in $script:TargetApps) {
        if ([string]::IsNullOrWhiteSpace($app.UninstallString)) {
            # A missing uninstall string is a per-target failure, not a script error.
            $script:FailedCount++
            Write-RemediationLog "Uninstall string is missing for '$($app.Name)'" -Level 'Error'
            continue
        }

        $command = Get-UninstallCommand -UninstallString $app.UninstallString
        Write-RemediationLog "Starting uninstall for '$($app.Name)' using $($command.FilePath)" -Level 'Info'

        Invoke-FixTarget -TargetName $app.Name -Fix {
            $process = Start-Process -FilePath $command.FilePath -ArgumentList $command.ArgumentList -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            if ($process.ExitCode -ne 0) {
                throw "Uninstaller exited with code $($process.ExitCode)"
            }
            Write-RemediationLog "Uninstall completed for '$($app.Name)'" -Level 'Info'
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

        Finish-Script -ExitCode 0 -Message "Remediation completed successfully" -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Post-remediation verification failed with $failedCount failure(s)" -Level 'ERROR'
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
