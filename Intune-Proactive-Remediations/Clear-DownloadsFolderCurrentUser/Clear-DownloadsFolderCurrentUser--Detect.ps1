<#
.SYNOPSIS
    Checks whether the current user's Downloads folder contains any items.

.DESCRIPTION
    This detection script enumerates the Downloads folder content under the
    current user profile.

    If one or more files or folders are present, it returns a non-zero result
    so the paired remediation script can clear the folder.

    Exit codes:
    - Exit 0: The target Downloads folder is already empty
    - Exit 1: One or more items are still present in the target Downloads folder

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Clear-DownloadsFolderCurrentUser--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Clear-DownloadsFolderCurrentUser--Detect.ps1'
$SolutionName = 'Clear-DownloadsFolderCurrentUser'
$ScriptMode   = 'Detection'

$DownloadsPath = Join-Path $env:USERPROFILE 'Downloads'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Clear-DownloadsFolderCurrentUser--Detect.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

function Initialize-Log {
    if (-not (Test-Path -Path $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
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

    Write-Log -Message $Message -Level $Level
    Write-Output $Message
    exit $ExitCode
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner
    Write-Log -Message ("Checking current user Downloads folder: {0}" -f $DownloadsPath)

    if (-not (Test-Path -Path $DownloadsPath)) {
        Finish-Script -Message 'Compliant: Downloads folder was not found.' -ExitCode 0 -Level 'SUCCESS'
    }

    $content = @(Get-ChildItem -Path $DownloadsPath -Force -ErrorAction SilentlyContinue)
    if (@($content).Count -eq 0) {
        Finish-Script -Message 'Compliant: Downloads folder is already empty.' -ExitCode 0 -Level 'SUCCESS'
    }

    Finish-Script -Message ("Non-Compliant: Found {0} item(s) in the current user Downloads folder." -f @($content).Count) -ExitCode 1 -Level 'WARNING'
}
catch {
    Finish-Script -Message ("Detection failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
