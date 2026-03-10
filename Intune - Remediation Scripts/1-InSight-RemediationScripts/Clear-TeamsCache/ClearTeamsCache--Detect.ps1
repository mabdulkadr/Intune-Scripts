<#
.SYNOPSIS
    Detect whether the Microsoft Teams cache folder exists for the current user.

.DESCRIPTION
    This detection script checks whether the legacy Teams cache folder exists
    under the current user's AppData profile.

    It returns a non-compliant result when the cache path is present so the
    paired remediation script can clear the Teams cache.

.RUN AS
    User

.EXAMPLE
    .\ClearTeamsCache--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Teams cache path used for detection.
$TeamsCachePath = Join-Path $env:APPDATA 'Microsoft\teams'

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'ClearTeamsCache--Detect.ps1'
$ScriptBaseName = 'ClearTeamsCache--Detect'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }

# Script-specific logging location.
$SolutionName = 'ClearTeamsCache'
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
if (Test-Path -Path $TeamsCachePath) {
    Write-Log -Level 'WARN' -Message 'The Teams cache path exists and remediation should run.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
    Exit 1
}
else {
    Write-Log -Level 'OK' -Message 'The Teams cache path was not found.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 0) ==='
    Exit 0
}
#endregion ================== FIRST DETECTION BLOCK ==================
