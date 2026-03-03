<#
.SYNOPSIS
    Repairs the device secure channel to the domain when needed.

.DESCRIPTION
    This remediation script checks whether the device is domain-joined and then
    attempts to repair the computer secure channel directly. It is intended for
    use with Intune Remediations.

    Exit codes:
    - Exit 0: Completed successfully or not applicable
    - Exit 1: Repair failed or an error occurred

.RUN AS
    System

.EXAMPLE
    .\SecureChannel--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'SecureChannel--Remediate.ps1'
$ScriptBaseName = 'SecureChannel--Remediate'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive   = if ($env:SystemDrive) { $env:SystemDrive } else { 'C:' }
$LogFolderName = 'Repaire-SecureChannel'
$LogDirectory  = Join-Path $SystemDrive "Intune\$LogFolderName"
$LogFilePath   = Join-Path $LogDirectory "$ScriptBaseName.txt"

# Keep reboot optional after a successful repair.
$ForceRebootAfterRepair = $false
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

    # Skip repair on devices that are not joined to a domain.
    $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    if (-not $ComputerSystem.PartOfDomain) {
        Write-Log -Message 'Device is not domain-joined. Secure channel repair is not applicable.' -Level 'OK'
        Write-Log -Message '=== Remediation END (Exit 0) ==='
        exit 0
    }

    $DomainName = $ComputerSystem.Domain
    Write-Log -Message "Domain: $DomainName"
    Write-Log -Message 'Device is domain-joined. Attempting secure channel repair now.' -Level 'WARN'

    # Attempt the built-in secure channel repair.
    $null = Test-ComputerSecureChannel -Repair -Verbose:$false -ErrorAction Stop
    Write-Log -Message 'Secure channel repair command completed successfully.' -Level 'OK'

    if ($ForceRebootAfterRepair) {
        Write-Log -Message 'A reboot was requested. Scheduling restart in 5 minutes.'
        shutdown.exe /r /t 300 /c "Secure channel repaired by Intune remediation"
    }

    Write-Log -Message '=== Remediation END (Exit 0) ==='
    exit 0
}
catch {
    Write-Log -Message "Remediation error: $($_.Exception.Message)" -Level 'FAIL'
    Write-Log -Message '=== Remediation END (Exit 1) ==='
    exit 1
}
#endregion ================= FIRST REMEDIATION BLOCK =================
