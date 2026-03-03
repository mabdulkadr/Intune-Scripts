<#
.SYNOPSIS
    Detects when a restart notification should be shown to the user.

.DESCRIPTION
    This detection script marks the device as non-compliant when either a
    Windows update reboot is already pending or the device uptime has reached
    the configured threshold. It is intended for use with Intune Remediations
    running in the logged-on user context.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Non-compliant or detection failed

.RUN AS
    User

.EXAMPLE
    .\WinUptimeRestartNotification--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'WinUptimeRestartNotification--Detect.ps1'
$ScriptBaseName = 'WinUptimeRestartNotification--Detect'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive   = if ($env:SystemDrive) { $env:SystemDrive } else { 'C:' }
$LogFolderName = 'WindowsUptimeRestartNotification'
$LogDirectory  = Join-Path $SystemDrive "Intune\$LogFolderName"
$LogFilePath   = Join-Path $LogDirectory "$ScriptBaseName.txt"

# Keep this value aligned with the remediation script.
$MaxUptimeDays = 14
#endregion ====================== CONFIGURATION =========================

#region ======================= HELPER FUNCTIONS =======================
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL')]
        [string]$Level = 'INFO'
    )

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogLine   = "[$Timestamp] [$Level] $Message"

    Add-Content -Path $LogFilePath -Value $LogLine -Encoding UTF8
    Write-Output $LogLine
}

function Get-PendingRebootInfo {
    # Detect restart requirements raised by Windows update servicing.
    $UpdateReasons = New-Object System.Collections.Generic.List[string]

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $UpdateReasons.Add('Windows Update')
    }

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $UpdateReasons.Add('CBS')
    }

    $UniqueReasons = @($UpdateReasons | Select-Object -Unique)
    $HasPendingReboot = $UniqueReasons.Count -gt 0

    return [PSCustomObject]@{
        Pending       = $HasPendingReboot
        UpdateReasons = $UniqueReasons
    }
}

function Get-UptimeDays {
    # Calculate full days since last boot using CIM for speed and reliability.
    try {
        $OperatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $BootTime = $OperatingSystem.LastBootUpTime
        $Uptime = (Get-Date) - $BootTime
        return [Math]::Floor($Uptime.TotalDays)
    }
    catch {
        # Avoid false positives if CIM fails.
        Write-Log -Message "Failed to read uptime. Treating as compliant. Error: $($_.Exception.Message)" -Level 'WARN'
        return $null
    }
}
#endregion ==================== HELPER FUNCTIONS =======================

#region ===================== FIRST DETECTION BLOCK =====================
try {
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    Write-Log -Message '=== Detection START ==='
    Write-Log -Message "Script: $ScriptName"
    Write-Log -Message "Log file: $LogFilePath"
    Write-Log -Message "Maximum uptime threshold (days): $MaxUptimeDays"

    # Gather both signals once, then make a deterministic compliance decision.
    $PendingInfo = Get-PendingRebootInfo
    $UptimeDays  = Get-UptimeDays

    Write-Log -Message "Pending reboot detected: $($PendingInfo.Pending)"
    if ($PendingInfo.UpdateReasons.Count -gt 0) {
        Write-Log -Message "Pending reboot reasons: $($PendingInfo.UpdateReasons -join ', ')"
    }

    if ($null -ne $UptimeDays) {
        Write-Log -Message "Current uptime (days): $UptimeDays"
    } else {
        Write-Log -Message 'Current uptime could not be determined.'
    }

    # Priority 1: if updates already require restart, mark non-compliant immediately.
    if ($PendingInfo.Pending) {
        Write-Log -Message 'A restart is already pending due to Windows servicing.' -Level 'WARN'
        Write-Output 'Non-Compliant'
        Write-Log -Message '=== Detection END (Exit 1) ==='
        exit 1
    }

    # Priority 2: uptime threshold breach.
    if (($null -ne $UptimeDays) -and ($UptimeDays -ge $MaxUptimeDays)) {
        Write-Log -Message "Device uptime is $UptimeDays day(s), which meets or exceeds the threshold." -Level 'WARN'
        Write-Output 'Non-Compliant'
        Write-Log -Message '=== Detection END (Exit 1) ==='
        exit 1
    }

    # If uptime cannot be read, stay compliant to avoid false positives.
    if ($null -eq $UptimeDays) {
        Write-Log -Message 'No pending reboot was detected and uptime is unavailable. Treating as compliant.' -Level 'OK'
        Write-Output 'Compliant'
        Write-Log -Message '=== Detection END (Exit 0) ==='
        exit 0
    }

    # Final compliant state.
    Write-Log -Message "No pending reboot was detected and uptime is within threshold ($UptimeDays day(s))." -Level 'OK'
    Write-Output 'Compliant'
    Write-Log -Message '=== Detection END (Exit 0) ==='
    exit 0
}
catch {
    Write-Log -Message "Detection error: $($_.Exception.Message)" -Level 'FAIL'
    Write-Output 'Non-Compliant'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
