<#
.SYNOPSIS
    Checks whether free space on drive C: is below the configured threshold.

.DESCRIPTION
    This detection script reads free space from `Get-PSDrive` for drive `C:`
    and compares it with the configured threshold.

    Exit codes:
    - Exit 0: Free space is above the threshold
    - Exit 1: Free space is below the threshold or could not be verified

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Get-DiskCleanupStatus--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName        = 'Get-DiskCleanupStatus--Detect.ps1'
$SolutionName      = 'Get-DiskCleanupStatus'
$ScriptMode        = 'Detection'
$StorageThresholdGB = 15

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Get-DiskCleanupStatus--Detect.txt'
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

function Get-FreeSpaceBytes {
    $drive = Get-PSDrive -Name 'C' -ErrorAction Stop
    return [int64]$drive.Free
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Checking free space threshold on drive C:. Threshold = {0} GB." -f $StorageThresholdGB)

try {
    $freeBytes = Get-FreeSpaceBytes
    $freeGB = [Math]::Round($freeBytes / 1GB, 2)

    Write-Log -Message ("Current free space on C:: {0} GB" -f $freeGB)

    if ($freeBytes -lt ($StorageThresholdGB * 1GB)) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("Free space is below threshold: {0} GB available." -f $freeGB)
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("Free space is above threshold: {0} GB available." -f $freeGB)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to evaluate free space on drive C:: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
