<#
.SYNOPSIS
    Repairs a stalled Intune sync state by fixing services and re-triggering management tasks.

.DESCRIPTION
    This remediation script checks the `DmWapPushService` and
    `IntuneManagementExtension` services, starts or restarts them when needed,
    and then triggers the scheduled tasks used for Intune and MDM sync
    operations.

    It is intended to recover devices where Intune activity appears stale even
    though the management stack is still installed.

.RUN AS
    System or User (according to assignment settings and script requirements).

.EXAMPLE
    .\Repair-IntuneSyncService--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName      = 'Repair-IntuneSyncService--Remediate.ps1'
$SolutionName    = 'Repair-IntuneSyncService'
$ScriptMode      = 'Remediation'
$DmServiceName   = 'DmWapPushService'
$ImeServiceName  = 'IntuneManagementExtension'
$SleepAfterIME   = 8
$ImeHealthLog    = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\HealthIntune-Management-Scripts.log'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Repair-IntuneSyncService--Remediate.txt'
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

    try {
        $imeLogFolder = Split-Path -Path $ImeHealthLog -Parent
        if (Test-Path -LiteralPath $imeLogFolder) {
            Add-Content -Path $ImeHealthLog -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
        }
    }
    catch {}
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

function Get-ServiceInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
}

function Ensure-ServiceRunning {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $serviceInfo = Get-ServiceInfo -Name $Name
    if (-not $serviceInfo) {
        return @{
            Ok     = $false
            Result = 'NotFound'
        }
    }

    try {
        $service = Get-Service -Name $Name -ErrorAction Stop
    }
    catch {
        return @{
            Ok     = $false
            Result = "GetServiceFailed: $($_.Exception.Message)"
        }
    }

    if ($service.Status -eq 'Running') {
        return @{
            Ok     = $true
            Result = 'AlreadyRunning'
        }
    }

    try {
        Start-Service -Name $Name -ErrorAction Stop
        Start-Sleep -Seconds 2

        $service = Get-Service -Name $Name -ErrorAction Stop
        if ($service.Status -eq 'Running') {
            return @{
                Ok     = $true
                Result = 'Started'
            }
        }

        return @{
            Ok     = $false
            Result = 'StartAttemptedButNotRunning'
        }
    }
    catch {
        return @{
            Ok     = $false
            Result = "StartFailed: $($_.Exception.Message)"
        }
    }
}

function Restart-ImeService {
    $imeInfo = Get-ServiceInfo -Name $ImeServiceName
    if (-not $imeInfo) {
        Write-Log -Message ("IME not installed: {0}" -f $ImeServiceName) -Level 'ERROR'
        return $false
    }

    try {
        $service = Get-Service -Name $ImeServiceName -ErrorAction Stop

        if ($service.Status -eq 'Running') {
            Write-Log -Message 'Restarting IntuneManagementExtension service.'
            Restart-Service -Name $ImeServiceName -Force -ErrorAction Stop
        }
        else {
            Write-Log -Message 'Starting IntuneManagementExtension service.'
            Start-Service -Name $ImeServiceName -ErrorAction Stop
        }

        Start-Sleep -Seconds $SleepAfterIME
        $service = Get-Service -Name $ImeServiceName -ErrorAction Stop

        if ($service.Status -eq 'Running') {
            Write-Log -Message 'IntuneManagementExtension service is running.' -Level 'SUCCESS'
            return $true
        }

        Write-Log -Message ("IntuneManagementExtension failed to reach running state. Current state: {0}" -f $service.Status) -Level 'ERROR'
        return $false
    }
    catch {
        Write-Log -Message ("Failed to start or restart IntuneManagementExtension: {0}" -f $_.Exception.Message) -Level 'ERROR'
        return $false
    }
}

