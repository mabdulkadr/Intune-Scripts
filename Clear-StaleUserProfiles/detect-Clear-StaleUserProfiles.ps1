<#
.TITLE
    Detection - Stale Local User Profiles

.SYNOPSIS
    Detects local user profiles whose last use is older than the configured age threshold.

.DESCRIPTION
    Enumerates Win32_UserProfile via CIM and identifies local profiles whose LastUseTime is older
    than $StaleAfterDays (30 days). Excludes special/system profiles, currently loaded profiles,
    profiles without a valid local path or SID, profiles without LastUseTime, and the built-in
    Default/Public profile folders. Each stale profile becomes a non-compliance reason so Intune
    runs the paired removal remediation. This script NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,Maintenance,UserProfiles,CIM

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Clear-StaleUserProfiles.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - queries Win32_UserProfile via CIM without changes.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    1.x - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Clear-StaleUserProfiles.ps1
    Returns exit 0 when no stale profiles exist; exit 1 when one or more are found.

.EXAMPLE
    .\detect-Clear-StaleUserProfiles.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Idempotent and read-only by definition.
    - Logs: <SystemDrive>\IntuneLogs\Clear-StaleUserProfiles\Clear-StaleUserProfiles-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Clear-StaleUserProfiles'
$ScriptMode   = 'Detection'

$StaleAfterDays = 30
$CutoffDate     = (Get-Date).AddDays(-$StaleAfterDays)

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
# DETECTION LOGIC
# Return a list of reason strings so operators see every failure at once.
# Empty list = compliant. Never modify the system here.
# ============================================================================

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    try {
        $profiles = @(Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop)

        # Legacy exclusion filters preserved exactly: special, loaded, pathless, SID-less,
        # LastUseTime-less, and Default/Public profile folders are never reported.
        $staleProfiles = @(
            $profiles | Where-Object {
                $_.Special -eq $false -and
                $_.Loaded -eq $false -and
                -not [string]::IsNullOrWhiteSpace($_.LocalPath) -and
                -not [string]::IsNullOrWhiteSpace($_.SID) -and
                $null -ne $_.LastUseTime -and
                $_.LastUseTime -lt $CutoffDate -and
                $_.LocalPath -notmatch '\\Users\\(Default|Default User|Public|All Users|defaultuser0)$'
            }
        )

        foreach ($staleProfile in $staleProfiles) {
            $lastUse = 'Unknown'
            try {
                $lastUse = Get-Date $staleProfile.LastUseTime -Format 'yyyy-MM-dd HH:mm:ss'
            }
            catch {
                $lastUse = 'Unknown'
            }

            Write-Log -Message ("Stale profile detected | UserPath: {0} | SID: {1} | LastUseTime: {2}" -f $staleProfile.LocalPath, $staleProfile.SID, $lastUse) -Level 'WARNING'
            $reasons.Add("Stale user profile older than $StaleAfterDays days: $($staleProfile.LocalPath)")
        }
    }
    catch {
        throw "Failed to enumerate user profiles: $($_.Exception.Message)"
    }

    return @($reasons)
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
    Write-Log -Message ("Checking for stale user profiles older than {0} days. Cutoff date: {1}" -f $StaleAfterDays, ($CutoffDate.ToString('yyyy-MM-dd HH:mm:ss'))) -Level 'INFO'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message "No stale user profiles were found." -Level 'SUCCESS'
    }

    foreach ($reason in $reasons) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "One or more stale user profiles were found. Remediation is required." -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}
