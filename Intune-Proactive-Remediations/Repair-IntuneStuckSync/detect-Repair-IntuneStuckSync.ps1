<#
.TITLE
    Detection - Intune Sync Health Status

.SYNOPSIS
    Detects whether Intune sync health appears stuck or unhealthy.

.DESCRIPTION
    Performs a lightweight health check for Intune sync components: the
    DmWapPushService MDM transport, the IntuneManagementExtension service when
    required, and recent IME log activity parsed from CMTrace timestamps with a
    file-timestamp fallback. This is a diagnostics package: findings become the
    reason list that triggers the paired sync-repair remediation. No system
    state is changed during detection.

    Exit contract:
    Exit 0 = compliant (no remediation needed)
    Exit 1 = non-compliant (Intune runs the paired remediation)
    Exit 2 = script error (Intune must NOT treat a crash as non-compliance)

.TAGS
    Remediation,Detection,Intune,Sync

.REMEDIATIONTYPE
    Detection

.PAIRSCRIPT
    remediate-Repair-IntuneStuckSync.ps1

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - queries service states and reads IME log files.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Detection errors now exit 2 instead of 1 so Intune never treats crashes as non-compliance
    - Legacy run parameters (ThresholdHours, RequireIME, StrictStartMode, TailLines)
      moved to CONFIGURATION; the manual-only OutputJson switch was retired
    1.0 - Legacy release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\detect-Repair-IntuneStuckSync.ps1
    Returns exit 0 when the transport baseline is healthy; exit 1 when repair is needed.

.EXAMPLE
    .\detect-Repair-IntuneStuckSync.ps1
    Returns exit 2 when an unexpected error prevents evaluation.

.NOTES
    - Runs in SYSTEM context via Intune Proactive Remediations.
    - Keep detection read-only: service queries and log tail reads only.
    - Idempotent and read-only by definition.
    - Logs: <SystemDrive>\IntuneLogs\IntuneStuckSyncFixer\IntuneStuckSyncFixer-Detection.txt
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and compliance target values.
# ============================================================================

$SolutionName = 'Repair-IntuneStuckSync'
$ScriptMode   = 'Detection'

# Detection settings (legacy run parameters, now fixed configuration)
$ThresholdHours  = 24
$RequireIME      = $true
$StrictStartMode = $false
$TailLines       = 300

$NowUtc         = (Get-Date).ToUniversalTime()
$LogsRoot       = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$ImeServiceName = 'IntuneManagementExtension'
$DmServiceName  = 'DmWapPushService'

# Candidate IME logs
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

$CandidateLogs = $CandidateLogNames | ForEach-Object {
    Join-Path $LogsRoot $_
}

# Findings containers
$script:Issues   = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

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

# Adds a finding to the issue list (compliance-relevant) or warning list.
function Add-Finding {
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = "",

        [ValidateSet('Issue', 'Warning')]
        [string]$Type = 'Issue'
    )

    if ($Type -eq 'Issue') {
        [void]$script:Issues.Add($Message)
    }
    else {
        Write-Log -Message "Warning: $Message" -Level 'WARNING'
        [void]$script:Warnings.Add($Message)
    }
}

# Return basic service information from Win32_Service.
function Get-ServiceInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $service = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction Stop
    }
    catch {
        return $null
    }

    return [pscustomobject]@{
        Name      = $service.Name
        State     = $service.State
        StartMode = $service.StartMode
    }
}

# Parse CMTrace style timestamps and return UTC DateTime.
function Parse-CMTraceTimestampUtc {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    $timeMatch = [regex]::Match($Line, 'time="(?<t>\d{1,2}:\d{2}:\d{2}(\.\d{1,3})?)"')
    $dateMatch = [regex]::Match($Line, 'date="(?<d>\d{4}[-/]\d{1,2}[-/]\d{1,2})"')

    if ($timeMatch.Success -and $dateMatch.Success) {
        $combinedValue = "$($dateMatch.Groups['d'].Value) $($timeMatch.Groups['t'].Value)"
        try {
            $localDate = [datetime]::Parse(
                $combinedValue,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::AssumeLocal
            )
            return $localDate.ToUniversalTime()
        }
        catch {
            # Unparseable CMTrace timestamp variant - try the fallback pattern below.
        }
    }

    # Fallback pattern
    $fallbackMatch = [regex]::Match($Line, '(?<d>\d{4}[-/]\d{1,2}[-/]\d{1,2}).*(?<t>\d{1,2}:\d{2}:\d{2})')
    if ($fallbackMatch.Success) {
        $combinedValue = "$($fallbackMatch.Groups['d'].Value) $($fallbackMatch.Groups['t'].Value)"
        try {
            $localDate = [datetime]::Parse(
                $combinedValue,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::AssumeLocal
            )
            return $localDate.ToUniversalTime()
        }
        catch {
            # Unparseable fallback timestamp - treat this line as having no stamp.
        }
    }

    return $null
}

