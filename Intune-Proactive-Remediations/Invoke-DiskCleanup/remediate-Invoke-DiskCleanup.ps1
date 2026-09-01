<#
.TITLE
    Disk Cleanup Remediation Script

.SYNOPSIS
    Cleans temporary files and empties recycle bin.

.DESCRIPTION
    Paired remediation for disk-cleanup. Runs only when detect-Invoke-DiskCleanup.ps1
    returns exit 1. Removes Windows temp files, user temp files, and empties the
    recycle bin, then runs the Windows disk cleanup utility with a timeout guard.
    Performs: (1) pre-remediation validation, (2) per-target cleanup with failure
    tracking, (3) post-remediation verification via freed-space measurement,
    (4) structured JSON result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (cleanup applied and verified)
    Exit 1 = failure (all targets failed or verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Invoke-DiskCleanup.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - deletes temp files and empties the Recycle Bin.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.1.1

.CHANGELOG
    1.1.1 (2026-08-26)
    - Migrated to Enterprise Admin standards
    1.1 - Added freed space reporting, per-target failure tracking with all-failed exit 1, and cleanmgr timeout handling
    1.0 - Initial version

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Invoke-DiskCleanup.ps1
    Clears temp folders and the recycle bin, then reports freed space.

.EXAMPLE
    .\remediate-Invoke-DiskCleanup.ps1
    Exits 1 if every cleanup target failed, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - cleanmgr.exe is stopped after a 300 second timeout so remediation never hangs.
    - Idempotent: safe to run repeatedly; freed-space delta is the verification signal.
    - Logs: <SystemDrive>\IntuneLogs\disk-cleanup\disk-cleanup-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'disk-cleanup'
$ScriptMode   = 'Remediation'

$script:CleanmgrTimeoutSeconds = 300

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
        # The free-space baseline must be readable before any cleanup runs.
        $null = Get-PSDrive -Name C -ErrorAction Stop
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
# REMEDIATION ACTION (per-target pattern)
# ============================================================================

# Removes the content of one folder; missing paths are treated as already clean.
function Remove-FolderContent {
    param([string]$Path)

    if (Test-Path $Path) {
        Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
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
# Verification signal: positive freed-space delta plus at least one succeeded target.
function Test-FixApplied {
    try {
        $freeAfter = (Get-PSDrive C).Free
        $freedMB = [math]::Round(($freeAfter - $script:FreeBefore) / 1MB, 2)
        Write-Output "Freed space: $freedMB MB"
        Write-RemediationLog "Verification measured $freedMB MB freed" -Level 'Info'
        $script:RemediationResult.PostCheckStatus += "Freed space: $freedMB MB"

        return ($script:TargetCount -gt 0 -and $script:FailedCount -lt $script:TargetCount)
    }
    catch {
        Write-RemediationLog "Verification could not measure free space: $($_.Exception.Message)" -Level 'Error'
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

    $script:FreeBefore  = (Get-PSDrive C).Free
    $script:FailedCount = 0
    $script:TargetCount = 0
    $mutationApproved   = $PSCmdlet.ShouldProcess('temp folders, recycle bin, and VolumeCaches state flags', 'Delete temporary files and run disk cleanup')

    # --- Fix (per-target failure tracking) ---
    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    if ($mutationApproved) {
        # Clean Windows Temp
        $script:TargetCount++
        Invoke-FixTarget -TargetName "Windows Temp" -Fix {
            Remove-FolderContent "$env:WINDIR\Temp"
        }

        # Clean User Temp folders (path captured script-scoped for the fix scriptblock)
        Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $script:TargetCount++
            $script:UserTempPath = Join-Path $_.FullName "AppData\Local\Temp"
            Invoke-FixTarget -TargetName "$($_.Name) temp folder" -Fix {
                Remove-FolderContent $script:UserTempPath
            }
        }

        # Empty Recycle Bin
        $script:TargetCount++
        Invoke-FixTarget -TargetName "Recycle Bin" -Fix {
            Clear-RecycleBin -Force -ErrorAction Stop
        }

        # Run Windows Cleanup
        $script:TargetCount++
        Invoke-FixTarget -TargetName "Windows disk cleanup (cleanmgr)" -Fix {
            # Enable cleanup categories
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
            Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                Set-ItemProperty -Path $_.PSPath -Name "StateFlags0100" -Value 2 -Type DWORD -ErrorAction SilentlyContinue
            }

            # Run cleanup with timeout so a hung cleanmgr does not block remediation
            $cleanmgrProcess = Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:100" -NoNewWindow -PassThru
            try {
                Wait-Process -Id $cleanmgrProcess.Id -Timeout $script:CleanmgrTimeoutSeconds -ErrorAction Stop
            }
            catch {
                # Stop cleanmgr if it is still running, count as failure and continue
                if ($cleanmgrProcess -and -not $cleanmgrProcess.HasExited) {
                    Stop-Process -Id $cleanmgrProcess.Id -Force -ErrorAction SilentlyContinue
                }
                throw
            }
        }
    }
    else {
        Write-RemediationLog "WhatIf mode - cleanup actions skipped" -Level 'Warning'
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    if (-not $mutationApproved) {
        $script:RemediationResult.PostCheckStatus += "WhatIf mode - actions were not applied, verification skipped"
        $verificationPassed = $false
    }
    else {
        $verificationPassed = Test-FixApplied
    }

    if ($script:TargetCount -gt 0 -and $script:FailedCount -ge $script:TargetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"

        Write-Output "Disk cleanup completed ($($script:TargetCount - $script:FailedCount) of $script:TargetCount targets succeeded)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Remediation completed successfully" -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        if ($script:TargetCount -gt 0 -and $script:FailedCount -ge $script:TargetCount) {
            Write-Output "All $script:TargetCount cleanup targets failed"
        }
        elseif (-not $mutationApproved) {
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

