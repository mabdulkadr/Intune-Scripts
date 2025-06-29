<#! 
.SYNOPSIS
    Detects outdated Win32/winget-native applications, excluding Java-related and non-Win32 apps.

.DESCRIPTION
    Checks for outdated apps via Winget, ignoring Java (JDK/JRE/OpenJDK/etc) and all non-native IDs (Store, ARP, MSIX, XP).
    If any true Win32/winget-native app is outdated, outputs 'Non-Compliant' and exits 1 for Intune detection.
    Otherwise, outputs 'Compliant' and exits 0.

.EXAMPLE
    Use as Intune detection rule (remediation = update script).

.NOTES
    Author  : M.omar
    Website : momar.tech
    Date    : 2025-06-24
    Version : 2.0
#>

# -------- Resolve Winget --------
$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -ErrorAction SilentlyContinue
if (-not $ResolveWingetPath) {
    Write-Output "Winget not found. Non-Compliant"
    exit 1
}
$WingetPath = $ResolveWingetPath[-1].Path
$Winget = "$WingetPath\winget.exe"

# -------- Run upgrade check --------
$upgrades = & $Winget upgrade --accept-source-agreements --accept-package-agreements 2>&1
if (-not $upgrades) {
    Write-Output "Compliant"
    exit 0
}

# -------- Clean output and check --------
$filtered = $upgrades | Where-Object {
    $_ -notmatch '^\s*[\|\\/\-]+\s*$' -and $_.Trim() -ne ""
}
$header = ($filtered | Select-String -Pattern '^\s*Name\s+Id' | Select-Object -First 1).LineNumber
if (-not $header) {
    Write-Output "Compliant"
    exit 0
}
$data = $filtered[$header..($filtered.Count - 1)]
$apps = foreach ($line in $data) {
    $cols = $line -split '\s{2,}'
    if ($cols.Count -ge 2) {
        [PSCustomObject]@{ Name = $cols[0]; Id = $cols[1] }
    }
}

$appsToCheck = $apps | Where-Object {
    $_.Id -match '\.' -and $_.Id -notmatch '^(MSIX|ARP|XP)' -and $_.Name -notmatch '(?i)java|jdk|jre|openjdk|graalvm|oraclejdk'
}

if ($appsToCheck.Count -gt 0) {
    Write-Output "Non-Compliant"
    exit 1
} else {
    Write-Output "Compliant"
    exit 0
}
