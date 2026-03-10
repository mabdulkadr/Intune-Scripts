<#
.SYNOPSIS
    Detect whether the Microsoft Configuration Manager (SCCM) client is installed.

.DESCRIPTION
    This detection script checks for the local `ccmsetup.exe` installer path used
    by the Microsoft Configuration Manager client.

    If the SCCM client files are present, the device is treated as non-compliant
    so the paired remediation script can run and uninstall the client.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\UninstallSCCM--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Path used to verify whether the SCCM client is installed.
$ccmSetupPath = "$env:windir\ccmsetup\ccmsetup.exe"

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'UninstallSCCM--Detect.ps1'
$ScriptBaseName = 'UninstallSCCM--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Script-specific logging location shared by the Detect and Remediate scripts.
$SolutionName = 'UninstallSCCM'
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ====================== CONFIGURATION ======================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory exists before writing entries.
function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }
}

function Start-LogRun {
    # Add a visual separator so each run is easier to scan in the same log file.
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

    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message

    switch ($Level) {
        'OK'   { Write-Host $line -ForegroundColor Green }
        'WARN' { Write-Host $line -ForegroundColor Yellow }
        'FAIL' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ===================== FIRST DETECTION BLOCK =====================
Start-LogRun
Write-Log -Level 'INFO' -Message '=== Detection START ==='
Write-Log -Level 'INFO' -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level 'INFO' -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level 'INFO' -Message ("SCCM setup path: {0}" -f $ccmSetupPath)

# Check if the SCCM client setup binary exists.
if (Test-Path -LiteralPath $ccmSetupPath) {
    Write-Output 'SCCM client is installed.'
    Write-Log -Level 'WARN' -Message 'SCCM client is installed. Remediation is required.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
    exit 1
}
else {
    Write-Output 'SCCM client is NOT installed.'
    Write-Log -Level 'OK' -Message 'SCCM client is not installed. System is compliant.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 0) ==='
    exit 0
}
#endregion ================== FIRST DETECTION BLOCK ==================
