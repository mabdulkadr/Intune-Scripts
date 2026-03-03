<#
.SYNOPSIS
    Detects whether application updates are available using Windows Package Manager (winget).

.DESCRIPTION
    This detection script checks if any installed applications on the device
    have pending updates via Windows Package Manager (winget).

    The script dynamically locates AppInstallerCLI.exe inside the WindowsApps
    directory under Program Files. This method ensures compatibility when
    running in SYSTEM context (for example, via Microsoft Intune).

    It executes:
        winget upgrade

    The command output is evaluated to determine whether updates are available.

    Logic:
    - If no upgradeable applications are detected (minimal output returned),
      the device is considered Compliant and exits with code 0.
    - If one or more applications have available updates,
      the device is considered Not Compliant and exits with code 1.
    - If an error occurs during execution, the script defaults to
      Not Compliant (exit code 1).

.HINT
    This is a community script. There is no guarantee for this.
    Review and test thoroughly before deploying in production.

.RUN AS
    System

.EXAMPLE
    .\WingetUpdateAll--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ============================ CONFIGURATION ==============================
# Use fixed names so Intune staging does not change the log file name.
$SystemDrive    = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) { 'C:' } else { $env:SystemDrive }
$ScriptName     = 'WingetUpdateAll--Detect.ps1'
$ScriptBaseName = 'WingetUpdateAll--Detect'
$LogDirectory   = Join-Path -Path $SystemDrive -ChildPath 'Intune\Winget-Update-All'
$LogFile        = Join-Path -Path $LogDirectory -ChildPath "$ScriptBaseName.txt"
#endregion ====================================================================

#region ============================ HELPER FUNCTIONS ===========================
function Initialize-LogFile {
    # Create the log directory only when it is needed.
    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL')]
        [string]$Level = 'INFO'
    )

    Initialize-LogFile

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"

    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
#endregion ====================================================================

#region ========================= FIRST DETECTION BLOCK ========================
Write-Log '=== Detection START ==='
Write-Log "Script: $ScriptName"
Write-Log "Log file: $LogFile"

try {
    # Resolve Winget executable path from WindowsApps directory (SYSTEM-safe resolution).
    $Winget = Get-ChildItem -Path (
        Join-Path -Path (
            Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsApps'
        ) -ChildPath 'Microsoft.DesktopAppInstaller*_x64*\AppInstallerCLI.exe'
    )

    Write-Log "Winget path: $($Winget.FullName)"

    # Execute winget upgrade to list applications with available updates.
    $updatecheck = & $winget upgrade

    Write-Log "Raw result count: $($updatecheck.Count)"

    # Evaluate command output line count to determine compliance state.
    if ($updatecheck.Count -lt 3) {
        Write-Log 'No upgrades detected. Returning Exit 0.' 'OK'
        Write-Log '=== Detection END (Exit 0) ==='
        Write-Output 'Compliant'
        exit 0
    }

    Write-Log 'Upgrades detected. Returning Exit 1.' 'WARN'
    Write-Log '=== Detection END (Exit 1) ==='
    Write-Warning 'Not Compliant'
    exit 1
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)" 'FAIL'
    Write-Log '=== Detection END (Exit 1) ==='
    Write-Warning 'Not Compliant'
    exit 1
}
#endregion ====================================================================

#region ======================== SECOND DETECTION BLOCK ========================
# NOTE:
# This block repeats the exact same detection logic as above.
# In practical implementation, duplication is unnecessary because
# the first Exit statement will terminate execution. It is preserved here
# exactly to keep the current script behavior and structure unchanged.

try {
    # Resolve Winget executable path again.
    $Winget = Get-ChildItem -Path (
        Join-Path -Path (
            Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsApps'
        ) -ChildPath 'Microsoft.DesktopAppInstaller*_x64*\AppInstallerCLI.exe'
    )

    Write-Log "Winget path (second block): $($Winget.FullName)"

    # Execute winget upgrade again.
    $updatecheck = & $winget upgrade

    Write-Log "Raw result count (second block): $($updatecheck.Count)"

    # Evaluate output again.
    if ($updatecheck.Count -lt 3) {
        Write-Log 'No upgrades detected in second block. Returning Exit 0.' 'OK'
        Write-Log '=== Detection END (Exit 0) ==='
        Write-Output 'Compliant'
        exit 0
    }

    Write-Log 'Upgrades detected in second block. Returning Exit 1.' 'WARN'
    Write-Log '=== Detection END (Exit 1) ==='
    Write-Warning 'Not Compliant'
    exit 1
}
catch {
    Write-Log "Second block detection failed: $($_.Exception.Message)" 'FAIL'
    Write-Log '=== Detection END (Exit 1) ==='
    Write-Warning 'Not Compliant'
    exit 1
}
#endregion ====================================================================
