<#
.SYNOPSIS
    Detects stale user profiles older than the configured age threshold.

.DESCRIPTION
    This detection script enumerates Win32_UserProfile using CIM and identifies
    local user profiles whose LastUseTime is older than the configured number of days.

    The script excludes:
    - Special/system profiles
    - Currently loaded profiles
    - Profiles without a valid local path
    - Profiles without LastUseTime

    Exit codes:
    - Exit 0: No stale user profiles found
    - Exit 1: One or more stale user profiles found or detection failed

.RUN AS
    System

.EXAMPLE
    .\Clear-StaleUserProfiles--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.3
#>

#region -- BOOTSTRAP -----------------------------------------------------------

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#endregion -- BOOTSTRAP --------------------------------------------------------

#region -- CONFIGURATION -------------------------------------------------------

$ScriptName      = 'Clear-StaleUserProfiles--Detect.ps1'
$SolutionName    = 'Clear-StaleUserProfiles'
$ScriptMode      = 'Detection'
$StaleAfterDays  = 30
$CutoffDate      = (Get-Date).AddDays(-$StaleAfterDays)

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Clear-StaleUserProfiles--Detect.txt'
$BannerLine  = '=' * 78

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
    $Title = "{0} | {1}" -f $SolutionName, $ScriptMode
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
            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
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
    $Profiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop

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

function Write-ProfileDetails {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Profiles
    )

    foreach ($Profile in $Profiles) {
        $LastUse = if ($Profile.LastUseTime) {
            try { (Get-Date $Profile.LastUseTime -Format 'yyyy-MM-dd HH:mm:ss') } catch { 'Unknown' }
        }
        else {
            'Unknown'
        }

        Write-Log -Level 'WARNING' -Message (
            "Stale profile detected | UserPath: {0} | SID: {1} | LastUseTime: {2}" -f `
            $Profile.LocalPath, $Profile.SID, $LastUse
        )
    }
}

function Finish-Script {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO',

        [string]$ComplianceState
    )

    Write-Log -Message $Message -Level $Level

    if (-not [string]::IsNullOrWhiteSpace($ComplianceState)) {
        Write-Output $ComplianceState
    }

    exit $ExitCode
}

#endregion -- FUNCTIONS --------------------------------------------------------

#region -- MAIN ----------------------------------------------------------------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Checking for stale user profiles older than {0} days. Cutoff date: {1}" -f $StaleAfterDays, ($CutoffDate.ToString('yyyy-MM-dd HH:mm:ss')))

try {
    $StaleProfiles = @(Get-StaleProfiles)
    $StaleProfileCount = @($StaleProfiles).Count

    if ($StaleProfileCount -gt 0) {
        Write-Log -Message ("Total stale profiles found: {0}" -f $StaleProfileCount) -Level 'WARNING'
        Write-ProfileDetails -Profiles $StaleProfiles

        Finish-Script -ExitCode 1 -Level 'WARNING' -ComplianceState 'Not Compliant' -Message 'One or more stale user profiles were found. Remediation is required.'
    }

    Finish-Script -ExitCode 0 -Level 'SUCCESS' -ComplianceState 'Compliant' -Message 'No stale user profiles were found.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -ComplianceState 'Not Compliant' -Message ("Failed to enumerate user profiles: {0}" -f $_.Exception.Message)
}

#endregion -- MAIN -------------------------------------------------------------