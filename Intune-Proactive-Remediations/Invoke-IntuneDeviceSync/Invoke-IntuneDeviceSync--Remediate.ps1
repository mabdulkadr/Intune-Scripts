<#
.SYNOPSIS
    Remediate Intune Management Extension sync by triggering it immediately and scheduling recurring sync.

.DESCRIPTION
    This remediation script:
    1. Triggers Intune Management Extension sync immediately.
    2. Creates or updates a scheduled task that triggers the same sync every hour.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\Invoke-IntuneDeviceSync--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName       = 'Invoke-IntuneDeviceSync--Remediate.ps1'
$SolutionName     = 'Invoke-IntuneDeviceSync'
$ScriptMode       = 'Remediation'
$ImeSyncUri       = 'intunemanagementextension://syncapp'
$TaskName         = 'Trigger-IME-Sync-Hourly'
$TaskDescription  = 'Scheduled task to trigger Intune Management Extension Sync every hour.'
$TaskExecute      = 'PowerShell.exe'
$TaskArgument     = "-NoProfile -WindowStyle Hidden -Command `"(New-Object -ComObject Shell.Application).Open('$ImeSyncUri')`""
$TriggerDelayMins = 1
$RepeatHours      = 1

$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

$LogRoot    = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile    = Join-Path $LogRoot 'Invoke-IntuneDeviceSync--Remediate.txt'
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

function Trigger-ImeSync {
    Write-Log -Message 'Triggering Intune Management Extension sync.'
    $shell = New-Object -ComObject Shell.Application
    $shell.Open($ImeSyncUri)
    Write-Log -Message 'Intune Management Extension sync triggered successfully.' -Level 'SUCCESS'
}

function Ensure-ImeSyncScheduledTask {
    Write-Log -Message 'Creating or updating the scheduled task for hourly IME sync.'

    $action = New-ScheduledTaskAction -Execute $TaskExecute -Argument $TaskArgument
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes($TriggerDelayMins) -RepetitionInterval (New-TimeSpan -Hours $RepeatHours)

    Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Action $action -Trigger $trigger -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
    Write-Log -Message ("Scheduled task '{0}' created or updated successfully." -f $TaskName) -Level 'SUCCESS'
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("IME sync URI: {0}" -f $ImeSyncUri)
Write-Log -Message ("Task name: {0}" -f $TaskName)

try {
    Trigger-ImeSync
    Ensure-ImeSyncScheduledTask
    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Remediation process completed successfully.' -OutputMessage 'Remediation process completed successfully.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Remediation failed: {0}" -f $_.Exception.Message) -OutputMessage ("Remediation failed: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
