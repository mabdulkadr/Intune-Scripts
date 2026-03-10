<#
.SYNOPSIS
    Detect whether Microsoft Outlook is installed at the expected Office 16 path.

.DESCRIPTION
    This detection script checks for the Outlook executable in the standard
    Microsoft 365 Office 16 installation directory.

    It returns a non-compliant result when `OUTLOOK.EXE` is present so the paired
    remediation script can run the Outlook cache cleanup command line switches.

.RUN AS
    System

.EXAMPLE
    .\ClearOutlookCache--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Outlook executable path used by both detection and remediation.
$OutlookPath = 'C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE'

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'ClearOutlookCache--Detect.ps1'
$ScriptBaseName = 'ClearOutlookCache--Detect'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }

# Script-specific logging location.
$SolutionName = 'ClearOutlookCache'
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
if (Test-Path -Path $OutlookPath) {
    Write-Log -Level 'WARN' -Message 'Outlook was found. Cache cleanup remediation should run.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
    return 1
}
else {
    Write-Log -Level 'OK' -Message 'Outlook was not found at the expected path.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 0) ==='
    return 0
}
#endregion ================== FIRST DETECTION BLOCK ==================
