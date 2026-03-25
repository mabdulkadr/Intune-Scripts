<#
.SYNOPSIS
    Detect whether Intune Management Extension sync occurred recently.

.DESCRIPTION
    This detection script checks the Intune diagnostic event log for the
    Intune Management Extension sync event.

    If the target event is found within the configured lookback window, the
    device is treated as compliant.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant (remediation should run)

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\Invoke-IntuneDeviceSync--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName     = 'Invoke-IntuneDeviceSync--Detect.ps1'
$SolutionName   = 'Invoke-IntuneDeviceSync'
$ScriptMode     = 'Detection'
$LookbackHours  = 1
$LogName        = 'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational'
$EventID        = 208
$TaskName       = 'Trigger-IME-Sync-Hourly'

$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

$LogRoot    = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile    = Join-Path $LogRoot 'Invoke-IntuneDeviceSync--Detect.txt'
$BannerLine = '=' * 78

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

function Get-RecentImeSyncEvent {
    $lookbackMilliseconds = $LookbackHours * 60 * 60 * 1000
    $filterXPath = "*[System[EventID=$EventID and TimeCreated[timediff(@SystemTime) <= $lookbackMilliseconds]]]"
    return Get-WinEvent -LogName $LogName -FilterXPath $filterXPath -ErrorAction SilentlyContinue
}

function Test-FallbackTask {
    $scheduledTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    return ($scheduledTask -and $scheduledTask.State -ne 'Disabled')
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Checking log name: {0}" -f $LogName)
Write-Log -Message ("Checking event ID: {0}" -f $EventID)
Write-Log -Message ("Lookback window: {0} hour(s)" -f $LookbackHours)
Write-Log -Message ("Fallback task name: {0}" -f $TaskName)

try {
    $syncEvent = Get-RecentImeSyncEvent

    if ($syncEvent) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("Intune Management Extension sync was detected within the last {0} hour(s)." -f $LookbackHours) -OutputMessage 'Intune Management Extension Sync detected within the last hour.'
    }

    if (Test-FallbackTask) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("No recent IME sync event was found, but scheduled task '{0}' exists and is enabled." -f $TaskName) -OutputMessage 'Intune IME sync task is configured.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("No Intune Management Extension sync was detected within the last {0} hour(s), and scheduled task '{1}' is missing or disabled." -f $LookbackHours, $TaskName) -OutputMessage 'No Intune Management Extension Sync detected within the last hour.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Detection error: {0}" -f $_.Exception.Message) -OutputMessage ("Detection error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
