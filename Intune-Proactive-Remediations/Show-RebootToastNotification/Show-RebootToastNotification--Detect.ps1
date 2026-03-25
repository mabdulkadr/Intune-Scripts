<#
.SYNOPSIS
    Decides whether the reboot reminder toast should run.

.DESCRIPTION
    This detection script preserves the original package behavior. It compares
    the current time to the start time of the current PowerShell process, not
    to the actual system boot time.

    Exit codes:
    - Exit 0: Current PowerShell process has been running for more than 7 days
    - Exit 1: Current PowerShell process has been running for less than 7 days

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Show-RebootToastNotification--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName      = 'Show-RebootToastNotification--Detect.ps1'
$SolutionName    = 'Show-RebootToastNotification'
$ScriptMode      = 'Detection'
$ThresholdDays   = 7
$ThresholdHours  = $ThresholdDays * 24

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Show-RebootToastNotification--Detect.txt'
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
        [string]$Level = 'INFO'
    )

    Write-Log -Message $Message -Level $Level
    exit $ExitCode
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

try {
    $now = Get-Date
    $processStart = (Get-Process -Id $pid -ErrorAction Stop).StartTime
    $hours = [math]::Round((New-TimeSpan -Start $processStart -End $now).TotalHours, 2)

    Write-Log -Message ("Current process runtime hours: {0}; ThresholdHours: {1}" -f $hours, $ThresholdHours)

    if ($hours -gt $ThresholdHours) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Current PowerShell process runtime exceeded the reboot reminder threshold.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -Message 'Current PowerShell process runtime is below the reboot reminder threshold.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Detection error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
