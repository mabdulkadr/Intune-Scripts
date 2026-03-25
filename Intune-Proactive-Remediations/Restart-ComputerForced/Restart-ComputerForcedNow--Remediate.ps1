<#
.SYNOPSIS
    Forces an immediate restart without a warning delay.

.DESCRIPTION
    This remediation script issues an immediate forced restart and does not
    depend on the delayed warning workflow.

.RUN AS
    System or User (according to assignment settings and script requirements).

.EXAMPLE
    .\Restart-ComputerForcedNow--Remediate.ps1

.NOTES
    Script  : Restart-ComputerForcedNow--Remediate.ps1
    Updated : 2026-02-15
#>

#region ---------- Configuration ----------

$ScriptName   = 'Restart-ComputerForcedNow--Remediate.ps1'
$SolutionName = 'Restart-ComputerForced'
$ScriptMode   = 'Immediate Remediation'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Restart-ComputerForcedNow--Remediate.txt'
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
    Write-Log -Message 'Forcing system restart immediately.' -Level 'WARNING'
    Restart-Computer -Force -Confirm:$false
    Finish-Script -Message 'Immediate forced restart command issued successfully.' -ExitCode 0 -Level 'SUCCESS'
}
catch {
    Finish-Script -Message ("Remediation failed: {0}" -f $_.Exception.Message) -ExitCode 1 -Level 'ERROR'
}

#endregion ---------- Main ----------
