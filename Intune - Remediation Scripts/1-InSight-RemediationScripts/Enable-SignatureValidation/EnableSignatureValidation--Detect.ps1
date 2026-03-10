<#
.SYNOPSIS
    Detect whether the Wintrust configuration path used for signature validation exists.

.DESCRIPTION
    This detection script checks the Wintrust configuration registry paths used
    for the `EnableCertPaddingCheck` mitigation related to CVE-2013-3900.

    The original script loops through two registry paths and returns immediately
    during the first iteration:
    - If the current path exists, it returns `Compliant` and exits `0`
    - If the current path does not exist, it returns `Not Compliant` and exits `1`

    That behavior is preserved exactly.

.RUN AS
    System

.EXAMPLE
    .\EnableSignatureValidation--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'EnableSignatureValidation--Detect.ps1'
$ScriptBaseName = 'EnableSignatureValidation--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Registry paths used by the original script.
$Path = 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Cryptography\Wintrust\Config', 'Registry::HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config'

# Script-specific logging location.
$SolutionName = 'EnableSignatureValidation'
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

foreach ($i in $Path) {
    Write-Log -Message "Checking registry path: $i"

    if ((Test-Path $i)) {
        Write-Log -Message 'Signature validation registry path exists.' -Level 'OK'
        Write-Log -Message '=== Detection END (Exit 0) ==='
        Write-Output 'Compliant'
        Exit 0
    }

    Write-Log -Message 'Signature validation registry path does not exist.' -Level 'WARN'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    Write-Warning 'Not Compliant'
    Exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
