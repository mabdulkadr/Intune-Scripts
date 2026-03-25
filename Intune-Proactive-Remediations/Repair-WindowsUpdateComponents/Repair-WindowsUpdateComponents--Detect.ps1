<#
.SYNOPSIS
    Detects whether the last installed Windows update is recent enough.

.DESCRIPTION
    This detection script checks the date of the most recent installed Windows
    update and marks the device as non-compliant when that update is older than
    the configured threshold.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Non-compliant or detection failed

.RUN AS
    System

.EXAMPLE
    .\Repair-WindowsUpdateComponents--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName          = 'Repair-WindowsUpdateComponents--Detect.ps1'
$SolutionName        = 'Repair-WindowsUpdateComponents'
$ScriptMode          = 'Detection'
$UpdateThresholdDays = 40

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Repair-WindowsUpdateComponents--Detect.txt'
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

function Get-LatestInstalledUpdateDate {
    $latestHotFix = Get-HotFix -ErrorAction Stop |
        Where-Object { $_.InstalledOn } |
        Sort-Object -Property InstalledOn |
        Select-Object -Last 1

    if ($null -eq $latestHotFix) {
        return $null
    }

    return [datetime]$latestHotFix.InstalledOn
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Update age threshold (days): {0}" -f $UpdateThresholdDays)

try {
    $lastUpdate = Get-LatestInstalledUpdateDate
    if ($null -eq $lastUpdate) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'No installed Windows updates with a valid InstalledOn date were found.'
    }

    Write-Log -Message ("Last installed update date: {0}" -f $lastUpdate.ToString('yyyy-MM-dd'))

    $daysSinceUpdate = (New-TimeSpan -Start $lastUpdate -End (Get-Date)).Days
    Write-Log -Message ("Days since last update: {0}" -f $daysSinceUpdate)

    if ($daysSinceUpdate -ge $UpdateThresholdDays) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("The last update was installed {0} days ago, which exceeds the threshold." -f $daysSinceUpdate)
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message ("Windows Update recency is compliant. Last update age is {0} day(s)." -f $daysSinceUpdate)
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Detection error: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
