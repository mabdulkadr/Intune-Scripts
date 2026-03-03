<#
.SYNOPSIS
    Detects whether the Windows Update service is installed and running.

.DESCRIPTION
    This detection script checks for the Windows Update service and verifies that
    its current status is Running. It is intended for use with Intune Remediations.

    Exit codes:
    - Exit 0: Compliant
    - Exit 1: Not compliant or detection failed

.RUN AS
    System

.EXAMPLE
    .\RestartWindowsUpdateService---Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'RestartWindowsUpdateService---Detect.ps1'
$ScriptBaseName = 'RestartWindowsUpdateService---Detect'

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

#region ===================== FIRST DETECTION BLOCK =====================
try {
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    Write-Log -Message '=== Detection START ==='
    Write-Log -Message "Script: $ScriptName"
    Write-Log -Message "Log file: $LogFilePath"
    Write-Log -Message "Service name: $ServiceName"

    # Retrieve the service once, then evaluate both existence and status.
    $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if ($null -eq $Service) {
        Write-Log -Message "Service '$ServiceName' was not found." -Level 'FAIL'
        Write-Log -Message '=== Detection END (Exit 1) ==='
        exit 1
    }

    Write-Log -Message "Service '$ServiceName' current status: $($Service.Status)"

    if ($Service.Status -eq 'Running') {
        Write-Log -Message "Service '$ServiceName' is installed and running. System is compliant." -Level 'OK'
        Write-Log -Message '=== Detection END (Exit 0) ==='
        exit 0
    }

    Write-Log -Message "Service '$ServiceName' exists but is not running. Remediation is required." -Level 'WARN'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    exit 1
}
catch {
    Write-Log -Message "Detection error: $($_.Exception.Message)" -Level 'FAIL'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
