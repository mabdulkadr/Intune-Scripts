<#!
.SYNOPSIS
    Detect restart requirement for Intune Proactive Remediations.

.DESCRIPTION
    This detection script marks a device as Not Compliant when a restart notice should be shown.
    Detection conditions are evaluated in this order:
    1) Pending reboot required by Windows update servicing
    2) Device uptime is greater than or equal to the configured threshold

    Exit codes:
    - Exit 1: Not Compliant (remediation should run)
    - Exit 0: Compliant

.RUN AS
    User (Intune Proactive Remediations: Run script using logged-on credentials = Yes)

.EXAMPLE
    .\Detect_WindowsUptimeRestartNotification.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2026-02-12
    Version : 1.2
#>

#region ============================ SETTINGS ===================================
# Keep this value aligned with the remediation script.
$MaxUptimeDays = 10
#endregion =====================================================================

#region ============================ HELPERS ====================================
function Get-PendingRebootInfo {
    # Detect restart requirements raised by Windows update components.
    $updateReasons = New-Object System.Collections.Generic.List[string]

    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $updateReasons.Add("Windows Update")
    }
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $updateReasons.Add("CBS")
    }

    $u = $updateReasons | Select-Object -Unique
    $hasUpdates = ($u -and $u.Count -gt 0)

    return [pscustomobject]@{
        Pending       = $hasUpdates
        HasUpdates    = $hasUpdates
        UpdateReasons = $u
    }
}

function Get-UptimeDays {
    # Calculate full days since last boot using CIM for speed and reliability.
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $boot = $os.LastBootUpTime
        $span = (Get-Date) - $boot
        return [Math]::Floor($span.TotalDays)
    }
    catch {
        # Avoid false positives if WMI/CIM fails
        Write-Output "WARN: Failed to read uptime. Treating as compliant. Error: $($_.Exception.Message)"
        return $null
    }
}
#endregion =====================================================================

#region ============================ DECISION ===================================
# Gather both signals once, then make a deterministic compliance decision.
$PendingInfo = Get-PendingRebootInfo
$UptimeDays = Get-UptimeDays

# Priority 1: if updates already require restart, mark non-compliant immediately.
if ($PendingInfo.Pending) {
    $detail = ""
    if ($PendingInfo.UpdateReasons -and $PendingInfo.UpdateReasons.Count -gt 0) {
        $detail = " Reasons=" + ($PendingInfo.UpdateReasons -join ",")
    }
    Write-Output "NOT COMPLIANT: Pending reboot required for updates.$detail"
    exit 1
}

# Priority 2: uptime threshold breach.
if (($null -ne $UptimeDays) -and ($UptimeDays -ge $MaxUptimeDays)) {
    Write-Output "NOT COMPLIANT: Device has not rebooted for $UptimeDays day(s). Threshold=$MaxUptimeDays."
    exit 1
}

# If uptime cannot be read, stay compliant to avoid false positives.
if ($null -eq $UptimeDays) {
    Write-Output "COMPLIANT: No pending update reboot detected. Uptime unavailable."
    exit 0
}

# Final compliant state.
Write-Output "COMPLIANT: No pending update reboot detected. Uptime=$UptimeDays day(s). Threshold=$MaxUptimeDays."
exit 0
#endregion =====================================================================
