<#
.SYNOPSIS
    Detect whether a BitLocker recovery password is available for drive C.

.DESCRIPTION
    This detection script reads the BitLocker key protectors for mount point `C`
    and checks whether a recovery password is available.

    The original behavior is preserved:
    - If a recovery password is found, the script returns `0`
    - If no recovery password is found, or the lookup fails, the script returns `1`

.RUN AS
    System

.EXAMPLE
    .\GetBitlockerRecoveryKey--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'GetBitlockerRecoveryKey--Detect.ps1'
$ScriptBaseName = 'GetBitlockerRecoveryKey--Detect'

# Detect the Windows system drive automatically instead of hard-coding C: for logs.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# The original script explicitly checks BitLocker on drive C.
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

#region ===================== FIRST DETECTION BLOCK =====================
Start-LogRun
Write-Log -Message '=== Detection START ==='
Write-Log -Message "Script: $ScriptName"
Write-Log -Message "Log file: $LogFile"
Write-Log -Message "BitLocker mount point: $MountPoint"

Try {
    $Result = (Get-BitLockerVolume -MountPoint $MountPoint).KeyProtector
    $Recoverykey = $Result.RecoveryPassword

    if ($Recoverykey -ne $null) {
        Write-Log -Message 'BitLocker recovery key is available.' -Level 'OK'
        Write-Log -Message '=== Detection END (Exit 0) ==='
        Write-Output "Bitlocker recovery key available $Recoverykey "
        exit 0
    }
    else {
        Write-Log -Message 'No BitLocker recovery key was found.' -Level 'WARN'
        Write-Log -Message '=== Detection END (Exit 1) ==='
        Write-Output 'No bitlocker recovery key available starting remediation'
        exit 1
    }
}
catch {
    Write-Log -Message ("Detection error: {0}" -f $_.Exception.Message) -Level 'WARN'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    Write-Warning 'Value Missing'
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
