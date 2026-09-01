<#
.TITLE
    Remediation - Repair Windows System Health

.SYNOPSIS
    Repairs the Windows component store and system file integrity issues.

.DESCRIPTION
    Paired remediation for detect-Windows-SystemHealth-Repair.ps1. Runs only when the
    detector returns exit 1. Executes DISM RestoreHealth followed by SFC
    /scannow, classifies the SFC result from its console output, and checks the
    pending-reboot state before and after the repair. Preserved legacy exit
    behavior: when a reboot is required to finalize repairs the script exits
    with the industry-standard code 3010 instead of 0. Performs: (1)
    pre-remediation validation, (2) repair execution with failure tracking,
    (3) post-remediation verification, (4) structured JSON result output for
    Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 3010 = success, but a reboot is required to finalize repairs (legacy MSI convention)
    Exit 1 = failure (repair could not be completed)
    Exit 2 = script error

.TAGS
    Remediation,Action,DISM,SFC,SystemHealth

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Windows-SystemHealth-Repair.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - runs DISM RestoreHealth and SFC /scannow repairs.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / fix / post-verify flow with JSON result output
    1.1
    - Legacy release
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Windows-SystemHealth-Repair.ps1
    Runs DISM RestoreHealth and SFC /scannow; exits 0 on success or 3010 when a reboot is required.

.EXAMPLE
    .\remediate-Windows-SystemHealth-Repair.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - DISM RestoreHealth can run for an extended period; allow generous Intune timeouts.
    - Exit 3010 is preserved from the legacy script so downstream automation can schedule a reboot.
    - Logs: <SystemDrive>\IntuneLogs\WindowsSystemHealth\WindowsSystemHealth-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Windows-SystemHealth-Repair'
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

# Runs an external command and captures its exit code plus stdout/stderr.
function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$Arguments
    )

    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName               = $FilePath
    $StartInfo.Arguments              = $Arguments
    $StartInfo.UseShellExecute        = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError  = $true
    $StartInfo.CreateNoWindow         = $true

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $StartInfo

    [void]$Process.Start()

    $StandardOutput = $Process.StandardOutput.ReadToEnd()
    $StandardError  = $Process.StandardError.ReadToEnd()

    $Process.WaitForExit()

    return [pscustomobject]@{
        ExitCode = $Process.ExitCode
        StdOut   = $StandardOutput
        StdErr   = $StandardError
    }
}

# Checks common reboot pending indicators across CBS, Windows Update, and
# PendingFileRenameOperations.
function Test-RebootPending {
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        return $true
    }

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        return $true
    }

    try {
        $PendingRename = Get-ItemProperty `
            -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
            -Name 'PendingFileRenameOperations' `
            -ErrorAction SilentlyContinue

        if ($PendingRename -and $PendingRename.PendingFileRenameOperations) {
            return $true
        }
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        # Value absent means no pending file rename operations - not an error condition.
    }

    return $false
}

