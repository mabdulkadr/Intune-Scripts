<#
.TITLE
    Detection - Browser Local Network Access Flag

.SYNOPSIS
    Verifies that Chrome and Edge both carry the required local-network-access experiment flag.

.DESCRIPTION
    Reads the browser 'Local State' JSON files for Google Chrome and Microsoft Edge under the user
    profile and verifies that browser.enabled_labs_experiments contains the required flag
    local-network-access-check@3. A missing file, unparseable JSON, missing experiments array, or
    absent flag makes that browser non-compliant so Intune runs the paired remediation. This script
    NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,Browser,Chrome,Edge

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Disable-LocalNetworkAccessRestrictions.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads Chrome and Edge Local State JSON files under the user profile.

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
    .\detect-Disable-LocalNetworkAccessRestrictions.ps1
    Returns exit 0 when both browsers contain the flag; exit 1 when one or both are missing it.

.EXAMPLE
    .\detect-Disable-LocalNetworkAccessRestrictions.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in the assigned user context via Intune Proactive Remediations ($env:LOCALAPPDATA paths).
    - Idempotent and read-only by definition.
    - Logs: <SystemDrive>\IntuneLogs\Disable-LocalNetworkAccessRestrictions\Disable-LocalNetworkAccessRestrictions-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Disable-LocalNetworkAccessRestrictions'
$ScriptMode   = 'Detection'

$RequiredFlag     = 'local-network-access-check@3'
$ChromeLocalState = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Local State'
$EdgeLocalState   = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Local State'

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

# Tests whether the required labs flag exists in the browser Local State file.
function Test-BrowserFlag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocalStatePath,

        [Parameter(Mandatory = $true)]
        [string]$BrowserName
    )

    if (-not (Test-Path -LiteralPath $LocalStatePath)) {
        # Expected absence - the browser has never run for this user.
        Write-Log -Message ("{0}: Local State was not found: {1}" -f $BrowserName, $LocalStatePath) -Level 'WARNING'
        return $false
    }

    try {
        $jsonData = Get-Content -LiteralPath $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Log -Message ("{0}: Failed to read or parse Local State JSON." -f $BrowserName) -Level 'ERROR'
        return $false
    }

    if ($null -eq $jsonData.browser -or $null -eq $jsonData.browser.enabled_labs_experiments) {
        Write-Log -Message ("{0}: browser.enabled_labs_experiments is missing." -f $BrowserName) -Level 'WARNING'
        return $false
    }

    $experiments = @($jsonData.browser.enabled_labs_experiments)
    if ($experiments -contains $RequiredFlag) {
        Write-Log -Message ("{0}: Required flag is present: {1}" -f $BrowserName, $RequiredFlag) -Level 'SUCCESS'
        return $true
    }

    Write-Log -Message ("{0}: Required flag is missing: {1}" -f $BrowserName, $RequiredFlag) -Level 'WARNING'
    return $false
}

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    try {
        $chromeOk = Test-BrowserFlag -LocalStatePath $ChromeLocalState -BrowserName 'Chrome'
        $edgeOk   = Test-BrowserFlag -LocalStatePath $EdgeLocalState -BrowserName 'Edge'

        if (-not $chromeOk) {
            $reasons.Add("Chrome is missing the required flag: $RequiredFlag")
        }
        if (-not $edgeOk) {
            $reasons.Add("Edge is missing the required flag: $RequiredFlag")
        }
    }
    catch {
        throw "Failed to evaluate browser Local State files: $($_.Exception.Message)"
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
    Write-Log -Message ("Checking browser flag: {0}" -f $RequiredFlag) -Level 'INFO'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message "Chrome and Edge both contain the required local network access flag." -Level 'SUCCESS'
    }

    foreach ($reason in $reasons) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "One or more browsers are missing the required flag." -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}
