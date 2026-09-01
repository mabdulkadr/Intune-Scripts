<#
.TITLE
    Remediation - Clear the Windows Recycle Bin

.SYNOPSIS
    Empties the Windows Recycle Bin across all volumes using Clear-RecycleBin with a direct-deletion fallback.

.DESCRIPTION
    Paired remediation for Clear-RecycleBin. Runs whenever Intune executes it because the paired
    detector intentionally always reports non-compliant. Runs Clear-RecycleBin -Force first; if
    items remain afterward, falls back to deleting $Recycle.Bin contents directly on every
    filesystem drive. Performs: (1) pre-remediation validation, (2) per-target cleanup with failure
    tracking, (3) post-remediation verification, (4) structured JSON result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,Maintenance,RecycleBin,Cleanup

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Clear-RecycleBin.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - empties Recycle Bin folders for all users on local volumes.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.x - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Clear-RecycleBin.ps1
    Empties the Recycle Bin and verifies it is empty; exits 0 on success.

.EXAMPLE
    .\remediate-Clear-RecycleBin.ps1
    Exits 1 if items remain after both cleanup passes, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - DESTRUCTIVE: emptied Recycle Bin content is permanently deleted and cannot be restored.
    - Idempotent: an already-empty Recycle Bin exits successfully without changes.
    - Logs: <SystemDrive>\IntuneLogs\Clear-RecycleBin\Clear-RecycleBin-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Clear-RecycleBin'
$ScriptMode   = 'Remediation'

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
        # At least one filesystem drive must be present for recycle bin enumeration.
        $filesystemDrives = @(Get-PSDrive -PSProvider FileSystem -ErrorAction Stop)
        if ($filesystemDrives.Count -eq 0) {
            throw "No filesystem drives were found for Recycle Bin enumeration"
        }

        $script:RecycleBinRoots = @(Get-RecycleBinRoots)
        Write-Log -Message "Discovered $($script:RecycleBinRoots.Count) accessible Recycle Bin root(s)." -Level 'INFO'

        $script:RemediationResult.PreCheckStatus += "Pre-remediation validation completed successfully"
        return $true
    }
    catch {
        Write-RemediationLog "Pre-remediation validation error: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# ============================================================================
# RECYCLE BIN ENUMERATION HELPERS (migrated legacy logic)
# ============================================================================

# Return each filesystem recycle bin root that currently exists.
function Get-RecycleBinRoots {
    $roots = foreach ($drive in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        $recycleBinRoot = Join-Path $drive.Root '$Recycle.Bin'

        try {
            if (Test-Path -LiteralPath $recycleBinRoot -ErrorAction Stop) {
                $recycleBinRoot
            }
        }
        catch {
            Write-Log -Message ("Skipping inaccessible recycle bin path: {0}" -f $recycleBinRoot) -Level 'WARNING'
        }
    }

    return $roots | Sort-Object -Unique
}

# Return real recycle bin contents, excluding the top-level SID folders themselves.
function Get-RecycleBinContent {
    $content = foreach ($recycleBinRoot in (Get-RecycleBinRoots)) {
        foreach ($rootItem in (Get-ChildItem -LiteralPath $recycleBinRoot -Force -ErrorAction SilentlyContinue)) {
            if ($rootItem.PSIsContainer) {
                Get-ChildItem -LiteralPath $rootItem.FullName -Force -Recurse -ErrorAction SilentlyContinue
            }
            else {
                $rootItem
            }
        }
    }

    return @($content)
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
        # Re-enumerate real recycle bin contents; compliant only when nothing remains.
        $remainingContent = @(Get-RecycleBinContent)
        if ($remainingContent.Count -gt 0) {
            Write-RemediationLog "$($remainingContent.Count) item(s) remain in the Recycle Bin." -Level 'Warning'
            return $false
        }
        return $true
    }
    catch {
        Write-RemediationLog "Verification could not enumerate the Recycle Bin: $($_.Exception.Message)" -Level 'Error'
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
    $script:FailedCount      = 0
    $targetCount             = 0
    $script:CmdletFailed     = $false
    $script:WasAlreadyEmpty  = $false

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    $binContentBefore = @(Get-RecycleBinContent)
    if ($binContentBefore.Count -eq 0) {
        $script:WasAlreadyEmpty = $true
        Write-RemediationLog "Recycle Bin is already empty." -Level 'Info'
    }
    else {
        Write-RemediationLog "Detected $($binContentBefore.Count) recycle bin item(s) before cleanup." -Level 'Info'
        Write-RemediationLog "Running command: Clear-RecycleBin -Force" -Level 'Info'

        $targetCount++
        $cmdletResult = Invoke-FixTarget -TargetName 'Clear-RecycleBin -Force' -Fix {
            $commandOutput = Clear-RecycleBin -Force -ErrorAction Stop 2>&1
            foreach ($line in @($commandOutput | ForEach-Object { $_.ToString().Trim() })) {
                if ($line) {
                    Write-Log -Message $line -Level 'INFO'
                }
            }
        }
        if (-not $cmdletResult) {
            $script:CmdletFailed = $true
        }

        # Legacy behavior preserved: when the built-in cmdlet leaves items behind,
        # delete the SID folder contents directly as a fallback pass.
        $remainingContent = @(Get-RecycleBinContent)
        if ($remainingContent.Count -gt 0) {
            Write-RemediationLog "$($remainingContent.Count) recycle bin item(s) remain after Clear-RecycleBin." -Level 'Warning'
            Write-RemediationLog "Running fallback cleanup by deleting recycle bin contents directly." -Level 'Warning'

            foreach ($recycleBinRoot in $script:RecycleBinRoots) {
                $targetCount++
                Invoke-FixTarget -TargetName "Direct deletion: $recycleBinRoot" -Fix {
                    foreach ($rootItem in (Get-ChildItem -LiteralPath $recycleBinRoot -Force -ErrorAction SilentlyContinue)) {
                        if ($rootItem.PSIsContainer) {
                            foreach ($childItem in (Get-ChildItem -LiteralPath $rootItem.FullName -Force -ErrorAction SilentlyContinue)) {
                                Remove-Item -LiteralPath $childItem.FullName -Force -Recurse -ErrorAction Stop
                            }
                        }
                        else {
                            Remove-Item -LiteralPath $rootItem.FullName -Force -Recurse -ErrorAction Stop
                        }
                    }
                }
            }
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
        $successMessage = if ($script:WasAlreadyEmpty) {
            'Recycle Bin is already empty.'
        }
        elseif ($script:CmdletFailed) {
            'Recycle Bin was cleared successfully using fallback cleanup.'
        }
        else {
            'Recycle Bin was cleared successfully.'
        }

        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $failedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message $successMessage -Level 'SUCCESS'
    }
    else {
        $remainingAfter = @(Get-RecycleBinContent)
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Recycle Bin cleanup did not complete. $($remainingAfter.Count) item(s) remain." -Level 'ERROR'
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
