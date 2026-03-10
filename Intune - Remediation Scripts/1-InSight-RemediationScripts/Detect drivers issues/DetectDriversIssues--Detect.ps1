<#
.SYNOPSIS
    Detect disabled or missing device drivers that require user notification.

.DESCRIPTION
    This detection script scans `Win32_PNPEntity` for devices with
    `ConfigManagerErrorCode` values that indicate driver problems.

    It only treats the following states as non-compliant:
    - `22` : Device is disabled
    - `28` : Driver is not installed

    When one or more affected devices are found, the script logs the device
    names and hardware IDs, then returns `Exit 1` so the paired remediation
    script can notify the user.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\DetectDriversIssues--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DetectDriversIssues--Detect.ps1'
$ScriptBaseName = 'DetectDriversIssues--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Script-specific logging location shared by the Detect and Remediate scripts.
$SolutionName = 'DetectDriversIssues'
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

    Initialize-LogFile

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line      = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

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

try {
    # Query devices with any PnP configuration error, then keep only disabled or missing drivers.
    $driversTest = Get-WmiObject Win32_PNPEntity | Where-Object { $_.ConfigManagerErrorCode -gt 0 }
    $problemDrivers = @(
        $driversTest | Where-Object {
            ($_.ConfigManagerErrorCode -eq 22) -or
            ($_.ConfigManagerErrorCode -eq 28)
        }
    )

    if ($problemDrivers.Count -gt 0) {
        $missingDriversCount  = @($problemDrivers | Where-Object { $_.ConfigManagerErrorCode -eq 28 }).Count
        $disabledDriversCount = @($problemDrivers | Where-Object { $_.ConfigManagerErrorCode -eq 22 }).Count

        Write-Log -Level 'WARN' -Message ("Driver issues detected. Missing drivers: {0} | Disabled drivers: {1}" -f $missingDriversCount, $disabledDriversCount)

        foreach ($driver in $problemDrivers) {
            Write-Log -Level 'INFO' -Message ("Driver name: {0}" -f $driver.Caption)
            Write-Log -Level 'INFO' -Message ("Driver device ID: {0}" -f $driver.DeviceID)
            Add-Content -Path $LogFile -Value '' -Encoding UTF8
        }

        Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
        exit 1
    }

    Write-Log -Level 'OK' -Message 'No disabled or missing drivers were detected.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 0) ==='
    exit 0
}
catch {
    Write-Log -Level 'FAIL' -Message ("Detection error: {0}" -f $_.Exception.Message)
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
