<#
.SYNOPSIS
    Detect whether the Windows system drive has enough free space for the CleanUpDisk remediation baseline.

.DESCRIPTION
    This detection script checks the available free space on the Windows system
    drive against a configured threshold in gigabytes.

    The script is intended for Microsoft Intune Proactive Remediations. When the
    device is below the required free-space threshold, the script returns a
    non-compliant result so the remediation script can run.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant (remediation should run)

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\CleanUpDisk--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Minimum required free space on the Windows system drive (in GB).
$storageThreshold = 15

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'CleanUpDisk--Detect.ps1'
$ScriptBaseName = 'CleanUpDisk--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}
$SystemDriveLetter = $SystemDrive.TrimEnd(':')
$SystemDriveLabel  = "{0}:" -f $SystemDriveLetter

# Script-specific logging location.
$SolutionName = "CleanUpDisk"
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ("{0}.txt" -f $ScriptBaseName)
#endregion ====================== CONFIGURATION ======================

#region ======================= HELPER FUNCTIONS =======================
# Ensure the log directory and log file exist before writing entries.
function Initialize-Logging {
    try {
        if (-not (Test-Path $BasePath)) {
            New-Item -Path $BasePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        if (-not (Test-Path $LogFile)) {
            New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        return $true
    }
    catch {
        return $false
    }
}

$LogReady = Initialize-Logging

# Convert raw byte values into a human-readable string for logging.
function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
    return ("{0} B" -f $Bytes)
}

# Write a colorized console message and persist it to the log file when available.
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

try {
    $drive = Get-PSDrive -Name $SystemDriveLetter -ErrorAction Stop
    $freeBytes     = [int64]$drive.Free
    $usedBytes     = [int64]$drive.Used
    $totalBytes    = $freeBytes + $usedBytes
    $thresholdBytes = $storageThreshold * 1GB

    Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
    Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)
    Write-Log -Level "INFO" -Message ("{0} Free: {1} | Used: {2} | Total: {3}" -f $SystemDriveLabel, (Format-Size $freeBytes), (Format-Size $usedBytes), (Format-Size $totalBytes))
    Write-Log -Level "INFO" -Message ("Threshold: {0} GB (device must have more than this free)" -f $storageThreshold)

    # Compliant only when free space is strictly greater than the configured threshold.
    if ($thresholdBytes -lt $freeBytes) {
        Write-Log -Level "OK" -Message "Compliant: free space above threshold."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 0) ==="
        exit 0
    }
    else {
        Write-Log -Level "WARN" -Message "Non-compliant: free space below threshold."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
        exit 1
    }
}
catch {
    Write-Log -Level "FAIL" -Message ("Detection error: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
