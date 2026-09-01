<#
.TITLE
    OneDrive Known Folder Move Detection Script

.SYNOPSIS
    Detects devices lacking OneDrive Known Folder Move policy configuration.

.DESCRIPTION
    Checks the OneDrive policy registry keys for silent Known Folder Move opt-in
    (KFMSilentOptIn with the tenant ID) and verifies the OneDrive sync client is
    installed. Returns exit code 1 when the KFM policy is missing or points to a
    different tenant, triggering the paired remediation that writes the policy keys.
    Desktop, Documents, and Pictures then move to OneDrive automatically at the next
    OneDrive sign-in. This script NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant (KFM configured for the expected tenant, or not applicable)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Enable-OneDriveKFM.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads OneDrive policy registry values.

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
    .\detect-Enable-OneDriveKFM.ps1
    Returns exit 1 if the KFM silent opt-in policy is not set for the tenant.

.EXAMPLE
    .\detect-Enable-OneDriveKFM.ps1
    Returns exit 2 when the script is deployed without setting $ExpectedTenantId.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - IMPORTANT: set $ExpectedTenantId to your Entra tenant ID before deploying (both scripts)
    - Devices without the OneDrive sync client are reported compliant with a note, since KFM cannot apply there
    - Logs: <SystemDrive>\IntuneLogs\onedrive-kfm\onedrive-kfm-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'onedrive-kfm'
$ScriptMode   = 'Detection'

# Set this to your Entra tenant ID before deploying
$ExpectedTenantId = "00000000-0000-0000-0000-000000000000"

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

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> banner -> compliance checks -> exit 0 compliant / 1 non-compliant / 2 error.

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }
    Write-Log -Message "Detection started" -Level 'INFO'

    if ($ExpectedTenantId -eq "00000000-0000-0000-0000-000000000000") {
        Write-Output "Configuration error: ExpectedTenantId has not been set in the detection script."
        Finish-Script -ExitCode 2 -Message "Configuration error - ExpectedTenantId has not been set" -Level 'ERROR'
    }

    # OneDrive must be present for KFM to work
    $oneDrivePaths = @(
        "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
        "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe"
    )
    $oneDriveInstalled = $false
    foreach ($path in $oneDrivePaths) {
        if (Test-Path $path) { $oneDriveInstalled = $true; break }
    }

    if (-not $oneDriveInstalled) {
        Write-Output "OneDrive sync client is not installed - KFM policy not applicable."
        Finish-Script -ExitCode 0 -Message "Compliant - OneDrive sync client not installed, KFM not applicable" -Level 'SUCCESS'
    }

    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
    $configuredTenant = $null
    if (Test-Path $policyPath) {
        $configuredTenant = (Get-ItemProperty -Path $policyPath -Name "KFMSilentOptIn" -ErrorAction SilentlyContinue).KFMSilentOptIn
    }

    if ($configuredTenant -eq $ExpectedTenantId) {
        Write-Output "KFM silent opt-in is configured for the expected tenant."
        Finish-Script -ExitCode 0 -Message "Compliant - KFM silent opt-in configured for the expected tenant" -Level 'SUCCESS'
    }

    $reasons = [System.Collections.Generic.List[string]]::new()
    if ($configuredTenant) {
        $reasons.Add("KFM silent opt-in points to a different tenant ($configuredTenant)")
    }
    else {
        $reasons.Add("KFM silent opt-in policy is not configured")
    }

    foreach ($reason in $reasons) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}

