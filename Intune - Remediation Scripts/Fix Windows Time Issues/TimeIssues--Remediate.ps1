<#
.SYNOPSIS
    Remediate common Windows time configuration issues.

.DESCRIPTION
    This remediation script:
    1. Ensures the Windows Time service is running and set to Automatic.
    2. Configures time synchronization and triggers a resync.
    3. Enables automatic time zone detection.
    4. Starts the Location Service when available.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\TimeIssues--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'TimeIssues--Remediate.ps1'
$ScriptBaseName = 'TimeIssues--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Service, registry, and NTP settings used for remediation.
$TimeServiceName      = 'w32time'
$LocationServiceName  = 'lfsvc'
$TimeZoneRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
$TimeZoneValueName    = 'Start'
$ExpectedTimeZoneMode = 3
$TimeServer           = 'time.windows.com'
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "Fix Windows Time Issues"
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName

# Remediation-specific log file.
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

#region ==================== FIRST REMEDIATION BLOCK ====================
Write-Log -Level "INFO" -Message "=== Remediation START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level "INFO" -Message ("Time service: {0}" -f $TimeServiceName)
Write-Log -Level "INFO" -Message ("Time server: {0}" -f $TimeServer)

try {
    # Ensure the Windows Time service exists and is running.
    Write-Log -Level "INFO" -Message "Ensuring Windows Time service is running."
    $TimeService = Get-Service -Name $TimeServiceName -ErrorAction SilentlyContinue
    if ($null -eq $TimeService) {
        Write-Log -Level "FAIL" -Message "Windows Time service was not found."
        Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
        exit 1
    }

    if ($TimeService.Status -ne 'Running') {
        Start-Service -Name $TimeServiceName -ErrorAction Stop
        Write-Log -Level "OK" -Message "Windows Time service started successfully."
    }
    else {
        Write-Log -Level "OK" -Message "Windows Time service is already running."
    }

    # Set the Windows Time service to start automatically.
    Set-Service -Name $TimeServiceName -StartupType Automatic -ErrorAction Stop
    Write-Log -Level "OK" -Message "Windows Time service startup type set to Automatic."

    # Configure time synchronization and force an immediate resync.
    Write-Log -Level "INFO" -Message "Configuring automatic time synchronization."
    w32tm /config /manualpeerlist:$TimeServer /syncfromflags:manual /reliable:yes /update | Out-Null
    Write-Log -Level "OK" -Message ("Time synchronization configured to use {0}." -f $TimeServer)

    w32tm /resync | Out-Null
    Write-Log -Level "OK" -Message "Time synchronized successfully."

    # Enable automatic time zone detection if it is not already enabled.
    Write-Log -Level "INFO" -Message "Enabling automatic time zone detection."
    $CurrentValue = Get-ItemProperty -Path $TimeZoneRegistryPath -Name $TimeZoneValueName -ErrorAction SilentlyContinue
    if ($null -eq $CurrentValue -or $CurrentValue.$TimeZoneValueName -ne $ExpectedTimeZoneMode) {
        Set-ItemProperty -Path $TimeZoneRegistryPath -Name $TimeZoneValueName -Value $ExpectedTimeZoneMode -ErrorAction Stop
        Write-Log -Level "OK" -Message "Automatic time zone detection enabled."
    }
    else {
        Write-Log -Level "OK" -Message "Automatic time zone detection is already enabled."
    }

    # Start the Location Service when available because it supports automatic time zone updates.
    Write-Log -Level "INFO" -Message "Checking Location Service status."
    $LocationService = Get-Service -Name $LocationServiceName -ErrorAction SilentlyContinue
    if ($null -eq $LocationService) {
        Write-Log -Level "WARN" -Message "Location Service was not found. Skipping service start."
    }
    elseif ($LocationService.Status -ne 'Running') {
        Start-Service -Name $LocationServiceName -ErrorAction Stop
        Write-Log -Level "OK" -Message "Location Service started successfully."
    }
    else {
        Write-Log -Level "OK" -Message "Location Service is already running."
    }

    Write-Log -Level "OK" -Message "All time-related issues have been fixed."
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 0) ==="
    exit 0
}
catch {
    Write-Log -Level "FAIL" -Message ("Error during remediation: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================
