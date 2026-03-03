<#
.SYNOPSIS
    Remediate Intune Management Extension sync by triggering it immediately and scheduling recurring sync.

.DESCRIPTION
    This remediation script:
    1. Triggers Intune Management Extension sync immediately.
    2. Creates or updates a scheduled task that triggers the same sync every hour.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Failed or requires further action

.RUN AS
    System or User, based on the Intune assignment configuration.

.EXAMPLE
    .\IntuneIMESync--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'IntuneIMESync--Remediate.ps1'
$ScriptBaseName = 'IntuneIMESync--Remediate'

# Detect the Windows system drive automatically instead of hard-coding C:.
$SystemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
else {
    $env:SystemDrive.TrimEnd('\')
}

# Intune sync URI and scheduled task settings.
$ImeSyncUri         = 'intunemanagementextension://syncapp'
$TaskName           = 'Trigger-IME-Sync-Hourly'
$TaskDescription    = 'Scheduled task to trigger Intune Management Extension Sync every hour.'
$TaskExecute        = 'PowerShell.exe'
$TaskArgument       = "-NoProfile -WindowStyle Hidden -Command `"(New-Object -ComObject Shell.Application).Open('$ImeSyncUri')`""
$TriggerDelayMins   = 1
$RepeatHours        = 1
#endregion ====================== CONFIGURATION ======================

#region ======================= PATHS AND LOGGING =======================
# Central log folder used by this remediation package.
$SolutionName = "IntuneSyncTrigger"
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

# Trigger an Intune Management Extension sync using the IME URI handler.
function Trigger-IMESync {
    try {
        Write-Log -Level "INFO" -Message "Triggering Intune Management Extension sync."
        $Shell = New-Object -ComObject Shell.Application
        $Shell.Open($ImeSyncUri)
        Write-Log -Level "OK" -Message "Intune Management Extension sync triggered successfully."
    }
    catch {
        throw ("Failed to trigger IME sync: {0}" -f $_.Exception.Message)
    }
}

# Create or update a scheduled task that triggers IME sync every hour.
function Create-IMESyncScheduledTask {
    try {
        Write-Log -Level "INFO" -Message "Creating or updating the scheduled task for hourly IME sync."

        $Action = New-ScheduledTaskAction -Execute $TaskExecute -Argument $TaskArgument
        $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes($TriggerDelayMins) -RepetitionInterval (New-TimeSpan -Hours $RepeatHours)

        Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Action $Action -Trigger $Trigger -User "SYSTEM" -RunLevel Highest -Force | Out-Null
        Write-Log -Level "OK" -Message ("Scheduled task '{0}' created or updated successfully." -f $TaskName)
    }
    catch {
        throw ("Failed to create scheduled task: {0}" -f $_.Exception.Message)
    }
}
#endregion ==================== HELPER FUNCTIONS ====================

#region ==================== FIRST REMEDIATION BLOCK ====================
Write-Log -Level "INFO" -Message "=== Remediation START ==="
Write-Log -Level "INFO" -Message ("Script: {0}" -f $ScriptName)
Write-Log -Level "INFO" -Message ("Log file: {0}" -f $LogFile)
Write-Log -Level "INFO" -Message ("Task name: {0}" -f $TaskName)
Write-Log -Level "INFO" -Message ("IME sync URI: {0}" -f $ImeSyncUri)

try {
    # Trigger an immediate sync first.
    Trigger-IMESync

    # Then ensure the recurring hourly task is present.
    Create-IMESyncScheduledTask

    Write-Output "Remediation process completed successfully."
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 0) ==="
    exit 0
}
catch {
    Write-Log -Level "FAIL" -Message $_.Exception.Message
    Write-Output ("Remediation failed: {0}" -f $_.Exception.Message)
    Write-Log -Level "INFO" -Message "=== Remediation END (Exit 1) ==="
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================
