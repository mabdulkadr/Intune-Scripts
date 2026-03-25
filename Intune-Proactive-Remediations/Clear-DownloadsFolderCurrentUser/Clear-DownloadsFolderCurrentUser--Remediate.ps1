<#
.SYNOPSIS
    Removes all child items from the current user's Downloads folder.

.DESCRIPTION
    This remediation script clears the current user's Downloads folder
    recursively by deleting all child content under `$env:USERPROFILE\Downloads`.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Clear-DownloadsFolderCurrentUser--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Clear-DownloadsFolderCurrentUser--Remediate.ps1'
$SolutionName = 'Clear-DownloadsFolderCurrentUser'
$ScriptMode   = 'Remediation'

$DownloadsPath = Join-Path $env:USERPROFILE 'Downloads'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Clear-DownloadsFolderCurrentUser--Remediate.txt'
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
    Write-Log -Message ("Clearing current user Downloads folder: {0}" -f $DownloadsPath)

    if (-not (Test-Path -Path $DownloadsPath)) {
        Finish-Script -Message 'Downloads folder was not found. Nothing to remediate.' -ExitCode 0 -Level 'SUCCESS'
    }

    $content = @(Get-ChildItem -Path $DownloadsPath -Force -ErrorAction SilentlyContinue)
    if (@($content).Count -eq 0) {
        Finish-Script -Message 'Downloads folder is already empty. Nothing to remediate.' -ExitCode 0 -Level 'SUCCESS'
    }

    Remove-Item -Path (Join-Path $DownloadsPath '*') -Recurse -Force -ErrorAction Stop
    Finish-Script -Message ("Removed {0} item(s) from the current user Downloads folder." -f @($content).Count) -ExitCode 0 -Level 'SUCCESS'
}
catch {
    Finish-Script -Message ("Remediation failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
