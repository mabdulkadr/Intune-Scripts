<#
.SYNOPSIS
    Removes the MicrosoftTeams AppX package from the device.

.DESCRIPTION
    This remediation script gets the AppX package named `MicrosoftTeams`
    across all users and attempts to remove each discovered package by using
    `Remove-AppxPackage`.

    It targets the Store/AppX form of Teams only.

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Uninstall-MicrosoftTeamsPersonal--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Uninstall-MicrosoftTeamsPersonal--Remediate.ps1'
$SolutionName = 'Uninstall-MicrosoftTeamsPersonal'
$ScriptMode   = 'Remediation'

$TargetPackageName = 'MicrosoftTeams'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Uninstall-MicrosoftTeamsPersonal--Remediate.txt'
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

function Remove-TeamsPersonalPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageFullName
    )

    $hasAllUsers = (Get-Command Remove-AppxPackage -ErrorAction Stop).Parameters.ContainsKey('AllUsers')
    if ($hasAllUsers) {
        Remove-AppxPackage -Package $PackageFullName -AllUsers -ErrorAction Stop
        return
    }

    Remove-AppxPackage -Package $PackageFullName -ErrorAction Stop
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

try {
    Initialize-Log
    Write-Banner
    Write-Log -Message ("Checking AppX package: {0}" -f $TargetPackageName)

    $packages = Get-TeamsPersonalPackages
    if (@($packages).Count -eq 0) {
        Finish-Script -Message 'MicrosoftTeams AppX package was not found. Nothing to remediate.' -ExitCode 0 -Level 'SUCCESS'
    }

    $failureCount = 0

    foreach ($package in $packages) {
        Write-Log -Message ("Removing AppX package: {0}" -f $package.PackageFullName)

        try {
            Remove-TeamsPersonalPackage -PackageFullName $package.PackageFullName
            Write-Log -Message ("Removed AppX package: {0}" -f $package.PackageFullName) -Level 'SUCCESS'
        }
        catch {
            $failureCount++
            Write-Log -Message ("Failed to remove AppX package '{0}': {1}" -f $package.PackageFullName, $_.Exception.Message) -Level 'ERROR'
        }
    }

    if ($failureCount -gt 0) {
        Finish-Script -Message ("Remediation completed with {0} failure(s)." -f $failureCount) -ExitCode 1 -Level 'WARNING'
    }

    Finish-Script -Message ("Remediation completed successfully for {0} MicrosoftTeams AppX package instance(s)." -f @($packages).Count) -ExitCode 0 -Level 'SUCCESS'
}
catch {
    Finish-Script -Message ("Remediation failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
