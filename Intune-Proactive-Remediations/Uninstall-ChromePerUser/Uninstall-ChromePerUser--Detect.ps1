<#
.SYNOPSIS
    Checks whether Google Chrome is registered as a per-user installed application.

.DESCRIPTION
    This detection script reads uninstall entries under the current user's
    registry hive and searches for `Google Chrome`.

    It normalizes the application name from `DisplayName` or
    `DisplayName_Localized` and returns a non-zero result when a per-user
    Chrome installation is found.

    Exit codes:
    - Exit 0: Per-user Chrome not detected
    - Exit 1: Per-user Chrome detected

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Uninstall-ChromePerUser--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Uninstall-ChromePerUser--Detect.ps1'
$SolutionName = 'Uninstall-ChromePerUser'
$ScriptMode   = 'Detection'

$UninstallRegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
$BlacklistApps    = @('Google Chrome')

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Uninstall-ChromePerUser--Detect.txt'
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

function Get-PerUserChromeEntries {
    if (-not (Test-Path -Path $UninstallRegPath)) {
        return @()
    }

    return @(
        Get-ChildItem -Path $UninstallRegPath -ErrorAction Stop |
        ForEach-Object {
            $entry = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
            if (-not $entry) { return }

            $name = if ($entry.DisplayName) { [string]$entry.DisplayName } else { [string]$entry.DisplayName_Localized }
            if (-not $name) { return }

            if ($BlacklistApps -contains $name) {
                [pscustomobject]@{
                    Name            = $name
                    UninstallString = [string]$entry.UninstallString
                    RegistryPath    = $_.PSPath
                }
            }
        }
    )
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner
    Write-Log -Message ("Checking user uninstall entries under: {0}" -f $UninstallRegPath)

    $matches = Get-PerUserChromeEntries

    if (@($matches).Count -eq 0) {
        Finish-Script -Message 'Compliant: Per-user Google Chrome was not detected.' -ExitCode 0 -Level 'SUCCESS'
    }

    Finish-Script -Message ("Non-Compliant: Found {0} per-user Google Chrome uninstall entry(ies)." -f @($matches).Count) -ExitCode 1 -Level 'WARNING'
}
catch {
    Finish-Script -Message ("Detection failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
