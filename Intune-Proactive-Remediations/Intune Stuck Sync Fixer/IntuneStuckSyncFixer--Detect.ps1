<#
.SYNOPSIS
    Detects whether Intune sync health appears stuck or unhealthy.

.DESCRIPTION
    This detection script performs a lightweight health check for Intune sync
    components on Windows devices.

    The script checks:
    1. DmWapPushService status
    2. IntuneManagementExtension service status when required
    3. Recent IME log activity using CMTrace timestamps with file timestamp fallback

    Exit codes:
    - Exit 0: Healthy
    - Exit 1: Unhealthy

.PARAMETER ThresholdHours
    Maximum allowed hours since the latest IME activity.

.PARAMETER RequireIME
    When set to $true, the Intune Management Extension service must exist and be running.

.PARAMETER StrictStartMode
    When set to $true, any StartMode not equal to Auto is treated as an issue.
    When set to $false, it is treated as a warning.

.PARAMETER OutputJson
    Outputs the full result object as JSON.

.PARAMETER TailLines
    Number of tail lines read from each log file.

.RUN AS
    System

.EXAMPLE
    .\IntuneStuckSyncFixer--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ---------- Parameters ----------

[CmdletBinding()]
param(
    [int]$ThresholdHours = 24,
    [bool]$RequireIME = $true,
    [bool]$StrictStartMode = $false,
    [switch]$OutputJson,
    [ValidateRange(50, 2000)]
    [int]$TailLines = 300
)

#endregion ---------- Parameters ----------


#region ---------- Configuration ----------

# Script metadata
$ScriptName     = 'IntuneStuckSyncFixer--Detect.ps1'
$ScriptBaseName = 'IntuneStuckSyncFixer--Detect'
$SolutionName   = 'Intune Stuck Sync Fixer'

# Detect Windows system drive
$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
else {
    'C:'
}

# Logging path
$BasePath = Join-Path $SystemDrive "Intune\$SolutionName"
$LogFile  = Join-Path $BasePath "$ScriptBaseName.txt"

# Detection settings
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

#endregion ---------- Configuration ----------


#region ---------- Functions ----------

# Create log folder and file if needed
function Initialize-Logging {
    try {
        if (-not (Test-Path -LiteralPath $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -LiteralPath $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force | Out-Null
        }

        return $true
    }
    catch {
        return $false
    }
}

# Write a message to console and log file
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line      = "[$TimeStamp] [$Level] $Message"

    switch ($Level) {
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        'WARNING' { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        default   { Write-Host $Line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        }
        catch {}
    }
}

# Add issue or warning to the result lists
function Add-Finding {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Issue', 'Warning')]
        [string]$Type = 'Issue'
    )

    if ($Type -eq 'Issue') {
        [void]$script:Issues.Add($Message)
    }
    else {
        [void]$script:Warnings.Add($Message)
    }
}

# Return basic service information from Win32_Service
function Get-ServiceInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $Service = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction Stop
    }
    catch {
        return $null
    }

    return [pscustomobject]@{
        Name      = $Service.Name
        State     = $Service.State
        StartMode = $Service.StartMode
    }
}

# Parse CMTrace style timestamps and return UTC DateTime
function Parse-CMTraceTimestampUtc {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    $TimeMatch = [regex]::Match($Line, 'time="(?<t>\d{1,2}:\d{2}:\d{2}(\.\d{1,3})?)"')
    $DateMatch = [regex]::Match($Line, 'date="(?<d>\d{4}[-/]\d{1,2}[-/]\d{1,2})"')

    if ($TimeMatch.Success -and $DateMatch.Success) {
        $CombinedValue = "$($DateMatch.Groups['d'].Value) $($TimeMatch.Groups['t'].Value)"
        try {
            $LocalDate = [datetime]::Parse(
                $CombinedValue,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::AssumeLocal
            )
            return $LocalDate.ToUniversalTime()
        }
        catch {}
    }

    # Fallback pattern
    $FallbackMatch = [regex]::Match($Line, '(?<d>\d{4}[-/]\d{1,2}[-/]\d{1,2}).*(?<t>\d{1,2}:\d{2}:\d{2})')
    if ($FallbackMatch.Success) {
        $CombinedValue = "$($FallbackMatch.Groups['d'].Value) $($FallbackMatch.Groups['t'].Value)"
        try {
            $LocalDate = [datetime]::Parse(
                $CombinedValue,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::AssumeLocal
            )
            return $LocalDate.ToUniversalTime()
        }
        catch {}
    }

    return $null
}

# Get the newest timestamp from a log file
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
        $Lines = Get-Content -LiteralPath $Path -Tail $Tail -ErrorAction Stop

        for ($Index = $Lines.Count - 1; $Index -ge 0; $Index--) {
            $ParsedUtc = Parse-CMTraceTimestampUtc -Line $Lines[$Index]
            if ($ParsedUtc) {
                return $ParsedUtc
            }
        }
    }
    catch {
        # Continue to file timestamp fallback
    }

    try {
        return (Get-Item -LiteralPath $Path -ErrorAction Stop).LastWriteTimeUtc
    }
    catch {
        return $null
    }
}

#endregion ---------- Functions ----------


#region ---------- Detection Logic ----------

# Prepare logging
$LogReady = Initialize-Logging

Write-Log -Message "Starting detection for $ScriptName"
Write-Log -Message "ThresholdHours: $ThresholdHours"
Write-Log -Message "RequireIME: $RequireIME"
Write-Log -Message "StrictStartMode: $StrictStartMode"
Write-Log -Message "TailLines: $TailLines"
Write-Log -Message "Logs root: $LogsRoot"
Write-Log -Message "Log file: $LogFile"

