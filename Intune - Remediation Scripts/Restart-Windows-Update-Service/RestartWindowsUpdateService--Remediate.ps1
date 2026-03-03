<#
.SYNOPSIS
    Restarts the Windows Update service.

.DESCRIPTION
    This remediation script checks for the Windows Update service and restarts it
    when available. It is intended for use with Intune Remediations.

    Exit codes:
    - Exit 0: Completed successfully
    - Exit 1: Remediation failed or service was not found

.RUN AS
    System

.EXAMPLE
    .\RestartWindowsUpdateService--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'RestartWindowsUpdateService--Remediate.ps1'
$ScriptBaseName = 'RestartWindowsUpdateService--Remediate'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive   = if ($env:SystemDrive) { $env:SystemDrive } else { 'C:' }
$LogFolderName = 'Restart-Windows-Update-Service'
$LogDirectory  = Join-Path $SystemDrive "Intune\$LogFolderName"
$LogFilePath   = Join-Path $LogDirectory "$ScriptBaseName.txt"

# Target the Windows Update service by its service name.
$ServiceName = 'wuauserv'
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
#endregion ==================== HELPER FUNCTIONS =======================

#region ==================== FIRST REMEDIATION BLOCK ====================
try {
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    Write-Log -Message '=== Remediation START ==='
    Write-Log -Message "Script: $ScriptName"
    Write-Log -Message "Log file: $LogFilePath"
    Write-Log -Message "Service name: $ServiceName"

    # Confirm that the service exists before attempting a restart.
    $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $Service) {
        Write-Log -Message "Service '$ServiceName' was not found." -Level 'FAIL'
        Write-Log -Message '=== Remediation END (Exit 1) ==='
        exit 1
    }

    Write-Log -Message "Service '$ServiceName' current status before restart: $($Service.Status)"

    # Restart the service to restore normal operation.
    Restart-Service -Name $ServiceName -Force -ErrorAction Stop

    # Confirm the service state after the restart command completes.
    $Service = Get-Service -Name $ServiceName -ErrorAction Stop
    Write-Log -Message "Service '$ServiceName' current status after restart: $($Service.Status)"

    if ($Service.Status -eq 'Running') {
        Write-Log -Message "Service '$ServiceName' restarted successfully." -Level 'OK'
        Write-Log -Message '=== Remediation END (Exit 0) ==='
        exit 0
    }

    Write-Log -Message "Service '$ServiceName' restart command completed but the service is not running." -Level 'FAIL'
    Write-Log -Message '=== Remediation END (Exit 1) ==='
    exit 1
}
catch {
    Write-Log -Message "Remediation error: $($_.Exception.Message)" -Level 'FAIL'
    Write-Log -Message '=== Remediation END (Exit 1) ==='
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================
