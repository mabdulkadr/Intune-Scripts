<#
.SYNOPSIS
    Checks whether the OS volume exposes a BitLocker recovery password.

.DESCRIPTION
    This detection script queries BitLocker on `C:`, inspects the
    `KeyProtector` collection, and looks for a populated `RecoveryPassword`
    value.

    Exit codes:
    - Exit 0: Recovery password found
    - Exit 1: Recovery password missing or query failed

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Get-BitLockerRecoveryKeyInfo--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Get-BitLockerRecoveryKeyInfo--Detect.ps1'
$SolutionName = 'Get-BitLockerRecoveryKeyInfo'
$ScriptMode   = 'Detection'
$MountPoint   = 'C:'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Get-BitLockerRecoveryKeyInfo--Detect.txt'
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

function Get-RecoveryPassword {
    param([string]$VolumeMountPoint)

    $volume = Get-BitLockerVolume -MountPoint $VolumeMountPoint -ErrorAction Stop
    $recoveryPasswords = @($volume.KeyProtector | Where-Object { $_.RecoveryPassword } | Select-Object -ExpandProperty RecoveryPassword)
    return $recoveryPasswords
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

    if ($ComplianceState) {
        Write-Output $ComplianceState
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

Write-Log -Message ("Querying BitLocker recovery password on mount point: {0}" -f $MountPoint)

try {
    $recoveryPasswords = @(Get-RecoveryPassword -VolumeMountPoint $MountPoint)

    if ($recoveryPasswords.Count -gt 0) {
        $maskedPassword = $recoveryPasswords[0]
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -ComplianceState ("Recovery key available: {0}" -f $maskedPassword) -Message 'BitLocker recovery password is available on the OS volume.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -ComplianceState 'No recovery key available' -Message 'No BitLocker recovery password was found on the OS volume.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -ComplianceState 'No recovery key available' -Message ("Failed to query BitLocker recovery password: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