# Get the newest timestamp from a log file.
function Get-LastLogTimestampUtc {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [int]$Tail = 200
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        $lines = Get-Content -LiteralPath $Path -Tail $Tail -ErrorAction Stop

        for ($index = $lines.Count - 1; $index -ge 0; $index--) {
            $parsedUtc = Parse-CMTraceTimestampUtc -Line $lines[$index]
            if ($parsedUtc) {
                return $parsedUtc
            }
        }
    }
    catch {
        # Continue to file timestamp fallback.
    }

    try {
        return (Get-Item -LiteralPath $Path -ErrorAction Stop).LastWriteTimeUtc
    }
    catch {
        return $null
    }
}

# Returns a reason string per unmet condition; empty output = compliant.
function Test-ComplianceState {
    $reasons = [System.Collections.Generic.List[string]]::new()

    try {
        # Check MDM transport service
        $dmService = Get-ServiceInfo -Name $DmServiceName

        if (-not $dmService) {
            Add-Finding -Type Issue -Message "MDM transport service is missing: $DmServiceName"
        }
        else {
            Write-Log -Message "DmWapPushService state: $($dmService.State) | StartMode: $($dmService.StartMode)" -Level 'DEBUG'

            if ($dmService.StartMode -ne 'Auto') {
                $message = "MDM transport StartMode is '$($dmService.StartMode)' but expected 'Auto'"
                if ($StrictStartMode) {
                    Add-Finding -Type Issue -Message $message
                }
                else {
                    Add-Finding -Type Warning -Message $message
                }
            }

            if ($dmService.State -ne 'Running') {
                Add-Finding -Type Issue -Message "MDM transport is not running. Current state: $($dmService.State)"
            }
        }

        # Check IME service when required
        $imeService = Get-ServiceInfo -Name $ImeServiceName

        if ($RequireIME) {
            if (-not $imeService) {
                Add-Finding -Type Issue -Message "IME service is not installed: $ImeServiceName"
            }
            else {
                Write-Log -Message "IntuneManagementExtension state: $($imeService.State) | StartMode: $($imeService.StartMode)" -Level 'DEBUG'

                if ($imeService.StartMode -ne 'Auto') {
                    $message = "IME StartMode is '$($imeService.StartMode)' but expected 'Auto'"
                    if ($StrictStartMode) {
                        Add-Finding -Type Issue -Message $message
                    }
                    else {
                        Add-Finding -Type Warning -Message $message
                    }
                }

                if ($imeService.State -ne 'Running') {
                    Add-Finding -Type Issue -Message "IME service is not running. Current state: $($imeService.State)"
                }
            }
        }

        # Check IME activity freshness
        if ($RequireIME -and $imeService -and (Test-Path -LiteralPath $LogsRoot)) {
            $timestamps = @(
                foreach ($logPath in $CandidateLogs) {
                    $timestampUtc = Get-LastLogTimestampUtc -Path $logPath -Tail $TailLines
                    if ($timestampUtc) {
                        [pscustomobject]@{
                            Path    = $logPath
                            TimeUtc = $timestampUtc
                        }
                    }
                }
            )

            if ($timestamps.Count -gt 0) {
                $latestLog = $timestamps | Sort-Object TimeUtc -Descending | Select-Object -First 1
                $ageHours  = [math]::Round(($NowUtc - $latestLog.TimeUtc).TotalHours, 1)

                Write-Log -Message "Latest IME activity: $([System.IO.Path]::GetFileName($latestLog.Path)) | AgeHours=$ageHours" -Level 'DEBUG'

                if ($ageHours -gt $ThresholdHours) {
                    Add-Finding -Type Issue -Message "IME activity is stale. Age=$ageHours hour(s), Threshold=$ThresholdHours hour(s)"
                }
            }
            else {
                Add-Finding -Type Warning -Message "IME logs were not found or could not be read under $LogsRoot"
            }
        }

        foreach ($issue in $script:Issues) {
            $reasons.Add($issue)
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
        Finish-Script -ExitCode 0 -Message "Compliant - Intune transport baseline looks OK" -Level 'SUCCESS'
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


