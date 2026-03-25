<#
.SYNOPSIS
    Re-queries BitLocker and reports the current recovery password when available.

.DESCRIPTION
    This remediation script does not create or rotate a BitLocker recovery
    protector. It only re-queries BitLocker and prints the current recovery
    password when the OS volume is fully encrypted.

    Exit codes:
    - Exit 0: Recovery password was reported successfully
    - Exit 1: Recovery password is unavailable or the query failed

.RUN AS
    System or User (depending on Intune assignment and script requirements)

.EXAMPLE
    .\Get-BitLockerRecoveryKeyInfo--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.2
#>

#region ---------- Configuration ----------

$ScriptName   = 'Get-BitLockerRecoveryKeyInfo--Remediate.ps1'
$SolutionName = 'Get-BitLockerRecoveryKeyInfo'
$ScriptMode   = 'Remediation'
$MountPoint   = 'C:'

$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$LogRoot     = Join-Path $SystemDrive "IntuneLogs\$SolutionName"
$LogFile     = Join-Path $LogRoot 'Get-BitLockerRecoveryKeyInfo--Remediate.txt'
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
    return [pscustomobject]@{
        EncryptionPercentage = $volume.EncryptionPercentage
        RecoveryPasswords    = @($volume.KeyProtector | Where-Object { $_.RecoveryPassword } | Select-Object -ExpandProperty RecoveryPassword)
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

Write-Log -Message ("Reporting BitLocker recovery password on mount point: {0}" -f $MountPoint)

try {
    $result = Get-RecoveryPassword -VolumeMountPoint $MountPoint
    Write-Log -Message ("Current encryption percentage: {0}" -f $result.EncryptionPercentage)

    if ($result.EncryptionPercentage -ne 100) {
        Finish-Script -ExitCode 1 -Level 'WARNING' -OutputMessage 'This script is only for reporting, no key available.' -Message 'The OS volume is not fully encrypted. Recovery password reporting was skipped.'
    }

    if ($result.RecoveryPasswords.Count -gt 0) {
        $recoveryPassword = $result.RecoveryPasswords[0]
        Finish-Script -ExitCode 0 -Level 'SUCCESS' -OutputMessage ("BitLocker recovery key {0}" -f $recoveryPassword) -Message 'BitLocker recovery password was reported successfully.'
    }

    Finish-Script -ExitCode 1 -Level 'WARNING' -OutputMessage 'This script is only for reporting, no key available.' -Message 'No BitLocker recovery password was found on the fully encrypted OS volume.'
}
catch {
    Finish-Script -ExitCode 1 -Level 'ERROR' -OutputMessage 'This script is only for reporting, no key available.' -Message ("Failed to query BitLocker recovery password: {0}" -f $_.Exception.Message)
}

#endregion ---------- Main ----------