function Invoke-ScheduledTaskFallback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FullTaskName
    )

    try {
        $process = Start-Process -FilePath 'schtasks.exe' -ArgumentList "/Run /TN `"$FullTaskName`"" -WindowStyle Hidden -PassThru -Wait -ErrorAction Stop
        return ($process.ExitCode -eq 0)
    }
    catch {
        return $false
    }
}

function Get-EnterpriseMgmtTasks {
    $getScheduledTask = Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue
    if ($getScheduledTask) {
        try {
            return @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskPath -like '\Microsoft\Windows\EnterpriseMgmt\*' })
        }
        catch {}
    }

    $tasks = @()

    try {
        $rawTasks = & schtasks.exe /Query /FO LIST /V 2>$null
        $currentTaskName = $null

        foreach ($line in $rawTasks) {
            if ($line -match '^TaskName:\s+(?<n>.+)$') {
                $currentTaskName = $Matches['n'].Trim()

                if ($currentTaskName -like '\Microsoft\Windows\EnterpriseMgmt\*') {
                    $taskName = Split-Path -Path $currentTaskName -Leaf
                    $taskPath = $currentTaskName.Substring(0, $currentTaskName.Length - $taskName.Length)

                    $tasks += [PSCustomObject]@{
                        TaskName = $taskName
                        TaskPath = $taskPath
                    }
                }
            }
        }
    }
    catch {}

    return @($tasks)
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

$dmService = Get-ServiceInfo -Name $DmServiceName
if (-not $dmService) {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Required service is missing: {0}" -f $DmServiceName)
}

Write-Log -Message ("DmWapPushService state: {0}; start mode: {1}" -f $dmService.State, $dmService.StartMode)

$dmResult = Ensure-ServiceRunning -Name $DmServiceName
if ($dmResult.Ok) {
    Write-Log -Message ("DmWapPushService action result: {0}" -f $dmResult.Result) -Level 'SUCCESS'
}
else {
    Write-Log -Message ("DmWapPushService action result: {0}" -f $dmResult.Result) -Level 'WARNING'
}

if (-not (Restart-ImeService)) {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'Failed to recover IntuneManagementExtension service.'
}

Write-Log -Message 'Discovering EnterpriseMgmt scheduled tasks.'
$tasks = @(Get-EnterpriseMgmtTasks)
Write-Log -Message ("EnterpriseMgmt tasks discovered: {0}" -f $tasks.Count)

if ($tasks.Count -lt 1) {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'No EnterpriseMgmt scheduled tasks were found.'
}

$attempted = 0
$triggered = 0
$startScheduledTask = Get-Command -Name Start-ScheduledTask -ErrorAction SilentlyContinue

foreach ($task in $tasks) {
    $attempted++
    $taskPath = $task.TaskPath

    if (-not $taskPath.EndsWith('\')) {
        $taskPath += '\'
    }

    $fullTaskName = '{0}{1}' -f $taskPath, $task.TaskName
    $taskTriggered = $false

    if ($startScheduledTask) {
        try {
            Start-ScheduledTask -TaskPath $taskPath -TaskName $task.TaskName -ErrorAction Stop
            $taskTriggered = $true
        }
        catch {
            $taskTriggered = $false
        }
    }

    if (-not $taskTriggered) {
        $taskTriggered = Invoke-ScheduledTaskFallback -FullTaskName $fullTaskName
    }

    if ($taskTriggered) {
        $triggered++
        Write-Log -Message ("Triggered scheduled task: {0}" -f $fullTaskName) -Level 'SUCCESS'
    }
    else {
        Write-Log -Message ("Failed to trigger scheduled task: {0}" -f $fullTaskName) -Level 'WARNING'
    }
}

Write-Log -Message ("Task trigger summary: Attempted={0}; Triggered={1}" -f $attempted, $triggered)

if ($triggered -lt 1) {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'No EnterpriseMgmt sync task was triggered successfully.'
}

Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Intune sync remediation completed successfully.'

#endregion ---------- Main ----------
