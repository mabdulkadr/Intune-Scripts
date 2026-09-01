<#
.TITLE
    Detection - Intune Sync Service Health

.SYNOPSIS
    Checks core Intune sync services and recent IME log activity for a healthy management state.

.DESCRIPTION
    Evaluates the DmWapPushService and IntuneManagementExtension services through
    CIM, validates their start mode and running state, and reviews recent
    timestamps from Intune Management Extension log files under
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs. Non-compliant when a
    required service is stopped or missing, when the start mode does not match the
    configured expectation (strict mode), or when IME activity appears stale
    beyond the configured threshold. This script NEVER modifies the system.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,Intune,Services

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Repair-IntuneSyncService.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - queries service state via CIM and reads IME log tails.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    1.2
    - Legacy release prior to canonical migration
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Repair-IntuneSyncService.ps1
    Returns exit 0 when compliant; exit 1 when the paired remediation must run.

.EXAMPLE
    .\detect-Repair-IntuneSyncService.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Former command-line parameters are preserved as fixed configuration values
      (ThresholdHours = 24, RequireIME = True, StrictStartMode = False, TailLines = 300).
    - Idempotent and read-only by definition.
    - Logs: <SystemDrive>\IntuneLogs\Repair-IntuneSyncService\Repair-IntuneSyncService-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Repair-IntuneSyncService'
$ScriptMode   = 'Detection'

# Original parameter defaults preserved as fixed configuration values.
$ThresholdHours   = 24
$RequireIME       = $true
$StrictStartMode  = $false
$TailLines        = 300
$LogsRoot         = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$ImeServiceName   = 'IntuneManagementExtension'
$DmServiceName    = 'DmWapPushService'
$CandidateLogNames = @(
    'IntuneManagementExtension.log',
    'AgentExecutor.log',
    'AppWorkload.log',
    'HealthScripts.log',
    'DeviceHealthMonitoring.log',
    'Win32AppInventory.log',
    'AppActionProcessor.log',
    'ClientCertCheck.log',
    'Sensor.log'
)

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

# Returns service name/state/start mode via CIM, or $null when not installed.
function Get-ServiceInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $service = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction Stop
        return [PSCustomObject]@{
            Name      = $service.Name
            State     = $service.State
            StartMode = $service.StartMode
        }
    }
    catch [Microsoft.Management.Infrastructure.CimException] {
        # Query failure is treated the same as service-not-installed (legacy behavior).
        return $null
    }
}

# Parses a CMTrace-style timestamp from one log line; returns UTC or $null.
function Parse-CMTraceTimestampUtc {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    $timeMatch = [regex]::Match($Line, 'time="(?<t>\d{1,2}:\d{2}:\d{2}(\.\d{1,3})?)"')
    $dateMatch = [regex]::Match($Line, 'date="(?<d>\d{4}[-/]\d{1,2}[-/]\d{1,2})"')

    if ($timeMatch.Success -and $dateMatch.Success) {
        $timestamp = '{0} {1}' -f $dateMatch.Groups['d'].Value, $timeMatch.Groups['t'].Value

        try {
            return ([DateTime]::Parse(
                    $timestamp,
                    [Globalization.CultureInfo]::InvariantCulture,
                    [Globalization.DateTimeStyles]::AssumeLocal
                )).ToUniversalTime()
        }
        catch [System.FormatException] {
            # Malformed timestamp text - fall through to the fallback pattern below.
        }
        catch [System.ArgumentException] {
            # Invalid timestamp arguments - fall through to the fallback pattern below.
        }
    }

    $fallback = [regex]::Match($Line, '(?<d>\d{4}[-/]\d{1,2}[-/]\d{1,2}).*(?<t>\d{1,2}:\d{2}:\d{2})')
    if ($fallback.Success) {
        $timestamp = '{0} {1}' -f $fallback.Groups['d'].Value, $fallback.Groups['t'].Value

        try {
            return ([DateTime]::Parse(
                    $timestamp,
                    [Globalization.CultureInfo]::InvariantCulture,
                    [Globalization.DateTimeStyles]::AssumeLocal
                )).ToUniversalTime()
        }
        catch [System.FormatException] {
            # Fallback timestamp text also malformed - treat this line as unparsable.
        }
        catch [System.ArgumentException] {
            # Fallback timestamp arguments invalid - treat this line as unparsable.
        }
    }

    return $null
}

