<#
.SYNOPSIS
    Report the BitLocker recovery password when the drive is fully encrypted.

.DESCRIPTION
    This remediation script checks the BitLocker status of the device and
    reports the recovery password for drive `C` when encryption is at `100%`.

    The original behavior is preserved exactly:
    - If encryption is `100`, it outputs the recovery key and exits `0`
    - Otherwise it reports that this is only for reporting and exits `1`

    Note: this script reports data but does not create or rotate a recovery key.

.RUN AS
    System

.EXAMPLE
    .\GetBitlockerRecoveryKey--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'GetBitlockerRecoveryKey--Remediate.ps1'
$ScriptBaseName = 'GetBitlockerRecoveryKey--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C: for logs.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# The original script explicitly reports BitLocker data for drive C.
$MountPoint = 'C'

# Script-specific logging location.
$SolutionName = 'GetBitlockerRecoveryKey'
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ====================== CONFIGURATION ======================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and log file exist before writing entries.
function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

# Add a visual separator so each run is easier to scan in the same log file.
function Start-LogRun {
    Initialize-LogFile

    if (Test-Path -LiteralPath $LogFile) {
        $existingLog = Get-Item -LiteralPath $LogFile -ErrorAction SilentlyContinue
        if ($existingLog -and $existingLog.Length -gt 0) {
            Add-Content -Path $LogFile -Value '' -Encoding UTF8
        }
    }

    Add-Content -Path $LogFile -Value ('=' * 78) -Encoding UTF8
}

# Write a colorized console message and persist it to the log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

    switch ($Level) {
        'OK' { Write-Host $line -ForegroundColor Green }
        'WARN' { Write-Host $line -ForegroundColor Yellow }
        'FAIL' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ==================== FIRST REMEDIATION BLOCK ====================
Start-LogRun
Write-Log -Message '=== Remediation START ==='
Write-Log -Message "Script: $ScriptName"
Write-Log -Message "Log file: $LogFile"
Write-Log -Message "BitLocker mount point: $MountPoint"

Try {
    $BLinfo = Get-BitLockerVolume
    if ($BLinfo.EncryptionPercentage -eq '100') {
        $Result = (Get-BitLockerVolume -MountPoint $MountPoint).KeyProtector
        $Recoverykey = $Result.RecoveryPassword
        Write-Log -Message 'Drive reports 100% encryption and a recovery key was queried.' -Level 'OK'
        Write-Log -Message '=== Remediation END (Exit 0) ==='
        Write-Output "Bitlocker recovery key $Recoverykey"
        Exit 0
    }
    else {
        Write-Log -Message 'Drive is not fully encrypted, so no recovery key is reported.' -Level 'WARN'
        Write-Log -Message '=== Remediation END (Exit 1) ==='
        Write-Output 'This is only for reporting, no key aviable'
        Exit 1
    }
}
catch {
    Write-Log -Message ("Remediation error: {0}" -f $_.Exception.Message) -Level 'WARN'
    Write-Log -Message '=== Remediation END (Exit 1) ==='
    Write-Warning 'Value Missing'
    Exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================
