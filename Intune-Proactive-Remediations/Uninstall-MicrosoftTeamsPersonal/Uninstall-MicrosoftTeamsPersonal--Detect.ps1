<#
.SYNOPSIS
    Checks whether the MicrosoftTeams AppX package is still installed.

.DESCRIPTION
    This detection script uses `Get-AppxPackage -Name MicrosoftTeams -AllUsers`
    to determine whether the AppX package is still present on the device.

    Exit codes:
    - Exit 0: MicrosoftTeams AppX package not found
    - Exit 1: MicrosoftTeams AppX package found

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Uninstall-MicrosoftTeamsPersonal--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Uninstall-MicrosoftTeamsPersonal--Detect.ps1'
$SolutionName = 'Uninstall-MicrosoftTeamsPersonal'
$ScriptMode   = 'Detection'

$TargetPackageName = 'MicrosoftTeams'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Uninstall-MicrosoftTeamsPersonal--Detect.txt'
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

function Get-TeamsPersonalPackages {
    return @(Get-AppxPackage -Name $TargetPackageName -AllUsers -ErrorAction Stop)
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner
    Write-Log -Message ("Checking AppX package: {0}" -f $TargetPackageName)

    $packages = Get-TeamsPersonalPackages
    if (@($packages).Count -eq 0) {
        Finish-Script -Message 'Compliant: MicrosoftTeams AppX package was not found.' -ExitCode 0 -Level 'SUCCESS'
    }

    Finish-Script -Message ("Non-Compliant: Found {0} MicrosoftTeams AppX package instance(s)." -f @($packages).Count) -ExitCode 1 -Level 'WARNING'
}
catch {
    Finish-Script -Message ("Detection failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
