<#
.TITLE
    Windows Defender Definition Update Remediation

.SYNOPSIS
    Updates Windows Defender antivirus definitions.

.DESCRIPTION
    Paired remediation for antivirus-definition-updates. Runs only when
    detect-Update-DefenderSignatures.ps1 returns exit 1. Forces a Windows
    Defender signature update, waits for the version to change (max 2 minutes),
    then verifies definition currency before reporting success. Performs:
    (1) pre-remediation validation, (2) signature update with failure tracking,
    (3) post-remediation verification, (4) structured JSON result output for
    Intune diagnostics.

    Exit contract:
    Exit 0 = success (definitions current after update)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Update-DefenderSignatures.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - triggers Defender signature updates via Update-MpSignature.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.1

.CHANGELOG
    1.0.1 (2026-08-26)
    - Migrated to Enterprise Admin standards
    1.0 - Initial version

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Update-DefenderSignatures.ps1
    Updates Defender signatures and verifies they are current; exits 0 on verified success.

.EXAMPLE
    .\remediate-Update-DefenderSignatures.ps1
    Exits 1 if definitions remain outdated after the update, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Waits up to 2 minutes for the signature version to change before verifying.
    - Idempotent: safe to run repeatedly; verify-before-and-after.
    - Logs: <SystemDrive>\IntuneLogs\antivirus-definition-updates\antivirus-definition-updates-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'Update-DefenderSignatures'
$ScriptMode   = 'Remediation'

$script:MaxDefinitionAgeHours = 48
$maxWait = 120

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
        $beforeUpdate = Get-MpComputerStatus -ErrorAction Stop
        $script:BeforeVersion = $beforeUpdate.AntivirusSignatureVersion
        Write-RemediationLog "Current version: $($script:BeforeVersion)" -Level 'Info'

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
        # Re-check the same value the detector read. Return $true only when
        # definitions are current again.
        $finalStatus = Get-MpComputerStatus -ErrorAction Stop
        $definitionAge = ((Get-Date) - $finalStatus.AntivirusSignatureLastUpdated).TotalHours
        Write-RemediationLog "Final signature version: $($finalStatus.AntivirusSignatureVersion)" -Level 'Info'
        return ($definitionAge -lt $script:MaxDefinitionAgeHours)
    }
    catch {
        Write-RemediationLog "Verification could not read Defender status: $($_.Exception.Message)" -Level 'Error'
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
    Write-Output "Starting definition update..."
    Write-RemediationLog "Starting remediation..." -Level 'Info'

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    # --- Fix (per-target failure tracking) ---
    $script:FailedCount = 0
    $targetCount        = 0
    $mutationApproved   = $PSCmdlet.ShouldProcess('Windows Defender', 'Update antivirus signatures (Update-MpSignature)')

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    $targetCount++
    if ($mutationApproved) {
        Write-Output "Downloading latest definitions..."
        Invoke-FixTarget -TargetName "Defender signature update" -Fix {
            Update-MpSignature -ErrorAction Stop

            # Wait for update to complete (max 2 minutes)
            $waited = 0
            while ($waited -lt $maxWait) {
                Start-Sleep -Seconds 10
                $waited += 10

                $currentStatus = Get-MpComputerStatus -ErrorAction Stop
                if ($currentStatus.AntivirusSignatureVersion -ne $script:BeforeVersion) {
                    Write-Output "Definitions updated to version: $($currentStatus.AntivirusSignatureVersion)"
                    break
                }
            }
        }
    }
    else {
        Write-RemediationLog "WhatIf mode - signature update skipped" -Level 'Warning'
        $script:FailedCount++
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    $verificationPassed = $false
    if (-not $mutationApproved) {
        $script:RemediationResult.PostCheckStatus += "WhatIf mode - actions were not applied, verification skipped"
    }
    elseif (Test-FixApplied) {
        $verificationPassed = $true
        $script:RemediationResult.PostCheckStatus += "Definitions are current after update"
    }
    else {
        $script:RemediationResult.PostCheckStatus += "Definitions still outdated after update"
    }

    if ($targetCount -gt 0 -and $failedCount -ge $targetCount) {
        $verificationPassed = $false
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"

        Write-Output "Update successful - Definitions are current"
        Write-Output "Targets processed: $targetCount (failed: $failedCount)"
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Remediation completed successfully" -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        if (-not $mutationApproved) {
            Write-Output "WhatIf mode - changes were not applied (verification skipped)"
        }
        else {
            Write-Output "Update may have failed - Definitions still outdated"
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


