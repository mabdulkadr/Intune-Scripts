<#
.SYNOPSIS
    Removes stale local user profiles older than the configured age threshold.

.DESCRIPTION
    This remediation script enumerates Win32_UserProfile using CIM and removes
    local user profiles whose LastUseTime is older than the configured number of days.

    The script excludes:
    - Special/system profiles
    - Currently loaded profiles
    - Profiles without a valid local path
    - Profiles without LastUseTime
    - Default/Public profile folders

    Exit codes:
    - Exit 0: Remediation completed successfully (profiles removed or none found)
    - Exit 1: Remediation failed

.RUN AS
    System

.EXAMPLE
    .\Clear-StaleUserProfiles--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region -- BOOTSTRAP -----------------------------------------------------------

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#endregion -- BOOTSTRAP --------------------------------------------------------

#region -- CONFIGURATION -------------------------------------------------------

$ScriptName      = 'Clear-StaleUserProfiles--Remediate.ps1'
$SolutionName    = 'Clear-StaleUserProfiles'
$ScriptMode      = 'Remediation'
$StaleAfterDays  = 30
$CutoffDate      = (Get-Date).AddDays(-$StaleAfterDays)

$SystemDrive = if ($env:SystemDrive) {
    $env:SystemDrive.TrimEnd('\')
}
elseif ($env:SystemRoot) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    'C:'
}

$LogRoot    = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile    = Join-Path $LogRoot 'Clear-StaleUserProfiles--Remediate.txt'
$BannerLine = '=' * 78

#endregion -- CONFIGURATION ----------------------------------------------------

#region -- FUNCTIONS -----------------------------------------------------------

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
        Write-Host ("Logging initialization failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

function Write-Banner {
    $Title = '{0} | {1}' -f $SolutionName, $ScriptMode
    $Lines = @(
        ''
        $BannerLine
        $Title
        $BannerLine
    )

    foreach ($Line in $Lines) {
        if ($Line -eq $Title) {
            Write-Host $Line -ForegroundColor White
        }
        else {
            Write-Host $Line -ForegroundColor DarkGray
        }

        if ($script:LogReady) {
            try {
                Add-Content -Path $LogFile -Value $Line -Encoding UTF8
            }
            catch {}
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

    $Line = '{0} | {1,-7} | {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        'WARNING' { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        default   { Write-Host $Line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        }
        catch {}
    }
}

function Get-StaleProfiles {
    $Profiles = @(Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop)

    $FilteredProfiles = @(
        $Profiles | Where-Object {
            $_.Special -eq $false -and
            $_.Loaded -eq $false -and
            -not [string]::IsNullOrWhiteSpace($_.LocalPath) -and
            -not [string]::IsNullOrWhiteSpace($_.SID) -and
            $null -ne $_.LastUseTime -and
            $_.LastUseTime -lt $CutoffDate -and
            $_.LocalPath -notmatch '\\Users\\(Default|Default User|Public|All Users|defaultuser0)$'
        }
    )

    return @($FilteredProfiles)
}

function Remove-StaleProfile {
    param(
        [Parameter(Mandatory = $true)]
        $Profile
    )

    try {
        $Path = $Profile.LocalPath
        $SID  = $Profile.SID

        Write-Log -Level 'INFO' -Message ("Removing profile: {0} | SID: {1}" -f $Path, $SID)

        # Remove via CIM (recommended)
        Remove-CimInstance -InputObject $Profile -ErrorAction Stop

        Write-Log -Level 'SUCCESS' -Message ("Successfully removed profile: {0}" -f $Path)
        return $true
    }
    catch {
        Write-Log -Level 'ERROR' -Message ("Failed to remove profile {0}: {1}" -f $Profile.LocalPath, $_.Exception.Message)
        return $false
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

#endregion -- FUNCTIONS --------------------------------------------------------

#region -- MAIN ----------------------------------------------------------------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Starting remediation. Removing profiles older than {0} days (Cutoff: {1})" -f $StaleAfterDays, ($CutoffDate.ToString('yyyy-MM-dd HH:mm:ss')))

try {
    $StaleProfiles = @(Get-StaleProfiles)
    $Total         = $StaleProfiles.Count
    $Removed       = 0
    $Failed        = 0

    if ($Total -eq 0) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'No stale user profiles found. Nothing to remediate.'
    }

    Write-Log -Level 'WARNING' -Message ("Stale profiles detected: {0}. Starting cleanup..." -f $Total)

    foreach ($Profile in $StaleProfiles) {
        $Result = Remove-StaleProfile -Profile $Profile

        if ($Result) {
            $Removed++
        }
        else {
            $Failed++
        }
    }

    Write-Log -Level 'INFO' -Message ("Summary | Total: {0} | Removed: {1} | Failed: {2}" -f $Total, $Removed, $Failed)

    if ($Failed -gt 0) {
        Finish-Script -ExitCode 1 -Level 'ERROR' -Message 'Remediation completed with errors.'
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Remediation completed successfully.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Remediation failed: {0}" -f $_.Exception.Message)
}

#endregion -- MAIN -------------------------------------------------------------