<#
.SYNOPSIS
    Detect whether the SMBv1 server protocol is disabled.

.DESCRIPTION
    This detection script reads the SMB server configuration and checks the
    current value of `EnableSMB1Protocol`.

    The device is compliant only when SMBv1 is already disabled. If SMBv1 is
    still enabled, the script returns a non-compliant result so the paired
    remediation script can run.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant

.RUN AS
    System

.EXAMPLE
    .\DisableSMBv1--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DisableSMBv1--Detect.ps1'
$ScriptBaseName = 'DisableSMBv1--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Script-specific logging location.
$SolutionName = 'DisableSMBv1'
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

# Read the current SMB server setting exactly as defined in the original script.
$smbv1 = Get-SmbServerConfiguration | Select-Object -ExpandProperty EnableSMB1Protocol

if ($smbv1 -eq $false) {
    Write-Log -Message 'SMBv1 is disabled.' -Level 'OK'
    Write-Log -Message '=== Detection END (Exit 0) ==='
    Write-Host 'SMBv1 is disabled'
    exit 0
}
else {
    Write-Log -Message 'SMBv1 is enabled.' -Level 'WARN'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    Write-Host 'SMBv1 is enabled'
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
