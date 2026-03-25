<#
.SYNOPSIS
    Runs Windows Disk Cleanup using the cleanup handlers configured in the script.

.DESCRIPTION
    This remediation script writes the selected cleanup handler flags to the
    registry and launches `CleanMgr.exe /sagerun:1`.

    Where the script includes extra cleanup paths, it also removes temporary
    content after the Disk Cleanup pass finishes.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Get-DiskCleanupStatus--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName           = 'Get-DiskCleanupStatus--Remediate.ps1'
$SolutionName         = 'Get-DiskCleanupStatus'
$ScriptMode           = 'Remediation'
$CleanupTypeSelection = 'Temporary Sync Files', 'Downloaded Program Files', 'Memory Dump Files', 'Recycle Bin'
$VolumeCachesPath     = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
$StateFlagName        = 'StateFlags0001'
$StateFlagValue       = 2
$CleanMgrArguments    = '/sagerun:1'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Get-DiskCleanupStatus--Remediate.txt'
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

function Enable-CleanupHandlers {
    foreach ($cleanupType in $CleanupTypeSelection) {
        $handlerPath = Join-Path $VolumeCachesPath $cleanupType

        if (-not (Test-Path -Path $handlerPath)) {
            Write-Log -Message ("Cleanup handler not found and will be skipped: {0}" -f $cleanupType) -Level 'WARNING'
            continue
        }

        New-ItemProperty -Path $handlerPath -Name $StateFlagName -Value $StateFlagValue -PropertyType DWord -Force | Out-Null
        Write-Log -Message ("Enabled cleanup handler: {0}" -f $cleanupType)
    }
}

function Invoke-DiskCleanup {
    $cleanMgrPath = Join-Path $env:SystemRoot 'System32\cleanmgr.exe'

    if (-not (Test-Path -Path $cleanMgrPath)) {
        throw 'CleanMgr.exe was not found on this device.'
    }

    Write-Log -Message ("Starting Disk Cleanup: {0} {1}" -f $cleanMgrPath, $CleanMgrArguments)
    Start-Process -FilePath $cleanMgrPath -ArgumentList $CleanMgrArguments -Wait -NoNewWindow -ErrorAction Stop
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message 'Configuring selected Disk Cleanup handlers.'

try {
    Enable-CleanupHandlers
    Invoke-DiskCleanup
    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Disk Cleanup completed successfully.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Disk Cleanup remediation failed: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
