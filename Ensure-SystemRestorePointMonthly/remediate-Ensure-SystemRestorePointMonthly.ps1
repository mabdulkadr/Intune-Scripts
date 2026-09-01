<#
.TITLE
    Remediation - Create Monthly System Restore Point

.SYNOPSIS
    Creates a valid monthly system restore point when one does not already exist.

.DESCRIPTION
    Paired remediation for Ensure-SystemRestorePointMonthly. Runs only when
    detect-Ensure-SystemRestorePointMonthly.ps1 returns exit 1. Performs:
    (1) pre-remediation validation, (2) System Protection availability check,
    (3) temporary removal of the restore point creation throttle followed by
    Checkpoint-Computer creation, (4) post-remediation verification, and
    (5) structured JSON result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (fix applied and verified)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action,SystemRestore,Recovery

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Ensure-SystemRestorePointMonthly.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - enables System Protection and creates a restore point.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Added pre-check / per-target fix / post-verify flow with JSON result output
    1.2 - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Ensure-SystemRestorePointMonthly.ps1
    Applies the fix and verifies it; exits 0 on verified success.

.EXAMPLE
    .\remediate-Ensure-SystemRestorePointMonthly.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Idempotent: safe to run repeatedly; skips creation when a valid point exists.
    - Logs: <SystemDrive>\IntuneLogs\Ensure-SystemRestorePointMonthly\Ensure-SystemRestorePointMonthly-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Ensure-SystemRestorePointMonthly'
$ScriptMode   = 'Remediation'

$CanonicalPrefix  = 'Monthly System Restore Point'
$AcceptedPrefixes = @(
    $CanonicalPrefix,
    'Intune Monthly Restore Point',
    'System Safety Restore Point'
)

try {
    $OsDrive = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).SystemDrive
}
catch {
    Write-Host "Could not resolve the OS drive from Win32_OperatingSystem: $($_.Exception.Message)" -ForegroundColor Yellow
    $OsDrive = $env:SystemDrive
}

