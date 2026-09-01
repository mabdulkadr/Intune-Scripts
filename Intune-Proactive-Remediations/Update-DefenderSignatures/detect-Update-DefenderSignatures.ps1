<#
.TITLE
    Windows Defender Definition Update Detection

.SYNOPSIS
    Detects if Windows Defender antivirus definitions are outdated.

.DESCRIPTION
    Checks if Windows Defender definitions are current (within 48 hours) by
    reading AntivirusSignatureLastUpdated from Get-MpComputerStatus. Outdated
    definitions trigger the paired remediation that forces a signature update.
    This script NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant (definitions current)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Update-DefenderSignatures.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads Defender signature status via Get-MpComputerStatus.

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
    .\detect-Update-DefenderSignatures.ps1
    Returns exit 0 when definitions are current; exit 1 when they are outdated.

.EXAMPLE
    .\detect-Update-DefenderSignatures.ps1
    Returns exit 2 when Defender status cannot be read.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Threshold: $MaxDefinitionAgeHours hours since last signature update.
    - Idempotent and read-only by definition.
    - Logs: <SystemDrive>\IntuneLogs\antivirus-definition-updates\antivirus-definition-updates-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Update-DefenderSignatures'
$ScriptMode   = 'Detection'

$script:MaxDefinitionAgeHours = 48

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

# Returns Defender signature diagnostics plus reasons; reporting happens in MAIN.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    try {
        $mpStatus = Get-MpComputerStatus -ErrorAction Stop
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        throw "Get-MpComputerStatus is not available - Microsoft Defender component missing"
    }

    # Check definition age
    if ($null -eq $mpStatus.AntivirusSignatureLastUpdated) {
        throw "Get-MpComputerStatus returned no AntivirusSignatureLastUpdated timestamp"
    }
    $now = Get-Date
    $definitionAge = ($now - $mpStatus.AntivirusSignatureLastUpdated).TotalHours

    Write-Log -Message "Definition age: $([math]::Round($definitionAge, 1)) hours, version $($mpStatus.AntivirusSignatureVersion)" -Level 'DEBUG'

    if ($definitionAge -gt $script:MaxDefinitionAgeHours) {
        $reasons.Add("Definitions are outdated (threshold: $script:MaxDefinitionAgeHours hours)")
    }

    return @{
        DefinitionAge = [math]::Round($definitionAge, 1)
        LastUpdated   = $mpStatus.AntivirusSignatureLastUpdated
        Version       = $mpStatus.AntivirusSignatureVersion
        Reasons       = @($reasons)
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

    $state = Test-ComplianceState

    Write-Output "Definition age: $($state.DefinitionAge) hours"
    Write-Output "Last updated: $($state.LastUpdated)"
    Write-Output "Version: $($state.Version)"

    if ($state.Reasons.Count -eq 0) {
        Write-Output "Windows Defender definitions are up to date"
        Finish-Script -ExitCode 0 -Message "Compliant - Windows Defender definitions are up to date" -Level 'SUCCESS'
    }

    foreach ($reason in @($state.Reasons)) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Non-compliant - $($state.Reasons.Count) condition(s) found" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}


