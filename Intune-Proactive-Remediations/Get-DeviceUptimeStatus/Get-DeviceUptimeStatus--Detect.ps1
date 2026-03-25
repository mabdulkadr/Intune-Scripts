<#
.SYNOPSIS
    Checks whether the device uptime has reached the configured threshold.

.DESCRIPTION
    This detection script uses `Get-ComputerInfo` and reads `OSUptime`.

    It returns success only when the uptime is below the configured threshold
    and returns a non-zero result when the device has been running for too long.

    Exit codes:
    - Exit 0: Device uptime is below the threshold
    - Exit 1: Device uptime reached the threshold or could not be verified

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Get-DeviceUptimeStatus--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName    = 'Get-DeviceUptimeStatus--Detect.ps1'
$SolutionName  = 'Get-DeviceUptimeStatus'
$ScriptMode    = 'Detection'
$MaxUptimeDays = 7

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Get-DeviceUptimeStatus--Detect.txt'
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

function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO',

        [string]$OutputMessage
    )

    Write-Log -Message $Message -Level $Level

    if ($OutputMessage) {
        Write-Output $OutputMessage
    }

    exit $ExitCode
}

function Get-Uptime {
    $computerInfo = Get-ComputerInfo -ErrorAction Stop
    return $computerInfo.OSUptime
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Checking whether device uptime reached {0} day(s)." -f $MaxUptimeDays)

try {
    $uptime = Get-Uptime
    $uptimeDays = [int][Math]::Floor($uptime.TotalDays)

    Write-Log -Message ("Current OSUptime: {0}" -f $uptime)
    Write-Log -Message ("Current uptime days: {0}" -f $uptimeDays)

    if ($uptimeDays -ge $MaxUptimeDays) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("Device uptime reached {0} day(s). Restart notification should be shown." -f $uptimeDays)
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("Device uptime is below threshold: {0} day(s)." -f $uptimeDays)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to read OS uptime: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