if (-not $OsDrive) {
    $OsDrive = $env:SystemDrive
}
$OsDrive = $OsDrive.TrimEnd('\')

$Now            = Get-Date
$MonthStart     = Get-Date -Year $Now.Year -Month $Now.Month -Day 1 -Hour 0 -Minute 0 -Second 0
$NextMonthStart = $MonthStart.AddMonths(1)
$MonthTag       = '({0})' -f $MonthStart.ToString('yyyy-MM')
$Description    = '{0} {1}' -f $CanonicalPrefix, $MonthTag

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
# RESTORE POINT HELPERS
# ============================================================================

# Converts a WMI datetime string to a standard DateTime object.
function Convert-WmiDate {
    param([string]$WmiDate)

    try {
        return [System.Management.ManagementDateTimeConverter]::ToDateTime($WmiDate)
    }
    catch {
        Write-Log -Message "Unparseable WMI datetime '$WmiDate' ignored" -Level 'DEBUG'
        return $null
    }
}

# Attempts to parse different restore point time formats safely.
function Convert-ToDateTime {
    param([object]$Value)

    try {
        return [datetime]$Value
    }
    catch {
        Write-Log -Message "Value '$Value' is not directly castable to DateTime - trying explicit formats" -Level 'DEBUG'
    }

    foreach ($format in 'G', 'g', 'yyyy-MM-dd HH:mm:ss', 'MM/dd/yyyy HH:mm:ss', 'dd/MM/yyyy HH:mm:ss') {
        $parsedDate = [datetime]::MinValue
        if ([datetime]::TryParseExact([string]$Value, $format, $null, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
            return $parsedDate
        }
    }

    return $null
}

# Collects restore points from both available providers and removes duplicates.
function Get-RestorePoints {
    $collection = New-Object System.Collections.Generic.List[object]

    try {
        foreach ($restorePoint in @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue)) {
            $creationDate = Convert-ToDateTime -Value $restorePoint.CreationTime
            if ($creationDate) {
                $collection.Add([pscustomobject]@{
                    Source       = 'Get-ComputerRestorePoint'
                    Sequence     = $restorePoint.SequenceNumber
                    Description  = ($restorePoint.Description).Trim()
                    CreationTime = $creationDate
                })
            }
        }
    }
    catch {
        throw "Failed to enumerate restore points via Get-ComputerRestorePoint: $($_.Exception.Message)"
    }

    try {
        foreach ($restorePoint in @(Get-CimInstance -Namespace 'root/default' -ClassName 'SystemRestore' -ErrorAction SilentlyContinue)) {
            $creationDate = Convert-WmiDate -WmiDate $restorePoint.CreationTime
            if ($creationDate) {
                $collection.Add([pscustomobject]@{
                    Source       = 'WMI:SystemRestore'
                    Sequence     = $restorePoint.SequenceNumber
                    Description  = ($restorePoint.Description).Trim()
                    CreationTime = $creationDate
                })
            }
        }
    }
    catch {
        throw "Failed to enumerate restore points via WMI SystemRestore: $($_.Exception.Message)"
    }

    return @(
        $collection |
        Sort-Object CreationTime -Descending |
        Group-Object Sequence, Description, CreationTime |
        ForEach-Object { $_.Group | Select-Object -First 1 }
    )
}

# Determines whether a valid monthly restore point already exists.
function Test-MonthlyRestorePoint {
    foreach ($restorePoint in (Get-RestorePoints)) {
        $description = $restorePoint.Description
        $isInMonth   = ($restorePoint.CreationTime -ge $MonthStart -and $restorePoint.CreationTime -lt $NextMonthStart)
        $prefixMatch = $AcceptedPrefixes | Where-Object { $description -match [regex]::Escape($_) }
        $tagMatch    = ($description -match [regex]::Escape($MonthTag))

        if (($isInMonth -and $prefixMatch) -or $tagMatch) {
            return $true
        }
    }

    return $false
}

# ============================================================================
# PRE-REMEDIATION VALIDATION
# ============================================================================

# Gate check before any mutation - failures must not touch target state.
function Test-RemediationPrerequisites {
    try {
        # A resolvable OS drive letter is required before System Protection
        # can be enabled and a restore point created.
        if ([string]::IsNullOrWhiteSpace($OsDrive)) {
            throw "OS drive letter could not be determined"
        }

        Write-RemediationLog "OS drive resolved: $OsDrive" -Level 'Info'

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

# Ensures System Protection is available for the target drive.
function Ensure-SystemProtection {
    param([string]$Drive)

    try {
        $null = Get-ComputerRestorePoint -ErrorAction Stop
        return $true
    }
    catch {
        # Query failure indicates System Protection is not enabled yet -
        # attempt to enable it below before creating the checkpoint.
        Write-Log -Message "System Protection appears to be unavailable: $($_.Exception.Message)" -Level 'WARNING'
    }

    Write-Log -Message "System Protection is not enabled. Attempting to enable it on $Drive." -Level 'WARNING'

    try {
        Enable-ComputerRestore -Drive $Drive -ErrorAction Stop
        Start-Sleep -Seconds 2
        $null = Get-ComputerRestorePoint -ErrorAction Stop
        Write-Log -Message "System Protection enabled successfully on $Drive." -Level 'SUCCESS'
        return $true
    }
    catch {
        Write-Log -Message "Failed to enable System Protection: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

# Creates the required monthly restore point, temporarily bypassing the 24-hour throttle.
function New-MonthlyRestorePoint {
    param([string]$RestorePointDescription)

    $registryPath  = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $valueName     = 'SystemRestorePointCreationFrequency'
    $originalValue = $null
    $hadValue      = $false

    try {
        if (Test-Path -LiteralPath $registryPath) {
            try {
                $currentValue = Get-ItemProperty -LiteralPath $registryPath -Name $valueName -ErrorAction Stop
                $originalValue = $currentValue.$valueName
                $hadValue = $true
            }
            catch [System.Management.Automation.PSArgumentException], [System.Management.Automation.ItemNotFoundException] {
                # The throttle value is simply absent - there is nothing to preserve.
                Write-Log -Message "No existing $valueName value to preserve" -Level 'DEBUG'
            }

            Set-ItemProperty -LiteralPath $registryPath -Name $valueName -Value 0 -Force
            Write-Log -Message 'Temporarily cleared the restore point creation throttle.'
        }
    }
    catch {
        Write-Log -Message "Failed to modify the throttle registry value: $($_.Exception.Message)" -Level 'WARNING'
    }

    try {
        Checkpoint-Computer -Description $RestorePointDescription -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log -Message "Restore point created successfully: $RestorePointDescription" -Level 'SUCCESS'
        return $true
    }
    catch {
        Write-Log -Message "MODIFY_SETTINGS failed: $($_.Exception.Message). Trying APPLICATION_INSTALL." -Level 'WARNING'
        try {
            Checkpoint-Computer -Description $RestorePointDescription -RestorePointType APPLICATION_INSTALL -ErrorAction Stop
            Write-Log -Message 'Restore point created successfully using APPLICATION_INSTALL.' -Level 'SUCCESS'
            return $true
        }
        catch {
            Write-Log -Message "Restore point creation failed: $($_.Exception.Message)" -Level 'ERROR'
            return $false
        }
    }
    finally {
        try {
            if ($hadValue) {
                Set-ItemProperty -LiteralPath $registryPath -Name $valueName -Value $originalValue -Force
                Write-Log -Message "Restored throttle value: $originalValue"
            }
            else {
                Remove-ItemProperty -LiteralPath $registryPath -Name $valueName -ErrorAction SilentlyContinue
                Write-Log -Message 'Removed the temporary throttle override.'
            }
        }
        catch {
            Write-Log -Message 'Failed to restore the throttle registry setting.' -Level 'WARNING'
        }
    }
}

# ============================================================================
# POST-REMEDIATION VERIFICATION
# ============================================================================

# Post-fix verification - trust-but-verify before declaring exit 0.
function Test-FixApplied {
    try {
        # Re-check the same condition the detector evaluated. Return $true only
        # when a valid monthly restore point now exists.
        return (Test-MonthlyRestorePoint)
    }
    catch {
        Write-RemediationLog "Verification could not enumerate restore points: $($_.Exception.Message)" -Level 'Error'
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
    Write-Log -Message "Checking restore point compliance for month tag: $MonthTag" -Level 'INFO'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 0

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    $alreadyCompliant = $false
    try {
        $alreadyCompliant = Test-MonthlyRestorePoint
    }
    catch {
        Write-RemediationLog "Existing restore point check failed - continuing with creation: $($_.Exception.Message)" -Level 'Warning'
    }

    if ($alreadyCompliant) {
        Write-RemediationLog "A valid monthly restore point already exists. No action is required." -Level 'Info'
    }
    else {
        $targetCount++
        Invoke-FixTarget -TargetName "System Protection available on $OsDrive" -Fix {
            if (-not (Ensure-SystemProtection -Drive $OsDrive)) {
                throw "System Protection could not be enabled on $OsDrive."
            }
        }

        $targetCount++
        Invoke-FixTarget -TargetName "Monthly restore point '$Description'" -Fix {
            if (-not (New-MonthlyRestorePoint -RestorePointDescription $Description)) {
                throw "Checkpoint-Computer could not create the monthly restore point."
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
        $script:RemediationResult.Status = "Success"
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"

        Write-Output "Remediation completed successfully"
        Write-Output "Targets processed: $targetCount (failed: $failedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Monthly restore point remediation completed successfully" -Level 'SUCCESS'
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
