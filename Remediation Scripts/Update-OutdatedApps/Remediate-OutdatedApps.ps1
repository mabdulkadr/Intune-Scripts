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
    Version : 3.1
#>

# ========== Logging ==========
$LogFolder = "C:\Intune"
$LogFile   = "$LogFolder\update_log.txt"
if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO","SUCCESS","ERROR","WARNING")]
        [string]$Level = "INFO"
    )
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Color = switch ($Level) {
        "INFO"     { "Cyan" }
        "SUCCESS"  { "Green" }
        "ERROR"    { "Red" }
        "WARNING"  { "Yellow" }
    }
    Write-Host "$Time [$Level] - $Message" -ForegroundColor $Color
    "$Time [$Level] - $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

Write-Log "======== Winget Application Update Script (Win32 Only) Started ========" "INFO"

# ========== Winget Check ==========
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Write-Log "Winget.exe not found! Exiting." "ERROR"
    exit 1
}

# ========== Get Upgrade List ==========
try {
    $wingetOutput = winget upgrade --accept-source-agreements --accept-package-agreements 2>&1
}
catch {
    Write-Log "Error running 'winget upgrade': $($_.Exception.Message)" "ERROR"
    exit 1
}

# ========== Clean spinner/art lines, find table header ==========
function Remove-ArtLines { param($lines)
    $lines | Where-Object { $_ -notmatch '^\s*[\|\\/\-]+\s*$' -and $_.Trim() -ne "" }
}
$cleanOutput = Remove-ArtLines $wingetOutput
$headerIdx = ($cleanOutput | Select-String -Pattern '^\s*Name\s+Id(\s+Version)?' | Select-Object -First 1).LineNumber
if (-not $headerIdx) {
    Write-Log "No table header found in output. Nothing to upgrade." "INFO"
    exit 0
}
$dataLines = $cleanOutput[$headerIdx..($cleanOutput.Count-1)] | Where-Object { $_ -notmatch '^-+$' }

# ========== Parse as [Name] [Id] ([Version] ...) ==========
$apps = @()
foreach ($line in $dataLines) {
    $columns = $line -split '\s{2,}'
    if ($columns.Count -ge 2) {
        $apps += [PSCustomObject]@{
            Name    = $columns[0].Trim()
            Id      = $columns[1].Trim()
        }
    }
}

if (-not $apps) {
    Write-Log "No upgradable applications parsed from Winget output." "INFO"
    exit 0
}

# ========== Exclude Java and non-Win32 apps ==========
$javaPattern = '(?i)java|openjdk|adoptopenjdk|oraclejdk|azul|corretto|graalvm|jdk|jre'
$appsToUpdate = $apps | Where-Object {
    $_.Name -notmatch $javaPattern -and $_.Id -notmatch $javaPattern -and
    $_.Id -notmatch '^(ARP|MSIX|XP|XPFCG|XP8B|XPFC|MSIX\\|MSIX/)' -and
    $_.Id -match '\.'               # Only classic vendor.ids like Google.Chrome
}

if (-not $appsToUpdate) {
    Write-Log "No Win32/winget-native upgradable applications found." "INFO"
    exit 0
}

Write-Log "Eligible for update: $($appsToUpdate.Count) app(s): $($appsToUpdate.Name -join ', ')" "INFO"

$SuccessCount = 0
$FailCount    = 0
foreach ($app in $appsToUpdate) {
    Write-Log "Upgrading [$($app.Name)] (Id: $($app.Id)) ..." "INFO"
    try {
        $result = winget upgrade --id "$($app.Id)" --silent --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0 -and ($result -join "`n") -notmatch 'No applicable update') {
            Write-Log "SUCCESS: $($app.Name) updated." "SUCCESS"
            $SuccessCount++
        }
        else {
            if ($result -match 'No available upgrade found') {
                $shortMsg = 'No newer version.'
            } else {
                $shortMsg = ($result -join ' ')
            }
            Write-Log "WARNING: $($app.Name) not updated. Reason: $shortMsg" "WARNING"
            $FailCount++
        }
    }
    catch {
        Write-Log "ERROR updating $($app.Name): $($_.Exception.Message)" "ERROR"
        $FailCount++
    }
}

Write-Log "Update process completed. Updated: $SuccessCount, Failed/skipped: $FailCount." "INFO"
Write-Log "======== Winget Application Update Script Finished ========" "INFO"
exit 0
