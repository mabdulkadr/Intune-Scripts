<#
.SYNOPSIS
    Detects whether Windows is waiting for a restart.

.DESCRIPTION
    This detection script checks common pending reboot indicators in the
    registry, writes the result to `C:\Intune\RestartStatus.txt`, and returns
    a non-zero result when a restart is required.

    Exit codes:
    - Exit 0: No restart required
    - Exit 1: Restart required

.RUN AS
    System or User (according to assignment settings and script requirements).

.EXAMPLE
    .\Restart-ComputerForced--Detect.ps1

.NOTES
    Script  : Restart-ComputerForced--Detect.ps1
    Updated : 2026-02-15
#>

#region ---------- Configuration ----------

$ScriptName   = 'Restart-ComputerForced--Detect.ps1'
$SolutionName = 'Restart-ComputerForced'
$ScriptMode   = 'Detection'

$StatusRoot = 'C:\Intune'
$StatusFile = Join-Path $StatusRoot 'RestartStatus.txt'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Restart-ComputerForced--Detect.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

function Initialize-Log {
    if (-not (Test-Path -Path $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    if (-not (Test-Path -Path $StatusRoot)) {
        New-Item -Path $StatusRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
}

function Write-Banner {
    Write-Host ''
    Write-Host $BannerLine -ForegroundColor DarkGray
    Write-Host ("{0} | {1}" -f $SolutionName, $ScriptMode) -ForegroundColor White
    Write-Host $BannerLine -ForegroundColor DarkGray
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '{0} | {1,-7} | {2}' -f $timestamp, $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'WARNING' { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        default   { Write-Host $line -ForegroundColor Cyan }
    }

    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    Set-Content -Path $StatusFile -Value $Message -Encoding UTF8
    Write-Log -Message $Message -Level $Level
    Write-Output $Message
    exit $ExitCode
}

function Test-PendingRestart {
    $rebootRequiredWU = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    $componentBasedServicing = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    $pendingFileRenameOperations = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue).PendingFileRenameOperations

    $computerName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -ErrorAction SilentlyContinue).ComputerName
    $activeComputerName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -ErrorAction SilentlyContinue).ComputerName
    $pendingComputerRename = $computerName -and $activeComputerName -and ($computerName -ne $activeComputerName)

    return ($rebootRequiredWU -or $componentBasedServicing -or $pendingFileRenameOperations -or $pendingComputerRename)
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner

    if (Test-PendingRestart) {
        Finish-Script -Message 'Restart required' -ExitCode 1 -Level 'WARNING'
    }

    Finish-Script -Message 'No restart required' -ExitCode 0 -Level 'SUCCESS'
}
catch {
    Finish-Script -Message ("Detection failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
