<#
.SYNOPSIS
    Detect whether the configured local admin account already exists.

.DESCRIPTION
    This detection script checks the local user database for the account defined
    by `$LocalAdminName`.

    It returns a compliant result only when the target local user already exists,
    so the paired remediation script can be skipped.

.RUN AS
    System

.EXAMPLE
    .\CreateLocalAdmin--Detect.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Version : 1.0
#>

#region ========================= CONFIGURATION =========================
# Local user name to check.
$LocalAdminName = ''

# Use a fixed script name so logging stays consistent when Intune stages the script under a temporary local file name.
$ScriptName     = 'CreateLocalAdmin--Detect.ps1'
$ScriptBaseName = 'CreateLocalAdmin--Detect'

# Store logs under the system drive instead of hard-coding C:.
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }

# Script-specific logging location.
$SolutionName = 'CreateLocalAdmin'
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
if (Get-LocalUser | Where-Object Name -eq $LocalAdminName) {
    Write-Host 'User does already exist'
    Write-Log -Level 'OK' -Message 'The configured local admin account already exists.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 0) ==='
    Exit 0
}
else {
    Write-Host 'User does not exist'
    Write-Log -Level 'WARN' -Message 'The configured local admin account was not found.'
    Write-Log -Level 'INFO' -Message '=== Detection END (Exit 1) ==='
    Exit 1
}
#endregion ================== FIRST DETECTION BLOCK ==================
