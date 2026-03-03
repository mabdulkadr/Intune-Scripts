<#
.SYNOPSIS
    Remediates outdated applications by upgrading all supported apps using Windows Package Manager (winget).

.DESCRIPTION
    This remediation script upgrades all installed applications that have
    available updates using Windows Package Manager (winget).

    The script dynamically resolves the location of AppInstallerCLI.exe
    within the WindowsApps directory under Program Files. This approach
    ensures compatibility when running under SYSTEM context, such as
    Microsoft Intune Proactive Remediations or device-level scripts.

    It executes:

        winget upgrade --all --force --silent

    Parameter details:
    --all     : Upgrades all applications with available updates.
    --force   : Reinstalls or overrides version checks when necessary.
    --silent  : Suppresses user interaction prompts for unattended execution.

    This script is typically paired with a detection script that identifies
    devices with pending application updates.

.HINT
    This is a community script. There is no guarantee for this.
    Review and test thoroughly before deploying in production.

.RUN AS
    System (64-bit PowerShell recommended)

.EXAMPLE
    .\winget-upgrade-remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

# Resolve Winget executable path dynamically from WindowsApps directory.
# This ensures compatibility when running under SYSTEM context.
$Winget = Get-ChildItem -Path (
    Join-Path -Path (
        Join-Path -Path $env:ProgramFiles -ChildPath "WindowsApps"
    ) -ChildPath "Microsoft.DesktopAppInstaller*_x64*\AppInstallerCLI.exe"
)

# Execute Winget upgrade in fully unattended mode.
# All detected upgradable applications will be updated silently.
&$winget upgrade --all --force --silent