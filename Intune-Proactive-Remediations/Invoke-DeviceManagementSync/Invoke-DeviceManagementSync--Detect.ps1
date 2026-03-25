<#
.SYNOPSIS
    Checks whether the device management sync task has gone stale.

.DESCRIPTION
    This detection script searches for Microsoft Enterprise Management scheduled tasks
    named PushLaunch and evaluates the most recent valid LastRunTime.

    The script:
    - Searches PushLaunch tasks under Microsoft\Windows\EnterpriseMgmt
    - Handles multiple matching tasks safely
    - Selects the newest valid LastRunTime
    - Compares the task age against the configured stale threshold

    Exit codes:
    - Exit 0: A valid PushLaunch task ran within the configured threshold
    - Exit 1: PushLaunch is stale, missing, never ran, or could not be verified

.RUN AS
    System or User

.EXAMPLE
    .\Invoke-DeviceManagementSync--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.3
#>

#region -- BOOTSTRAP -----------------------------------------------------------

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#endregion -- BOOTSTRAP --------------------------------------------------------

#region -- CONFIGURATION -------------------------------------------------------

$ScriptName      = 'Invoke-DeviceManagementSync--Detect.ps1'
$SolutionName    = 'Invoke-DeviceManagementSync'
$ScriptMode      = 'Detection'
$TaskName        = 'PushLaunch'
$TaskPathFilter  = '\Microsoft\Windows\EnterpriseMgmt\'
$StaleAfterDays  = 2

$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
elseif ($env:SystemRoot) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    'C:'
}

$LogRoot    = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile    = Join-Path $LogRoot 'Invoke-DeviceManagementSync--Detect.txt'
$BannerLine = '=' * 78

#endregion -- CONFIGURATION ----------------------------------------------------

#region -- FUNCTIONS -----------------------------------------------------------

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
        Write-Host ("Logging initialization failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

function Write-Banner {
    $Title = '{0} | {1}' -f $SolutionName, $ScriptMode
    $Lines = @(
        ''
        $BannerLine
        $Title
        $BannerLine
    )

    foreach ($Line in $Lines) {
        if ($Line -eq $Title) {
            Write-Host $Line -ForegroundColor White
        }
        else {
            Write-Host $Line -ForegroundColor DarkGray
        }

        if ($script:LogReady) {
            try {
                Add-Content -Path $LogFile -Value $Line -Encoding UTF8
            }
            catch {}
        }
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'DETAIL')]
        [string]$Level = 'INFO'
    )

    $Line = '{0} | {1,-7} | {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        'WARNING' { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        'DETAIL'  { Write-Host $Line -ForegroundColor DarkGray }
        default   { Write-Host $Line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
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

    if (-not [string]::IsNullOrWhiteSpace($OutputMessage)) {
        Write-Output $OutputMessage
    }

    exit $ExitCode
}

function Get-PushLaunchTasks {
    try {
        $Tasks = @(
            Get-ScheduledTask -ErrorAction Stop | Where-Object {
                $_.TaskName -eq $TaskName -and
                $_.TaskPath -like "$TaskPathFilter*"
            }
        )

        return @($Tasks)
    }
    catch {
        throw "Failed to enumerate scheduled tasks. $($_.Exception.Message)"
    }
}

function Get-LatestValidTaskRun {
    $Tasks = @(Get-PushLaunchTasks)

    if ($Tasks.Count -eq 0) {
        throw "No '$TaskName' tasks were found under '$TaskPathFilter'."
    }

    Write-Log -Message ("Found {0} matching '{1}' task(s)." -f $Tasks.Count, $TaskName)

    $TaskRunObjects = @()

    foreach ($Task in $Tasks) {
        try {
            $TaskInfo = $Task | Get-ScheduledTaskInfo -ErrorAction Stop
            $LastRunTime = $TaskInfo.LastRunTime

            Write-Log -Level 'DETAIL' -Message ("Task found | Path: {0} | Name: {1} | LastRunTime: {2}" -f $Task.TaskPath, $Task.TaskName, $LastRunTime)

            if ($null -eq $LastRunTime) {
                continue
            }

            # Some tasks may return MinValue-like dates when never run.
            if ($LastRunTime -is [datetime]) {
                if ($LastRunTime.Year -le 1901) {
                    continue
                }

                $TaskRunObjects += [PSCustomObject]@{
                    TaskName     = $Task.TaskName
                    TaskPath     = $Task.TaskPath
                    LastRunTime  = $LastRunTime
                }
            }
        }
        catch {
            Write-Log -Level 'WARNING' -Message ("Failed to read task info | Path: {0} | Name: {1} | Details: {2}" -f $Task.TaskPath, $Task.TaskName, $_.Exception.Message)
        }
    }

    if (@($TaskRunObjects).Count -eq 0) {
        throw "Matching '$TaskName' tasks were found, but none had a valid LastRunTime."
    }

    $LatestTask = $TaskRunObjects | Sort-Object -Property LastRunTime -Descending | Select-Object -First 1
    $Age = New-TimeSpan -Start $LatestTask.LastRunTime -End (Get-Date)

    return [PSCustomObject]@{
        TaskName     = $LatestTask.TaskName
        TaskPath     = $LatestTask.TaskPath
        LastRunTime  = $LatestTask.LastRunTime
        Age          = $Age
    }
}

#endregion -- FUNCTIONS --------------------------------------------------------

#region -- MAIN ----------------------------------------------------------------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Checking scheduled task age for '{0}' under '{1}'" -f $TaskName, $TaskPathFilter)

try {
    $TaskState = Get-LatestValidTaskRun

    Write-Log -Message ("Selected task path: {0}" -f $TaskState.TaskPath)
    Write-Log -Message ("Last run time: {0}" -f $TaskState.LastRunTime)
    Write-Log -Message ("Days since last run: {0}" -f $TaskState.Age.Days)
    Write-Log -Message ("Total age: {0}" -f $TaskState.Age)

    if ($TaskState.Age.TotalDays -gt $StaleAfterDays) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("Last sync was more than {0} day(s) ago." -f $StaleAfterDays) -OutputMessage ("Last sync was more than {0} days ago." -f $StaleAfterDays)
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'PushLaunch task ran within the allowed interval.' -OutputMessage 'Sync Complete'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to evaluate PushLaunch task state: {0}" -f $_.Exception.Message) -OutputMessage 'PushLaunch verification failed'
}

#endregion -- MAIN -------------------------------------------------------------