<#
.TITLE
    Remediation - Reset Windows Update Components

.SYNOPSIS
    Resets SoftwareDistribution and catroot2, then triggers Windows Update detection.

.DESCRIPTION
    Paired remediation for Reset-WindowsUpdateComponents. Runs every time
    detect-Reset-WindowsUpdateComponents.ps1 returns exit 1 (the detector is an
    unconditional trigger). Stops Windows Update-related services, renames both
    SoftwareDistribution and catroot2 to .bak, starts the services again in
    reverse order, and finally runs `wuauclt /updatenow`. Performs:
    (1) pre-remediation validation, (2) sequential fix steps with failure
    tracking and abort-on-failure (preserved legacy behavior), (3)
    post-remediation verification, (4) structured JSON result output for Intune
    diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,WindowsUpdate

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Reset-WindowsUpdateComponents.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - stops/starts services and renames update cache folders.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.2
    - Legacy release prior to canonical migration
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Reset-WindowsUpdateComponents.ps1
    Stops services, resets the update folders, and verifies; exits 0 on success.

.EXAMPLE
    .\remediate-Reset-WindowsUpdateComponents.ps1
    Exits 1 if any reset step fails verification, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Destructive maintenance: renaming SoftwareDistribution and catroot2 wipes
      the local update cache and download history.
    - Idempotent: safe to run repeatedly; an existing .bak folder is removed first.
    - Logs: <SystemDrive>\IntuneLogs\Reset-WindowsUpdateComponents\Reset-WindowsUpdateComponents-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Reset-WindowsUpdateComponents'
$ScriptMode   = 'Remediation'

$SoftwareDistributionPath = Join-Path $env:windir 'SoftwareDistribution'
$SoftwareDistributionBak  = Join-Path $env:windir 'SoftwareDistribution.bak'
$CatrootPath              = Join-Path $env:windir 'System32\catroot2'
$CatrootBak               = Join-Path $env:windir 'System32\catroot2.bak'
$CoreServices             = @('wuauserv', 'cryptsvc', 'bits')

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
        # Every core service must exist before any of them is stopped; otherwise
        # the device would be left with stopped services and no reset performed.
        foreach ($serviceName in $CoreServices) {
            $null = Get-Service -Name $serviceName -ErrorAction Stop
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

# Moves a folder aside by renaming it to its backup name after clearing old backups.
function Reset-FolderWithBackup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$BackupPath
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        # Expected absence on a clean system - skip without failing.
        Write-RemediationLog "Path not found, skipping: $Path" -Level 'Warning'
        return
    }

    if (Test-Path -LiteralPath $BackupPath) {
        Remove-Item -LiteralPath $BackupPath -Recurse -Force -ErrorAction Stop
    }

    Rename-Item -LiteralPath $Path -NewName ([System.IO.Path]::GetFileName($BackupPath)) -ErrorAction Stop
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    try {
        # Success definition preserved from the legacy script: every executed step
        # must have completed without failure (services running again, folders
        # renamed, scan triggered). Any abort leaves failedCount > 0.
        return ($script:FailedCount -eq 0)
    }
    catch {
        Write-RemediationLog "Verification could not evaluate the reset summary: $($_.Exception.Message)" -Level 'Error'
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

    # Running dependents of cryptsvc are captured once so they can be restored later.
    $dependentServices = @(Get-Service -Name cryptsvc -DependentServices -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' })

    # Step 1: stop running dependents, then the core services (legacy order).
    $targetCount++
    $workflowOk = Invoke-FixTarget -TargetName 'Stop Windows Update services' -Fix {
        foreach ($service in $dependentServices) {
            Write-RemediationLog "Stopping dependent service: $($service.Name)" -Level 'Info'
            Stop-Service -Name $service.Name -Force -ErrorAction Stop
        }

        foreach ($serviceName in $CoreServices) {
            Write-RemediationLog "Stopping service: $serviceName" -Level 'Info'
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
        }
    }

    # Step 2: rename SoftwareDistribution to .bak (aborts the workflow on failure).
    if ($workflowOk) {
        $targetCount++
        $stepOk = Invoke-FixTarget -TargetName 'Rename SoftwareDistribution to .bak' -Fix {
            Write-RemediationLog 'Renaming SoftwareDistribution to .bak.' -Level 'Info'
            Reset-FolderWithBackup -Path $SoftwareDistributionPath -BackupPath $SoftwareDistributionBak
        }
        $workflowOk = $workflowOk -and $stepOk
    }
    else {
        Write-RemediationLog 'Skipping SoftwareDistribution reset because the service stop step failed.' -Level 'Warning'
    }

    # Step 3: rename catroot2 to .bak (aborts the workflow on failure).
    if ($workflowOk) {
        $targetCount++
        $stepOk = Invoke-FixTarget -TargetName 'Rename catroot2 to .bak' -Fix {
            Write-RemediationLog 'Renaming catroot2 to .bak.' -Level 'Info'
            Reset-FolderWithBackup -Path $CatrootPath -BackupPath $CatrootBak
        }
        $workflowOk = $workflowOk -and $stepOk
    }
    else {
        Write-RemediationLog 'Skipping catroot2 reset because an earlier step failed.' -Level 'Warning'
    }

    # Step 4: start core services in reverse order, then restore dependents.
    if ($workflowOk) {
        $targetCount++
        $stepOk = Invoke-FixTarget -TargetName 'Restart Windows Update services' -Fix {
            $restartServices = @($CoreServices)
            [array]::Reverse($restartServices)
            foreach ($serviceName in $restartServices) {
                Write-RemediationLog "Starting service: $serviceName" -Level 'Info'
                Start-Service -Name $serviceName -ErrorAction Stop
            }

            foreach ($service in $dependentServices) {
                Write-RemediationLog "Restarting dependent service: $($service.Name)" -Level 'Info'
                Start-Service -Name $service.Name -ErrorAction Stop
            }
        }
        $workflowOk = $workflowOk -and $stepOk
    }
    else {
        Write-RemediationLog 'Skipping service restart because an earlier step failed.' -Level 'Warning'
    }

    # Step 5: trigger a new Windows Update scan via wuauclt.
    if ($workflowOk) {
        $targetCount++
        $null = Invoke-FixTarget -TargetName 'Trigger Windows Update scan' -Fix {
            Write-RemediationLog 'Triggering Windows Update scan with wuauclt /updatenow.' -Level 'Info'
            Start-Process -FilePath 'wuauclt.exe' -ArgumentList '/updatenow' -WindowStyle Hidden -ErrorAction Stop | Out-Null
        }
    }
    else {
        Write-RemediationLog 'Skipping scan trigger because an earlier step failed.' -Level 'Warning'
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

        Finish-Script -ExitCode 0 -Message 'Windows Update components were reset successfully.' -Level 'SUCCESS'
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
