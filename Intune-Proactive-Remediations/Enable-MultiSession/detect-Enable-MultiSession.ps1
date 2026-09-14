<#
.TITLE
    Detection - Multi-Session Restrictions Removed

.SYNOPSIS
    Verifies that Windows is not enforcing single-session restrictions that block concurrent user logons.

.DESCRIPTION
    Evaluates two registry locations that may prevent multiple concurrent
    interactive user sessions on the same device:

    1. Terminal Server setting:
       HKLM:\System\CurrentControlSet\Control\Terminal Server
       - fSingleSessionPerUser (compliant when 0 or absent)

    2. Optional acNam Credential Provider setting (only when installed):
       HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{B12744B8-5BB7-463a-B85E-BB7627E73002}
       - EnforceSingleLogon (compliant when 0 or absent)

    Shared, lab, and domain-joined devices that must serve concurrent users
    require both values at 0. This script NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,MultiSession,TerminalServer

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Enable-MultiSession.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads registry values only.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-09-13)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    - Consolidated checks into Test-ComplianceState reason-list pattern
    - Null-safe registry reads via Get-ItemProperty member access (Get-ItemPropertyValue throws terminating PSArgumentException when a value is absent)
    1.0 - Legacy release

.LASTUPDATE
    2026-09-13

.EXAMPLE
    .\detect-Enable-MultiSession.ps1
    Returns exit 0 when compliant; exit 1 when the paired remediation must run.

.EXAMPLE
    .\detect-Enable-MultiSession.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Keep detection under 30 seconds: two registry reads only.
    - Idempotent and read-only by definition.
    - Logs: <SystemDrive>\IntuneLogs\Enable-MultiSession\Enable-MultiSession-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and registry targets.
# ============================================================================

$SolutionName = 'Enable-MultiSession'
$ScriptMode   = 'Detection'

$TerminalServerPath = 'HKLM:\System\CurrentControlSet\Control\Terminal Server'
$TerminalServerName = 'fSingleSessionPerUser'

$CredentialProvPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{B12744B8-5BB7-463a-B85E-BB7627E73002}'
$CredentialProvName = 'EnforceSingleLogon'

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

    $title      = '{0} | {1} | {2}' -f $SolutionName, $ScriptMode, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
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
        [AllowEmptyString()]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers use Write-Log -Message "" to break sections; early-return on empty.
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Console = clean, no timestamp/level prefix - color alone conveys severity.
    # File    = detailed - keeps [timestamp] [LEVEL] for fleet troubleshooting.
    $fileLine  = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $Message -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $fileLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

# Logs the final message and terminates with the given exit code.
function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
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

    # --- CHECK 1: Terminal Server single-session restriction ------------------
    # Compliant when fSingleSessionPerUser = 0 or absent. Non-compliant when 1.
    if (-not (Test-Path -LiteralPath $TerminalServerPath)) {
        $reasons.Add("Terminal Server registry path was not found: $TerminalServerPath")
    }
    else {
        $terminalValue = (Get-ItemProperty -LiteralPath $TerminalServerPath -ErrorAction Stop).$TerminalServerName
        Write-Log -Message "Current $TerminalServerName value: $terminalValue" -Level 'DEBUG'

        if ($terminalValue -eq 1) {
            $reasons.Add("fSingleSessionPerUser is set to 1 - expected 0 (multi-session allowed)")
        }
    }

    # --- CHECK 2: optional acNam credential provider restriction --------------
    # Skipped when the provider is not installed. Compliant when absent or 0.
    if (-not (Test-Path -LiteralPath $CredentialProvPath)) {
        Write-Log -Message "acNam Credential Provider path not found - skipping vendor check." -Level 'DEBUG'
    }
    else {
        $providerValue = (Get-ItemProperty -LiteralPath $CredentialProvPath -ErrorAction Stop).$CredentialProvName
        Write-Log -Message "Current $CredentialProvName value: $providerValue" -Level 'DEBUG'

        if ($providerValue -eq 1) {
            $reasons.Add("EnforceSingleLogon is set to 1 - expected 0 (multi-session allowed)")
        }
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

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message "Compliant - no single-session restrictions detected" -Level 'SUCCESS'
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