# Evaluates SFC output and returns a simple result classification.
function Get-SfcResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputText
    )

    if ($OutputText -match 'did not find any integrity violations') {
        return 'NoIssues'
    }

    if ($OutputText -match 'successfully repaired') {
        return 'Repaired'
    }

    if ($OutputText -match 'unable to fix some') {
        return 'Unrepaired'
    }

    return 'Unknown'
}

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # The repair tools must be resolvable before any repair can run.
        foreach ($tool in 'dism.exe', 'sfc.exe') {
            if (-not (Get-Command -Name $tool -ErrorAction SilentlyContinue)) {
                throw "Required tool not found: $tool"
            }
        }

        # Record the reboot state before the repair starts.
        $script:RebootPendingBefore = Test-RebootPending
        Write-RemediationLog "Reboot pending before repair: $($script:RebootPendingBefore)" -Level 'Info'

        if ($script:RebootPendingBefore) {
            Write-RemediationLog "A reboot is already pending before repair starts." -Level 'Warning'
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
    # The component store repair must have succeeded and SFC must not have
    # reported unrepaired integrity violations.
    return ($script:DismExitCode -eq 0 -and $script:SfcStatus -ne 'Unrepaired')
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> pre-checks -> per-target fix -> post-verify -> exit 0 / 3010 / 1 / 2.

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
    $script:FailedCount     = 0
    $targetCount            = 2
    $script:DismExitCode    = $null
    $script:SfcStatus       = $null

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    # Target 1: repair the component store first.
    Invoke-FixTarget -TargetName 'DISM RestoreHealth' -Fix {
        Write-RemediationLog "Running DISM RestoreHealth..." -Level 'Info'
        $dismResult = Invoke-ExternalCommand -FilePath 'dism.exe' -Arguments '/Online /Cleanup-Image /RestoreHealth'

        $script:DismExitCode = $dismResult.ExitCode
        Write-RemediationLog "DISM RestoreHealth exit code: $($dismResult.ExitCode)" -Level 'Info'

        if ($dismResult.StdErr) {
            Write-Log -Message "DISM standard error output: $($dismResult.StdErr.Trim())" -Level 'DEBUG'
        }

        if ($dismResult.ExitCode -ne 0) {
            throw "DISM RestoreHealth failed with exit code $($dismResult.ExitCode) - skipping SFC scan."
        }

        Write-RemediationLog "DISM RestoreHealth completed successfully" -Level 'Info'
    }

    # Target 2: run SFC after DISM, only when the component store repair succeeded.
    if ($script:DismExitCode -eq 0) {
        Invoke-FixTarget -TargetName 'SFC Scannow' -Fix {
            Write-RemediationLog "Running SFC Scannow..." -Level 'Info'
            $sfcResult = Invoke-ExternalCommand -FilePath 'sfc.exe' -Arguments '/scannow'

            Write-RemediationLog "SFC exit code: $($sfcResult.ExitCode)" -Level 'Info'

            if ($sfcResult.StdErr) {
                Write-Log -Message "SFC standard error output: $($sfcResult.StdErr.Trim())" -Level 'DEBUG'
            }

            $script:SfcStatus = Get-SfcResult -OutputText $sfcResult.StdOut

            switch ($script:SfcStatus) {
                'NoIssues' {
                    Write-RemediationLog "SFC found no integrity violations" -Level 'Info'
                }
                'Repaired' {
                    Write-RemediationLog "SFC repaired integrity violations successfully" -Level 'Info'
                }
                'Unrepaired' {
                    throw "SFC could not repair some files - review CBS.log"
                }
                default {
                    Write-RemediationLog "SFC completed with an unrecognized result - review CBS.log if needed" -Level 'Warning'
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
    if (-not $verificationPassed) {
        $script:RemediationResult.Status = "Failed"
        Write-Output "Remediation finished but verification failed"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 1 -Message "Post-remediation verification failed with $failedCount failure(s)" -Level 'ERROR'
    }

    $rebootPendingAfter = Test-RebootPending
    Write-RemediationLog "Reboot pending after repair: $rebootPendingAfter" -Level 'Info'

    if ($script:RebootPendingBefore -or $rebootPendingAfter) {
        # Preserved legacy behavior: signal a required reboot via exit 3010.
        $script:RemediationResult.Status = "SuccessRebootRequired"
        $script:RemediationResult.PostCheckStatus += "A reboot is required to finalize repairs"

        Write-Output "A reboot is required to finalize repairs"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)
        Finish-Script -ExitCode 3010 -Message "A reboot is required to finalize repairs" -Level 'WARNING'
    }

    $script:RemediationResult.Status = "Success"
    $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

    Write-Output "Remediation completed successfully"
    Write-Output "Targets processed: $targetCount (failed: $failedCount)"
    Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

    Finish-Script -ExitCode 0 -Message "Windows system health remediation completed successfully" -Level 'SUCCESS'
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


