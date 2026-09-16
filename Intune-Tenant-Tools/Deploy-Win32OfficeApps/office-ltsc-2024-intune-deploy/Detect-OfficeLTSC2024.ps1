<#
.TITLE
    Detect-OfficeLTSC2024

.SYNOPSIS
    Intune custom detection script for Office LTSC Professional Plus 2024 (volume, Click-to-Run).

.DESCRIPTION
    Verifies that Office LTSC Professional Plus 2024 (volume licensed) is installed and that a core
    application (WINWORD.EXE) exists on disk. Touches only the Click-to-Run registry hive and
    the disk probe; the only write is the detection output captured by Intune.
    Exit contract: 0 = installed (compliant), 1 = not installed (non-compliant),
    2 = script error. Intune treats any non-zero exit as "not installed" and re-evaluates the app.

.TAGS
    Intune,Detection,Office,LTSC,ClickToRun

.REMEDIATIONTYPE
    Win32 App Detection (no remediation partner)

.PAIRSCRIPT
    N/A - this is an Intune Win32 app detection rule, not part of a Proactive Remediation pair.

.PLATFORM
    Windows 10, Windows 11

.PERMISSIONS
    None (local SYSTEM context)

.AUTHOR
    Mohammad Abdelkader Omar | GitHub @mabdulkadr | momar.tech

.VERSION
    1.2.0

.CHANGELOG
    1.2.0 (2026-09-16) - Migrated detection to ProPlus2024Volume (Office LTSC Professional
                          Plus 2024), matching the re-issued install configs.
    1.1.0 (2026-09-16) - Standardized header to the canonical multi-line format and aligned
                         the detection exit contract documentation with the paired Install/
                         Uninstall scripts.
    1.0.0 (2026-09-16) - Initial release.

.LASTUPDATE
    2026-09-16

.EXAMPLE
    Intune: upload as custom detection script, run as SYSTEM, run as 64-bit. Exit 0 = detected.

.NOTES
    Works for fresh installs and upgrades. Requires PowerShell 5.1+. Detection output and
    exit code are captured by the Intune Management Extension; deployment logs are written
    to <SystemDrive>\IntuneLogs\OfficeLTSC2024\ by the paired install scripts.
#>

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

# Reads the ClickToRun registry, confirms the product + core binary, then exits 0/1/2.
$c2rKey = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
$productId = 'ProPlus2024Volume'

# Script error (exit 2) when the authoritative registry key cannot be read.
try {
    $config = Get-ItemProperty -LiteralPath $c2rKey -ErrorAction Stop
} catch {
    Write-Host "ClickToRun registry key '$c2rKey' not found: $($_.Exception.Message)"
    exit 2
}

# Non-compliant when the volume product is missing from ProductReleaseIds.
if (([string]$config.ProductReleaseIds) -notmatch [regex]::Escape($productId)) {
    Write-Host "Product '$productId' not present in ProductReleaseIds: $($config.ProductReleaseIds)"
    exit 1
}

# Non-compliant when no version is reported (partial or failed install).
if (-not $config.VersionToReport) {
    Write-Host 'ClickToRun ProductReleaseIds matches but VersionToReport is empty.'
    exit 1
}

# Hardening: confirm a core binary actually exists at the reported install path.
$installPath = $config.InstallPath
if ($installPath -and -not (Test-Path -LiteralPath (Join-Path $installPath 'root\Office16\WINWORD.EXE'))) {
    Write-Host "WINWORD.EXE not found under InstallPath '$installPath'."
    exit 1
}

Write-Host "Office LTSC 2024 detected: ProductReleaseIds=$($config.ProductReleaseIds) Version=$($config.VersionToReport)"
exit 0