try {
    # Check MDM transport service
    $DmService = Get-ServiceInfo -Name $DmServiceName

    if (-not $DmService) {
        Add-Finding -Type Issue -Message "MDM transport service is missing: $DmServiceName"
    }
    else {
        Write-Log -Message "DmWapPushService state: $($DmService.State) | StartMode: $($DmService.StartMode)"

        if ($DmService.StartMode -ne 'Auto') {
            $Message = "MDM transport StartMode is '$($DmService.StartMode)' but expected 'Auto'"
            if ($StrictStartMode) {
                Add-Finding -Type Issue -Message $Message
            }
            else {
                Add-Finding -Type Warning -Message $Message
            }
        }

        if ($DmService.State -ne 'Running') {
            Add-Finding -Type Issue -Message "MDM transport is not running. Current state: $($DmService.State)"
        }
    }

    # Check IME service when required
    $ImeService = Get-ServiceInfo -Name $ImeServiceName

    if ($RequireIME) {
        if (-not $ImeService) {
            Add-Finding -Type Issue -Message "IME service is not installed: $ImeServiceName"
        }
        else {
            Write-Log -Message "IntuneManagementExtension state: $($ImeService.State) | StartMode: $($ImeService.StartMode)"

            if ($ImeService.StartMode -ne 'Auto') {
                $Message = "IME StartMode is '$($ImeService.StartMode)' but expected 'Auto'"
                if ($StrictStartMode) {
                    Add-Finding -Type Issue -Message $Message
                }
                else {
                    Add-Finding -Type Warning -Message $Message
                }
            }

            if ($ImeService.State -ne 'Running') {
                Add-Finding -Type Issue -Message "IME service is not running. Current state: $($ImeService.State)"
            }
        }
    }

    # Check IME activity freshness
    $ImeActivity = $null

    if ($RequireIME -and $ImeService -and (Test-Path -LiteralPath $LogsRoot)) {
        $Timestamps = foreach ($LogPath in $CandidateLogs) {
            $TimestampUtc = Get-LastLogTimestampUtc -Path $LogPath -Tail $TailLines
            if ($TimestampUtc) {
                [pscustomobject]@{
                    Path    = $LogPath
                    TimeUtc = $TimestampUtc
                }
            }
        }

        $Timestamps = @($Timestamps)

        if ($Timestamps.Count -gt 0) {
            $LatestLog = $Timestamps | Sort-Object TimeUtc -Descending | Select-Object -First 1
            $AgeHours  = [math]::Round(($NowUtc - $LatestLog.TimeUtc).TotalHours, 1)

            $ImeActivity = [pscustomobject]@{
                NewestLog      = [System.IO.Path]::GetFileName($LatestLog.Path)
                NewestTimeUtc  = $LatestLog.TimeUtc
                AgeHours       = $AgeHours
                ThresholdHours = $ThresholdHours
            }

            Write-Log -Message "Latest IME activity: $($ImeActivity.NewestLog) | AgeHours=$AgeHours"

            if ($AgeHours -gt $ThresholdHours) {
                Add-Finding -Type Issue -Message "IME activity is stale. Age=$AgeHours hour(s), Threshold=$ThresholdHours hour(s)"
            }
        }
        else {
            Add-Finding -Type Warning -Message "IME logs were not found or could not be read under $LogsRoot"
        }
    }

    $Healthy = ($script:Issues.Count -eq 0)
    $HealthText = if ($Healthy) { 'Healthy' } else { 'Unhealthy' }

    $Result = [pscustomobject]@{
        Health          = $HealthText
        ThresholdHours  = $ThresholdHours
        RequireIME      = $RequireIME
        StrictStartMode = $StrictStartMode
        DmWapPush       = $DmService
        IMEService      = $ImeService
        IMEActivity     = $ImeActivity
        Issues          = $script:Issues
        Warnings        = $script:Warnings
        TimestampUtc    = $NowUtc
    }

    if ($OutputJson) {
        $Result | ConvertTo-Json -Depth 7
    }
    else {
        if ($Healthy) {
            Write-Output 'Healthy | Intune transport baseline looks OK'

            if ($ImeActivity) {
                Write-Output ("Last IME activity: {0} ({1}h ago)" -f $ImeActivity.NewestLog, $ImeActivity.AgeHours)
            }

            if ($script:Warnings.Count -gt 0) {
                Write-Output 'Warnings:'
                $script:Warnings | ForEach-Object {
                    Write-Output (' - ' + $_)
                }
            }
        }
        else {
            Write-Output 'Unhealthy:'
            $script:Issues | ForEach-Object {
                Write-Output (' - ' + $_)
            }

            if ($script:Warnings.Count -gt 0) {
                Write-Output 'Warnings:'
                $script:Warnings | ForEach-Object {
                    Write-Output (' - ' + $_)
                }
            }
        }
    }

    if ($Healthy) {
        Write-Log -Message 'Intune sync health is healthy.' -Level 'SUCCESS'
        exit 0
    }
    else {
        Write-Log -Message ("Issues: " + ($script:Issues -join ' | ')) -Level 'WARNING'
        if ($script:Warnings.Count -gt 0) {
            Write-Log -Message ("Warnings: " + ($script:Warnings -join ' | '))
        }
        exit 1
    }
}
catch {
    Write-Log -Message "Detection failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Output 'Unhealthy'
    exit 1
}

#endregion ---------- Detection Logic ----------