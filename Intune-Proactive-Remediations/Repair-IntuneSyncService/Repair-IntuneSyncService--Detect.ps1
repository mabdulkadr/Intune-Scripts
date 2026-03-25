<#
.SYNOPSIS
    Checks whether core Intune sync services and recent IME log activity indicate a healthy management state.

.DESCRIPTION
    This detection script inspects the `DmWapPushService` and
    `IntuneManagementExtension` services through CIM, validates their start mode
    and running state, and reviews recent timestamps from Intune Management
    Extension log files under
    `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.

    It returns a non-zero result when the required services are stopped or
    missing, when start mode does not match the configured expectation, or when
    IME activity appears stale beyond the configured threshold.

    Exit codes:
    - Exit 0: Services and log freshness checks passed
    - Exit 1: One or more service or IME activity checks failed

.RUN AS
    System or User (according to assignment settings and script requirements).

.EXAMPLE
    .\Repair-IntuneSyncService--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>
[CmdletBinding()]
param(
    [int]$ThresholdHours = 24,
    [bool]$RequireIME = $true,
    [bool]$StrictStartMode = $false,
    [switch]$OutputJson,
    [ValidateRange(50, 2000)]
    [int]$TailLines = 300
)

#region ---------- Configuration ----------

$ScriptName      = 'Repair-IntuneSyncService--Detect.ps1'
$SolutionName    = 'Repair-IntuneSyncService'
$ScriptMode      = 'Detection'
$NowUtc          = (Get-Date).ToUniversalTime()
$LogsRoot        = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$ImeServiceName  = 'IntuneManagementExtension'
$DmServiceName   = 'DmWapPushService'
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

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Repair-IntuneSyncService--Detect.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

function Initialize-Log {
    try {
        if (-not (Test-Path -Path $LogRoot)) {
            New-Item -Path $LogRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }

        return $true
    }
    catch {
        Write-Host "Logging initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Write-Banner {
    $title = "{0} | {1}" -f $SolutionName, $ScriptMode
    $lines = @('', $BannerLine, $title, $BannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        }
        else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady) {
            Add-Content -Path $LogFile -Value $line -Encoding UTF8
        }
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $line = '{0} | {1,-7} | {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'WARNING' { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        default   { Write-Host $line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $line -Encoding UTF8
        }
        catch {}
    }
}

function Add-Finding {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Issue', 'Warning')]
        [string]$Type = 'Issue'
    )

    if ($Type -eq 'Issue') {
        [void]$script:Issues.Add($Message)
        Write-Log -Message $Message -Level 'ERROR'
    }
    else {
        [void]$script:Warnings.Add($Message)
        Write-Log -Message $Message -Level 'WARNING'
    }
}

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
    catch {
        return $null
    }
}

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
        catch {}
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
        catch {}
    }

    return $null
}

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
            $timestamp = Parse-CMTraceTimestampUtc -Line $lines[$index]
            if ($timestamp) {
                return $timestamp
            }
        }
    }
    catch {}

    try {
        return (Get-Item -LiteralPath $Path -ErrorAction Stop).LastWriteTimeUtc
    }
    catch {
        return $null
    }
}

function Write-StructuredResult {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Result
    )

    if ($OutputJson) {
        Write-Output ($Result | ConvertTo-Json -Depth 7)
        return
    }

    if ($Result.Health -eq 'Healthy') {
        Write-Output 'Healthy | Intune transport baseline OK'

        if ($Result.IMEActivity) {
            Write-Output ('Last IME activity: {0} ({1}h ago)' -f $Result.IMEActivity.NewestLog, $Result.IMEActivity.AgeHours)
        }

        foreach ($warning in $Result.Warnings) {
            Write-Output ('Warning: ' + $warning)
        }
    }
    else {
        Write-Output 'Unhealthy:'
        foreach ($issue in $Result.Issues) {
            Write-Output (' - ' + $issue)
        }

        foreach ($warning in $Result.Warnings) {
            Write-Output ('Warning: ' + $warning)
        }
    }
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
$script:Issues   = New-Object 'System.Collections.Generic.List[string]'
$script:Warnings = New-Object 'System.Collections.Generic.List[string]'

Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("ThresholdHours={0}; RequireIME={1}; StrictStartMode={2}; TailLines={3}" -f $ThresholdHours, $RequireIME, $StrictStartMode, $TailLines)

$dmService = Get-ServiceInfo -Name $DmServiceName
if (-not $dmService) {
    Add-Finding -Type 'Issue' -Message ("MDM transport missing: {0}" -f $DmServiceName)
}
else {
    Write-Log -Message ("DmWapPushService state: {0}; start mode: {1}" -f $dmService.State, $dmService.StartMode)

    if ($dmService.StartMode -ne 'Auto') {
        $message = "MDM transport StartMode is '$($dmService.StartMode)' (expected Auto)"
        if ($StrictStartMode) {
            Add-Finding -Type 'Issue' -Message $message
        }
        else {
            Add-Finding -Type 'Warning' -Message $message
        }
    }

    if ($dmService.State -ne 'Running') {
        Add-Finding -Type 'Issue' -Message ("MDM transport not running: State={0}" -f $dmService.State)
    }
}

$imeService = Get-ServiceInfo -Name $ImeServiceName
if ($RequireIME) {
    if (-not $imeService) {
        Add-Finding -Type 'Issue' -Message ("IME not installed: {0}" -f $ImeServiceName)
    }
    else {
        Write-Log -Message ("IntuneManagementExtension state: {0}; start mode: {1}" -f $imeService.State, $imeService.StartMode)

        if ($imeService.StartMode -ne 'Auto') {
            $message = "IME StartMode is '$($imeService.StartMode)' (expected Auto)"
            if ($StrictStartMode) {
                Add-Finding -Type 'Issue' -Message $message
            }
            else {
                Add-Finding -Type 'Warning' -Message $message
            }
        }

        if ($imeService.State -ne 'Running') {
            Add-Finding -Type 'Issue' -Message ("IME not running: State={0}" -f $imeService.State)
        }
    }
}

$imeActivity = $null
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
    Write-Log -Message ("IME log timestamps collected: {0}" -f $logCandidates.Count)

    if ($logCandidates.Count -gt 0) {
        $latest = $logCandidates | Sort-Object TimeUtc -Descending | Select-Object -First 1
        $ageHours = [math]::Round(($NowUtc - $latest.TimeUtc).TotalHours, 1)

        $imeActivity = [PSCustomObject]@{
            NewestLog      = [System.IO.Path]::GetFileName($latest.Path)
            NewestTimeUtc  = $latest.TimeUtc
            AgeHours       = $ageHours
            ThresholdHours = $ThresholdHours
        }

        Write-Log -Message ("Newest IME log: {0}; age: {1} hour(s)" -f $imeActivity.NewestLog, $imeActivity.AgeHours)

        if ($ageHours -gt $ThresholdHours) {
            Add-Finding -Type 'Issue' -Message ("IME activity stale ({0} h > {1} h)" -f $ageHours, $ThresholdHours)
        }
    }
    else {
        Add-Finding -Type 'Warning' -Message ("IME logs not found or unreadable under {0}" -f $LogsRoot)
    }
}
elseif ($RequireIME) {
    Add-Finding -Type 'Warning' -Message ("IME log folder not found: {0}" -f $LogsRoot)
}

$healthy = ($script:Issues.Count -eq 0)
$result = [PSCustomObject]@{
    Health          = $(if ($healthy) { 'Healthy' } else { 'Unhealthy' })
    ThresholdHours  = $ThresholdHours
    RequireIME      = $RequireIME
    StrictStartMode = $StrictStartMode
    DmWapPush       = $dmService
    IMEService      = $imeService
    IMEActivity     = $imeActivity
    Issues          = @($script:Issues)
    Warnings        = @($script:Warnings)
    TimestampUtc    = $NowUtc
}

Write-StructuredResult -Result $result

if ($healthy) {
    Write-Log -Message 'Intune transport baseline looks healthy.' -Level 'SUCCESS'
    exit 0
}

Write-Log -Message ("Intune transport baseline is unhealthy. Issues detected: {0}" -f $script:Issues.Count) -Level 'ERROR'
exit 1

#endregion ---------- Main ----------
