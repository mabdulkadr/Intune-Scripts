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

    This script is commonly used as:
    - Intune Detection Script
    - Proactive Remediation Detection phase
    - Compliance monitoring for third-party application updates

.HINT
    This is a community script. There is no guarantee for this.
    Review and test thoroughly before deploying in production.

.RUN AS
    System

.EXAMPLE
    .\winget-update-detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

# ========================= FIRST DETECTION BLOCK =========================
Try {

    # Resolve Winget executable path from WindowsApps directory (SYSTEM-safe resolution)
    $Winget = Get-ChildItem -Path (
        Join-Path -Path (
            Join-Path -Path $env:ProgramFiles -ChildPath "WindowsApps"
        ) -ChildPath "Microsoft.DesktopAppInstaller*_x64*\AppInstallerCLI.exe"
    )

    # Execute winget upgrade to list applications with available updates
    $updatecheck = &$winget upgrade

    # Evaluate command output line count to determine compliance state
    If ($updatecheck.count -lt 3){

        # No upgrades detected → Compliant
        Write-Output "Compliant"
        Exit 0
    } 

    # Updates detected → Not Compliant
    Write-Warning "Not Compliant"
    Exit 1
} 
Catch {

    # Any execution failure defaults to Not Compliant
    Write-Warning "Not Compliant"
    Exit 1
}

# ========================= SECOND DETECTION BLOCK =========================
# NOTE:
# This block repeats the exact same detection logic as above.
# In practical implementation, duplication is unnecessary because
# the first Exit statement will terminate execution. However,
# it is preserved here intentionally as requested (no code changes).

Try {

    # Resolve Winget executable path again
    $Winget = Get-ChildItem -Path (
        Join-Path -Path (
            Join-Path -Path $env:ProgramFiles -ChildPath "WindowsApps"
        ) -ChildPath "Microsoft.DesktopAppInstaller*_x64*\AppInstallerCLI.exe"
    )

    # Execute winget upgrade again
    $updatecheck = &$winget upgrade

    # Evaluate output again
    If ($updatecheck.count -lt 3){

        # No upgrades detected → Compliant
        Write-Output "Compliant"
        Exit 0
    } 

    # Updates detected → Not Compliant
    Write-Warning "Not Compliant"
    Exit 1
} 
Catch {

    # Any execution failure defaults to Not Compliant
    Write-Warning "Not Compliant"
    Exit 1
}