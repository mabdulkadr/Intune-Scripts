<#
.TITLE
    OneDrive Known Folder Move Remediation Script

.SYNOPSIS
    Configures OneDrive silent Known Folder Move via policy registry keys.

.DESCRIPTION
    Paired remediation for onedrive-kfm. Runs only when
    detect-Enable-OneDriveKFM.ps1 returns exit 1. Writes the OneDrive
    policy registry values that silently move Desktop, Documents, and Pictures
    into OneDrive for the configured tenant: KFMSilentOptIn with the tenant ID,
    silent opt-in without notification, and KFMBlockOptOut so users cannot move
    the folders back out. Performs: (1) pre-remediation validation, (2) policy
    key write with failure tracking, (3) post-remediation verification by reading
    the values back, (4) structured JSON result output for Intune diagnostics.

    Exit contract:
    Exit 0 = success (policy verified after applying)
    Exit 1 = failure (verification failed after applying)
    Exit 2 = script error

.TAGS
    Remediation,Action

.REMEDIATIONTYPE
    Remediation

.PAIRSCRIPT
    detect-Enable-OneDriveKFM.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - writes OneDrive policy registry values under HKLM.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.0.1

.CHANGELOG
    1.0.1 (2026-08-26)
    - Migrated to Enterprise Admin standards
    1.0 - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\remediate-Enable-OneDriveKFM.ps1
    Writes the KFM silent opt-in policy for the configured tenant and verifies it.

.EXAMPLE
    .\remediate-Enable-OneDriveKFM.ps1
    Exits 1 if verification fails, exit 2 on unexpected script error.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - IMPORTANT: set $TenantId to your Entra tenant ID before deploying (both scripts)
    - Users must be signed in to OneDrive with a licensed account for the folder move to complete
    - Set $BlockOptOut to $false if users should be allowed to redirect folders back
    - Logs: <SystemDrive>\IntuneLogs\onedrive-kfm\onedrive-kfm-Remediation.txt
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and desired state values.
# ============================================================================

$SolutionName = 'onedrive-kfm'
$ScriptMode   = 'Remediation'

# Set this to your Entra tenant ID before deploying
$script:TenantId = "00000000-0000-0000-0000-000000000000"

# Prevent users from moving known folders back out of OneDrive
$script:BlockOptOut = $true

$script:PolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"

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
        # HKLM policy writes fail without a writable Policies hive path.
        if (-not (Test-Path -LiteralPath "HKLM:\SOFTWARE\Policies\Microsoft")) {
            throw "Required registry key not found: HKLM:\SOFTWARE\Policies\Microsoft"
        }

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
# Reads the policy values back; passes only when they match the desired state.
function Test-FixApplied {
    try {
        $appliedTenant = (Get-ItemProperty -LiteralPath $script:PolicyPath -Name "KFMSilentOptIn" -ErrorAction Stop).KFMSilentOptIn
        if ($appliedTenant -ne $script:TenantId) {
            Write-RemediationLog "Verification failed - KFMSilentOptIn is '$appliedTenant', expected '$($script:TenantId)'" -Level 'Error'
            $script:RemediationResult.PostCheckStatus += "KFMSilentOptIn does not match the configured tenant"
            return $false
        }

        if ($script:BlockOptOut) {
            $blockValue = (Get-ItemProperty -LiteralPath $script:PolicyPath -Name "KFMBlockOptOut" -ErrorAction Stop).KFMBlockOptOut
            if ($blockValue -ne 1) {
                Write-RemediationLog "Verification failed - KFMBlockOptOut is '$blockValue', expected 1" -Level 'Error'
                $script:RemediationResult.PostCheckStatus += "KFMBlockOptOut is not enabled"
                return $false
            }
        }

        Write-RemediationLog "Verification passed - KFM policy matches the desired state" -Level 'Info'
        $script:RemediationResult.PostCheckStatus += "Verification passed after remediation"
        return $true
    }
    catch {
        Write-RemediationLog "Verification could not read the policy values: $($_.Exception.Message)" -Level 'Error'
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

    if ($script:TenantId -eq "00000000-0000-0000-0000-000000000000") {
        Write-Output "Configuration error: TenantId has not been set in the remediation script."
        Finish-Script -ExitCode 2 -Message "Configuration error - TenantId has not been set" -Level 'ERROR'
    }

    # --- Pre-checks ---
    Write-RemediationLog "Performing pre-remediation checks..." -Level 'Info'
    if (-not (Test-RemediationPrerequisites)) {
        throw "Pre-remediation validation failed - aborting before any change."
    }

    $script:FailedCount = 0
    $targetCount        = 0

    # --- Fix (per-target failure tracking) ---
    $mutationApproved = $PSCmdlet.ShouldProcess($script:PolicyPath, "Write KFM silent opt-in policy for tenant $($script:TenantId)")

    Write-RemediationLog "Executing remediation actions..." -Level 'Info'

    if ($mutationApproved) {
        $targetCount++
        Invoke-FixTarget -TargetName "OneDrive KFM policy keys" -Fix {
            if (-not (Test-Path -LiteralPath $script:PolicyPath)) {
                $null = New-Item -Path $script:PolicyPath -Force
            }

            # Silent opt-in moves Desktop/Documents/Pictures without user interaction
            Set-ItemProperty -LiteralPath $script:PolicyPath -Name "KFMSilentOptIn" -Value $script:TenantId -Type String
            Set-ItemProperty -LiteralPath $script:PolicyPath -Name "KFMSilentOptInWithNotification" -Value 0 -Type DWord

            if ($script:BlockOptOut) {
                Set-ItemProperty -LiteralPath $script:PolicyPath -Name "KFMBlockOptOut" -Value 1 -Type DWord
            }
        }
    }
    else {
        Write-RemediationLog "WhatIf mode - registry writes skipped" -Level 'Warning'
    }

    # --- Verify ---
    Write-RemediationLog "Performing post-remediation verification..." -Level 'Info'
    if (-not $mutationApproved) {
        $script:RemediationResult.PostCheckStatus += "WhatIf mode - actions were not applied, verification skipped"
        $verificationPassed = $false
    }
    elseif ($script:FailedCount -ge $targetCount -and $targetCount -gt 0) {
        $verificationPassed = $false
    }
    else {
        $verificationPassed = Test-FixApplied
    }

    # --- Report ---
    if ($verificationPassed) {
        $script:RemediationResult.Status = "Success"

        Write-Output "KFM silent opt-in configured for tenant $($script:TenantId). OneDrive applies the folder move at its next sign-in or policy refresh."
        Write-Output ($remediationResult | ConvertTo-Json -Depth 6 -Compress)

        Finish-Script -ExitCode 0 -Message "Remediation completed successfully" -Level 'SUCCESS'
    }
    else {
        $script:RemediationResult.Status = "Failed"
        if (-not $mutationApproved) {
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

