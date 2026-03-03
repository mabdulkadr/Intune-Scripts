<#
.SYNOPSIS
    Detects whether the device secure channel to the domain is healthy.

.DESCRIPTION
    This detection script verifies whether the device is domain-joined and whether
    the computer secure channel is working correctly. It is intended for use with
    Intune Remediations.

    Exit codes:
    - Exit 0: Compliant or not applicable
    - Exit 1: Not compliant or detection failed

.RUN AS
    System

.EXAMPLE
    .\SecureChannel--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'SecureChannel--Detect.ps1'
$ScriptBaseName = 'SecureChannel--Detect'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive   = if ($env:SystemDrive) { $env:SystemDrive } else { 'C:' }
$LogFolderName = 'Repaire-SecureChannel'
$LogDirectory  = Join-Path $SystemDrive "Intune\$LogFolderName"
$LogFilePath   = Join-Path $LogDirectory "$ScriptBaseName.txt"
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

    # Skip remediation on devices that are not joined to a domain.
    $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    if (-not $ComputerSystem.PartOfDomain) {
        Write-Log -Message 'Device is not domain-joined. Secure channel check is not applicable.' -Level 'OK'
        Write-Log -Message '=== Detection END (Exit 0) ==='
        exit 0
    }

    Write-Log -Message "Domain: $($ComputerSystem.Domain)"
    Write-Log -Message 'Device is domain-joined. Testing the computer secure channel.'

    # Test-ComputerSecureChannel returns True when the trust with the domain is healthy.
    $SecureChannelHealthy = Test-ComputerSecureChannel -ErrorAction Stop

    if ($SecureChannelHealthy) {
        Write-Log -Message 'Secure channel is healthy. System is compliant.' -Level 'OK'
        Write-Log -Message '=== Detection END (Exit 0) ==='
        exit 0
    }

    Write-Log -Message 'Secure channel is broken. Remediation is required.' -Level 'WARN'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    exit 1
}
catch {
    Write-Log -Message "Detection error: $($_.Exception.Message)" -Level 'FAIL'
    Write-Log -Message '=== Detection END (Exit 1) ==='
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
