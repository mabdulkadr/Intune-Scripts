<#
.SYNOPSIS
    Starts the device management sync task.

.DESCRIPTION
    This remediation script searches for Enterprise Management scheduled tasks
    named PushLaunch and starts the matching task instances to trigger a device
    management sync attempt.

    The script:
    - Searches for PushLaunch tasks under Microsoft\Windows\EnterpriseMgmt
    - Handles multiple matching tasks safely
    - Starts each matching task
    - Waits briefly, then reads updated task metadata
    - Logs path, state, and last run details

    Exit codes:
    - Exit 0: One or more PushLaunch tasks were started successfully
    - Exit 1: No matching task was found, task start failed, or verification failed

.RUN AS
    System or User

.EXAMPLE
    .\Invoke-DeviceManagementSync--Remediate.ps1

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

$ScriptName      = 'Invoke-DeviceManagementSync--Remediate.ps1'
$SolutionName    = 'Invoke-DeviceManagementSync'
$ScriptMode      = 'Remediation'
$TaskName        = 'PushLaunch'
$TaskPathFilter  = '\Microsoft\Windows\EnterpriseMgmt\'
$WaitSeconds     = 5

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
$LogFile    = Join-Path $LogRoot 'Invoke-DeviceManagementSync--Remediate.txt'
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

function Start-PushLaunchTasks {
    $Tasks = @(Get-PushLaunchTasks)

    if ($Tasks.Count -eq 0) {
        throw "No '$TaskName' tasks were found under '$TaskPathFilter'."
    }

    Write-Log -Message ("Found {0} matching '{1}' task(s)." -f $Tasks.Count, $TaskName)

    $Results = @()

    foreach ($Task in $Tasks) {
        $Started = $false
        $Details = $null

        try {
            Write-Log -Message ("Starting task | Path: {0} | Name: {1}" -f $Task.TaskPath, $Task.TaskName)

            Start-ScheduledTask -TaskPath $Task.TaskPath -TaskName $Task.TaskName -ErrorAction Stop
            $Started = $true

            Write-Log -Level 'SUCCESS' -Message ("Start request sent successfully | Path: {0} | Name: {1}" -f $Task.TaskPath, $Task.TaskName)
        }
        catch {
            Write-Log -Level 'ERROR' -Message ("Failed to start task | Path: {0} | Name: {1} | Details: {2}" -f $Task.TaskPath, $Task.TaskName, $_.Exception.Message)
        }

        try {
            $TaskInfo = Get-ScheduledTask -TaskPath $Task.TaskPath -TaskName $Task.TaskName -ErrorAction Stop | Get-ScheduledTaskInfo -ErrorAction Stop

            $Details = [PSCustomObject]@{
                TaskName       = $Task.TaskName
                TaskPath       = $Task.TaskPath
                Started        = $Started
                LastRunTime    = $TaskInfo.LastRunTime
                LastTaskResult = $TaskInfo.LastTaskResult
                NextRunTime    = $TaskInfo.NextRunTime
            }

            Write-Log -Level 'DETAIL' -Message ("Task status | Path: {0} | LastRunTime: {1} | LastTaskResult: {2} | NextRunTime: {3}" -f $Task.TaskPath, $TaskInfo.LastRunTime, $TaskInfo.LastTaskResult, $TaskInfo.NextRunTime)
        }
        catch {
            Write-Log -Level 'WARNING' -Message ("Failed to read task info after start | Path: {0} | Name: {1} | Details: {2}" -f $Task.TaskPath, $Task.TaskName, $_.Exception.Message)

            $Details = [PSCustomObject]@{
                TaskName       = $Task.TaskName
                TaskPath       = $Task.TaskPath
                Started        = $Started
                LastRunTime    = $null
                LastTaskResult = $null
                NextRunTime    = $null
            }
        }

        $Results += $Details
    }

    return @($Results)
}

#endregion -- FUNCTIONS --------------------------------------------------------

#region -- MAIN ----------------------------------------------------------------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Starting scheduled task '{0}' under '{1}'" -f $TaskName, $TaskPathFilter)

try {
    $Tasks = @(Get-PushLaunchTasks)

    if ($Tasks.Count -eq 0) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("No matching '{0}' tasks were found under '{1}'." -f $TaskName, $TaskPathFilter) -OutputMessage 'PushLaunch task not found'
    }

    $BeforeState = @()
    foreach ($Task in $Tasks) {
        try {
            $TaskInfo = Get-ScheduledTask -TaskPath $Task.TaskPath -TaskName $Task.TaskName -ErrorAction Stop | Get-ScheduledTaskInfo -ErrorAction Stop
            $BeforeState += [PSCustomObject]@{
                TaskName    = $Task.TaskName
                TaskPath    = $Task.TaskPath
                LastRunTime = $TaskInfo.LastRunTime
            }

            Write-Log -Level 'DETAIL' -Message ("Before start | Path: {0} | LastRunTime: {1}" -f $Task.TaskPath, $TaskInfo.LastRunTime)
        }
        catch {
            Write-Log -Level 'WARNING' -Message ("Failed to capture pre-start state | Path: {0} | Name: {1} | Details: {2}" -f $Task.TaskPath, $Task.TaskName, $_.Exception.Message)
        }
    }

    $StartedResults = @(Start-PushLaunchTasks)

    Start-Sleep -Seconds $WaitSeconds

    $SuccessfulStarts = @(
        $StartedResults | Where-Object {
            $_.Started -eq $true
        }
    )

    if ($SuccessfulStarts.Count -eq 0) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'No PushLaunch task could be started successfully.' -OutputMessage 'PushLaunch start failed'
    }

    Write-Log -Message ("Tasks successfully started: {0}" -f $SuccessfulStarts.Count)

    $LatestRun = $SuccessfulStarts |
        Where-Object { $null -ne $_.LastRunTime } |
        Sort-Object -Property LastRunTime -Descending |
        Select-Object -First 1

    if ($LatestRun) {
        Write-Log -Level 'DETAIL' -Message ("Latest observed run | Path: {0} | LastRunTime: {1} | LastTaskResult: {2}" -f $LatestRun.TaskPath, $LatestRun.LastRunTime, $LatestRun.LastTaskResult)
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'PushLaunch task start request completed successfully.' -OutputMessage 'Sync triggered'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to start PushLaunch task: {0}" -f $_.Exception.Message) -OutputMessage 'PushLaunch remediation failed'
}

#endregion -- MAIN -------------------------------------------------------------