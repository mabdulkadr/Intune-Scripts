<#
.SYNOPSIS
    Checks whether the free-space percentage on C: is below the configured alert threshold.

.DESCRIPTION
    This detection script reads `Win32_LogicalDisk` for drive `C:` and compares
    the calculated free-space percentage to `$Percent_Alert`.

    Exit codes:
    - Exit 0: Free space is above the configured alert threshold
    - Exit 1: Free space is at or below the configured alert threshold

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Show-LowDiskSpaceAlert--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName    = 'Show-LowDiskSpaceAlert--Detect.ps1'
$SolutionName  = 'Show-LowDiskSpaceAlert'
$ScriptMode    = 'Detection'
$Percent_Alert = 20
$DriveLetter   = 'C:'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Show-LowDiskSpaceAlert--Detect.txt'
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
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $DriveLetter) -ErrorAction Stop
    if ($null -eq $disk -or $disk.Size -le 0) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Unable to read valid disk information for {0}." -f $DriveLetter)
    }

    $freeSpacePercent = [math]::Round((($disk.FreeSpace / $disk.Size) * 100), 2)
    $freeSpaceGb = [math]::Round(($disk.FreeSpace / 1GB), 2)
    $totalSpaceGb = [math]::Round(($disk.Size / 1GB), 2)

    Write-Log -Message ("Drive={0}; FreeSpacePercent={1}; FreeSpaceGB={2}; TotalSpaceGB={3}; AlertThreshold={4}" -f $DriveLetter, $freeSpacePercent, $freeSpaceGb, $totalSpaceGb, $Percent_Alert)

    if ($freeSpacePercent -le $Percent_Alert) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("Low disk space detected on {0}. Free space is {1}%." -f $DriveLetter, $freeSpacePercent)
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("Disk space is above the alert threshold on {0}. Free space is {1}%." -f $DriveLetter, $freeSpacePercent)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Detection error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
