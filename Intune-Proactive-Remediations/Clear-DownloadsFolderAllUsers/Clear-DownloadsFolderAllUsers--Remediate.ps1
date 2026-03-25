<#
.SYNOPSIS
    Deletes content under every user's Downloads folder.

.DESCRIPTION
    This remediation script enumerates local user profiles under `C:\Users`,
    locates each `Downloads` folder, and removes all child content recursively.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Clear-DownloadsFolderAllUsers--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Clear-DownloadsFolderAllUsers--Remediate.ps1'
$SolutionName = 'Clear-DownloadsFolderAllUsers'
$ScriptMode   = 'Remediation'

$UserProfilesRoot = 'C:\Users'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Clear-DownloadsFolderAllUsers--Remediate.txt'
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
    Write-Log -Message ("Scanning user profiles under: {0}" -f $UserProfilesRoot)

    $downloadsFolders = Get-ChildItem -Path $UserProfilesRoot -Directory -ErrorAction Stop |
        ForEach-Object {
            $downloadsPath = Join-Path $_.FullName 'Downloads'
            if (Test-Path -Path $downloadsPath) {
                $downloadsPath
            }
        }

    $processedCount = 0

    foreach ($downloadsFolder in $downloadsFolders) {
        $items = @(Get-ChildItem -Path $downloadsFolder -Force -ErrorAction SilentlyContinue)
        if (@($items).Count -eq 0) {
            continue
        }

        Write-Log -Message ("Clearing Downloads folder: {0}" -f $downloadsFolder)
        Remove-Item -Path (Join-Path $downloadsFolder '*') -Recurse -Force -ErrorAction Stop
        $processedCount++
    }

    Finish-Script -Message ("Downloads cleanup completed for {0} user folder(s)." -f $processedCount) -ExitCode 0 -Level 'SUCCESS'
}
catch {
    Finish-Script -Message ("Remediation failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
