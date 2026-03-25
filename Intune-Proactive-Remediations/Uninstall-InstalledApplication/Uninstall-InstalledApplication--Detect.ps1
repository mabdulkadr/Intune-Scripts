<#
.SYNOPSIS
    Checks whether any blacklisted applications are installed on the device.

.DESCRIPTION
    This detection script searches the standard 64-bit and 32-bit uninstall
    registry locations under `HKLM` and compares discovered display names to a
    configurable blacklist array.

    Exit codes:
    - Exit 0: No blacklisted applications were detected
    - Exit 1: One or more blacklisted applications were detected

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Uninstall-InstalledApplication--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Uninstall-InstalledApplication--Detect.ps1'
$SolutionName = 'Uninstall-InstalledApplication'
$ScriptMode   = 'Detection'

$BlacklistApps = @(
    'APP 1'
    'APP 2'
)

$UninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Uninstall-InstalledApplication--Detect.txt'
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

function Get-InstalledBlacklistedApps {
    return @(
        Get-ItemProperty -Path $UninstallPaths -ErrorAction SilentlyContinue |
        ForEach-Object {
            $name = if ($_.DisplayName) { [string]$_.DisplayName } else { [string]$_.DisplayName_Localized }
            if (-not $name -or $BlacklistApps -notcontains $name) { return }

            [pscustomobject]@{
                Name            = $name
                UninstallString = [string]$_.UninstallString
                RegistryPath    = $_.PSPath
            }
        }
    )
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner
    Write-Log -Message 'Searching uninstall registry locations for blacklisted applications.'

    $matches = Get-InstalledBlacklistedApps
    if (@($matches).Count -eq 0) {
        Finish-Script -Message 'Compliant: No blacklisted applications were detected.' -ExitCode 0 -Level 'SUCCESS'
    }

    $names = ($matches | Select-Object -ExpandProperty Name -Unique) -join ', '
    Finish-Script -Message ("Non-Compliant: Found {0} blacklisted application(s): {1}" -f @($matches).Count, $names) -ExitCode 1 -Level 'WARNING'
}
catch {
    Finish-Script -Message ("Detection failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
