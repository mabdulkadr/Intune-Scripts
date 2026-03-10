<#
.SYNOPSIS
    Detect whether the Windows system drive reports an unhealthy volume state.

.DESCRIPTION
    This detection script checks the Windows system drive by reading the volume
    `HealthStatus` with `Get-Volume`.

    The device is compliant only when the system drive health status is
    `Healthy`. Any other state is treated as non-compliant so the paired
    remediation script can run.

    Exit codes:
    - Exit 0: Healthy
    - Exit 1: Needs repair or further checking

.RUN AS
    System

.EXAMPLE
    .\DiskRepair--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'DiskRepair--Detect.ps1'
$ScriptBaseName = 'DiskRepair--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}
$SystemDriveLetter = $SystemDrive.TrimEnd(':')

# Script-specific logging location.
$SolutionName = 'DiskRepair'
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
Write-Log -Message "Checking drive letter: $SystemDriveLetter"

try {
    # Read the current health state without running a repair action.
    $volume = Get-Volume -DriveLetter $SystemDriveLetter -ErrorAction Stop
    $healthStatus = [string]$volume.HealthStatus

    Write-Log -Message "Volume health status: $healthStatus"
    Write-Output $healthStatus

    if ($healthStatus -eq 'Healthy') {
        Write-Log -Message 'No disk issues were reported.' -Level 'OK'
        Write-Log -Message '=== Detection END (Exit 0) ==='
        Write-Host 'No issues'
        Exit 0
    }

    Write-Log -Message 'The volume does not report a healthy state.' -Level 'WARN'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    Write-Host 'Needs checking'
    Exit 1
}
catch {
    Write-Log -Message ("Detection error: {0}" -f $_.Exception.Message) -Level 'FAIL'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    Write-Host 'Needs checking'
    Exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
