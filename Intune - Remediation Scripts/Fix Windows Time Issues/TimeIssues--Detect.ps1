<#
.SYNOPSIS
    Detect whether core Windows time settings are configured correctly.

.DESCRIPTION
    This detection script verifies three time-related requirements:
    1. The Windows Time service is running.
    2. Automatic time synchronization is configured.
    3. Automatic time zone detection is enabled.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not Compliant (remediation should run)
    - Exit 2: Detection error

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\TimeIssues--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'TimeIssues--Detect.ps1'
$ScriptBaseName = 'TimeIssues--Detect'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Service and registry settings used for time-related compliance checks.
$TimeServiceName      = 'w32time'
$TimeZoneRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
$TimeZoneValueName    = 'Start'
$ExpectedTimeZoneMode = 3
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Fix Windows Time Issues"
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
Write-Log -Level "INFO" -Message ("Time service: {0}" -f $TimeServiceName)

try {
    # Check that the Windows Time service is present and currently running.
    Write-Log -Level "INFO" -Message "Checking Windows Time service status."
    $TimeService = Get-Service -Name $TimeServiceName -ErrorAction SilentlyContinue
    if ($null -eq $TimeService) {
        Write-Log -Level "WARN" -Message "NonCompliant: Windows Time service was not found."
        Write-Output "NonCompliant: Windows Time service was not found."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
        exit 1
    }

    Write-Log -Level "INFO" -Message ("Windows Time service state: {0}" -f $TimeService.Status)
    if ($TimeService.Status -ne 'Running') {
        Write-Log -Level "WARN" -Message "NonCompliant: Windows Time service is not running."
        Write-Output "NonCompliant: Windows Time service is not running."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
        exit 1
    }

    # Check whether automatic time synchronization is configured.
    Write-Log -Level "INFO" -Message "Checking automatic time synchronization settings."
    $TimeConfig = w32tm /query /configuration | Select-String "NtpClient"
    if (-not $TimeConfig) {
        Write-Log -Level "WARN" -Message "NonCompliant: Automatic time synchronization is not configured."
        Write-Output "NonCompliant: Automatic time synchronization is not configured."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
        exit 1
    }

    # Check whether automatic time zone detection is enabled.
    Write-Log -Level "INFO" -Message "Checking automatic time zone detection settings."
    $CurrentValue = Get-ItemProperty -Path $TimeZoneRegistryPath -Name $TimeZoneValueName -ErrorAction SilentlyContinue
    if ($null -eq $CurrentValue -or $CurrentValue.$TimeZoneValueName -ne $ExpectedTimeZoneMode) {
        Write-Log -Level "WARN" -Message "NonCompliant: Automatic time zone detection is not enabled."
        Write-Output "NonCompliant: Automatic time zone detection is not enabled."
        Write-Log -Level "INFO" -Message "=== Detection END (Exit 1) ==="
        exit 1
    }

    Write-Log -Level "OK" -Message "Compliant: All time-related settings are correctly configured."
    Write-Output "Compliant: All time-related settings are correctly configured."
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 0) ==="
    exit 0
}
catch {
    Write-Log -Level "FAIL" -Message ("Detection error: {0}" -f $_.Exception.Message)
    Write-Output ("Error during detection: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Detection END (Exit 2) ==="
    exit 2
}
#endregion ================== FIRST DETECTION BLOCK ==================
