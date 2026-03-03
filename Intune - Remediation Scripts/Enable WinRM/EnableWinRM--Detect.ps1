<#
.SYNOPSIS
    Detect whether WinRM (PowerShell Remoting) is enabled.

.DESCRIPTION
    This detection script uses `Test-WSMan` to verify whether WinRM and
    PowerShell Remoting are available on the local device.

    If WinRM responds successfully, the device is treated as compliant.
    If the test fails, remediation should run.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant (remediation should run)

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\EnableWinRM--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'EnableWinRM--Detect.ps1'
$ScriptBaseName = 'EnableWinRM--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Enable WinRM"
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName

# Detection-specific log file.
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ==================== PATHS AND LOGGING ====================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and file exist before any write attempts.
function Initialize-Logging {
    try {
        if (-not (Test-Path -Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        if (-not (Test-Path -Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        return $true
    }
    catch {
        # If logging init fails, the script still continues with console output.
        return $false
    }
}

$LogReady = Initialize-Logging

# Write colored console output and persist the same line to the log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "OK", "WARN", "FAIL")]
        [string]$Level = "INFO"
    )

    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message

    switch ($Level) {
        "OK"   { Write-Host $line -ForegroundColor Green }
        "WARN" { Write-Host $line -ForegroundColor Yellow }
        "FAIL" { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    if ($LogReady) {
        try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch {}
    }
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ===================== FIRST DETECTION BLOCK =====================
Write-Log -Level "INFO" -Message "=== Detection START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)

try {
    # Test whether WinRM responds successfully on the local device.
    $TestResult = Test-WSMan -ErrorAction Stop

    if ($TestResult) {
        Write-Log -Level "OK" -Message "WinRM is enabled and responding."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 0) ==="
        exit 0
    }

    Write-Log -Level "WARN" -Message "WinRM test did not return a valid result."
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
    exit 1
}
catch {
    Write-Log -Level "WARN" -Message ("WinRM appears to be disabled or unavailable: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
