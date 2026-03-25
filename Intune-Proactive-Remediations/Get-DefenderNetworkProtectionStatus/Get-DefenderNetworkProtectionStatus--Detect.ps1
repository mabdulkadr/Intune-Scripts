<#
.SYNOPSIS
    Checks whether Microsoft Defender Network Protection is enabled.

.DESCRIPTION
    This detection script reads Microsoft Defender preferences by using
    `Get-MpPreference` and checks whether `EnableNetworkProtection` is set to
    `1`.

    Exit codes:
    - Exit 0: Network Protection is enabled
    - Exit 1: Network Protection is not enabled or the query failed

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Get-DefenderNetworkProtectionStatus--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName     = 'Get-DefenderNetworkProtectionStatus--Detect.ps1'
$SolutionName   = 'Get-DefenderNetworkProtectionStatus'
$ScriptMode     = 'Detection'
$ExpectedValue  = 1
$Version        = 'C1'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Get-DefenderNetworkProtectionStatus--Detect.txt'
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

Write-Log -Message 'Reading Microsoft Defender preferences.'

try {
    $preferences = Get-MpPreference -ErrorAction Stop
    Write-Log -Message ("Current EnableNetworkProtection value: {0}" -f $preferences.EnableNetworkProtection)

    if ($preferences.EnableNetworkProtection -eq $ExpectedValue) {
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -OutputMessage "$Version COMPLIANT" -Message 'Defender Network Protection is enabled.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -OutputMessage "$Version NON-COMPLIANT" -Message 'Defender Network Protection is not enabled.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -OutputMessage "$Version NON-COMPLIANT" -Message ("Failed to read Defender preferences: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
