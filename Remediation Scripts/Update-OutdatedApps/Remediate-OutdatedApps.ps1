<#! 
.SYNOPSIS
    Silently updates only Win32/winget-native apps, excluding Java and Store/ARP/MSIX/XP apps.

.DESCRIPTION
    Parses Winget output, excludes Java and non-Win32 app IDs.
    Only attempts upgrades for classic Win32/winget apps (Id contains a dot, does not start with ARP\, MSIX\, XP, etc).
    Logs actionable steps/results, with clear summary.
    Designed for Intune remediation and Windows PowerShell 5.1+.

.EXAMPLE
    Deploy as Intune Remediation or run as admin for fleet compliance.

.NOTES
    Author  : M.omar
    Website : momar.tech
    Date    : 2025-06-24
    Version : 2.0
#>


# ===== Logging =====
$LogFolder = "C:\Intune"
$LogFile = "$LogFolder\Update-OutdatedApps_log.txt"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}
function Write-Log {
    param (
        [string]$Message
    )
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Message" | Tee-Object -FilePath $LogFile -Append
}

Write-Log ""
Write-Log "======== Starting Winget Update Remediation ========"

# ===== Resolve Winget.exe =====
$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -ErrorAction SilentlyContinue
if (-not $ResolveWingetPath) {
    Write-Log "Winget not found. Exiting."
    exit 1
}
$WingetPath = $ResolveWingetPath[-1].Path
$Winget = "$WingetPath\winget.exe"

# ===== Get upgradable apps =====
$wingetOutput = & $Winget upgrade --accept-source-agreements --accept-package-agreements 2>&1
$clean = $wingetOutput | Where-Object { $_ -notmatch '^\s*[\|\\/\-]+\s*$' -and $_.Trim() -ne "" }
$header = ($clean | Select-String -Pattern '^\s*Name\s+Id' | Select-Object -First 1).LineNumber
if (-not $header) {
    Write-Log "No upgradable apps found."
    exit 0
}
$data = $clean[$header..($clean.Count - 1)]

$apps = foreach ($line in $data) {
    $cols = $line -split '\s{2,}'
    if ($cols.Count -ge 2) {
        [PSCustomObject]@{ Name = $cols[0]; Id = $cols[1] }
    }
}

$appsToUpdate = $apps | Where-Object {
    $_.Id -match '\.' -and $_.Id -notmatch '^(MSIX|ARP|XP)' -and $_.Name -notmatch '(?i)java|jdk|jre|openjdk|graalvm|oraclejdk'
}

if (-not $appsToUpdate) {
    Write-Log "No eligible apps to update."
    exit 0
}

# ===== Process Updates =====
$Success = 0
$Fail = 0
foreach ($app in $appsToUpdate) {
    Write-Log ""
    Write-Log "Updating [$($app.Name)] ..."
    try {
        $result = & $Winget upgrade --id "$($app.Id)" --silent --accept-source-agreements --accept-package-agreements 2>&1
        $output = $result -join "`n"
        if ($LASTEXITCODE -eq 0 -and $output -notmatch "No applicable update") {
            Write-Log "Success: $($app.Name) updated."
            $Success++
        } else {
            $reason = if ($output -match 'No available upgrade found') { "No newer version" } else { $output }
            Write-Log "No Updates: $($app.Name) not updated, $reason"
            $Fail++
        }
    } catch {
        Write-Log "ERROR updating: $($app.Name): $($_.Exception.Message)"
        $Fail++
    }
}

Write-Log "Summary: Updated = $Success | Failed = $Fail"
Write-Log "======== Winget Update Script Completed ========"
exit 0
