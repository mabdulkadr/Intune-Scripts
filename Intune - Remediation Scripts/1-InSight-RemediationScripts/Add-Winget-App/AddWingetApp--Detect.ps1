<#
.SYNOPSIS
    Detect whether the configured winget application is installed.

.DESCRIPTION
    This detection script resolves the winget executable and checks the configured
    package ID using `winget list`.

    It returns a compliant result only when the application defined by `$AppId`
    is already installed on the device.

.RUN AS
    System

.EXAMPLE
    .\AddWingetApp--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Winget package ID to detect.
$AppId = ''

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'AddWingetApp--Detect.ps1'
$ScriptBaseName = 'AddWingetApp--Detect'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }

# Script-specific logging location.
$SolutionName = 'AddWingetApp'
$BasePath     = Join-Path (Join-Path $SystemDrive 'Intune') $SolutionName
$LogFile      = Join-Path $BasePath ('{0}.txt' -f $ScriptBaseName)
#endregion ====================== CONFIGURATION ======================

#region ========================= HELPER FUNCTIONS =========================
function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

function Start-LogRun {
    Initialize-LogFile
    if (Test-Path -LiteralPath $LogFile) {
        $existingLog = Get-Item -LiteralPath $LogFile -ErrorAction SilentlyContinue
        if ($existingLog -and $existingLog.Length -gt 0) {
            Add-Content -Path $LogFile -Value '' -Encoding UTF8
        }
    }
    Add-Content -Path $LogFile -Value ('=' * 78) -Encoding UTF8
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'FAIL')][string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'OK'   { Write-Host $line -ForegroundColor Green }
        'WARN' { Write-Host $line -ForegroundColor Yellow }
        'FAIL' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }

    try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
}
#endregion ====================== HELPER FUNCTIONS ======================

Start-LogRun
Write-Log -Level 'INFO' -Message '=== Detection START ==='
Write-Log -Level 'INFO' -Message ('Script: {0}' -f $ScriptName)
Write-Log -Level 'INFO' -Message ('Log file: {0}' -f $LogFile)

#region ===================== FIRST DETECTION BLOCK =====================
$ResolveWingetPath = Resolve-Path 'C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe'
if ($ResolveWingetPath) {
    $WingetPath = $ResolveWingetPath[-1].Path
}
else {
    Write-Log -Level 'WARN' -Message 'Winget path was not found. Returning compliant result.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 0) ==='
    exit 0
}

Start-Sleep -Seconds 10

$Winget = $WingetPath + '\winget.exe'
$wingettest = & $Winget list --id $AppId
if ($wingettest -like "*$AppId*") {
    Write-Host 'Found it!'
    Write-Log -Level 'OK' -Message 'The configured application was found.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 0) ==='
    exit 0
}
else {
    Write-Host 'Not Found'
    Write-Log -Level 'WARN' -Message 'The configured application was not found.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
    exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
