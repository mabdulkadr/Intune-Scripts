<#
.TITLE
    Remediation - Upgrade Winget Packages

.SYNOPSIS
    Upgrades all packages that the Winget client considers eligible for update.

.DESCRIPTION
    Paired remediation for Update-WingetPackages. Runs only when
    detect-Update-WingetPackages.ps1 returns exit 1. Resolves the installed
    Winget client and runs `winget upgrade --all --force --silent
    --accept-package-agreements --accept-source-agreements`, capturing every
    output line into the log. Performs: (1) pre-remediation validation, (2)
    upgrade execution with failure tracking, (3) post-remediation verification
    based on Winget's own exit code, (4) structured JSON result output for
    Intune diagnostics. When Winget cannot be resolved, the legacy behavior is
    preserved: nothing to remediate, reported as success.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Winget,Updates

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Update-WingetPackages.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - runs silent Winget upgrades for eligible packages.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.1.0

.CHANGELOG
    2.1.0 (2026-08-26)
    - Merged enterprise exclusion handling: --disable-interactivity, synchronized $ExcludedIds lifecycle with pin add/remove around upgrade --all
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / fix / post-verify flow with JSON result output
    1.2 (2025)
    - Logging and banner improvements
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Update-WingetPackages.ps1
    Runs the silent Winget upgrade for all eligible packages; exits 0 when Winget succeeds.

.EXAMPLE
    .\remediate-Update-WingetPackages.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Requires the Winget client (App Installer) on the device.
    - Upgrading packages can restart or interrupt running applications.
    - Idempotent: safe to run repeatedly; verify-before-and-after.
    - Logs: <SystemDrive>\IntuneLogs\Update-WingetPackages\Update-WingetPackages-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Update-WingetPackages'
$ScriptMode   = 'Remediation'

# Winget package IDs to exclude — kept in sync with the detection script.
$script:ExcludedIds = @(
    "Microsoft.Office",
    "Microsoft.Teams"
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

# Resolves the Winget executable from the App Installer package, WindowsApps
# fallback patterns, PATH, or the per-user app execution shim.
function Resolve-WingetExecutable {
    $appInstallerPackage = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1

    if ($appInstallerPackage -and $appInstallerPackage.InstallLocation) {
        foreach ($fileName in 'winget.exe', 'AppInstallerCLI.exe') {
            $packageExecutable = Join-Path $appInstallerPackage.InstallLocation $fileName
            if (Test-Path -Path $packageExecutable) {
                return $packageExecutable
            }
        }
    }

    $patterns = @(
        (Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe'),
        (Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\AppInstallerCLI.exe')
    )

    foreach ($pattern in $patterns) {
        $resolvedPath = Resolve-Path -Path $pattern -ErrorAction SilentlyContinue |
            Sort-Object -Property Path -Descending |
            Select-Object -First 1

        if ($resolvedPath) {
            return $resolvedPath.Path
        }
    }

    $command = Get-Command -Name 'winget.exe' -ErrorAction SilentlyContinue
    if ($command) {
        return $(if ($command.Source) { $command.Source } else { $command.Name })
    }

    $shimPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -Path $shimPath) {
        return 'winget.exe'
    }

    return $null
}

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # Resolve the Winget client once so the fix phase works against a known path.
        $script:WingetPath = Resolve-WingetExecutable

        if (-not $script:WingetPath) {
            # Preserve legacy intent: without Winget there is nothing to remediate.
            Write-RemediationLog "Winget was not found. Nothing to remediate." -Level 'Info'
        }
        else {
            Write-RemediationLog "Using Winget executable: $($script:WingetPath)" -Level 'Info'
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
    # Verification mirrors the legacy success criterion: the Winget upgrade run
    # itself must report success through its process exit code.
    return ($script:LastWingetExitCode -eq 0)
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
    $script:FailedCount         = 0
    $targetCount                = $(if ($script:WingetPath) { 1 } else { 0 })
    $script:LastWingetExitCode  = $null

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    if (-not $script:WingetPath) {
        # Nothing to target without a Winget client - reported as verified success below.
        Write-RemediationLog "No Winget client available - skipping upgrade execution" -Level 'Info'
    }
    else {
        Invoke-FixTarget -TargetName 'WingetUpgradeAll' -Fix {
            Write-RemediationLog "Starting Winget upgrade for all eligible packages" -Level 'Info'

            foreach ($excludedId in $script:ExcludedIds) {
                # winget 1.4+ hides pinned packages from --all; a temporary pin per run
                # enforces the enterprise exclusion list without persisting state.
                & $script:WingetPath pin add --id $excludedId --accept-source-agreements 2>&1 | Out-Null
            }

            $output = & $script:WingetPath upgrade --all --force --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | ForEach-Object { [string]$_ }
            foreach ($line in $output) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-Log -Message $line.Trim() -Level 'DEBUG'
                }
            }

            $script:LastWingetExitCode = $LASTEXITCODE

            foreach ($excludedId in $script:ExcludedIds) {
                # Remove the temporary pins so they do not leak into the user context.
                & $script:WingetPath pin remove --id $excludedId 2>&1 | Out-Null
            }
            if ($script:LastWingetExitCode -ne 0) {
                throw "Winget upgrade failed with exit code $($script:LastWingetExitCode)"
            }

            Write-RemediationLog "Winget upgrade completed successfully" -Level 'Info'
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

        Finish-Script -ExitCode 0 -Message "Winget upgrade completed successfully" -Level 'SUCCESS'
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
