<#
.SYNOPSIS
    Detect whether Microsoft Defender PUA protection is enabled.

.DESCRIPTION
    This detection script checks the Microsoft Defender preference:

        (Get-MpPreference).PUAProtection

    PUA protection helps Microsoft Defender detect or block potentially
    unwanted applications such as suspicious bundles, adware, and unwanted
    software installers.

    The original script reports compliance using the version marker `C1` and
    returns `0` only when PUA protection is enabled (`1`).

.RUN AS
    System

.EXAMPLE
    .\GetPUAProtection--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Version marker preserved from the original script output.
$version = 'C1'

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'GetPUAProtection--Detect.ps1'
$ScriptBaseName = 'GetPUAProtection--Detect'

# Detect the Windows system drive automatically instead of hard-coding C: for logging.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Script-specific logging location.
$SolutionName = 'GetPUAProtection'
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

$mpPreference = Get-MpPreference
Write-Log -Message ("PUAProtection: {0}" -f $mpPreference.PUAProtection)

if ($mpPreference.PUAProtection -eq 1) {
    Write-Log -Message 'Microsoft Defender PUA protection is enabled.' -Level 'OK'
    Write-Log -Message '=== Detection END (Exit 0) ==='
    Write-Output "$version COMPLIANT"
    exit 0
}
else {
    Write-Log -Message 'Microsoft Defender PUA protection is not enabled.' -Level 'WARN'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    Write-Output "$version NON-COMPLIANT"
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
