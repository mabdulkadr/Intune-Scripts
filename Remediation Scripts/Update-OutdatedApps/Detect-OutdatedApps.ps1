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

# ===== Winget Check =====
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Write-Output "Winget not found. Device is Non-Compliant."
    exit 1
}

# ===== Get Upgrade List =====
try {
    $wingetOutput = winget upgrade --accept-source-agreements --accept-package-agreements 2>&1
} catch {
    Write-Output "Error running winget. Device is Non-Compliant."
    exit 1
}

# ===== Clean spinner/art lines, find table header =====
function Remove-ArtLines { param($lines)
    $lines | Where-Object { $_ -notmatch '^\s*[\|\\/\-]+\s*$' -and $_.Trim() -ne "" }
}
$cleanOutput = Remove-ArtLines $wingetOutput
$headerIdx = ($cleanOutput | Select-String -Pattern '^\s*Name\s+Id(\s+Version)?' | Select-Object -First 1).LineNumber
if (-not $headerIdx) {
    Write-Output "Compliant"
    exit 0
}
$dataLines = $cleanOutput[$headerIdx..($cleanOutput.Count-1)] | Where-Object { $_ -notmatch '^-+$' }

# ===== Parse as [Name] [Id] ([Version] ...) =====
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
    Write-Output "Compliant"
    exit 0
}

# ===== Exclude Java and non-Win32 apps =====
$javaPattern = '(?i)java|openjdk|adoptopenjdk|oraclejdk|azul|corretto|graalvm|jdk|jre'
$appsToCheck = $apps | Where-Object {
    $_.Name -notmatch $javaPattern -and $_.Id -notmatch $javaPattern -and
    $_.Id -notmatch '^(ARP|MSIX|XP|XPFCG|XP8B|XPFC|MSIX\\|MSIX/)' -and
    $_.Id -match '\.'               # Only vendor.ids (Google.Chrome, etc.)
}

if ($appsToCheck) {
    Write-Output "Non-Compliant"
    exit 1
} else {
    Write-Output "Compliant"
    exit 0
}
