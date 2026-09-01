<#
.TITLE
    Detection - Monthly System Restore Point Present

.SYNOPSIS
    Verifies that a valid system restore point exists for the current month.

.DESCRIPTION
    Evaluates whether at least one accepted monthly restore point exists by
    querying both Get-ComputerRestorePoint and the root/default SystemRestore
    WMI provider. A device is treated as compliant when a restore point matches
    the accepted naming rules (accepted prefix within the current month, or a
    description tagged with the current '(yyyy-MM)' month tag). This script
    NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,SystemRestore,Recovery

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Ensure-SystemRestorePointMonthly.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - queries restore points from two local providers.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    1.2 - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Ensure-SystemRestorePointMonthly.ps1
    Returns exit 0 when compliant; exit 1 when the paired remediation must run.

.EXAMPLE
    .\detect-Ensure-SystemRestorePointMonthly.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Keep detection under 30 seconds: two restore-point provider queries only.
    - Idempotent and read-only by definition.
    - Logs: <SystemDrive>\IntuneLogs\Ensure-SystemRestorePointMonthly\Ensure-SystemRestorePointMonthly-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Ensure-SystemRestorePointMonthly'
$ScriptMode   = 'Detection'

$AcceptedPrefixes = @(
    'Monthly System Restore Point',
    'Intune Monthly Restore Point',
    'System Safety Restore Point'
)

$Now            = Get-Date
$MonthStart     = Get-Date -Year $Now.Year -Month $Now.Month -Day 1 -Hour 0 -Minute 0 -Second 0
$NextMonthStart = $MonthStart.AddMonths(1)
$MonthTag       = '({0})' -f $MonthStart.ToString('yyyy-MM')

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
        [AllowEmptyString()]
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

# Tests whether a valid restore point exists for the current month.
function Test-MonthlyRestorePoint {
    param([object[]]$RestorePoints)

    foreach ($restorePoint in $RestorePoints) {
        $description = $restorePoint.Description
        $isInMonth   = ($restorePoint.CreationTime -ge $MonthStart -and $restorePoint.CreationTime -lt $NextMonthStart)
        $prefixMatch = $AcceptedPrefixes | Where-Object { $description -match [regex]::Escape($_) }
        $tagMatch    = ($description -match [regex]::Escape($MonthTag))

        if (($isInMonth -and $prefixMatch) -or $tagMatch) {
            return $restorePoint
        }
    }

    return $null
}

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    $restorePoints = Get-RestorePoints

    if ($restorePoints.Count -eq 0) {
        $reasons.Add("No restore points were found on the system")
        return @($reasons)
    }

    Write-Log -Message "Restore points collected: $($restorePoints.Count)" -Level 'DEBUG'

    $matchingRestorePoint = Test-MonthlyRestorePoint -RestorePoints $restorePoints

    if (-not $matchingRestorePoint) {
        $reasons.Add("No valid restore point was found for $($MonthStart.ToString('yyyy-MM'))")
    }
    else {
        Write-Log -Message "Valid monthly restore point found: '$($matchingRestorePoint.Description)' at $($matchingRestorePoint.CreationTime) via $($matchingRestorePoint.Source)" -Level 'DEBUG'
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
    Write-Log -Message "Checking restore points for month tag: $MonthTag" -Level 'INFO'

    $reasons = Test-ComplianceState

    if ($reasons.Count -eq 0) {
        Finish-Script -ExitCode 0 -Message "Compliant - a valid monthly restore point already exists" -Level 'SUCCESS'
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
