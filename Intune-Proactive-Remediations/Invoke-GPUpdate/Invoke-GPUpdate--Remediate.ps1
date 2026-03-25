<#
.SYNOPSIS
    Forces a Group Policy refresh.

.DESCRIPTION
    This remediation script runs `gpupdate /force` and returns success or
    failure based on the command result.

.RUN AS
    System or User (according to assignment settings and script requirements)

.EXAMPLE
    .\Invoke-GPUpdate--Remediate.ps1

.NOTES
    Script  : Invoke-GPUpdate--Remediate.ps1
    Updated : 2026-02-15
#>

#region ---------- Configuration ----------

$ScriptName   = 'Invoke-GPUpdate--Remediate.ps1'
$SolutionName = 'Invoke-GPUpdate'
$ScriptMode   = 'Remediation'
$CommandName  = 'gpupdate'
$Arguments    = '/force'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Invoke-GPUpdate--Remediate.txt'
$BannerLine  = '=' * 78

#endregion ---------- Configuration ----------

#region ---------- Functions ----------

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
        Write-Host "Logging initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Write-Banner {
    $title = "{0} | {1}" -f $SolutionName, $ScriptMode
    $lines = @('', $BannerLine, $title, $BannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        }
        else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady) {
            Add-Content -Path $LogFile -Value $line -Encoding UTF8
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

    $line = '{0} | {1,-7} | {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    switch ($Level) {
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'WARNING' { Write-Host $line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        default   { Write-Host $line -ForegroundColor Cyan }
    }

    if ($script:LogReady) {
        try {
            Add-Content -Path $LogFile -Value $line -Encoding UTF8
        }
        catch {}
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

        [string]$OutputMessage
    )

    Write-Log -Message $Message -Level $Level

    if ($OutputMessage) {
        Write-Output $OutputMessage
    }

    exit $ExitCode
}

#endregion ---------- Functions ----------

#region ---------- Main ----------

$script:LogReady = Initialize-Log
Write-Banner

if ($script:LogReady) {
    Write-Log -Message ("Log file ready: {0}" -f $LogFile)
}

Write-Log -Message ("Running command: {0} {1}" -f $CommandName, $Arguments)

try {
    & $CommandName $Arguments | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -Message 'Group Policy update forced successfully.' -OutputMessage 'Success: Group Policy update forced.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -Message ("gpupdate returned exit code {0}." -f $LASTEXITCODE) -OutputMessage 'Error: Failed to force Group Policy update.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -Message ("Failed to force Group Policy update: {0}" -f $_.Exception.Message) -OutputMessage 'Error: Failed to force Group Policy update.'
}

#endregion ---------- Main ----------
