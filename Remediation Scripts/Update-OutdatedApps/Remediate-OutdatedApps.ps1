<#! 
.SYNOPSIS
    Silently updates only Win32/winget-native apps, excluding Java and Store/ARP/MSIX/XP apps.

.DESCRIPTION
    This script performs the following actions:
    1. Detects the latest installed WinGet executable.
    2. Retrieves a list of all installed applications.
    3. Retrieves a list of applications with available updates.
    4. Applies exclusion filters for app names or package IDs.
    5. Attempts to silently update each eligible application.
    6. Logs a detailed final audit and update table showing results per application.

    The script is designed for use in enterprise environments to ensure applications
    remain up-to-date with minimal user interaction. It is compatible with PowerShell 5.1
    and WinGet installed via Microsoft Store (AppInstaller)..

.NOTES
    Author  : M.omar
    Website : momar.tech
    Date    : 2025-06-24
    Version : 2.0
#>

param (
    [string[]]$ExcludeNames     = @('Java 8 Update 411'),   # Application display names to exclude
    [string[]]$ExcludeWingetIds = @()                       # Package IDs to exclude
)

$logDir = "C:\Intune"
$logFile = Join-Path $logDir "WingetUpdate_log.txt"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
}

function Log($msg) {
    "$msg" | Tee-Object -FilePath $logFile -Append
}

# Resolve WinGet executable path
function Get-WingetPath {
    (Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*") | ForEach-Object {
        Join-Path $_.Path "winget.exe"
    } | Where-Object { Test-Path $_ } | Select-Object -Last 1
}

# Retrieve installed apps
function Get-Apps($winget) {
    $lines = & $winget list --accept-source-agreements | Where-Object { $_ -match '\S' -and $_ -notmatch '^[-|]+' }
    $header = ($lines | Select-String 'Name\s+Id').LineNumber
    if (-not $header) { return @() }
    return $lines[$header..($lines.Count-1)] | ForEach-Object {
        $cols = $_ -split '\s{2,}'
        if ($cols.Count -ge 3) {
            [PSCustomObject]@{
                AppName     = $cols[0].Trim()
                PackageId   = $cols[1].Trim()
                CurrentVer  = $cols[2].Trim()
                IsInWinget  = $cols[1] -match '\.'
            }
        }
    }
}

# Retrieve upgradable apps
function Get-Upgrades($winget) {
    $lines = & $winget upgrade --accept-source-agreements --accept-package-agreements | Where-Object { $_ -match '\S' -and $_ -notmatch '^[-|]+' }
    $header = ($lines | Select-String 'Name\s+Id').LineNumber
    $map = @{}
    if ($header) {
        $lines[$header..($lines.Count-1)] | ForEach-Object {
            $cols = $_ -split '\s{2,}'
            if ($cols.Count -ge 4) {
                $id = $cols[1].Trim()
                $version = $cols[3].Trim()
                $map[$id] = $version
            }
        }
    }
    return $map
}

function Update-Apps {
    $winget = Get-WingetPath
    if (-not (Test-Path $winget)) {
        Log "Winget not found. Exiting."
        return
    }

    $apps = Get-Apps $winget
    $upgMap = Get-Upgrades $winget

    # Process each app
    $results = foreach ($app in $apps) {
        $excluded = $ExcludeNames -contains $app.AppName -or $ExcludeWingetIds -contains $app.PackageId
        $app | Add-Member -NotePropertyName IsExcluded -NotePropertyValue $excluded
        $upgradable = $upgMap.ContainsKey($app.PackageId)
        $app | Add-Member -NotePropertyName Upgradable -NotePropertyValue $upgradable
        $latest = if ($upgradable) { $upgMap[$app.PackageId] } else { $app.CurrentVer }
        $app | Add-Member -NotePropertyName LatestVer -NotePropertyValue $latest

        if ($excluded) {
            $app | Add-Member -NotePropertyName UpdateStatus -NotePropertyValue 'Excluded'
        } else {
            try {
                $upgradeOutput = & $winget upgrade --id $app.PackageId --silent --accept-source-agreements --accept-package-agreements 2>&1
                if ($LASTEXITCODE -eq 0 -and $upgradeOutput -join '\n' -notmatch 'No applicable update') {
                    $app | Add-Member -NotePropertyName UpdateStatus -NotePropertyValue 'Updated'
                } elseif ($upgradable) {
                    $app | Add-Member -NotePropertyName UpdateStatus -NotePropertyValue 'UpgradeFailed'
                } else {
                    $app | Add-Member -NotePropertyName UpdateStatus -NotePropertyValue 'NotNeeded'
                }
            } catch {
                $app | Add-Member -NotePropertyName UpdateStatus -NotePropertyValue 'Failed'
            }
        }
        $app
    }

    # Final Audit Table
    Log "======== Full App Audit & Update Table ========"
    Log "AppName                 PackageId                     CurrentVer      Native    Upgradable  LatestVer      UpdateStatus"
    Log "----------------------  ----------------------------  -------------- ---------  ----------  ------------  ------------"
    foreach ($r in $results | Sort-Object AppName) {
        $appName = if ($r.AppName) { $r.AppName.Substring(0, [Math]::Min(21, $r.AppName.Length)) } else { "" }
        $pkgId   = if ($r.PackageId) { $r.PackageId.Substring(0, [Math]::Min(27, $r.PackageId.Length)) } else { "" }
        $native  = if ($r.IsInWinget) { 'Yes' } else { 'No' }
        $upgrade = if ($r.Upgradable) { 'Yes' } else { 'No' }
        $line = "{0,-22}  {1,-28}  {2,-14} {3,-9}  {4,-10} {5,-12} {6,-12}" -f $appName, $pkgId, $r.CurrentVer, $native, $upgrade, $r.LatestVer, $r.UpdateStatus
        Log $line
    }

    Log "======== Script Completed ========"
}

Update-Apps
