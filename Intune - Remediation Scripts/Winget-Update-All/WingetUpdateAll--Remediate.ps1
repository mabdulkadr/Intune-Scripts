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
    .\WingetUpdateAll--Remediate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ============================ CONFIGURATION ==============================
# Use fixed names so Intune staging does not change the log file name.
$SystemDrive    = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) { 'C:' } else { $env:SystemDrive }
$ScriptName     = 'WingetUpdateAll--Remediate.ps1'
$ScriptBaseName = 'WingetUpdateAll--Remediate'
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

#region ======================== FIRST REMEDIATION BLOCK =======================
Write-Log '=== Remediation START ==='
Write-Log "Script: $ScriptName"
Write-Log "Log file: $LogFile"

# Resolve Winget executable path dynamically from WindowsApps directory.
# This ensures compatibility when running under SYSTEM context.
$Winget = @(
    Get-ChildItem -Path (
        Join-Path -Path (
            Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsApps'
        ) -ChildPath 'Microsoft.DesktopAppInstaller*_x64*\AppInstallerCLI.exe'
    ) -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

    Get-ChildItem -Path (
        Join-Path -Path (
            Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsApps'
        ) -ChildPath 'Microsoft.DesktopAppInstaller*_x64*\winget.exe'
    ) -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

    Get-Command winget.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
) | Select-Object -First 1

if (-not $Winget) {
    throw 'Windows Package Manager executable was not found.'
}

Write-Log "Winget path: $Winget"

# Execute Winget upgrade in fully unattended mode.
# All detected upgradable applications will be updated silently.
& $Winget upgrade --all --force --silent --accept-package-agreements --accept-source-agreements

Write-Log 'Winget remediation command completed.'
Write-Log '=== Remediation END ==='
#endregion ====================================================================