# Returns the newest parsable UTC timestamp from a log tail, or the file write time.
function Get-LastLogTimestampUtc {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [int]$Tail = 200
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $lines = $null
    try {
        $lines = Get-Content -LiteralPath $Path -Tail $Tail -ErrorAction Stop
    }
    catch [System.IO.IOException] {
        # Log file locked by the IME writer - fall back to LastWriteTimeUtc below.
        $lines = $null
    }
    catch [System.UnauthorizedAccessException] {
        # Access denied while tailing - fall back to LastWriteTimeUtc below.
        $lines = $null
    }

    if ($lines) {
        for ($index = $lines.Count - 1; $index -ge 0; $index--) {
            $timestamp = Parse-CMTraceTimestampUtc -Line $lines[$index]
            if ($timestamp) {
                return $timestamp
            }
        }
    }

    try {
        return (Get-Item -LiteralPath $Path -ErrorAction Stop).LastWriteTimeUtc
    }
    catch [System.IO.IOException] {
        # File metadata unavailable - report no timestamp for this log.
        return $null
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        # Log disappeared between the existence test and metadata read.
        return $null
    }
}

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    try {
        $nowUtc = (Get-Date).ToUniversalTime()
        Write-Log -Message "ThresholdHours=$ThresholdHours; RequireIME=$RequireIME; StrictStartMode=$StrictStartMode; TailLines=$TailLines" -Level 'DEBUG'

        # --- MDM transport service ---
        $dmService = Get-ServiceInfo -Name $DmServiceName
        if (-not $dmService) {
            $reasons.Add("MDM transport missing: $DmServiceName")
            Write-Log -Message "MDM transport missing: $DmServiceName" -Level 'ERROR'
        }
        else {
            Write-Log -Message ("DmWapPushService state: {0}; start mode: {1}" -f $dmService.State, $dmService.StartMode) -Level 'DEBUG'

            if ($dmService.StartMode -ne 'Auto') {
                $message = "MDM transport StartMode is '$($dmService.StartMode)' (expected Auto)"
                if ($StrictStartMode) {
                    $reasons.Add($message)
                    Write-Log -Message $message -Level 'ERROR'
                }
                else {
                    Write-Log -Message $message -Level 'WARNING'
                }
            }

            if ($dmService.State -ne 'Running') {
                $message = "MDM transport not running: State=$($dmService.State)"
                $reasons.Add($message)
                Write-Log -Message $message -Level 'ERROR'
            }
        }

        # --- Intune Management Extension service ---
        $imeService = $null
        if ($RequireIME) {
            $imeService = Get-ServiceInfo -Name $ImeServiceName
            if (-not $imeService) {
                $reasons.Add("IME not installed: $ImeServiceName")
                Write-Log -Message "IME not installed: $ImeServiceName" -Level 'ERROR'
            }
            else {
                Write-Log -Message ("IntuneManagementExtension state: {0}; start mode: {1}" -f $imeService.State, $imeService.StartMode) -Level 'DEBUG'

                if ($imeService.StartMode -ne 'Auto') {
                    $message = "IME StartMode is '$($imeService.StartMode)' (expected Auto)"
                    if ($StrictStartMode) {
                        $reasons.Add($message)
                        Write-Log -Message $message -Level 'ERROR'
                    }
                    else {
                        Write-Log -Message $message -Level 'WARNING'
                    }
                }

                if ($imeService.State -ne 'Running') {
                    $message = "IME not running: State=$($imeService.State)"
                    $reasons.Add($message)
                    Write-Log -Message $message -Level 'ERROR'
                }
            }
        }

        # --- IME log activity freshness ---
        if ($RequireIME -and $imeService -and (Test-Path -LiteralPath $LogsRoot)) {
            $logCandidates = foreach ($logName in $CandidateLogNames) {
                $logPath = Join-Path $LogsRoot $logName
                $timestamp = Get-LastLogTimestampUtc -Path $logPath -Tail $TailLines

                if ($timestamp) {
                    [PSCustomObject]@{
                        Path    = $logPath
                        TimeUtc = $timestamp
                    }
                }
            }

            $logCandidates = @($logCandidates)
            Write-Log -Message ("IME log timestamps collected: {0}" -f $logCandidates.Count) -Level 'DEBUG'

            if ($logCandidates.Count -gt 0) {
                $latest = $logCandidates | Sort-Object TimeUtc -Descending | Select-Object -First 1
                $ageHours = [math]::Round(($nowUtc - $latest.TimeUtc).TotalHours, 1)

                Write-Log -Message ("Newest IME log: {0}; age: {1} hour(s)" -f [System.IO.Path]::GetFileName($latest.Path), $ageHours) -Level 'DEBUG'

                if ($ageHours -gt $ThresholdHours) {
                    $message = "IME activity stale ($ageHours h > $ThresholdHours h)"
                    $reasons.Add($message)
                    Write-Log -Message $message -Level 'ERROR'
                }
            }
            else {
                Write-Log -Message ("IME logs not found or unreadable under {0}" -f $LogsRoot) -Level 'WARNING'
            }
        }
        elseif ($RequireIME) {
            Write-Log -Message ("IME log folder not found: {0}" -f $LogsRoot) -Level 'WARNING'
        }
    }
    catch {
        throw "Failed to evaluate Intune sync health: $($_.Exception.Message)"
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
        Finish-Script -ExitCode 0 -Message "Compliant - Intune transport baseline looks healthy" -Level 'SUCCESS'
    }

    foreach ($reason in $reasons) {
        Write-Output $reason
        Write-Log -Message "Non-compliant: $reason" -Level 'WARNING'
    }
    Finish-Script -ExitCode 1 -Message "Non-compliant - Intune transport baseline is unhealthy. Issues detected: $($reasons.Count)" -Level 'WARNING'
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    Finish-Script -ExitCode 2 -Message "Detection script error: $($_.Exception.Message)" -Level 'ERROR'
}
