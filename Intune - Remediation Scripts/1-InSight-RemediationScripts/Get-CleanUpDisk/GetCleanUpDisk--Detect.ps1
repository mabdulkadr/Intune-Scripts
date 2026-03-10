<#
.SYNOPSIS
    Detect whether the system drive has more than the required free space threshold.

.DESCRIPTION
    This detection script checks the available free space on drive `C` and
    compares it with a fixed threshold of `15 GB`.

    The original logic is preserved:
    - If free space is greater than 15 GB, the script exits `0`
    - Otherwise, the script exits `1` so disk cleanup remediation can run

.RUN AS
    System

.EXAMPLE
    .\GetCleanUpDisk--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Minimum required free space on the Windows system drive (in GB).
$storageThreshold = 15

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'GetCleanUpDisk--Detect.ps1'
$ScriptBaseName = 'GetCleanUpDisk--Detect'

# Detect the Windows system drive automatically instead of hard-coding C: for logging.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# The original script explicitly checks drive C.
$TargetDrive = 'C'

# Script-specific logging location.
$SolutionName = 'GetCleanUpDisk'
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

# Convert raw byte values into a human-readable string for logging.
function Format-Size {
    param([long]$Bytes)

    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
    return ("{0} B" -f $Bytes)
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
Write-Log -Message "Target drive: $TargetDrive"

$utilization = (Get-PSDrive | Where-Object { $_.Name -eq $TargetDrive }).Free
Write-Log -Message ("Free space: {0}" -f (Format-Size ([int64]$utilization)))
Write-Log -Message ("Threshold: {0} GB" -f $storageThreshold)

if (($storageThreshold * 1GB) -lt $utilization) {
    Write-Log -Message 'Free space is above the threshold.' -Level 'OK'
    Write-Log -Message '=== Detection END (Exit 0) ==='
    exit 0
}
else {
    Write-Log -Message 'Free space is below the threshold.' -Level 'WARN'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
